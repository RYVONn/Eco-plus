# EcoPlus backend

REST API for the EcoPlus smart recycling platform: citizens and businesses scan bags and request pickups,
drivers collect, employees weigh (the ground truth), points are awarded, material goes to the warehouse,
factories order. Design documents: the EcoPlus project document (use cases, ERD, table dictionary).

Stack: Node.js 24, NestJS 12 (TypeScript, ESM), PostgreSQL 16, Prisma 7, Zod, JWT, Vitest.

## Run it locally

You need Node 24 (`nvm use`) and a PostgreSQL 16 database.

```bash
npm install
cp .env.example .env        # then set DATABASE_URL and a real JWT_ACCESS_SECRET
npx prisma migrate dev      # creates the tables and the database rules
npm run db:seed             # levels, materials, one warehouse and factory, one test user per role
npm run start:dev           # http://localhost:3000, Swagger UI at /docs
```

With Docker instead: `docker compose up --build` starts PostgreSQL and the API (not yet tested on a
machine without Docker; see the note in the project hand-over).

Check it works: `curl localhost:3000/health` returns `{"status":"ok","db":"up",...}`.

### Test accounts (seed only, never in production)

`citizen@`, `business@`, `driver@`, `employee@`, `admin@`, `factory@` followed by `ecoplus.test`.
The password is the constant `TEST_PASSWORD` at the top of `prisma/seed.ts`. The seed refuses to run when
`NODE_ENV=production`. Point factors, prices, multipliers and capacities in the seed are placeholders until
real quotes and buyer prices exist.

## What Phase 1 does

```
citizen/business                          employee
POST /uploads/image  -> url
POST /scans          -> scan (material, fill level, location)
POST /pickup-requests {scanId}
   fill level below the threshold  -> 200 decision "wait", nothing stored
   fill level enough               -> 201 request + shipment with QR code (ECO-XXXXXXXXXX)
                                          POST /shipments/:id/collect      (staff; the driver app replaces this in Phase 2)
                                          GET  /shipments/by-qr/:code
                                          POST /shipments/:id/weigh        (one transaction)
GET /me/points, /leaderboard, /notifications, /shipments
                                          GET /warehouse/stock, /warehouse/batches, PATCH /warehouse/batches/:id
admin/employee: POST /admin/pickup-requests  (customer called or wrote on WhatsApp)
```

Rules worth knowing:
- Decision rule v1 is in `src/requests/decision.ts`: household bags need a fill level of `READY_FILL_THRESHOLD`
  (default 0.6), businesses `BUSINESS_READY_FILL_THRESHOLD` (0.4). The "merge nearby requests" decision is Phase 2.
- Points = weight x material point factor x level multiplier, rounded half up, only for citizens
  (businesses are weighed and get stock records but no points). Points are written to the append-only ledger.
- Weighing is one transaction under a row lock: weighing record, ledger row, cached total and level, batch
  weight, shipment status and notification all succeed together or not at all. The same weighing sent twice
  returns the first result (200); different values for an already weighed shipment give 409.
- A new batch is only started when no open batch exists for the same warehouse, material and grade.
- Photos are stored on local disk (`UPLOAD_DIR`) under random names and served only to logged-in users.

## What Phase 2 does (logistics)

Admin plans the day, the driver follows the stops, the customer proves the handover with a code.

1. **Fleet** (admin): `POST/GET/PATCH /vehicles`, `POST/GET/PATCH /drivers`. A driver is a normal login with role `driver`.
2. **Plan a route** (admin): `POST /routes` with driver, vehicle, date and shipment ids (up to 25). In one transaction every
   shipment becomes `assigned` with a fresh 6 digit **handover code**, its request becomes `scheduled`, and the customer is
   notified with the code. If any shipment is not waiting for a driver, nothing changes (two admins cannot take the same one).
3. **Stop order**: nearest-neighbour from the optional `start` point. With `GOOGLE_ROUTES_API_KEY` and a `start`, Google Routes API
   is asked first (max 25 stops) and any failure falls back to nearest-neighbour. The Google call is covered by tests with a fake
   response only; it has not been tried against the real service.
4. **Change a planned route**: `PUT /routes/:id/stop-order` (manual order), `DELETE /routes/:id/stops/:shipmentId`,
   `DELETE /routes/:id`. Removed shipments go back to `created` and the old code stops working. A started route is locked.
5. **Driver app API**: `GET /driver/routes` (today, Cairo time, or `?date=`), `POST /driver/routes/:id/start` (own day only, one at
   a time), `POST /driver/stops/:shipmentId/collect {handoverCode}`. The driver never sees the code; a wrong code is refused, the
   route must be started, and only the route's own driver can collect. The last collected stop finishes the route.
