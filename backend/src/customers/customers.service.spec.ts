import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { CustomersService } from './customers.service';
import { Customer } from './entities/customer.entity';

const TEAM_ID = 'team-uuid-1';

describe('CustomersService', () => {
  let service: CustomersService;

  const mockCustomer = {
    id: 'cust-uuid-1',
    teamId: TEAM_ID,
    name: 'Juan Pérez',
    email: 'juan@test.com',
    phone: '3001234567',
    documentType: 'CC',
    documentNumber: '123456789',
    address: 'Calle 1',
    notes: null,
    sales: [],
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const mockQueryBuilder = {
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    getMany: jest.fn().mockResolvedValue([mockCustomer]),
  };

  const mockRepository = {
    findOne: jest.fn(),
    create: jest.fn().mockReturnValue(mockCustomer),
    save: jest.fn().mockResolvedValue(mockCustomer),
    remove: jest.fn().mockResolvedValue(mockCustomer),
    createQueryBuilder: jest.fn().mockReturnValue(mockQueryBuilder),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CustomersService,
        { provide: getRepositoryToken(Customer), useValue: mockRepository },
      ],
    }).compile();

    service = module.get<CustomersService>(CustomersService);
    jest.clearAllMocks();
    mockRepository.createQueryBuilder.mockReturnValue(mockQueryBuilder);
  });

  describe('create', () => {
    it('should create a customer', async () => {
      mockRepository.findOne.mockResolvedValue(null);
      const result = await service.create(TEAM_ID, {
        name: 'Juan Pérez',
        documentNumber: '123456789',
      });
      expect(result.name).toBe('Juan Pérez');
    });

    it('should throw ConflictException for duplicate document', async () => {
      mockRepository.findOne.mockResolvedValue(mockCustomer);
      await expect(
        service.create(TEAM_ID, {
          name: 'Juan Pérez',
          documentNumber: '123456789',
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('should allow creating customer without document', async () => {
      const result = await service.create(TEAM_ID, {
        name: 'Cliente sin doc',
      });
      expect(result).toBeDefined();
    });
  });

  describe('findAll', () => {
    it('should return customers for a team', async () => {
      const result = await service.findAll(TEAM_ID);
      expect(result).toHaveLength(1);
    });

    it('should filter by search', async () => {
      await service.findAll(TEAM_ID, { search: 'Juan' });
      expect(mockQueryBuilder.andWhere).toHaveBeenCalled();
    });
  });

  describe('findOne', () => {
    it('should return a customer', async () => {
      mockRepository.findOne.mockResolvedValue(mockCustomer);
      const result = await service.findOne(TEAM_ID, 'cust-uuid-1');
      expect(result.name).toBe('Juan Pérez');
    });

    it('should throw NotFoundException', async () => {
      mockRepository.findOne.mockResolvedValue(null);
      await expect(service.findOne(TEAM_ID, 'uuid-999')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('remove', () => {
    it('should delete customer without sales', async () => {
      mockRepository.findOne.mockResolvedValue({
        ...mockCustomer,
        sales: [],
      });
      await service.remove(TEAM_ID, 'cust-uuid-1');
      expect(mockRepository.remove).toHaveBeenCalled();
    });

    it('should throw ConflictException when customer has sales', async () => {
      mockRepository.findOne.mockResolvedValue({
        ...mockCustomer,
        sales: [{ id: 'sale-1' }],
      });
      await expect(service.remove(TEAM_ID, 'cust-uuid-1')).rejects.toThrow(
        ConflictException,
      );
    });
  });
});
