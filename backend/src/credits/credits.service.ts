import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  CreditAccount,
  CreditStatus,
  InterestType,
} from './entities/credit-account.entity';
import {
  CreditInstallment,
  InstallmentStatus,
} from './entities/credit-installment.entity';
import { CreateCreditDto } from './dto/create-credit.dto';
import { PayInstallmentDto } from './dto/pay-installment.dto';
import {
  Notification,
  NotificationType,
} from '../reminders/entities/notification.entity';
import { Payment } from '../payments/entities/payment.entity';

@Injectable()
export class CreditsService {
  private readonly logger = new Logger(CreditsService.name);

  constructor(
    @InjectRepository(CreditAccount)
    private readonly creditsRepository: Repository<CreditAccount>,
    @InjectRepository(CreditInstallment)
    private readonly installmentsRepository: Repository<CreditInstallment>,
    @InjectRepository(Notification)
    private readonly notificationsRepository: Repository<Notification>,
  ) {}

  async create(
    teamId: string,
    createCreditDto: CreateCreditDto,
  ): Promise<CreditAccount> {
    const startDate =
      createCreditDto.startDate || new Date().toISOString().split('T')[0];
    const interestRate = createCreditDto.interestRate || 0;
    const interestType = createCreditDto.interestType || InterestType.NONE;

    // Calculate installment amounts
    const installmentAmounts = this.calculateInstallments(
      createCreditDto.totalAmount,
      interestRate,
      interestType,
      createCreditDto.installments,
    );

    const credit = this.creditsRepository.create({
      teamId,
      saleId: createCreditDto.saleId,
      customerId: createCreditDto.customerId,
      totalAmount: createCreditDto.totalAmount,
      interestRate,
      interestType,
      installments: createCreditDto.installments,
      startDate,
    });
    const savedCredit = await this.creditsRepository.save(credit);

    // Generate installments with due dates
    const installments: CreditInstallment[] = [];
    for (let i = 0; i < createCreditDto.installments; i++) {
      const dueDate = this.addMonths(startDate, i + 1);
      const installment = this.installmentsRepository.create({
        creditAccountId: savedCredit.id,
        installmentNumber: i + 1,
        amount: installmentAmounts[i],
        dueDate,
      });
      installments.push(await this.installmentsRepository.save(installment));
    }

    // Immediate notification so the team sees the new credit right away
    const firstDue = installments[0]?.dueDate ?? '';
    const total = createCreditDto.totalAmount.toLocaleString('es-CO');
    const n = createCreditDto.installments;
    const notification = this.notificationsRepository.create({
      teamId,
      type: NotificationType.SYSTEM,
      title: 'Crédito registrado',
      message: `Crédito por $${total} en ${n} cuota${n > 1 ? 's' : ''}. Primera cuota: ${firstDue}`,
      metadata: {
        creditAccountId: savedCredit.id,
        customerId: savedCredit.customerId,
        totalAmount: createCreditDto.totalAmount,
        installments: n,
        firstDueDate: firstDue,
      },
    });
    await this.notificationsRepository.save(notification);

    return this.findOne(teamId, savedCredit.id);
  }

  async findAll(
    teamId: string,
    options?: { customerId?: string; status?: CreditStatus },
  ): Promise<CreditAccount[]> {
    const query = this.creditsRepository
      .createQueryBuilder('credit')
      .leftJoinAndSelect('credit.customer', 'customer')
      .leftJoinAndSelect('credit.sale', 'sale')
      .leftJoinAndSelect('credit.creditInstallments', 'installments')
      .where('credit.teamId = :teamId', { teamId });

    if (options?.customerId) {
      query.andWhere('credit.customerId = :customerId', {
        customerId: options.customerId,
      });
    }

    if (options?.status) {
      query.andWhere('credit.status = :status', { status: options.status });
    }

    return query
      .orderBy('credit.createdAt', 'DESC')
      .addOrderBy('installments.installmentNumber', 'ASC')
      .getMany();
  }

  async findOne(teamId: string, id: string): Promise<CreditAccount> {
    const credit = await this.creditsRepository.findOne({
      where: { id, teamId },
      relations: ['customer', 'sale', 'creditInstallments'],
      order: { creditInstallments: { installmentNumber: 'ASC' } },
    });
    if (!credit) {
      throw new NotFoundException(`Credit account #${id} not found`);
    }
    return credit;
  }

