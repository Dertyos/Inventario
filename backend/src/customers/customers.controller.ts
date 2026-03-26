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
  ParseUUIDPipe,
} from '@nestjs/common';
import { CustomersService } from './customers.service';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { UpdateCustomerDto } from './dto/update-customer.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TeamRolesGuard } from '../teams/guards/team-roles.guard';
import { TeamRoles } from '../teams/decorators/team-roles.decorator';
import { RequirePermission } from '../teams/decorators/require-permission.decorator';
import { TeamRole } from '../teams/entities/team-member.entity';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('customers')
@ApiBearerAuth()
@Controller('teams/:teamId/customers')
@UseGuards(JwtAuthGuard, TeamRolesGuard)
export class CustomersController {
  constructor(private readonly customersService: CustomersService) {}

  @Post()
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN, TeamRole.MANAGER)
  @RequirePermission('customers.create')
  create(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Body() createCustomerDto: CreateCustomerDto,
  ) {
    return this.customersService.create(teamId, createCustomerDto);
  }

  @Get()
  findAll(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('search') search?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.customersService.findAll(teamId, {
      search,
      page: page ? parseInt(page, 10) : undefined,
      limit: limit ? parseInt(limit, 10) : undefined,
    });
  }

  @Get(':id')
  findOne(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.customersService.findOne(teamId, id);
  }

  @Patch(':id')
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN, TeamRole.MANAGER)
  update(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() updateCustomerDto: UpdateCustomerDto,
  ) {
    return this.customersService.update(teamId, id, updateCustomerDto);
  }

  @Delete(':id')
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN)
  remove(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.customersService.remove(teamId, id);
  }
}
