import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { LotsService } from './lots.service';
import { ProductLot, LotStatus } from './entities/product-lot.entity';

const TEAM_ID = 'team-uuid-1';

describe('LotsService', () => {
  let service: LotsService;

  const mockLot = {
    id: 'lot-uuid-1',
    teamId: TEAM_ID,
    productId: 'prod-uuid-1',
    lotNumber: 'LOT-001',
    quantity: 100,
    soldQuantity: 0,
    expirationDate: '2026-06-01',
    manufacturingDate: '2026-01-01',
    status: LotStatus.ACTIVE,
    notes: null,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const mockQueryBuilder = {
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    update: jest.fn().mockReturnThis(),
    set: jest.fn().mockReturnThis(),
    execute: jest.fn().mockResolvedValue({ affected: 2 }),
    getMany: jest.fn().mockResolvedValue([mockLot]),
  };

  const mockRepository = {
    findOne: jest.fn(),
    find: jest.fn(),
    create: jest.fn().mockReturnValue(mockLot),
    save: jest.fn().mockResolvedValue(mockLot),
    createQueryBuilder: jest.fn().mockReturnValue(mockQueryBuilder),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        LotsService,
        { provide: getRepositoryToken(ProductLot), useValue: mockRepository },
      ],
    }).compile();

    service = module.get<LotsService>(LotsService);
    jest.clearAllMocks();
    mockRepository.createQueryBuilder.mockReturnValue(mockQueryBuilder);
  });

  describe('create', () => {
    it('should create a lot', async () => {
      const result = await service.create(TEAM_ID, {
        productId: 'prod-uuid-1',
        lotNumber: 'LOT-001',
        quantity: 100,
        expirationDate: '2026-06-01',
      });
      expect(result.lotNumber).toBe('LOT-001');
    });
  });

  describe('findAll', () => {
    it('should return lots for a team', async () => {
      const result = await service.findAll(TEAM_ID);
      expect(result).toHaveLength(1);
    });

    it('should filter by productId', async () => {
      await service.findAll(TEAM_ID, { productId: 'prod-uuid-1' });
      expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith(
        'lot.productId = :productId',
        { productId: 'prod-uuid-1' },
      );
    });
  });

  describe('findOne', () => {
    it('should return a lot', async () => {
      mockRepository.findOne.mockResolvedValue(mockLot);
      const result = await service.findOne(TEAM_ID, 'lot-uuid-1');
      expect(result.lotNumber).toBe('LOT-001');
    });

    it('should throw NotFoundException', async () => {
      mockRepository.findOne.mockResolvedValue(null);
      await expect(service.findOne(TEAM_ID, 'uuid-999')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('deductFromLots (FEFO)', () => {
    it('should deduct from oldest expiring lot first', async () => {
      const lots = [
        {
          ...mockLot,
          id: 'lot-1',
          expirationDate: '2026-04-01',
          quantity: 50,
          soldQuantity: 0,
        },
        {
          ...mockLot,
          id: 'lot-2',
          expirationDate: '2026-06-01',
          quantity: 100,
          soldQuantity: 0,
        },
      ];
      mockRepository.find.mockResolvedValue(lots);
      mockRepository.save.mockImplementation((lot) => Promise.resolve(lot));

      const result = await service.deductFromLots(TEAM_ID, 'prod-uuid-1', 70);

      expect(result).toHaveLength(2);
      expect(result[0]).toEqual({ lotId: 'lot-1', deducted: 50 });
      expect(result[1]).toEqual({ lotId: 'lot-2', deducted: 20 });
      // First lot should be depleted
      expect(lots[0].status).toBe(LotStatus.DEPLETED);
    });

    it('should throw BadRequestException for insufficient lot stock', async () => {
      mockRepository.find.mockResolvedValue([
        { ...mockLot, quantity: 10, soldQuantity: 0 },
      ]);
      mockRepository.save.mockImplementation((lot) => Promise.resolve(lot));

      await expect(
        service.deductFromLots(TEAM_ID, 'prod-uuid-1', 50),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('markExpiredLots', () => {
    it('should return count of expired lots', async () => {
      const result = await service.markExpiredLots(TEAM_ID);
      expect(result).toBe(2);
    });
  });
});
