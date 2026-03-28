# Meeple

A board game community app for discovering games, tracking your collection, connecting with players, and organising game nights.

## Stack

| Layer | Technology |
|-------|-----------|
| Frontend | SvelteKit + Tailwind CSS |
| Backend | Spring Boot 3.5 (Java 21) + Gradle |
| Database | Neon PostgreSQL (serverless) + Flyway migrations |
| Cache | Upstash Redis |
| Storage | Cloudflare R2 + CDN |
| Auth | JWT (httpOnly cookies) + Google OAuth |
| Deploy | Cloudflare Pages (frontend) + Railway (backend) |

## Project Structure

```
boardgame/
├── backend/          # Spring Boot API
├── frontend/         # SvelteKit web app
├── docs/             # Architecture, design, and feature specs
└── .github/workflows # CI/CD pipelines
```

## Development Phases

- **Phase 1 (current):** Auth, Game Library (BGG), Collection, Posts, Events
- **Phase 2:** Friend requests, Notifications (WebSocket + FCM), i18n
- **Phase 3:** AI rule assistant (RAG + conversation), Flutter mobile
- **Phase 4:** Stories, DMs, Leaderboards

## Getting Started

### Prerequisites

- Java 21
- Node.js 20+
- PostgreSQL (or use Docker)
- Redis (or use Docker)

### Local setup with Docker

```bash
docker-compose up -d   # starts Postgres + Redis
```

### Backend

```bash
cd backend
./gradlew bootRun
# Runs on http://localhost:8080
# Spring profile: local (default)
```

Copy `.env.local.example` to `.env.local` and fill in:

```
DB_URL=jdbc:postgresql://localhost:5432/meeple_dev
DB_USERNAME=postgres
DB_PASSWORD=postgres
REDIS_URL=redis://localhost:6379
JWT_SECRET=local-dev-secret-must-be-at-least-256-bits-long-xx
R2_ENDPOINT=
R2_ACCESS_KEY=
R2_SECRET_KEY=
R2_BUCKET=meeple-media
R2_PUBLIC_URL=
RESEND_API_KEY=
```

**Only `RESEND_API_KEY` is required locally** (for email verification). R2 keys are optional — file uploads won't work but the rest of the app runs fine.

## Staging / Production Setup

### 1. Neon PostgreSQL

1. Create a project at [neon.tech](https://neon.tech)
2. Create two branches: `main` (prod) and `staging`
3. For each branch, copy the connection string from the Neon dashboard
4. Enable the `pgvector` extension: `CREATE EXTENSION IF NOT EXISTS vector;`

### 2. Upstash Redis

1. Create a database at [upstash.com](https://upstash.com) (free tier)
2. Enable TLS — connection string starts with `rediss://`
3. Copy the connection string from the Upstash console

### 3. Cloudflare R2

1. In the Cloudflare dashboard → R2 → Create bucket `meeple-hearth-media`
2. Create an API token with R2 read/write permissions → copy Access Key ID + Secret Access Key
3. Set a custom domain for public access (e.g. `cdn.meeple-hearth.com`) under the bucket's Settings → Custom Domains
4. Endpoint format: `https://<account-id>.r2.cloudflarestorage.com`

### 4. Resend (email)

1. Sign up at [resend.com](https://resend.com) and create an API key
2. Add and verify your sending domain (e.g. `meeple-hearth.com`)

### 5. Railway (backend)

1. Create a new project at [railway.app](https://railway.app)
2. Add a service → deploy from GitHub → select the `backend/` directory
3. Set the environment variables listed below under **Backend env vars**
4. Set `SPRING_PROFILES_ACTIVE=production` (or `staging` for the staging service)
5. Lock the instance count to 1 (required for WebSocket — see `docs/TECH_STACK_ADDITIONS.md` §20)

### 6. Cloudflare Pages (frontend)

1. In Cloudflare dashboard → Pages → Create project → Connect to Git
2. Build settings: Framework `SvelteKit`, build command `npm run build`, output `/frontend/.svelte-kit/cloudflare`
3. Set the environment variables listed below under **Frontend env vars**

### 7. GitHub Secrets (CI/CD)

Add these in your repo → Settings → Secrets → Actions:

```
RAILWAY_TOKEN          # Railway API token
CF_API_TOKEN           # Cloudflare API token with Pages:Edit permission
CF_ACCOUNT_ID          # Cloudflare account ID
```

---

### Backend env vars (Railway dashboard)

```
DB_URL=jdbc:postgresql://ep-xxx.neon.tech/meeple?sslmode=require
DB_USERNAME=...
DB_PASSWORD=...
REDIS_URL=rediss://default:xxx@host.upstash.io:6379
JWT_SECRET=<256-bit random hex>
R2_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com
R2_ACCESS_KEY=...
R2_SECRET_KEY=...
R2_BUCKET=meeple-hearth-media
R2_PUBLIC_URL=https://cdn.meeple-hearth.com
RESEND_API_KEY=re_...
EMAIL_FROM=noreply@meeple-hearth.com
APP_BASE_URL=https://meeple-hearth.com
SPRING_PROFILES_ACTIVE=production
SERVER_PORT=8080
```

### Frontend env vars (Cloudflare Pages dashboard)

```
VITE_API_URL=https://api.meeple-hearth.com
VITE_WS_URL=wss://api.meeple-hearth.com/ws
VITE_R2_PUBLIC_URL=https://cdn.meeple-hearth.com
```

### Frontend

```bash
cd frontend
npm install
npm run dev
# Runs on http://localhost:5173
```

## API

Base URL: `/api/v1/`

All responses follow a consistent shape:

```json
// Success — single object
{ "data": { ... } }

// Success — paginated list
{ "data": [...], "meta": { "page": 1, "limit": 20, "total": 150, "hasMore": true } }

// Error
{ "error": "Description", "code": "ERROR_CODE" }
```

Auth endpoints (`/api/v1/auth/**`) are public. All others require a valid `access_token` httpOnly cookie.

## File Upload Flow

Images are uploaded directly to Cloudflare R2 — the backend never handles image bytes:

1. `POST /api/v1/upload/presign` → backend returns a presigned PUT URL (valid 10 min)
2. `PUT <presignedUrl>` with image bytes → client uploads directly to R2
3. Pass the returned `key` in the subsequent API call (e.g. create post)

## Git Workflow

```
feature/* → develop (staging) → main (production)
```

- Never push directly to `main` or `develop`
- All changes go through a PR
- Branch off from `develop`

Commit format: `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`

## Docs

| Doc | Contents |
|-----|---------|
| `docs/PLAN.md` | DB schema, API endpoints, phases |
| `docs/DESIGN.md` | Colors, components, UI rules |
| `docs/TECH_STACK.md` | Infrastructure, auth flow, project structure |
| `docs/FEATURES_COMPLETE.md` | Business rules and edge cases for every feature |
| `docs/SCREENS_AND_STATES.md` | Every screen and UI state |
| `docs/ENGINEERING_STANDARDS.md` | Environments, CI/CD, monitoring, code quality |
