# Meeple — Engineering Standards

> Code quality, scalability, observability, and operational standards.
> These apply from Day 1. No shortcuts that create technical debt.

---

## 1. Environment Strategy

### Three Environments

| Env | Backend | Database | Frontend | Purpose |
|-----|---------|----------|----------|---------|
| **local** | `localhost:8080` | Docker Compose Postgres | `localhost:5173` | Daily development |
| **staging** | Railway (staging service) | Neon (staging branch) | Cloudflare Pages (develop branch) | Pre-production testing |
| **production** | Railway (production service) | Neon (main branch) | Cloudflare Pages (main branch) | Real users |

### Neon Branch Strategy

```
Neon Project
├── main         → production DB
├── staging      → staging DB (branched from main weekly)
└── dev-{name}   → per-developer branch (optional, branch from main)
```

Benefits: Neon branches are instant and cheap. Staging always has a copy of production schema (with reset data).

### Spring Boot Profiles

```
src/main/resources/
├── application.properties          # shared config (port, app name, etc.)
├── application-local.properties    # local overrides (debug logging, Docker DB)
├── application-staging.properties  # staging-specific
└── application-production.properties # production (secrets from env vars, not files)
```

**Active profile set via env var:**
```
SPRING_PROFILES_ACTIVE=production   # Railway
SPRING_PROFILES_ACTIVE=staging      # Railway staging
SPRING_PROFILES_ACTIVE=local        # local (set in IDE or shell)
```

**Never commit secrets.** All sensitive values in `application-production.properties` are placeholders:
```properties
# application-production.properties
db.url=${DB_URL}
jwt.secret=${JWT_SECRET}
resend.api-key=${RESEND_API_KEY}
```

### SvelteKit Environments

```
.env.local         # local dev (gitignored)
.env.staging       # staging values (committed, no secrets)
.env.production    # production values (set in Cloudflare Pages dashboard, NOT committed)
```

---

## 2. Circuit Breakers — Resilience4j

All calls to external services (BGG API, OpenAI, Firebase FCM) must be wrapped in circuit breakers. If BGG goes down, the app should degrade gracefully — not throw 500s to users.

### Dependency

```kotlin
// build.gradle.kts
implementation("io.github.resilience4j:resilience4j-spring-boot3:2.x")
implementation("io.github.resilience4j:resilience4j-reactor:2.x")  // for WebClient
```

### Configuration

```yaml
# application.properties (YAML format for resilience4j)
resilience4j:
  circuitbreaker:
    instances:
      bgg-api:
        registerHealthIndicator: true
        slidingWindowSize: 10
        minimumNumberOfCalls: 5
        permittedNumberOfCallsInHalfOpenState: 3
        automaticTransitionFromOpenToHalfOpenEnabled: true
        waitDurationInOpenState: 30s
        failureRateThreshold: 50        # 50% failure rate → open circuit
        eventConsumerBufferSize: 10

      openai-api:
        slidingWindowSize: 10
        failureRateThreshold: 50
        waitDurationInOpenState: 60s    # OpenAI is slower to recover, wait longer
        slowCallDurationThreshold: 10s  # calls > 10s counted as failures
        slowCallRateThreshold: 80

      firebase-fcm:
        slidingWindowSize: 20
        failureRateThreshold: 60
        waitDurationInOpenState: 30s

  retry:
    instances:
      bgg-api:
        maxAttempts: 3
        waitDuration: 1s
        enableExponentialBackoff: true
        exponentialBackoffMultiplier: 2    # 1s, 2s, 4s
        retryExceptions:
          - java.io.IOException
          - java.util.concurrent.TimeoutException

      openai-api:
        maxAttempts: 2
        waitDuration: 2s

  timelimiter:
    instances:
      bgg-api:
        timeoutDuration: 10s
      openai-api:
        timeoutDuration: 30s      # AI calls can be slow
      firebase-fcm:
        timeoutDuration: 5s
```

### Usage in Services

