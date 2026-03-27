# Tech Stack — Additional Infrastructure

> Appends to TECH_STACK.md. All missing pieces identified in planning phase.

---

## 14. Email Service — Resend

### Why Resend
- Modern JSON API (not just SMTP), developer-friendly
- Free tier: 3,000 emails/month, 100/day
- Reliable deliverability, built-in analytics per email type

### Spring Boot Integration

```kotlin
// build.gradle.kts
implementation("com.resend:resend-java:3.x")
```

```java
@Service
public class EmailService {
  private final Resend resend;

  public EmailService(@Value("${resend.api-key}") String apiKey) {
    this.resend = new Resend(apiKey);
  }

  public void sendVerificationEmail(String toEmail, String token) {
    String link = appBaseUrl + "/auth/verify-email?token=" + token;
    resend.emails().send(SendEmailRequest.builder()
      .from("Meeple & Hearth <noreply@meeple-hearth.com>")
      .to(toEmail)
      .subject("Verify your Meeple & Hearth account")
      .html(buildVerificationHtml(link))
      .build());
  }

  public void sendPasswordResetEmail(String toEmail, String token) { ... }
  public void sendAccountDeletionEmail(String toEmail) { ... }
  public void sendDataExportEmail(String toEmail, String downloadUrl) { ... }
}
```

### Templates Needed

1. Email Verification — "Verify your account"
2. Password Reset — "Reset your password" (token expires 1h)
3. Account Deletion Scheduled — "Your account will be deleted in 30 days"
4. Data Export Ready — "Your data export is ready to download"

**Shared template style:**
- Background: `#F8F9FA` (warm off-white)
- Header: "Meeple & Hearth" in `#895100`
- CTA button: gradient `#895100 → #FF9F1C`, `border-radius: 999px`
- Footer: "You received this because you have a Meeple & Hearth account."

**New environment variables:**
```
RESEND_API_KEY=re_xxxx
EMAIL_FROM=noreply@meeple-hearth.com
APP_BASE_URL=https://meeple-hearth.com
```

---

## 15. Error Monitoring — Sentry

### Why Sentry
- Industry standard, free tier 5,000 errors/month
- Automatic stack traces, user context, request breadcrumbs
- Works for both Spring Boot and SvelteKit

### Spring Boot

```kotlin
implementation("io.sentry:sentry-spring-boot-starter-jakarta:7.x")
```

```properties
sentry.dsn=${SENTRY_DSN}
sentry.traces-sample-rate=0.1
sentry.environment=${SPRING_PROFILES_ACTIVE:production}
sentry.send-default-pii=false
```

Sentry auto-captures all unhandled exceptions, slow DB queries, and request context.

Set user context after auth:
```java
Sentry.configureScope(scope -> {
  scope.setUser(new User());
  scope.getUser().setId(userId.toString());
});
```

### SvelteKit

```bash
npx @sentry/wizard@latest -i sveltekit
```

```typescript
// sentry.client.config.ts
import * as Sentry from "@sentry/sveltekit";
Sentry.init({
  dsn: import.meta.env.VITE_SENTRY_DSN,
  tracesSampleRate: 0.1,
  environment: import.meta.env.MODE,
});
```

After login: `Sentry.setUser({ id: user.id, username: user.username })`
After logout: `Sentry.setUser(null)`

**New environment variables:**
```
SENTRY_DSN=https://xxx@sentry.io/xxx         # Railway
VITE_SENTRY_DSN=https://xxx@sentry.io/xxx    # Cloudflare Pages
```

---

## 16. Analytics — PostHog

### Why PostHog
- Open-source, GDPR-compliant
- Free tier: 1M events/month
- Feature flags support for gradual rollouts

### SvelteKit

```bash
npm install posthog-js
```

```typescript
// src/lib/analytics.ts
import posthog from 'posthog-js';

export function initAnalytics() {
  posthog.init(import.meta.env.VITE_POSTHOG_KEY, {
    api_host: 'https://app.posthog.com',
    capture_pageview: false,
    persistence: 'memory',
  });
}

export const track = (event: string, props?: Record<string, unknown>) =>
  posthog.capture(event, props);

export const identify = (userId: string) => posthog.identify(userId);
```

**Key events:**
```typescript
track('signup_completed')
track('onboarding_completed', { skipped_bgg: boolean, games_added: number })
track('game_added_to_collection', { source: 'search' | 'bgg_import' })
track('event_created', { has_game: boolean, invited_count: number })
track('post_created', { has_images: boolean })
track('ai_rules_queried', { cached: boolean })
track('match_request_created')
track('match_accepted')
```

**New environment variable:**
```
VITE_POSTHOG_KEY=phc_xxxx
```

---

## 17. CI/CD — GitHub Actions

