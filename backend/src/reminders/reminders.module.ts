import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PaymentReminder } from './entities/payment-reminder.entity';
import { Notification } from './entities/notification.entity';
import { CreditInstallment } from '../credits/entities/credit-installment.entity';
import { TeamSettings } from '../teams/entities/team-settings.entity';
import { RemindersService } from './reminders.service';
import { RemindersController } from './reminders.controller';
import { TeamsModule } from '../teams/teams.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      PaymentReminder,
      Notification,
      CreditInstallment,
      TeamSettings,
    ]),
    TeamsModule,
  ],
  controllers: [RemindersController],
  providers: [RemindersService],
  exports: [RemindersService],
})
export class RemindersModule {}
