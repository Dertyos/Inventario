import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  OneToOne,
} from 'typeorm';
import { TeamMember } from './team-member.entity';
import { TeamSettings } from './team-settings.entity';

@Entity('teams')
export class Team {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ unique: true })
  slug: string;

  @Column({ default: 'COP' })
  currency: string;

  @Column({ default: 'America/Bogota' })
  timezone: string;

  @Column({ default: true })
  isActive: boolean;

  @OneToMany(() => TeamMember, (member) => member.team)
  members: TeamMember[];

  @OneToOne(() => TeamSettings, (settings) => settings.team, { cascade: true })
  settings: TeamSettings;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
