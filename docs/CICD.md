# CI/CD Pipelines

All pipelines live in `.github/workflows/`. Deploy and build workflows are triggered by a
successful **CI** run (`workflow_run`), so nothing ships unless backend, frontend and mobile
checks all pass. Each deploy workflow is a no-op (with a warning) until its secrets are set.

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `ci.yml` (CI) | PRs and pushes to `main` / `develop` | Backend: `./gradlew build` against Postgres (pgvector) + Redis, JaCoCo gate 85% line / 75% branch, plus a Docker image build. Frontend: type check, lint, Vitest with coverage gate (85/75), build. Mobile: build_runner, `flutter analyze`, `flutter test --coverage` with an 80% line gate. |
| `deploy-backend.yml` | CI success on a push to `main` (production) or `develop` (staging), or manual | `railway up` from `backend/`: Railway builds `backend/Dockerfile` and only switches traffic once `/actuator/health` passes (`backend/railway.toml`). Optional external smoke check. One deploy per branch at a time. |
| `deploy-frontend.yml` | CI success on a push to `main` (production) or `develop` (staging alias), or manual | Builds SvelteKit with adapter-cloudflare and deploys to Cloudflare Pages with `wrangler pages deploy`. |
| `build-mobile.yml` | CI success on a push to `main`, or manual | Builds a release APK (and AAB when a release keystore is configured) and uploads them as run artifacts. Optional unsigned iOS compile check on macOS. Store upload is not automated. |

Merging a PR into `main` therefore runs: **CI → (backend deploy ‖ frontend deploy ‖ mobile build)**; merging into `develop` runs CI → (backend + frontend staging deploys).

## Required configuration

Set these under *Settings → Secrets and variables → Actions*. Workflows use the GitHub
environments `production` (main) and `staging` (develop; backend and frontend); environment-level
values override repository-level ones, and an environment can require reviewer approval.

### Backend (Railway)
| Kind | Name | Notes |
|------|------|-------|
| secret | `RAILWAY_TOKEN` | Railway *project token* scoped to the matching Railway environment (set separately on the `production` and `staging` GitHub environments) |
| variable | `RAILWAY_SERVICE` | backend service name |
| variable | `BACKEND_HEALTH_URL` | optional, e.g. `https://api.example.com/actuator/health` |

Runtime variables live on the Railway service: `SPRING_PROFILES_ACTIVE=prod` (or `staging`),
`JWT_SECRET` (≥ 32 bytes), `DB_*`, `REDIS_URL`, `R2_*` incl. `R2_PRIVATE_BUCKET`, and the rest of
`TECH_STACK_ADDITIONS.md` §24. Railway injects `PORT`. Flyway applies pending migrations on
startup; to roll back, redeploy a previous deployment from the Railway dashboard.

Client IPs (used for rate limiting) are read from `X-Forwarded-For` only when the connecting proxy
is in Tomcat's trusted internal ranges. If Railway's edge connects from another range, every
request would share one IP; check `/actuator/health` logs or a test request, and if needed set
`SERVER_TOMCAT_REMOTEIP_INTERNAL_PROXIES` to a regex matching the proxy addresses.

If you prefer Railway's own GitHub integration (with "Wait for CI"), leave `RAILWAY_TOKEN` unset so
the workflow is a no-op.

### Frontend (Cloudflare Pages)
| Kind | Name | Notes |
|------|------|-------|
| secret | `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | token needs *Cloudflare Pages: Edit* |
| variable | `CLOUDFLARE_PAGES_PROJECT` | Pages project name; leave unset if the project uses Cloudflare's own Git integration (avoids double deploys) |
| variable | `VITE_API_URL` (required), `VITE_GOOGLE_CLIENT_ID`, `VITE_SENTRY_DSN`, `VITE_SENTRY_ENVIRONMENT`, `VITE_POSTHOG_KEY`, `VITE_POSTHOG_HOST`, `VITE_FIREBASE_*`, `VITE_TERMS_URL`, `VITE_PRIVACY_URL`, `VITE_FEEDBACK_EMAIL` | baked in at build time; set per environment |

Runtime server variables such as `COOKIE_DOMAIN` are set in the Cloudflare Pages dashboard.

### Mobile
| Kind | Name | Notes |
|------|------|-------|
| secret | `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | optional; without them only a debug-signed APK is built |
| variable | `MOBILE_API_BASE_URL`, `MOBILE_WEB_ORIGIN`, `GOOGLE_SERVER_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID`, `FIREBASE_*`, `POSTHOG_API_KEY`, `POSTHOG_HOST`, `MOBILE_SENTRY_DSN` | passed as `--dart-define`s (see `MOBILE_FLUTTER.md` §17) |
| variable | `ENABLE_IOS_BUILD=true` | enables the macOS iOS compile check |

## Recommended branch protection (main and develop)

Require a pull request, require the CI checks `backend`, `frontend` and `mobile` to pass,
require the branch to be up to date, and restrict direct pushes — as described in `CLAUDE.md`.