```java
// BggApiClient.java
@CircuitBreaker(name = "bgg-api", fallbackMethod = "searchGamesFallback")
@Retry(name = "bgg-api")
@TimeLimiter(name = "bgg-api")
public CompletableFuture<List<GameDto>> searchGames(String query) {
  return CompletableFuture.supplyAsync(() -> {
    // ... BGG API call
  });
}

// Fallback: return empty results gracefully
public CompletableFuture<List<GameDto>> searchGamesFallback(String query, Exception e) {
  log.warn("BGG API circuit breaker open, returning empty results: {}", e.getMessage());
  return CompletableFuture.completedFuture(Collections.emptyList());
}

// AiService.java
@CircuitBreaker(name = "openai-api", fallbackMethod = "askRulesFallback")
public String askRules(UUID gameId, String question) { ... }

public String askRulesFallback(UUID gameId, String question, Exception e) {
  throw new ServiceUnavailableException("AI_UNAVAILABLE",
    "The AI assistant is temporarily unavailable. Please try again later.");
}
```

### Circuit Breaker States

```
CLOSED (normal) → 50% failure rate → OPEN (rejecting calls)
OPEN → after 30s → HALF_OPEN (let 3 calls through as test)
HALF_OPEN → all succeed → CLOSED again
HALF_OPEN → any fail → OPEN again
```

---

## 3. Monitoring

### Stack

| Layer | Tool | Why |
|-------|------|-----|
| Metrics collection | Spring Boot Actuator + Micrometer | Built into Spring Boot, zero config |
| Metrics storage + dashboard | **Grafana Cloud** (free tier) | 10K series free, beautiful dashboards |
| Log aggregation | **Grafana Loki** (via Grafana Cloud) | Same dashboard, free 50GB/month |
| Uptime monitoring | **Better Uptime** (free) | Ping `/actuator/health` every 5 min, alert on down |
| Error tracking | Sentry (already in TECH_STACK.md) | — |

### Actuator Setup

```properties
# application.properties
management.endpoints.web.exposure.include=health,info,metrics,prometheus,circuitbreakers
management.endpoint.health.show-details=when_authorized
management.health.circuitbreakers.enabled=true
management.metrics.export.prometheus.enabled=true
```

**Expose `/actuator/prometheus` only to internal network** (Railway internal or secured with bearer token):
```java
@Bean
public SecurityFilterChain actuatorSecurity(HttpSecurity http) throws Exception {
  http.securityMatcher("/actuator/**")
    .authorizeHttpRequests(auth -> auth
      .requestMatchers("/actuator/health").permitAll()   // Railway health check
      .anyRequest().hasRole("ACTUATOR_ADMIN"))           // Prometheus scrape + internal
    .httpBasic(withDefaults());
  return http.build();
}
```

### Key Metrics to Monitor

**Application metrics (auto-collected by Micrometer):**
- `http_server_requests_seconds` — p50/p95/p99 latency per endpoint
- `http_server_requests_total` — request count + error rate
- `jvm_memory_used_bytes` — heap memory usage
- `hikaricp_connections_active` — DB connection pool usage
- `resilience4j_circuitbreaker_state` — circuit breaker open/closed/half-open

**Custom metrics to add:**
```java
// In each service, inject MeterRegistry
private final Counter postCreatedCounter;
private final Counter aiQueriesCounter;
private final Timer bgApiResponseTimer;

// In PostService.createPost():
postCreatedCounter.increment();

// In BggApiClient:
Timer.Sample sample = Timer.start(meterRegistry);
// ... BGG call ...
sample.stop(bgApiResponseTimer);
```

**Custom metrics list:**
- `meeple_posts_created_total` — posts created per day
- `meeple_events_created_total` — events created
- `meeple_ai_queries_total{cached}` — AI usage + cache hit rate
- `meeple_bgg_api_duration_seconds` — BGG API response time
- `meeple_matching_groups_created_total` — matching job output
- `meeple_websocket_connections_active` — current WS connections

### Grafana Cloud Setup

1. Create free account at grafana.com
2. Create a Prometheus data source pointing to your Spring Boot `/actuator/prometheus`
3. Import the official Spring Boot Grafana dashboard (ID: 11378)
4. Create custom panels for Meeple-specific metrics
5. Set up alerts:
   - Alert if error rate > 5% over 5 minutes
   - Alert if p95 latency > 2s
   - Alert if circuit breaker is OPEN
   - Alert if DB connection pool > 80% utilization

