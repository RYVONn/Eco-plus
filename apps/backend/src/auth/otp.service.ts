import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';
import { BadRequestException, HttpException, HttpStatus, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Env } from '../config/env.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { SmsService } from './sms.service.js';

const TTL_MS = 5 * 60 * 1000;
const RESEND_AFTER_MS = 30 * 1000;
const MAX_SENDS_PER_HOUR = 5;
const MAX_ATTEMPTS = 5;
const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;

@Injectable()
export class OtpService {
  private readonly log = new Logger(OtpService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly sms: SmsService,
    private readonly config: ConfigService<Env, true>,
  ) {}

  private hash(phone: string, code: string) {
    const key = this.config.get('JWT_ACCESS_SECRET', { infer: true });
    return createHmac('sha256', key).update(`${phone}:${code}`).digest('hex');
  }

  async request(phone: string): Promise<{ expiresInSeconds: number; resendAfterSeconds: number }> {
    const now = Date.now();
    const recent = await this.prisma.otpCode.findMany({
      where: { phone, failedAt: null, createdAt: { gt: new Date(now - HOUR_MS) } },
      orderBy: { createdAt: 'desc' },
      select: { createdAt: true },
    });
    const last = recent[0];
    if (recent.length >= MAX_SENDS_PER_HOUR || (last && now - last.createdAt.getTime() < RESEND_AFTER_MS)) {
      throw new HttpException(
        { code: 'otp_rate_limited', message: 'Too many codes requested. Try again in a moment.' },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    // A botnet can rotate phone numbers and IP addresses, so the total per day is capped as well.
    const dailyLimit = this.config.get('OTP_DAILY_LIMIT', { infer: true });
    if ((await this.prisma.otpCode.count({ where: { createdAt: { gt: new Date(now - DAY_MS) } } })) >= dailyLimit) {
      this.log.error(`Daily limit of ${dailyLimit} sign-in codes reached. New codes are refused until it drops.`);
      throw new HttpException(
        { code: 'otp_daily_limit', message: 'Sign-in codes are unavailable right now. Try again later.' },
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }

    const devCode = this.config.get('OTP_DEV_CODE', { infer: true });
    const code = devCode ?? String(randomInt(0, 1_000_000)).padStart(6, '0');
    const row = await this.prisma.otpCode.create({
      data: { phone, codeHash: this.hash(phone, code), expiresAt: new Date(now + TTL_MS) },
    });
    if (!devCode) {
      try {
        await this.sms.send(phone, `EcoPlus code: ${code}. It works for 5 minutes. Do not share it.`);
      } catch (e) {
        await this.prisma.otpCode.update({ where: { id: row.id }, data: { failedAt: new Date() } });
        this.log.error(`SMS failed for ${phone}: ${(e as Error).message}`);
        throw new HttpException(
          { code: 'sms_failed', message: 'Could not send the code. Try again shortly.' },
          HttpStatus.BAD_GATEWAY,
        );
      }
    }
    return { expiresInSeconds: TTL_MS / 1000, resendAfterSeconds: RESEND_AFTER_MS / 1000 };
  }

  /** Throws unless the newest live code for this phone matches. A code works once. */
  async verify(phone: string, code: string): Promise<void> {
    const row = await this.prisma.otpCode.findFirst({
      where: { phone, failedAt: null, consumedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
    });
    if (!row || row.attempts >= MAX_ATTEMPTS) throw new BadRequestException('The code is wrong or expired.');

    const expected = Buffer.from(row.codeHash, 'hex');
    const given = Buffer.from(this.hash(phone, code), 'hex');
    if (!timingSafeEqual(expected, given)) {
      await this.prisma.otpCode.update({ where: { id: row.id }, data: { attempts: { increment: 1 } } });
      throw new BadRequestException('The code is wrong or expired.');
    }
    const used = await this.prisma.otpCode.updateMany({
      where: { id: row.id, consumedAt: null },
      data: { consumedAt: new Date() },
    });
    if (used.count !== 1) throw new BadRequestException('The code is wrong or expired.');
  }
}
