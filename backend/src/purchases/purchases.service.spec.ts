import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { PurchasesService } from './purchases.service';
import { Purchase, PurchaseStatus } from './entities/purchase.entity';

const TEAM_ID = 'team-uuid-1';
const USER_ID = 'user-uuid-1';

describe('PurchasesService', () => {
  let service: PurchasesService;

  const mockPurchase = {
    id: 'purch-uuid-1',
    teamId: TEAM_ID,
    purchaseNumber: 'C-0001',
    supplierId: 'sup-uuid-1',
    userId: USER_ID,
    total: 500000,
    status: PurchaseStatus.PENDING,
    items: [],
    notes: null,
    receivedAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const mockProduct = {
    id: 'prod-uuid-1',
    stock: 10,
    cost: 100,
  };

  const mockQueryRunner = {
    connect: jest.fn(),
    startTransaction: jest.fn(),
    commitTransaction: jest.fn(),
    rollbackTransaction: jest.fn(),
    release: jest.fn(),
    manager: {
      findOne: jest.fn(),
      save: jest
        .fn()
        .mockImplementation((entity) =>
          Promise.resolve({ id: 'new-uuid', ...entity }),
        ),
      create: jest.fn().mockImplementation((EntityClass, data) => data),
    },
  };

  const mockQueryBuilder = {
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    getMany: jest.fn().mockResolvedValue([mockPurchase]),
  };

  const mockPurchasesRepo = {
    findOne: jest.fn(),
    create: jest.fn().mockReturnValue(mockPurchase),
    save: jest.fn().mockResolvedValue(mockPurchase),
    createQueryBuilder: jest.fn().mockReturnValue(mockQueryBuilder),
  };

  const mockItemsRepo = {
    create: jest.fn().mockImplementation((data) => data),
    save: jest.fn().mockImplementation((data) => Promise.resolve(data)),
  };

  const mockDataSource = {
    createQueryRunner: jest.fn().mockReturnValue(mockQueryRunner),
    getRepository: jest.fn().mockReturnValue(mockItemsRepo),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PurchasesService,
        { provide: getRepositoryToken(Purchase), useValue: mockPurchasesRepo },
        { provide: DataSource, useValue: mockDataSource },
      ],
    }).compile();

    service = module.get<PurchasesService>(PurchasesService);
    jest.clearAllMocks();
    mockPurchasesRepo.createQueryBuilder.mockReturnValue(mockQueryBuilder);
    mockDataSource.createQueryRunner.mockReturnValue(mockQueryRunner);
    mockDataSource.getRepository.mockReturnValue(mockItemsRepo);
  });

  describe('create', () => {
    it('should throw BadRequestException for empty items', async () => {
      await expect(
        service.create(TEAM_ID, USER_ID, {
          supplierId: 'sup-uuid-1',
          items: [],
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should create a purchase order', async () => {
      mockPurchasesRepo.findOne
        .mockResolvedValueOnce(null) // generatePurchaseNumber
        .mockResolvedValueOnce({
          ...mockPurchase,
          items: [
            {
              productId: 'prod-uuid-1',
              quantity: 50,
              unitCost: 10000,
              subtotal: 500000,
            },
          ],
        });

      const result = await service.create(TEAM_ID, USER_ID, {
        supplierId: 'sup-uuid-1',
        items: [{ productId: 'prod-uuid-1', quantity: 50, unitCost: 10000 }],
      });

      expect(mockPurchasesRepo.save).toHaveBeenCalled();
      expect(result.purchaseNumber).toBe('C-0001');
    });
  });

  describe('findAll', () => {
    it('should return purchases for a team', async () => {
      const result = await service.findAll(TEAM_ID);
      expect(result).toHaveLength(1);
    });

    it('should filter by supplierId', async () => {
      await service.findAll(TEAM_ID, { supplierId: 'sup-uuid-1' });
      expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith(
        'purchase.supplierId = :supplierId',
        { supplierId: 'sup-uuid-1' },
      );
    });
  });

  describe('findOne', () => {
    it('should return a purchase', async () => {
      mockPurchasesRepo.findOne.mockResolvedValue(mockPurchase);
      const result = await service.findOne(TEAM_ID, 'purch-uuid-1');
      expect(result.purchaseNumber).toBe('C-0001');
    });

    it('should throw NotFoundException', async () => {
      mockPurchasesRepo.findOne.mockResolvedValue(null);
      await expect(service.findOne(TEAM_ID, 'uuid-999')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('receive', () => {
    it('should receive a purchase, add stock and update cost', async () => {
      mockQueryRunner.manager.findOne
        .mockResolvedValueOnce({
          ...mockPurchase,
          items: [{ productId: 'prod-uuid-1', quantity: 50, unitCost: 200 }],
        }) // purchase
        .mockResolvedValueOnce({ ...mockProduct }); // product

      mockPurchasesRepo.findOne.mockResolvedValue({
        ...mockPurchase,
        status: PurchaseStatus.RECEIVED,
      });

      const result = await service.receive(TEAM_ID, 'purch-uuid-1', USER_ID);

      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
      expect(mockQueryRunner.manager.save).toHaveBeenCalledWith(
        expect.objectContaining({ stock: 60, cost: 200 }),
      );
      expect(result.status).toBe(PurchaseStatus.RECEIVED);
    });

    it('should throw BadRequestException for already received purchase', async () => {
      mockQueryRunner.manager.findOne.mockResolvedValueOnce({
        ...mockPurchase,
        status: PurchaseStatus.RECEIVED,
      });

      await expect(
        service.receive(TEAM_ID, 'purch-uuid-1', USER_ID),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('cancel', () => {
    it('should cancel a pending purchase', async () => {
      mockPurchasesRepo.findOne.mockResolvedValue({ ...mockPurchase });
      mockPurchasesRepo.save.mockResolvedValue({
        ...mockPurchase,
        status: PurchaseStatus.CANCELLED,
      });

      const result = await service.cancel(TEAM_ID, 'purch-uuid-1');
      expect(result.status).toBe(PurchaseStatus.CANCELLED);
    });

    it('should throw BadRequestException for non-pending purchase', async () => {
      mockPurchasesRepo.findOne.mockResolvedValue({
        ...mockPurchase,
        status: PurchaseStatus.RECEIVED,
      });

      await expect(service.cancel(TEAM_ID, 'purch-uuid-1')).rejects.toThrow(
        BadRequestException,
      );
    });
  });
});
