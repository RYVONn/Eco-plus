# Deploying on Vercel

Everything runs on Vercel's free Hobby plan: the API, the database (Neon, added from Vercel Storage) and, in the next change, the uploaded photos (Vercel Blob). Hobby is for personal, non-commercial use only. Move to Pro before real customers pay for anything.

Never commit secrets. Every value below is set in the Vercel project settings, not in the repository.

## Backend project (`apps/backend`)

1. Vercel, Add New, Project, import `RYVONn/Eco-plus`.
2. Root Directory: `apps/backend`. Framework preset: NestJS.
3. Build Command: `npm run vercel-build`. It generates the Prisma client, runs `prisma migrate deploy` on production deployments only, then builds. Preview deployments never migrate.
4. Storage tab, Create Database, Neon Postgres, connect it to this project. This adds `DATABASE_URL` (pooled) and `DATABASE_URL_UNPOOLED` (used for migrations).
5. Environment variables (Production):

| Name | Value |
|---|---|
| `NODE_ENV` | `production` |
| `JWT_ACCESS_SECRET` | 48 random characters |
| `CORS_ORIGINS` | the dashboard and app web URLs, comma separated |
| `TRUST_PROXY` | `1` (Vercel is one proxy hop) |
| `SWAGGER_ENABLED` | `false` |
| `PUSH_PROVIDER` | `none` until Firebase is set up |

6. Deploy, then open `/health`.

## First data

The seed refuses to run when `NODE_ENV=production`, so a new database has no levels, materials or admin. Run the seed once from a laptop against the new database with `NODE_ENV=development` and the Neon connection string in `DATABASE_URL` (copy it from the Vercel Storage tab; do not paste it into chat or commit it).

## Known limits on Vercel

- The whole API is one function; a request ends after 300 seconds on Hobby.
- The disk is read-only and not shared, so photos cannot be saved to `UPLOAD_DIR`. Uploads move to Vercel Blob in the next change; until then `POST /uploads/image` does not work in production.
- Neon scales to zero when idle, so the first request after a pause is slower.
- Runtime logs are kept for 1 hour on Hobby.
