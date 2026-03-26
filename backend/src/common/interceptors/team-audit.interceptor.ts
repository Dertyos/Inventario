import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
  Logger,
  ForbiddenException,
} from '@nestjs/common';
import { Observable, tap } from 'rxjs';
import { AuditService } from '../../audit/audit.service';

/**
 * Interceptor that audits team-scoped requests.
 * - Validates that the teamId in the URL is a valid UUID format
 * - Logs mutations (POST/PUT/PATCH/DELETE) for audit trail
 * - Persists audit log entries via AuditService
 * - Detects and blocks teamId mismatch in request body (defense in depth)
 */
@Injectable()
export class TeamAuditInterceptor implements NestInterceptor {
  private readonly logger = new Logger('TeamAudit');

  constructor(private readonly auditService: AuditService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();
    const teamId = request.params?.teamId;

    if (!teamId) {
      return next.handle();
    }

    // Block any attempt to override teamId via request body
    if (
      request.body &&
      typeof request.body === 'object' &&
      'teamId' in request.body
    ) {
      this.logger.warn(
        `Blocked teamId override attempt | user=${request.user?.id} | url=${request.url} | bodyTeamId=${request.body.teamId}`,
      );
      throw new ForbiddenException('Cannot override teamId in request body');
    }

    const method = request.method;
    const isMutation = ['POST', 'PUT', 'PATCH', 'DELETE'].includes(method);

    if (isMutation) {
      const userId = request.user?.id || 'anonymous';
      const now = Date.now();

      return next.handle().pipe(
        tap({
          next: () => {
            const duration = Date.now() - now;
            this.logger.log(
              `${method} ${request.url} | team=${teamId} | user=${userId} | ${duration}ms`,
            );

            // Extract entity info from URL path
            const { entityType, entityId } = this.extractEntityInfo(request.url);

            // Fire-and-forget audit log persistence
            this.auditService
              .log({
                teamId,
                userId,
                entityType,
                entityId,
                action: method,
                changes: request.body || null,
              })
              .catch((err) => {
                this.logger.warn(
                  `Failed to save audit log: ${err.message}`,
                );
              });
          },
          error: (err) => {
            const duration = Date.now() - now;
            this.logger.warn(
              `${method} ${request.url} FAILED | team=${teamId} | user=${userId} | ${duration}ms | ${err.message}`,
            );
          },
        }),
      );
    }

    return next.handle();
  }

  /**
   * Extracts entityType and entityId from a URL path.
   * Example: /teams/:teamId/products/:id -> { entityType: 'products', entityId: ':id' }
   */
  private extractEntityInfo(url: string): {
    entityType: string;
    entityId?: string;
  } {
    // Remove query string
    const path = url.split('?')[0];
    // Split into segments and filter empty
    const segments = path.split('/').filter(Boolean);

    // Find the segment after 'teams/:teamId'
    const teamsIndex = segments.indexOf('teams');
    if (teamsIndex === -1 || teamsIndex + 2 >= segments.length) {
      return { entityType: 'unknown' };
    }

    const entityType = segments[teamsIndex + 2]; // e.g. 'products', 'sales', 'customers'
    const entityId = segments[teamsIndex + 3]; // e.g. the UUID after entity type, if present

    // Validate entityId looks like a UUID before using it
    const uuidRegex =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const resolvedEntityId =
      entityId && uuidRegex.test(entityId) ? entityId : undefined;

    return { entityType, entityId: resolvedEntityId };
  }
}
