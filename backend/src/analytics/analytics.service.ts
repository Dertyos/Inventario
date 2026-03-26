import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Sale, SaleStatus } from '../sales/entities/sale.entity';
import { SaleItem } from '../sales/entities/sale-item.entity';
import { Product } from '../products/entities/product.entity';
import { InventoryMovement } from '../inventory/entities/inventory-movement.entity';
import { CreditAccount, CreditStatus } from '../credits/entities/credit-account.entity';

@Injectable()
export class AnalyticsService {
  constructor(
    @InjectRepository(Sale)
    private readonly salesRepository: Repository<Sale>,
    @InjectRepository(SaleItem)
    private readonly saleItemsRepository: Repository<SaleItem>,
    @InjectRepository(Product)
    private readonly productsRepository: Repository<Product>,
    @InjectRepository(InventoryMovement)
    private readonly movementsRepository: Repository<InventoryMovement>,
    @InjectRepository(CreditAccount)
    private readonly creditsRepository: Repository<CreditAccount>,
  ) {}

  async getSummary(teamId: string) {
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const todayEnd = new Date(todayStart);
    todayEnd.setDate(todayEnd.getDate() + 1);

    const yesterdayStart = new Date(todayStart);
    yesterdayStart.setDate(yesterdayStart.getDate() - 1);

    const weekStart = new Date(todayStart);
    weekStart.setDate(weekStart.getDate() - weekStart.getDay());

    // Today's sales
    const todayResult = await this.salesRepository
      .createQueryBuilder('sale')
      .select('COALESCE(SUM(sale.total), 0)', 'revenue')
      .addSelect('COUNT(sale.id)', 'count')
      .where('sale.teamId = :teamId', { teamId })
      .andWhere('sale.status != :cancelled', { cancelled: SaleStatus.CANCELLED })
      .andWhere('sale.createdAt >= :start', { start: todayStart.toISOString() })
      .andWhere('sale.createdAt < :end', { end: todayEnd.toISOString() })
      .getRawOne();

    // Yesterday's sales
    const yesterdayResult = await this.salesRepository
      .createQueryBuilder('sale')
      .select('COALESCE(SUM(sale.total), 0)', 'revenue')
      .addSelect('COUNT(sale.id)', 'count')
      .where('sale.teamId = :teamId', { teamId })
      .andWhere('sale.status != :cancelled', { cancelled: SaleStatus.CANCELLED })
      .andWhere('sale.createdAt >= :start', { start: yesterdayStart.toISOString() })
      .andWhere('sale.createdAt < :end', { end: todayStart.toISOString() })
      .getRawOne();

    // This week's sales
    const thisWeekResult = await this.salesRepository
      .createQueryBuilder('sale')
      .select('COALESCE(SUM(sale.total), 0)', 'revenue')
      .addSelect('COUNT(sale.id)', 'count')
      .where('sale.teamId = :teamId', { teamId })
      .andWhere('sale.status != :cancelled', { cancelled: SaleStatus.CANCELLED })
      .andWhere('sale.createdAt >= :start', { start: weekStart.toISOString() })
      .andWhere('sale.createdAt < :end', { end: todayEnd.toISOString() })
      .getRawOne();

    // Percent change vs yesterday
    const todayRevenue = parseFloat(todayResult.revenue) || 0;
    const yesterdayRevenue = parseFloat(yesterdayResult.revenue) || 0;
    const percentChange =
      yesterdayRevenue > 0
        ? ((todayRevenue - yesterdayRevenue) / yesterdayRevenue) * 100
        : todayRevenue > 0
          ? 100
          : 0;

    // Revenue history: last 7 days
    const sevenDaysAgo = new Date(todayStart);
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 6);

    const revenueHistoryRaw = await this.salesRepository
      .createQueryBuilder('sale')
      .select('DATE(sale.createdAt)', 'date')
      .addSelect('COALESCE(SUM(sale.total), 0)', 'revenue')
      .where('sale.teamId = :teamId', { teamId })
      .andWhere('sale.status != :cancelled', { cancelled: SaleStatus.CANCELLED })
      .andWhere('sale.createdAt >= :start', { start: sevenDaysAgo.toISOString() })
      .andWhere('sale.createdAt < :end', { end: todayEnd.toISOString() })
      .groupBy('DATE(sale.createdAt)')
      .orderBy('DATE(sale.createdAt)', 'ASC')
      .getRawMany();

