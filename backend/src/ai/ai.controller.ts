import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { AiService } from './ai.service';
import { ParseTransactionDto } from './dto/parse-transaction.dto';
import { TeamMemberGuard } from '../teams/guards/team-member.guard';

@ApiTags('AI')
@ApiBearerAuth()
@Controller('teams/:teamId/ai')
@UseGuards(TeamMemberGuard)
export class AiController {
  constructor(private readonly aiService: AiService) {}

  @Post('parse-transaction')
  @ApiOperation({
    summary: 'Parse natural language into a structured transaction',
  })
  async parseTransaction(
    @Param('teamId') teamId: string,
    @Body() dto: ParseTransactionDto,
  ) {
    return this.aiService.parseTransaction(teamId, dto.text);
  }
}
