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
