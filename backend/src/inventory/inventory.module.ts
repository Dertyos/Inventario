import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { InventoryMovement } from './entities/inventory-movement.entity';
import { Product } from '../products/entities/product.entity';
import { ProductLot } from '../lots/entities/product-lot.entity';
import { Supplier } from '../suppliers/entities/supplier.entity';
import { TeamSettings } from '../teams/entities/team-settings.entity';
import { InventoryService } from './inventory.service';
import { InventoryController } from './inventory.controller';
import { TeamsModule } from '../teams/teams.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([InventoryMovement, Product, ProductLot, Supplier, TeamSettings]),
    TeamsModule,
  ],
  controllers: [InventoryController],
  providers: [InventoryService],
  exports: [InventoryService],
})
export class InventoryModule {}