  async payInstallment(
    teamId: string,
    creditId: string,
    installmentId: string,
    payInstallmentDto: PayInstallmentDto,
  ): Promise<CreditAccount> {
    const credit = await this.findOne(teamId, creditId);

    if (credit.status === CreditStatus.PAID) {
      throw new BadRequestException('This credit is already fully paid');
    }

    const installment = credit.creditInstallments.find(
      (i) => i.id === installmentId,
    );
    if (!installment) {
      throw new NotFoundException('Installment not found');
    }

    if (installment.status === InstallmentStatus.PAID) {
      throw new BadRequestException('This installment is already paid');
    }

    const remaining =
      Number(installment.amount) - Number(installment.paidAmount);
    const paymentAmount = Math.min(payInstallmentDto.amount, remaining);

    installment.paidAmount = Number(installment.paidAmount) + paymentAmount;

    if (installment.paidAmount >= Number(installment.amount)) {
      installment.status = InstallmentStatus.PAID;
      installment.paidAt = new Date();
    } else {
      installment.status = InstallmentStatus.PARTIAL;
    }

    await this.installmentsRepository.save(installment);

    // Create Payment audit record
    const paymentRecord = this.installmentsRepository.manager.create(Payment, {
      teamId,
      saleId: credit.saleId,
      amount: paymentAmount,
      method: 'cash' as any,
      reference: `Installment #${installment.installmentNumber} of credit ${creditId}`,
      creditAccountId: creditId,
      installmentId: installment.id,
      paidAt: new Date(),
    });
    await this.installmentsRepository.manager.save(paymentRecord);

    // Update credit account totals
    credit.paidAmount = Number(credit.paidAmount) + paymentAmount;

    // Check if all installments are paid
    const allPaid = credit.creditInstallments.every((i) =>
      i.id === installmentId
        ? installment.status === InstallmentStatus.PAID
        : i.status === InstallmentStatus.PAID,
    );

    if (allPaid) {
      credit.status = CreditStatus.PAID;
    }

    await this.creditsRepository.save(credit);

    return this.findOne(teamId, creditId);
  }

  async getOverdue(teamId: string): Promise<CreditInstallment[]> {
    const today = new Date().toISOString().split('T')[0];
    return this.installmentsRepository
      .createQueryBuilder('installment')
      .leftJoinAndSelect('installment.creditAccount', 'credit')
      .leftJoinAndSelect('credit.customer', 'customer')
      .where('credit.teamId = :teamId', { teamId })
      .andWhere('installment.dueDate < :today', { today })
      .andWhere('installment.status IN (:...statuses)', {
        statuses: [InstallmentStatus.PENDING, InstallmentStatus.PARTIAL],
      })
      .orderBy('installment.dueDate', 'ASC')
      .getMany();
  }

  private calculateInstallments(
    totalAmount: number,
    interestRate: number,
    interestType: InterestType,
    numInstallments: number,
  ): number[] {
    let totalWithInterest: number;

    switch (interestType) {
      case InterestType.FIXED:
        totalWithInterest = totalAmount * (1 + interestRate / 100);
        break;
      case InterestType.MONTHLY:
        totalWithInterest =
          totalAmount * Math.pow(1 + interestRate / 100, numInstallments);
        break;
      case InterestType.NONE:
      default:
        totalWithInterest = totalAmount;
        break;
    }

    // Banker's rounding: work in cents to avoid floating-point issues
    const totalCents = Math.round(totalWithInterest * 100);
    const baseCents = Math.floor(totalCents / numInstallments);
    const remainder = totalCents - baseCents * numInstallments;

    const amounts: number[] = [];
    for (let i = 0; i < numInstallments; i++) {
      // Distribute remainder cents across the first N installments
      const cents = baseCents + (i < remainder ? 1 : 0);
      amounts.push(cents / 100);
    }

    return amounts;
  }

  /**
   * Marks active credits as DEFAULTED when ALL installments are overdue
   * and at least one is > 30 days past due.
   */
  async markDefaultedCredits(teamId: string): Promise<number> {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const thirtyDaysAgoStr = thirtyDaysAgo.toISOString().split('T')[0];

    const credits = await this.creditsRepository.find({
      where: { teamId, status: CreditStatus.ACTIVE },
      relations: ['creditInstallments'],
    });

    let marked = 0;
    for (const credit of credits) {
      const unpaid = credit.creditInstallments.filter(
        (i) => i.status !== InstallmentStatus.PAID,
      );
      if (unpaid.length === 0) continue;

      const allOverdue = unpaid.every((i) => i.dueDate < thirtyDaysAgoStr);
      if (allOverdue) {
        credit.status = CreditStatus.DEFAULTED;
        await this.creditsRepository.save(credit);
        marked++;
      }
    }
    return marked;
  }

  @Cron('0 7 * * *')
  async handleDefaultedCron(): Promise<void> {
    this.logger.log('Running daily defaulted credits check...');
    try {
      // Get all team IDs with active credits
      const activeCredits = await this.creditsRepository
        .createQueryBuilder('credit')
        .select('DISTINCT credit.teamId', 'teamId')
        .where('credit.status = :status', { status: CreditStatus.ACTIVE })
        .getRawMany();

      let totalMarked = 0;
      for (const { teamId } of activeCredits) {
        try {
          totalMarked += await this.markDefaultedCredits(teamId);
        } catch (error) {
          this.logger.error(`Failed to check defaulted credits for team ${teamId}: ${error.message}`);
        }
      }
      this.logger.log(`Defaulted credits check completed. Marked ${totalMarked} as defaulted.`);
    } catch (error) {
      this.logger.error(`Defaulted credits cron failed: ${error.message}`);
    }
  }

  private addMonths(dateStr: string, months: number): string {
    const date = new Date(dateStr);
    date.setMonth(date.getMonth() + months);
    return date.toISOString().split('T')[0];
  }
}
