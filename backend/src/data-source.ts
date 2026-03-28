import { DataSource } from 'typeorm';
import { config } from 'dotenv';

config();

const isProduction = process.env.NODE_ENV === 'production';
const databaseUrl = process.env.DATABASE_URL;
// Strip sslmode from URL to avoid pg v8 SSL deprecation warning
const url = isProduction && databaseUrl
  ? databaseUrl.replace(/[?&]sslmode=[^&]*/g, '').replace(/\?$/, '')
  : databaseUrl;

export default new DataSource({
  type: 'postgres',
  url,
  entities: ['dist/**/*.entity.js'],
  migrations: ['dist/migrations/*.js'],
  synchronize: false,
  logging: false,
  ssl: isProduction
    ? { rejectUnauthorized: process.env.DB_SSL_REJECT_UNAUTHORIZED !== 'false' }
    : false,
});
