import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { createTestApp, cleanDatabase } from './test-utils';

describe('App (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    app = await createTestApp();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET / - should return hello message', () => {
    return request(app.getHttpServer())
      .get('/')
      .expect(200)
      .expect('Hello World!');
  });

  it('GET /health - should return ok status', () => {
    return request(app.getHttpServer())
      .get('/health')
      .expect(200)
      .expect({ status: 'ok' });
  });

  it('GET /auth/profile - should reject unauthenticated request', () => {
    return request(app.getHttpServer()).get('/auth/profile').expect(401);
  });

  it('GET /nonexistent - should return 404', () => {
    return request(app.getHttpServer()).get('/nonexistent').expect(404);
  });
});
