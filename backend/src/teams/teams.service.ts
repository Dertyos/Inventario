import {
  Injectable,
  NotFoundException,
  ConflictException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan } from 'typeorm';
import { v4 as uuidv4 } from 'uuid';
import { Team } from './entities/team.entity';
import { TeamMember, TeamRole } from './entities/team-member.entity';
import { TeamSettings } from './entities/team-settings.entity';
import { TeamInvite, InviteStatus } from './entities/team-invite.entity';
import { RolePermissions } from './entities/role-permissions.entity';
import { UsersService } from '../users/users.service';
import { EmailService } from '../email/email.service';
import { CreateTeamDto } from './dto/create-team.dto';
import { UpdateTeamDto } from './dto/update-team.dto';
import { AddMemberDto } from './dto/add-member.dto';
import { UpdateSettingsDto } from './dto/update-settings.dto';
import {
  DEFAULT_PERMISSIONS,
  ALL_PERMISSIONS,
} from './permissions.constants';

@Injectable()
export class TeamsService {
  constructor(
    @InjectRepository(Team)
    private readonly teamsRepository: Repository<Team>,
    @InjectRepository(TeamMember)
    private readonly membersRepository: Repository<TeamMember>,
    @InjectRepository(TeamSettings)
    private readonly settingsRepository: Repository<TeamSettings>,
    @InjectRepository(TeamInvite)
    private readonly invitesRepository: Repository<TeamInvite>,
    @InjectRepository(RolePermissions)
    private readonly rolePermissionsRepository: Repository<RolePermissions>,
    private readonly usersService: UsersService,
    private readonly emailService: EmailService,
  ) {}

  async create(createTeamDto: CreateTeamDto, ownerId: string): Promise<Team> {
    const slug = this.generateSlug(createTeamDto.name);

    const existing = await this.teamsRepository.findOne({ where: { slug } });
    if (existing) {
      throw new ConflictException('A team with a similar name already exists');
    }

    const team = this.teamsRepository.create({
      ...createTeamDto,
      slug,
    });
    const savedTeam = await this.teamsRepository.save(team);

    // Create default settings
    const settings = this.settingsRepository.create({ teamId: savedTeam.id });
    await this.settingsRepository.save(settings);

    // Add creator as owner
    const member = this.membersRepository.create({
      userId: ownerId,
      teamId: savedTeam.id,
      role: TeamRole.OWNER,
      joinedAt: new Date(),
    });
    await this.membersRepository.save(member);

    // Seed default permissions for manager and staff
    const managerPerms = this.rolePermissionsRepository.create({
      teamId: savedTeam.id,
      role: TeamRole.MANAGER,
      permissions: DEFAULT_PERMISSIONS[TeamRole.MANAGER],
    });
    const staffPerms = this.rolePermissionsRepository.create({
      teamId: savedTeam.id,
      role: TeamRole.STAFF,
      permissions: DEFAULT_PERMISSIONS[TeamRole.STAFF],
    });
    await this.rolePermissionsRepository.save([managerPerms, staffPerms]);

    return this.findOne(savedTeam.id);
  }

  async findOne(id: string): Promise<Team> {
    const team = await this.teamsRepository.findOne({
      where: { id },
      relations: ['settings', 'members', 'members.user'],
    });
    if (!team) {
      throw new NotFoundException(`Team #${id} not found`);
    }
    return team;
  }

  async findByUser(userId: string): Promise<Array<Team & { userRole: string }>> {
    const memberships = await this.membersRepository.find({
      where: { userId, isActive: true },
      relations: ['team', 'team.settings'],
    });
    return memberships.map((m) => ({
      ...m.team,
      userRole: m.role,
    }));
  }

  async update(id: string, updateTeamDto: UpdateTeamDto): Promise<Team> {
    const team = await this.findOne(id);

    if (updateTeamDto.name) {
      const newSlug = this.generateSlug(updateTeamDto.name);
      const existing = await this.teamsRepository.findOne({
        where: { slug: newSlug },
      });
      if (existing && existing.id !== id) {
        throw new ConflictException(
          'A team with a similar name already exists',
        );
      }
      team.slug = newSlug;
    }

    Object.assign(team, updateTeamDto);
    await this.teamsRepository.save(team);
    return this.findOne(id);
  }

