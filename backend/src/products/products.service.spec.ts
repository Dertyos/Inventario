import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { ProductsService } from './products.service';
import { Product } from './entities/product.entity';

describe('ProductsService', () => {
  let service: ProductsService;

  const mockProduct = {
    id: 'uuid-prod-1',
    sku: 'SKU-001',
    name: 'Laptop',
    description: 'A laptop',
    price: 999.99,
    cost: 700,
    stock: 10,
    minStock: 5,
    categoryId: 'uuid-cat-1',
    isActive: true,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const mockQueryBuilder = {
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    getMany: jest.fn().mockResolvedValue([mockProduct]),
  };

  const mockRepository = {
    findOne: jest.fn(),
    create: jest.fn().mockReturnValue(mockProduct),
    save: jest.fn().mockResolvedValue(mockProduct),
    createQueryBuilder: jest.fn().mockReturnValue(mockQueryBuilder),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ProductsService,
        { provide: getRepositoryToken(Product), useValue: mockRepository },
      ],
    }).compile();

    service = module.get<ProductsService>(ProductsService);
    jest.clearAllMocks();
    mockRepository.createQueryBuilder.mockReturnValue(mockQueryBuilder);
  });

  describe('create', () => {
    it('should create a product', async () => {
      mockRepository.findOne.mockResolvedValue(null);
      const result = await service.create({
        sku: 'SKU-001',
        name: 'Laptop',
        price: 999.99,
        categoryId: 'uuid-cat-1',
      });
      expect(result.sku).toBe('SKU-001');
    });

    it('should throw ConflictException for duplicate SKU', async () => {
      mockRepository.findOne.mockResolvedValue(mockProduct);
      await expect(
        service.create({
          sku: 'SKU-001',
          name: 'Laptop',
          price: 999.99,
          categoryId: 'uuid-cat-1',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('findAll', () => {
    it('should return products', async () => {
      const result = await service.findAll();
      expect(result).toHaveLength(1);
    });

    it('should filter by categoryId', async () => {
      await service.findAll({ categoryId: 'uuid-cat-1' });
      expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith(
        'product.categoryId = :categoryId',
        { categoryId: 'uuid-cat-1' },
      );
    });

    it('should filter by search term', async () => {
      await service.findAll({ search: 'laptop' });
      expect(mockQueryBuilder.andWhere).toHaveBeenCalledWith(
        '(product.name ILIKE :search OR product.sku ILIKE :search)',
        { search: '%laptop%' },
      );
    });
  });

  describe('findOne', () => {
    it('should return a product', async () => {
      mockRepository.findOne.mockResolvedValue(mockProduct);
      const result = await service.findOne('uuid-prod-1');
      expect(result.name).toBe('Laptop');
    });

    it('should throw NotFoundException', async () => {
      mockRepository.findOne.mockResolvedValue(null);
      await expect(service.findOne('uuid-999')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('findLowStock', () => {
    it('should return low stock products', async () => {
      const result = await service.findLowStock();
      expect(result).toHaveLength(1);
    });
  });
});
