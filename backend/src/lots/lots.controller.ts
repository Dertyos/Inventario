import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  Query,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import { LotsService } from './lots.service';
import { CreateLotDto } from './dto/create-lot.dto';
import { LotStatus } from './entities/product-lot.entity';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TeamRolesGuard } from '../teams/guards/team-roles.guard';
import { TeamRoles } from '../teams/decorators/team-roles.decorator';
import { TeamRole } from '../teams/entities/team-member.entity';

@Controller('teams/:teamId/lots')
@UseGuards(JwtAuthGuard, TeamRolesGuard)
export class LotsController {
  constructor(private readonly lotsService: LotsService) {}

  @Post()
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN, TeamRole.MANAGER)
  create(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Body() createLotDto: CreateLotDto,
  ) {
    return this.lotsService.create(teamId, createLotDto);
  }

  @Get()
  findAll(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('productId') productId?: string,
    @Query('status') status?: LotStatus,
  ) {
    return this.lotsService.findAll(teamId, { productId, status });
  }

  @Get('expiring')
  getExpiring(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('days') days?: string,
  ) {
    return this.lotsService.getExpiringLots(teamId, days ? parseInt(days) : 30);
  }

  @Get(':id')
  findOne(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.lotsService.findOne(teamId, id);
  }

  @Post('mark-expired')
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN)
  markExpired(@Param('teamId', ParseUUIDPipe) teamId: string) {
    return this.lotsService.markExpiredLots(teamId);
  }
}
