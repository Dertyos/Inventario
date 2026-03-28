import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { AnalyticsService } from './analytics.service';
import { Sale, SaleStatus } from '../sales/entities/sale.entity';
import { SaleItem } from '../sales/entities/sale-item.entity';
import { Product } from '../products/entities/product.entity';
import { InventoryMovement } from '../inventory/entities/inventory-movement.entity';
import { CreditAccount } from '../credits/entities/credit-account.entity';

const TEAM_ID = 'team-uuid-1';

describe('AnalyticsService', () => {
  let service: AnalyticsService;

  // Reusable chainable query builder mock
  const createChainableQB = (rawOneResult: any = null, rawManyResult: any[] = []) => ({
    select: jest.fn().mockReturnThis(),
    addSelect: jest.fn().mockReturnThis(),
    innerJoin: jest.fn().mockReturnThis(),
    leftJoin: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    groupBy: jest.fn().mockReturnThis(),
    addGroupBy: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    getRawOne: jest.fn().mockResolvedValue(rawOneResult),
    getRawMany: jest.fn().mockResolvedValue(rawManyResult),
  });

  let salesQBs: any[];
  let saleItemsQB: any;
  let productsQBs: any[];
  let movementsQB: any;
  let creditsQB: any;

  const mockSalesRepo = {
    createQueryBuilder: jest.fn(),
  };

  const mockSaleItemsRepo = {
    createQueryBuilder: jest.fn(),
  };

  const mockProductsRepo = {
    createQueryBuilder: jest.fn(),
  };

  const mockMovementsRepo = {
    createQueryBuilder: jest.fn(),
  };

  const mockCreditsRepo = {
    createQueryBuilder: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AnalyticsService,
        { provide: getRepositoryToken(Sale), useValue: mockSalesRepo },
        { provide: getRepositoryToken(SaleItem), useValue: mockSaleItemsRepo },
        { provide: getRepositoryToken(Product), useValue: mockProductsRepo },
        { provide: getRepositoryToken(InventoryMovement), useValue: mockMovementsRepo },
        { provide: getRepositoryToken(CreditAccount), useValue: mockCreditsRepo },
      ],
    }).compile();

    service = module.get<AnalyticsService>(AnalyticsService);
    jest.clearAllMocks();
  });

  describe('getSummary', () => {
    beforeEach(() => {
      // getSummary uses Promise.all with 6 salesRepo queries:
      // today, yesterday, thisWeek, prevWeek, last30, prev30
      // then 1 more for revenueHistory (sequential after Promise.all)
      salesQBs = [
        createChainableQB({ revenue: '1500.50', count: '5' }),   // today
        createChainableQB({ revenue: '1200.00', count: '4' }),   // yesterday
        createChainableQB({ revenue: '7500.00', count: '20' }),  // thisWeek
        createChainableQB({ revenue: '6000.00', count: '15' }),  // prevWeek
        createChainableQB({ revenue: '25000.00', count: '80' }), // last30Days
        createChainableQB({ revenue: '20000.00', count: '70' }), // prev30Days
        createChainableQB(null, [                                 // revenueHistory
          { date: new Date().toISOString().split('T')[0], revenue: '1500.50' },
        ]),
        createChainableQB(null, []),                              // monthlyRevenueHistory
      ];

      let salesCallIndex = 0;
      mockSalesRepo.createQueryBuilder.mockImplementation(() => salesQBs[salesCallIndex++]);

      // saleItems: topProducts
      saleItemsQB = createChainableQB(null, [
        { name: 'Laptop', revenue: '5000', count: '10' },
        { name: 'Mouse', revenue: '500', count: '50' },
      ]);
      mockSaleItemsRepo.createQueryBuilder.mockReturnValue(saleItemsQB);

      // credits
      creditsQB = createChainableQB({ pending: '3200.00' });
      mockCreditsRepo.createQueryBuilder.mockReturnValue(creditsQB);
    });

    it('should return correct summary structure with all periods, percentChanges, revenueHistory, topProducts', async () => {
      const result = await service.getSummary(TEAM_ID);

      expect(result).toBeDefined();
      expect(result.today).toBeDefined();
      expect(result.today.revenue).toBe(1500.50);
      expect(result.today.count).toBe(5);
      expect(result.yesterday).toBeDefined();
      expect(result.yesterday.revenue).toBe(1200.00);
      expect(result.yesterday.count).toBe(4);
      expect(result.thisWeek).toBeDefined();
      expect(result.thisWeek.revenue).toBe(7500.00);
      expect(result.thisWeek.count).toBe(20);
      expect(result.last30Days).toBeDefined();
      expect(result.last30Days.revenue).toBe(25000.00);
      expect(result.last30Days.count).toBe(80);
      expect(result.percentChange).toBeDefined();
      expect(typeof result.percentChange).toBe('number');
      expect(result.weekPercentChange).toBeDefined();
      expect(typeof result.weekPercentChange).toBe('number');
      expect(result.monthPercentChange).toBeDefined();
      expect(typeof result.monthPercentChange).toBe('number');
      expect(result.revenueHistory).toBeDefined();
      expect(result.revenueHistory).toHaveLength(7);
      expect(result.topProducts).toBeDefined();
      expect(Array.isArray(result.topProducts)).toBe(true);
      expect(result.activeCredits).toBe(3200.00);
    });

    it('should calculate percent change correctly when yesterday had revenue', async () => {
      const result = await service.getSummary(TEAM_ID);

      // (1500.50 - 1200) / 1200 * 100 = 25.04166...
      const expected = Math.round(((1500.50 - 1200) / 1200) * 100 * 100) / 100;
      expect(result.percentChange).toBe(expected);
    });

    it('should calculate week and month percent changes correctly', async () => {
      const result = await service.getSummary(TEAM_ID);

      // week: (7500 - 6000) / 6000 * 100 = 25
      const expectedWeek = Math.round(((7500 - 6000) / 6000) * 100 * 100) / 100;
      expect(result.weekPercentChange).toBe(expectedWeek);

      // month: (25000 - 20000) / 20000 * 100 = 25
      const expectedMonth = Math.round(((25000 - 20000) / 20000) * 100 * 100) / 100;
      expect(result.monthPercentChange).toBe(expectedMonth);
    });

    it('should return topProducts with name, revenue, and count', async () => {
      const result = await service.getSummary(TEAM_ID);

      expect(result.topProducts).toHaveLength(2);
      expect(result.topProducts[0]).toEqual({
        name: 'Laptop',
        revenue: 5000,
        count: 10,
      });
      expect(result.topProducts[1]).toEqual({
        name: 'Mouse',
        revenue: 500,
        count: 50,
      });
    });

    it('should handle empty sales data with zero values', async () => {
      salesQBs = [
        createChainableQB({ revenue: '0', count: '0' }),   // today
        createChainableQB({ revenue: '0', count: '0' }),   // yesterday
        createChainableQB({ revenue: '0', count: '0' }),   // thisWeek
        createChainableQB({ revenue: '0', count: '0' }),   // prevWeek
        createChainableQB({ revenue: '0', count: '0' }),   // last30
        createChainableQB({ revenue: '0', count: '0' }),   // prev30
        createChainableQB(null, []),                         // revenueHistory (empty)
        createChainableQB(null, []),                         // monthlyRevenueHistory (empty)
      ];

      let salesCallIndex = 0;
      mockSalesRepo.createQueryBuilder.mockImplementation(() => salesQBs[salesCallIndex++]);

      mockSaleItemsRepo.createQueryBuilder.mockReturnValue(
        createChainableQB(null, []),
      );
      mockCreditsRepo.createQueryBuilder.mockReturnValue(
        createChainableQB({ pending: '0' }),
      );

      const result = await service.getSummary(TEAM_ID);

      expect(result.today.revenue).toBe(0);
      expect(result.today.count).toBe(0);
      expect(result.yesterday.revenue).toBe(0);
      expect(result.last30Days.revenue).toBe(0);
      expect(result.percentChange).toBe(0);
      expect(result.weekPercentChange).toBe(0);
      expect(result.monthPercentChange).toBe(0);
      expect(result.revenueHistory).toEqual([0, 0, 0, 0, 0, 0, 0]);
      expect(result.topProducts).toEqual([]);
      expect(result.activeCredits).toBe(0);
    });

    it('should return 100 percent change when yesterday is zero but today has revenue', async () => {
      salesQBs = [
        createChainableQB({ revenue: '500', count: '2' }),  // today
        createChainableQB({ revenue: '0', count: '0' }),    // yesterday
        createChainableQB({ revenue: '500', count: '2' }),  // thisWeek
        createChainableQB({ revenue: '0', count: '0' }),    // prevWeek
        createChainableQB({ revenue: '500', count: '2' }),  // last30
        createChainableQB({ revenue: '0', count: '0' }),    // prev30
        createChainableQB(null, []),                          // revenueHistory
        createChainableQB(null, []),                          // monthlyRevenueHistory
      ];

      let salesCallIndex = 0;
      mockSalesRepo.createQueryBuilder.mockImplementation(() => salesQBs[salesCallIndex++]);

      mockSaleItemsRepo.createQueryBuilder.mockReturnValue(createChainableQB(null, []));
      mockCreditsRepo.createQueryBuilder.mockReturnValue(createChainableQB({ pending: '0' }));

      const result = await service.getSummary(TEAM_ID);

      expect(result.percentChange).toBe(100);
      expect(result.weekPercentChange).toBe(100);
      expect(result.monthPercentChange).toBe(100);
    });

    it('should fill revenue history array to 7 days even when data is sparse', async () => {
      const today = new Date();
      const todayStr = today.toISOString().split('T')[0];
      const twoDaysAgo = new Date(today);
      twoDaysAgo.setDate(twoDaysAgo.getDate() - 2);
      const twoDaysAgoStr = twoDaysAgo.toISOString().split('T')[0];

      salesQBs = [
        createChainableQB({ revenue: '100', count: '1' }),   // today
        createChainableQB({ revenue: '50', count: '1' }),    // yesterday
        createChainableQB({ revenue: '150', count: '2' }),   // thisWeek
        createChainableQB({ revenue: '100', count: '1' }),   // prevWeek
        createChainableQB({ revenue: '300', count: '4' }),   // last30
        createChainableQB({ revenue: '200', count: '3' }),   // prev30
        createChainableQB(null, [                             // revenueHistory
          { date: twoDaysAgoStr, revenue: '50' },
          { date: todayStr, revenue: '100' },
        ]),
        createChainableQB(null, []),                          // monthlyRevenueHistory
      ];

      let salesCallIndex = 0;
      mockSalesRepo.createQueryBuilder.mockImplementation(() => salesQBs[salesCallIndex++]);
      mockSaleItemsRepo.createQueryBuilder.mockReturnValue(createChainableQB(null, []));
      mockCreditsRepo.createQueryBuilder.mockReturnValue(createChainableQB({ pending: '0' }));

      const result = await service.getSummary(TEAM_ID);

      expect(result.revenueHistory).toHaveLength(7);
      // Last element should be today's revenue
      expect(result.revenueHistory[6]).toBe(100);
      // Element 4 (two days ago) should be 50
      expect(result.revenueHistory[4]).toBe(50);
      // Other entries should be 0
      expect(result.revenueHistory[0]).toBe(0);
    });
  });

  describe('getSalesAnalytics', () => {
    beforeEach(() => {
      // getSalesAnalytics calls salesRepo.createQueryBuilder 3 times:
      // dataPoints, paymentMethods, totals
      const dataPointsQB = createChainableQB(null, [
        { date: '2026-03-25', revenue: '1000', count: '3' },
        { date: '2026-03-26', revenue: '1500', count: '5' },
      ]);
      const paymentMethodsQB = createChainableQB(null, [
        { method: 'cash', total: '1500', count: '5' },
        { method: 'card', total: '1000', count: '3' },
      ]);
      const totalsQB = createChainableQB({ revenue: '2500', count: '8' });

      let salesCallIndex = 0;
      const qbs = [dataPointsQB, paymentMethodsQB, totalsQB];
      mockSalesRepo.createQueryBuilder.mockImplementation(() => qbs[salesCallIndex++]);

      // topProducts
      const topProductsQB = createChainableQB(null, [
        { id: 'prod-1', name: 'Laptop', revenue: '2000', count: '4' },
      ]);
      mockSaleItemsRepo.createQueryBuilder.mockReturnValue(topProductsQB);
    });

    it('should return dataPoints, topProducts, and paymentMethods', async () => {
      const result = await service.getSalesAnalytics(TEAM_ID);

      expect(result).toBeDefined();
      expect(result.dataPoints).toHaveLength(2);
      expect(result.dataPoints[0]).toEqual({
        date: '2026-03-25',
        revenue: 1000,
        count: 3,
      });
      expect(result.topProducts).toHaveLength(1);
      expect(result.topProducts[0]).toEqual({
        id: 'prod-1',
        name: 'Laptop',
        revenue: 2000,
        count: 4,
      });
      expect(result.paymentMethods).toHaveLength(2);
      expect(result.paymentMethods[0]).toEqual({
        method: 'cash',
        total: 1500,
        count: 5,
      });
      expect(result.totalRevenue).toBe(2500);
      expect(result.totalCount).toBe(8);
    });

    it('should filter by date range when startDate and endDate are provided', async () => {
      const dataPointsQB = createChainableQB(null, []);
      const paymentMethodsQB = createChainableQB(null, []);
      const totalsQB = createChainableQB({ revenue: '0', count: '0' });

      let salesCallIndex = 0;
      const qbs = [dataPointsQB, paymentMethodsQB, totalsQB];
      mockSalesRepo.createQueryBuilder.mockImplementation(() => qbs[salesCallIndex++]);
      mockSaleItemsRepo.createQueryBuilder.mockReturnValue(createChainableQB(null, []));

      await service.getSalesAnalytics(TEAM_ID, 'daily', '2026-01-01', '2026-01-31');

      // Verify the date range was passed as parameters in andWhere
      expect(dataPointsQB.andWhere).toHaveBeenCalledWith(
        'sale.createdAt >= :start',
        { start: '2026-01-01' },
      );
      expect(dataPointsQB.andWhere).toHaveBeenCalledWith(
        'sale.createdAt <= :end',
        { end: '2026-01-31' },
      );
    });

    it('should use daily date expression for daily period', async () => {
      const dataPointsQB = createChainableQB(null, []);
      const paymentMethodsQB = createChainableQB(null, []);
      const totalsQB = createChainableQB({ revenue: '0', count: '0' });

      let salesCallIndex = 0;
      const qbs = [dataPointsQB, paymentMethodsQB, totalsQB];
      mockSalesRepo.createQueryBuilder.mockImplementation(() => qbs[salesCallIndex++]);
      mockSaleItemsRepo.createQueryBuilder.mockReturnValue(createChainableQB(null, []));

      await service.getSalesAnalytics(TEAM_ID, 'daily');

      expect(dataPointsQB.select).toHaveBeenCalledWith(
        "TO_CHAR(DATE(sale.createdAt), 'YYYY-MM-DD')",
        'date',
      );
    });

    it('should use weekly date expression for weekly period', async () => {
      const dataPointsQB = createChainableQB(null, []);
      const paymentMethodsQB = createChainableQB(null, []);
      const totalsQB = createChainableQB({ revenue: '0', count: '0' });

      let salesCallIndex = 0;
      const qbs = [dataPointsQB, paymentMethodsQB, totalsQB];
      mockSalesRepo.createQueryBuilder.mockImplementation(() => qbs[salesCallIndex++]);
      mockSaleItemsRepo.createQueryBuilder.mockReturnValue(createChainableQB(null, []));

      await service.getSalesAnalytics(TEAM_ID, 'weekly');

      expect(dataPointsQB.select).toHaveBeenCalledWith(
        "TO_CHAR(DATE_TRUNC('week', sale.createdAt), 'YYYY-MM-DD')",
        'date',
      );
    });

    it('should use monthly date expression for monthly period', async () => {
      const dataPointsQB = createChainableQB(null, []);
      const paymentMethodsQB = createChainableQB(null, []);
      const totalsQB = createChainableQB({ revenue: '0', count: '0' });

      let salesCallIndex = 0;
      const qbs = [dataPointsQB, paymentMethodsQB, totalsQB];
      mockSalesRepo.createQueryBuilder.mockImplementation(() => qbs[salesCallIndex++]);
      mockSaleItemsRepo.createQueryBuilder.mockReturnValue(createChainableQB(null, []));

      await service.getSalesAnalytics(TEAM_ID, 'monthly');

      expect(dataPointsQB.select).toHaveBeenCalledWith(
        "TO_CHAR(DATE_TRUNC('month', sale.createdAt), 'YYYY-MM-DD')",
        'date',
      );
    });

    it('should return empty arrays and zero totals when no sales exist', async () => {
      const dataPointsQB = createChainableQB(null, []);
      const paymentMethodsQB = createChainableQB(null, []);
      const totalsQB = createChainableQB({ revenue: '0', count: '0' });

      let salesCallIndex = 0;
      const qbs = [dataPointsQB, paymentMethodsQB, totalsQB];
      mockSalesRepo.createQueryBuilder.mockImplementation(() => qbs[salesCallIndex++]);
      mockSaleItemsRepo.createQueryBuilder.mockReturnValue(createChainableQB(null, []));

      const result = await service.getSalesAnalytics(TEAM_ID);

      expect(result.dataPoints).toEqual([]);
      expect(result.topProducts).toEqual([]);
      expect(result.paymentMethods).toEqual([]);
      expect(result.totalRevenue).toBe(0);
      expect(result.totalCount).toBe(0);
    });

    it('should default to daily period when no period is provided', async () => {
      const dataPointsQB = createChainableQB(null, []);
      const paymentMethodsQB = createChainableQB(null, []);
      const totalsQB = createChainableQB({ revenue: '0', count: '0' });

      let salesCallIndex = 0;
      const qbs = [dataPointsQB, paymentMethodsQB, totalsQB];
      mockSalesRepo.createQueryBuilder.mockImplementation(() => qbs[salesCallIndex++]);
      mockSaleItemsRepo.createQueryBuilder.mockReturnValue(createChainableQB(null, []));

      await service.getSalesAnalytics(TEAM_ID);

      expect(dataPointsQB.select).toHaveBeenCalledWith(
        "TO_CHAR(DATE(sale.createdAt), 'YYYY-MM-DD')",
        'date',
      );
    });
  });

  describe('getInventoryAnalytics', () => {
    beforeEach(() => {
      // getInventoryAnalytics calls productsRepo.createQueryBuilder 3 times:
      // totalValue, byCategory, lowStock
      const valueQB = createChainableQB({ totalValue: '50000', totalProducts: '25' });
      const categoryQB = createChainableQB(null, [
        { name: 'Electronicos', count: '10', value: '30000' },
        { name: 'Accesorios', count: '15', value: '20000' },
      ]);
      const lowStockQB = createChainableQB({ count: '3' });

      let productsCallIndex = 0;
      const qbs = [valueQB, categoryQB, lowStockQB];
      mockProductsRepo.createQueryBuilder.mockImplementation(() => qbs[productsCallIndex++]);

      // recentMovements
      const movementsQBInst = createChainableQB(null, [
        { type: 'entrada', count: '15' },
        { type: 'salida', count: '10' },
      ]);
      mockMovementsRepo.createQueryBuilder.mockReturnValue(movementsQBInst);
    });

    it('should return totalValue, byCategory, recentMovements, and lowStockCount', async () => {
      const result = await service.getInventoryAnalytics(TEAM_ID);

      expect(result).toBeDefined();
      expect(result.totalValue).toBe(50000);
      expect(result.totalProducts).toBe(25);
      expect(result.byCategory).toHaveLength(2);
      expect(result.byCategory[0]).toEqual({
        name: 'Electronicos',
        count: 10,
        value: 30000,
      });
      expect(result.byCategory[1]).toEqual({
        name: 'Accesorios',
        count: 15,
        value: 20000,
      });
      expect(result.recentMovements).toHaveLength(2);
      expect(result.recentMovements[0]).toEqual({
        type: 'entrada',
        count: 15,
      });
      expect(result.lowStockCount).toBe(3);
    });

    it('should handle empty products and movements with zero values', async () => {
      const valueQB = createChainableQB({ totalValue: '0', totalProducts: '0' });
      const categoryQB = createChainableQB(null, []);
      const lowStockQB = createChainableQB({ count: '0' });

      let productsCallIndex = 0;
      const qbs = [valueQB, categoryQB, lowStockQB];
      mockProductsRepo.createQueryBuilder.mockImplementation(() => qbs[productsCallIndex++]);
      mockMovementsRepo.createQueryBuilder.mockReturnValue(createChainableQB(null, []));

      const result = await service.getInventoryAnalytics(TEAM_ID);

      expect(result.totalValue).toBe(0);
      expect(result.totalProducts).toBe(0);
      expect(result.byCategory).toEqual([]);
      expect(result.recentMovements).toEqual([]);
      expect(result.lowStockCount).toBe(0);
    });

    it('should parse numeric strings to proper numbers', async () => {
      const result = await service.getInventoryAnalytics(TEAM_ID);

      expect(typeof result.totalValue).toBe('number');
      expect(typeof result.totalProducts).toBe('number');
      expect(typeof result.byCategory[0].count).toBe('number');
      expect(typeof result.byCategory[0].value).toBe('number');
      expect(typeof result.recentMovements[0].count).toBe('number');
      expect(typeof result.lowStockCount).toBe('number');
    });
  });
});
