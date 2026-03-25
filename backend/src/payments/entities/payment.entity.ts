import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Team } from '../../teams/entities/team.entity';
import { Sale } from '../../sales/entities/sale.entity';
import { User } from '../../users/entities/user.entity';

export enum PaymentMethodType {
  CASH = 'cash',
  CARD = 'card',
  TRANSFER = 'transfer',
}

@Entity('payments')
export class Payment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  teamId: string;

  @ManyToOne(() => Team)
  @JoinColumn({ name: 'teamId' })
  team: Team;

  @Column({ nullable: true })
  saleId: string;

  @ManyToOne(() => Sale, (sale) => sale.payments, { nullable: true })
  @JoinColumn({ name: 'saleId' })
  sale: Sale;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  amount: number;

  @Column({
    type: 'enum',
    enum: PaymentMethodType,
    default: PaymentMethodType.CASH,
  })
  method: PaymentMethodType;

  @Column({ nullable: true })
  reference: string;

  @Column({ nullable: true })
  notes: string;

  @Column()
  receivedBy: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'receivedBy' })
  receivedByUser: User;

  @Column({ type: 'timestamp' })
  paidAt: Date;

  @CreateDateColumn()
  createdAt: Date;
}
