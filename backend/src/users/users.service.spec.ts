import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { Repository } from 'typeorm';
import { UsersService } from './users.service';
import { User, UserRole } from './entities/user.entity';

describe('UsersService', () => {
  let service: UsersService;
  let repository: Partial<Repository<User>>;

  const mockUser: User = {
    id: 'uuid-1',
    email: 'test@test.com',
    password: 'hashedpassword',
    firstName: 'John',
    lastName: 'Doe',
    role: UserRole.EMPLOYEE,
    isActive: true,
    createdAt: new Date(),
    updatedAt: new Date(),
    inventoryMovements: [],
  };

  beforeEach(async () => {
    repository = {
      findOne: jest.fn(),
      find: jest.fn().mockResolvedValue([mockUser]),
      create: jest.fn().mockReturnValue(mockUser),
      save: jest.fn().mockResolvedValue(mockUser),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: getRepositoryToken(User), useValue: repository },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
  });

  describe('create', () => {
    it('should create a user', async () => {
      (repository.findOne as jest.Mock).mockResolvedValue(null);

      const result = await service.create({
        email: 'test@test.com',
        password: 'password123',
        firstName: 'John',
        lastName: 'Doe',
      });

      expect(result).toEqual(mockUser);
      expect(repository.save).toHaveBeenCalled();
    });

    it('should throw ConflictException for duplicate email', async () => {
      (repository.findOne as jest.Mock).mockResolvedValue(mockUser);

      await expect(
        service.create({
          email: 'test@test.com',
          password: 'password123',
          firstName: 'John',
          lastName: 'Doe',
        }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('findAll', () => {
    it('should return all users', async () => {
      const result = await service.findAll();
      expect(result).toEqual([mockUser]);
    });
  });

  describe('findOne', () => {
    it('should return a user', async () => {
      (repository.findOne as jest.Mock).mockResolvedValue(mockUser);
      const result = await service.findOne('uuid-1');
      expect(result).toEqual(mockUser);
    });

    it('should throw NotFoundException', async () => {
      (repository.findOne as jest.Mock).mockResolvedValue(null);
      await expect(service.findOne('uuid-999')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('update', () => {
    it('should update a user', async () => {
      (repository.findOne as jest.Mock).mockResolvedValue(mockUser);
      const updated = { ...mockUser, firstName: 'Jane' };
      (repository.save as jest.Mock).mockResolvedValue(updated);

      const result = await service.update('uuid-1', { firstName: 'Jane' });
      expect(result.firstName).toBe('Jane');
    });
  });

  describe('remove', () => {
    it('should soft-delete a user', async () => {
      (repository.findOne as jest.Mock).mockResolvedValue({ ...mockUser });
      await service.remove('uuid-1');
      expect(repository.save).toHaveBeenCalledWith(
        expect.objectContaining({ isActive: false }),
      );
    });
  });
});
