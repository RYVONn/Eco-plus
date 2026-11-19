import { Controller, Get, HttpCode, Param, ParseIntPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { type AuthUser, CurrentUser } from '../auth/auth-user.js';
import { Roles } from '../auth/roles.decorator.js';
import { type Pagination, paginationSchema } from '../common/pagination.js';
import { ZodValidationPipe } from '../common/zod-validation.pipe.js';
import { PayoutsService } from './payouts.service.js';

const listSchema = paginationSchema.extend({ status: z.enum(['unpaid', 'paid']).default('unpaid') });
type ListQuery = z.infer<typeof listSchema>;

@ApiTags('payouts')
@ApiBearerAuth()
@Controller()
export class PayoutsController {
  constructor(private readonly service: PayoutsService) {}

  @Roles('admin')
  @Get('admin/payouts')
  @ApiOperation({ summary: 'Cash owed to business sellers (status=unpaid|paid) with the total' })
  list(@Query(new ZodValidationPipe(listSchema)) q: ListQuery) {
    return this.service.list(q.status, q);
  }

  @Roles('admin')
  @HttpCode(200)
  @Post('admin/payouts/:weighingId/pay')
  @ApiOperation({ summary: 'Mark a cash payout as paid. Audited; cannot be paid twice' })
  pay(@CurrentUser() admin: AuthUser, @Param('weighingId', ParseIntPipe) weighingId: number) {
    return this.service.pay(admin, weighingId);
  }

  @Roles('business')
  @Get('me/payouts')
  @ApiOperation({ summary: 'My cash payouts: items, amount due and amount paid' })
  mine(@CurrentUser() user: AuthUser, @Query(new ZodValidationPipe(paginationSchema)) q: Pagination) {
    return this.service.statement(user.id, q);
  }
}
