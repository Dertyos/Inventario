import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ExportService } from './export.service';
import { Sale } from '../sales/entities/sale.entity';
import { Product } from '../products/entities/product.entity';
import { InventoryMovement } from '../inventory/entities/inventory-movement.entity';

const TEAM_ID = 'team-uuid-1';

describe('ExportService', () => {
  let service: ExportService;

  const mockSale = {
    id: 'sale-uuid-1',
    saleNumber: 'V-0001',
    total: 999.99,
    paymentMethod: 'cash',
    status: 'completed',
    createdAt: new Date('2026-03-15T10:00:00Z'),
    customer: { name: 'Juan Perez' },
  };

  const mockProduct = {
    id: 'prod-uuid-1',
    sku: 'SKU-001',
    name: 'Laptop',
    price: 999.99,
    cost: 700,
    stock: 10,
    minStock: 5,
    category: { name: 'Electronicos' },
  };

  const mockMovement = {
    id: 'mov-uuid-1',
    type: 'entrada',
    quantity: 20,
    reason: 'Compra inicial',
    createdAt: new Date('2026-03-15T10:00:00Z'),
    product: { name: 'Laptop' },
  };

  const createSalesQB = (sales: any[]) => ({
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    getMany: jest.fn().mockResolvedValue(sales),
  });

  const createProductsQB = (products: any[]) => ({
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    getMany: jest.fn().mockResolvedValue(products),
  });

  const createMovementsQB = (movements: any[]) => ({
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    getMany: jest.fn().mockResolvedValue(movements),
  });

  const mockSalesRepo = {
    createQueryBuilder: jest.fn(),
  };

  const mockProductsRepo = {
    createQueryBuilder: jest.fn(),
  };

  const mockMovementsRepo = {
    createQueryBuilder: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ExportService,
        { provide: getRepositoryToken(Sale), useValue: mockSalesRepo },
        { provide: getRepositoryToken(Product), useValue: mockProductsRepo },
        { provide: getRepositoryToken(InventoryMovement), useValue: mockMovementsRepo },
      ],
    }).compile();

    service = module.get<ExportService>(ExportService);
    jest.clearAllMocks();
  });

  describe('exportSales', () => {
    it('should return valid CSV string with correct headers', async () => {
      mockSalesRepo.createQueryBuilder.mockReturnValue(createSalesQB([mockSale]));

      const result = await service.exportSales(TEAM_ID);

      expect(result).toBeDefined();
      const lines = result.split('\n');
      expect(lines[0]).toBe('fecha,numero,cliente,total,metodo_pago,estado');
    });

    it('should include all sale fields: fecha, numero, cliente, total, metodo, estado', async () => {
      mockSalesRepo.createQueryBuilder.mockReturnValue(createSalesQB([mockSale]));

      const result = await service.exportSales(TEAM_ID);

      const lines = result.split('\n');
      expect(lines).toHaveLength(2);
      const row = lines[1];
      expect(row).toContain('2026-03-15');
      expect(row).toContain('V-0001');
      expect(row).toContain('Juan Perez');
      expect(row).toContain('999.99');
      expect(row).toContain('cash');
      expect(row).toContain('completed');
    });

    it('should filter by date range when startDate and endDate are provided', async () => {
      const qb = createSalesQB([mockSale]);
      mockSalesRepo.createQueryBuilder.mockReturnValue(qb);

      await service.exportSales(TEAM_ID, '2026-01-01', '2026-12-31');

      expect(qb.andWhere).toHaveBeenCalledWith(
        'sale.createdAt >= :startDate',
        { startDate: '2026-01-01' },
      );
      expect(qb.andWhere).toHaveBeenCalledWith(
        'sale.createdAt <= :endDate',
        { endDate: '2026-12-31' },
      );
    });

    it('should not add date filters when no dates are provided', async () => {
      const qb = createSalesQB([mockSale]);
      mockSalesRepo.createQueryBuilder.mockReturnValue(qb);

      await service.exportSales(TEAM_ID);

      expect(qb.andWhere).not.toHaveBeenCalled();
    });

    it('should handle empty sales returning only headers', async () => {
      mockSalesRepo.createQueryBuilder.mockReturnValue(createSalesQB([]));

      const result = await service.exportSales(TEAM_ID);

      const lines = result.split('\n');
      expect(lines).toHaveLength(1);
      expect(lines[0]).toBe('fecha,numero,cliente,total,metodo_pago,estado');
    });

    it('should handle sale without customer name', async () => {
      const saleNoCustomer = { ...mockSale, customer: null };
      mockSalesRepo.createQueryBuilder.mockReturnValue(createSalesQB([saleNoCustomer]));

      const result = await service.exportSales(TEAM_ID);

      const lines = result.split('\n');
      expect(lines).toHaveLength(2);
      // Empty cliente field
      expect(lines[1]).toContain('V-0001,,999.99');
    });

    it('should escape CSV values containing commas in customer name', async () => {
      const saleWithComma = { ...mockSale, customer: { name: 'Perez, Juan' } };
      mockSalesRepo.createQueryBuilder.mockReturnValue(createSalesQB([saleWithComma]));

      const result = await service.exportSales(TEAM_ID);

      const lines = result.split('\n');
      expect(lines[1]).toContain('"Perez, Juan"');
    });

    it('should handle multiple sales correctly', async () => {
      const secondSale = {
        ...mockSale,
        id: 'sale-uuid-2',
        saleNumber: 'V-0002',
        total: 500,
        customer: { name: 'Maria Lopez' },
      };
      mockSalesRepo.createQueryBuilder.mockReturnValue(createSalesQB([mockSale, secondSale]));

      const result = await service.exportSales(TEAM_ID);

      const lines = result.split('\n');
      expect(lines).toHaveLength(3);
      expect(lines[1]).toContain('V-0001');
      expect(lines[2]).toContain('V-0002');
    });
  });

  describe('exportProducts', () => {
    it('should return valid CSV with product headers', async () => {
      mockProductsRepo.createQueryBuilder.mockReturnValue(createProductsQB([mockProduct]));

      const result = await service.exportProducts(TEAM_ID);

      expect(result).toBeDefined();
      const lines = result.split('\n');
      expect(lines[0]).toBe('sku,nombre,categoria,precio,costo,stock,stock_minimo');
    });

    it('should include all product fields in CSV rows', async () => {
      mockProductsRepo.createQueryBuilder.mockReturnValue(createProductsQB([mockProduct]));

      const result = await service.exportProducts(TEAM_ID);

      const lines = result.split('\n');
      expect(lines).toHaveLength(2);
      const row = lines[1];
      expect(row).toContain('SKU-001');
      expect(row).toContain('Laptop');
      expect(row).toContain('Electronicos');
      expect(row).toContain('999.99');
      expect(row).toContain('700');
      expect(row).toContain('10');
      expect(row).toContain('5');
    });

    it('should handle empty products returning only headers', async () => {
      mockProductsRepo.createQueryBuilder.mockReturnValue(createProductsQB([]));

      const result = await service.exportProducts(TEAM_ID);

      const lines = result.split('\n');
      expect(lines).toHaveLength(1);
      expect(lines[0]).toBe('sku,nombre,categoria,precio,costo,stock,stock_minimo');
    });

    it('should handle product without category', async () => {
      const productNoCategory = { ...mockProduct, category: null };
      mockProductsRepo.createQueryBuilder.mockReturnValue(createProductsQB([productNoCategory]));

      const result = await service.exportProducts(TEAM_ID);

      const lines = result.split('\n');
      expect(lines[1]).toContain('SKU-001,Laptop,');
    });

    it('should handle product without cost showing empty value', async () => {
      const productNoCost = { ...mockProduct, cost: null };
      mockProductsRepo.createQueryBuilder.mockReturnValue(createProductsQB([productNoCost]));

      const result = await service.exportProducts(TEAM_ID);

      const lines = result.split('\n');
      // cost should be empty string
      expect(lines[1]).toBe('SKU-001,Laptop,Electronicos,999.99,,10,5');
    });

    it('should escape product names containing commas', async () => {
      const productWithComma = { ...mockProduct, name: 'Laptop, 15 pulgadas' };
      mockProductsRepo.createQueryBuilder.mockReturnValue(createProductsQB([productWithComma]));

      const result = await service.exportProducts(TEAM_ID);

      const lines = result.split('\n');
      expect(lines[1]).toContain('"Laptop, 15 pulgadas"');
    });
  });

  describe('exportInventory', () => {
    it('should return valid CSV with movement headers', async () => {
      mockMovementsRepo.createQueryBuilder.mockReturnValue(createMovementsQB([mockMovement]));

      const result = await service.exportInventory(TEAM_ID);

      expect(result).toBeDefined();
      const lines = result.split('\n');
      expect(lines[0]).toBe('fecha,producto,tipo,cantidad,razon');
      expect(lines).toHaveLength(2);
    });

    it('should include all movement fields in CSV rows', async () => {
      mockMovementsRepo.createQueryBuilder.mockReturnValue(createMovementsQB([mockMovement]));

      const result = await service.exportInventory(TEAM_ID);

      const lines = result.split('\n');
      const row = lines[1];
      expect(row).toContain('2026-03-15');
      expect(row).toContain('Laptop');
      expect(row).toContain('entrada');
      expect(row).toContain('20');
      expect(row).toContain('Compra inicial');
    });

    it('should handle empty movements returning only headers', async () => {
      mockMovementsRepo.createQueryBuilder.mockReturnValue(createMovementsQB([]));

      const result = await service.exportInventory(TEAM_ID);

      const lines = result.split('\n');
      expect(lines).toHaveLength(1);
      expect(lines[0]).toBe('fecha,producto,tipo,cantidad,razon');
    });

    it('should filter by date range when startDate and endDate are provided', async () => {
      const qb = createMovementsQB([mockMovement]);
      mockMovementsRepo.createQueryBuilder.mockReturnValue(qb);

      await service.exportInventory(TEAM_ID, '2026-01-01', '2026-12-31');

      expect(qb.andWhere).toHaveBeenCalledWith(
        'movement.createdAt >= :startDate',
        { startDate: '2026-01-01' },
      );
      expect(qb.andWhere).toHaveBeenCalledWith(
        'movement.createdAt <= :endDate',
        { endDate: '2026-12-31' },
      );
    });

    it('should handle movements without product name', async () => {
      const movementNoProduct = { ...mockMovement, product: null };
      mockMovementsRepo.createQueryBuilder.mockReturnValue(createMovementsQB([movementNoProduct]));

      const result = await service.exportInventory(TEAM_ID);

      const lines = result.split('\n');
      expect(lines).toHaveLength(2);
      // Product name should be empty string
      expect(lines[1]).toContain(',,entrada');
    });

    it('should handle movements without reason', async () => {
      const movementNoReason = { ...mockMovement, reason: null };
      mockMovementsRepo.createQueryBuilder.mockReturnValue(createMovementsQB([movementNoReason]));

      const result = await service.exportInventory(TEAM_ID);

      const lines = result.split('\n');
      expect(lines).toHaveLength(2);
    });

    it('should escape CSV values containing commas in reason', async () => {
      const movementWithComma = {
        ...mockMovement,
        reason: 'Ajuste, inventario inicial',
      };
      mockMovementsRepo.createQueryBuilder.mockReturnValue(
        createMovementsQB([movementWithComma]),
      );

      const result = await service.exportInventory(TEAM_ID);

      const lines = result.split('\n');
      // Reason with comma should be wrapped in quotes
      expect(lines[1]).toContain('"Ajuste, inventario inicial"');
    });
  });
});
