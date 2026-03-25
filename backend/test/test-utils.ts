import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { AppModule } from '../src/app.module';

/**
 * Creates a fully bootstrapped NestJS application for E2E testing.
 *
 * The app uses the real AppModule but overrides the TypeORM configuration
 * to point at the test database defined by DATABASE_URL in .env.test.
 * Global validation pipes are applied to match production behavior.
 */
export async function createTestApp(): Promise<INestApplication> {
  // Load .env.test so the ConfigService picks up test values
  process.env.NODE_ENV = 'test';

  const moduleFixture: TestingModule = await Test.createTestingModule({
    imports: [AppModule],
  })
    .overrideModule(ConfigModule)
    .useModule(
      ConfigModule.forRoot({
        isGlobal: true,
        envFilePath: '.env.test',
      }),
    )
    .compile();

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
 * starts from a clean state. Tables are truncated in a single statement
 * to avoid FK-ordering issues.
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
