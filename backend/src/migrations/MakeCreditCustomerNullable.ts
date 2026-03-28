import { MigrationInterface, QueryRunner } from 'typeorm';

export class MakeCreditCustomerNullable1711800000000
  implements MigrationInterface
{
  name = 'MakeCreditCustomerNullable1711800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "credit_accounts" ALTER COLUMN "customerId" DROP NOT NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "credit_accounts" ALTER COLUMN "customerId" SET NOT NULL`,
    );
  }
}
