import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { TeamsService } from '../teams.service';
import { TeamRole } from '../entities/team-member.entity';
import { TEAM_ROLES_KEY } from '../decorators/team-roles.decorator';

@Injectable()
export class TeamRolesGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly teamsService: TeamsService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const user = request.user;
    const teamId = request.params.teamId;

    if (!teamId || !user) {
      return false;
    }

    const member = await this.teamsService.getMemberByUserAndTeam(
      user.id,
      teamId,
    );

    if (!member) {
      throw new ForbiddenException('You are not a member of this team');
    }

    // Attach member info to request for downstream use
    request.teamMember = member;

    const requiredRoles = this.reflector.getAllAndOverride<TeamRole[]>(
      TEAM_ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!requiredRoles) {
      return true; // No specific roles required, membership is enough
    }

    return requiredRoles.includes(member.role);
  }
}
