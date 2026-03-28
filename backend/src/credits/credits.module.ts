import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CreditAccount } from './entities/credit-account.entity';
import { CreditInstallment } from './entities/credit-installment.entity';
import { Notification } from '../reminders/entities/notification.entity';
import { Sale } from '../sales/entities/sale.entity';
import { CreditsService } from './credits.service';
import { CreditsController } from './credits.controller';
import { TeamsModule } from '../teams/teams.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([CreditAccount, CreditInstallment, Notification, Sale]),
    TeamsModule,
  ],
  controllers: [CreditsController],
  providers: [CreditsService],
  exports: [CreditsService],
})
export class CreditsModule {}
