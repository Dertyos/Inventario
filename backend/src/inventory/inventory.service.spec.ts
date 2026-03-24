import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { BadRequestException } from '@nestjs/common';
import { InventoryService } from './inventory.service';
import {
  InventoryMovement,
  MovementType,
} from './entities/inventory-movement.entity';
import { Product } from '../products/entities/product.entity';

describe('InventoryService', () => {
  let service: InventoryService;

  const mockProduct = {
    id: 'uuid-prod-1',
    stock: 10,
  };

  const mockMovement = {
    id: 'uuid-mov-1',
    type: MovementType.IN,
    quantity: 5,
    productId: 'uuid-prod-1',
    userId: 'uuid-user-1',
    stockBefore: 10,
    stockAfter: 15,
    createdAt: new Date(),
  };

  const mockQueryRunner = {
    connect: jest.fn(),
    startTransaction: jest.fn(),
    commitTransaction: jest.fn(),
    rollbackTransaction: jest.fn(),
    release: jest.fn(),
    manager: {
      findOne: jest.fn().mockResolvedValue({ ...mockProduct }),
      save: jest.fn().mockImplementation((entity) => Promise.resolve(entity)),
      create: jest.fn().mockReturnValue(mockMovement),
    },
  };

  const mockQueryBuilder = {
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    getMany: jest.fn().mockResolvedValue([mockMovement]),
  };

  const mockMovementsRepo = {
    findOne: jest.fn(),
    createQueryBuilder: jest.fn().mockReturnValue(mockQueryBuilder),
  };

  const mockProductsRepo = {};

  const mockDataSource = {
    createQueryRunner: jest.fn().mockReturnValue(mockQueryRunner),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        InventoryService,
        {
          provide: getRepositoryToken(InventoryMovement),
          useValue: mockMovementsRepo,
        },
        { provide: getRepositoryToken(Product), useValue: mockProductsRepo },
        { provide: DataSource, useValue: mockDataSource },
      ],
    }).compile();

    service = module.get<InventoryService>(InventoryService);
    jest.clearAllMocks();
    mockDataSource.createQueryRunner.mockReturnValue(mockQueryRunner);
    mockQueryRunner.manager.findOne.mockResolvedValue({ ...mockProduct });
    mockQueryRunner.manager.create.mockReturnValue(mockMovement);
    mockMovementsRepo.createQueryBuilder.mockReturnValue(mockQueryBuilder);
  });

  describe('createMovement', () => {
    it('should create an IN movement and increase stock', async () => {
      await service.createMovement(
        { type: MovementType.IN, quantity: 5, productId: 'uuid-prod-1' },
        'uuid-user-1',
      );

      expect(mockQueryRunner.commitTransaction).toHaveBeenCalled();
      expect(mockQueryRunner.manager.save).toHaveBeenCalledWith(
        expect.objectContaining({ stock: 15 }),
      );
    });

    it('should create an OUT movement and decrease stock', async () => {
      await service.createMovement(
        { type: MovementType.OUT, quantity: 3, productId: 'uuid-prod-1' },
        'uuid-user-1',
      );

      expect(mockQueryRunner.manager.save).toHaveBeenCalledWith(
        expect.objectContaining({ stock: 7 }),
      );
    });

    it('should throw BadRequestException for insufficient stock', async () => {
      await expect(
        service.createMovement(
          { type: MovementType.OUT, quantity: 20, productId: 'uuid-prod-1' },
          'uuid-user-1',
        ),
      ).rejects.toThrow(BadRequestException);
      expect(mockQueryRunner.rollbackTransaction).toHaveBeenCalled();
    });

    it('should create an ADJUSTMENT movement setting exact stock', async () => {
      await service.createMovement(
        {
          type: MovementType.ADJUSTMENT,
          quantity: 50,
          productId: 'uuid-prod-1',
        },
        'uuid-user-1',
      );

      expect(mockQueryRunner.manager.save).toHaveBeenCalledWith(
        expect.objectContaining({ stock: 50 }),
      );
    });

    it('should throw BadRequestException for non-existent product', async () => {
      mockQueryRunner.manager.findOne.mockResolvedValue(null);

      await expect(
        service.createMovement(
          { type: MovementType.IN, quantity: 5, productId: 'uuid-999' },
          'uuid-user-1',
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('findAll', () => {
    it('should return movements', async () => {
      const result = await service.findAll();
      expect(result).toHaveLength(1);
    });

    it('should filter by productId', async () => {
      await service.findAll({ productId: 'uuid-prod-1' });
      expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith(
        'movement.productId = :productId',
        { productId: 'uuid-prod-1' },
      );
    });
  });
});
