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
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { UserRole } from '../users/entities/user.entity';

@Controller('inventory')
@UseGuards(JwtAuthGuard, RolesGuard)
export class InventoryController {
  constructor(private readonly inventoryService: InventoryService) {}

  @Post('movements')
  @Roles(UserRole.ADMIN, UserRole.MANAGER, UserRole.EMPLOYEE)
  createMovement(@Body() createMovementDto: CreateMovementDto, @Request() req) {
    return this.inventoryService.createMovement(createMovementDto, req.user.id);
  }

  @Get('movements')
  findAllMovements(
    @Query('productId') productId?: string,
    @Query('type') type?: MovementType,
  ) {
    return this.inventoryService.findAll({ productId, type });
  }

  @Get('movements/:id')
  findOneMovement(@Param('id', ParseUUIDPipe) id: string) {
    return this.inventoryService.findOne(id);
  }
}
