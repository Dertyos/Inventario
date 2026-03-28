import { Injectable, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import {
  InventoryMovement,
  MovementType,
} from './entities/inventory-movement.entity';
import { Product } from '../products/entities/product.entity';
import { CreditAccount, InterestType } from '../credits/entities/credit-account.entity';
import { CreditInstallment } from '../credits/entities/credit-installment.entity';
import { CreateMovementDto } from './dto/create-movement.dto';

@Injectable()
export class InventoryService {
  constructor(
    @InjectRepository(InventoryMovement)
    private readonly movementsRepository: Repository<InventoryMovement>,
    @InjectRepository(Product)
    private readonly productsRepository: Repository<Product>,
    private readonly dataSource: DataSource,
  ) {}

  async createMovement(
    teamId: string,
    createMovementDto: CreateMovementDto,
    userId: string,
  ): Promise<InventoryMovement> {
    // Large adjustments require approval (threshold: > 100 units)
    if (
      createMovementDto.type === MovementType.ADJUSTMENT &&
      Math.abs(createMovementDto.quantity) > 100
    ) {
      throw new BadRequestException(
        'Ajustes mayores a 100 unidades requieren aprobación de un administrador',
      );
    }

    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const product = await queryRunner.manager.findOne(Product, {
        where: { id: createMovementDto.productId, teamId },
        lock: { mode: 'pessimistic_write' },
      });

      if (!product) {
        throw new BadRequestException('Product not found in this team');
      }

      const stockBefore = product.stock;
      let stockAfter: number;

      switch (createMovementDto.type) {
        case MovementType.IN:
          stockAfter = stockBefore + createMovementDto.quantity;
          break;
        case MovementType.OUT:
          stockAfter = stockBefore - createMovementDto.quantity;
          if (stockAfter < 0) {
            throw new BadRequestException(
              `Insufficient stock. Available: ${stockBefore}, requested: ${createMovementDto.quantity}`,
            );
          }
          break;
        case MovementType.ADJUSTMENT:
          stockAfter = createMovementDto.quantity;
          break;
        default:
          stockAfter = stockBefore;
      }

      product.stock = stockAfter;
      await queryRunner.manager.save(product);

      // Calculate costs
      const unitCost = createMovementDto.unitCost ?? null;
      const totalCost = unitCost != null ? unitCost * createMovementDto.quantity : null;

      const movement = queryRunner.manager.create(InventoryMovement, {
        type: createMovementDto.type,
        quantity: createMovementDto.quantity,
        reason: createMovementDto.reason,
        productId: createMovementDto.productId,
        supplierId: createMovementDto.supplierId,
        unitCost,
        totalCost,
        teamId,
        userId,
        stockBefore,
        stockAfter,
      });
      const savedMovement = await queryRunner.manager.save(movement);

      // Create credit account for credit purchases
      if (createMovementDto.isCredit && totalCost != null && totalCost > 0) {
        const numInstallments = createMovementDto.creditInstallments || 1;
        const frequency = createMovementDto.creditFrequency || 'monthly';
        const startDate = new Date().toISOString().split('T')[0];

        const totalCents = Math.round(totalCost * 100);
        const baseCents = Math.floor(totalCents / numInstallments);
        const remainder = totalCents - baseCents * numInstallments;

        const creditAccount = queryRunner.manager.create(CreditAccount, {
          teamId,
          saleId: null,
          customerId: null,
          movementId: savedMovement.id,
          totalAmount: totalCost,
          interestRate: 0,
          interestType: InterestType.NONE,
          installments: numInstallments,
          startDate,
        });
        const savedCredit = await queryRunner.manager.save(creditAccount);

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
      return savedMovement;
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
      productId?: string;
      supplierId?: string;
      type?: MovementType;
      page?: number;
      limit?: number;
    },
  ): Promise<InventoryMovement[] | { data: InventoryMovement[]; total: number; page: number; limit: number }> {
    const query = this.movementsRepository
      .createQueryBuilder('movement')
      .leftJoinAndSelect('movement.product', 'product')
      .leftJoinAndSelect('movement.user', 'user')
      .leftJoinAndSelect('movement.supplier', 'supplier')
      .where('movement.teamId = :teamId', { teamId });

    if (options?.productId) {
      query.andWhere('movement.productId = :productId', {
        productId: options.productId,
      });
    }

    if (options?.supplierId) {
      query.andWhere('movement.supplierId = :supplierId', {
        supplierId: options.supplierId,
      });
    }

    if (options?.type) {
      query.andWhere('movement.type = :type', { type: options.type });
    }

    query.orderBy('movement.createdAt', 'DESC');

    if (options?.page && options?.limit) {
      const page = Math.max(1, options.page);
      const limit = Math.max(1, options.limit);
      query.skip((page - 1) * limit).take(limit);
      const [data, total] = await query.getManyAndCount();
      return { data, total, page, limit };
    }

    return query.getMany();
  }

  async findOne(teamId: string, id: string): Promise<InventoryMovement> {
    const movement = await this.movementsRepository.findOne({
      where: { id, teamId },
      relations: ['product', 'user', 'supplier'],
    });
    if (!movement) {
      throw new BadRequestException(`Movement #${id} not found`);
    }
    return movement;
  }
}
