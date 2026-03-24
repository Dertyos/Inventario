import { Test, TestingModule } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';
import { UsersService } from '../users/users.service';
import { UserRole } from '../users/entities/user.entity';
import * as bcrypt from 'bcrypt';

jest.mock('bcrypt');

describe('AuthService', () => {
  let service: AuthService;
  let usersService: Partial<UsersService>;
  let jwtService: Partial<JwtService>;

  const mockUser = {
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
    usersService = {
      create: jest.fn().mockResolvedValue(mockUser),
      findByEmail: jest.fn().mockResolvedValue(mockUser),
      findOne: jest.fn().mockResolvedValue(mockUser),
    };

    jwtService = {
      sign: jest.fn().mockReturnValue('mock-token'),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: UsersService, useValue: usersService },
        { provide: JwtService, useValue: jwtService },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
  });

  describe('register', () => {
    it('should register a new user and return token', async () => {
      const result = await service.register({
        email: 'test@test.com',
        password: 'password123',
        firstName: 'John',
        lastName: 'Doe',
      });

      expect(result.accessToken).toBe('mock-token');
      expect(result.user.email).toBe('test@test.com');
      expect(usersService.create).toHaveBeenCalled();
    });
  });

  describe('login', () => {
    it('should return token for valid credentials', async () => {
      (bcrypt.compare as jest.Mock).mockResolvedValue(true);

      const result = await service.login({
        email: 'test@test.com',
        password: 'password123',
      });

      expect(result.accessToken).toBe('mock-token');
      expect(result.user.email).toBe('test@test.com');
    });

    it('should throw UnauthorizedException for invalid email', async () => {
      (usersService.findByEmail as jest.Mock).mockResolvedValue(null);

      await expect(
        service.login({ email: 'wrong@test.com', password: 'password123' }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('should throw UnauthorizedException for invalid password', async () => {
      (bcrypt.compare as jest.Mock).mockResolvedValue(false);

      await expect(
        service.login({ email: 'test@test.com', password: 'wrong' }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('should throw UnauthorizedException for deactivated user', async () => {
      (bcrypt.compare as jest.Mock).mockResolvedValue(true);
      (usersService.findByEmail as jest.Mock).mockResolvedValue({
        ...mockUser,
        isActive: false,
      });

      await expect(
        service.login({ email: 'test@test.com', password: 'password123' }),
      ).rejects.toThrow(UnauthorizedException);
    });
  });

  describe('getProfile', () => {
    it('should return user profile', async () => {
      const result = await service.getProfile('uuid-1');

      expect(result.email).toBe('test@test.com');
      expect(result.firstName).toBe('John');
    });
  });
});
