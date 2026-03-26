import {
  Controller,
  Get,
  Param,
  Query,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import { AnalyticsService } from './analytics.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TeamRolesGuard } from '../teams/guards/team-roles.guard';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('analytics')
@ApiBearerAuth()
@Controller('teams/:teamId/analytics')
@UseGuards(JwtAuthGuard, TeamRolesGuard)
export class AnalyticsController {
  constructor(private readonly analyticsService: AnalyticsService) {}

  @Get('summary')
  getSummary(@Param('teamId', ParseUUIDPipe) teamId: string) {
    return this.analyticsService.getSummary(teamId);
  }

  @Get('sales')
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
  getInventoryAnalytics(@Param('teamId', ParseUUIDPipe) teamId: string) {
    return this.analyticsService.getInventoryAnalytics(teamId);
  }
}