6. **Decision rule v2 (merge)**: a bag below the normal threshold but at least `MERGE_MIN_FILL` full is collected anyway when another
   shipment that is `created` or `assigned` is within `MERGE_RADIUS_M` metres. Its request has decision `merge`.
7. **Devices**: `POST /me/device-tokens`, `DELETE /me/device-tokens/:token`. `PUSH_PROVIDER=log` only logs how many phones would be
   notified; **sending real FCM messages is not built** (needs Firebase credentials). The in-app notification is always stored.

Staff can no longer mark a shipment that is on a route as collected (`409 on_driver_route`).

## What Phase 3 (factory side) does

1. **Materials** (admin): `POST/PATCH /materials`; `GET /materials` for admin, employee and factory. Changing a price affects only future orders.
2. **Factories** (admin): `POST/GET/PATCH /factories`, `POST /factories/:id/users` creates a login (role `factory`) tied to the factory.
3. **Catalog** (factory, admin): `GET /catalog` shows free stock per material and grade with the price. Reserved and sold batches are not shown.
4. **Order** (factory): `POST /orders` with lines `{materialTypeId, grade?, quantityKg}`. In one transaction the oldest batches are locked and
   reserved (a batch that is only partly needed is split; the part taken becomes a `reserved` batch). If any line cannot be covered,
   nothing is reserved and the answer is `409 insufficient_stock` with the available kg. Prices are copied into the order items.
5. **Status**: `placed -> confirmed -> dispatched -> delivered` (admin: `POST /orders/:id/confirm|dispatch|deliver`). Cancel with
   `POST /orders/:id/cancel`: a factory only while `placed`, an admin until `dispatched`; reserved stock goes back to `in_stock`.
6. **Delivery** makes the batches `sold` and issues the invoice in the same transaction: number `ECO-INV-YYYY-NNNNNN`, total = sum of
   kg x unit price (2 decimals), due `INVOICE_DUE_DAYS` (30) after delivery.
7. **Invoices**: `GET /invoices`, `GET /invoices/:id` (factory sees its own; others get 404), `POST /invoices/:id/pay` (admin). An unpaid
   invoice past its due date is shown as `overdue` when read; there is no background job.

Still open in Phase 3: admin dashboard numbers, impact report, capacity and low-stock alerts, audit log table, user and level management.

## Cash payouts, account deletion and sign-in limits

**Cash payouts.** A business can ask for cash instead of points (`reward: cash` on the pickup request). Weighing then stores
`payout = weight x pricePerKg` and writes no ledger entries. Cash is handed over outside the app, so an admin records it:

| Call | Who | What it does |
| --- | --- | --- |
| `GET /admin/payouts?status=unpaid\|paid` | admin | Payouts newest first, with the total of the whole filter (`totalEgp`) |
| `POST /admin/payouts/:weighingId/pay` | admin | Marks it paid. `409 already_paid` the second time, `404` when the weighing has no cash payout. Writes `payout_paid` to the audit log and notifies the business |
| `GET /me/payouts` | business | Its own statement with `dueEgp` and `paidEgp` |

Two admins paying at once cannot both win: the claim is one conditional update. `GET /admin/alerts` shows `unpaid_payouts` for cash unpaid over 7 days.

**Account deletion.** `DELETE /me` (citizen or business) erases name, phone, email, address, locations, bag photos, notifications and
device tokens, disables the login and writes `account_deleted` to the audit log. Weighings, points and shipments stay, without a name or
contact, because the factory's books depend on them. It answers `409 pickup_in_progress` while a pickup is open or waiting to be weighed
and `409 payout_due` while cash is still owed. The phone number can then be used for a new account. Staff accounts are removed by an admin.

**Limits on phone sign-in.** Per phone: 30 seconds between codes, 5 codes an hour, 5 wrong tries per code. Per IP address: the `/auth` limit
(`AUTH_THROTTLE_LIMIT` a minute) and `OTP_IP_HOURLY_LIMIT` codes an hour. All phones together: `OTP_DAILY_LIMIT` codes a day, then `503 otp_daily_limit`
and an error in the log, so a botnet cannot run up the SMS bill. A code the gateway refused is marked `failedAt`, does not count against the phone,
and shows in `GET /admin/alerts` as `sms_failures` (last hour).

**Behind a reverse proxy (Coolify).** Set `TRUST_PROXY=1`. Without it every user looks like the proxy's address and shares one rate limit. Use the
real number of proxies: a higher number lets a client fake its address with `X-Forwarded-For`. Mobile carriers share one address between many
users, so raise `OTP_IP_HOURLY_LIMIT` if real people get blocked.

