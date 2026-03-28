import {
  Controller,
  Get,
  Post,
  Patch,
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
import { PurchasesService } from './purchases.service';
import { CreatePurchaseDto } from './dto/create-purchase.dto';
import { PurchaseStatus } from './entities/purchase.entity';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TeamRolesGuard } from '../teams/guards/team-roles.guard';
import { FeatureGuard } from '../common/guards/feature.guard';
import { TeamRoles } from '../teams/decorators/team-roles.decorator';
import { RequireFeature } from '../common/decorators/require-feature.decorator';
import { TeamRole } from '../teams/entities/team-member.entity';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('purchases')
@ApiBearerAuth()
@Controller('teams/:teamId/purchases')
@UseGuards(JwtAuthGuard, TeamRolesGuard, FeatureGuard)
@RequireFeature('enableSuppliers')
export class PurchasesController {
  constructor(
    private readonly purchasesService: PurchasesService,
    @Inject(CACHE_MANAGER) private cacheManager: Cache,
  ) {}

  @Post()
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN, TeamRole.MANAGER)
  async create(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Body() createPurchaseDto: CreatePurchaseDto,
    @Request() req,
  ) {
    const result = await this.purchasesService.create(teamId, req.user.id, createPurchaseDto);
    await this.cacheManager.clear();
    return result;
  }

  @Get()
  findAll(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('supplierId') supplierId?: string,
    @Query('status') status?: PurchaseStatus,
  ) {
    return this.purchasesService.findAll(teamId, { supplierId, status });
  }

  @Get(':id')
  findOne(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.purchasesService.findOne(teamId, id);
  }

  @Patch(':id/receive')
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN, TeamRole.MANAGER)
  async receive(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Request() req,
  ) {
    const result = await this.purchasesService.receive(teamId, id, req.user.id);
    await this.cacheManager.clear();
    return result;
  }

  @Patch(':id/cancel')
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN)
  async cancel(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Request() req,
  ) {
    const result = await this.purchasesService.cancel(teamId, id, req.user.id);
    await this.cacheManager.clear();
    return result;
  }
}
