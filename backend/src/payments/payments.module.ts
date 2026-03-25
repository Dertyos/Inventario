import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Payment } from './entities/payment.entity';
import { PaymentsService } from './payments.service';
import { PaymentsController } from './payments.controller';
import { TeamsModule } from '../teams/teams.module';
import { CreditAccount } from '../credits/entities/credit-account.entity';
import { CreditInstallment } from '../credits/entities/credit-installment.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Payment, CreditAccount, CreditInstallment]),
    TeamsModule,
  ],
  controllers: [PaymentsController],
  providers: [PaymentsService],
  exports: [PaymentsService],
})
export class PaymentsModule {}
