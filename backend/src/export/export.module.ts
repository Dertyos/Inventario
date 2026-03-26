import { Module } from '@nestjs/common';
import { ExportService } from './export.service';
import { ExportController } from './export.controller';
import { SalesModule } from '../sales/sales.module';
import { ProductsModule } from '../products/products.module';
import { InventoryModule } from '../inventory/inventory.module';
import { TeamsModule } from '../teams/teams.module';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Sale } from '../sales/entities/sale.entity';
import { Product } from '../products/entities/product.entity';
import { InventoryMovement } from '../inventory/entities/inventory-movement.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Sale, Product, InventoryMovement]),
    SalesModule,
    ProductsModule,
    InventoryModule,
    TeamsModule,
  ],
  controllers: [ExportController],
  providers: [ExportService],
})
export class ExportModule {}
