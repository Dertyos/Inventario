import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { Team } from '../../teams/entities/team.entity';
import { CreditInstallment } from '../../credits/entities/credit-installment.entity';
import { Customer } from '../../customers/entities/customer.entity';
import { Supplier } from '../../suppliers/entities/supplier.entity';

export enum ReminderChannel {
  SMS = 'sms',
  WHATSAPP = 'whatsapp',
  EMAIL = 'email',
  PUSH = 'push',
  INTERNAL = 'internal',
}

export enum ReminderStatus {
  PENDING = 'pending',
  SENT = 'sent',
  FAILED = 'failed',
}

export enum ReminderType {
  BEFORE_DUE = 'before_due',
  ON_DUE = 'on_due',
  AFTER_DUE = 'after_due',
}

@Unique('UQ_reminder_installment_type_date', ['installmentId', 'type', 'scheduledDate'])
@Entity('payment_reminders')
export class PaymentReminder {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  teamId: string;

  @ManyToOne(() => Team)
  @JoinColumn({ name: 'teamId' })
  team: Team;

  @Column()
  installmentId: string;

  @ManyToOne(() => CreditInstallment)
  @JoinColumn({ name: 'installmentId' })
  installment: CreditInstallment;

  @Column({ nullable: true })
  customerId: string | null;

  @ManyToOne(() => Customer, { nullable: true })
  @JoinColumn({ name: 'customerId' })
  customer: Customer | null;

  @Column({ nullable: true })
  supplierId: string | null;

  @ManyToOne(() => Supplier, { nullable: true })
  @JoinColumn({ name: 'supplierId' })
  supplier: Supplier | null;

  @Column({
    type: 'enum',
    enum: ReminderType,
  })
  type: ReminderType;

  @Column({
    type: 'enum',
    enum: ReminderChannel,
    default: ReminderChannel.INTERNAL,
  })
  channel: ReminderChannel;

  @Column({
    type: 'enum',
    enum: ReminderStatus,
    default: ReminderStatus.PENDING,
  })
  status: ReminderStatus;

  @Column({ type: 'date' })
  scheduledDate: string;

  @Column({ type: 'timestamp', nullable: true })
  sentAt: Date;

  @Column({ nullable: true })
  message: string;

  @Column({ nullable: true })
  errorMessage: string;

  @CreateDateColumn()
  createdAt: Date;
}
