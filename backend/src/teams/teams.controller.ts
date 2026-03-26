import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  UseGuards,
  Request,
  ParseUUIDPipe,
} from '@nestjs/common';
import { TeamsService } from './teams.service';
import { CreateTeamDto } from './dto/create-team.dto';
import { UpdateTeamDto } from './dto/update-team.dto';
import { AddMemberDto } from './dto/add-member.dto';
import { UpdateSettingsDto } from './dto/update-settings.dto';
import { CreateInviteDto } from './dto/create-invite.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TeamRolesGuard } from './guards/team-roles.guard';
import { TeamRoles } from './decorators/team-roles.decorator';
import { TeamRole } from './entities/team-member.entity';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('teams')
@ApiBearerAuth()
@Controller('teams')
@UseGuards(JwtAuthGuard)
export class TeamsController {
  constructor(private readonly teamsService: TeamsService) {}

  @Post()
  create(@Body() createTeamDto: CreateTeamDto, @Request() req) {
    return this.teamsService.create(createTeamDto, req.user.id);
  }

  @Get()
  async findMyTeams(@Request() req) {
    const teams = await this.teamsService.findByUser(req.user.id);
    return teams.map((team) => ({
      id: team.id,
      name: team.name,
      slug: team.slug,
      currency: team.currency,
      timezone: team.timezone,
      isActive: team.isActive,
      userRole: team.userRole,
      settings: team.settings,
      createdAt: team.createdAt,
      updatedAt: team.updatedAt,
    }));
  }

  @Get(':teamId')
  @UseGuards(TeamRolesGuard)
  findOne(@Param('teamId', ParseUUIDPipe) teamId: string) {
    return this.teamsService.findOne(teamId);
  }

  @Patch(':teamId')
  @UseGuards(TeamRolesGuard)
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN)
  update(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Body() updateTeamDto: UpdateTeamDto,
  ) {
    return this.teamsService.update(teamId, updateTeamDto);
  }

  // ── Members ───────────────────────────────────

  @Get(':teamId/members')
  @UseGuards(TeamRolesGuard)
  getMembers(@Param('teamId', ParseUUIDPipe) teamId: string) {
    return this.teamsService
      .findOne(teamId)
      .then((team) => team.members.filter((m) => m.isActive));
  }

  @Post(':teamId/members')
  @UseGuards(TeamRolesGuard)
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN)
  addMember(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Body() addMemberDto: AddMemberDto,
  ) {
    return this.teamsService.addMember(teamId, addMemberDto);
  }

  @Delete(':teamId/members/:memberId')
  @UseGuards(TeamRolesGuard)
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN)
  removeMember(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('memberId', ParseUUIDPipe) memberId: string,
  ) {
    return this.teamsService.removeMember(teamId, memberId);
  }

  @Patch(':teamId/members/:memberId/role')
  @UseGuards(TeamRolesGuard)
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN)
  updateMemberRole(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('memberId', ParseUUIDPipe) memberId: string,
    @Body('role') role: TeamRole,
  ) {
    return this.teamsService.updateMemberRole(teamId, memberId, role);
  }

  // ── Invitations ─────────────────────────────────

  @Post(':teamId/invitations')
  @UseGuards(TeamRolesGuard)
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN)
  createInvitation(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Body() createInviteDto: CreateInviteDto,
    @Request() req,
  ) {
    return this.teamsService.createInvitation(
      teamId,
      createInviteDto.email,
      req.user.id,
    );
  }

  @Get(':teamId/invitations')
  @UseGuards(TeamRolesGuard)
  getInvitations(@Param('teamId', ParseUUIDPipe) teamId: string) {
    return this.teamsService.getInvitations(teamId);
  }

  @Delete(':teamId/invitations/:invitationId')
  @UseGuards(TeamRolesGuard)
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN)
  revokeInvitation(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('invitationId', ParseUUIDPipe) invitationId: string,
  ) {
    return this.teamsService.revokeInvitation(teamId, invitationId);
  }

  // ── Settings ──────────────────────────────────

  @Get(':teamId/settings')
  @UseGuards(TeamRolesGuard)
  getSettings(@Param('teamId', ParseUUIDPipe) teamId: string) {
    return this.teamsService.getSettings(teamId);
  }

  @Patch(':teamId/settings')
  @UseGuards(TeamRolesGuard)
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN)
  updateSettings(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Body() updateSettingsDto: UpdateSettingsDto,
  ) {
    return this.teamsService.updateSettings(teamId, updateSettingsDto);
  }
}
