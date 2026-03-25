import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Purchase, PurchaseStatus } from './entities/purchase.entity';
import { PurchaseItem } from './entities/purchase-item.entity';
import { Product } from '../products/entities/product.entity';
import {
  InventoryMovement,
  MovementType,
} from '../inventory/entities/inventory-movement.entity';
import { CreatePurchaseDto } from './dto/create-purchase.dto';

@Injectable()
export class PurchasesService {
  constructor(
    @InjectRepository(Purchase)
    private readonly purchasesRepository: Repository<Purchase>,
    private readonly dataSource: DataSource,
  ) {}

  async create(
    teamId: string,
    userId: string,
    createPurchaseDto: CreatePurchaseDto,
  ): Promise<Purchase> {
    if (!createPurchaseDto.items || createPurchaseDto.items.length === 0) {
      throw new BadRequestException('Purchase must have at least one item');
    }

    const purchaseNumber = await this.generatePurchaseNumber(teamId);

    let total = 0;
    const items: Partial<PurchaseItem>[] = [];

    for (const item of createPurchaseDto.items) {
      const subtotal = item.unitCost * item.quantity;
      total += subtotal;
      items.push({
        productId: item.productId,
        quantity: item.quantity,
        unitCost: item.unitCost,
        subtotal,
      });
    }

    const purchase = this.purchasesRepository.create({
      teamId,
      userId,
      purchaseNumber,
      supplierId: createPurchaseDto.supplierId,
      total,
      notes: createPurchaseDto.notes,
    });
    const savedPurchase = await this.purchasesRepository.save(purchase);

    // Save items
    const itemsRepo = this.dataSource.getRepository(PurchaseItem);
    for (const item of items) {
      const purchaseItem = itemsRepo.create({
        ...item,
        purchaseId: savedPurchase.id,
      });
      await itemsRepo.save(purchaseItem);
    }

    return this.findOne(teamId, savedPurchase.id);
  }

  async findAll(
    teamId: string,
    options?: { supplierId?: string; status?: PurchaseStatus },
  ): Promise<Purchase[]> {
    const query = this.purchasesRepository
      .createQueryBuilder('purchase')
      .leftJoinAndSelect('purchase.supplier', 'supplier')
      .leftJoinAndSelect('purchase.user', 'user')
      .leftJoinAndSelect('purchase.items', 'items')
      .leftJoinAndSelect('items.product', 'product')
      .where('purchase.teamId = :teamId', { teamId });

    if (options?.supplierId) {
      query.andWhere('purchase.supplierId = :supplierId', {
        supplierId: options.supplierId,
      });
    }

    if (options?.status) {
      query.andWhere('purchase.status = :status', { status: options.status });
    }

    return query.orderBy('purchase.createdAt', 'DESC').getMany();
  }

  async findOne(teamId: string, id: string): Promise<Purchase> {
    const purchase = await this.purchasesRepository.findOne({
      where: { id, teamId },
      relations: ['supplier', 'user', 'items', 'items.product'],
    });
    if (!purchase) {
      throw new NotFoundException(`Purchase #${id} not found`);
    }
    return purchase;
  }

  /**
   * Receive a purchase: adds stock to products and creates inventory movements.
   */
  async receive(teamId: string, id: string, userId: string): Promise<Purchase> {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();
    await queryRunner.startTransaction();

    try {
      const purchase = await queryRunner.manager.findOne(Purchase, {
        where: { id, teamId },
        relations: ['items'],
      });

      if (!purchase) {
        throw new NotFoundException(`Purchase #${id} not found`);
      }

      if (purchase.status !== PurchaseStatus.PENDING) {
        throw new BadRequestException(`Purchase is already ${purchase.status}`);
      }

      for (const item of purchase.items) {
        const product = await queryRunner.manager.findOne(Product, {
          where: { id: item.productId },
          lock: { mode: 'pessimistic_write' },
        });

        if (!product) continue;

        const stockBefore = product.stock;
        product.stock += item.quantity;
        // Update cost to last purchase cost
        product.cost = Number(item.unitCost);
        await queryRunner.manager.save(product);

        const movement = queryRunner.manager.create(InventoryMovement, {
          teamId,
          productId: item.productId,
          userId,
          type: MovementType.PURCHASE,
          quantity: item.quantity,
          stockBefore,
          stockAfter: product.stock,
          reason: `Purchase #${purchase.purchaseNumber}`,
          referenceType: 'purchase',
          referenceId: purchase.id,
        });
        await queryRunner.manager.save(movement);
      }

      purchase.status = PurchaseStatus.RECEIVED;
      purchase.receivedAt = new Date().toISOString().split('T')[0];
      await queryRunner.manager.save(purchase);

      await queryRunner.commitTransaction();
      return this.findOne(teamId, id);
    } catch (error) {
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  async cancel(teamId: string, id: string): Promise<Purchase> {
    const purchase = await this.findOne(teamId, id);

    if (purchase.status !== PurchaseStatus.PENDING) {
      throw new BadRequestException('Only pending purchases can be cancelled');
    }

    purchase.status = PurchaseStatus.CANCELLED;
    return this.purchasesRepository.save(purchase);
  }

  private async generatePurchaseNumber(teamId: string): Promise<string> {
    const lastPurchase = await this.purchasesRepository.findOne({
      where: { teamId },
      order: { createdAt: 'DESC' },
    });

    if (!lastPurchase) {
      return 'C-0001';
    }

    const lastNumber =
      parseInt(lastPurchase.purchaseNumber.split('-')[1], 10) || 0;
    return `C-${String(lastNumber + 1).padStart(4, '0')}`;
  }
}
