import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ProductLot } from './entities/product-lot.entity';
import { Team } from '../teams/entities/team.entity';
import { LotsService } from './lots.service';
import { LotsController } from './lots.controller';
import { TeamsModule } from '../teams/teams.module';

@Module({
  imports: [TypeOrmModule.forFeature([ProductLot, Team]), TeamsModule],
  controllers: [LotsController],
  providers: [LotsService],
  exports: [LotsService],
})
export class LotsModule {}