### Logging (Grafana Loki)

```xml
<!-- logback-spring.xml — production profile -->
<springProfile name="production">
  <appender name="LOKI" class="com.github.loki4j.logback.Loki4jAppender">
    <http>
      <url>${LOKI_URL}</url>
    </http>
    <format>
      <label>
        <pattern>app=meeple,env=production,host=${HOSTNAME}</pattern>
      </label>
      <message class="com.github.loki4j.logback.JsonLayout"/>
    </format>
  </appender>
  <root level="INFO">
    <appender-ref ref="LOKI"/>
    <appender-ref ref="STDOUT"/>
  </root>
</springProfile>
```

```kotlin
implementation("com.github.loki4j:loki-logback-appender:1.x")
```

**New environment variable:**
```
LOKI_URL=https://logs-prod-xxx.grafana.net/loki/api/v1/push
GRAFANA_METRICS_USER=xxx
GRAFANA_METRICS_KEY=xxx
```

---

## 4. Database Backup Strategy

### Neon Built-in (Primary)

Neon provides **Point-in-Time Recovery (PITR)**:
- Free tier: 7-day restore window
- Pro tier: 30-day restore window
- Automatic — no setup needed

**How to restore:** Neon dashboard → Branch → Restore to point in time → creates new branch with that state → verify → promote to main.

### Secondary Backup (pg_dump to R2)

For extra safety, daily SQL dumps stored in Cloudflare R2:

```yaml
# .github/workflows/backup.yml
name: Database Backup
on:
  schedule:
    - cron: '0 2 * * *'    # 2am UTC daily
  workflow_dispatch:         # allow manual trigger

jobs:
  backup:
    runs-on: ubuntu-latest
    steps:
      - name: Install pg_dump
        run: sudo apt-get install -y postgresql-client

      - name: Dump database
        env:
          DATABASE_URL: ${{ secrets.PRODUCTION_DB_URL }}
        run: |
          FILENAME="backup-$(date +%Y-%m-%d).sql.gz"
          pg_dump "$DATABASE_URL" | gzip > "$FILENAME"
          echo "FILENAME=$FILENAME" >> $GITHUB_ENV

      - name: Upload to R2
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CF_API_TOKEN }}
          command: r2 object put meeple-backups/${{ env.FILENAME }} --file=${{ env.FILENAME }}

      - name: Delete backups older than 30 days
        # List R2 objects, delete those > 30 days old
        run: echo "Cleanup old backups"
```

**Backup retention:** 30 daily backups kept in R2 (separate `meeple-backups` bucket, not public).

### Backup Verification (Monthly)

Once a month:
1. Restore latest backup to a Neon dev branch
2. Run `SELECT COUNT(*) FROM users, posts, events` — verify row counts match
3. Document in a simple "backup log" (Notion or Google Doc)

---

## 5. Code Quality Standards

### Backend (Spring Boot)

**Linting / Static Analysis:**
```kotlin
// build.gradle.kts
plugins {
  id("checkstyle")
  id("com.github.spotbugs") version "6.x"
  id("org.sonarqube") version "5.x"       // free for public repos
}

checkstyle {
  toolVersion = "10.x"
  configFile = file("config/checkstyle/checkstyle.xml")
}

spotbugs {
  effort = com.github.spotbugs.snom.Effort.MAX
  reportLevel = com.github.spotbugs.snom.Confidence.MEDIUM
  excludeFilter = file("config/spotbugs/exclude.xml")
}
```

**Code style rules (checkstyle.xml):**
- Max line length: 120 chars
- No wildcard imports (`import java.util.*`)
- No unused imports
- Braces required for all blocks
- Javadoc required on all public methods (at least one-liner)

**Test coverage minimum:**
```kotlin
jacoco {
  toolVersion = "0.8.x"
}
jacocoTestCoverageVerification {
  violationRules {
    rule {
      limit { minimum = "0.70".toBigDecimal() }  // 70% line coverage minimum
    }
  }
}
tasks.named("check") { dependsOn("jacocoTestCoverageVerification") }
```

**SonarCloud** (free for public repos):
- Add `SONAR_TOKEN` to GitHub secrets
- Add Sonar analysis step to CI pipeline
- Tracks: code smells, bugs, vulnerabilities, coverage trends over time

