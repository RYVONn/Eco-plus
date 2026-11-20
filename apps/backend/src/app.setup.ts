import type { INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import type { Express } from 'express';
import helmetModule from 'helmet';
import { AllExceptionsFilter } from './common/all-exceptions.filter.js';
import type { Env } from './config/env.js';

// Vercel type-checks with CommonJS interop, where the default import is the module object; unwrap it.
const helmet = ((helmetModule as unknown as { default?: typeof helmetModule }).default ?? helmetModule) as typeof helmetModule;

/** Settings shared by the real server (main.ts) and the end-to-end tests. */
export function configureApp(app: INestApplication): void {
  const config = app.get<ConfigService<Env, true>>(ConfigService);

  // Behind a reverse proxy every request would otherwise look like it came from the proxy's address.
  const proxyHops = config.get('TRUST_PROXY', { infer: true });
  if (proxyHops > 0) (app.getHttpAdapter().getInstance() as Express).set('trust proxy', proxyHops);

  app.use(helmet());
  app.useGlobalFilters(new AllExceptionsFilter());

  const origins = config
    .get('CORS_ORIGINS', { infer: true })
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);
  app.enableCors({ origin: origins, credentials: true });

  if (config.get('SWAGGER_ENABLED', { infer: true })) {
    const doc = new DocumentBuilder()
      .setTitle('EcoPlus API')
      .setDescription('Smart recycling platform: citizens, drivers, warehouse, factories.')
      .setVersion('0.1.0')
      .addBearerAuth()
      .build();
    SwaggerModule.setup('docs', app, SwaggerModule.createDocument(app, doc));
  }
}
