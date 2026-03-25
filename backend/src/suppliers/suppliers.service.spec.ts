import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { SuppliersService } from './suppliers.service';
import { Supplier } from './entities/supplier.entity';

const TEAM_ID = 'team-uuid-1';

describe('SuppliersService', () => {
  let service: SuppliersService;

  const mockSupplier = {
    id: 'sup-uuid-1',
    teamId: TEAM_ID,
    name: 'Distribuidora ABC',
    nit: '900123456-1',
    contactName: 'Carlos',
    email: 'carlos@abc.com',
    phone: '3009876543',
    address: 'Cra 10 #20-30',
    isActive: true,
    notes: null,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const mockQueryBuilder = {
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    getMany: jest.fn().mockResolvedValue([mockSupplier]),
  };

  const mockRepository = {
    findOne: jest.fn(),
    create: jest.fn().mockReturnValue(mockSupplier),
    save: jest.fn().mockResolvedValue(mockSupplier),
    createQueryBuilder: jest.fn().mockReturnValue(mockQueryBuilder),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SuppliersService,
        { provide: getRepositoryToken(Supplier), useValue: mockRepository },
      ],
    }).compile();

    service = module.get<SuppliersService>(SuppliersService);
    jest.clearAllMocks();
    mockRepository.createQueryBuilder.mockReturnValue(mockQueryBuilder);
  });

  describe('create', () => {
    it('should create a supplier', async () => {
      mockRepository.findOne.mockResolvedValue(null);
      const result = await service.create(TEAM_ID, {
        name: 'Distribuidora ABC',
        nit: '900123456-1',
      });
      expect(result.name).toBe('Distribuidora ABC');
    });

    it('should throw ConflictException for duplicate NIT', async () => {
      mockRepository.findOne.mockResolvedValue(mockSupplier);
      await expect(
        service.create(TEAM_ID, {
          name: 'Otra',
          nit: '900123456-1',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('findAll', () => {
    it('should return suppliers for a team', async () => {
      const result = await service.findAll(TEAM_ID);
      expect(result).toHaveLength(1);
    });

    it('should filter by search', async () => {
      await service.findAll(TEAM_ID, { search: 'ABC' });
      expect(mockQueryBuilder.andWhere).toHaveBeenCalled();
    });
  });

  describe('findOne', () => {
    it('should return a supplier', async () => {
      mockRepository.findOne.mockResolvedValue(mockSupplier);
      const result = await service.findOne(TEAM_ID, 'sup-uuid-1');
      expect(result.name).toBe('Distribuidora ABC');
    });

    it('should throw NotFoundException', async () => {
      mockRepository.findOne.mockResolvedValue(null);
      await expect(service.findOne(TEAM_ID, 'uuid-999')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('update', () => {
    it('should update a supplier', async () => {
      mockRepository.findOne.mockResolvedValue({ ...mockSupplier });
      const result = await service.update(TEAM_ID, 'sup-uuid-1', {
        name: 'ABC Updated',
      });
      expect(result).toBeDefined();
    });
  });
});
