import {
  Injectable,
  NotFoundException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Team } from './entities/team.entity';
import { TeamMember, TeamRole } from './entities/team-member.entity';
import { TeamSettings } from './entities/team-settings.entity';
import { UsersService } from '../users/users.service';
import { CreateTeamDto } from './dto/create-team.dto';
import { UpdateTeamDto } from './dto/update-team.dto';
import { AddMemberDto } from './dto/add-member.dto';
import { UpdateSettingsDto } from './dto/update-settings.dto';

@Injectable()
export class TeamsService {
  constructor(
    @InjectRepository(Team)
    private readonly teamsRepository: Repository<Team>,
    @InjectRepository(TeamMember)
    private readonly membersRepository: Repository<TeamMember>,
    @InjectRepository(TeamSettings)
    private readonly settingsRepository: Repository<TeamSettings>,
    private readonly usersService: UsersService,
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

  async findByUser(userId: string): Promise<Team[]> {
    const memberships = await this.membersRepository.find({
      where: { userId, isActive: true },
      relations: ['team', 'team.settings'],
    });
    return memberships.map((m) => m.team);
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

  private generateSlug(name: string): string {
    return name
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '');
  }
}
