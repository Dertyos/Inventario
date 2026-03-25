import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CreditAccount } from './entities/credit-account.entity';
import { CreditInstallment } from './entities/credit-installment.entity';
import { CreditsService } from './credits.service';
import { CreditsController } from './credits.controller';
import { TeamsModule } from '../teams/teams.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([CreditAccount, CreditInstallment]),
    TeamsModule,
  ],
  controllers: [CreditsController],
  providers: [CreditsService],
  exports: [CreditsService],
})
export class CreditsModule {}
