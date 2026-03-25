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
import { User } from '../../users/entities/user.entity';

export enum TeamRole {
  OWNER = 'owner',
  ADMIN = 'admin',
  MANAGER = 'manager',
  STAFF = 'staff',
}

@Entity('team_members')
@Unique(['userId', 'teamId'])
export class TeamMember {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @ManyToOne(() => User, (user) => user.teamMemberships)
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column()
  teamId: string;

  @ManyToOne(() => Team, (team) => team.members)
  @JoinColumn({ name: 'teamId' })
  team: Team;

  @Column({ type: 'enum', enum: TeamRole, default: TeamRole.STAFF })
  role: TeamRole;

  @Column({ default: true })
  isActive: boolean;

  @Column({ type: 'timestamp', nullable: true })
  joinedAt: Date;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