  async addMember(
    teamId: string,
    addMemberDto: AddMemberDto,
  ): Promise<TeamMember> {
    const user = await this.usersService.findByEmail(addMemberDto.email);
    if (!user) {
      throw new NotFoundException(
        `User with email ${addMemberDto.email} not found`,
      );
    }

    const existing = await this.membersRepository.findOne({
      where: { userId: user.id, teamId },
    });

    if (existing) {
      if (existing.isActive) {
        throw new ConflictException('User is already a member of this team');
      }
      // Re-activate
      existing.isActive = true;
      existing.role = addMemberDto.role || TeamRole.STAFF;
      existing.joinedAt = new Date();
      return this.membersRepository.save(existing);
    }

    const member = this.membersRepository.create({
      userId: user.id,
      teamId,
      role: addMemberDto.role || TeamRole.STAFF,
      joinedAt: new Date(),
    });
    return this.membersRepository.save(member);
  }

  async removeMember(teamId: string, memberId: string): Promise<void> {
    const member = await this.membersRepository.findOne({
      where: { id: memberId, teamId },
    });
    if (!member) {
      throw new NotFoundException('Member not found');
    }
    if (member.role === TeamRole.OWNER) {
      throw new ForbiddenException('Cannot remove the team owner');
    }
    member.isActive = false;
    await this.membersRepository.save(member);
  }

  async updateMemberRole(
    teamId: string,
    memberId: string,
    role: TeamRole,
  ): Promise<TeamMember> {
    const member = await this.membersRepository.findOne({
      where: { id: memberId, teamId },
    });
    if (!member) {
      throw new NotFoundException('Member not found');
    }
    if (member.role === TeamRole.OWNER) {
      throw new ForbiddenException('Cannot change the owner role');
    }
    if (role === TeamRole.OWNER) {
      throw new ForbiddenException('Cannot assign owner role');
    }
    member.role = role;
    return this.membersRepository.save(member);
  }

  async getSettings(teamId: string): Promise<TeamSettings> {
    const settings = await this.settingsRepository.findOne({
      where: { teamId },
    });
    if (!settings) {
      throw new NotFoundException('Team settings not found');
    }
    return settings;
  }

  async updateSettings(
    teamId: string,
    updateSettingsDto: UpdateSettingsDto,
  ): Promise<TeamSettings> {
    const settings = await this.getSettings(teamId);
    Object.assign(settings, updateSettingsDto);
    return this.settingsRepository.save(settings);
  }

  async getMemberByUserAndTeam(
    userId: string,
    teamId: string,
  ): Promise<TeamMember | null> {
    return this.membersRepository.findOne({
      where: { userId, teamId, isActive: true },
    });
  }

  // ── Invitations ─────────────────────────────────

  async createInvitation(
    teamId: string,
    email: string,
    invitedById: string,
  ): Promise<TeamInvite> {
    const team = await this.findOne(teamId);

    // Check if user is already a member
    const existingUser = await this.usersService.findByEmail(email);
    if (existingUser) {
      const existingMember = await this.membersRepository.findOne({
        where: { userId: existingUser.id, teamId, isActive: true },
      });
      if (existingMember) {
        throw new ConflictException('User is already a member of this team');
      }
    }

    // Check if there's already a pending invitation for this email
    const existingInvite = await this.invitesRepository.findOne({
      where: {
        teamId,
        email,
        status: InviteStatus.PENDING,
        expiresAt: MoreThan(new Date()),
      },
    });
    if (existingInvite) {
      throw new ConflictException(
        'There is already a pending invitation for this email',
      );
    }

    const inviter = await this.usersService.findOne(invitedById);

    const invite = this.invitesRepository.create({
      teamId,
      email,
      token: uuidv4(),
      invitedBy: invitedById,
      status: InviteStatus.PENDING,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
    });
    const savedInvite = await this.invitesRepository.save(invite);

    // Send invitation email
    const inviteLink = `https://inventario.dertyos.com/invite/${savedInvite.token}`;
    const inviterName = `${inviter.firstName} ${inviter.lastName}`.trim();
    await this.emailService.sendTeamInvitation(
      email,
      team.name,
      inviterName,
      inviteLink,
    );

    return savedInvite;
  }

  async getInvitations(teamId: string): Promise<TeamInvite[]> {
    return this.invitesRepository.find({
      where: { teamId },
      relations: ['inviter'],
      order: { createdAt: 'DESC' },
    });
  }

  async revokeInvitation(
    teamId: string,
    invitationId: string,
  ): Promise<void> {
    const invite = await this.invitesRepository.findOne({
      where: { id: invitationId, teamId },
    });
    if (!invite) {
      throw new NotFoundException('Invitation not found');
    }
    if (invite.status !== InviteStatus.PENDING) {
      throw new BadRequestException('Only pending invitations can be revoked');
    }
    invite.status = InviteStatus.REVOKED;
    await this.invitesRepository.save(invite);
  }

