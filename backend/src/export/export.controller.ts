import {
  Controller,
  Get,
  Param,
  Query,
  UseGuards,
  ParseUUIDPipe,
  Res,
} from '@nestjs/common';
import { Response } from 'express';
import { Throttle } from '@nestjs/throttler';
import { ExportService } from './export.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TeamRolesGuard } from '../teams/guards/team-roles.guard';
import { RequirePermission } from '../teams/decorators/require-permission.decorator';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('export')
@ApiBearerAuth()
@Controller('teams/:teamId/export')
@UseGuards(JwtAuthGuard, TeamRolesGuard)
export class ExportController {
  constructor(private readonly exportService: ExportService) {}

  @Throttle({ default: { limit: 5, ttl: 60000 } })
  @Get('sales')
  @RequirePermission('reports.export')
  async exportSales(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
    @Res() res?: Response,
  ) {
    const stream = await this.exportService.exportSalesStream(teamId, startDate, endDate);
    const now = new Date();
    const filename = `sales-${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}.csv`;
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    stream.pipe(res);
  }

  @Throttle({ default: { limit: 5, ttl: 60000 } })
  @Get('products')
  @RequirePermission('reports.export')
  async exportProducts(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Res() res?: Response,
  ) {
    const stream = await this.exportService.exportProductsStream(teamId);
    const now = new Date();
    const filename = `products-${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}.csv`;
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    stream.pipe(res);
  }

  @Throttle({ default: { limit: 5, ttl: 60000 } })
  @Get('inventory')
  @RequirePermission('reports.export')
  async exportInventory(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
    @Res() res?: Response,
  ) {
    const stream = await this.exportService.exportInventoryStream(
      teamId,
      startDate,
      endDate,
    );
    const now = new Date();
    const filename = `inventory-${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}.csv`;
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    stream.pipe(res);
  }
}
