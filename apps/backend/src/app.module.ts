import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { AccountModule } from './account/account.module.js';
import { AdminModule } from './admin/admin.module.js';
import { AuthModule } from './auth/auth.module.js';
import { JwtAuthGuard } from './auth/jwt-auth.guard.js';
import { RolesGuard } from './auth/roles.guard.js';
import { RateLimitGuard } from './common/rate-limit.js';
import { requestId } from './common/request-id.middleware.js';
import { validateEnv } from './config/env.js';
import { CatalogModule } from './catalog/catalog.module.js';
import { DevicesModule } from './devices/devices.module.js';
import { FactoriesModule } from './factories/factories.module.js';
import { FleetModule } from './fleet/fleet.module.js';
import { HealthController } from './health/health.controller.js';
import { InvoicesModule } from './invoices/invoices.module.js';
import { NotificationsModule } from './notifications/notifications.module.js';
import { OrdersModule } from './orders/orders.module.js';
import { PointsModule } from './points/points.module.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { PushModule } from './push/push.module.js';
import { RequestsModule } from './requests/requests.module.js';
import { RoutesModule } from './routes/routes.module.js';
import { ScansModule } from './scans/scans.module.js';
import { ShipmentsModule } from './shipments/shipments.module.js';
import { UploadsModule } from './uploads/uploads.module.js';
import { WarehouseModule } from './warehouse/warehouse.module.js';
import { WeighingModule } from './weighing/weighing.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, validate: validateEnv, cache: true }),
    PrismaModule,
    AuthModule,
    AccountModule,
    NotificationsModule,
    PushModule,
    DevicesModule,
    UploadsModule,
    ScansModule,
    RequestsModule,
    ShipmentsModule,
    PointsModule,
    WeighingModule,
    WarehouseModule,
    FleetModule,
    CatalogModule,
    FactoriesModule,
    OrdersModule,
    InvoicesModule,
    RoutesModule,
    AdminModule,
  ],
  controllers: [HealthController],
  providers: [
    // Order matters: rate limit first, then login check, then role check.
    { provide: APP_GUARD, useClass: RateLimitGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    consumer.apply(requestId).forRoutes('*path');
  }
}
