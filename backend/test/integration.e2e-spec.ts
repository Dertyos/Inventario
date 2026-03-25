import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { createTestApp, cleanDatabase } from './test-utils';

/**
 * Full end-to-end integration tests for the Inventario backend.
 *
 * The tests run sequentially and exercise the complete business flow:
 *   register -> login -> create team -> categories -> products
 *   -> inventory -> customers -> sales -> payments -> credits
 *
 * A real PostgreSQL database (from docker-compose) is used so that
 * enum types, UUID generation, pessimistic locks, and transactions
 * behave exactly as they do in production.
 */
describe('Inventario Integration (e2e)', () => {
  let app: INestApplication;

  // Shared state across ordered test groups
  let accessToken: string;
  let userId: string;
  let teamId: string;
  let categoryId: string;
  let productId: string;
  let customerId: string;
  let saleId: string;

  beforeAll(async () => {
    app = await createTestApp();
    await cleanDatabase(app);
  });

  afterAll(async () => {
    await cleanDatabase(app);
    await app.close();
  });

  // ────────────────────────────────────────────
  //  AUTH FLOW
  // ────────────────────────────────────────────
  describe('Auth', () => {
    const testUser = {
      email: 'test@tienda.co',
      password: 'Test1234!',
      firstName: 'Carlos',
      lastName: 'Gómez',
    };

    it('POST /auth/register - should register a new user', async () => {
      const res = await request(app.getHttpServer())
        .post('/auth/register')
        .send(testUser)
        .expect(201);

      expect(res.body).toHaveProperty('accessToken');
      expect(res.body.user).toMatchObject({
        email: testUser.email,
        firstName: testUser.firstName,
        lastName: testUser.lastName,
      });
      expect(res.body.user).toHaveProperty('id');

      accessToken = res.body.accessToken;
      userId = res.body.user.id;
    });

    it('POST /auth/register - should reject duplicate email (409)', async () => {
      const res = await request(app.getHttpServer())
        .post('/auth/register')
        .send(testUser)
        .expect(409);

      expect(res.body.message).toContain('Email already registered');
    });

    it('POST /auth/register - should reject invalid email (400)', async () => {
      await request(app.getHttpServer())
        .post('/auth/register')
        .send({
          email: 'not-an-email',
          password: 'Test1234!',
          firstName: 'Test',
          lastName: 'User',
        })
        .expect(400);
    });

    it('POST /auth/register - should reject short password (400)', async () => {
      await request(app.getHttpServer())
        .post('/auth/register')
        .send({
          email: 'short@tienda.co',
          password: '123',
          firstName: 'Test',
          lastName: 'User',
        })
        .expect(400);
    });

    it('POST /auth/register - should reject missing fields (400)', async () => {
      await request(app.getHttpServer())
        .post('/auth/register')
        .send({ email: 'missing@tienda.co' })
        .expect(400);
    });

    it('POST /auth/login - should login with valid credentials', async () => {
      const res = await request(app.getHttpServer())
        .post('/auth/login')
        .send({
          email: testUser.email,
          password: testUser.password,
        })
        .expect(201);

      expect(res.body).toHaveProperty('accessToken');
      expect(res.body.user.email).toBe(testUser.email);

      // Refresh token from login
      accessToken = res.body.accessToken;
    });

    it('POST /auth/login - should reject wrong password (401)', async () => {
      const res = await request(app.getHttpServer())
        .post('/auth/login')
        .send({
          email: testUser.email,
          password: 'WrongPassword99!',
        })
        .expect(401);

      expect(res.body.message).toBe('Invalid credentials');
    });

    it('POST /auth/login - should reject non-existent email (401)', async () => {
      await request(app.getHttpServer())
        .post('/auth/login')
        .send({
          email: 'nobody@tienda.co',
          password: 'Test1234!',
        })
        .expect(401);
    });

    it('GET /auth/profile - should return current user profile', async () => {
      const res = await request(app.getHttpServer())
        .get('/auth/profile')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(res.body).toMatchObject({
        id: userId,
        email: testUser.email,
        firstName: testUser.firstName,
        lastName: testUser.lastName,
      });
    });

    it('GET /auth/profile - should reject request without token (401)', async () => {
      await request(app.getHttpServer()).get('/auth/profile').expect(401);
    });

    it('GET /auth/profile - should reject invalid token (401)', async () => {
      await request(app.getHttpServer())
        .get('/auth/profile')
        .set('Authorization', 'Bearer invalid-token-string')
        .expect(401);
    });
  });

  // ────────────────────────────────────────────
  //  TEAMS FLOW
  // ────────────────────────────────────────────
  describe('Teams', () => {
    it('POST /teams - should create a team', async () => {
      const res = await request(app.getHttpServer())
        .post('/teams')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          name: 'Tienda Don Carlos',
          currency: 'COP',
          timezone: 'America/Bogota',
        })
        .expect(201);

      expect(res.body.name).toBe('Tienda Don Carlos');
      expect(res.body).toHaveProperty('id');
      expect(res.body).toHaveProperty('slug');
      expect(res.body.members).toBeDefined();
      // The creator should be an OWNER member
      expect(res.body.members.length).toBeGreaterThanOrEqual(1);

      teamId = res.body.id;
    });

    it('POST /teams - should reject duplicate team name (409)', async () => {
      const res = await request(app.getHttpServer())
        .post('/teams')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ name: 'Tienda Don Carlos' })
        .expect(409);

      expect(res.body.message).toContain('similar name already exists');
    });

    it('POST /teams - should reject without auth (401)', async () => {
      await request(app.getHttpServer())
        .post('/teams')
        .send({ name: 'Unauthorized Team' })
        .expect(401);
    });

    it('GET /teams - should list user teams', async () => {
      const res = await request(app.getHttpServer())
        .get('/teams')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(1);
      expect(res.body[0].name).toBe('Tienda Don Carlos');
    });

    it('GET /teams/:teamId - should get team details', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(res.body.name).toBe('Tienda Don Carlos');
      expect(res.body.settings).toBeDefined();
      expect(res.body.members).toBeDefined();
    });

    it('PATCH /teams/:teamId - should update team', async () => {
      const res = await request(app.getHttpServer())
        .patch(`/teams/${teamId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ currency: 'USD' })
        .expect(200);

      expect(res.body.currency).toBe('USD');
    });

    it('GET /teams/:teamId/settings - should get team settings', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/settings`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(res.body).toHaveProperty('teamId', teamId);
    });

    it('GET /teams/:teamId/members - should list team members', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/members`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(1);
      expect(res.body[0].role).toBe('owner');
    });
  });

  // ────────────────────────────────────────────
  //  CATEGORIES FLOW
  // ────────────────────────────────────────────
  describe('Categories', () => {
    it('POST /teams/:teamId/categories - should create a category', async () => {
      const res = await request(app.getHttpServer())
        .post(`/teams/${teamId}/categories`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          name: 'Bebidas',
          description: 'Bebidas frías y calientes',
          color: '#FF6B35',
        })
        .expect(201);

      expect(res.body.name).toBe('Bebidas');
      expect(res.body.description).toBe('Bebidas frías y calientes');
      expect(res.body.color).toBe('#FF6B35');
      expect(res.body).toHaveProperty('id');

      categoryId = res.body.id;
    });

    it('POST /teams/:teamId/categories - should create a second category', async () => {
      const res = await request(app.getHttpServer())
        .post(`/teams/${teamId}/categories`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ name: 'Snacks' })
        .expect(201);

      expect(res.body.name).toBe('Snacks');
    });

    it('GET /teams/:teamId/categories - should list all categories', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/categories`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(2);
    });

    it('GET /teams/:teamId/categories/:id - should get single category', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/categories/${categoryId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(res.body.name).toBe('Bebidas');
    });

    it('PATCH /teams/:teamId/categories/:id - should update category', async () => {
      const res = await request(app.getHttpServer())
        .patch(`/teams/${teamId}/categories/${categoryId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ color: '#00FF00' })
        .expect(200);

      expect(res.body.color).toBe('#00FF00');
    });
  });

  // ────────────────────────────────────────────
  //  PRODUCTS FLOW
  // ────────────────────────────────────────────
  describe('Products', () => {
    it('POST /teams/:teamId/products - should create a product', async () => {
      const res = await request(app.getHttpServer())
        .post(`/teams/${teamId}/products`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          sku: 'BEB-001',
          name: 'Coca-Cola 350ml',
          price: 2500,
          cost: 1800,
          minStock: 10,
          categoryId: categoryId,
        })
        .expect(201);

      expect(res.body.name).toBe('Coca-Cola 350ml');
      expect(res.body.sku).toBe('BEB-001');
      expect(res.body.stock).toBe(0);
      expect(res.body.isActive).toBe(true);
      expect(res.body).toHaveProperty('id');

      productId = res.body.id;
    });

    it('POST /teams/:teamId/products - should reject duplicate SKU (409)', async () => {
      const res = await request(app.getHttpServer())
        .post(`/teams/${teamId}/products`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          sku: 'BEB-001',
          name: 'Duplicate SKU',
          price: 1000,
          categoryId: categoryId,
        })
        .expect(409);

      expect(res.body.message).toContain('SKU already exists');
    });

    it('POST /teams/:teamId/products - should reject negative price (400)', async () => {
      await request(app.getHttpServer())
        .post(`/teams/${teamId}/products`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          sku: 'TEST-NEG',
          name: 'Invalid Product',
          price: -100,
          categoryId: categoryId,
        })
        .expect(400);
    });

    it('POST /teams/:teamId/products - should reject missing required fields (400)', async () => {
      await request(app.getHttpServer())
        .post(`/teams/${teamId}/products`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ name: 'No SKU or price' })
        .expect(400);
    });

    it('GET /teams/:teamId/products - should list products', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/products`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(1);
      expect(res.body[0].name).toBe('Coca-Cola 350ml');
    });

    it('GET /teams/:teamId/products/:id - should get single product', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/products/${productId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(res.body.name).toBe('Coca-Cola 350ml');
      expect(res.body.category).toBeDefined();
    });

    it('PATCH /teams/:teamId/products/:id - should update product price', async () => {
      const res = await request(app.getHttpServer())
        .patch(`/teams/${teamId}/products/${productId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ price: 3000 })
        .expect(200);

      // TypeORM decimal columns come back as strings or numbers
      expect(Number(res.body.price)).toBe(3000);
    });

    it('GET /teams/:teamId/products/low-stock - should show low-stock products', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/products/low-stock`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      // Product has stock=0, minStock=10 => low stock
      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBeGreaterThanOrEqual(1);
      expect(res.body.find((p: any) => p.id === productId)).toBeDefined();
    });
  });

  // ────────────────────────────────────────────
  //  INVENTORY FLOW
  // ────────────────────────────────────────────
  describe('Inventory', () => {
    it('POST /teams/:teamId/inventory/movements - should add stock (type=in)', async () => {
      const res = await request(app.getHttpServer())
        .post(`/teams/${teamId}/inventory/movements`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          productId: productId,
          type: 'in',
          quantity: 50,
          reason: 'Compra inicial',
        })
        .expect(201);

      expect(res.body.stockBefore).toBe(0);
      expect(res.body.stockAfter).toBe(50);
      expect(res.body.type).toBe('in');
      expect(res.body.quantity).toBe(50);
    });

    it('POST /teams/:teamId/inventory/movements - should remove stock (type=out)', async () => {
      const res = await request(app.getHttpServer())
        .post(`/teams/${teamId}/inventory/movements`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          productId: productId,
          type: 'out',
          quantity: 5,
          reason: 'Producto dañado',
        })
        .expect(201);

      expect(res.body.stockBefore).toBe(50);
      expect(res.body.stockAfter).toBe(45);
    });

    it('POST /teams/:teamId/inventory/movements - should reject insufficient stock for out', async () => {
      await request(app.getHttpServer())
        .post(`/teams/${teamId}/inventory/movements`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          productId: productId,
          type: 'out',
          quantity: 999,
          reason: 'Too much',
        })
        .expect(400);
    });

    it('POST /teams/:teamId/inventory/movements - should adjust stock (type=adjustment)', async () => {
      const res = await request(app.getHttpServer())
        .post(`/teams/${teamId}/inventory/movements`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          productId: productId,
          type: 'adjustment',
          quantity: 100,
          reason: 'Conteo físico',
        })
        .expect(201);

      expect(res.body.stockBefore).toBe(45);
      expect(res.body.stockAfter).toBe(100);
    });

    it('GET /teams/:teamId/inventory/movements - should list all movements', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/inventory/movements`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(3);
    });

    it('GET /teams/:teamId/inventory/movements?productId= - should filter by product', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/inventory/movements`)
        .query({ productId })
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(res.body.length).toBe(3);
      for (const m of res.body) {
        expect(m.productId).toBe(productId);
      }
    });

    it('should reflect correct product stock after movements', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/products/${productId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(res.body.stock).toBe(100);
    });
  });

  // ────────────────────────────────────────────
  //  CUSTOMERS FLOW
  // ────────────────────────────────────────────
  describe('Customers', () => {
    it('POST /teams/:teamId/customers - should create a customer', async () => {
      const res = await request(app.getHttpServer())
        .post(`/teams/${teamId}/customers`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          name: 'María López',
          phone: '3001234567',
          documentType: 'CC',
          documentNumber: '1234567890',
        })
        .expect(201);

      expect(res.body.name).toBe('María López');
      expect(res.body.phone).toBe('3001234567');
      expect(res.body.documentType).toBe('CC');
      expect(res.body).toHaveProperty('id');

      customerId = res.body.id;
    });

    it('POST /teams/:teamId/customers - should reject duplicate document (409)', async () => {
      const res = await request(app.getHttpServer())
        .post(`/teams/${teamId}/customers`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          name: 'Duplicate',
          documentType: 'CC',
          documentNumber: '1234567890',
        })
        .expect(409);

      expect(res.body.message).toContain('document already exists');
    });

    it('POST /teams/:teamId/customers - should create customer without document', async () => {
      const res = await request(app.getHttpServer())
        .post(`/teams/${teamId}/customers`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ name: 'Walk-in Customer' })
        .expect(201);

      expect(res.body.name).toBe('Walk-in Customer');
    });

    it('GET /teams/:teamId/customers - should list customers', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/customers`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(2);
    });

    it('GET /teams/:teamId/customers?search= - should search customers', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/customers`)
        .query({ search: 'María' })
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(res.body.length).toBe(1);
      expect(res.body[0].name).toBe('María López');
    });

    it('GET /teams/:teamId/customers/:id - should get customer details', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/customers/${customerId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(res.body.name).toBe('María López');
    });

    it('PATCH /teams/:teamId/customers/:id - should update customer', async () => {
      const res = await request(app.getHttpServer())
        .patch(`/teams/${teamId}/customers/${customerId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ address: 'Cra 7 #32-16, Bogotá' })
        .expect(200);

      expect(res.body.address).toBe('Cra 7 #32-16, Bogotá');
    });
  });

  // ────────────────────────────────────────────
  //  SALES FLOW
  // ────────────────────────────────────────────
  describe('Sales', () => {
    it('POST /teams/:teamId/sales - should create a cash sale', async () => {
      const res = await request(app.getHttpServer())
        .post(`/teams/${teamId}/sales`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          customerId: customerId,
          items: [
            {
              productId: productId,
              quantity: 5,
              unitPrice: 3000,
            },
          ],
          paymentMethod: 'cash',
        })
        .expect(201);

      expect(Number(res.body.total)).toBe(15000);
      expect(Number(res.body.subtotal)).toBe(15000);
      expect(res.body.status).toBe('completed');
      expect(res.body.paymentMethod).toBe('cash');
      expect(res.body.saleNumber).toBeDefined();
      expect(res.body.items).toBeDefined();
      expect(res.body.items.length).toBe(1);
      expect(res.body).toHaveProperty('id');

      saleId = res.body.id;
    });

    it('POST /teams/:teamId/sales - should reject empty items (400)', async () => {
      const res = await request(app.getHttpServer())
        .post(`/teams/${teamId}/sales`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          items: [],
          paymentMethod: 'cash',
        })
        .expect(400);

      expect(res.body.message).toContain('at least one item');
    });

    it('POST /teams/:teamId/sales - should reject insufficient stock', async () => {
      await request(app.getHttpServer())
        .post(`/teams/${teamId}/sales`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          items: [
            {
              productId: productId,
              quantity: 9999,
              unitPrice: 3000,
            },
          ],
          paymentMethod: 'cash',
        })
        .expect(400);
    });

    it('should have deducted stock after sale', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/products/${productId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      // Was 100 after adjustment, sold 5
      expect(res.body.stock).toBe(95);
    });

    it('GET /teams/:teamId/sales - should list sales', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/sales`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(1);
    });

    it('GET /teams/:teamId/sales/:id - should get sale with items', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/sales/${saleId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(res.body.items).toBeDefined();
      expect(res.body.items.length).toBe(1);
      expect(res.body.items[0].productId).toBe(productId);
      expect(res.body.customer).toBeDefined();
      expect(res.body.customer.id).toBe(customerId);
    });

    it('POST /teams/:teamId/sales - should create sale without customer', async () => {
      const res = await request(app.getHttpServer())
        .post(`/teams/${teamId}/sales`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          items: [
            {
              productId: productId,
              quantity: 2,
              unitPrice: 3000,
            },
          ],
          paymentMethod: 'cash',
        })
        .expect(201);

      expect(Number(res.body.total)).toBe(6000);
      expect(res.body.customerId).toBeNull();
    });

    it('PATCH /teams/:teamId/sales/:id/cancel - should cancel a sale and restore stock', async () => {
      // Check stock before cancel
      const before = await request(app.getHttpServer())
        .get(`/teams/${teamId}/products/${productId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      const stockBefore = before.body.stock;

      const res = await request(app.getHttpServer())
        .patch(`/teams/${teamId}/sales/${saleId}/cancel`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(res.body.status).toBe('cancelled');

      // Stock should be restored
      const after = await request(app.getHttpServer())
        .get(`/teams/${teamId}/products/${productId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(after.body.stock).toBe(stockBefore + 5); // original sale had 5 items
    });

    it('PATCH /teams/:teamId/sales/:id/cancel - should reject cancelling already cancelled sale', async () => {
      await request(app.getHttpServer())
        .patch(`/teams/${teamId}/sales/${saleId}/cancel`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(400);
    });
  });

  // ────────────────────────────────────────────
  //  PAYMENTS FLOW
  // ────────────────────────────────────────────
  describe('Payments', () => {
    let newSaleId: string;

    it('should create a sale to make payments against', async () => {
      const res = await request(app.getHttpServer())
        .post(`/teams/${teamId}/sales`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          customerId: customerId,
          items: [
            { productId: productId, quantity: 3, unitPrice: 3000 },
          ],
          paymentMethod: 'cash',
        })
        .expect(201);

      newSaleId = res.body.id;
    });

    it('POST /teams/:teamId/payments - should record a payment', async () => {
      const res = await request(app.getHttpServer())
        .post(`/teams/${teamId}/payments`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          saleId: newSaleId,
          amount: 9000,
          method: 'cash',
        })
        .expect(201);

      expect(Number(res.body.amount)).toBe(9000);
      expect(res.body.method).toBe('cash');
      expect(res.body.saleId).toBe(newSaleId);
      expect(res.body).toHaveProperty('id');
      expect(res.body).toHaveProperty('paidAt');
    });

    it('POST /teams/:teamId/payments - should record a transfer payment', async () => {
      const res = await request(app.getHttpServer())
        .post(`/teams/${teamId}/payments`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          saleId: newSaleId,
          amount: 5000,
          method: 'transfer',
          reference: 'TXN-12345',
          notes: 'Nequi transfer',
        })
        .expect(201);

      expect(res.body.method).toBe('transfer');
      expect(res.body.reference).toBe('TXN-12345');
    });

    it('GET /teams/:teamId/payments - should list all payments', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/payments`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(2);
    });

    it('GET /teams/:teamId/payments?saleId= - should filter payments by sale', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/payments`)
        .query({ saleId: newSaleId })
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(res.body.length).toBe(2);
      for (const p of res.body) {
        expect(p.saleId).toBe(newSaleId);
      }
    });
  });

  // ────────────────────────────────────────────
  //  CREDITS FLOW
  // ────────────────────────────────────────────
  describe('Credits', () => {
    let creditSaleId: string;
    let creditId: string;

    it('should create a credit sale', async () => {
      const res = await request(app.getHttpServer())
        .post(`/teams/${teamId}/sales`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          customerId: customerId,
          items: [
            { productId: productId, quantity: 10, unitPrice: 3000 },
          ],
          paymentMethod: 'credit',
        })
        .expect(201);

      creditSaleId = res.body.id;
      expect(Number(res.body.total)).toBe(30000);
      expect(res.body.paymentMethod).toBe('credit');
    });

    it('POST /teams/:teamId/credits - should create credit account with installments', async () => {
      const res = await request(app.getHttpServer())
        .post(`/teams/${teamId}/credits`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          saleId: creditSaleId,
          customerId: customerId,
          totalAmount: 30000,
          interestType: 'none',
          installments: 3,
        })
        .expect(201);

      expect(Number(res.body.totalAmount)).toBe(30000);
      expect(res.body.status).toBe('active');
      expect(res.body.installments).toBe(3);
      expect(res.body.creditInstallments).toBeDefined();
      expect(res.body.creditInstallments.length).toBe(3);

      // Each installment should be 10000
      for (const inst of res.body.creditInstallments) {
        expect(Number(inst.amount)).toBe(10000);
        expect(inst.status).toBe('pending');
      }

      creditId = res.body.id;
    });

    it('GET /teams/:teamId/credits - should list credits', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/credits`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBe(1);
      expect(res.body[0].id).toBe(creditId);
    });

    it('GET /teams/:teamId/credits/:id - should get credit with installments', async () => {
      const res = await request(app.getHttpServer())
        .get(`/teams/${teamId}/credits/${creditId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(res.body.creditInstallments).toBeDefined();
      expect(res.body.creditInstallments.length).toBe(3);
      expect(res.body.customer).toBeDefined();
      expect(res.body.customer.id).toBe(customerId);
    });

    it('POST /teams/:teamId/credits/:id/installments/:installmentId/pay - should pay an installment', async () => {
      // Get installment IDs
      const creditRes = await request(app.getHttpServer())
        .get(`/teams/${teamId}/credits/${creditId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      const firstInstallment = creditRes.body.creditInstallments[0];

      const res = await request(app.getHttpServer())
        .post(
          `/teams/${teamId}/credits/${creditId}/installments/${firstInstallment.id}/pay`,
        )
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ amount: 10000 })
        .expect(201);

      // First installment should be paid
      const paidInstallment = res.body.creditInstallments.find(
        (i: any) => i.id === firstInstallment.id,
      );
      expect(paidInstallment.status).toBe('paid');
      expect(Number(res.body.paidAmount)).toBe(10000);
      // Credit should still be active (2 installments remain)
      expect(res.body.status).toBe('active');
    });

    it('should mark credit as paid when all installments are paid', async () => {
      // Get current credit state
      const creditRes = await request(app.getHttpServer())
        .get(`/teams/${teamId}/credits/${creditId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      const pendingInstallments = creditRes.body.creditInstallments.filter(
        (i: any) => i.status !== 'paid',
      );

      // Pay remaining installments
      for (const inst of pendingInstallments) {
        await request(app.getHttpServer())
          .post(
            `/teams/${teamId}/credits/${creditId}/installments/${inst.id}/pay`,
          )
          .set('Authorization', `Bearer ${accessToken}`)
          .send({ amount: Number(inst.amount) })
          .expect(201);
      }

      // Check final credit status
      const finalRes = await request(app.getHttpServer())
        .get(`/teams/${teamId}/credits/${creditId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(finalRes.body.status).toBe('paid');
      expect(Number(finalRes.body.paidAmount)).toBe(30000);
    });
  });

  // ────────────────────────────────────────────
  //  CROSS-CUTTING / AUTHORIZATION TESTS
  // ────────────────────────────────────────────
  describe('Authorization & Access Control', () => {
    let otherToken: string;

    it('should register a second user', async () => {
      const res = await request(app.getHttpServer())
        .post('/auth/register')
        .send({
          email: 'other@tienda.co',
          password: 'Other1234!',
          firstName: 'Ana',
          lastName: 'Ruiz',
        })
        .expect(201);

      otherToken = res.body.accessToken;
    });

    it('should deny non-member access to team resources (403)', async () => {
      await request(app.getHttpServer())
        .get(`/teams/${teamId}/products`)
        .set('Authorization', `Bearer ${otherToken}`)
        .expect(403);
    });

    it('should deny non-member access to categories (403)', async () => {
      await request(app.getHttpServer())
        .get(`/teams/${teamId}/categories`)
        .set('Authorization', `Bearer ${otherToken}`)
        .expect(403);
    });

    it('should deny non-member access to customers (403)', async () => {
      await request(app.getHttpServer())
        .get(`/teams/${teamId}/customers`)
        .set('Authorization', `Bearer ${otherToken}`)
        .expect(403);
    });

    it('should deny non-member access to sales (403)', async () => {
      await request(app.getHttpServer())
        .get(`/teams/${teamId}/sales`)
        .set('Authorization', `Bearer ${otherToken}`)
        .expect(403);
    });
  });

  // ────────────────────────────────────────────
  //  ADDITIONAL VALIDATION TESTS
  // ────────────────────────────────────────────
  describe('Validation', () => {
    it('should reject register with extra/unknown fields (400)', async () => {
      await request(app.getHttpServer())
        .post('/auth/register')
        .send({
          email: 'extra@tienda.co',
          password: 'Test1234!',
          firstName: 'Test',
          lastName: 'User',
          unknownField: 'should not be here',
        })
        .expect(400);
    });

    it('should reject creating product with non-UUID categoryId (400)', async () => {
      await request(app.getHttpServer())
        .post(`/teams/${teamId}/products`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          sku: 'VAL-001',
          name: 'Validation Product',
          price: 100,
          categoryId: 'not-a-uuid',
        })
        .expect(400);
    });

    it('should reject inventory movement with quantity 0 (400)', async () => {
      await request(app.getHttpServer())
        .post(`/teams/${teamId}/inventory/movements`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          productId: productId,
          type: 'in',
          quantity: 0,
        })
        .expect(400);
    });

    it('should reject inventory movement with invalid type (400)', async () => {
      await request(app.getHttpServer())
        .post(`/teams/${teamId}/inventory/movements`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          productId: productId,
          type: 'invalid_type',
          quantity: 10,
        })
        .expect(400);
    });

    it('should reject payment with amount 0 (400)', async () => {
      await request(app.getHttpServer())
        .post(`/teams/${teamId}/payments`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          amount: 0,
          method: 'cash',
        })
        .expect(400);
    });

    it('should reject credit with 0 installments (400)', async () => {
      await request(app.getHttpServer())
        .post(`/teams/${teamId}/credits`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          saleId: saleId,
          customerId: customerId,
          totalAmount: 10000,
          installments: 0,
        })
        .expect(400);
    });

    it('should reject team creation with short name (400)', async () => {
      await request(app.getHttpServer())
        .post('/teams')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ name: 'A' })
        .expect(400);
    });

    it('should return 404 for non-existent product UUID', async () => {
      await request(app.getHttpServer())
        .get(`/teams/${teamId}/products/00000000-0000-0000-0000-000000000000`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(404);
    });

    it('should return 404 for non-existent sale UUID', async () => {
      await request(app.getHttpServer())
        .get(`/teams/${teamId}/sales/00000000-0000-0000-0000-000000000000`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(404);
    });

    it('should return 400 for invalid UUID in path params', async () => {
      await request(app.getHttpServer())
        .get(`/teams/${teamId}/products/not-a-uuid`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(400);
    });
  });
});
