import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { Exclude } from 'class-transformer';
import { InventoryMovement } from '../../inventory/entities/inventory-movement.entity';
import { TeamMember } from '../../teams/entities/team-member.entity';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  email: string;

  @Column()
  @Exclude()
  password: string;

  @Column()
  firstName: string;

  @Column()
  lastName: string;

  @Column({ nullable: true })
  phone: string;

  @Column({ default: true })
  isActive: boolean;

  @OneToMany(() => TeamMember, (membership) => membership.user)
  teamMemberships: TeamMember[];

  @OneToMany(() => InventoryMovement, (movement) => movement.user)
  inventoryMovements: InventoryMovement[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
