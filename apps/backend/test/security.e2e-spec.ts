import { createServer, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import type { INestApplication } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import request from 'supertest';
import { PrismaService } from '../src/prisma/prisma.service.js';
import { createTestApp, login, registerCustomer } from './helpers.js';

const newPhone = () => `+2011${Math.floor(Math.random() * 1e8).toString().padStart(8, '0')}`;
const bearer = (token: string) => ({ Authorization: `Bearer ${token}` });

describe('JWT secret rotation', () => {
  const OLD = 'old-secret-0123456789-0123456789-0123456789';
  let rotating: INestApplication;
  let plain: INestApplication;

  beforeAll(async () => {
    rotating = await createTestApp([], { JWT_ACCESS_SECRET_PREVIOUS: OLD });
    plain = await createTestApp();
  });
  afterAll(async () => {
    await rotating.close();
    await plain.close();
  });

  it('accepts a token signed with the previous secret while rotating, and refuses any other secret', async () => {
    const customer = await registerCustomer(rotating);
    const sign = (secret: string) => new JwtService({ secret }).signAsync({ sub: customer.id, role: 'citizen' }, { expiresIn: '5m' });
    const http = () => request(rotating.getHttpServer());
    await http().get('/me').set(bearer(customer.token)).expect(200);
    await http().get('/me').set(bearer(await sign(OLD))).expect(200);
    await http().get('/me').set(bearer(await sign('another-secret-0123456789-0123456789-0123'))).expect(401);
  });

  it('refuses the old secret once no previous secret is configured', async () => {
    const customer = await registerCustomer(plain);
    const token = await new JwtService({ secret: OLD }).signAsync({ sub: customer.id, role: 'citizen' }, { expiresIn: '5m' });
    await request(plain.getHttpServer()).get('/me').set(bearer(token)).expect(401);
  });
});

describe('Phone codes per IP address', () => {
  const sendFrom = (app: INestApplication, ip: string) =>
    request(app.getHttpServer()).post('/auth/otp/request').set('X-Forwarded-For', ip).send({ phone: newPhone() });

  it('gives each client address its own allowance behind a trusted proxy', async () => {
    const app = await createTestApp([], { NODE_ENV: 'development', TRUST_PROXY: '1', OTP_IP_HOURLY_LIMIT: '2' });
    try {
      await sendFrom(app, '203.0.113.7').expect(200);
      await sendFrom(app, '203.0.113.7').expect(200);
      await sendFrom(app, '203.0.113.7').expect(429);
      await sendFrom(app, '203.0.113.8').expect(200);
    } finally {
      await app.close();
    }
  });

  it('ignores a forwarded address when no proxy is trusted, so it cannot be used to dodge the limit', async () => {
    const app = await createTestApp([], { NODE_ENV: 'development', OTP_IP_HOURLY_LIMIT: '2' });
    try {
      await sendFrom(app, '203.0.113.7').expect(200);
      await sendFrom(app, '203.0.113.8').expect(200);
      await sendFrom(app, '203.0.113.9').expect(429);
    } finally {
      await app.close();
    }
  });
});

describe('Daily budget for phone codes', () => {
  it('refuses new codes once the day is full and works again when it is not', async () => {
    const app = await createTestApp();
    const prisma = app.get(PrismaService);
    const expiresAt = new Date(Date.now() + 60_000);
    await prisma.otpCode.createMany({
      data: Array.from({ length: 200 }, (_, i) => ({ phone: `+2019999${String(i).padStart(5, '0')}`, codeHash: 'x', expiresAt })),
    });
    try {
      const full = await request(app.getHttpServer()).post('/auth/otp/request').send({ phone: newPhone() }).expect(503);
      expect(full.body.code).toBe('otp_daily_limit');
    } finally {
      await prisma.otpCode.deleteMany({ where: { phone: { startsWith: '+2019999' } } });
    }
    await request(app.getHttpServer()).post('/auth/otp/request').send({ phone: newPhone() }).expect(200);
    await app.close();
  });
});

describe('A failing SMS gateway', () => {
  let gateway: Server;
  let app: INestApplication;
  let prisma: PrismaService;
  let admin: string;
  const http = () => request(app.getHttpServer());

  beforeAll(async () => {
    gateway = createServer((_req, res) => {
      res.statusCode = 500;
      res.end('down');
    });
    await new Promise<void>((resolve) => gateway.listen(0, '127.0.0.1', resolve));
    const { port } = gateway.address() as AddressInfo;
    app = await createTestApp([], { OTP_DEV_CODE: '', SMS_WEBHOOK_URL: `http://127.0.0.1:${port}/sms` });
    prisma = app.get(PrismaService);
    admin = await login(app, 'admin@ecoplus.test');
  });
  afterAll(async () => {
    await app.close();
    gateway.close();
  });

  const failures = async () => {
    const res = await http().get('/admin/alerts').set(bearer(admin)).expect(200);
    return (res.body.items.find((i: { type: string }) => i.type === 'sms_failures')?.count ?? 0) as number;
  };

  it('answers 502, does not use up the phone allowance, and shows up in the admin alerts', async () => {
    const phone = newPhone();
    const before = await failures();

    const first = await http().post('/auth/otp/request').send({ phone }).expect(502);
    expect(first.body.code).toBe('sms_failed');
    // A code that was never sent does not start the resend wait.
    await http().post('/auth/otp/request').send({ phone }).expect(502);

    expect(await prisma.otpCode.count({ where: { phone, failedAt: { not: null } } })).toBe(2);
    expect(await failures()).toBe(before + 2);
    // A code that never reached the phone cannot be used to sign in.
    await http().post('/auth/otp/verify').send({ phone, code: '123456' }).expect(400);
  });
});
