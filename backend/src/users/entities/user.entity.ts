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

  @Column({ default: false })
  emailVerified: boolean;

  @Column({ nullable: true })
  @Exclude()
  verificationCode: string;

  @Column({ type: 'timestamp', nullable: true })
  verificationCodeExpiry: Date;

  @Column({ default: 0 })
  verificationAttempts: number;

  @Column({ nullable: true })
  @Exclude()
  resetCode: string;

  @Column({ type: 'timestamp', nullable: true })
  resetCodeExpiry: Date;

  @Column({ default: 0 })
  resetAttempts: number;

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
