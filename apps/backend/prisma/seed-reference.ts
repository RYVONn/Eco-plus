/**
 * Reference data for a real database: levels, materials and the main warehouse. No test accounts.
 * Safe to run more than once (everything is an upsert). Point factors and prices are PLACEHOLDERS
 * until real buyer prices exist. Run: DATABASE_URL=... npm run db:seed-ref
 */
import 'dotenv/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client.js';

const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
});

const LEVELS = [
  { name: 'Bronze', minPoints: 0, multiplier: 1.0 },
  { name: 'Silver', minPoints: 500, multiplier: 1.1 },
  { name: 'Gold', minPoints: 2000, multiplier: 1.25 },
  { name: 'Platinum', minPoints: 5000, multiplier: 1.5 },
];

const MATERIALS = [
  { name: 'PET plastic', pointFactor: 10, pricePerKg: 12 },
  { name: 'HDPE plastic', pointFactor: 8, pricePerKg: 9 },
  { name: 'Cardboard', pointFactor: 3, pricePerKg: 4 },
  { name: 'Paper', pointFactor: 2, pricePerKg: 3 },
  { name: 'Glass', pointFactor: 1, pricePerKg: 1 },
  { name: 'Aluminium', pointFactor: 20, pricePerKg: 40 },
  { name: 'Steel', pointFactor: 4, pricePerKg: 6 },
];

async function main() {
  for (const l of LEVELS) {
    await prisma.level.upsert({ where: { name: l.name }, update: l, create: l });
  }
  for (const m of MATERIALS) {
    await prisma.materialType.upsert({ where: { name: m.name }, update: m, create: m });
  }
  const warehouse = await prisma.warehouse.findFirst({ where: { name: 'Main warehouse' } });
  if (!warehouse) {
    await prisma.warehouse.create({
      data: { name: 'Main warehouse', address: 'To be set', capacityKg: 20000 },
    });
  }
  console.log('Reference data ready: %d levels, %d materials, main warehouse.', LEVELS.length, MATERIALS.length);
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
