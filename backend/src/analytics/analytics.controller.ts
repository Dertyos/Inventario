import {
  Controller,
  Get,
  Param,
  Query,
  UseGuards,
  UseInterceptors,
  ParseUUIDPipe,
} from '@nestjs/common';
import { CacheInterceptor, CacheTTL } from '@nestjs/cache-manager';
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
  constructor(private readonly analyticsService: AnalyticsService) {}

  @UseInterceptors(CacheInterceptor)
  @CacheTTL(300000) // 5 minutes
  @Get('summary')
  @RequirePermission('reports.view')
  getSummary(@Param('teamId', ParseUUIDPipe) teamId: string) {
    return this.analyticsService.getSummary(teamId);
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
