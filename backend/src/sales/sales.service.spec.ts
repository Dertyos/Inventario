import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { SalesService } from './sales.service';
import { Sale, SaleStatus, PaymentMethod } from './entities/sale.entity';
import { CreditsService } from '../credits/credits.service';

const TEAM_ID = 'team-uuid-1';
const USER_ID = 'user-uuid-1';

describe('SalesService', () => {
  let service: SalesService;

  const mockProduct = {
    id: 'prod-uuid-1',
    teamId: TEAM_ID,
    name: 'Laptop',
    stock: 10,
    isActive: true,
  };

  const mockSale = {
    id: 'sale-uuid-1',
    teamId: TEAM_ID,
    saleNumber: 'V-0001',
    userId: USER_ID,
    customerId: null,
    subtotal: 999.99,
    tax: 0,
    total: 999.99,
    paymentMethod: PaymentMethod.CASH,
    status: SaleStatus.COMPLETED,
    items: [],
    payments: [],
    createdAt: new Date(),
    updatedAt: new Date(),
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
      update: jest.fn().mockResolvedValue({}),
    },
  };

  const mockQueryBuilder = {
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    getMany: jest.fn().mockResolvedValue([mockSale]),
  };

  const mockSalesRepo = {
    findOne: jest.fn(),
    createQueryBuilder: jest.fn().mockReturnValue(mockQueryBuilder),
  };

  const mockDataSource = {
    createQueryRunner: jest.fn().mockReturnValue(mockQueryRunner),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SalesService,
        { provide: getRepositoryToken(Sale), useValue: mockSalesRepo },
        { provide: DataSource, useValue: mockDataSource },
        {
          provide: CreditsService,
          useValue: { createFromSale: jest.fn().mockResolvedValue(undefined) },
        },
      ],
    }).compile();

    service = module.get<SalesService>(SalesService);
    jest.clearAllMocks();
    mockDataSource.createQueryRunner.mockReturnValue(mockQueryRunner);
    mockSalesRepo.createQueryBuilder.mockReturnValue(mockQueryBuilder);
    mockQueryRunner.manager.create.mockImplementation(
      (EntityClass, data) => data,
    );
    mockQueryRunner.manager.save.mockImplementation((entity) =>
      Promise.resolve({ id: 'new-uuid', ...entity }),
    );
  });

  describe('create', () => {
    it('should throw BadRequestException for empty items', async () => {
      await expect(
        service.create(TEAM_ID, USER_ID, {
          items: [],
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException for non-existent product', async () => {
      mockQueryRunner.manager.findOne.mockResolvedValueOnce(null); // saleNumber
      mockQueryRunner.manager.findOne.mockResolvedValueOnce(null); // product

      await expect(
        service.create(TEAM_ID, USER_ID, {
          items: [{ productId: 'uuid-999', quantity: 1, unitPrice: 100 }],
        }),
      ).rejects.toThrow(BadRequestException);
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });

    it('should throw BadRequestException for insufficient stock', async () => {
      mockQueryRunner.manager.findOne.mockResolvedValueOnce(null); // saleNumber
      mockQueryRunner.manager.findOne.mockResolvedValueOnce({
        ...mockProduct,
        stock: 2,
      }); // product

      await expect(
        service.create(TEAM_ID, USER_ID, {
          items: [{ productId: 'prod-uuid-1', quantity: 5, unitPrice: 100 }],
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should create sale, deduct stock and create movements', async () => {
      mockQueryRunner.manager.findOne
        .mockResolvedValueOnce(null) // last sale for number
        .mockResolvedValueOnce({ ...mockProduct }); // product

      mockSalesRepo.findOne.mockResolvedValue({
        ...mockSale,
        items: [
          {
            productId: 'prod-uuid-1',
            quantity: 2,
            unitPrice: 500,
            subtotal: 1000,
          },
        ],
      });

      await service.create(TEAM_ID, USER_ID, {
        items: [{ productId: 'prod-uuid-1', quantity: 2, unitPrice: 500 }],
      });

      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
      // Stock should be deducted
      expect(mockQueryRunner.manager.save).toHaveBeenCalledWith(
        expect.objectContaining({ stock: 8 }),
      );
    });

    it('should throw BadRequestException for inactive product', async () => {
      mockQueryRunner.manager.findOne
        .mockResolvedValueOnce(null) // sale number
        .mockResolvedValueOnce({ ...mockProduct, isActive: false }); // product

      await expect(
        service.create(TEAM_ID, USER_ID, {
          items: [{ productId: 'prod-uuid-1', quantity: 1, unitPrice: 100 }],
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('findAll', () => {
    it('should return sales for a team', async () => {
      const result = await service.findAll(TEAM_ID);
      expect(result).toHaveLength(1);
    });

    it('should filter by customerId', async () => {
      await service.findAll(TEAM_ID, { customerId: 'cust-uuid-1' });
      expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith(
        'sale.customerId = :customerId',
        { customerId: 'cust-uuid-1' },
      );
    });

    it('should filter by date range', async () => {
      await service.findAll(TEAM_ID, {
        startDate: '2026-01-01',
        endDate: '2026-12-31',
      });
      expect(mockQueryBuilder.andWhere).toHaveBeenCalledTimes(2);
    });
  });

  describe('findOne', () => {
    it('should return a sale', async () => {
      mockSalesRepo.findOne.mockResolvedValue(mockSale);
      const result = await service.findOne(TEAM_ID, 'sale-uuid-1');
      expect(result.saleNumber).toBe('V-0001');
    });

    it('should throw NotFoundException', async () => {
      mockSalesRepo.findOne.mockResolvedValue(null);
      await expect(service.findOne(TEAM_ID, 'uuid-999')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('cancel', () => {
    it('should cancel sale and restore stock', async () => {
      mockQueryRunner.manager.findOne
        .mockResolvedValueOnce({
          ...mockSale,
          items: [{ productId: 'prod-uuid-1', quantity: 2 }],
        }) // sale
        .mockResolvedValueOnce({ ...mockProduct, stock: 8 }); // product

      mockSalesRepo.findOne.mockResolvedValue({
        ...mockSale,
        status: SaleStatus.CANCELLED,
      });

      await service.cancel(TEAM_ID, 'sale-uuid-1', USER_ID);

      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
      // Stock restored
      expect(mockQueryRunner.manager.save).toHaveBeenCalledWith(
        expect.objectContaining({ stock: 10 }),
      );
    });

    it('should throw BadRequestException for already cancelled sale', async () => {
      mockQueryRunner.manager.findOne.mockResolvedValueOnce({
        ...mockSale,
        status: SaleStatus.CANCELLED,
      });

      await expect(
        service.cancel(TEAM_ID, 'sale-uuid-1', USER_ID),
      ).rejects.toThrow(BadRequestException);
    });
  });
});
