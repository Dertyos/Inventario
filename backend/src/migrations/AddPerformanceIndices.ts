import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddPerformanceIndices1711700000000 implements MigrationInterface {
  name = 'AddPerformanceIndices1711700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Sales: frequent queries by team + date range
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_sales_team_created" ON "sales" ("teamId", "createdAt" DESC)`,
    );
    // Sales: filter by status
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_sales_team_status" ON "sales" ("teamId", "status")`,
    );
    // Credit accounts: by team and status
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_credit_accounts_team_status" ON "credit_accounts" ("teamId", "status")`,
    );
    // Credit installments: by due date and status (for reminders cron)
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_credit_installments_due_status" ON "credit_installments" ("dueDate", "status")`,
    );
    // Products: low stock queries
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_products_team_stock" ON "products" ("teamId", "stock", "minStock") WHERE "isActive" = true`,
    );
    // Inventory movements: by team and date
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_inventory_movements_team_created" ON "inventory_movements" ("teamId", "createdAt" DESC)`,
    );
    // Product lots: expiring lots query
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_product_lots_team_expiration" ON "product_lots" ("teamId", "expirationDate") WHERE "status" = 'active'`,
    );
    // Payment reminders: unique constraint (avoid duplicates)
    await queryRunner.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS "IDX_reminders_unique" ON "payment_reminders" ("installmentId", "type", "scheduledDate")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_sales_team_created"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_sales_team_status"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_credit_accounts_team_status"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_credit_installments_due_status"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_products_team_stock"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_inventory_movements_team_created"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_product_lots_team_expiration"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "IDX_reminders_unique"`);
  }
}
