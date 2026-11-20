# Frontend build status (all roles, same design)

Branch: `feat/frontend-all-roles`. Frontend first with sample data, then connect the backend, then finish the backend.

Decisions (Moaz, 19 Nov 2026): logo = Sorted E (option 2). Digits are always Western (0-9), also in Arabic.

| Module | State |
|---|---|
| Brand foundation (tokens, Readex Pro, Sorted E, kit) | done, not yet run |
| Employee (16 screens, sample data) | done, not yet run |
| Driver (15 screens) | done, tests pass |
| Citizen (22 screens) | done, tests pass |
| Business (30 screens: sign-up, sell flow, pickups, wallet, invoices, branches, team) | done, tests pass (22 total) |
| Buyer/Factory, Admin web, portals | not started |
| Public sales website | last |

Not verified: Flutter is not installed in the cloud workspace, so `flutter pub get`, `analyze` and `test` have not run. Run the checks locally before opening the pull request.


## Update
- Buyer/Factory app, Admin (with support mode), and the two web portals (client and factory, shared `PortalShell`) are built with sample data.
- Public sales website (7 pages, AR/EN) is built at `/site`, open without login, in `lib/roles/site/`.
- Still to do: connect to the backend. Real mode is used only for a signed-in non-demo user; preview mode keeps sample data.

## Backend connection status

Real mode is used only for a signed-in non-demo user. Preview mode keeps the sample data. Nothing below has been run against a live backend yet; the checks at the end of the work decide.

Connected:
- Citizen: points and shipments, scan flow, handover code.
- Driver: route list (finished routes are `done`), start route, collect with the 6-digit handover code, bag photo upload and `POST /driver/stops/:shipmentId/proof`.
- Employee: shipments, materials and stock; real QR scan (camera through `mobile_scanner`, or typed code) with `GET /shipments/by-qr/:code`; weigh and reject through `POST /shipments/:id/weigh`.
- Business: pickups list from `/shipments`. A new pickup in real mode opens the photo scan flow, because the backend creates a pickup from a scan.
- Buyer and factory: live catalogue from `/catalog` as lots, orders from `/orders`, placing an order with `POST /orders`.
- Admin: overview (stats, impact, alerts), pickups, orders, factories and the audit log are real; the other pages keep design samples.
- Client and factory web portals: pickups, market and orders pages use the same real data.
- Public site: the contact form posts to `POST /contact` when name and mobile are filled.

Built in preview mode only: phone/code/profile steps in citizen onboarding (the code check is simulated), the citizen map tab (sample points on a drawn map), rewards and wallet (spending is local and never touches `points_ledger`; rewards are outside the MVP).

Still sample data in real mode: business wallet, branches and team; buyer contracts and scrap selling; the other admin pages; driver bag count, ETA, weight and address text (the API does not return them); employee batch details, customer names and estimates; admin support mode does not call `POST /admin/support-sessions` yet because the tables carry no account ids.

Backend added in this round (needs `npx prisma generate` and a migration run): `ContactMessage` and `AuditLog` tables, `POST /contact` (public, 5 per minute), `POST /admin/support-sessions`, `GET /admin/audit`, `GET /admin/contact-messages`, `GET /admin/impact` (CO2 factor 1.5 is a placeholder), `GET /admin/alerts`, `RouteStop.proofUrl`, `POST /driver/stops/:shipmentId/proof`, drivers may call `POST /uploads/image`, shipment weighing now includes the material name.

Built, needs credentials or real devices to finish:
- Phone sign-in by SMS code: backend `/auth/otp/request` and `/auth/otp/verify`, app screen `/phone`. Needs `SMS_WEBHOOK_URL` in production; `OTP_DEV_CODE` is for development only.
- Points or cash for business sellers: the pickup request carries `reward`; at weighing a cash seller gets a payout figure and no points. Rate uses the placeholder `pricePerKg`.
- Push notifications: backend `PUSH_PROVIDER=fcm` with `FCM_SERVICE_ACCOUNT_JSON`; app registers its token after a real login. Needs the Firebase project and `google-services.json` / `GoogleService-Info.plist`; run `flutter pub get` for the new packages.
- Real map SDK and the citizen camera screen in the newer design.