    // Fill in missing days with 0
    const revenueHistory: number[] = [];
    for (let i = 0; i < 7; i++) {
      const d = new Date(sevenDaysAgo);
      d.setDate(d.getDate() + i);
      const dateStr = d.toISOString().split('T')[0];
      const found = revenueHistoryRaw.find(
        (r) => r.date === dateStr || (r.date instanceof Date && r.date.toISOString().split('T')[0] === dateStr),
      );
      revenueHistory.push(found ? parseFloat(found.revenue) : 0);
    }

    // Top 5 products by revenue (last 30 days)
    const thirtyDaysAgo = new Date(todayStart);
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const topProducts = await this.saleItemsRepository
      .createQueryBuilder('item')
      .innerJoin('item.sale', 'sale')
      .innerJoin('item.product', 'product')
      .select('product.name', 'name')
      .addSelect('COALESCE(SUM(item.subtotal), 0)', 'revenue')
      .addSelect('COALESCE(SUM(item.quantity), 0)', 'count')
      .where('sale.teamId = :teamId', { teamId })
      .andWhere('sale.status != :cancelled', { cancelled: SaleStatus.CANCELLED })
      .andWhere('sale.createdAt >= :start', { start: thirtyDaysAgo.toISOString() })
      .groupBy('product.name')
      .orderBy('revenue', 'DESC')
      .limit(5)
      .getRawMany();

    // Active credits total pending amount
    const creditsResult = await this.creditsRepository
      .createQueryBuilder('credit')
      .select('COALESCE(SUM(credit.totalAmount - credit.paidAmount), 0)', 'pending')
      .where('credit.teamId = :teamId', { teamId })
      .andWhere('credit.status = :status', { status: CreditStatus.ACTIVE })
      .getRawOne();

