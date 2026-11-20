import { Module } from '@nestjs/common';
import { UploadsModule } from '../uploads/uploads.module.js';
import { AccountController } from './account.controller.js';
import { AccountService } from './account.service.js';

@Module({
  imports: [UploadsModule],
  controllers: [AccountController],
  providers: [AccountService],
})
export class AccountModule {}