**Rotating the JWT secret.** 1) Put the old value in `JWT_ACCESS_SECRET_PREVIOUS` and the new one in `JWT_ACCESS_SECRET`. 2) Deploy: new tokens use the new
secret, tokens signed with the old one still work. 3) After `JWT_ACCESS_TTL` has passed, empty `JWT_ACCESS_SECRET_PREVIOUS` and deploy again.
Refresh tokens are random values and are not affected. Phone codes sent in the last 5 minutes stop working at step 2 (the user asks for a new one).

## Tests

```bash
createdb ecoplus_test        # once
npm test                     # unit tests
npm run test:e2e             # end-to-end tests against the ecoplus_test database
```

The e2e setup applies migrations, empties the test database and seeds it, and refuses to run unless the
database name contains `ecoplus_test`. Connection details are in `.env.test`.

What the e2e tests prove today:
- health check and the common error shape (`{ code, message, details?, requestId }`);
- register, login, `/me`, refresh-token rotation with reuse detection, logout;
- role guard for every role, and that a disabled account loses access at once;
- the whole core flow, the decision rule, QR lookup, points and level-ups, the weighing transaction
  (failure at the last step saves nothing, a double or simultaneous submit gives one record), ownership
  and role checks, photo validation, staff-created requests, warehouse batches and stock;
- the database itself refuses: edits or deletes on `points_ledger`, zero or negative weights, two weighings
  for one shipment, duplicate QR codes, scan scores outside 0 to 1, negative stock.

## Structure

```
prisma/            schema, migrations (init + constraints), seed
src/config/        environment validation (fails fast at startup)
src/prisma/        database client module
src/common/        request id and logging, error filter, Zod validation pipe
src/auth/          register, login, refresh, logout, /me, guards and decorators
src/health/        GET /health
src/uploads/       bag photo upload and download
src/scans/         bag scans
src/requests/      pickup requests, decision rule, cancel
src/shipments/     shipments, QR codes, status machine, mark collected
src/weighing/      the weighing transaction (weight, points, batch, status, notification)
src/points/        points formula, ledger, level progression, leaderboard
src/warehouse/     batches and stock
src/notifications/ in-app notifications
src/admin/         staff create a request for a customer
test/              end-to-end tests
```

Every route needs a login unless marked `@Public()`. Restrict by role with `@Roles('admin', ...)`.

## How the database differs from the project document

The Prisma schema follows the dictionary (section 6b) with a few additions found while building:

| Change | Why |
| --- | --- |
| New table `refresh_tokens` | Refresh tokens are stored hashed so they can be revoked and rotated |
| `users.isActive` | Disable an account without deleting history |
| `bag_scans.source`, `lat`, `lng` | Know if the type came from the AI or by hand, and where the bag is |
| `pickup_requests.createdById` | Audit who created a request on behalf of a customer |
| `invoices.number`, `dueAt` | Invoice numbering and overdue calculation |
| `weighing_records.materialTypeId` optional | A rejected weighing may not have a known material |
| `shipments.status` has `cancelled` | A user can withdraw a request before collection |
| `invoices.paidAt` | When an invoice was paid |
| New table `device_tokens` | Phone push tokens for notifications |
| `shipments.status` can go `assigned` -> `created` | A planned route can be changed, the shipment returns to waiting |
| `points_ledger` trigger | Blocks UPDATE and DELETE, so history cannot be rewritten |

That makes 24 tables, not 22 as written in the document. Each change above also needs to be copied into the
project document (ERD and dictionary).

## Known limits

- Photos are not resized or compressed (needs a native image library); they live on the server's disk, not in
  object storage, so a second server would not see them. Move to S3-compatible storage before production.
- Warehouse changes are written to the application log; the proper audit table is a Phase 3 task.
- A customer created by staff has no usable password until password reset exists.
- A driver cannot report "customer not home"; a stop that cannot be collected has to be removed by an admin before the route starts, and after that it stays open.
- The 6 digit handover code is protected by a rate limit (10 tries a minute per IP) and the route checks, not by a per-code attempt counter.
- Stop order ignores traffic and vehicle capacity (no weight is known before weighing).
- Rate limiting is per IP (stricter on `/auth` and on phone codes). There is no per-account lockout for password login yet.
- Cash payouts are recorded by an admin after the cash is handed over. Nothing moves money in the app, and there is no way to undo "paid" (a wrong entry is fixed with a note in the audit log).
- The price per kilo behind cash payouts, and the CO2 factor, are placeholders until written factory quotes exist.
- Password reset, email and phone verification are not built.
- The Dockerfile and `docker-compose.yml` were written but not run (Docker is not installed on the
  development machine). CI is written but has not run yet because the repository is not on GitHub.
