import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { TeamsService } from '../../teams/teams.service';
import { FEATURE_KEY } from '../decorators/require-feature.decorator';

@Injectable()
export class FeatureGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly teamsService: TeamsService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const feature = this.reflector.getAllAndOverride<string>(FEATURE_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!feature) {
      return true;
    }

    const request = context.switchToHttp().getRequest();
    const teamId = request.params.teamId;

    if (!teamId) {
      return true;
    }

    const settings = await this.teamsService.getSettings(teamId);

    if (!settings[feature]) {
      throw new ForbiddenException(
        'Esta función no está habilitada para tu equipo',
      );
    }

    return true;
  }
}
