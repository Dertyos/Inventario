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
import { UpdateSaleDto } from './dto/update-sale.dto';
import { PaymentMethod } from './entities/sale.entity';
import { CreditsService } from '../credits/credits.service';
import { CreditAccount, CreditStatus } from '../credits/entities/credit-account.entity';
import { CreditInstallment } from '../credits/entities/credit-installment.entity';
import { Customer } from '../customers/entities/customer.entity';

@Injectable()
export class SalesService {
  constructor(
    @InjectRepository(Sale)
    private readonly salesRepository: Repository<Sale>,
    private readonly dataSource: DataSource,
    private readonly creditsService: CreditsService,
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

      // Validate customer belongs to team
      if (createSaleDto.customerId) {
        const customer = await queryRunner.manager.findOne(Customer, {
          where: { id: createSaleDto.customerId, teamId },
        });
        if (!customer) {
          throw new BadRequestException('El cliente no pertenece a este equipo');
        }
      }

      // Validate creditPaidAmount doesn't exceed subtotal
      if (createSaleDto.creditPaidAmount != null && createSaleDto.creditPaidAmount > subtotal) {
        throw new BadRequestException(
          `El abono (${createSaleDto.creditPaidAmount}) no puede ser mayor al total de la venta (${subtotal})`,
        );
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
        creditFrequency: createSaleDto.creditFrequency || null,
        creditNextPayment: createSaleDto.creditNextPayment
          ? new Date(createSaleDto.creditNextPayment)
          : null,
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

      // Auto-create credit account for all credit sales (INSIDE transaction)
      if (createSaleDto.paymentMethod === PaymentMethod.CREDIT) {
        const interestRate = createSaleDto.creditInterestRate || 0;
        let interestType = 'none';
        if (interestRate > 0) {
          interestType = createSaleDto.creditFrequency === 'monthly' ? 'monthly' : 'fixed';
        }

        const numInstallments = createSaleDto.creditInstallments || 1;
        const startDate = new Date().toISOString().split('T')[0];

        // Calculate total with interest
        let totalWithInterest: number;
        if (interestType === 'fixed') {
          totalWithInterest = subtotal * (1 + interestRate / 100);
        } else if (interestType === 'monthly') {
          totalWithInterest = subtotal * Math.pow(1 + interestRate / 100, numInstallments);
        } else {
          totalWithInterest = subtotal;
        }

        // Banker's rounding for installments
        const totalCents = Math.round(totalWithInterest * 100);
        const baseCents = Math.floor(totalCents / numInstallments);
        const remainder = totalCents - baseCents * numInstallments;

        const creditAccount = queryRunner.manager.create(CreditAccount, {
          teamId,
          saleId: savedSale.id,
          customerId: createSaleDto.customerId || null,
          totalAmount: totalWithInterest,
          interestRate,
          interestType: interestType as any,
          installments: numInstallments,
          startDate,
        });
        const savedCredit = await queryRunner.manager.save(creditAccount);

        const frequency = createSaleDto.creditFrequency || 'monthly';

        for (let i = 0; i < numInstallments; i++) {
          const amount = (baseCents + (i < remainder ? 1 : 0)) / 100;
          const dueDate = new Date(startDate);
          if (frequency === 'daily') {
            dueDate.setDate(dueDate.getDate() + i + 1);
          } else if (frequency === 'weekly') {
            dueDate.setDate(dueDate.getDate() + (i + 1) * 7);
          } else {
            dueDate.setMonth(dueDate.getMonth() + i + 1);
          }

          const installment = queryRunner.manager.create(CreditInstallment, {
            creditAccountId: savedCredit.id,
            installmentNumber: i + 1,
            amount,
            dueDate: dueDate.toISOString().split('T')[0],
          });
          await queryRunner.manager.save(installment);
        }
      }

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
      page?: number;
      limit?: number;
    },
  ): Promise<Sale[] | { data: Sale[]; total: number; page: number; limit: number }> {
    const query = this.salesRepository
      .createQueryBuilder('sale')
      .leftJoinAndSelect('sale.customer', 'customer')
      .leftJoinAndSelect('sale.user', 'user')
      .leftJoinAndSelect('sale.items', 'items')
      .leftJoinAndSelect('items.product', 'product')
      .leftJoin('sale.creditAccount', 'creditAccount')
      .addSelect(['creditAccount.id'])
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

    query.orderBy('sale.createdAt', 'DESC');

    if (options?.page && options?.limit) {
      const page = Math.max(1, options.page);
      const limit = Math.max(1, options.limit);
      query.skip((page - 1) * limit).take(limit);
      const [data, total] = await query.getManyAndCount();
      return { data, total, page, limit };
    }

    return query.getMany();
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

      // Cancel associated credit account if exists
      const creditAccount = await queryRunner.manager.findOne(CreditAccount, {
        where: { saleId: sale.id, teamId },
      });
      if (creditAccount && creditAccount.status !== CreditStatus.PAID) {
        creditAccount.status = CreditStatus.DEFAULTED;
        await queryRunner.manager.save(creditAccount);
      }

      await queryRunner.commitTransaction();
      return this.findOne(teamId, id);
    } catch (error) {
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  async update(
    teamId: string,
    id: string,
    updateSaleDto: UpdateSaleDto,
  ): Promise<Sale> {
    const sale = await this.findOne(teamId, id);

    if (sale.status === SaleStatus.CANCELLED) {
      throw new BadRequestException('Cannot edit a cancelled sale');
    }

    if (updateSaleDto.customerId !== undefined) {
      sale.customerId = updateSaleDto.customerId;
    }
    if (updateSaleDto.paymentMethod !== undefined) {
      sale.paymentMethod = updateSaleDto.paymentMethod;
    }
    if (updateSaleDto.creditInstallments !== undefined) {
      sale.creditInstallments = updateSaleDto.creditInstallments;
    }
    if (updateSaleDto.creditPaidAmount !== undefined) {
      sale.creditPaidAmount = updateSaleDto.creditPaidAmount;
    }
    if (updateSaleDto.creditInterestRate !== undefined) {
      sale.creditInterestRate = updateSaleDto.creditInterestRate;
    }
    if (updateSaleDto.creditFrequency !== undefined) {
      sale.creditFrequency = updateSaleDto.creditFrequency;
    }
    if (updateSaleDto.creditNextPayment !== undefined) {
      sale.creditNextPayment = new Date(updateSaleDto.creditNextPayment);
    }
    if (updateSaleDto.notes !== undefined) {
      sale.notes = updateSaleDto.notes;
    }

    await this.salesRepository.save(sale);
    return this.findOne(teamId, id);
  }

  async remove(teamId: string, id: string, userId: string): Promise<void> {
    const sale = await this.findOne(teamId, id);

    if (sale.status !== SaleStatus.CANCELLED) {
      throw new BadRequestException(
        'Only cancelled sales can be deleted. Cancel the sale first.',
      );
    }

    await this.salesRepository.remove(sale);
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
