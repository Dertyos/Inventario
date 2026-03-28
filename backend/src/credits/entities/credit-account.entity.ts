import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
} from 'typeorm';
import { Team } from '../../teams/entities/team.entity';
import { Sale } from '../../sales/entities/sale.entity';
import { Customer } from '../../customers/entities/customer.entity';
import { CreditInstallment } from './credit-installment.entity';

export enum InterestType {
  NONE = 'none',
  FIXED = 'fixed',
  MONTHLY = 'monthly',
}

export enum CreditStatus {
  ACTIVE = 'active',
  PAID = 'paid',
  DEFAULTED = 'defaulted',
}

@Entity('credit_accounts')
export class CreditAccount {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  teamId: string;

  @ManyToOne(() => Team)
  @JoinColumn({ name: 'teamId' })
  team: Team;

  @Column({ nullable: true })
  saleId: string | null;

  @ManyToOne(() => Sale, { nullable: true })
  @JoinColumn({ name: 'saleId' })
  sale: Sale | null;

  @Column({ nullable: true })
  movementId: string | null;

  @Column({ nullable: true })
  customerId: string | null;

  @ManyToOne(() => Customer, { nullable: true })
  @JoinColumn({ name: 'customerId' })
  customer: Customer | null;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  totalAmount: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 0 })
  paidAmount: number;

  @Column({ type: 'decimal', precision: 5, scale: 2, default: 0 })
  interestRate: number;

  @Column({
    type: 'enum',
    enum: InterestType,
    default: InterestType.NONE,
  })
  interestType: InterestType;

  @Column({ type: 'int', default: 1 })
  installments: number;

  @Column({ type: 'date' })
  startDate: string;

  @Column({
    type: 'enum',
    enum: CreditStatus,
    default: CreditStatus.ACTIVE,
  })
  status: CreditStatus;

  @OneToMany(
    () => CreditInstallment,
    (installment) => installment.creditAccount,
    { cascade: true },
  )
  creditInstallments: CreditInstallment[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
