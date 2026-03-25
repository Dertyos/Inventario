import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan, In } from 'typeorm';
import { ProductLot, LotStatus } from './entities/product-lot.entity';
import { CreateLotDto } from './dto/create-lot.dto';

@Injectable()
export class LotsService {
  constructor(
    @InjectRepository(ProductLot)
    private readonly lotsRepository: Repository<ProductLot>,
  ) {}

  async create(
    teamId: string,
    createLotDto: CreateLotDto,
  ): Promise<ProductLot> {
    const lot = this.lotsRepository.create({
      ...createLotDto,
      teamId,
    });
    return this.lotsRepository.save(lot);
  }

  async findAll(
    teamId: string,
    options?: { productId?: string; status?: LotStatus },
  ): Promise<ProductLot[]> {
    const query = this.lotsRepository
      .createQueryBuilder('lot')
      .leftJoinAndSelect('lot.product', 'product')
      .where('lot.teamId = :teamId', { teamId });

    if (options?.productId) {
      query.andWhere('lot.productId = :productId', {
        productId: options.productId,
      });
    }

    if (options?.status) {
      query.andWhere('lot.status = :status', { status: options.status });
    }

    return query.orderBy('lot.expirationDate', 'ASC', 'NULLS LAST').getMany();
  }

  async findOne(teamId: string, id: string): Promise<ProductLot> {
    const lot = await this.lotsRepository.findOne({
      where: { id, teamId },
      relations: ['product'],
    });
    if (!lot) {
      throw new NotFoundException(`Lot #${id} not found`);
    }
    return lot;
  }

  /**
   * FEFO: First Expired, First Out.
   * Deducts quantity from the oldest expiring lots first.
   * Returns the lots that were affected.
   */
  async deductFromLots(
    teamId: string,
    productId: string,
    quantity: number,
  ): Promise<{ lotId: string; deducted: number }[]> {
    const lots = await this.lotsRepository.find({
      where: { teamId, productId, status: LotStatus.ACTIVE },
      order: { expirationDate: 'ASC' },
    });

    let remaining = quantity;
    const deductions: { lotId: string; deducted: number }[] = [];

    for (const lot of lots) {
      if (remaining <= 0) break;

      const available = lot.quantity - lot.soldQuantity;
      if (available <= 0) continue;

      const toDeduct = Math.min(available, remaining);
      lot.soldQuantity += toDeduct;
      remaining -= toDeduct;

      if (lot.soldQuantity >= lot.quantity) {
        lot.status = LotStatus.DEPLETED;
      }

      await this.lotsRepository.save(lot);
      deductions.push({ lotId: lot.id, deducted: toDeduct });
    }

    if (remaining > 0) {
      throw new BadRequestException(
        `Insufficient lot stock for product ${productId}. Missing: ${remaining} units`,
      );
    }

    return deductions;
  }

  /**
   * Returns lots expiring within the specified number of days.
   */
  async getExpiringLots(
    teamId: string,
    daysAhead: number = 30,
  ): Promise<ProductLot[]> {
    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + daysAhead);
    const futureDateStr = futureDate.toISOString().split('T')[0];

    return this.lotsRepository.find({
      where: {
        teamId,
        status: In([LotStatus.ACTIVE]),
        expirationDate: LessThan(futureDateStr),
      },
      relations: ['product'],
      order: { expirationDate: 'ASC' },
    });
  }

  /**
   * Marks expired lots based on current date.
   */
  async markExpiredLots(teamId: string): Promise<number> {
    const today = new Date().toISOString().split('T')[0];
    const result = await this.lotsRepository
      .createQueryBuilder()
      .update(ProductLot)
      .set({ status: LotStatus.EXPIRED })
      .where('teamId = :teamId', { teamId })
      .andWhere('status = :status', { status: LotStatus.ACTIVE })
      .andWhere('expirationDate < :today', { today })
      .execute();
    return result.affected || 0;
  }
}
