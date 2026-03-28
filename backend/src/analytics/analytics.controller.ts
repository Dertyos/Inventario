import {
  Controller,
  Get,
  Inject,
  Param,
  Query,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Cache } from 'cache-manager';
import { AnalyticsService } from './analytics.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TeamRolesGuard } from '../teams/guards/team-roles.guard';
import { RequirePermission } from '../teams/decorators/require-permission.decorator';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('analytics')
@ApiBearerAuth()
@Controller('teams/:teamId/analytics')
@UseGuards(JwtAuthGuard, TeamRolesGuard)
export class AnalyticsController {
  constructor(
    private readonly analyticsService: AnalyticsService,
    @Inject(CACHE_MANAGER) private readonly cacheManager: Cache,
  ) {}

  @Get('summary')
  @RequirePermission('reports.view')
  async getSummary(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('tzOffset') tzOffset?: string,
  ) {
    const offset = tzOffset ? parseInt(tzOffset, 10) : undefined;
    const cacheKey = `analytics:summary:${teamId}:${offset ?? 0}`;

    const cached = await this.cacheManager.get(cacheKey);
    if (cached) return cached;

    const result = await this.analyticsService.getSummary(teamId, offset);
    await this.cacheManager.set(cacheKey, result, 300000); // 5 minutes
    return result;
  }

  @Get('sales')
  @RequirePermission('reports.view')
  getSalesAnalytics(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('period') period?: string,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
  ) {
    return this.analyticsService.getSalesAnalytics(
      teamId,
      period,
      startDate,
      endDate,
    );
  }

  @Get('inventory')
  @RequirePermission('reports.view')
  getInventoryAnalytics(@Param('teamId', ParseUUIDPipe) teamId: string) {
    return this.analyticsService.getInventoryAnalytics(teamId);
  }
}
