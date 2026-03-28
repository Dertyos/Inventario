import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
  Logger,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { AiService } from './ai.service';
import {
  ParseTransactionDto,
  ParseCommandDto,
} from './dto/parse-transaction.dto';
import { TeamRolesGuard } from '../teams/guards/team-roles.guard';
import { RequirePermission } from '../teams/decorators/require-permission.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('AI')
@ApiBearerAuth()
@Controller('teams/:teamId/ai')
@UseGuards(JwtAuthGuard, TeamRolesGuard)
export class AiController {
  private readonly logger = new Logger(AiController.name);

  constructor(private readonly aiService: AiService) {}

  @Get('status')
  @RequirePermission('admin.ai')
  @ApiOperation({ summary: 'Check AI service health' })
  status() {
    return this.aiService.getStatus();
  }

  @Post('parse-transaction')
  @RequirePermission('admin.ai')
  @Throttle({ short: { limit: 5, ttl: 60000 } })
  @ApiOperation({
    summary: 'Parse natural language into a structured transaction',
    description:
      'Receives voice-transcribed text in Spanish and returns a structured transaction for user confirmation. Rate limited to 5 requests/minute.',
  })
  async parseTransaction(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Body() dto: ParseTransactionDto,
  ) {
    this.logger.log(
      `Parsing transaction for team ${teamId}: "${dto.text.substring(0, 50)}..."`,
    );
    return this.aiService.parseTransaction(teamId, dto.text);
  }

  @Post('parse-command')
  @RequirePermission('admin.ai')
  @Throttle({ short: { limit: 5, ttl: 60000 } })
  @ApiOperation({
    summary: 'Parse natural language into a structured command',
    description:
      'Receives text in Spanish and returns a structured command for any inventory management operation. Rate limited to 5 requests/minute.',
  })
  async parseCommand(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Body() dto: ParseCommandDto,
  ) {
    this.logger.log(
      `Parsing command for team ${teamId}: "${dto.text.substring(0, 50)}..."`,
    );
    return this.aiService.parseCommand(teamId, dto.text);
  }
}
