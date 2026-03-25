import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  Query,
  UseGuards,
  ParseUUIDPipe,
  Request,
} from '@nestjs/common';
import { InventoryService } from './inventory.service';
import { CreateMovementDto } from './dto/create-movement.dto';
import { MovementType } from './entities/inventory-movement.entity';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TeamRolesGuard } from '../teams/guards/team-roles.guard';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('inventory')
@ApiBearerAuth()
@Controller('teams/:teamId/inventory')
@UseGuards(JwtAuthGuard, TeamRolesGuard)
export class InventoryController {
  constructor(private readonly inventoryService: InventoryService) {}

  @Post('movements')
  createMovement(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Body() createMovementDto: CreateMovementDto,
    @Request() req,
  ) {
    return this.inventoryService.createMovement(
      teamId,
      createMovementDto,
      req.user.id,
    );
  }

  @Get('movements')
  findAllMovements(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('productId') productId?: string,
    @Query('type') type?: MovementType,
  ) {
    return this.inventoryService.findAll(teamId, { productId, type });
  }

  @Get('movements/:id')
  findOneMovement(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.inventoryService.findOne(teamId, id);
  }
}
