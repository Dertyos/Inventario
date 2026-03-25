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
import { SalesService } from './sales.service';
import { CreateSaleDto } from './dto/create-sale.dto';
import { SaleStatus } from './entities/sale.entity';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TeamRolesGuard } from '../teams/guards/team-roles.guard';
import { TeamRoles } from '../teams/decorators/team-roles.decorator';
import { TeamRole } from '../teams/entities/team-member.entity';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('sales')
@ApiBearerAuth()
@Controller('teams/:teamId/sales')
@UseGuards(JwtAuthGuard, TeamRolesGuard)
export class SalesController {
  constructor(private readonly salesService: SalesService) {}

  @Post()
  create(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Body() createSaleDto: CreateSaleDto,
    @Request() req,
  ) {
    return this.salesService.create(teamId, req.user.id, createSaleDto);
  }

  @Get()
  findAll(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('customerId') customerId?: string,
    @Query('status') status?: SaleStatus,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
  ) {
    return this.salesService.findAll(teamId, {
      customerId,
      status,
      startDate,
      endDate,
    });
  }

  @Get(':id')
  findOne(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.salesService.findOne(teamId, id);
  }

  @Patch(':id/cancel')
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN, TeamRole.MANAGER)
  cancel(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Request() req,
  ) {
    return this.salesService.cancel(teamId, id, req.user.id);
  }
}
