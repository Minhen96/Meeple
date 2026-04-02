# Meeple

A board game community app for discovering games, tracking your collection, connecting with players, and organising game nights.

## Stack

| Layer    | Technology                                                                    |
| -------- | ----------------------------------------------------------------------------- |
| Frontend | SvelteKit + Tailwind CSS                                                      |
| Backend  | Spring Boot 3.5 (Java 21) + Gradle                                            |
| Database | Neon PostgreSQL (serverless) + Flyway migrations                              |
| Cache    | Upstash Redis                                                                 |
| Storage  | Cloudflare R2 + CDN                                                           |
| Auth     | JWT (httpOnly cookies) + Google OAuth                                         |
| Deploy   | Cloudflare Pages (frontend) + AWS Elastic Beanstalk (backend, ap-southeast-1) |

## Project Structure

```
boardgame/
├── backend/          # Spring Boot API
├── frontend/         # SvelteKit web app
├── docs/             # Architecture, design, and feature specs
└── .github/workflows # CI/CD pipelines
```

## Development Phases

- **Phase 1 (done):** Auth (email + Google OAuth), Game Library (BGG catalog), Collection, Play logs, Posts, Events, Matching, Friend requests, Notifications (in-app + WebSocket)
- **Phase 2 (current):** AI rule assistant (RAG + conversation), i18n (zh-CN), FCM push notifications
- **Phase 3:** Flutter mobile
- **Phase 4:** Stories, DMs, Leaderboards

## Getting Started

