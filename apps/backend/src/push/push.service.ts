import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Env } from '../config/env.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { FcmSender } from './fcm.sender.js';

/**
 * Sends a push message to every phone a user has registered.
 * Providers: none, log (writes the title to the log) and fcm (Firebase Cloud Messaging).
 * Push is a convenience on top of the stored notification, so a failure here never fails the request.
 */
@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService<Env, true>,
  ) {}

  private fcm: FcmSender | null = null;

  private sender(): FcmSender {
    this.fcm ??= new FcmSender(this.config.get('FCM_SERVICE_ACCOUNT_JSON', { infer: true })!);
    return this.fcm;
  }

  async sendToUser(userId: number, title: string): Promise<void> {
    try {
      const provider = this.config.get('PUSH_PROVIDER', { infer: true });
      if (provider === 'none') return;
      const devices = await this.prisma.deviceToken.findMany({ where: { userId }, select: { id: true, token: true } });
      if (devices.length === 0) return;
      if (provider === 'log') {
        // Title only: never log message bodies (they can contain handover codes) or tokens.
        this.logger.log(`push to user ${userId} (${devices.length} device(s)): ${title}`);
        return;
      }
      for (const d of devices) {
        const alive = await this.sender().send(d.token, title);
        if (!alive) await this.prisma.deviceToken.delete({ where: { id: d.id } }).catch(() => undefined);
      }
    } catch (e) {
      this.logger.warn(`push failed for user ${userId}: ${e instanceof Error ? e.message : String(e)}`);
    }
  }
}
