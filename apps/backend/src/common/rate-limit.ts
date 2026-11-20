import { type CanActivate, type ExecutionContext, HttpException, HttpStatus, Injectable, SetMetadata } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import type { Request, Response } from 'express';
import type { Env } from '../config/env.js';

export interface RateLimitOptions {
  limit: number;
  ttl: number;
}

const OVERRIDE_KEY = 'rate-limit:override';
const SKIP_KEY = 'rate-limit:skip';

/** Overrides the limit of the named limiter ("default", "auth", "otp") on a controller or handler. */
export const Throttle = (overrides: Record<string, RateLimitOptions>): MethodDecorator & ClassDecorator =>
  SetMetadata(OVERRIDE_KEY, overrides);

export const SkipThrottle = (): MethodDecorator & ClassDecorator => SetMetadata(SKIP_KEY, true);

interface Limiter {
  name: string;
  ttl: number;
  limit: number;
  applies: (url: string) => boolean;
}

interface Hit {
  count: number;
  resetAt: number;
}

// Counters live in memory, so on serverless each instance counts on its own.
@Injectable()
export class RateLimitGuard implements CanActivate {
  private readonly hits = new Map<string, Hit>();
  private readonly limiters: Limiter[];
  private readonly disabled: boolean;
  private lastSweep = 0;

  constructor(
    private readonly reflector: Reflector,
    config: ConfigService<Env, true>,
  ) {
    this.disabled = config.get('NODE_ENV', { infer: true }) === 'test';
    this.limiters = [
      { name: 'default', ttl: 60_000, limit: config.get('THROTTLE_LIMIT', { infer: true }), applies: () => true },
      {
        // Stricter limit for login, register and refresh to slow down password guessing.
        name: 'auth',
        ttl: 60_000,
        limit: config.get('AUTH_THROTTLE_LIMIT', { infer: true }),
        applies: (url) => url.startsWith('/auth'),
      },
      {
        // Each phone code costs an SMS, so one IP address gets a small hourly allowance.
        name: 'otp',
        ttl: 3_600_000,
        limit: config.get('OTP_IP_HOURLY_LIMIT', { infer: true }),
        applies: (url) => url === '/auth/otp/request',
      },
    ];
  }

  canActivate(context: ExecutionContext): boolean {
    if (this.disabled || context.getType() !== 'http') return true;
    const targets = [context.getHandler(), context.getClass()];
    if (this.reflector.getAllAndOverride<boolean | undefined>(SKIP_KEY, targets)) return true;

    const http = context.switchToHttp();
    const req = http.getRequest<Request>();
    const res = http.getResponse<Response>();
    const overrides = this.reflector.getAllAndOverride<Record<string, RateLimitOptions> | undefined>(OVERRIDE_KEY, targets) ?? {};
    const now = Date.now();
    this.sweep(now);

    const route = `${context.getClass().name}.${context.getHandler().name}`;
    const tracker = req.ip ?? 'unknown';
    for (const limiter of this.limiters) {
      if (!limiter.applies(req.url)) continue;
      const { limit, ttl } = overrides[limiter.name] ?? limiter;
      const key = `${limiter.name}:${route}:${tracker}`;
      let hit = this.hits.get(key);
      if (!hit || hit.resetAt <= now) {
        hit = { count: 0, resetAt: now + ttl };
        this.hits.set(key, hit);
      }
      hit.count += 1;
      if (hit.count > limit) {
        res.setHeader('Retry-After', Math.max(1, Math.ceil((hit.resetAt - now) / 1000)));
        throw new HttpException('Too Many Requests', HttpStatus.TOO_MANY_REQUESTS);
      }
    }
    return true;
  }

  private sweep(now: number): void {
    if (now - this.lastSweep < 60_000) return;
    this.lastSweep = now;
    for (const [key, hit] of this.hits) if (hit.resetAt <= now) this.hits.delete(key);
  }
}
