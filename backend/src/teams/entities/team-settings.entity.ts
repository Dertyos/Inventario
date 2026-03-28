import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToOne,
  JoinColumn,
} from 'typeorm';
import { Team } from './team.entity';

@Entity('team_settings')
export class TeamSettings {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  teamId: string;

  @OneToOne(() => Team, (team) => team.settings)
  @JoinColumn({ name: 'teamId' })
  team: Team;

  // ── Feature Toggles ──────────────────────────────

  @Column({ default: true })
  enableLots: boolean;

  @Column({ default: true })
  enableCredit: boolean;

  @Column({ default: true })
  enableSuppliers: boolean;

  @Column({ default: true })
  enableReminders: boolean;

  @Column({ default: false })
  enableTax: boolean;

  @Column({ default: true })
  enableBarcode: boolean;

  // ── Timezone ──────────────────────────────────────

  @Column({ type: 'int', default: 0 })
  tzOffsetMinutes: number;

  // ── Defaults ──────────────────────────────────────

  @Column({ type: 'decimal', precision: 5, scale: 2, default: 19.0 })
  defaultTaxRate: number;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
