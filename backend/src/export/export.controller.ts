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
import { ExportService } from './export.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TeamRolesGuard } from '../teams/guards/team-roles.guard';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('export')
@ApiBearerAuth()
@Controller('teams/:teamId/export')
@UseGuards(JwtAuthGuard, TeamRolesGuard)
export class ExportController {
  constructor(private readonly exportService: ExportService) {}

  @Get('sales')
  async exportSales(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
    @Res() res?: Response,
  ) {
    const csv = await this.exportService.exportSales(teamId, startDate, endDate);
    const now = new Date();
    const filename = `sales-${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}.csv`;
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(csv);
  }

  @Get('products')
  async exportProducts(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Res() res?: Response,
  ) {
    const csv = await this.exportService.exportProducts(teamId);
    const now = new Date();
    const filename = `products-${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}.csv`;
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(csv);
  }

  @Get('inventory')
  async exportInventory(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
    @Res() res?: Response,
  ) {
    const csv = await this.exportService.exportInventory(
      teamId,
      startDate,
      endDate,
    );
    const now = new Date();
    const filename = `inventory-${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}.csv`;
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(csv);
  }
}
