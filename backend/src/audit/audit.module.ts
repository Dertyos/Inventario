import { Global, Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuditLog } from './entities/audit-log.entity';
import { AuditService } from './audit.service';
import { AuditController } from './audit.controller';
import { TeamsModule } from '../teams/teams.module';

@Global()
@Module({
  imports: [TypeOrmModule.forFeature([AuditLog]), TeamsModule],
  controllers: [AuditController],
  providers: [AuditService],
  exports: [AuditService],
})
export class AuditModule {}
