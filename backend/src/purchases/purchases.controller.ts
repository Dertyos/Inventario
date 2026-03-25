import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Body,
  Query,
  UseGuards,
  ParseUUIDPipe,
  Request,
} from '@nestjs/common';
import { PurchasesService } from './purchases.service';
import { CreatePurchaseDto } from './dto/create-purchase.dto';
import { PurchaseStatus } from './entities/purchase.entity';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TeamRolesGuard } from '../teams/guards/team-roles.guard';
import { TeamRoles } from '../teams/decorators/team-roles.decorator';
import { TeamRole } from '../teams/entities/team-member.entity';

@Controller('teams/:teamId/purchases')
@UseGuards(JwtAuthGuard, TeamRolesGuard)
export class PurchasesController {
  constructor(private readonly purchasesService: PurchasesService) {}

  @Post()
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN, TeamRole.MANAGER)
  create(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Body() createPurchaseDto: CreatePurchaseDto,
    @Request() req,
  ) {
    return this.purchasesService.create(teamId, req.user.id, createPurchaseDto);
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
  receive(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Request() req,
  ) {
    return this.purchasesService.receive(teamId, id, req.user.id);
  }

  @Patch(':id/cancel')
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN)
  cancel(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.purchasesService.cancel(teamId, id);
  }
}
