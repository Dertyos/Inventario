import {
  Controller,
  Get,
  Post,
  Param,
  UseGuards,
  Request,
} from '@nestjs/common';
import { TeamsService } from './teams.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ApiTags } from '@nestjs/swagger';

@ApiTags('invitations')
@Controller('invitations')
export class InvitationsController {
  constructor(private readonly teamsService: TeamsService) {}

  @Get(':token')
  async getInvitation(@Param('token') token: string) {
    const invite = await this.teamsService.getInvitationByToken(token);
    return {
      id: invite.id,
      email: invite.email,
      status: invite.status,
      expiresAt: invite.expiresAt,
      createdAt: invite.createdAt,
      team: {
        id: invite.team.id,
        name: invite.team.name,
      },
      inviter: {
        firstName: invite.inviter.firstName,
        lastName: invite.inviter.lastName,
      },
    };
  }

  @Post(':token/accept')
  @UseGuards(JwtAuthGuard)
  async acceptInvitation(@Param('token') token: string, @Request() req) {
    return this.teamsService.acceptInvitation(token, req.user.id);
  }
}
