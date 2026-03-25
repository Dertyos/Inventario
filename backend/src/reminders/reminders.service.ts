import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  PaymentReminder,
  ReminderStatus,
  ReminderType,
  ReminderChannel,
} from './entities/payment-reminder.entity';
import { Notification, NotificationType } from './entities/notification.entity';
import {
  CreditInstallment,
  InstallmentStatus,
} from '../credits/entities/credit-installment.entity';

@Injectable()
export class RemindersService {
  constructor(
    @InjectRepository(PaymentReminder)
    private readonly remindersRepository: Repository<PaymentReminder>,
    @InjectRepository(Notification)
    private readonly notificationsRepository: Repository<Notification>,
    @InjectRepository(CreditInstallment)
    private readonly installmentsRepository: Repository<CreditInstallment>,
  ) {}

  /**
   * Generates payment reminders for upcoming and overdue installments.
   * - 3 days before due: BEFORE_DUE
   * - On due date: ON_DUE
   * - 1 day after due: AFTER_DUE
   */
  async generateReminders(teamId: string): Promise<number> {
    const today = new Date();
    const threeDaysAhead = new Date(today);
    threeDaysAhead.setDate(today.getDate() + 3);
    const oneDayAgo = new Date(today);
    oneDayAgo.setDate(today.getDate() - 1);

    const todayStr = today.toISOString().split('T')[0];
    const threeDaysStr = threeDaysAhead.toISOString().split('T')[0];
    const oneDayAgoStr = oneDayAgo.toISOString().split('T')[0];

    // Find installments needing reminders
    const installments = await this.installmentsRepository
      .createQueryBuilder('installment')
      .leftJoinAndSelect('installment.creditAccount', 'credit')
      .leftJoinAndSelect('credit.customer', 'customer')
      .where('credit.teamId = :teamId', { teamId })
      .andWhere('installment.status IN (:...statuses)', {
        statuses: [InstallmentStatus.PENDING, InstallmentStatus.PARTIAL],
      })
      .andWhere('installment.dueDate >= :oneDayAgo', {
        oneDayAgo: oneDayAgoStr,
      })
      .andWhere('installment.dueDate <= :threeDaysAhead', {
        threeDaysAhead: threeDaysStr,
      })
      .getMany();

    let created = 0;

    for (const installment of installments) {
      const credit = installment.creditAccount;
      let reminderType: ReminderType;

      if (installment.dueDate === oneDayAgoStr) {
        reminderType = ReminderType.AFTER_DUE;
      } else if (installment.dueDate === todayStr) {
        reminderType = ReminderType.ON_DUE;
      } else {
        reminderType = ReminderType.BEFORE_DUE;
      }

      // Check if reminder already exists
      const existing = await this.remindersRepository.findOne({
        where: {
          installmentId: installment.id,
          type: reminderType,
          scheduledDate: todayStr,
        },
      });

      if (existing) continue;

      const remaining =
        Number(installment.amount) - Number(installment.paidAmount);
      const message = this.buildReminderMessage(
        reminderType,
        remaining,
        installment.dueDate,
      );

      const reminder = this.remindersRepository.create({
        teamId,
        installmentId: installment.id,
        customerId: credit.customerId,
        type: reminderType,
        channel: ReminderChannel.INTERNAL,
        scheduledDate: todayStr,
        message,
      });
      await this.remindersRepository.save(reminder);

      // Also create an internal notification
      const notification = this.notificationsRepository.create({
        teamId,
        type: NotificationType.PAYMENT_DUE,
        title: `Cuota ${reminderType === ReminderType.AFTER_DUE ? 'vencida' : 'próxima'}`,
        message,
        metadata: {
          installmentId: installment.id,
          creditAccountId: credit.id,
          customerId: credit.customerId,
          dueDate: installment.dueDate,
          amount: remaining,
        },
      });
      await this.notificationsRepository.save(notification);

      created++;
    }

    return created;
  }

  async findReminders(
    teamId: string,
    options?: { customerId?: string; status?: ReminderStatus },
  ): Promise<PaymentReminder[]> {
    const query = this.remindersRepository
      .createQueryBuilder('reminder')
      .leftJoinAndSelect('reminder.customer', 'customer')
      .leftJoinAndSelect('reminder.installment', 'installment')
      .where('reminder.teamId = :teamId', { teamId });

    if (options?.customerId) {
      query.andWhere('reminder.customerId = :customerId', {
        customerId: options.customerId,
      });
    }

    if (options?.status) {
      query.andWhere('reminder.status = :status', { status: options.status });
    }

    return query.orderBy('reminder.scheduledDate', 'DESC').getMany();
  }

  async getNotifications(
    teamId: string,
    options?: { userId?: string; unreadOnly?: boolean },
  ): Promise<Notification[]> {
    const query = this.notificationsRepository
      .createQueryBuilder('notification')
      .where('notification.teamId = :teamId', { teamId });

    if (options?.userId) {
      query.andWhere(
        '(notification.userId = :userId OR notification.userId IS NULL)',
        { userId: options.userId },
      );
    }

    if (options?.unreadOnly) {
      query.andWhere('notification.isRead = false');
    }

    return query.orderBy('notification.createdAt', 'DESC').limit(50).getMany();
  }

  async markAsRead(teamId: string, id: string): Promise<Notification> {
    const notification = await this.notificationsRepository.findOne({
      where: { id, teamId },
    });
    if (!notification) {
      throw new NotFoundException(`Notification #${id} not found`);
    }
    notification.isRead = true;
    return this.notificationsRepository.save(notification);
  }

  async markAllAsRead(teamId: string, userId: string): Promise<void> {
    await this.notificationsRepository
      .createQueryBuilder()
      .update(Notification)
      .set({ isRead: true })
      .where('teamId = :teamId', { teamId })
      .andWhere('(userId = :userId OR userId IS NULL)', { userId })
      .andWhere('isRead = false')
      .execute();
  }

  private buildReminderMessage(
    type: ReminderType,
    amount: number,
    dueDate: string,
  ): string {
    const formattedAmount = new Intl.NumberFormat('es-CO', {
      style: 'currency',
      currency: 'COP',
      minimumFractionDigits: 0,
    }).format(amount);

    switch (type) {
      case ReminderType.BEFORE_DUE:
        return `Su cuota de ${formattedAmount} vence el ${dueDate}. Por favor realice su pago a tiempo.`;
      case ReminderType.ON_DUE:
        return `Su cuota de ${formattedAmount} vence hoy (${dueDate}). Realice su pago para evitar recargos.`;
      case ReminderType.AFTER_DUE:
        return `Su cuota de ${formattedAmount} venció el ${dueDate}. Por favor póngase al día.`;
    }
  }
}
