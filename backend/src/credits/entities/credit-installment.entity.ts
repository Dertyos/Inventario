import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { CreditAccount } from './credit-account.entity';

export enum InstallmentStatus {
  PENDING = 'pending',
  PAID = 'paid',
  OVERDUE = 'overdue',
  PARTIAL = 'partial',
}

@Entity('credit_installments')
export class CreditInstallment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  creditAccountId: string;

  @ManyToOne(() => CreditAccount, (account) => account.creditInstallments, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'creditAccountId' })
  creditAccount: CreditAccount;

  @Column({ type: 'int' })
  installmentNumber: number;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  amount: number;

  @Column({ type: 'date' })
  dueDate: string;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  paidAmount: number;

  @Column({ type: 'timestamp', nullable: true })
  paidAt: Date;

  @Column({
    type: 'enum',
    enum: InstallmentStatus,
    default: InstallmentStatus.PENDING,
  })
  status: InstallmentStatus;

  @CreateDateColumn()
  createdAt: Date;
}
