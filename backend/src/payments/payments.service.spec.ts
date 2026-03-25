import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { NotFoundException } from '@nestjs/common';
import { PaymentsService } from './payments.service';
import { Payment, PaymentMethodType } from './entities/payment.entity';

const TEAM_ID = 'team-uuid-1';
const USER_ID = 'user-uuid-1';

describe('PaymentsService', () => {
  let service: PaymentsService;

  const mockPayment = {
    id: 'pay-uuid-1',
    teamId: TEAM_ID,
    saleId: 'sale-uuid-1',
    amount: 50000,
    method: PaymentMethodType.CASH,
    reference: null,
    notes: null,
    receivedBy: USER_ID,
    paidAt: new Date(),
    createdAt: new Date(),
  };

  const mockQueryBuilder = {
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    getMany: jest.fn().mockResolvedValue([mockPayment]),
  };

  const mockRepository = {
    findOne: jest.fn(),
    create: jest.fn().mockReturnValue(mockPayment),
    save: jest.fn().mockResolvedValue(mockPayment),
    createQueryBuilder: jest.fn().mockReturnValue(mockQueryBuilder),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PaymentsService,
        { provide: getRepositoryToken(Payment), useValue: mockRepository },
      ],
    }).compile();

    service = module.get<PaymentsService>(PaymentsService);
    jest.clearAllMocks();
    mockRepository.createQueryBuilder.mockReturnValue(mockQueryBuilder);
  });

  describe('create', () => {
    it('should create a payment', async () => {
      const result = await service.create(TEAM_ID, USER_ID, {
        saleId: 'sale-uuid-1',
        amount: 50000,
      });
      expect(result.amount).toBe(50000);
      expect(mockRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          teamId: TEAM_ID,
          receivedBy: USER_ID,
        }),
      );
    });
  });

  describe('findAll', () => {
    it('should return payments for a team', async () => {
      const result = await service.findAll(TEAM_ID);
      expect(result).toHaveLength(1);
    });

    it('should filter by saleId', async () => {
      await service.findAll(TEAM_ID, { saleId: 'sale-uuid-1' });
      expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith(
        'payment.saleId = :saleId',
        { saleId: 'sale-uuid-1' },
      );
    });
  });

  describe('findOne', () => {
    it('should return a payment', async () => {
      mockRepository.findOne.mockResolvedValue(mockPayment);
      const result = await service.findOne(TEAM_ID, 'pay-uuid-1');
      expect(result.amount).toBe(50000);
    });

    it('should throw NotFoundException', async () => {
      mockRepository.findOne.mockResolvedValue(null);
      await expect(service.findOne(TEAM_ID, 'uuid-999')).rejects.toThrow(
        NotFoundException,
      );
    });
  });
});
