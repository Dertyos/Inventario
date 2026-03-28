import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddInventoryPurchaseFields1711900000000
  implements MigrationInterface
{
  name = 'AddInventoryPurchaseFields1711900000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Inventory movement cost tracking
    await queryRunner.query(
      `ALTER TABLE "inventory_movements" ADD COLUMN IF NOT EXISTS "unitCost" decimal(12,2)`,
    );
    await queryRunner.query(
      `ALTER TABLE "inventory_movements" ADD COLUMN IF NOT EXISTS "totalCost" decimal(12,2)`,
    );
    // Credit accounts: make saleId nullable and add movementId
    await queryRunner.query(
      `ALTER TABLE "credit_accounts" ALTER COLUMN "saleId" DROP NOT NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE "credit_accounts" ADD COLUMN IF NOT EXISTS "movementId" uuid`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "credit_accounts" DROP COLUMN IF EXISTS "movementId"`,
    );
    await queryRunner.query(
      `ALTER TABLE "credit_accounts" ALTER COLUMN "saleId" SET NOT NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE "inventory_movements" DROP COLUMN IF EXISTS "totalCost"`,
    );
    await queryRunner.query(
      `ALTER TABLE "inventory_movements" DROP COLUMN IF EXISTS "unitCost"`,
    );
  }
}
