import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Team } from './entities/team.entity';
import { TeamMember } from './entities/team-member.entity';
import { TeamSettings } from './entities/team-settings.entity';
import { TeamInvite } from './entities/team-invite.entity';
import { RolePermissions } from './entities/role-permissions.entity';
import { TeamsService } from './teams.service';
import { TeamsController } from './teams.controller';
import { InvitationsController } from './invitations.controller';
import { InviteLandingController } from './invite-landing.controller';
import { WellKnownController } from './well-known.controller';
import { UsersModule } from '../users/users.module';
import { EmailModule } from '../email/email.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Team, TeamMember, TeamSettings, TeamInvite, RolePermissions]),
    UsersModule,
    EmailModule,
  ],
  controllers: [
    TeamsController,
    InvitationsController,
    InviteLandingController,
    WellKnownController,
  ],
  providers: [TeamsService],
  exports: [TeamsService],
})
export class TeamsModule {}
