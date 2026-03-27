import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  Inject,
  ParseUUIDPipe,
  Request,
} from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Cache } from 'cache-manager';
import { SalesService } from './sales.service';
import { CreateSaleDto } from './dto/create-sale.dto';
import { UpdateSaleDto } from './dto/update-sale.dto';
import { SaleStatus } from './entities/sale.entity';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TeamRolesGuard } from '../teams/guards/team-roles.guard';
import { TeamRoles } from '../teams/decorators/team-roles.decorator';
import { RequirePermission } from '../teams/decorators/require-permission.decorator';
import { TeamRole } from '../teams/entities/team-member.entity';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('sales')
@ApiBearerAuth()
@Controller('teams/:teamId/sales')
@UseGuards(JwtAuthGuard, TeamRolesGuard)
export class SalesController {
  constructor(
    private readonly salesService: SalesService,
    @Inject(CACHE_MANAGER) private cacheManager: Cache,
  ) {}

  @Post()
  @RequirePermission('sales.create')
  async create(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Body() createSaleDto: CreateSaleDto,
    @Request() req,
  ) {
    const result = await this.salesService.create(teamId, req.user.id, createSaleDto);
    await this.cacheManager.clear();
    return result;
  }

  @Get()
  findAll(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('customerId') customerId?: string,
    @Query('status') status?: SaleStatus,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.salesService.findAll(teamId, {
      customerId,
      status,
      startDate,
      endDate,
      page: page ? parseInt(page, 10) : undefined,
      limit: limit ? parseInt(limit, 10) : undefined,
    });
  }

  @Get(':id')
  findOne(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.salesService.findOne(teamId, id);
  }

  @Patch(':id')
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN, TeamRole.MANAGER)
  @RequirePermission('sales.edit')
  async update(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() updateSaleDto: UpdateSaleDto,
  ) {
    const result = await this.salesService.update(teamId, id, updateSaleDto);
    await this.cacheManager.clear();
    return result;
  }

  @Delete(':id')
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN)
  @RequirePermission('sales.delete')
  async remove(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Request() req,
  ) {
    const result = await this.salesService.remove(teamId, id, req.user.id);
    await this.cacheManager.clear();
    return result;
  }

  @Patch(':id/cancel')
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN, TeamRole.MANAGER)
  @RequirePermission('sales.cancel')
  async cancel(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Request() req,
  ) {
    const result = await this.salesService.cancel(teamId, id, req.user.id);
    await this.cacheManager.clear();
    return result;
  }
}
