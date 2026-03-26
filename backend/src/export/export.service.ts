import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Sale, SaleStatus } from '../sales/entities/sale.entity';
import { Product } from '../products/entities/product.entity';
import { InventoryMovement } from '../inventory/entities/inventory-movement.entity';

@Injectable()
export class ExportService {
  constructor(
    @InjectRepository(Sale)
    private readonly salesRepository: Repository<Sale>,
    @InjectRepository(Product)
    private readonly productsRepository: Repository<Product>,
    @InjectRepository(InventoryMovement)
    private readonly movementsRepository: Repository<InventoryMovement>,
  ) {}

  async exportSales(
    teamId: string,
    startDate?: string,
    endDate?: string,
  ): Promise<string> {
    const query = this.salesRepository
      .createQueryBuilder('sale')
      .leftJoinAndSelect('sale.customer', 'customer')
      .where('sale.teamId = :teamId', { teamId });

    if (startDate) {
      query.andWhere('sale.createdAt >= :startDate', { startDate });
    }

    if (endDate) {
      query.andWhere('sale.createdAt <= :endDate', { endDate });
    }

    const sales = await query.orderBy('sale.createdAt', 'DESC').getMany();

    const header = 'fecha,numero,cliente,total,metodo_pago,estado';
    const rows = sales.map((sale) => {
      const fecha = sale.createdAt
        ? new Date(sale.createdAt).toISOString().split('T')[0]
        : '';
      const cliente = this.escapeCsv(sale.customer?.name || '');
      return `${fecha},${sale.saleNumber},${cliente},${sale.total},${sale.paymentMethod},${sale.status}`;
    });

    return [header, ...rows].join('\n');
  }

  async exportProducts(teamId: string): Promise<string> {
    const products = await this.productsRepository
      .createQueryBuilder('product')
      .leftJoinAndSelect('product.category', 'category')
      .where('product.teamId = :teamId', { teamId })
      .andWhere('product.isActive = true')
      .orderBy('product.name', 'ASC')
      .getMany();

    const header = 'sku,nombre,categoria,precio,costo,stock,stock_minimo';
    const rows = products.map((product) => {
      const nombre = this.escapeCsv(product.name);
      const categoria = this.escapeCsv(product.category?.name || '');
      const costo = product.cost != null ? product.cost : '';
      return `${product.sku},${nombre},${categoria},${product.price},${costo},${product.stock},${product.minStock}`;
    });

    return [header, ...rows].join('\n');
  }

  async exportInventory(
    teamId: string,
    startDate?: string,
    endDate?: string,
  ): Promise<string> {
    const query = this.movementsRepository
      .createQueryBuilder('movement')
      .leftJoinAndSelect('movement.product', 'product')
      .where('movement.teamId = :teamId', { teamId });

    if (startDate) {
      query.andWhere('movement.createdAt >= :startDate', { startDate });
    }

    if (endDate) {
      query.andWhere('movement.createdAt <= :endDate', { endDate });
    }

    const movements = await query
      .orderBy('movement.createdAt', 'DESC')
      .getMany();

    const header = 'fecha,producto,tipo,cantidad,razon';
    const rows = movements.map((movement) => {
      const fecha = movement.createdAt
        ? new Date(movement.createdAt).toISOString().split('T')[0]
        : '';
      const producto = this.escapeCsv(movement.product?.name || '');
      const razon = this.escapeCsv(movement.reason || '');
      return `${fecha},${producto},${movement.type},${movement.quantity},${razon}`;
    });

    return [header, ...rows].join('\n');
  }

  private escapeCsv(value: string): string {
    if (value.includes(',') || value.includes('"') || value.includes('\n')) {
      return `"${value.replace(/"/g, '""')}"`;
    }
    return value;
  }
}
