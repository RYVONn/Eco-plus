import { Controller, Get, HttpException, HttpStatus } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { PrismaService } from '../prisma/prisma.service.js';
import { Public } from '../auth/public.decorator.js';
import { SkipThrottle } from '../common/rate-limit.js';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Public()
  @SkipThrottle()
  @Get()
  @ApiOperation({ summary: 'Liveness check that also verifies the database connection' })
  async check(): Promise<{ status: 'ok'; db: 'up'; time: string }> {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
    } catch {
      throw new HttpException(
        { code: 'db_unavailable', message: 'Database is not reachable.' },
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }
    return { status: 'ok', db: 'up', time: new Date().toISOString() };
  }
}
