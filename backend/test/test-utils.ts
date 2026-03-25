import * as path from 'path';
import * as fs from 'fs';
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { DataSource } from 'typeorm';

// ── Load .env.test before anything else ──────────────────────────
// ConfigModule.forRoot() in AppModule honours process.env when
// envFilePath is not set.  By populating process.env here we make
// sure the test database URL and JWT secret are picked up.
const envTestPath = path.resolve(__dirname, '..', '.env.test');
if (fs.existsSync(envTestPath)) {
  const envContent = fs.readFileSync(envTestPath, 'utf-8');
  for (const line of envContent.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx === -1) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    const value = trimmed.slice(eqIdx + 1).trim();
    // Only set if not already defined (allows CI to override)
    if (process.env[key] === undefined) {
      process.env[key] = value;
    }
  }
}

// Import AppModule *after* env vars are loaded so ConfigService
// sees the test values during module initialisation.
import { AppModule } from '../src/app.module';

/**
 * Creates a fully bootstrapped NestJS application for E2E testing.
 *
 * Uses the real AppModule with the PostgreSQL test database defined
 * in `.env.test`.  Global validation pipes are applied to match
 * production behavior.
 */
export async function createTestApp(): Promise<INestApplication> {
  const moduleFixture: TestingModule = await Test.createTestingModule({
    imports: [AppModule],
  }).compile();

  const app = moduleFixture.createNestApplication();

  // Match the global pipes used in main.ts
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  await app.init();
  return app;
}

/**
 * Truncates every table in the database (CASCADE) so each test suite
 * starts from a clean state.  Tables are truncated in a single
 * statement to avoid FK-ordering issues.
 */
export async function cleanDatabase(app: INestApplication): Promise<void> {
  const dataSource = app.get(DataSource);
  const entities = dataSource.entityMetadatas;

  if (entities.length === 0) return;

  const tableNames = entities
    .map((entity) => `"${entity.tableName}"`)
    .join(', ');

  await dataSource.query(`TRUNCATE TABLE ${tableNames} CASCADE`);
}
