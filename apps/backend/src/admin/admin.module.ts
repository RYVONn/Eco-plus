import { Module } from '@nestjs/common';
import { RequestsModule } from '../requests/requests.module.js';
import { ScansModule } from '../scans/scans.module.js';
import { AdminSupportController } from './admin-support.controller.js';
import { AdminSupportService } from './admin-support.service.js';
import { AdminStatsController } from './admin-stats.controller.js';
import { AdminStatsService } from './admin-stats.service.js';
import { AdminRequestsController } from './admin-requests.controller.js';
import { PayoutsController } from './payouts.controller.js';
import { PayoutsService } from './payouts.service.js';
import { AdminRequestsService } from './admin-requests.service.js';

@Module({
  imports: [ScansModule, RequestsModule],
  controllers: [AdminRequestsController, AdminStatsController, AdminSupportController, PayoutsController],
  providers: [AdminRequestsService, AdminStatsService, AdminSupportService, PayoutsService],
})
export class AdminModule {}
