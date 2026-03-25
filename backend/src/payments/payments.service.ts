import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Payment } from './entities/payment.entity';
import { CreatePaymentDto } from './dto/create-payment.dto';

@Injectable()
export class PaymentsService {
  constructor(
    @InjectRepository(Payment)
    private readonly paymentsRepository: Repository<Payment>,
  ) {}

  async create(
    teamId: string,
    userId: string,
    createPaymentDto: CreatePaymentDto,
  ): Promise<Payment> {
    const payment = this.paymentsRepository.create({
      ...createPaymentDto,
      teamId,
      receivedBy: userId,
      paidAt: new Date(),
    });
    return this.paymentsRepository.save(payment);
  }

  async findAll(
    teamId: string,
    options?: { saleId?: string },
  ): Promise<Payment[]> {
    const query = this.paymentsRepository
      .createQueryBuilder('payment')
      .leftJoinAndSelect('payment.sale', 'sale')
      .leftJoinAndSelect('payment.receivedByUser', 'user')
      .where('payment.teamId = :teamId', { teamId });

    if (options?.saleId) {
      query.andWhere('payment.saleId = :saleId', {
        saleId: options.saleId,
      });
    }

    return query.orderBy('payment.paidAt', 'DESC').getMany();
  }

  async findOne(teamId: string, id: string): Promise<Payment> {
    const payment = await this.paymentsRepository.findOne({
      where: { id, teamId },
      relations: ['sale', 'receivedByUser'],
    });
    if (!payment) {
      throw new NotFoundException(`Payment #${id} not found`);
    }
    return payment;
  }
}
