import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ForbiddenException, BadRequestException } from '@nestjs/common';
import { TeamsService } from './teams.service';
import { Team } from './entities/team.entity';
import { TeamMember, TeamRole } from './entities/team-member.entity';
import { TeamSettings } from './entities/team-settings.entity';
import { TeamInvite } from './entities/team-invite.entity';
import { RolePermissions } from './entities/role-permissions.entity';
import { UsersService } from '../users/users.service';
import { EmailService } from '../email/email.service';
import {
  DEFAULT_PERMISSIONS,
  ALL_PERMISSIONS,
  Permission,
} from './permissions.constants';

const TEAM_ID = 'team-uuid-1';

describe('TeamsService - Permissions', () => {
  let service: TeamsService;

  const mockRolePermissionsRepo = {
    findOne: jest.fn(),
    create: jest.fn(),
    save: jest.fn(),
    find: jest.fn(),
  };

  const mockTeamsRepo = {
    findOne: jest.fn(),
    create: jest.fn(),
    save: jest.fn(),
  };

  const mockMembersRepo = {
    findOne: jest.fn(),
    find: jest.fn(),
    create: jest.fn(),
    save: jest.fn(),
  };

  const mockSettingsRepo = {
    findOne: jest.fn(),
    create: jest.fn(),
    save: jest.fn(),
  };

  const mockInvitesRepo = {
    findOne: jest.fn(),
    find: jest.fn(),
    create: jest.fn(),
    save: jest.fn(),
  };

  const mockUsersService = {
    findByEmail: jest.fn(),
    findOne: jest.fn(),
  };

  const mockEmailService = {
    sendTeamInvitation: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TeamsService,
        { provide: getRepositoryToken(Team), useValue: mockTeamsRepo },
        { provide: getRepositoryToken(TeamMember), useValue: mockMembersRepo },
        { provide: getRepositoryToken(TeamSettings), useValue: mockSettingsRepo },
        { provide: getRepositoryToken(TeamInvite), useValue: mockInvitesRepo },
        { provide: getRepositoryToken(RolePermissions), useValue: mockRolePermissionsRepo },
        { provide: UsersService, useValue: mockUsersService },
        { provide: EmailService, useValue: mockEmailService },
      ],
    }).compile();

    service = module.get<TeamsService>(TeamsService);
    jest.clearAllMocks();
  });

  describe('getRolePermissions', () => {
    it('should return ALL_PERMISSIONS for owner', async () => {
      const result = await service.getRolePermissions(TEAM_ID, TeamRole.OWNER);

      expect(result).toEqual(ALL_PERMISSIONS);
      // Should not query the database for owner
      expect(mockRolePermissionsRepo.findOne).not.toHaveBeenCalled();
    });

    it('should return ALL_PERMISSIONS for admin', async () => {
      const result = await service.getRolePermissions(TEAM_ID, TeamRole.ADMIN);

      expect(result).toEqual(ALL_PERMISSIONS);
      expect(mockRolePermissionsRepo.findOne).not.toHaveBeenCalled();
    });

    it('should return default permissions for manager when no custom exist', async () => {
      mockRolePermissionsRepo.findOne.mockResolvedValue(null);

      const result = await service.getRolePermissions(TEAM_ID, TeamRole.MANAGER);

      expect(result).toEqual(DEFAULT_PERMISSIONS[TeamRole.MANAGER]);
      expect(result).toContain(Permission.SALES_CREATE);
      expect(result).toContain(Permission.REPORTS_VIEW);
    });

    it('should return default permissions for staff when no custom exist', async () => {
      mockRolePermissionsRepo.findOne.mockResolvedValue(null);

      const result = await service.getRolePermissions(TEAM_ID, TeamRole.STAFF);

      expect(result).toEqual(DEFAULT_PERMISSIONS[TeamRole.STAFF]);
      expect(result).toContain(Permission.SALES_CREATE);
      expect(result).toContain(Permission.INVENTORY_VIEW);
      expect(result).not.toContain(Permission.REPORTS_VIEW);
    });

    it('should return custom permissions when they exist in database', async () => {
      const customPermissions = [
        Permission.SALES_CREATE,
        Permission.INVENTORY_VIEW,
        Permission.REPORTS_VIEW,
      ];
      mockRolePermissionsRepo.findOne.mockResolvedValue({
        id: 'rp-uuid-1',
        teamId: TEAM_ID,
        role: TeamRole.STAFF,
        permissions: customPermissions,
      });

      const result = await service.getRolePermissions(TEAM_ID, TeamRole.STAFF);

      expect(result).toEqual(customPermissions);
      expect(mockRolePermissionsRepo.findOne).toHaveBeenCalledWith({
        where: { teamId: TEAM_ID, role: TeamRole.STAFF },
      });
    });
  });

  describe('updateRolePermissions', () => {
    it('should throw ForbiddenException for owner role', async () => {
      await expect(
        service.updateRolePermissions(TEAM_ID, TeamRole.OWNER, [Permission.SALES_CREATE]),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should throw ForbiddenException for admin role', async () => {
      await expect(
        service.updateRolePermissions(TEAM_ID, TeamRole.ADMIN, [Permission.SALES_CREATE]),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should throw BadRequestException for invalid permissions', async () => {
      await expect(
        service.updateRolePermissions(TEAM_ID, TeamRole.STAFF, ['invalid.permission']),
      ).rejects.toThrow(BadRequestException);
    });

    it('should create new entry when none exists', async () => {
      const newPermissions = [Permission.SALES_CREATE, Permission.INVENTORY_VIEW];
      mockRolePermissionsRepo.findOne.mockResolvedValue(null);
      const createdEntry = {
        teamId: TEAM_ID,
        role: TeamRole.STAFF,
        permissions: newPermissions,
      };
      mockRolePermissionsRepo.create.mockReturnValue(createdEntry);
      mockRolePermissionsRepo.save.mockResolvedValue({ id: 'rp-uuid-new', ...createdEntry });

      const result = await service.updateRolePermissions(TEAM_ID, TeamRole.STAFF, newPermissions);

      expect(mockRolePermissionsRepo.create).toHaveBeenCalledWith({
        teamId: TEAM_ID,
        role: TeamRole.STAFF,
        permissions: newPermissions,
      });
      expect(mockRolePermissionsRepo.save).toHaveBeenCalled();
      expect(result.permissions).toEqual(newPermissions);
    });

    it('should update existing entry when one exists', async () => {
      const existingEntry = {
        id: 'rp-uuid-1',
        teamId: TEAM_ID,
        role: TeamRole.MANAGER,
        permissions: [Permission.SALES_CREATE],
      };
      mockRolePermissionsRepo.findOne.mockResolvedValue(existingEntry);

      const updatedPermissions = [Permission.SALES_CREATE, Permission.REPORTS_VIEW];
      mockRolePermissionsRepo.save.mockResolvedValue({
        ...existingEntry,
        permissions: updatedPermissions,
      });

      const result = await service.updateRolePermissions(
        TEAM_ID,
        TeamRole.MANAGER,
        updatedPermissions,
      );

      // Should NOT call create, should update existing
      expect(mockRolePermissionsRepo.create).not.toHaveBeenCalled();
      expect(mockRolePermissionsRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({ permissions: updatedPermissions }),
      );
      expect(result.permissions).toEqual(updatedPermissions);
    });
  });

  describe('hasPermission', () => {
    it('should return true for owner regardless of permission', async () => {
      const result = await service.hasPermission(TEAM_ID, TeamRole.OWNER, Permission.ADMIN_TEAM_SETTINGS);

      expect(result).toBe(true);
    });

    it('should return true for admin regardless of permission', async () => {
      const result = await service.hasPermission(TEAM_ID, TeamRole.ADMIN, Permission.ADMIN_AUDIT);

      expect(result).toBe(true);
    });

    it('should return true for manager with a default permission', async () => {
      mockRolePermissionsRepo.findOne.mockResolvedValue(null);

      const result = await service.hasPermission(TEAM_ID, TeamRole.MANAGER, Permission.SALES_CREATE);

      expect(result).toBe(true);
    });

    it('should return false for staff without the requested permission', async () => {
      mockRolePermissionsRepo.findOne.mockResolvedValue(null);

      const result = await service.hasPermission(TEAM_ID, TeamRole.STAFF, Permission.REPORTS_VIEW);

      expect(result).toBe(false);
    });

    it('should return true for staff with custom permissions that include the requested one', async () => {
      mockRolePermissionsRepo.findOne.mockResolvedValue({
        id: 'rp-uuid-1',
        teamId: TEAM_ID,
        role: TeamRole.STAFF,
        permissions: [Permission.SALES_CREATE, Permission.REPORTS_VIEW],
      });

      const result = await service.hasPermission(TEAM_ID, TeamRole.STAFF, Permission.REPORTS_VIEW);

      expect(result).toBe(true);
    });

    it('should return true when permissions include wildcard (*)', async () => {
      mockRolePermissionsRepo.findOne.mockResolvedValue({
        id: 'rp-uuid-1',
        teamId: TEAM_ID,
        role: TeamRole.MANAGER,
        permissions: ['*'],
      });

      const result = await service.hasPermission(TEAM_ID, TeamRole.MANAGER, Permission.ADMIN_AUDIT);

      expect(result).toBe(true);
    });
  });

  describe('getAllPermissions', () => {
    it('should return permissions for all roles with defaults', async () => {
      mockRolePermissionsRepo.find.mockResolvedValue([]);

      const result = await service.getAllPermissions(TEAM_ID);

      expect(result).toBeDefined();
      expect(result[TeamRole.OWNER]).toEqual(ALL_PERMISSIONS);
      expect(result[TeamRole.ADMIN]).toEqual(ALL_PERMISSIONS);
      expect(result[TeamRole.MANAGER]).toEqual(DEFAULT_PERMISSIONS[TeamRole.MANAGER]);
      expect(result[TeamRole.STAFF]).toEqual(DEFAULT_PERMISSIONS[TeamRole.STAFF]);
    });

    it('should override defaults with custom permissions from database', async () => {
      const customStaffPerms = [Permission.SALES_CREATE, Permission.REPORTS_VIEW];
      mockRolePermissionsRepo.find.mockResolvedValue([
        {
          role: TeamRole.STAFF,
          permissions: customStaffPerms,
        },
      ]);

      const result = await service.getAllPermissions(TEAM_ID);

      expect(result[TeamRole.STAFF]).toEqual(customStaffPerms);
      // Owner and admin should always be ALL_PERMISSIONS
      expect(result[TeamRole.OWNER]).toEqual(ALL_PERMISSIONS);
      expect(result[TeamRole.ADMIN]).toEqual(ALL_PERMISSIONS);
    });

    it('should always return ALL_PERMISSIONS for owner and admin even if database has entries', async () => {
      mockRolePermissionsRepo.find.mockResolvedValue([
        {
          role: TeamRole.OWNER,
          permissions: [Permission.SALES_CREATE],
        },
        {
          role: TeamRole.ADMIN,
          permissions: [Permission.SALES_CREATE],
        },
      ]);

      const result = await service.getAllPermissions(TEAM_ID);

      expect(result[TeamRole.OWNER]).toEqual(ALL_PERMISSIONS);
      expect(result[TeamRole.ADMIN]).toEqual(ALL_PERMISSIONS);
    });
  });
});
