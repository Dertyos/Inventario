import {
  Body,
  Controller,
  Param,
  Post,
  UseGuards,
  Logger,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { AiService } from './ai.service';
import { ParseTransactionDto } from './dto/parse-transaction.dto';
import { TeamMemberGuard } from '../teams/guards/team-member.guard';

@ApiTags('AI')
@ApiBearerAuth()
@Controller('teams/:teamId/ai')
@UseGuards(TeamMemberGuard)
export class AiController {
  private readonly logger = new Logger(AiController.name);

  constructor(private readonly aiService: AiService) {}

  @Post('parse-transaction')
  @Throttle({ short: { limit: 5, ttl: 60000 } })
  @ApiOperation({
    summary: 'Parse natural language into a structured transaction',
    description:
      'Receives voice-transcribed text in Spanish and returns a structured transaction for user confirmation. Rate limited to 5 requests/minute.',
  })
  async parseTransaction(
    @Param('teamId') teamId: string,
    @Body() dto: ParseTransactionDto,
  ) {
    this.logger.log(
      `Parsing transaction for team ${teamId}: "${dto.text.substring(0, 50)}..."`,
    );
    return this.aiService.parseTransaction(teamId, dto.text);
  }
}
