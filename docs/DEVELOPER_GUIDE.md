# SkillTrack Pro — Developer Guide

This guide explains how the project is structured and where to change things.

## Repository layout

- `frontend/` — Flutter mobile app (UI + API consumer)
- `backend/` — Node.js/Express REST API + PostgreSQL
- `docs/` — Project documentation (user manual + developer guide)

Design rules (important):

- The app must remain lightweight.
- No business logic/authorization decisions in Flutter; backend is authoritative.
- Minimize API calls; paginate list views.
- Do not store secrets in the app.

---

# Backend (Node.js + Express + PostgreSQL)

## Key folders

- `backend/src/app.js` — Express app wiring: routes, middleware, error handling
- `backend/src/db/` — database connection / helpers
- `backend/src/middleware/` — auth, RBAC, error handler
- `backend/src/routes/` — route modules:
  - `auth.js`
  - `learner.js`
  - `mentor.js`
  - `admin.js`
  - `notifications.js`
- `backend/migrations/` — SQL migrations
- `backend/seed/` — seed scripts / seed SQL

## How routing is wired

`backend/src/app.js` mounts:

- `GET /health`
- `/auth`
- `/learner`
- `/mentor`
- `/admin`
- `/notifications`

If you add a new route module, register it in `backend/src/app.js`.

## Auth + RBAC

- Authentication: JWT
- Password hashing: bcrypt
- RBAC: middleware checks user role for access

Change access rules in:

- `backend/src/middleware/auth.js` (token parsing)
- `backend/src/middleware/rbac.js` (role enforcement)

Important: RBAC must remain on the backend.

## Notifications

- Data is stored in a `notifications` table (read/unread).
- Unread badge count is supported through an endpoint in `backend/src/routes/notifications.js`.

When you add new actions (e.g., new submission events), generate notifications in the backend so all clients stay consistent.

## Migrations and seed

Typical dev setup:

1. Create database + user in PostgreSQL.
2. Set `DATABASE_URL` in `backend/.env`.
3. Run migrations.
4. Seed demo data.

See `backend/README.md` for exact commands (kept as the single source of truth).

## Common backend edits

- Add a new endpoint: create handler in the appropriate file under `backend/src/routes/`.
- Add a new DB field: create a migration in `backend/migrations/`, then update route queries.
- Add input validation: use Zod in the relevant route handler.

Do not:

- Put business logic in the client.
- Return internal stack traces to clients.

---

# Frontend (Flutter)

## Key folders

- `frontend/lib/app/` — app wiring (router, startup)
- `frontend/lib/screens/` — UI screens grouped by role:
  - `auth/`
  - `learner/`
  - `mentor/`
  - `admin/`
  - `shared/` (notifications, reusable screens)
- `frontend/lib/services/` — API client, auth storage, network helpers
- `frontend/lib/ui/` — reusable UI components (buttons, popups)

## Routing (go_router)

Main router is in:

- `frontend/lib/app/router.dart`

Patterns:

- Role-based redirects prevent opening routes for other roles.
- Keep new features behind navigation actions (lazy load by user intent).

When adding a screen:

1. Create the screen widget under the correct role folder.
2. Add a route in `frontend/lib/app/router.dart`.
3. Add a navigation entry point from an existing screen (button/menu).

## Notifications UX

- The bell icon badge uses `/notifications/unread-count`.
- Notification list items open a popup detail view and then mark read.

Popup helpers live in:

- `frontend/lib/ui/app_popups.dart`

Per project rules: prefer custom app popups over platform alerts.

## API base URL configuration

Where base URL is configured depends on the existing API client setup.

- Search for `baseUrl`, `API_BASE_URL`, or `http://` inside `frontend/lib/services/`.

Windows/device tips:

- Android emulator uses `10.0.2.2` to reach host machine.
- Physical device requires your machine LAN IP.

## Network failure handling

- Keep errors user-friendly.
- Show retry where useful.
- Avoid spamming multiple API calls.

---

# Change Map (Where to modify what)

## Add a new feature (example: “Learner Certificates”)

Backend:

- Add DB tables/migrations if needed.
- Add endpoints under `backend/src/routes/learner.js` (or a new `certificates.js` route module).
- Add RBAC rules.

Frontend:

- Add screen under `frontend/lib/screens/learner/`.
- Add route in `frontend/lib/app/router.dart`.
- Add API methods in `frontend/lib/services/`.

## Change submission locking rules

Backend:

- `backend/src/routes/learner.js` controls whether resubmission is allowed.

Frontend:

- `frontend/lib/screens/learner/task_detail_screen.dart` controls the locked UI behavior.

## Change mentor review behavior

Backend:

- `backend/src/routes/mentor.js` controls validation and persistence.

Frontend:

- `frontend/lib/screens/mentor/mentor_review_screen.dart` controls view/edit toggle UX.

---

# Local Dev Workflow

## Run backend

- From `backend/`: install deps, create `.env`, run migrations/seed, start server.

## Run frontend

- From `frontend/`: `flutter pub get`, `flutter run`.

Recommended:

- Keep backend running on a stable port.
- Avoid running multiple backend servers to prevent port conflicts.

---

# Troubleshooting

## 401/403 issues

- Confirm token is present in secure storage.
- Confirm backend role checks allow the action.

## Postgres type errors

- Ensure UUID/text casting is correct in SQL queries.
- Prefer explicit casts when building JSONB meta fields.

## Datetime validation errors

- Prefer `z.coerce.date()` when accepting date inputs from clients.
- Store ISO strings consistently.