### Frontend (SvelteKit)

```bash
# package.json scripts
"lint": "eslint src --ext .ts,.svelte",
"format": "prettier --write src",
"check": "svelte-check --tsconfig ./tsconfig.json",
"test": "vitest run",
"test:e2e": "playwright test"
```

**ESLint config (`.eslintrc.cjs`):**
```js
module.exports = {
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:svelte/recommended',
    'prettier'
  ],
  rules: {
    '@typescript-eslint/no-unused-vars': 'error',
    '@typescript-eslint/no-explicit-any': 'error',   // no `any` types
    'no-console': ['warn', { allow: ['warn', 'error'] }],
  }
};
```

**Prettier config (`.prettierrc`):**
```json
{
  "useTabs": true,
  "singleQuote": true,
  "trailingComma": "es5",
  "printWidth": 100,
  "plugins": ["prettier-plugin-svelte"],
  "overrides": [{ "files": "*.svelte", "options": { "parser": "svelte" } }]
}
```

**TypeScript:** strict mode enabled
```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true
  }
}
```

### Git Workflow

```
main        — production-ready code only. Direct push forbidden.
develop     — integration branch. All features merge here first.
feature/*   — individual feature branches (e.g., feature/event-matching)
fix/*       — bug fixes
chore/*     — non-feature work (deps, config, docs)
```

**Branch naming:** `feature/auth-google-oauth`, `fix/event-race-condition`, `chore/update-dependencies`

**Commit message convention (Conventional Commits):**
```
feat(events): add event cancellation with participant notifications
fix(auth): prevent login bypass on locked accounts
chore(deps): upgrade Spring Boot to 3.3.5
docs(api): add missing endpoint documentation
test(matching): add unit tests for matching algorithm
refactor(notifications): extract notification dispatch to service layer
```

**Pull request rules (GitHub branch protection on `main` and `develop`):**
- [ ] Require PR — no direct push to main/develop
- [ ] Require 1 reviewer approval (even if solo — review your own PR thoughtfully)
- [ ] Require all CI checks to pass (test + lint + build)
- [ ] Require branches to be up to date before merge
- [ ] Delete branch after merge

**PR template (`.github/pull_request_template.md`):**
```markdown
## What does this PR do?
<!-- One sentence summary -->

## Why?
<!-- Link to feature spec or describe the problem -->

## How was it tested?
- [ ] Unit tests added/updated
- [ ] Tested locally
- [ ] Tested on staging

## Checklist
- [ ] No hardcoded secrets
- [ ] No `console.log` or debug code left
- [ ] Database migration included (if schema change)
- [ ] API docs updated (if endpoint change)
```

---

## 6. Scalability Patterns

### Database Query Rules

**Never do N+1 queries.** Use JPA `@EntityGraph` or `JOIN FETCH` for relationships:
```java
// Wrong — N+1: fetches event, then separate query per participant
event.getParticipants().forEach(p -> p.getUser().getDisplayName());

// Right — single JOIN query
@Query("SELECT e FROM Event e LEFT JOIN FETCH e.participants p LEFT JOIN FETCH p.user WHERE e.id = :id")
Optional<Event> findByIdWithParticipants(@Param("id") UUID id);
```

**Pagination everywhere.** No endpoint returns unbounded results. Every list endpoint has `limit` with a maximum of 100.

**Indexes on all foreign keys and query predicates.** Every `WHERE` and `ORDER BY` column should have an index (already documented in TECH_STACK.md, verify in migrations).

**Soft deletes use partial indexes:**
```sql
-- Only index non-deleted rows for better performance
CREATE INDEX idx_posts_active ON posts(author_id, created_at DESC)
  WHERE deleted_at IS NULL;
```

### Caching Strategy

**L1: Application cache** — Spring `@Cacheable` with Redis for frequently-read, rarely-changing data:

| Data | TTL | Invalidation |
|------|-----|-------------|
| Game details (from BGG) | 7 days | On manual refresh |
| BGG search results | 1 hour | On cache expiry only |
| User profile | 10 min | On `PUT /users/me` |
| Notification unread count | 5 min | On new notification + read-all |
| AI rule answers | 7 days | On new rulebook ingestion |
| Event details | 5 min | On event update/join/leave |

