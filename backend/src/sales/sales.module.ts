import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Sale } from './entities/sale.entity';
import { SaleItem } from './entities/sale-item.entity';
import { SalesService } from './sales.service';
import { SalesController } from './sales.controller';
import { TeamsModule } from '../teams/teams.module';
import { CreditsModule } from '../credits/credits.module';

@Module({
  imports: [TypeOrmModule.forFeature([Sale, SaleItem]), TeamsModule, CreditsModule],
  controllers: [SalesController],
  providers: [SalesService],
  exports: [SalesService],
})
export class SalesModule {}