    return {
      today: {
        revenue: parseFloat(todayResult.revenue) || 0,
        count: parseInt(todayResult.count, 10) || 0,
      },
      yesterday: {
        revenue: parseFloat(yesterdayResult.revenue) || 0,
        count: parseInt(yesterdayResult.count, 10) || 0,
      },
      thisWeek: {
        revenue: parseFloat(thisWeekResult.revenue) || 0,
        count: parseInt(thisWeekResult.count, 10) || 0,
      },
      percentChange: Math.round(percentChange * 100) / 100,
      revenueHistory,
      topProducts: topProducts.map((p) => ({
        name: p.name,
        revenue: parseFloat(p.revenue) || 0,
        count: parseInt(p.count, 10) || 0,
      })),
      activeCredits: parseFloat(creditsResult.pending) || 0,
    };
  }

  async getSalesAnalytics(
    teamId: string,
    period?: string,
    startDate?: string,
    endDate?: string,
  ) {
    const validPeriod = period || 'daily';
    const now = new Date();
    const defaultEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    const defaultStart = new Date(defaultEnd);
    defaultStart.setDate(defaultStart.getDate() - 30);

    const start = startDate || defaultStart.toISOString().split('T')[0];
    const end = endDate || defaultEnd.toISOString().split('T')[0];

    // Date grouping expression
    let dateExpr: string;
    switch (validPeriod) {
      case 'weekly':
        dateExpr = "TO_CHAR(DATE_TRUNC('week', sale.createdAt), 'YYYY-MM-DD')";
        break;
      case 'monthly':
        dateExpr = "TO_CHAR(DATE_TRUNC('month', sale.createdAt), 'YYYY-MM-DD')";
        break;
      case 'daily':
      default:
        dateExpr = "TO_CHAR(DATE(sale.createdAt), 'YYYY-MM-DD')";
        break;
    }

    // Data points grouped by period
    const dataPoints = await this.salesRepository
      .createQueryBuilder('sale')
      .select(dateExpr, 'date')
      .addSelect('COALESCE(SUM(sale.total), 0)', 'revenue')
      .addSelect('COUNT(sale.id)', 'count')
      .where('sale.teamId = :teamId', { teamId })
      .andWhere('sale.status != :cancelled', { cancelled: SaleStatus.CANCELLED })
      .andWhere('sale.createdAt >= :start', { start })
      .andWhere('sale.createdAt <= :end', { end })
      .groupBy(dateExpr)
      .orderBy(dateExpr, 'ASC')
      .getRawMany();

    // Top products in range
    const topProducts = await this.saleItemsRepository
      .createQueryBuilder('item')
      .innerJoin('item.sale', 'sale')
      .innerJoin('item.product', 'product')
      .select('product.id', 'id')
      .addSelect('product.name', 'name')
      .addSelect('COALESCE(SUM(item.subtotal), 0)', 'revenue')
      .addSelect('COALESCE(SUM(item.quantity), 0)', 'count')
      .where('sale.teamId = :teamId', { teamId })
      .andWhere('sale.status != :cancelled', { cancelled: SaleStatus.CANCELLED })
      .andWhere('sale.createdAt >= :start', { start })
      .andWhere('sale.createdAt <= :end', { end })
      .groupBy('product.id')
      .addGroupBy('product.name')
      .orderBy('revenue', 'DESC')
      .limit(10)
      .getRawMany();

    // Payment methods breakdown
    const paymentMethods = await this.salesRepository
      .createQueryBuilder('sale')
      .select('sale.paymentMethod', 'method')
      .addSelect('COALESCE(SUM(sale.total), 0)', 'total')
      .addSelect('COUNT(sale.id)', 'count')
      .where('sale.teamId = :teamId', { teamId })
      .andWhere('sale.status != :cancelled', { cancelled: SaleStatus.CANCELLED })
      .andWhere('sale.createdAt >= :start', { start })
      .andWhere('sale.createdAt <= :end', { end })
      .groupBy('sale.paymentMethod')
      .orderBy('total', 'DESC')
      .getRawMany();

    // Totals
    const totals = await this.salesRepository
      .createQueryBuilder('sale')
      .select('COALESCE(SUM(sale.total), 0)', 'revenue')
      .addSelect('COUNT(sale.id)', 'count')
      .where('sale.teamId = :teamId', { teamId })
      .andWhere('sale.status != :cancelled', { cancelled: SaleStatus.CANCELLED })
      .andWhere('sale.createdAt >= :start', { start })
      .andWhere('sale.createdAt <= :end', { end })
      .getRawOne();

    return {
      dataPoints: dataPoints.map((dp) => ({
        date: dp.date,
        revenue: parseFloat(dp.revenue) || 0,
        count: parseInt(dp.count, 10) || 0,
      })),
      topProducts: topProducts.map((p) => ({
        id: p.id,
        name: p.name,
        revenue: parseFloat(p.revenue) || 0,
        count: parseInt(p.count, 10) || 0,
      })),
      paymentMethods: paymentMethods.map((pm) => ({
        method: pm.method,
        total: parseFloat(pm.total) || 0,
        count: parseInt(pm.count, 10) || 0,
      })),
      totalRevenue: parseFloat(totals.revenue) || 0,
      totalCount: parseInt(totals.count, 10) || 0,
    };
  }

  async getInventoryAnalytics(teamId: string) {
    // Total value and count
    const valueResult = await this.productsRepository
      .createQueryBuilder('product')
      .select('COALESCE(SUM(product.price * product.stock), 0)', 'totalValue')
      .addSelect('COUNT(product.id)', 'totalProducts')
      .where('product.teamId = :teamId', { teamId })
      .andWhere('product.isActive = true')
      .getRawOne();

    // By category
    const byCategory = await this.productsRepository
      .createQueryBuilder('product')
      .leftJoin('product.category', 'category')
      .select("COALESCE(category.name, 'Sin categoría')", 'name')
      .addSelect('COUNT(product.id)', 'count')
      .addSelect('COALESCE(SUM(product.price * product.stock), 0)', 'value')
      .where('product.teamId = :teamId', { teamId })
      .andWhere('product.isActive = true')
      .groupBy('category.name')
      .orderBy('value', 'DESC')
      .getRawMany();

    // Recent movements by type (last 30 days)
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const recentMovements = await this.movementsRepository
      .createQueryBuilder('movement')
      .select('movement.type', 'type')
      .addSelect('COUNT(movement.id)', 'count')
      .where('movement.teamId = :teamId', { teamId })
      .andWhere('movement.createdAt >= :start', {
        start: thirtyDaysAgo.toISOString(),
      })
      .groupBy('movement.type')
      .orderBy('count', 'DESC')
      .getRawMany();

    // Low stock count
    const lowStockResult = await this.productsRepository
      .createQueryBuilder('product')
      .select('COUNT(product.id)', 'count')
      .where('product.teamId = :teamId', { teamId })
      .andWhere('product.isActive = true')
      .andWhere('product.stock <= product.minStock')
      .getRawOne();

    return {
      totalValue: parseFloat(valueResult.totalValue) || 0,
      totalProducts: parseInt(valueResult.totalProducts, 10) || 0,
      byCategory: byCategory.map((c) => ({
        name: c.name,
        count: parseInt(c.count, 10) || 0,
        value: parseFloat(c.value) || 0,
      })),
      recentMovements: recentMovements.map((m) => ({
        type: m.type,
        count: parseInt(m.count, 10) || 0,
      })),
      lowStockCount: parseInt(lowStockResult.count, 10) || 0,
    };
  }
}