**Cache key naming convention:** `{entity}:{id}:{variant}`
```
game:550e8400:detail
user:a3f8d001:profile
bgg:search:catan:page1
```

**Cache-aside pattern:**
```java
// Read: cache-aside
@Cacheable(value = "game-detail", key = "#gameId")
public GameDto getGame(UUID gameId) {
  return gameRepository.findById(gameId)
    .map(gameMapper::toDto)
    .orElseThrow(() -> new NotFoundException("GAME_NOT_FOUND"));
}

// Write: invalidate on update
@CacheEvict(value = "game-detail", key = "#gameId")
public void updateGame(UUID gameId, UpdateGameRequest req) { ... }
```

### Async Processing

**Use `@Async` for non-blocking operations:**
```java
@Configuration
@EnableAsync
public class AsyncConfig {
  @Bean("notificationExecutor")
  public Executor notificationExecutor() {
    ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
    executor.setCorePoolSize(4);
    executor.setMaxPoolSize(8);
    executor.setQueueCapacity(500);
    executor.setThreadNamePrefix("notify-");
    executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
    executor.initialize();
    return executor;
  }

  @Bean("aiExecutor")
  public Executor aiExecutor() {
    ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
    executor.setCorePoolSize(2);
    executor.setMaxPoolSize(4);
    executor.setQueueCapacity(50);
    executor.setThreadNamePrefix("ai-");
    executor.initialize();
    return executor;
  }
}
```

Apply to:
- Email sending: `@Async("notificationExecutor")`
- FCM push: `@Async("notificationExecutor")`
- WebSocket delivery: `@Async("notificationExecutor")`
- AI rulebook ingestion: `@Async("aiExecutor")`
- BGG collection import: `@Async("notificationExecutor")`

### Stateless API Design

- **No server-side sessions.** All state in JWT + DB.
- **No file storage on the server.** All uploads go direct to R2 via presigned URLs.
- **Idempotent write operations** where possible (like/unlike, follow/unfollow).
- **Horizontal scaling ready** from Day 1 (even if running 1 instance).

---

## 7. Internationalisation (i18n)

### Supported Languages: English (en) + Chinese Simplified (zh-CN)

**Why Simplified Chinese:** Malaysia's Chinese community predominantly uses Simplified Chinese (zh-CN).

### SvelteKit Setup

```bash
npm install @inlang/paraglide-js-adapter-sveltekit
```

Paraglide-JS compiles translations at build time — zero runtime overhead.

```
src/
└── lib/
    └── i18n/
        ├── messages/
        │   ├── en.json      # English strings (source of truth)
        │   └── zh-CN.json   # Chinese translations
        └── index.ts         # re-exports paraglide functions
```

```json
// en.json
{
  "nav.home": "Home",
  "nav.library": "Library",
  "nav.events": "Events",
  "nav.profile": "Profile",
  "home.greeting": "Good {timeOfDay}, {name}!",
  "home.nextSession": "Your next session is in {days} days.",
  "event.join": "Join Event",
  "event.full": "Event is Full",
  "auth.login": "Log In",
  "auth.register": "Create Account"
}
```

```json
// zh-CN.json
{
  "nav.home": "主页",
  "nav.library": "游戏库",
  "nav.events": "活动",
  "nav.profile": "个人资料",
  "home.greeting": "{name}，{timeOfDay}好！",
  "home.nextSession": "您的下一场游戏在 {days} 天后。",
  "event.join": "加入活动",
  "event.full": "活动已满",
  "auth.login": "登录",
  "auth.register": "创建账户"
}
```

**Usage in Svelte components:**
```svelte
<script>
  import { m } from '$lib/i18n';
</script>

<h1>{m['home.greeting']({ timeOfDay: 'evening', name: user.displayName })}</h1>
<button>{m['event.join']()}</button>
```

**Language detection and switching:**
- Detect from browser `navigator.language` on first visit
- Store preference in `users.preferred_language` (add column: `VARCHAR(10) DEFAULT 'en'`)
- Language switcher in Settings: "English / 中文"

### Flutter (Phase 3)

