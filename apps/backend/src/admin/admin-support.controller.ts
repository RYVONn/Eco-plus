import { Body, Controller, Get, HttpCode, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { type AuthUser, CurrentUser } from '../auth/auth-user.js';
import { Public } from '../auth/public.decorator.js';
import { Roles } from '../auth/roles.decorator.js';
import { type Pagination, paginationSchema } from '../common/pagination.js';
import { ZodValidationPipe } from '../common/zod-validation.pipe.js';
import { type ContactDto, type StartSupportDto, contactSchema, startSupportSchema } from './admin-support.schemas.js';
import { AdminSupportService } from './admin-support.service.js';

@ApiTags('admin')
@ApiBearerAuth()
@Controller()
export class AdminSupportController {
  constructor(private readonly service: AdminSupportService) {}

  @Roles('admin')
  @Post('admin/support-sessions')
  @HttpCode(201)
  @ApiOperation({ summary: 'Open support mode on an account. Written to the audit log' })
  start(@CurrentUser() admin: AuthUser, @Body(new ZodValidationPipe(startSupportSchema)) dto: StartSupportDto) {
    return this.service.start(admin, dto.userId);
  }

  @Roles('admin')
  @Get('admin/audit')
  @ApiOperation({ summary: 'Audit log, newest first' })
  audit(@Query(new ZodValidationPipe(paginationSchema)) q: Pagination) {
    return this.service.audit(q);
  }

  @Public()
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('contact')
  @HttpCode(201)
  @ApiOperation({ summary: 'Message from the public website form' })
  contact(@Body(new ZodValidationPipe(contactSchema)) dto: ContactDto) {
    return this.service.saveContact(dto);
  }

  @Roles('admin')
  @Get('admin/contact-messages')
  @ApiOperation({ summary: 'Messages from the website form, newest first' })
  contactMessages(@Query(new ZodValidationPipe(paginationSchema)) q: Pagination) {
    return this.service.contactMessages(q);
  }
}
