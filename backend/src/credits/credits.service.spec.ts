import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { CreditsService } from './credits.service';
import {
  CreditAccount,
  CreditStatus,
  InterestType,
} from './entities/credit-account.entity';
import {
  CreditInstallment,
  InstallmentStatus,
} from './entities/credit-installment.entity';
import { Notification } from '../reminders/entities/notification.entity';

const TEAM_ID = 'team-uuid-1';

describe('CreditsService', () => {
  let service: CreditsService;
  let creditsRepo: any;
  let installmentsRepo: any;

  const mockInstallments = [
    {
      id: 'inst-1',
      creditAccountId: 'credit-uuid-1',
      installmentNumber: 1,
      amount: 500000,
      dueDate: '2026-04-25',
      paidAmount: 0,
      status: InstallmentStatus.PENDING,
    },
    {
      id: 'inst-2',
      creditAccountId: 'credit-uuid-1',
      installmentNumber: 2,
      amount: 500000,
      dueDate: '2026-05-25',
      paidAmount: 0,
      status: InstallmentStatus.PENDING,
    },
  ];

  const mockCredit = {
    id: 'credit-uuid-1',
    teamId: TEAM_ID,
    saleId: 'sale-uuid-1',
    customerId: 'cust-uuid-1',
    totalAmount: 1000000,
    paidAmount: 0,
    interestRate: 0,
    interestType: InterestType.NONE,
    installments: 2,
    startDate: '2026-03-25',
    status: CreditStatus.ACTIVE,
    creditInstallments: [...mockInstallments],
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const mockQueryBuilder = {
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    addOrderBy: jest.fn().mockReturnThis(),
    getMany: jest.fn().mockResolvedValue([mockCredit]),
  };

  beforeEach(async () => {
    creditsRepo = {
      findOne: jest.fn().mockResolvedValue(mockCredit),
      create: jest.fn().mockReturnValue(mockCredit),
      save: jest.fn().mockResolvedValue(mockCredit),
      createQueryBuilder: jest.fn().mockReturnValue(mockQueryBuilder),
    };

    installmentsRepo = {
      create: jest.fn().mockImplementation((data) => ({
        id: `inst-${data.installmentNumber}`,
        ...data,
      })),
      save: jest.fn().mockImplementation((data) => Promise.resolve(data)),
      createQueryBuilder: jest.fn().mockReturnValue(mockQueryBuilder),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CreditsService,
        {
          provide: getRepositoryToken(CreditAccount),
          useValue: creditsRepo,
        },
        {
          provide: getRepositoryToken(CreditInstallment),
          useValue: installmentsRepo,
        },
        {
          provide: getRepositoryToken(Notification),
          useValue: {
            create: jest.fn().mockReturnValue({}),
            save: jest.fn().mockResolvedValue({}),
          },
        },
      ],
    }).compile();

    service = module.get<CreditsService>(CreditsService);
    jest.clearAllMocks();
    creditsRepo.findOne.mockResolvedValue(mockCredit);
    creditsRepo.createQueryBuilder.mockReturnValue(mockQueryBuilder);
    installmentsRepo.createQueryBuilder.mockReturnValue(mockQueryBuilder);
  });

  describe('create', () => {
    it('should create a credit with installments', async () => {
      await service.create(TEAM_ID, {
        saleId: 'sale-uuid-1',
        customerId: 'cust-uuid-1',
        totalAmount: 1000000,
        installments: 2,
      });

      expect(creditsRepo.save).toHaveBeenCalled();
      expect(installmentsRepo.save).toHaveBeenCalledTimes(2);
    });

    it('should calculate fixed interest correctly', async () => {
      await service.create(TEAM_ID, {
        saleId: 'sale-uuid-1',
        customerId: 'cust-uuid-1',
        totalAmount: 1000000,
        interestRate: 10,
        interestType: InterestType.FIXED,
        installments: 2,
      });

      // Total with 10% fixed interest = 1,100,000
      // Each installment should be ~550,000
      const calls = installmentsRepo.create.mock.calls;
      const totalInstallments = calls[0][0].amount + calls[1][0].amount;
      expect(totalInstallments).toBeCloseTo(1100000, 0);
    });

    it('should calculate monthly interest correctly', async () => {
      await service.create(TEAM_ID, {
        saleId: 'sale-uuid-1',
        customerId: 'cust-uuid-1',
        totalAmount: 1000000,
        interestRate: 2,
        interestType: InterestType.MONTHLY,
        installments: 3,
      });

      // 1,000,000 * (1.02)^3 = ~1,061,208
      const calls = installmentsRepo.create.mock.calls;
      const totalInstallments =
        calls[0][0].amount + calls[1][0].amount + calls[2][0].amount;
      expect(totalInstallments).toBeCloseTo(1061208, -1);
    });
  });

  describe('findAll', () => {
    it('should return credits for a team', async () => {
      const result = await service.findAll(TEAM_ID);
      expect(result).toHaveLength(1);
    });

    it('should filter by customerId', async () => {
      await service.findAll(TEAM_ID, { customerId: 'cust-uuid-1' });
      expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith(
        'credit.customerId = :customerId',
        { customerId: 'cust-uuid-1' },
      );
    });
  });

  describe('findOne', () => {
    it('should return a credit', async () => {
      const result = await service.findOne(TEAM_ID, 'credit-uuid-1');
      expect(result.totalAmount).toBe(1000000);
    });

    it('should throw NotFoundException', async () => {
      creditsRepo.findOne.mockResolvedValue(null);
      await expect(service.findOne(TEAM_ID, 'uuid-999')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('payInstallment', () => {
    it('should pay an installment fully', async () => {
      const creditWithInstallments = {
        ...mockCredit,
        creditInstallments: [
          { ...mockInstallments[0] },
          { ...mockInstallments[1] },
        ],
      };
      creditsRepo.findOne.mockResolvedValue(creditWithInstallments);

      await service.payInstallment(TEAM_ID, 'credit-uuid-1', 'inst-1', {
        amount: 500000,
      });

      expect(installmentsRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({
          status: InstallmentStatus.PAID,
          paidAmount: 500000,
        }),
      );
    });

    it('should handle partial payment', async () => {
      const creditWithInstallments = {
        ...mockCredit,
        creditInstallments: [
          { ...mockInstallments[0] },
          { ...mockInstallments[1] },
        ],
      };
      creditsRepo.findOne.mockResolvedValue(creditWithInstallments);

      await service.payInstallment(TEAM_ID, 'credit-uuid-1', 'inst-1', {
        amount: 200000,
      });

      expect(installmentsRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({
          status: InstallmentStatus.PARTIAL,
          paidAmount: 200000,
        }),
      );
    });

    it('should mark credit as paid when all installments are paid', async () => {
      const creditWithInstallments = {
        ...mockCredit,
        paidAmount: 500000,
        creditInstallments: [
          {
            ...mockInstallments[0],
            status: InstallmentStatus.PAID,
            paidAmount: 500000,
          },
          { ...mockInstallments[1] },
        ],
      };
      creditsRepo.findOne.mockResolvedValue(creditWithInstallments);

      await service.payInstallment(TEAM_ID, 'credit-uuid-1', 'inst-2', {
        amount: 500000,
      });

      expect(creditsRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({ status: CreditStatus.PAID }),
      );
    });

    it('should throw BadRequestException for already paid credit', async () => {
      creditsRepo.findOne.mockResolvedValue({
        ...mockCredit,
        status: CreditStatus.PAID,
      });

      await expect(
        service.payInstallment(TEAM_ID, 'credit-uuid-1', 'inst-1', {
          amount: 100,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw NotFoundException for non-existent installment', async () => {
      await expect(
        service.payInstallment(TEAM_ID, 'credit-uuid-1', 'inst-999', {
          amount: 100,
        }),
      ).rejects.toThrow(NotFoundException);
    });
  });
});