```yaml
# pubspec.yaml
flutter_localizations:
  sdk: flutter
intl: ^0.19.x
```

```dart
// l10n/app_en.arb
{
  "navHome": "Home",
  "navLibrary": "Library",
  "homeGreeting": "Good {timeOfDay}, {name}!",
  "@homeGreeting": {
    "placeholders": {
      "timeOfDay": { "type": "String" },
      "name": { "type": "String" }
    }
  }
}

// l10n/app_zh.arb
{
  "navHome": "主页",
  "navLibrary": "游戏库",
  "homeGreeting": "{name}，{timeOfDay}好！"
}
```

### Backend i18n

API error messages are in English only (client translates using error `code`). This means the frontend maps error codes to localised strings, not the backend:

```typescript
// src/lib/i18n/errors.ts
const errorMessages = {
  en: {
    EVENT_FULL: "This event is already full.",
    INVALID_CREDENTIALS: "Incorrect email or password.",
  },
  'zh-CN': {
    EVENT_FULL: "该活动已满。",
    INVALID_CREDENTIALS: "邮箱或密码不正确。",
  }
};
```

User-generated content (post captions, event titles, etc.) is stored as-is — no translation needed.

---

## 8. Google OAuth Integration

### Flow

```
[Web/Flutter] → Google Sign-In → Get idToken
→ POST /api/v1/auth/google { idToken }
→ Spring Boot verifies idToken with Google
→ Extract: email, googleId, name, avatarUrl
→ Upsert user (create if new, link if email exists)
→ Return { accessToken, refreshToken, user, isNewUser }
→ If isNewUser: redirect to onboarding
```

### Backend

```kotlin
implementation("com.google.auth:google-auth-library-oauth2-http:1.x")
```

```java
@Service
public class GoogleAuthService {
  private static final String GOOGLE_CLIENT_ID = System.getenv("GOOGLE_CLIENT_ID");

  public GoogleUserInfo verifyIdToken(String idToken) throws GeneralSecurityException, IOException {
    GoogleIdTokenVerifier verifier = new GoogleIdTokenVerifier.Builder(
      new NetHttpTransport(), GsonFactory.getDefaultInstance())
      .setAudience(Collections.singletonList(GOOGLE_CLIENT_ID))
      .build();

    GoogleIdToken token = verifier.verify(idToken);
    if (token == null) throw new UnauthorizedException("INVALID_TOKEN", "Invalid Google token");

    Payload payload = token.getPayload();
    return new GoogleUserInfo(
      payload.getSubject(),         // googleId
      payload.getEmail(),           // email
      (String) payload.get("name"), // displayName
      (String) payload.get("picture") // avatarUrl
    );
  }
}

// In AuthService.googleLogin():
GoogleUserInfo googleUser = googleAuthService.verifyIdToken(idToken);

// Find by googleId or email
User user = userRepo.findByGoogleId(googleUser.googleId())
  .or(() -> userRepo.findByEmail(googleUser.email()))
  .map(existing -> {
    if (existing.getGoogleId() == null) {
      existing.setGoogleId(googleUser.googleId()); // link Google to existing account
    }
    return userRepo.save(existing);
  })
  .orElseGet(() -> {
    // Create new user
    User newUser = new User();
    newUser.setGoogleId(googleUser.googleId());
    newUser.setEmail(googleUser.email());
    newUser.setDisplayName(googleUser.displayName());
    newUser.setAvatarUrl(googleUser.avatarUrl());
    newUser.setUsername(generateUniqueUsername(googleUser.displayName()));
    newUser.setEmailVerified(true);  // Google already verified the email
    newUser.setOnboardingCompleted(false);
    return userRepo.save(newUser);
  });

boolean isNewUser = user.getCreatedAt().isAfter(Instant.now().minusSeconds(5));
return buildAuthResponse(user, isNewUser);
```

**Schema additions:**
```sql
ALTER TABLE users ADD COLUMN google_id VARCHAR(255) UNIQUE;
ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;  -- null for Google-only users
ALTER TABLE users ADD COLUMN preferred_language VARCHAR(10) DEFAULT 'en';
```

