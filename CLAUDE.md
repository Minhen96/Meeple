# Meeple — Claude Code Instructions

## What This Project Is
A board game community + recording app. Stack: SvelteKit + Tailwind (frontend), Spring Boot Java 21 (backend), Neon PostgreSQL, Upstash Redis, Cloudflare R2, Flutter (mobile Phase 3).

**Always read the relevant doc before writing any code.** All decisions are locked — do not deviate without explicit user confirmation.

---

## Docs — What to Read Before Coding

| Area | Read This First |
|------|----------------|
| DB schema, API endpoints, phases | `docs/PLAN.md` |
| Colors, components, UI rules | `docs/DESIGN.md` |
| Infrastructure, project structure, auth flow, R2, Redis | `docs/TECH_STACK.md` + `docs/TECH_STACK_ADDITIONS.md` |
| Every feature's business rules and edge cases | `docs/FEATURES_COMPLETE.md` |
| Every screen, every UI state, navigation | `docs/SCREENS_AND_STATES.md` |
| Flutter architecture, packages, offline mode | `docs/MOBILE_FLUTTER.md` |
| Environments, circuit breakers, monitoring, code quality, git | `docs/ENGINEERING_STANDARDS.md` |

---

## Non-Negotiable Rules

### Backend
- All API routes prefixed `/api/v1/`
- Java 21, Spring Boot, Gradle (Kotlin DSL)
- Flyway for all DB migrations — never modify schema manually
- JWT in httpOnly cookie (web) / flutter_secure_storage (mobile)
- WebSocket STOMP: JWT passed in connect header, not URL
- No N+1 queries — use `@EntityGraph` or JOIN FETCH
- All scheduled jobs use Redis distributed lock (`setIfAbsent`) to prevent double-execution
- Circuit breakers (Resilience4j) on BGG API, OpenAI, FCM — never call external APIs without them
- Never log passwords, tokens, or email addresses

### Frontend (SvelteKit)
- Tailwind only — no inline styles, no external CSS libraries
- No-Line Rule: no `border` utilities except `border-white/10` on glass surfaces
- Color tokens from `docs/DESIGN.md` — never use raw hex values in templates
- API client always goes through `src/lib/api/client.ts` — never raw `fetch` in components
- TypeScript strict mode — no `any`

### Database
- `friend_requests` table (not `follows`) — Facebook model, must accept before friends
- `user_games` uses multi-boolean columns: `is_owned`, `is_wishlisted`, `is_favorited` (not a status enum)
- Soft deletes: `deleted_at` column on users, posts, events — never hard delete immediately
- All UUIDs as primary keys

### AI Feature
- Conversation mode: client keeps last 3 Q&A pairs in state, sends them in every prompt
- Embeddings: `text-embedding-3-small`, completion: `gpt-4o-mini`
- RAG source: `game_rules` table with `pgvector` similarity search

### Social
- Friend model: `friend_requests` table with `pending` / `accepted` / `declined` status
- UI language: "Add Friend" → "Pending" → "Friends" (never "Follow" / "Followers")
- Block: silently removes friendship, hides all content

---

## Development Phases — Do Not Skip Ahead

- **Phase 1 (current):** Auth (email + Google OAuth), Game Library (BGG), Collection, Posts, Events
- **Phase 2:** Matching, Notifications (WS + FCM), Social graph (friend requests), i18n
- **Phase 3:** AI assistant (RAG + conversation), Flutter mobile
- **Phase 4:** Stories, DMs, leaderboards

Only implement what the current phase requires. Do not add Phase 2+ code during Phase 1.

---

## Git Branching Strategy

```
main        — production-ready only. Direct push FORBIDDEN.
develop     — integration branch. All features merge here first.
feature/*   — individual features (e.g. feature/user-auth, feature/event-create)
fix/*       — bug fixes (e.g. fix/jwt-expiry)
chore/*     — non-feature work (deps, config, docs)
```

**Branch → Environment mapping:**
| Branch | Deploys To | DB |
|--------|-----------|-----|
| `main` | Production (Railway + Cloudflare Pages) | Neon `main` branch |
| `develop` | Staging (Railway staging + Cloudflare Pages preview) | Neon `staging` branch |
| `feature/*` | No auto-deploy (Cloudflare Pages PR preview URL only) | — |

**Flow:** `feature/* → develop (staging) → main (production)`
- Never commit directly to `main` or `develop`
- Every change goes through a PR
- Branch off from `develop`, not `main`
- Delete branch after merge

**Commit format (Conventional Commits):**
```
feat: add friend request accept endpoint
fix: correct JWT expiry calculation
chore: upgrade Spring Boot to 3.3
docs: update API endpoint table
test: add integration test for event creation
refactor: extract image compression to utility
```

**PR rules (GitHub branch protection on `main` and `develop`):**
- Require PR — no direct push
- Require CI to pass (test + lint + build) before merge
- Require branch to be up to date before merge
- Delete branch after merge

---

## Code Quality Standards

- 70% minimum test coverage (JaCoCo for backend)
- Integration tests use real Postgres + Redis (no mocking the DB)
- No `TODO` comments in committed code — either implement it or create an issue

---

## Environment Variables

Never hardcode secrets. All env vars documented in `docs/TECH_STACK_ADDITIONS.md` Section 24.

- Backend: set in Railway dashboard
- Frontend: set in Cloudflare Pages dashboard
- Local: `.env.local` (gitignored)

---

## When in Doubt

Read `docs/FEATURES_COMPLETE.md` Section 0 (Locked Design Decisions table) — it lists every confirmed architectural choice.
