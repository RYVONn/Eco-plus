import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { PrismaService } from '../src/prisma/prisma.service.js';
import { bagToWeighed, createTestApp, login, registerCustomer } from './helpers.js';

describe('Cash payouts to businesses', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let admin: string;
  let employee: string;
  let citizen: string;
  let petId: number;
  let price: number;
  const http = () => request(app.getHttpServer());
  const as = (token: string) => ({ Authorization: `Bearer ${token}` });

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
    admin = await login(app, 'admin@ecoplus.test');
    employee = await login(app, 'employee@ecoplus.test');
    citizen = await login(app, 'citizen@ecoplus.test');
    const pet = await prisma.materialType.findUniqueOrThrow({ where: { name: 'PET plastic' } });
    petId = pet.id;
    price = Number(pet.pricePerKg);
  });
  afterAll(() => app.close());

  const weighed = async (customer: Awaited<ReturnType<typeof registerCustomer>>, reward?: 'points' | 'cash') =>
    (await bagToWeighed(app, customer, employee, petId, { reward })).weighingId;

  it('lists a cash payout as unpaid and shows the business what it is owed', async () => {
    const biz = await registerCustomer(app, 'business');
    const weighingId = await weighed(biz, 'cash');

    const unpaid = await http().get('/admin/payouts?status=unpaid&limit=50').set(as(admin)).expect(200);
    expect(unpaid.body.items.some((i: { id: number }) => i.id === weighingId)).toBe(true);
    expect(Number(unpaid.body.totalEgp)).toBeGreaterThanOrEqual(10 * price);

    const mine = await http().get('/me/payouts').set(as(biz.token)).expect(200);
    expect(mine.body.items).toHaveLength(1);
    expect(Number(mine.body.dueEgp)).toBeCloseTo(10 * price, 2);
    expect(Number(mine.body.paidEgp)).toBe(0);
  });

  it('marks a payout paid once: audited, business notified, moved from unpaid to paid', async () => {
    const biz = await registerCustomer(app, 'business');
    const weighingId = await weighed(biz, 'cash');

    const paid = await http().post(`/admin/payouts/${weighingId}/pay`).set(as(admin)).expect(200);
    expect(paid.body.paidAt).toBeTruthy();

    await http().post(`/admin/payouts/${weighingId}/pay`).set(as(admin)).expect(409);

    const row = await prisma.weighingRecord.findUniqueOrThrow({ where: { id: weighingId } });
    expect(row.paidAt).not.toBeNull();
    expect(row.paidById).not.toBeNull();
    expect(await prisma.auditLog.count({ where: { action: 'payout_paid', targetUserId: biz.id } })).toBe(1);
    expect(await prisma.notification.count({ where: { userId: biz.id, title: 'Payout paid' } })).toBe(1);

    const mine = await http().get('/me/payouts').set(as(biz.token)).expect(200);
    expect(Number(mine.body.dueEgp)).toBe(0);
    expect(Number(mine.body.paidEgp)).toBeCloseTo(10 * price, 2);

    const unpaid = await http().get('/admin/payouts?status=unpaid&limit=50').set(as(admin)).expect(200);
    expect(unpaid.body.items.some((i: { id: number }) => i.id === weighingId)).toBe(false);
    const done = await http().get('/admin/payouts?status=paid&limit=50').set(as(admin)).expect(200);
    expect(done.body.items.some((i: { id: number }) => i.id === weighingId)).toBe(true);
  });

  it('lets only one of two simultaneous payments through', async () => {
    const biz = await registerCustomer(app, 'business');
    const weighingId = await weighed(biz, 'cash');
    const results = await Promise.all([
      http().post(`/admin/payouts/${weighingId}/pay`).set(as(admin)),
      http().post(`/admin/payouts/${weighingId}/pay`).set(as(admin)),
    ]);
    expect(results.map((r) => r.status).sort((a, b) => a - b)).toEqual([200, 409]);
    expect(await prisma.auditLog.count({ where: { action: 'payout_paid', targetUserId: biz.id } })).toBe(1);
  });

  it('raises an alert for cash left unpaid for over a week', async () => {
    const count = async () => {
      const res = await http().get('/admin/alerts').set(as(admin)).expect(200);
      return (res.body.items.find((i: { type: string }) => i.type === 'unpaid_payouts')?.count ?? 0) as number;
    };
    const biz = await registerCustomer(app, 'business');
    const weighingId = await weighed(biz, 'cash');
    const fresh = await count();

    await prisma.weighingRecord.update({ where: { id: weighingId }, data: { weighedAt: new Date(Date.now() - 8 * 24 * 60 * 60 * 1000) } });
    expect(await count()).toBe(fresh + 1);

    await http().post(`/admin/payouts/${weighingId}/pay`).set(as(admin)).expect(200);
    expect(await count()).toBe(fresh);
  });

  it('has nothing to pay for a points pickup or a missing weighing', async () => {
    const biz = await registerCustomer(app, 'business');
    const weighingId = await weighed(biz);
    await http().post(`/admin/payouts/${weighingId}/pay`).set(as(admin)).expect(404);
    await http().post('/admin/payouts/99999999/pay').set(as(admin)).expect(404);
    const mine = await http().get('/me/payouts').set(as(biz.token)).expect(200);
    expect(mine.body.items).toHaveLength(0);
  });

  it('keeps each business statement private and limits the endpoints by role', async () => {
    const owner = await registerCustomer(app, 'business');
    const other = await registerCustomer(app, 'business');
    const weighingId = await weighed(owner, 'cash');

    const otherView = await http().get('/me/payouts').set(as(other.token)).expect(200);
    expect(otherView.body.items).toHaveLength(0);

    await http().get('/admin/payouts').set(as(citizen)).expect(403);
    await http().get('/admin/payouts').set(as(owner.token)).expect(403);
    await http().post(`/admin/payouts/${weighingId}/pay`).set(as(employee)).expect(403);
    await http().post(`/admin/payouts/${weighingId}/pay`).set(as(owner.token)).expect(403);
    await http().get('/me/payouts').set(as(citizen)).expect(403);
    await http().get('/me/payouts').expect(401);
    await http().get('/admin/payouts?status=maybe').set(as(admin)).expect(422);
  });
});
