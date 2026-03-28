import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
  Unique,
} from 'typeorm';
import { Category } from '../../categories/entities/category.entity';
import { InventoryMovement } from '../../inventory/entities/inventory-movement.entity';
import { Team } from '../../teams/entities/team.entity';

@Entity('products')
@Unique(['teamId', 'sku'])
export class Product {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  teamId: string;

  @ManyToOne(() => Team)
  @JoinColumn({ name: 'teamId' })
  team: Team;

  @Column()
  sku: string;

  @Column({ nullable: true })
  barcode: string;

  @Column()
  name: string;

  @Column({ nullable: true })
  description: string;

  @Column({ nullable: true })
  imageUrl: string;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  price: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, nullable: true })
  cost: number;

  @Column({ type: 'int', default: 0 })
  stock: number;

  @Column({ type: 'int', default: 0 })
  minStock: number;

  @Column({ default: false })
  trackLots: boolean;

  @Column({ type: 'boolean', default: false })
  isPerishable: boolean;

  @Column({ nullable: true })
  categoryId: string;

  @ManyToOne(() => Category, (category) => category.products, { nullable: true })
  @JoinColumn({ name: 'categoryId' })
  category: Category;

  @OneToMany(() => InventoryMovement, (movement) => movement.product)
  inventoryMovements: InventoryMovement[];

  @Column({ default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