**Username auto-generation for Google users:**
```java
String generateUniqueUsername(String displayName) {
  String base = displayName.toLowerCase()
    .replaceAll("[^a-z0-9]", "")  // keep only alphanumeric
    .substring(0, Math.min(20, displayName.length()));
  if (base.length() < 3) base = "user";

  String candidate = base;
  int suffix = 1;
  while (userRepo.existsByUsername(candidate)) {
    candidate = base + suffix++;
  }
  return candidate;
}
```

### SvelteKit (Web)

```bash
npm install @auth/sveltekit @auth/core
```

```typescript
// src/auth.ts
import { SvelteKitAuth } from "@auth/sveltekit";
import Google from "@auth/core/providers/google";

export const { handle, signIn, signOut } = SvelteKitAuth({
  providers: [
    Google({
      clientId: process.env.GOOGLE_CLIENT_ID,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    })
  ],
  callbacks: {
    async jwt({ token, account }) {
      if (account?.provider === 'google' && account.id_token) {
        // Exchange Google idToken for our own JWT
        const res = await fetch(`${API_URL}/api/v1/auth/google`, {
          method: 'POST',
          body: JSON.stringify({ idToken: account.id_token }),
          headers: { 'Content-Type': 'application/json' }
        });
        const data = await res.json();
        token.accessToken = data.accessToken;
        token.refreshToken = data.refreshToken;
        token.user = data.user;
        token.isNewUser = data.isNewUser;
      }
      return token;
    }
  }
});
```

**New environment variables:**
```
GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=xxx     # backend only, never exposed to frontend
```

### Flutter (Phase 3)

```yaml
google_sign_in: ^6.x
```

```dart
Future<void> signInWithGoogle() async {
  final GoogleSignIn googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  final GoogleSignInAccount? account = await googleSignIn.signIn();
  if (account == null) return;  // User cancelled

  final GoogleSignInAuthentication auth = await account.authentication;
  final String? idToken = auth.idToken;
  if (idToken == null) throw Exception('No ID token');

  // Exchange for our app's JWT
  final response = await _authRepo.googleLogin(idToken);
  // Handle same as regular login
}
```

---

## 9. Friend System (Facebook Model — Confirmed)

### Decision: Explicit friend request + accept

- Send a friend request → other person must **accept** → you become friends
- No asymmetric follow — it is either friends or nothing
- Friends-only features: see each other's posts in feed, invite to events, match together, tag in posts

### Schema (replaces `follows` table)

```sql
friend_requests
  id UUID PK
  sender_id UUID FK(users.id)
  receiver_id UUID FK(users.id)
  status VARCHAR(20) DEFAULT 'pending'  -- 'pending' | 'accepted' | 'declined'
  created_at TIMESTAMP
  updated_at TIMESTAMP
  UNIQUE(sender_id, receiver_id)
  CHECK (sender_id != receiver_id)

CREATE INDEX idx_fr_receiver_pending ON friend_requests(receiver_id, status)
  WHERE status = 'pending';
CREATE INDEX idx_fr_accepted ON friend_requests(sender_id, receiver_id)
  WHERE status = 'accepted';
```

**Is-friends check:**
```sql
SELECT EXISTS(
  SELECT 1 FROM friend_requests
  WHERE status = 'accepted'
    AND ((sender_id = $a AND receiver_id = $b)
      OR (sender_id = $b AND receiver_id = $a))
) AS are_friends;
```

**UI language:** Profile shows **"Friends"** count (not followers/following). Button states: "Add Friend" → "Pending" → "Friends".

---

## 10. Event Visibility: Three Levels

### Schema Addition

```sql
ALTER TABLE events ADD COLUMN visibility VARCHAR(20) DEFAULT 'invite_only'
  CHECK (visibility IN ('invite_only', 'friends', 'public'));
```

| Visibility | Who can see it | Who can join |
|-----------|---------------|-------------|
| `invite_only` | Only explicitly invited users | Invited users only |
| `friends` | All mutual follows of the host | Invited users only (host must still invite) |
| `public` | Everyone | Anyone (up to max_participants) |

### Feed Changes

**Events screen adds a "Community" tab** (for public events):
```
GET /api/v1/events/community?gameId=&page=1&limit=20
```
- Returns `visibility = 'public'` events, sorted by `scheduled_at ASC` (soonest first)
- Filterable by game
- Phase 2: filter by city/region

