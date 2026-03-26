import {
  Controller,
  Get,
  Param,
  Query,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import { AuditService } from './audit.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TeamRolesGuard } from '../teams/guards/team-roles.guard';
import { TeamRoles } from '../teams/decorators/team-roles.decorator';
import { TeamRole } from '../teams/entities/team-member.entity';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('audit')
@ApiBearerAuth()
@Controller('teams/:teamId/audit')
@UseGuards(JwtAuthGuard, TeamRolesGuard)
export class AuditController {
  constructor(private readonly auditService: AuditService) {}

  @Get()
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN)
  findAll(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('limit') limit?: string,
  ) {
    const parsedLimit = limit ? parseInt(limit, 10) : 50;
    return this.auditService.findByTeam(teamId, parsedLimit);
  }
}
