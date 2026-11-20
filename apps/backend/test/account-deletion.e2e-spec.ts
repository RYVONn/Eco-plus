import { randomUUID } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { PrismaService } from '../src/prisma/prisma.service.js';
import { TEST_PASSWORD, bagToPickup, bagToWeighed, createTestApp, login, registerCustomer } from './helpers.js';

describe('Deleting my own account', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let admin: string;
  let employee: string;
  let petId: number;
  const http = () => request(app.getHttpServer());
  const as = (token: string) => ({ Authorization: `Bearer ${token}` });

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
    admin = await login(app, 'admin@ecoplus.test');
    employee = await login(app, 'employee@ecoplus.test');
    petId = (await prisma.materialType.findUniqueOrThrow({ where: { name: 'PET plastic' } })).id;
  });
  afterAll(() => app.close());

  it('erases personal data, keeps the books, removes the photo and frees the phone number', async () => {
    const citizen = await registerCustomer(app);
    const before = await prisma.user.findUniqueOrThrow({ where: { id: citizen.id } });
    const { scan, weighingId } = await bagToWeighed(app, citizen, employee, petId);
    await prisma.deviceToken.create({ data: { userId: citizen.id, token: `tok-${randomUUID()}`, platform: 'android' } });
    await http().get(scan.imageUrl).set(as(admin)).expect(200);
    const ledgerBefore = await prisma.pointsLedger.count({ where: { userId: citizen.id } });
    expect(ledgerBefore).toBeGreaterThan(0);

    await http().delete('/me').set(as(citizen.token)).expect(204);

    const after = await prisma.user.findUniqueOrThrow({ where: { id: citizen.id } });
    expect(after).toMatchObject({ name: 'Deleted user', phone: null, email: null, isActive: false });
    expect(await prisma.refreshToken.count({ where: { userId: citizen.id } })).toBe(0);
    expect(await prisma.deviceToken.count({ where: { userId: citizen.id } })).toBe(0);
    expect(await prisma.notification.count({ where: { userId: citizen.id } })).toBe(0);
    expect(await prisma.pointsLedger.count({ where: { userId: citizen.id } })).toBe(ledgerBefore);
    expect(await prisma.weighingRecord.count({ where: { id: weighingId } })).toBe(1);
    expect(await prisma.bagScan.findUniqueOrThrow({ where: { id: scan.id } })).toMatchObject({ imageUrl: null, lat: null, lng: null });
    expect(await prisma.auditLog.count({ where: { action: 'account_deleted', targetUserId: citizen.id } })).toBe(1);

    await http().get('/me').set(as(citizen.token)).expect(401);
    await http().post('/auth/login').send({ identifier: before.phone, password: TEST_PASSWORD }).expect(401);
    await http().get(scan.imageUrl).set(as(admin)).expect(404);

    await http().post('/auth/register').send({ name: 'Sara Again', phone: before.phone, password: TEST_PASSWORD, role: 'citizen' }).expect(201);
  });

  it('lets a phone that signed in by code come back as a new account', async () => {
    const phone = `+2011${Math.floor(Math.random() * 1e8).toString().padStart(8, '0')}`;
    await http().post('/auth/otp/request').send({ phone }).expect(200);
    const first = await http().post('/auth/otp/verify').send({ phone, code: '123456', name: 'Omar Test' }).expect(200);

    await http().delete('/me').set(as(first.body.accessToken)).expect(204);

    await http().post('/auth/otp/request').send({ phone }).expect(200);
    const again = await http().post('/auth/otp/verify').send({ phone, code: '123456' }).expect(200);
    expect(again.body.isNew).toBe(true);
    expect(again.body.user.id).not.toBe(first.body.user.id);
  });

  it('refuses while a pickup is in progress and allows it after cancelling', async () => {
    const citizen = await registerCustomer(app);
    const { pickup } = await bagToPickup(app, citizen);
    expect(pickup.status).toBe(201);

    const refused = await http().delete('/me').set(as(citizen.token)).expect(409);
    expect(refused.body.code).toBe('pickup_in_progress');
    expect((await prisma.user.findUniqueOrThrow({ where: { id: citizen.id } })).isActive).toBe(true);

    await http().patch(`/pickup-requests/${pickup.body.request.id}/cancel`).set(as(citizen.token)).expect(200);
    await http().delete('/me').set(as(citizen.token)).expect(204);
  });

  it('refuses a business that is still owed cash until it is paid', async () => {
    const biz = await registerCustomer(app, 'business');
    const { weighingId } = await bagToWeighed(app, biz, employee, petId, { reward: 'cash' });

    const refused = await http().delete('/me').set(as(biz.token)).expect(409);
    expect(refused.body.code).toBe('payout_due');

    await http().post(`/admin/payouts/${weighingId}/pay`).set(as(admin)).expect(200);
    await http().delete('/me').set(as(biz.token)).expect(204);
    expect(await prisma.businessProfile.findUniqueOrThrow({ where: { userId: biz.id } })).toMatchObject({ businessName: 'Deleted business', lat: null, lng: null });
  });

  it('is for customers only and needs a login', async () => {
    await http().delete('/me').expect(401);
    await http().delete('/me').set(as(employee)).expect(403);
    await http().delete('/me').set(as(admin)).expect(403);
  });
});
