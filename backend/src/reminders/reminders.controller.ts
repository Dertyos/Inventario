import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Query,
  UseGuards,
  ParseUUIDPipe,
  Request,
} from '@nestjs/common';
import { RemindersService } from './reminders.service';
import { ReminderStatus } from './entities/payment-reminder.entity';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TeamRolesGuard } from '../teams/guards/team-roles.guard';
import { FeatureGuard } from '../common/guards/feature.guard';
import { TeamRoles } from '../teams/decorators/team-roles.decorator';
import { RequireFeature } from '../common/decorators/require-feature.decorator';
import { TeamRole } from '../teams/entities/team-member.entity';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';

@ApiTags('reminders')
@ApiBearerAuth()
@Controller('teams/:teamId')
@UseGuards(JwtAuthGuard, TeamRolesGuard, FeatureGuard)
@RequireFeature('enableReminders')
export class RemindersController {
  constructor(private readonly remindersService: RemindersService) {}

  @Post('reminders/generate')
  @TeamRoles(TeamRole.OWNER, TeamRole.ADMIN)
  generateReminders(@Param('teamId', ParseUUIDPipe) teamId: string) {
    return this.remindersService.generateReminders(teamId);
  }

  @Get('reminders')
  findReminders(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Query('customerId') customerId?: string,
    @Query('status') status?: ReminderStatus,
  ) {
    return this.remindersService.findReminders(teamId, {
      customerId,
      status,
    });
  }

  @Get('notifications')
  getNotifications(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Request() req,
    @Query('unreadOnly') unreadOnly?: string,
  ) {
    return this.remindersService.getNotifications(teamId, {
      userId: req.user.id,
      unreadOnly: unreadOnly === 'true',
    });
  }

  @Patch('notifications/:id/read')
  markAsRead(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.remindersService.markAsRead(teamId, id);
  }

  @Post('notifications/read-all')
  markAllAsRead(
    @Param('teamId', ParseUUIDPipe) teamId: string,
    @Request() req,
  ) {
    return this.remindersService.markAllAsRead(teamId, req.user.id);
  }
}
