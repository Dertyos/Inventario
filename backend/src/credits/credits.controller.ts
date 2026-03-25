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
import { CreditsService } from './credits.service';
import { CreateCreditDto } from './dto/create-credit.dto';
import { PayInstallmentDto } from './dto/pay-installment.dto';
import { CreditStatus } from './entities/credit-account.entity';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TeamRolesGuard } from '../teams/guards/team-roles.guard';
import { TeamRoles } from '../teams/decorators/team-roles.decorator';
import { TeamRole } from '../teams/entities/team-member.entity';

@Controller('teams/:teamId/credits')
@UseGuards(JwtAuthGuard, TeamRolesGuard)
export class CreditsController {
  constructor(private readonly creditsService: CreditsService) {}

  @Post()
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN, TeamRole.MANAGER)
  create(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Body() createCreditDto: CreateCreditDto,
  ) {
    return this.creditsService.create(teamId, createCreditDto);
  }

  @Get()
  findAll(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('customerId') customerId?: string,
    @Query('status') status?: CreditStatus,
  ) {
    return this.creditsService.findAll(teamId, { customerId, status });
  }

  @Get('overdue')
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN, TeamRole.MANAGER)
  getOverdue(@Param('teamId', ParseUUIDPipe) teamId: string) {
    return this.creditsService.getOverdue(teamId);
  }

  @Get(':id')
  findOne(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.creditsService.findOne(teamId, id);
  }

  @Post(':id/installments/:installmentId/pay')
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN, TeamRole.MANAGER, TeamRole.STAFF)
  payInstallment(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('installmentId', ParseUUIDPipe) installmentId: string,
    @Body() payInstallmentDto: PayInstallmentDto,
  ) {
    return this.creditsService.payInstallment(
      teamId,
      id,
      installmentId,
      payInstallmentDto,
    );
  }
}
