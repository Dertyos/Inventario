import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import {
  ConflictException,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { TeamsService } from './teams.service';
import { Team } from './entities/team.entity';
import { TeamMember, TeamRole } from './entities/team-member.entity';
import { TeamSettings } from './entities/team-settings.entity';
import { UsersService } from '../users/users.service';

describe('TeamsService', () => {
  let service: TeamsService;
  let teamsRepo: any;
  let membersRepo: any;
  let settingsRepo: any;
  let usersService: any;

  const mockTeam = {
    id: 'team-uuid-1',
    name: 'Mi Tienda',
    slug: 'mi-tienda',
    currency: 'COP',
    timezone: 'America/Bogota',
    isActive: true,
    members: [],
    settings: { enableLots: false, enableCredit: false },
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const mockMember = {
    id: 'member-uuid-1',
    userId: 'user-uuid-1',
    teamId: 'team-uuid-1',
    role: TeamRole.OWNER,
    isActive: true,
    joinedAt: new Date(),
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const mockSettings = {
    id: 'settings-uuid-1',
    teamId: 'team-uuid-1',
    enableLots: false,
    enableCredit: false,
    enableSuppliers: false,
    enableReminders: false,
    enableTax: false,
    enableBarcode: false,
    defaultTaxRate: 19.0,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const mockUser = {
    id: 'user-uuid-1',
    email: 'test@test.com',
    firstName: 'John',
    lastName: 'Doe',
  };

  beforeEach(async () => {
    teamsRepo = {
      findOne: jest.fn(),
      create: jest.fn().mockReturnValue(mockTeam),
      save: jest.fn().mockResolvedValue(mockTeam),
    };

    membersRepo = {
      findOne: jest.fn(),
      find: jest.fn().mockResolvedValue([{ ...mockMember, team: mockTeam }]),
      create: jest.fn().mockReturnValue(mockMember),
      save: jest.fn().mockResolvedValue(mockMember),
    };

    settingsRepo = {
      findOne: jest.fn().mockResolvedValue(mockSettings),
      create: jest.fn().mockReturnValue(mockSettings),
      save: jest.fn().mockResolvedValue(mockSettings),
    };

    usersService = {
      findByEmail: jest.fn().mockResolvedValue(mockUser),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TeamsService,
        { provide: getRepositoryToken(Team), useValue: teamsRepo },
        { provide: getRepositoryToken(TeamMember), useValue: membersRepo },
        { provide: getRepositoryToken(TeamSettings), useValue: settingsRepo },
        { provide: UsersService, useValue: usersService },
      ],
    }).compile();

    service = module.get<TeamsService>(TeamsService);
  });

  describe('create', () => {
    it('should create a team with owner and settings', async () => {
      teamsRepo.findOne.mockResolvedValueOnce(null); // slug check
      teamsRepo.findOne.mockResolvedValueOnce({
        ...mockTeam,
        members: [mockMember],
        settings: mockSettings,
      }); // findOne after create

      await service.create({ name: 'Mi Tienda' }, 'user-uuid-1');

      expect(teamsRepo.save).toHaveBeenCalled();
      expect(settingsRepo.save).toHaveBeenCalled();
      expect(membersRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({ role: TeamRole.OWNER }),
      );
    });

    it('should throw ConflictException for duplicate slug', async () => {
      teamsRepo.findOne.mockResolvedValue(mockTeam);

      await expect(
        service.create({ name: 'Mi Tienda' }, 'user-uuid-1'),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('findByUser', () => {
    it('should return teams for a user', async () => {
      const result = await service.findByUser('user-uuid-1');
      expect(result).toHaveLength(1);
    });
  });

  describe('addMember', () => {
    it('should add a new member', async () => {
      membersRepo.findOne.mockResolvedValue(null);
      const staffMember = { ...mockMember, role: TeamRole.STAFF };
      membersRepo.create.mockReturnValue(staffMember);

      await service.addMember('team-uuid-1', {
        email: 'new@test.com',
        role: TeamRole.STAFF,
      });

      expect(membersRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({ role: TeamRole.STAFF }),
      );
      expect(membersRepo.save).toHaveBeenCalled();
    });

    it('should throw NotFoundException for non-existent user', async () => {
      usersService.findByEmail.mockResolvedValue(null);

      await expect(
        service.addMember('team-uuid-1', { email: 'nope@test.com' }),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw ConflictException for existing active member', async () => {
      membersRepo.findOne.mockResolvedValue({
        ...mockMember,
        isActive: true,
      });

      await expect(
        service.addMember('team-uuid-1', { email: 'test@test.com' }),
      ).rejects.toThrow(ConflictException);
    });

    it('should re-activate an inactive member', async () => {
      membersRepo.findOne.mockResolvedValue({
        ...mockMember,
        isActive: false,
      });

      await service.addMember('team-uuid-1', {
        email: 'test@test.com',
        role: TeamRole.MANAGER,
      });

      expect(membersRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({ isActive: true, role: TeamRole.MANAGER }),
      );
    });
  });

  describe('removeMember', () => {
    it('should soft-remove a member', async () => {
      membersRepo.findOne.mockResolvedValue({
        ...mockMember,
        role: TeamRole.STAFF,
      });

      await service.removeMember('team-uuid-1', 'member-uuid-1');
      expect(membersRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({ isActive: false }),
      );
    });

    it('should throw ForbiddenException when removing owner', async () => {
      membersRepo.findOne.mockResolvedValue(mockMember);

      await expect(
        service.removeMember('team-uuid-1', 'member-uuid-1'),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('updateSettings', () => {
    it('should update team settings', async () => {
      const updated = { ...mockSettings, enableCredit: true };
      settingsRepo.save.mockResolvedValue(updated);

      const result = await service.updateSettings('team-uuid-1', {
        enableCredit: true,
      });

      expect(result.enableCredit).toBe(true);
    });
  });

  describe('getMemberByUserAndTeam', () => {
    it('should return member if exists', async () => {
      membersRepo.findOne.mockResolvedValue(mockMember);

      const result = await service.getMemberByUserAndTeam(
        'user-uuid-1',
        'team-uuid-1',
      );
      expect(result).toEqual(mockMember);
    });

    it('should return null if not a member', async () => {
      membersRepo.findOne.mockResolvedValue(null);

      const result = await service.getMemberByUserAndTeam(
        'user-uuid-2',
        'team-uuid-1',
      );
      expect(result).toBeNull();
    });
  });
});