  async getInvitationByToken(token: string): Promise<TeamInvite> {
    const invite = await this.invitesRepository.findOne({
      where: { token },
      relations: ['team', 'inviter'],
    });
    if (!invite) {
      throw new NotFoundException('Invitation not found');
    }
    return invite;
  }

  async acceptInvitation(token: string, userId: string): Promise<TeamMember> {
    const invite = await this.invitesRepository.findOne({
      where: { token },
      relations: ['team'],
    });
    if (!invite) {
      throw new NotFoundException('Invitation not found');
    }
    if (invite.status !== InviteStatus.PENDING) {
      throw new BadRequestException('This invitation is no longer valid');
    }
    if (new Date() > invite.expiresAt) {
      throw new BadRequestException('This invitation has expired');
    }

    // Check if user is already a member
    const existingMember = await this.membersRepository.findOne({
      where: { userId, teamId: invite.teamId },
    });

    if (existingMember) {
      if (existingMember.isActive) {
        // Already a member, just mark invite as accepted
        invite.status = InviteStatus.ACCEPTED;
        await this.invitesRepository.save(invite);
        throw new ConflictException('You are already a member of this team');
      }
      // Re-activate
      existingMember.isActive = true;
      existingMember.role = TeamRole.STAFF;
      existingMember.joinedAt = new Date();
      invite.status = InviteStatus.ACCEPTED;
      await this.invitesRepository.save(invite);
      return this.membersRepository.save(existingMember);
    }

    // Add user as team member
    const member = this.membersRepository.create({
      userId,
      teamId: invite.teamId,
      role: TeamRole.STAFF,
      joinedAt: new Date(),
    });
    const savedMember = await this.membersRepository.save(member);

    // Mark invitation as accepted
    invite.status = InviteStatus.ACCEPTED;
    await this.invitesRepository.save(invite);

    return savedMember;
  }

  // ── Role Permissions ─────────────────────────────

  async getRolePermissions(
    teamId: string,
    role: TeamRole,
  ): Promise<string[]> {
    // OWNER and ADMIN always have all permissions
    if (role === TeamRole.OWNER || role === TeamRole.ADMIN) {
      return ALL_PERMISSIONS;
    }

    const entry = await this.rolePermissionsRepository.findOne({
      where: { teamId, role },
    });

    if (!entry) {
      return DEFAULT_PERMISSIONS[role] || [];
    }

    return entry.permissions;
  }

  async updateRolePermissions(
    teamId: string,
    role: TeamRole,
    permissions: string[],
  ): Promise<RolePermissions> {
    if (role === TeamRole.OWNER || role === TeamRole.ADMIN) {
      throw new ForbiddenException(
        'Cannot customize permissions for owner or admin roles',
      );
    }

    // Validate that all provided permissions are valid
    const invalidPermissions = permissions.filter(
      (p) => !ALL_PERMISSIONS.includes(p as any),
    );
    if (invalidPermissions.length > 0) {
      throw new BadRequestException(
        `Invalid permissions: ${invalidPermissions.join(', ')}`,
      );
    }

    let entry = await this.rolePermissionsRepository.findOne({
      where: { teamId, role },
    });

    if (entry) {
      entry.permissions = permissions;
    } else {
      entry = this.rolePermissionsRepository.create({
        teamId,
        role,
        permissions,
      });
    }

    return this.rolePermissionsRepository.save(entry);
  }

  async hasPermission(
    teamId: string,
    role: TeamRole,
    permission: string,
  ): Promise<boolean> {
    // OWNER and ADMIN always have all permissions
    if (role === TeamRole.OWNER || role === TeamRole.ADMIN) {
      return true;
    }

    const permissions = await this.getRolePermissions(teamId, role);

    if (permissions.includes('*')) {
      return true;
    }

    return permissions.includes(permission);
  }

  async getAllPermissions(
    teamId: string,
  ): Promise<Record<string, string[]>> {
    const entries = await this.rolePermissionsRepository.find({
      where: { teamId },
    });

    const result: Record<string, string[]> = {
      [TeamRole.OWNER]: ALL_PERMISSIONS,
      [TeamRole.ADMIN]: ALL_PERMISSIONS,
      [TeamRole.MANAGER]: DEFAULT_PERMISSIONS[TeamRole.MANAGER],
      [TeamRole.STAFF]: DEFAULT_PERMISSIONS[TeamRole.STAFF],
    };

    for (const entry of entries) {
      result[entry.role] = entry.permissions;
    }

    // Owner and admin are always all permissions regardless of DB
    result[TeamRole.OWNER] = ALL_PERMISSIONS;
    result[TeamRole.ADMIN] = ALL_PERMISSIONS;

    return result;
  }

  private generateSlug(name: string): string {
    return name
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '');
  }
}
