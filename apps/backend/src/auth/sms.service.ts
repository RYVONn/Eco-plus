import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Env } from '../config/env.js';

@Injectable()
export class SmsService {
  private readonly log = new Logger(SmsService.name);

  constructor(private readonly config: ConfigService<Env, true>) {}

  /** Sends through the configured webhook. Without one the text is only logged (development). */
  async send(to: string, text: string): Promise<void> {
    const url = this.config.get('SMS_WEBHOOK_URL', { infer: true });
    if (!url) {
      this.log.log(`SMS to ${to}: ${text}`);
      return;
    }
    const token = this.config.get('SMS_WEBHOOK_TOKEN', { infer: true });
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
      body: JSON.stringify({ to, text }),
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) throw new Error(`SMS gateway answered ${res.status}`);
  }
}
