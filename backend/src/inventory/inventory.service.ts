import { Injectable, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import {
  InventoryMovement,
  MovementType,
} from './entities/inventory-movement.entity';
import { Product } from '../products/entities/product.entity';
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

      const movement = queryRunner.manager.create(InventoryMovement, {
        ...createMovementDto,
        teamId,
        userId,
        stockBefore,
        stockAfter,
      });
      const savedMovement = await queryRunner.manager.save(movement);

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
      type?: MovementType;
    },
  ): Promise<InventoryMovement[]> {
    const query = this.movementsRepository
      .createQueryBuilder('movement')
      .leftJoinAndSelect('movement.product', 'product')
      .leftJoinAndSelect('movement.user', 'user')
      .where('movement.teamId = :teamId', { teamId });

    if (options?.productId) {
      query.andWhere('movement.productId = :productId', {
        productId: options.productId,
      });
    }

    if (options?.type) {
      query.andWhere('movement.type = :type', { type: options.type });
    }

    return query.orderBy('movement.createdAt', 'DESC').getMany();
  }

  async findOne(teamId: string, id: string): Promise<InventoryMovement> {
    const movement = await this.movementsRepository.findOne({
      where: { id, teamId },
      relations: ['product', 'user'],
    });
    if (!movement) {
      throw new BadRequestException(`Movement #${id} not found`);
    }
    return movement;
  }
}
