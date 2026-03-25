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
} from '@nestjs/common';
import { SuppliersService } from './suppliers.service';
import { CreateSupplierDto } from './dto/create-supplier.dto';
import { UpdateSupplierDto } from './dto/update-supplier.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TeamRolesGuard } from '../teams/guards/team-roles.guard';
import { TeamRoles } from '../teams/decorators/team-roles.decorator';
import { TeamRole } from '../teams/entities/team-member.entity';

@Controller('teams/:teamId/suppliers')
@UseGuards(JwtAuthGuard, TeamRolesGuard)
export class SuppliersController {
  constructor(private readonly suppliersService: SuppliersService) {}

  @Post()
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN, TeamRole.MANAGER)
  create(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Body() createSupplierDto: CreateSupplierDto,
  ) {
    return this.suppliersService.create(teamId, createSupplierDto);
  }

  @Get()
  findAll(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('search') search?: string,
  ) {
    return this.suppliersService.findAll(teamId, { search });
  }

  @Get(':id')
  findOne(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.suppliersService.findOne(teamId, id);
  }

  @Patch(':id')
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN, TeamRole.MANAGER)
  update(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() updateSupplierDto: UpdateSupplierDto,
  ) {
    return this.suppliersService.update(teamId, id, updateSupplierDto);
  }
}