**Friends tab** (default):
```
GET /api/v1/events?visibility=friends&page=1
```
- Returns: events you're invited to + events hosted by mutual follows with `visibility != 'invite_only'`

### Location Privacy for Public Events

- For `invite_only` and `friends` events: show full location
- For `public` events: show **area/venue name only** in the list (e.g., "Petaling Jaya, Selangor")
- Show **full location only after user joins** the event
- Add: `events.location_display VARCHAR(100)` — a sanitised display name for public listings

---

## 11. AI: Conversation Mode

### Implementation

Keep last 3 Q&A pairs in **client state** (not DB). Include them in each prompt:

**Frontend state:**
```typescript
// src/lib/stores/aiChat.ts
interface ChatMessage { role: 'user' | 'assistant'; content: string; }
interface ChatState {
  gameId: string;
  messages: ChatMessage[];  // keep last 6 (3 pairs)
}
```

**API request:**
```json
POST /api/v1/ai/rules
{
  "gameId": "uuid",
  "question": "What about the bird feeder specifically?",
  "conversationHistory": [
    { "role": "user", "content": "How do you win?" },
    { "role": "assistant", "content": "You win by having the most points..." }
  ]
}
```

**Prompt construction:**
```java
// Build messages array for OpenAI chat completions
List<Map<String, String>> messages = new ArrayList<>();
messages.add(Map.of("role", "system", "content", systemPrompt));

// Add conversation history (max last 3 exchanges = 6 messages)
for (ConversationMessage msg : conversationHistory) {
  messages.add(Map.of("role", msg.role(), "content", msg.content()));
}

// Add current question
messages.add(Map.of("role", "user", "content",
  "Rulebook context:\n\n" + retrievedChunks + "\n\nQuestion: " + question));
```

**Cache key changes:** Include a hash of the conversation for cached answers in the same context. Conversation mode reduces cache hit rate slightly — acceptable trade-off for much better UX.

**Token budget:**
- System prompt: ~200 tokens
- 3 Q&A history: ~400 tokens
- 5 rulebook chunks: ~600 tokens
- Question: ~100 tokens
- Total input: ~1,300 tokens ≈ ~RM0.001 per query (still very cheap with gpt-4o-mini)

---

## 12. Production Readiness Checklist

Before going live with real users:

**Security:**
- [ ] All endpoints require auth except: health, auth/*, public events
- [ ] CORS restricted to known origins only
- [ ] Rate limiting active on all endpoints
- [ ] Input validation on all request bodies (`@Valid`)
- [ ] SQL injection impossible (JPA parameterized queries only)
- [ ] JWT secret is 256-bit random, rotated after any suspected breach
- [ ] No secrets in git history (`git log --all -S "password"`)
- [ ] R2 bucket is private; all URLs are CDN-served (no direct R2 URLs exposed)
- [ ] HTTPS enforced end-to-end

**Reliability:**
- [ ] Circuit breakers configured for BGG, OpenAI, FCM
- [ ] Database connection pool sized correctly for Railway instance RAM
- [ ] Background jobs use distributed locks
- [ ] Graceful shutdown configured: `server.shutdown=graceful` + `spring.lifecycle.timeout-per-shutdown-phase=30s`
- [ ] Health check returns 200 at `/actuator/health`

**Observability:**
- [ ] Sentry capturing errors in both backend and frontend
- [ ] Grafana dashboards showing p95 latency + error rate
- [ ] Uptime monitor alerting on downtime
- [ ] Structured JSON logs in production

**Data:**
- [ ] Neon PITR enabled (verify in Neon dashboard)
- [ ] Daily pg_dump GitHub Action running and verified
- [ ] `migrations/` folder has all schema changes in versioned files (V1, V2, ...)
- [ ] No `spring.jpa.hibernate.ddl-auto=create` in production (use `validate`)

**Performance:**
- [ ] All foreign key columns have indexes
- [ ] No N+1 queries (verified with Hibernate SQL logging in staging)
- [ ] Feed endpoint responds < 200ms at p95 (verified with k6 load test)
- [ ] Redis caching working (verify cache hit rate in Grafana)
