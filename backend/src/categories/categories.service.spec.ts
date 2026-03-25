import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { Repository } from 'typeorm';
import { CategoriesService } from './categories.service';
import { Category } from './entities/category.entity';

const TEAM_ID = 'team-uuid-1';

describe('CategoriesService', () => {
  let service: CategoriesService;
  let repository: Partial<Repository<Category>>;

  const mockCategory = {
    id: 'uuid-cat-1',
    teamId: TEAM_ID,
    team: null,
    name: 'Electronics',
    description: 'Electronic devices',
    color: null,
    products: [],
    createdAt: new Date(),
    updatedAt: new Date(),
  } as Category;

  beforeEach(async () => {
    repository = {
      findOne: jest.fn(),
      find: jest.fn().mockResolvedValue([mockCategory]),
      create: jest.fn().mockReturnValue(mockCategory),
      save: jest.fn().mockResolvedValue(mockCategory),
      remove: jest.fn().mockResolvedValue(mockCategory),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CategoriesService,
        { provide: getRepositoryToken(Category), useValue: repository },
      ],
    }).compile();

    service = module.get<CategoriesService>(CategoriesService);
  });

  describe('create', () => {
    it('should create a category', async () => {
      (repository.findOne as jest.Mock).mockResolvedValue(null);
      const result = await service.create(TEAM_ID, {
        name: 'Electronics',
        description: 'Electronic devices',
      });
      expect(result.name).toBe('Electronics');
    });

    it('should throw ConflictException for duplicate name', async () => {
      (repository.findOne as jest.Mock).mockResolvedValue(mockCategory);
      await expect(
        service.create(TEAM_ID, { name: 'Electronics' }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('findAll', () => {
    it('should return all categories for a team', async () => {
      const result = await service.findAll(TEAM_ID);
      expect(result).toHaveLength(1);
    });
  });

  describe('findOne', () => {
    it('should return a category', async () => {
      (repository.findOne as jest.Mock).mockResolvedValue(mockCategory);
      const result = await service.findOne(TEAM_ID, 'uuid-cat-1');
      expect(result.name).toBe('Electronics');
    });

    it('should throw NotFoundException', async () => {
      (repository.findOne as jest.Mock).mockResolvedValue(null);
      await expect(service.findOne(TEAM_ID, 'uuid-999')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('remove', () => {
    it('should delete a category without products', async () => {
      (repository.findOne as jest.Mock).mockResolvedValue({
        ...mockCategory,
        products: [],
      });
      await service.remove(TEAM_ID, 'uuid-cat-1');
      expect(repository.remove).toHaveBeenCalled();
    });

    it('should throw ConflictException when category has products', async () => {
      (repository.findOne as jest.Mock).mockResolvedValue({
        ...mockCategory,
        products: [{ id: 'prod-1' }],
      });
      await expect(service.remove(TEAM_ID, 'uuid-cat-1')).rejects.toThrow(
        ConflictException,
      );
    });
  });
});
