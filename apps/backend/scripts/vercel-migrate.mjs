// Runs the database migrations during a Vercel production build, and only then.
// Preview builds must never touch the production database.
import { spawnSync } from 'node:child_process';

if (process.env.VERCEL_ENV !== 'production') {
  console.log(`Skipping migrations (VERCEL_ENV=${process.env.VERCEL_ENV ?? 'unset'}).`);
  process.exit(0);
}

// Migrations need a direct (non-pooled) connection; the app itself uses the pooled DATABASE_URL.
const url = process.env.DATABASE_URL_UNPOOLED || process.env.DATABASE_URL;
if (!url) {
  console.error('DATABASE_URL is not set: add the Postgres database to this Vercel project first.');
  process.exit(1);
}

const result = spawnSync('npx', ['prisma', 'migrate', 'deploy'], {
  stdio: 'inherit',
  env: { ...process.env, DATABASE_URL: url },
});
process.exit(result.status ?? 1);