### Branch Strategy
```
main     → production (Railway + Cloudflare Pages)
develop  → staging
feature/* → PR preview (Cloudflare Pages preview URLs)
```

### Backend (.github/workflows/backend.yml)

```yaml
name: Backend CI/CD
on:
  push:
    branches: [main, develop]
    paths: ['backend/**']
  pull_request:
    paths: ['backend/**']

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: pgvector/pgvector:pg16
        env:
          POSTGRES_DB: meeple_test
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
        ports: ['5432:5432']
      redis:
        image: redis:7-alpine
        ports: ['6379:6379']
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '21', distribution: 'temurin' }
      - name: Run tests
        working-directory: backend
        run: ./gradlew test
        env:
          DB_URL: jdbc:postgresql://localhost:5432/meeple_test
          DB_USERNAME: postgres
          DB_PASSWORD: postgres
          REDIS_URL: redis://localhost:6379
          JWT_SECRET: test-secret-32-chars-minimum-here

  deploy:
    needs: test
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Railway
        run: |
          curl -fsSL https://railway.app/install.sh | sh
          railway up --service backend
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
```

### Frontend (.github/workflows/frontend.yml)

```yaml
name: Frontend CI/CD
on:
  push:
    branches: [main, develop]
    paths: ['frontend/**']
  pull_request:
    paths: ['frontend/**']

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
        working-directory: frontend
      - run: npm run check
        working-directory: frontend
      - run: npm run lint
        working-directory: frontend
      - run: npm run build
        working-directory: frontend
        env:
          VITE_API_URL: ${{ github.ref == 'refs/heads/main' && 'https://api.meeple-hearth.com' || 'https://staging-api.meeple-hearth.com' }}
      - uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CF_API_TOKEN }}
          accountId: ${{ secrets.CF_ACCOUNT_ID }}
          command: pages deploy frontend/.svelte-kit/cloudflare --project-name=meeple-hearth --branch=${{ github.ref_name }}
```

**GitHub Secrets to configure:**
```
RAILWAY_TOKEN
CF_API_TOKEN
CF_ACCOUNT_ID
```

---

## 18. Image Processing Pipeline

### Client-side (SvelteKit)

```bash
npm install browser-image-compression
```

```typescript
// src/lib/utils/image.ts
import imageCompression from 'browser-image-compression';

export async function compressPostImage(file: File): Promise<File> {
  return imageCompression(file, {
    maxSizeMB: 1,
    maxWidthOrHeight: 1200,
    useWebWorker: true,
    fileType: 'image/webp',
    initialQuality: 0.85,
  });
}

export async function compressAvatar(file: File): Promise<File> {
  return imageCompression(file, {
    maxSizeMB: 0.2,
    maxWidthOrHeight: 400,
    useWebWorker: true,
    fileType: 'image/webp',
  });
}
// EXIF is stripped automatically during re-encoding (privacy: GPS data removed)
```

### Thumbnail Strategy (MVP)

**Decision:** One size only — compressed 1200px max. Feed uses CSS `object-fit: cover`. Simple.

**Phase 2 upgrade:** Cloudflare Images transform on-the-fly:
```
https://cdn.meeple-hearth.com/posts/{id}/0.webp?width=400&height=400&fit=crop
https://cdn.meeple-hearth.com/posts/{id}/0.webp?width=1200
```
Cost: ~$5/month for 100K transformations.

---

## 19. Internal Search (PostgreSQL FTS)

No external search service in MVP. PostgreSQL full-text search is sufficient.

### User Search

```sql
ALTER TABLE users
  ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (
    to_tsvector('english',
      coalesce(username, '') || ' ' || coalesce(display_name, ''))
  ) STORED;

CREATE INDEX idx_users_search ON users USING GIN(search_vector);
```

Query:
```sql
SELECT * FROM users
WHERE search_vector @@ plainto_tsquery('english', $1)
  AND deleted_at IS NULL
ORDER BY ts_rank(search_vector, plainto_tsquery('english', $1)) DESC
LIMIT 20;
```

**Phase 3:** Migrate to **Typesense** (self-hosted, free) if FTS proves insufficient.

---

## 20. WebSocket Scaling Plan

### MVP: Single Instance

Spring Boot's `enableSimpleBroker` works on 1 Railway instance. Lock Railway to max 1 instance. Sufficient for early users.

### Phase 2: RabbitMQ Relay

When scaling beyond 1 instance, switch to RabbitMQ STOMP relay:

```kotlin
// build.gradle.kts
implementation("org.springframework.boot:spring-boot-starter-reactor-netty")
```

```java
registry.enableStompBrokerRelay("/topic", "/queue", "/user")
  .setRelayHost(rabbitHost)
  .setRelayPort(61613)
  .setClientLogin(rabbitUser)
  .setClientPasscode(rabbitPass);
```

