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
import { Team } from '../../teams/entities/team.entity';
import { Supplier } from '../../suppliers/entities/supplier.entity';
import { ProductLot } from '../../lots/entities/product-lot.entity';

export enum MovementType {
  IN = 'in',
  OUT = 'out',
  ADJUSTMENT = 'adjustment',
  SALE = 'sale',
  PURCHASE = 'purchase',
  RETURN = 'return',
}

@Entity('inventory_movements')
export class InventoryMovement {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  teamId: string;

  @ManyToOne(() => Team)
  @JoinColumn({ name: 'teamId' })
  team: Team;

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

  @Column({ nullable: true })
  supplierId: string;

  @ManyToOne(() => Supplier, { nullable: true })
  @JoinColumn({ name: 'supplierId' })
  supplier: Supplier;

  @Column({ nullable: true })
  lotId: string;

  @ManyToOne(() => ProductLot, { nullable: true })
  @JoinColumn({ name: 'lotId' })
  lot: ProductLot;

  @Column({ type: 'decimal', precision: 12, scale: 2, nullable: true })
  unitCost: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, nullable: true })
  totalCost: number;

  @Column({ nullable: true })
  referenceType: string;

  @Column({ nullable: true })
  referenceId: string;

  @Column({ type: 'int' })
  stockBefore: number;

  @Column({ type: 'int' })
  stockAfter: number;

  @CreateDateColumn()
  createdAt: Date;
}
