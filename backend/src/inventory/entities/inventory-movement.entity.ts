import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Product } from '../../products/entities/product.entity';
import { User } from '../../users/entities/user.entity';

export enum MovementType {
  IN = 'in',
  OUT = 'out',
  ADJUSTMENT = 'adjustment',
}

@Entity('inventory_movements')
export class InventoryMovement {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'enum', enum: MovementType })
  type: MovementType;

  @Column({ type: 'int' })
  quantity: number;

  @Column({ nullable: true })
  reason: string;

  @Column()
  productId: string;

  @ManyToOne(() => Product, (product) => product.inventoryMovements)
  @JoinColumn({ name: 'productId' })
  product: Product;

  @Column()
  userId: string;

  @ManyToOne(() => User, (user) => user.inventoryMovements)
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column({ type: 'int' })
  stockBefore: number;

  @Column({ type: 'int' })
  stockAfter: number;

  @CreateDateColumn()
  createdAt: Date;
}
