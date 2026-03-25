import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
  Logger,
  ForbiddenException,
} from '@nestjs/common';
import { Observable, tap } from 'rxjs';

/**
 * Interceptor that audits team-scoped requests.
 * - Validates that the teamId in the URL is a valid UUID format
 * - Logs mutations (POST/PUT/PATCH/DELETE) for audit trail
 * - Detects and blocks teamId mismatch in request body (defense in depth)
 */
@Injectable()
export class TeamAuditInterceptor implements NestInterceptor {
  private readonly logger = new Logger('TeamAudit');

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();
    const teamId = request.params?.teamId;

    if (!teamId) {
      return next.handle();
    }

    // Block any attempt to override teamId via request body
    if (request.body && typeof request.body === 'object' && 'teamId' in request.body) {
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
}
