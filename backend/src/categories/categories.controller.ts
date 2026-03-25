import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import { CategoriesService } from './categories.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TeamRolesGuard } from '../teams/guards/team-roles.guard';
import { TeamRoles } from '../teams/decorators/team-roles.decorator';
import { TeamRole } from '../teams/entities/team-member.entity';

@Controller('teams/:teamId/categories')
@UseGuards(JwtAuthGuard, TeamRolesGuard)
export class CategoriesController {
  constructor(private readonly categoriesService: CategoriesService) {}

  @Post()
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN, TeamRole.MANAGER)
  create(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Body() createCategoryDto: CreateCategoryDto,
  ) {
    return this.categoriesService.create(teamId, createCategoryDto);
  }

  @Get()
  findAll(@Param('teamId', ParseUUIDPipe) teamId: string) {
    return this.categoriesService.findAll(teamId);
  }

  @Get(':id')
  findOne(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.categoriesService.findOne(teamId, id);
  }

  @Patch(':id')
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN, TeamRole.MANAGER)
  update(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() updateCategoryDto: UpdateCategoryDto,
  ) {
    return this.categoriesService.update(teamId, id, updateCategoryDto);
  }

  @Delete(':id')
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN)
  remove(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.categoriesService.remove(teamId, id);
  }
}
