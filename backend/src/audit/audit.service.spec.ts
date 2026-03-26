import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { AuditService } from './audit.service';
import { AuditLog } from './entities/audit-log.entity';

const TEAM_ID = 'team-uuid-1';
const USER_ID = 'user-uuid-1';

describe('AuditService', () => {
  let service: AuditService;

  const mockAuditLog = {
    id: 'audit-uuid-1',
    teamId: TEAM_ID,
    userId: USER_ID,
    entityType: 'product',
    entityId: 'prod-uuid-1',
    action: 'POST',
    changes: { name: 'Laptop', price: 999.99 },
    createdAt: new Date(),
  };

  const mockAuditLogRepo = {
    create: jest.fn(),
    save: jest.fn(),
    find: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuditService,
        { provide: getRepositoryToken(AuditLog), useValue: mockAuditLogRepo },
      ],
    }).compile();

    service = module.get<AuditService>(AuditService);
    jest.clearAllMocks();
  });

  describe('log', () => {
    it('should create an audit entry', async () => {
      mockAuditLogRepo.create.mockReturnValue(mockAuditLog);
      mockAuditLogRepo.save.mockResolvedValue(mockAuditLog);

      const result = await service.log({
        teamId: TEAM_ID,
        userId: USER_ID,
        entityType: 'product',
        entityId: 'prod-uuid-1',
        action: 'POST',
        changes: { name: 'Laptop', price: 999.99 },
      });

      expect(result).toBeDefined();
      expect(result.id).toBe('audit-uuid-1');
      expect(mockAuditLogRepo.create).toHaveBeenCalled();
      expect(mockAuditLogRepo.save).toHaveBeenCalled();
    });

    it('should save all fields correctly', async () => {
      const logData = {
        teamId: TEAM_ID,
        userId: USER_ID,
        entityType: 'sale',
        entityId: 'sale-uuid-1',
        action: 'PATCH',
        changes: { status: 'cancelled' },
      };

      mockAuditLogRepo.create.mockReturnValue({ ...logData, id: 'audit-uuid-2' });
      mockAuditLogRepo.save.mockResolvedValue({ ...logData, id: 'audit-uuid-2', createdAt: new Date() });

      await service.log(logData);

      expect(mockAuditLogRepo.create).toHaveBeenCalledWith(logData);
      expect(mockAuditLogRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({
          teamId: TEAM_ID,
          userId: USER_ID,
          entityType: 'sale',
          entityId: 'sale-uuid-1',
          action: 'PATCH',
          changes: { status: 'cancelled' },
        }),
      );
    });

    it('should handle log entry without entityId', async () => {
      const logData = {
        teamId: TEAM_ID,
        userId: USER_ID,
        entityType: 'product',
        action: 'POST',
      };

      mockAuditLogRepo.create.mockReturnValue({ ...logData, id: 'audit-uuid-3' });
      mockAuditLogRepo.save.mockResolvedValue({ ...logData, id: 'audit-uuid-3', createdAt: new Date() });

      const result = await service.log(logData);

      expect(result).toBeDefined();
      expect(mockAuditLogRepo.create).toHaveBeenCalledWith(logData);
    });
  });

  describe('findByTeam', () => {
    it('should return entries ordered by createdAt DESC', async () => {
      const logs = [
        { ...mockAuditLog, id: 'audit-1', createdAt: new Date('2026-03-26') },
        { ...mockAuditLog, id: 'audit-2', createdAt: new Date('2026-03-25') },
      ];
      mockAuditLogRepo.find.mockResolvedValue(logs);

      const result = await service.findByTeam(TEAM_ID);

      expect(result).toHaveLength(2);
      expect(mockAuditLogRepo.find).toHaveBeenCalledWith({
        where: { teamId: TEAM_ID },
        order: { createdAt: 'DESC' },
        take: 50,
      });
    });

    it('should respect limit parameter', async () => {
      mockAuditLogRepo.find.mockResolvedValue([mockAuditLog]);

      await service.findByTeam(TEAM_ID, 10);

      expect(mockAuditLogRepo.find).toHaveBeenCalledWith({
        where: { teamId: TEAM_ID },
        order: { createdAt: 'DESC' },
        take: 10,
      });
    });

    it('should use default limit of 50', async () => {
      mockAuditLogRepo.find.mockResolvedValue([]);

      await service.findByTeam(TEAM_ID);

      expect(mockAuditLogRepo.find).toHaveBeenCalledWith(
        expect.objectContaining({ take: 50 }),
      );
    });
  });

  describe('findByEntity', () => {
    it('should filter by entityType and entityId', async () => {
      const logs = [mockAuditLog];
      mockAuditLogRepo.find.mockResolvedValue(logs);

      const result = await service.findByEntity('product', 'prod-uuid-1');

      expect(result).toHaveLength(1);
      expect(mockAuditLogRepo.find).toHaveBeenCalledWith({
        where: { entityType: 'product', entityId: 'prod-uuid-1' },
        order: { createdAt: 'DESC' },
      });
    });

    it('should return empty array when no logs exist for entity', async () => {
      mockAuditLogRepo.find.mockResolvedValue([]);

      const result = await service.findByEntity('customer', 'cust-uuid-999');

      expect(result).toEqual([]);
      expect(mockAuditLogRepo.find).toHaveBeenCalledWith({
        where: { entityType: 'customer', entityId: 'cust-uuid-999' },
        order: { createdAt: 'DESC' },
      });
    });
  });
});
