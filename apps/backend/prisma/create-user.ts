/**
 * Creates one real user with a role profile.
 * Run: USER_PASSWORD='...' DATABASE_URL=... npm run db:create-user -- <role> <email> <name> <phone> [factoryName]
 * Roles: admin, employee, driver, factory, citizen, business. Run db:seed-ref first.
 */
import 'dotenv/config';
import { PrismaPg } from '@prisma/adapter-pg';
import bcrypt from 'bcryptjs';
import { PrismaClient, type Role } from '../src/generated/prisma/client.js';

const ROLES: Role[] = ['admin', 'employee', 'driver', 'factory', 'citizen', 'business'];

const [roleArg, email, name, phone, factoryName] = process.argv.slice(2);
const password = process.env.USER_PASSWORD;

if (!ROLES.includes(roleArg as Role) || !email || !name || !phone || !password || password.length < 8) {
  console.error('Usage: USER_PASSWORD=<8+ chars> npm run db:create-user -- <role> <email> <name> <phone> [factoryName]');
  console.error('Roles:', ROLES.join(', '));
  process.exit(1);
}
const role = roleArg as Role;

const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
});

async function main() {
  const passwordHash = await bcrypt.hash(password!, 10);

  let factoryId: number | null = null;
  if (role === 'factory') {
    const fname = factoryName ?? `${name} factory`;
    const factory =
      (await prisma.factory.findFirst({ where: { name: fname } })) ??
      (await prisma.factory.create({ data: { name: fname, contact: email, address: 'To be set' } }));
    factoryId = factory.id;
  }

  const user = await prisma.user.upsert({
    where: { email },
    update: { name, role, phone, passwordHash, factoryId },
    create: { name, email, phone, role, passwordHash, factoryId },
  });

  if (role === 'citizen') {
    const bronze = await prisma.level.findUniqueOrThrow({ where: { name: 'Bronze' } });
    await prisma.citizenProfile.upsert({
      where: { userId: user.id },
      update: {},
      create: { userId: user.id, levelId: bronze.id, address: 'To be set', lat: 30.0444, lng: 31.2357 },
    });
  }
  if (role === 'business') {
    await prisma.businessProfile.upsert({
      where: { userId: user.id },
      update: {},
      create: { userId: user.id, businessName: name, businessType: 'cafe', lat: 30.0626, lng: 31.2497 },
    });
  }
  if (role === 'driver') {
    await prisma.driver.upsert({
      where: { userId: user.id },
      update: {},
      create: { userId: user.id, licenseNo: 'TO-BE-SET' },
    });
  }
  if (role === 'employee') {
    const warehouse = await prisma.warehouse.findFirstOrThrow({ where: { name: 'Main warehouse' } });
    await prisma.employee.upsert({
      where: { userId: user.id },
      update: {},
      create: { userId: user.id, warehouseId: warehouse.id, position: 'Weighing clerk' },
    });
  }

  console.log('User ready: %s (%s)', email, role);
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