Options for RabbitMQ hosting:
- Railway: add RabbitMQ plugin/service (~$5/month)
- CloudAMQP: free tier (1M messages/month)

---

## 21. Background Jobs Summary

All jobs use Spring `@Scheduled` + Redis distributed lock to prevent double-execution.

```java
// Distributed lock pattern for all scheduled jobs:
boolean locked = redis.opsForValue()
  .setIfAbsent("lock:" + jobName, "1", Duration.ofMinutes(lockTtlMinutes));
if (!locked) return;
try {
  runJob();
} finally {
  redis.delete("lock:" + jobName);
}
```

| Job | Cron/Interval | Lock TTL | Action |
|-----|--------------|---------|--------|
| `matching_job` | Every 30 min | 25 min | Run matching algorithm |
| `event_auto_complete` | Every 30 min | 25 min | Complete events 12h+ old |
| `event_reminder` | Every 1 hour | 55 min | Send 24h-before reminders |
| `match_request_expire` | Every 1 hour | 55 min | Expire stale match requests |
| `notification_cleanup` | Daily 3am UTC | 1 hour | Delete notifications > 90 days |
| `post_image_cleanup` | Daily 3am UTC | 1 hour | Delete R2 images of deleted posts > 30 days |
| `account_hard_delete` | Daily 3am UTC | 1 hour | Hard-delete accounts 30+ days after soft-delete |
| `bgg_data_refresh` | Weekly Sun 2am | 2 hours | Refresh cached game data |

---

## 22. Logging Strategy

**Log format:**
- Development: `%d{HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n`
- Production: JSON (Logstash encoder)

```kotlin
implementation("net.logstash.logback:logstash-logback-encoder:7.x")
```

```xml
<!-- logback-spring.xml — production profile -->
<springProfile name="production">
  <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
    <encoder class="net.logstash.logback.encoder.LogstashEncoder"/>
  </appender>
  <root level="INFO"><appender-ref ref="STDOUT"/></root>
  <logger name="com.meeplehearth" level="INFO"/>
  <logger name="org.springframework" level="WARN"/>
  <logger name="org.hibernate.SQL" level="WARN"/>
</springProfile>
```

**Log destinations:**
- MVP: Railway's built-in log viewer (7-day retention)
- Phase 2: Forward to **Logtail** (free tier: 1GB/month) for longer retention + search

**Security rule:** Never log passwords, tokens, or email addresses. Mask FCM tokens.

---

## 23. API Versioning

### URL Prefix: `/api/v1/`

All controllers:
```java
@RestController
@RequestMapping("/api/v1")
public class GameController { ... }
```

**Breaking change policy:**
- Adding optional response fields: no new version needed
- Adding new endpoints: no new version needed
- Removing or renaming fields: requires `/api/v2/`
- Changing required/optional on request fields: requires `/api/v2/`

**Deprecation timeline:** Keep v1 alive for 90 days after v2 launch (allows mobile users to update their app version).

---

## 24. Complete Environment Variables Reference

### Spring Boot (set in Railway dashboard)

```
DB_URL=jdbc:postgresql://ep-xxx.neon.tech/meeple?sslmode=require
DB_USERNAME=meeple_user
DB_PASSWORD=...

JWT_SECRET=<256-bit-random-hex-string>
JWT_EXPIRY_MS=900000

REDIS_URL=rediss://default:xxx@host.upstash.io:6379

R2_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com
R2_ACCESS_KEY=...
R2_SECRET_KEY=...
R2_BUCKET=meeple-hearth-media
R2_PUBLIC_URL=https://cdn.meeple-hearth.com

OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-4o-mini
OPENAI_EMBEDDING_MODEL=text-embedding-3-small

FIREBASE_SERVICE_ACCOUNT_JSON=<base64-encoded-json>

BGG_API_URL=https://boardgamegeek.com/xmlapi2

RESEND_API_KEY=re_...
EMAIL_FROM=noreply@meeple-hearth.com
APP_BASE_URL=https://meeple-hearth.com

SENTRY_DSN=https://xxx@sentry.io/xxx
SPRING_PROFILES_ACTIVE=production
SERVER_PORT=8080
```

### SvelteKit (set in Cloudflare Pages dashboard)

```
VITE_API_URL=https://api.meeple-hearth.com
VITE_WS_URL=wss://api.meeple-hearth.com/ws
VITE_R2_PUBLIC_URL=https://cdn.meeple-hearth.com
VITE_SENTRY_DSN=https://xxx@sentry.io/xxx
VITE_POSTHOG_KEY=phc_...
```

### Local Development (.env.local)

```
VITE_API_URL=http://localhost:8080
VITE_WS_URL=ws://localhost:8080/ws
VITE_R2_PUBLIC_URL=https://cdn.meeple-hearth.com
```
