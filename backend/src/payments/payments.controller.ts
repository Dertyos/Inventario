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
import { PaymentsService } from './payments.service';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TeamRolesGuard } from '../teams/guards/team-roles.guard';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('payments')
@ApiBearerAuth()
@Controller('teams/:teamId/payments')
@UseGuards(JwtAuthGuard, TeamRolesGuard)
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Post()
  create(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Body() createPaymentDto: CreatePaymentDto,
    @Request() req,
  ) {
    return this.paymentsService.create(teamId, req.user.id, createPaymentDto);
  }

  @Get()
  findAll(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('saleId') saleId?: string,
  ) {
    return this.paymentsService.findAll(teamId, { saleId });
  }

  @Get(':id')
  findOne(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.paymentsService.findOne(teamId, id);
  }
}
