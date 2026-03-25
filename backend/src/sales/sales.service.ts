import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Sale, SaleStatus } from './entities/sale.entity';
import { SaleItem } from './entities/sale-item.entity';
import { Product } from '../products/entities/product.entity';
import {
  InventoryMovement,
  MovementType,
} from '../inventory/entities/inventory-movement.entity';
import { CreateSaleDto } from './dto/create-sale.dto';

@Injectable()
export class SalesService {
  constructor(
    @InjectRepository(Sale)
    private readonly salesRepository: Repository<Sale>,
    private readonly dataSource: DataSource,
  ) {}

  async create(
    teamId: string,
    userId: string,
    createSaleDto: CreateSaleDto,
  ): Promise<Sale> {
    if (!createSaleDto.items || createSaleDto.items.length === 0) {
      throw new BadRequestException('Sale must have at least one item');
    }

    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      // Generate sale number
      const saleNumber = await this.generateSaleNumber(teamId, queryRunner);

      // Process items: validate stock and calculate totals
      let subtotal = 0;
      const saleItems: Partial<SaleItem>[] = [];

      for (const item of createSaleDto.items) {
        const product = await queryRunner.manager.findOne(Product, {
          where: { id: item.productId, teamId },
          lock: { mode: 'pessimistic_write' },
        });

        if (!product) {
          throw new BadRequestException(
            `Product ${item.productId} not found in this team`,
          );
        }

        if (!product.isActive) {
          throw new BadRequestException(
            `Product "${product.name}" is not active`,
          );
        }

        if (product.stock < item.quantity) {
          throw new BadRequestException(
            `Insufficient stock for "${product.name}". Available: ${product.stock}, requested: ${item.quantity}`,
          );
        }

        const itemSubtotal = item.unitPrice * item.quantity;
        subtotal += itemSubtotal;

        saleItems.push({
          productId: item.productId,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          subtotal: itemSubtotal,
        });

        // Deduct stock
        const stockBefore = product.stock;
        product.stock -= item.quantity;
        await queryRunner.manager.save(product);

        // Create inventory movement
        const movement = queryRunner.manager.create(InventoryMovement, {
          teamId,
          productId: item.productId,
          userId,
          type: MovementType.SALE,
          quantity: item.quantity,
          stockBefore,
          stockAfter: product.stock,
          reason: `Sale #${saleNumber}`,
          referenceType: 'sale',
        });
        await queryRunner.manager.save(movement);
      }

      // Create sale
      const sale = queryRunner.manager.create(Sale, {
        teamId,
        userId,
        saleNumber,
        customerId: createSaleDto.customerId || null,
        paymentMethod: createSaleDto.paymentMethod,
        subtotal,
        tax: 0, // Tax calculation done in Phase with enableTax
        total: subtotal,
        creditInstallments: createSaleDto.creditInstallments || null,
        creditPaidAmount: createSaleDto.creditPaidAmount ?? null,
        creditInterestRate: createSaleDto.creditInterestRate ?? null,
        notes: createSaleDto.notes,
      });
      const savedSale = await queryRunner.manager.save(sale);

      // Create sale items
      for (const item of saleItems) {
        const saleItem = queryRunner.manager.create(SaleItem, {
          ...item,
          saleId: savedSale.id,
        });
        await queryRunner.manager.save(saleItem);
      }

      // Update movement references with sale ID
      await queryRunner.manager.update(
        InventoryMovement,
        {
          referenceType: 'sale',
          referenceId: null,
          reason: `Sale #${saleNumber}`,
        },
        { referenceId: savedSale.id },
      );

      await queryRunner.commitTransaction();

      return this.findOne(teamId, savedSale.id);
    } catch (error) {
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  async findAll(
    teamId: string,
    options?: {
      customerId?: string;
      status?: SaleStatus;
      startDate?: string;
      endDate?: string;
    },
  ): Promise<Sale[]> {
    const query = this.salesRepository
      .createQueryBuilder('sale')
      .leftJoinAndSelect('sale.customer', 'customer')
      .leftJoinAndSelect('sale.user', 'user')
      .leftJoinAndSelect('sale.items', 'items')
      .leftJoinAndSelect('items.product', 'product')
      .where('sale.teamId = :teamId', { teamId });

    if (options?.customerId) {
      query.andWhere('sale.customerId = :customerId', {
        customerId: options.customerId,
      });
    }

    if (options?.status) {
      query.andWhere('sale.status = :status', { status: options.status });
    }

    if (options?.startDate) {
      query.andWhere('sale.createdAt >= :startDate', {
        startDate: options.startDate,
      });
    }

    if (options?.endDate) {
      query.andWhere('sale.createdAt <= :endDate', {
        endDate: options.endDate,
      });
    }

    return query.orderBy('sale.createdAt', 'DESC').getMany();
  }

  async findOne(teamId: string, id: string): Promise<Sale> {
    const sale = await this.salesRepository.findOne({
      where: { id, teamId },
      relations: ['customer', 'user', 'items', 'items.product', 'payments'],
    });
    if (!sale) {
      throw new NotFoundException(`Sale #${id} not found`);
    }
    return sale;
  }

  async cancel(teamId: string, id: string, userId: string): Promise<Sale> {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const sale = await queryRunner.manager.findOne(Sale, {
        where: { id, teamId },
        relations: ['items'],
      });

      if (!sale) {
        throw new NotFoundException(`Sale #${id} not found`);
      }

      if (sale.status === SaleStatus.CANCELLED) {
        throw new BadRequestException('Sale is already cancelled');
      }

      // Restore stock for each item
      for (const item of sale.items) {
        const product = await queryRunner.manager.findOne(Product, {
          where: { id: item.productId, teamId },
          lock: { mode: 'pessimistic_write' },
        });

        if (product) {
          const stockBefore = product.stock;
          product.stock += item.quantity;
          await queryRunner.manager.save(product);

          // Create return movement
          const movement = queryRunner.manager.create(InventoryMovement, {
            teamId,
            productId: item.productId,
            userId,
            type: MovementType.RETURN,
            quantity: item.quantity,
            stockBefore,
            stockAfter: product.stock,
            reason: `Cancelled sale #${sale.saleNumber}`,
            referenceType: 'sale',
            referenceId: sale.id,
          });
          await queryRunner.manager.save(movement);
        }
      }

      sale.status = SaleStatus.CANCELLED;
      await queryRunner.manager.save(sale);

      await queryRunner.commitTransaction();
      return this.findOne(teamId, id);
    } catch (error) {
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  private async generateSaleNumber(
    teamId: string,
    queryRunner: any,
  ): Promise<string> {
    const lastSale = await queryRunner.manager.findOne(Sale, {
      where: { teamId },
      order: { createdAt: 'DESC' },
    });

    if (!lastSale) {
      return 'V-0001';
    }

    const lastNumber = parseInt(lastSale.saleNumber.split('-')[1], 10) || 0;
    return `V-${String(lastNumber + 1).padStart(4, '0')}`;
  }
}
