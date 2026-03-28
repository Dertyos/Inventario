import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { NotFoundException } from '@nestjs/common';
import { RemindersService } from './reminders.service';
import {
  PaymentReminder,
  ReminderStatus,
} from './entities/payment-reminder.entity';
import { Notification } from './entities/notification.entity';
import {
  CreditInstallment,
  InstallmentStatus,
} from '../credits/entities/credit-installment.entity';
import { TeamSettings } from '../teams/entities/team-settings.entity';

const TEAM_ID = 'team-uuid-1';

describe('RemindersService', () => {
  let service: RemindersService;

  const mockReminder = {
    id: 'rem-uuid-1',
    teamId: TEAM_ID,
    installmentId: 'inst-1',
    customerId: 'cust-uuid-1',
    type: 'before_due',
    channel: 'internal',
    status: ReminderStatus.PENDING,
    scheduledDate: '2026-03-25',
    message: 'Su cuota vence pronto',
    createdAt: new Date(),
  };

  const mockNotification = {
    id: 'notif-uuid-1',
    teamId: TEAM_ID,
    type: 'payment_due',
    title: 'Cuota próxima',
    message: 'test',
    isRead: false,
    createdAt: new Date(),
  };

  const reminderQueryBuilder = {
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    getMany: jest.fn().mockResolvedValue([mockReminder]),
  };

  const notificationQueryBuilder = {
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    update: jest.fn().mockReturnThis(),
    set: jest.fn().mockReturnThis(),
    execute: jest.fn().mockResolvedValue({ affected: 3 }),
    getMany: jest.fn().mockResolvedValue([mockNotification]),
  };

  const installmentQueryBuilder = {
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    getMany: jest.fn().mockResolvedValue([]),
  };

  const mockRemindersRepo = {
    findOne: jest.fn(),
    create: jest.fn().mockReturnValue(mockReminder),
    save: jest.fn().mockResolvedValue(mockReminder),
    createQueryBuilder: jest.fn().mockReturnValue(reminderQueryBuilder),
  };

  const mockNotificationsRepo = {
    findOne: jest.fn(),
    create: jest.fn().mockReturnValue(mockNotification),
    save: jest.fn().mockResolvedValue(mockNotification),
    createQueryBuilder: jest.fn().mockReturnValue(notificationQueryBuilder),
  };

  const mockInstallmentsRepo = {
    createQueryBuilder: jest.fn().mockReturnValue(installmentQueryBuilder),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RemindersService,
        {
          provide: getRepositoryToken(PaymentReminder),
          useValue: mockRemindersRepo,
        },
        {
          provide: getRepositoryToken(Notification),
          useValue: mockNotificationsRepo,
        },
        {
          provide: getRepositoryToken(CreditInstallment),
          useValue: mockInstallmentsRepo,
        },
        {
          provide: getRepositoryToken(TeamSettings),
          useValue: { findOne: jest.fn().mockResolvedValue({ enableReminders: true }) },
        },
      ],
    }).compile();

    service = module.get<RemindersService>(RemindersService);
    jest.clearAllMocks();
    mockRemindersRepo.createQueryBuilder.mockReturnValue(reminderQueryBuilder);
    mockNotificationsRepo.createQueryBuilder.mockReturnValue(
      notificationQueryBuilder,
    );
    mockInstallmentsRepo.createQueryBuilder.mockReturnValue(
      installmentQueryBuilder,
    );
  });

  describe('generateReminders', () => {
    it('should return 0 when no installments need reminders', async () => {
      const result = await service.generateReminders(TEAM_ID);
      expect(result).toBe(0);
    });

    it('should generate reminders for upcoming installments', async () => {
      const today = new Date();
      const dueDateStr = today.toISOString().split('T')[0];

      installmentQueryBuilder.getMany.mockResolvedValue([
        {
          id: 'inst-1',
          dueDate: dueDateStr,
          amount: 500000,
          paidAmount: 0,
          status: InstallmentStatus.PENDING,
          creditAccount: {
            id: 'credit-1',
            teamId: TEAM_ID,
            customerId: 'cust-1',
          },
        },
      ]);
      mockRemindersRepo.findOne.mockResolvedValue(null); // no existing reminder

      const result = await service.generateReminders(TEAM_ID);
      expect(result).toBe(1);
      expect(mockRemindersRepo.save).toHaveBeenCalled();
      expect(mockNotificationsRepo.save).toHaveBeenCalled();
    });
  });

  describe('findReminders', () => {
    it('should return reminders for a team', async () => {
      const result = await service.findReminders(TEAM_ID);
      expect(result).toHaveLength(1);
    });

    it('should filter by customerId', async () => {
      await service.findReminders(TEAM_ID, { customerId: 'cust-uuid-1' });
      expect(reminderQueryBuilder.andWhere).toHaveBeenCalledWith(
        'reminder.customerId = :customerId',
        { customerId: 'cust-uuid-1' },
      );
    });
  });

  describe('getNotifications', () => {
    it('should return notifications for a team', async () => {
      const result = await service.getNotifications(TEAM_ID);
      expect(result).toHaveLength(1);
    });

    it('should filter unread only', async () => {
      await service.getNotifications(TEAM_ID, { unreadOnly: true });
      expect(notificationQueryBuilder.andWhere).toHaveBeenCalledWith(
        'notification.isRead = false',
      );
    });
  });

  describe('markAsRead', () => {
    it('should mark a notification as read', async () => {
      mockNotificationsRepo.findOne.mockResolvedValue({
        ...mockNotification,
      });
      await service.markAsRead(TEAM_ID, 'notif-uuid-1');
      expect(mockNotificationsRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({ isRead: true }),
      );
    });

    it('should throw NotFoundException', async () => {
      mockNotificationsRepo.findOne.mockResolvedValue(null);
      await expect(service.markAsRead(TEAM_ID, 'uuid-999')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('markAllAsRead', () => {
    it('should mark all notifications as read', async () => {
      await service.markAllAsRead(TEAM_ID, 'user-uuid-1');
      expect(notificationQueryBuilder.execute).toHaveBeenCalled();
    });
  });
});