### Prerequisites
 
 - Java 21
 - Node.js 20+
 - PostgreSQL (or use Docker)
 - Redis (or use Docker)
 - MailHog (optional, for local email testing)
 
 ### 1. Start local services (recommended)
 
 The easiest way is using Docker Compose (starts PostgreSQL, Redis, and MailHog):
 
 ```bash
 docker compose up -d
 ```
 
 > [!NOTE]
 > **Local Email Testing:** All emails sent by the app in `local` mode are captured by MailHog. You can view them by visiting [**http://localhost:8025**](http://localhost:8025) in your browser.
 
 #### Manual Docker commands (Alternative)
 
 For Bash (Linux, macOS, Git Bash):
 
 ```bash
 docker run -d --name meeple-postgres \
   -p 5432:5432 \
   -e POSTGRES_PASSWORD=postgres \
   -e POSTGRES_DB=meeple_dev \
   pgvector/pgvector:pg16
 
 docker run -d --name meeple-redis \
   -p 6379:6379 \
   redis:alpine
 
 docker run -d --name meeple-mailhog \
   -p 1025:1025 \
   -p 8025:8025 \
   mailhog/mailhog
 ```
 
 For PowerShell (Windows):
 
 ```powershell
 docker run -d --name meeple-postgres `
   -p 5432:5432 `
   -e POSTGRES_PASSWORD=postgres `
   -e POSTGRES_DB=meeple_dev `
   pgvector/pgvector:pg16
 
 docker run -d --name meeple-redis `
   -p 6379:6379 `
   redis:alpine
 
 docker run -d --name meeple-mailhog `
   -p 1025:1025 `
   -p 8025:8025 `
   mailhog/mailhog
 ```

### 2. Configure backend env

Create `backend/.env`:

```env
SPRING_PROFILES_ACTIVE=local

# Google OAuth (required)
GOOGLE_CLIENT_ID=your-google-client-id

# JWT (required)
JWT_SECRET=local-dev-secret-must-be-at-least-256-bits-long-xx

# Email — Resend (needed for email verification flows)
RESEND_API_KEY=your-resend-api-key
EMAIL_FROM=noreply@meeple.yapminhen.com

# Cloudflare R2 (optional — omit to use mock defaults; file uploads won't work without it)
# R2_ENDPOINT=https://...r2.cloudflarestorage.com
# R2_ACCESS_KEY=
# R2_SECRET_KEY=
# R2_BUCKET=meeple-prod
# R2_PUBLIC_URL=https://cdn.yapminhen.com
```

> DB and Redis are not set here — the `local` profile defaults to `localhost:5432/meeple_dev` and `localhost:6379`.
> Flyway runs migrations automatically on first startup.

### 3. Run backend

```bash
cd backend
./gradlew bootRun
# Runs on http://localhost:8081
```

### 4. Run frontend

```bash
cd frontend
npm install
npm run dev
# Runs on http://localhost:5173
```

### 5. Configure AI providers (Phase 2)

Add to `backend/.env`:

```env
# Completion (DeepSeek, OpenAI, Groq, or any OpenAI-compatible provider)
AI_COMPLETION_BASE_URL=https://api.deepseek.com
AI_COMPLETION_API_KEY=sk-...
AI_COMPLETION_MODEL=deepseek-chat

# Embeddings (OpenAI only — DeepSeek has no embedding API)
AI_EMBEDDING_BASE_URL=https://api.openai.com
AI_EMBEDDING_API_KEY=sk-...
AI_EMBEDDING_MODEL=text-embedding-3-small
```

> If you skip this step, AI features (How to Play, AI Assistant, smart search) will not work, but the rest of the app runs normally.

### 6. Board Game Catalog — Admin-Controlled Data Pipeline

The backend has a **three-step data pipeline** that must be triggered manually by an admin. Nothing runs automatically on startup — you control when each step begins. All steps are tracked by Redis flags and are **crash-safe**: if the server restarts mid-run, each step resumes from where it stopped.

#### How to trigger: Profile → System button

Log in as an admin, go to **Profile → System**. The panel shows live progress bars for all 3 steps and lets you start/stop each one.

#### Step 1 — Game catalog import (`init:games-imported`)

1. Upload `boardgames.csv` (161k BGG games) to your R2 bucket
2. Set `SEED_CSV_URL=https://cdn.example.com/boardgames.csv` in your environment
3. In the System Setup panel, click **Check CSV Access** to verify the URL is reachable, then click **Start**
4. The backend downloads and imports the CSV (~2–3 min)

#### Step 2 — BGG hydration (`init:games-hydration-started`)

Click **Start** after the catalog import. Hits the BGG API in batches of 20 (1.1 s delay) to fill in mechanics, categories, player counts, designers, etc.

- Takes ~3 hours for 161k games due to BGG rate limiting
- Games become usable immediately — hydration fills in data progressively
- Watch logs: `Bulk hydration progress: X games hydrated so far...`

#### Step 3 — Rulebook pump (`init:rulebook-fetch`)

Click **Start** after hydration. Fetches PDF rulebooks for the top 10,000 games by BGG rank from [rule-book.org](https://rule-book.org) and [1jour1jeu](https://en.1jour-1jeu.com), then embeds them with `text-embedding-3-small`.

- **Estimated one-time cost**: ~$0.40 (embeddings only)
- **Crash-safe**: already-approved games are skipped on restart
- Watch logs: `Queued ingestion for '...' via rule_book_org`
- Verify completion: `SELECT status, COUNT(*) FROM game_rulebooks GROUP BY status`

For games not covered, users can click **"Generate Rules"** in the How to Play tab, or upload a PDF themselves (goes to admin review queue).

#### System Setup panel controls

- **Start** — triggers a step (safe to re-run; re-clears flags automatically)
- **Stop** — graceful stop for hydration and rulebook pump (stops after current batch/game)
- **Reset All Flags** — clears all Redis flags; use Start buttons to re-run each step

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
2. Add and verify your sending domain

### 5. AWS Elastic Beanstalk (backend)

1. Create an ECR repository named `meeple-backend-prod` in `ap-southeast-1`
2. Create an Elastic Beanstalk application named `Meeple-backend` with environment `Meeple-backend-env-v2`
3. Use the Docker platform — deployment uses `backend/Dockerrun.aws.json`
4. Set the environment variables listed below under **Backend env vars** in the EB environment configuration
5. Lock the instance count to 1 (required for WebSocket sticky sessions)

### 6. Cloudflare Pages (frontend)

1. In Cloudflare dashboard → Pages → Create project → Connect to Git
2. Build settings: Framework `SvelteKit`, build command `npm run build`, output `/frontend/.svelte-kit/cloudflare`
3. Set the environment variables listed below under **Frontend env vars**

### 7. GitHub Secrets (CI/CD)

Add these in your repo → Settings → Secrets → Actions:

```
AWS_ACCESS_KEY_ID      # IAM user with ECR push + EB deploy permissions
AWS_SECRET_ACCESS_KEY  # IAM user secret
AWS_ACCOUNT_ID         # Your AWS account ID (used to build the ECR URI)
```

---

### Backend env vars (Railway / Elastic Beanstalk)

```
# Database (Neon)
DB_URL=jdbc:postgresql://ep-xxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require
DB_USERNAME=neondb_owner
DB_PASSWORD=...

# Redis (Upstash)
REDIS_URL=rediss://default:xxx@xxx.upstash.io:6379

# Auth
JWT_SECRET=<base64-encoded 256-bit secret>
GOOGLE_CLIENT_ID=<google-oauth-client-id>

# Cookies
APP_AUTH_COOKIE_DOMAIN=.yapminhen.com
COOKIE_DOMAIN=yapminhen.com

# URLs
APP_BASE_URL=https://meeple.yapminhen.com
FRONTEND_URL=https://meeple.yapminhen.com

# Cloudflare R2  (endpoint must NOT include bucket name)
R2_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com
R2_ACCESS_KEY=...
R2_SECRET_KEY=...
R2_BUCKET=meeple-prod
R2_PUBLIC_URL=https://cdn.yapminhen.com

# Game catalog seed CSV (upload boardgames.csv to R2 first, then set this URL)
SEED_CSV_URL=https://cdn.yapminhen.com/boardgames.csv

# AI — Completion (DeepSeek / OpenAI / Groq — any OpenAI-compatible provider)
AI_COMPLETION_BASE_URL=https://api.deepseek.com
AI_COMPLETION_API_KEY=sk-...
AI_COMPLETION_MODEL=deepseek-chat

# AI — Embeddings (OpenAI only — DeepSeek has no embedding API)
AI_EMBEDDING_BASE_URL=https://api.openai.com
AI_EMBEDDING_API_KEY=sk-...
AI_EMBEDDING_MODEL=text-embedding-3-small

# Email (Resend)
RESEND_API_KEY=re_...
EMAIL_FROM=noreply@meeple.yapminhen.com

# Runtime
SPRING_PROFILES_ACTIVE=prod
JAVA_TOOL_OPTIONS=-Xms512m -Xmx1024m
```

> **R2 note:** The endpoint is your account-level S3 URL — do NOT append the bucket name. Example:
> `R2_ENDPOINT=https://abc123.r2.cloudflarestorage.com` ✓
> `R2_ENDPOINT=https://abc123.r2.cloudflarestorage.com/meeple-prod` ✗

### Frontend env vars (Cloudflare Pages dashboard)

```
NODE_VERSION=20
VITE_API_URL=https://meeple.api-prod.yapminhen.com
VITE_WS_URL=wss://meeple.api-prod.yapminhen.com/ws
VITE_R2_PUBLIC_URL=https://cdn.yapminhen.com
VITE_GOOGLE_CLIENT_ID=<google-oauth-client-id>
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

| Doc                             | Contents                                        |
| ------------------------------- | ----------------------------------------------- |
| `docs/PLAN.md`                  | DB schema, API endpoints, phases                |
| `docs/DESIGN.md`                | Colors, components, UI rules                    |
| `docs/TECH_STACK.md`            | Infrastructure, auth flow, project structure    |
| `docs/FEATURES_COMPLETE.md`     | Business rules and edge cases for every feature |
| `docs/SCREENS_AND_STATES.md`    | Every screen and UI state                       |
| `docs/ENGINEERING_STANDARDS.md` | Environments, CI/CD, monitoring, code quality   |
| `docs/AI_PLAN.md`               | AI feature build order, cost estimates, RAG pipeline design |
