import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuditLog } from './entities/audit-log.entity';

@Injectable()
export class AuditService {
  constructor(
    @InjectRepository(AuditLog)
    private readonly auditLogRepository: Repository<AuditLog>,
  ) {}

  async log(data: {
    teamId: string;
    userId: string;
    entityType: string;
    entityId?: string;
    action: string;
    changes?: Record<string, any>;
  }): Promise<AuditLog> {
    const entry = this.auditLogRepository.create(data);
    return this.auditLogRepository.save(entry);
  }

  async findByTeam(teamId: string, limit = 50): Promise<AuditLog[]> {
    return this.auditLogRepository.find({
      where: { teamId },
      order: { createdAt: 'DESC' },
      take: limit,
    });
  }

  async findByEntity(entityType: string, entityId: string): Promise<AuditLog[]> {
    return this.auditLogRepository.find({
      where: { entityType, entityId },
      order: { createdAt: 'DESC' },
    });
  }
}
