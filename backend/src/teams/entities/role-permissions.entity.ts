import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Unique,
} from 'typeorm';
import { Team } from './team.entity';
import { TeamRole } from './team-member.entity';

@Entity('role_permissions')
@Unique(['teamId', 'role'])
export class RolePermissions {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column('uuid')
  teamId: string;

  @ManyToOne(() => Team)
  @JoinColumn({ name: 'teamId' })
  team: Team;

  @Column({ type: 'enum', enum: TeamRole })
  role: TeamRole;

  @Column('jsonb', { default: '[]' })
  permissions: string[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
