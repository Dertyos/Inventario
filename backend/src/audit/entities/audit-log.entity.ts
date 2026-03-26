import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

@Entity('audit_logs')
export class AuditLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid')
  teamId: string;

  @Column('uuid')
  userId: string;

  @Column('varchar', { length: 50 })
  entityType: string; // 'product', 'sale', 'customer', etc.

  @Column('uuid', { nullable: true })
  entityId: string;

  @Column('varchar', { length: 10 })
  action: string; // POST, PATCH, DELETE

  @Column('jsonb', { nullable: true })
  changes: Record<string, any>; // request body (new values)

  @CreateDateColumn()
  createdAt: Date;
}
