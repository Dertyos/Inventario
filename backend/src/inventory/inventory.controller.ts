import {
  Controller,
  Get,
  Post,
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
import { InventoryService } from './inventory.service';
import { CreateMovementDto } from './dto/create-movement.dto';
import { MovementType } from './entities/inventory-movement.entity';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TeamRolesGuard } from '../teams/guards/team-roles.guard';
import { RequirePermission } from '../teams/decorators/require-permission.decorator';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('inventory')
@ApiBearerAuth()
@Controller('teams/:teamId/inventory')
@UseGuards(JwtAuthGuard, TeamRolesGuard)
export class InventoryController {
  constructor(
    private readonly inventoryService: InventoryService,
    @Inject(CACHE_MANAGER) private cacheManager: Cache,
  ) {}

  @Post('movements')
  @RequirePermission('inventory.movements')
  async createMovement(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Body() createMovementDto: CreateMovementDto,
    @Request() req,
  ) {
    const result = await this.inventoryService.createMovement(
      teamId,
      createMovementDto,
      req.user.id,
    );
    await this.cacheManager.clear();
    return result;
  }

  @Get('movements')
  findAllMovements(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('productId') productId?: string,
    @Query('type') type?: MovementType,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.inventoryService.findAll(teamId, {
      productId,
      type,
      page: page ? parseInt(page, 10) : undefined,
      limit: limit ? parseInt(limit, 10) : undefined,
    });
  }

  @Get('movements/:id')
  findOneMovement(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.inventoryService.findOne(teamId, id);
  }
}
