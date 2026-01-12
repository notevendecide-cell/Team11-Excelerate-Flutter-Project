# SkillTrack Pro — Backend (Node.js + Express + PostgreSQL)

This folder contains the SkillTrack Pro REST API.

## Tech

- Node.js + Express
- PostgreSQL (`pg`)
- JWT auth + role-based access control (RBAC)
- Zod request validation

## Prerequisites

- Node.js (LTS recommended)
- PostgreSQL 13+

## Setup

1) Install dependencies

```bash
cd backend
npm install
```

2) Configure environment

Copy the example env file:

```bash
cd backend
cp .env.example .env
```

Update `.env` if needed:

- `DATABASE_URL` (Postgres connection string)
- `JWT_SECRET` (set a strong value in production)
- `PORT` (default `3000`)

3) Create schema (migrations)

```bash
npm run migrate
```

4) Seed demo data (recommended for local dev)

```bash
npm run seed
```

The seed script reads optional values from `.env`:

- `SEED_ADMIN_EMAIL`, `SEED_MENTOR_EMAIL`, `SEED_LEARNER_EMAIL`
- `SEED_DEFAULT_PASSWORD`
- `SEED_DEMO_DATA=true`

## Run

Development (nodemon):

```bash
npm run dev
```

Production:

```bash
npm start
```

Server will log:

- `SkillTrack Pro API listening on :3000`

## API Overview

Base URL: `http://localhost:3000`

### Auth

- `POST /auth/login`
- `GET /auth/me`
- `POST /auth/request-password-reset` (dev prints reset link to console)
- `POST /auth/reset-password`

### Notifications

- `GET /notifications` (paginated)
- `GET /notifications/unread-count`
- `POST /notifications/:notificationId/read`

### Role routes

- `GET /learner/*` (learner-only)
- `GET /mentor/*` (mentor-only)
- `GET /admin/*` (admin-only)

## Common issues

- **Port already in use (`EADDRINUSE :3000`)**: stop the existing process or change `PORT`.
- **Database connection failures**: confirm Postgres is running and `DATABASE_URL` is correct.
- **Vercel + Supabase (`getaddrinfo ENOTFOUND`)**: use Supabase "Connection pooling" URL (pooler host + port `6543`). Some `db.<ref>.supabase.co` hosts are IPv6-only and can fail on IPv4-only serverless runtimes.

## Notes

- The backend is the single source of truth for permissions/authorization.
- Lists are paginated via `limit` and `offset` query params.
