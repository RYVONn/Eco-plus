import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { createTestApp, login, registerCustomer } from './helpers.js';

describe('Admin support, audit, contact, impact and alerts', () => {
  let app: INestApplication;
  let admin: string;
  let citizen: string;
  const as = (token: string) => ({ Authorization: `Bearer ${token}` });
  const http = () => request(app.getHttpServer());

  beforeAll(async () => {
    app = await createTestApp();
    admin = await login(app, 'admin@ecoplus.test');
    citizen = await login(app, 'citizen@ecoplus.test');
  });
  afterAll(() => app.close());

  it('takes contact messages from anyone and shows them to admins only', async () => {
    await http().post('/contact').send({ name: 'Mona', contact: '01012345678', message: 'We want a pickup for our cafe.' }).expect(201);
    await http().post('/contact').send({ name: 'Mona', contact: '01012345678', message: 'x' }).expect(422);
    const list = await http().get('/admin/contact-messages').set(as(admin)).expect(200);
    expect(list.body.items[0].name).toBe('Mona');
    await http().get('/admin/contact-messages').set(as(citizen)).expect(403);
  });

  it('serves impact and alerts to admins only', async () => {
    await http().get('/admin/impact').set(as(admin)).expect(200);
    await http().get('/admin/alerts').set(as(admin)).expect(200);
    await http().get('/admin/impact').set(as(citizen)).expect(403);
    await http().get('/admin/alerts').set(as(citizen)).expect(403);
  });

  it('records a support session in the audit log', async () => {
    const target = await registerCustomer(app);
    await http().post('/admin/support-sessions').set(as(admin)).send({ userId: target.id }).expect((r) => {
      if (r.status >= 400) throw new Error(`support session answered ${r.status}`);
    });
    const audit = await http().get('/admin/audit').set(as(admin)).expect(200);
    expect(audit.body.items.length).toBeGreaterThan(0);
    await http().get('/admin/audit').set(as(citizen)).expect(403);
  });
});
