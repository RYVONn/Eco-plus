import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { PrismaService } from '../src/prisma/prisma.service.js';
import { bagToPickup, createTestApp, login, registerCustomer } from './helpers.js';

const DEV_CODE = '123456';

describe('Phone sign-in (OTP)', () => {
  let app: INestApplication;
  const http = () => request(app.getHttpServer());
  const newPhone = () => `+2011${Math.floor(Math.random() * 1e8).toString().padStart(8, '0')}`;

  beforeAll(async () => {
    app = await createTestApp();
  });
  afterAll(async () => {
    await app.close();
  });

  it('creates a citizen on first sign-in and signs the same phone in again later', async () => {
    const phone = newPhone();
    await http().post('/auth/otp/request').send({ phone }).expect(200);
    const first = await http().post('/auth/otp/verify').send({ phone, code: DEV_CODE, name: 'Omar Test' }).expect(200);
    expect(first.body.isNew).toBe(true);
    expect(first.body.user.role).toBe('citizen');
    expect(first.body.accessToken).toBeTruthy();
    const me = await http().get('/me').set('Authorization', `Bearer ${first.body.accessToken}`).expect(200);
    expect(me.body.citizenProfile.totalPoints).toBe(0);

    // Resend is blocked for a short time, so wait is simulated by clearing the previous code row.
    await app.get(PrismaService).otpCode.deleteMany({ where: { phone } });
    await http().post('/auth/otp/request').send({ phone }).expect(200);
    const second = await http().post('/auth/otp/verify').send({ phone, code: DEV_CODE }).expect(200);
    expect(second.body.isNew).toBe(false);
    expect(second.body.user.id).toBe(first.body.user.id);
  });

  it('rejects a wrong code, a used code, and a phone with no code', async () => {
    const phone = newPhone();
    await http().post('/auth/otp/verify').send({ phone, code: DEV_CODE }).expect(400);
    await http().post('/auth/otp/request').send({ phone }).expect(200);
    await http().post('/auth/otp/verify').send({ phone, code: '000000' }).expect(400);
    await http().post('/auth/otp/verify').send({ phone, code: DEV_CODE }).expect(200);
    await http().post('/auth/otp/verify').send({ phone, code: DEV_CODE }).expect(400);
  });

  it('limits how fast codes can be requested and checks the input', async () => {
    const phone = newPhone();
    await http().post('/auth/otp/request').send({ phone }).expect(200);
    await http().post('/auth/otp/request').send({ phone }).expect(429);
    await http().post('/auth/otp/request').send({ phone: 'abc' }).expect(422);
    await http().post('/auth/otp/verify').send({ phone, code: '12' }).expect(422);
  });

  it('locks a code after too many wrong attempts', async () => {
    const phone = newPhone();
    await http().post('/auth/otp/request').send({ phone }).expect(200);
    for (let i = 0; i < 5; i++) await http().post('/auth/otp/verify').send({ phone, code: '000000' }).expect(400);
    await http().post('/auth/otp/verify').send({ phone, code: DEV_CODE }).expect(400);
  });
});

describe('Points or cash for business pickups', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let employee: string;
  let petId: number;
  let price: number;
  const http = () => request(app.getHttpServer());
  const as = (token: string) => ({ Authorization: `Bearer ${token}` });

  beforeAll(async () => {
    app = await createTestApp();
    prisma = app.get(PrismaService);
    employee = await login(app, 'employee@ecoplus.test');
    const pet = await prisma.materialType.findUniqueOrThrow({ where: { name: 'PET plastic' } });
    petId = pet.id;
    price = Number(pet.pricePerKg);
  });
  afterAll(async () => {
    await app.close();
  });

  async function weighed(customer: Awaited<ReturnType<typeof registerCustomer>>, reward?: 'points' | 'cash') {
    const { pickup } = await bagToPickup(app, customer, { fillLevel: 0.9, reward });
    expect(pickup.status).toBe(201);
    const id = pickup.body.shipment.id;
    await http().post(`/shipments/${id}/collect`).set(as(employee)).expect(200);
    const res = await http().post(`/shipments/${id}/weigh`).set(as(employee)).send({ materialTypeId: petId, actualWeightKg: 10, accepted: true }).expect(201);
    return { pickup: pickup.body, res: res.body };
  }

  it('pays a business that chose cash, with no points entries', async () => {
    const biz = await registerCustomer(app, 'business');
    const { pickup, res } = await weighed(biz, 'cash');
    expect(pickup.request.reward).toBe('cash');
    expect(res.pointsAwarded).toBe(0);
    expect(Number(res.payout)).toBeCloseTo(10 * price, 2);
    expect(await prisma.pointsLedger.count({ where: { userId: biz.id } })).toBe(0);
    const stored = await prisma.weighingRecord.findUniqueOrThrow({ where: { id: res.weighing.id } });
    expect(Number(stored.payout)).toBeCloseTo(10 * price, 2);
  });

  it('gives no payout when a business does not pick cash', async () => {
    const biz = await registerCustomer(app, 'business');
    const { pickup, res } = await weighed(biz);
    expect(pickup.request.reward).toBe('points');
    expect(res.payout).toBeNull();
  });

  it('ignores cash for a citizen: points are earned and nothing is paid', async () => {
    const citizen = await registerCustomer(app);
    const { pickup, res } = await weighed(citizen, 'cash');
    expect(pickup.request.reward).toBe('points');
    expect(res.payout).toBeNull();
    expect(res.pointsAwarded).toBeGreaterThan(0);
  });
});
