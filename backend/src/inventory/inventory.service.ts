import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import {
  InventoryMovement,
  MovementType,
} from './entities/inventory-movement.entity';
import { Product } from '../products/entities/product.entity';
import { ProductLot, LotStatus } from '../lots/entities/product-lot.entity';
import { CreditAccount, InterestType } from '../credits/entities/credit-account.entity';
import { CreditInstallment } from '../credits/entities/credit-installment.entity';
import { TeamSettings } from '../teams/entities/team-settings.entity';
import { CreateMovementDto } from './dto/create-movement.dto';

@Injectable()
export class InventoryService {
  constructor(
    @InjectRepository(InventoryMovement)
    private readonly movementsRepository: Repository<InventoryMovement>,
    @InjectRepository(Product)
    private readonly productsRepository: Repository<Product>,
    @InjectRepository(TeamSettings)
    private readonly settingsRepository: Repository<TeamSettings>,
    private readonly dataSource: DataSource,
  ) {}

  async createMovement(
    teamId: string,
    createMovementDto: CreateMovementDto,
    userId: string,
  ): Promise<InventoryMovement> {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const product = await queryRunner.manager.findOne(Product, {
        where: { id: createMovementDto.productId, teamId },
        lock: { mode: 'pessimistic_write' },
      });

      if (!product) {
        throw new BadRequestException('Producto no encontrado en este equipo');
      }

      // Check if lots are required for this product
      const settings = await this.settingsRepository.findOne({ where: { teamId } });
      const lotsEnabled = settings?.enableLots ?? false;
      const requiresLot = lotsEnabled && product.trackLots;

      if (requiresLot && !createMovementDto.lotId && createMovementDto.type === MovementType.IN) {
        throw new BadRequestException(
          'Este producto requiere seleccionar un lote para registrar entrada de stock',
        );
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
              `Stock insuficiente. Disponible: ${stockBefore}, solicitado: ${createMovementDto.quantity}`,
            );
          }
          break;
        default:
          stockAfter = stockBefore;
      }

      product.stock = stockAfter;
      await queryRunner.manager.save(product);

      // Update lot quantity if lot is specified
      let lotId = createMovementDto.lotId || null;
      if (lotId) {
        const lot = await queryRunner.manager.findOne(ProductLot, {
          where: { id: lotId, teamId, productId: product.id },
        });
        if (!lot) {
          throw new BadRequestException('Lote no encontrado para este producto');
        }

        if (createMovementDto.type === MovementType.IN) {
          lot.quantity += createMovementDto.quantity;
          if (lot.status === LotStatus.DEPLETED) {
            lot.status = LotStatus.ACTIVE;
          }
        } else if (createMovementDto.type === MovementType.OUT) {
          const available = lot.quantity - lot.soldQuantity;
          if (createMovementDto.quantity > available) {
            throw new BadRequestException(
              `Stock insuficiente en lote ${lot.lotNumber}. Disponible: ${available}`,
            );
          }
          lot.soldQuantity += createMovementDto.quantity;
          if (lot.soldQuantity >= lot.quantity) {
            lot.status = LotStatus.DEPLETED;
          }
        }
        await queryRunner.manager.save(lot);
      }

      // Calculate costs
      const unitCost = createMovementDto.unitCost ?? null;
      const totalCost = unitCost != null ? unitCost * createMovementDto.quantity : null;

      const movement = queryRunner.manager.create(InventoryMovement, {
        type: createMovementDto.type,
        quantity: createMovementDto.quantity,
        reason: createMovementDto.reason,
        productId: createMovementDto.productId,
        supplierId: createMovementDto.supplierId,
        lotId,
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
          supplierId: createMovementDto.supplierId || null,
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
      return this.findOne(teamId, savedMovement.id);
    } catch (error) {
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  async deleteMovement(
    teamId: string,
    id: string,
  ): Promise<void> {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const movement = await queryRunner.manager.findOne(InventoryMovement, {
        where: { id, teamId },
      });

      if (!movement) {
        throw new NotFoundException('Movimiento no encontrado');
      }

      // Don't allow deleting system-generated movements (sales, purchases)
      if (movement.type === MovementType.SALE || movement.type === MovementType.PURCHASE) {
        throw new BadRequestException(
          'No se puede eliminar un movimiento generado por una venta o compra',
        );
      }

      // Revert product stock
      const product = await queryRunner.manager.findOne(Product, {
        where: { id: movement.productId, teamId },
        lock: { mode: 'pessimistic_write' },
      });

      if (product) {
        if (movement.type === MovementType.IN) {
          product.stock = Math.max(0, product.stock - movement.quantity);
        } else if (movement.type === MovementType.OUT) {
          product.stock += movement.quantity;
        }
        await queryRunner.manager.save(product);
      }

      // Revert lot quantity if lot was involved
      if (movement.lotId) {
        const lot = await queryRunner.manager.findOne(ProductLot, {
          where: { id: movement.lotId },
        });
        if (lot) {
          if (movement.type === MovementType.IN) {
            lot.quantity = Math.max(0, lot.quantity - movement.quantity);
            if (lot.quantity <= lot.soldQuantity) {
              lot.status = LotStatus.DEPLETED;
            }
          } else if (movement.type === MovementType.OUT) {
            lot.soldQuantity = Math.max(0, lot.soldQuantity - movement.quantity);
            if (lot.status === LotStatus.DEPLETED && lot.soldQuantity < lot.quantity) {
              lot.status = LotStatus.ACTIVE;
            }
          }
          await queryRunner.manager.save(lot);
        }
      }

      await queryRunner.manager.remove(movement);
      await queryRunner.commitTransaction();
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
      .leftJoinAndSelect('movement.lot', 'lot')
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
      relations: ['product', 'user', 'supplier', 'lot'],
    });
    if (!movement) {
      throw new NotFoundException(`Movimiento no encontrado`);
    }
    return movement;
  }
}
