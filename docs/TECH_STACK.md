# Meeple & Hearth — Tech Stack

## Overview

```
[SvelteKit Web App]  ←→  [Spring Boot API]  ←→  [Neon PostgreSQL]
                                  ↕
                    [Cloudflare R2] [Upstash Redis]
                    [OpenAI API]    [Firebase FCM]
```

| Layer | Technology | Provider | Cost |
|-------|-----------|----------|------|
| Frontend | SvelteKit + Tailwind CSS | Cloudflare Pages | Free |
| Mobile (later) | Flutter | App Stores | Free |
| Backend | Spring Boot (Java 21) | Railway | ~RM20–80/mo |
| Database | PostgreSQL | Neon (serverless) | Free tier |
| Cache | Redis | Upstash | Free–RM20/mo |
| Storage | R2 (S3-compatible) | Cloudflare | ~RM5–15/mo |
| Realtime | WebSocket (STOMP) | Spring Boot (bundled) | — |
| Push | Firebase Cloud Messaging | Google Firebase | Free |
| AI | GPT-4o-mini + Embeddings | OpenAI | ~RM0–50/mo |
| External Game Data | BGG API / RAWG-equivalent | Board Game Geek | Free |

---

## 1. Frontend — SvelteKit

### Why SvelteKit
- Zero runtime overhead — compiles to vanilla JS
- Built-in routing, SSR, SSG, form actions
- Tailwind CSS integrates naturally
- Smaller bundle vs. React/Next.js
- Fast development iteration

### Project Structure
```
src/
├── lib/
│   ├── components/         # Reusable UI components
│   │   ├── ui/             # Primitives (Button, Card, Avatar, Chip)
│   │   ├── layout/         # AppBar, BottomNav, FAB, PageShell
│   │   ├── game/           # GameCard, GameDetailHero, GameInfoBar
│   │   ├── event/          # EventCard, EventDetail, CreateEventForm
│   │   ├── post/           # PostCard, CreatePostForm, FeedItem
│   │   ├── notification/   # NotificationItem, NotificationBell
│   │   └── match/          # MatchSuggestionCard
│   ├── stores/             # Svelte stores (auth, notifications, websocket)
│   ├── api/                # API client functions (fetch wrappers)
│   ├── utils/              # Date formatting, image helpers, etc.
│   └── types/              # TypeScript interfaces/types
├── routes/
│   ├── +layout.svelte      # Root layout (AppBar + BottomNav)
│   ├── +page.svelte        # Home feed
│   ├── library/
│   │   ├── +page.svelte    # Library (tabs: All / Collection / Wishlist / Favorites)
│   │   └── [gameId]/
│   │       └── +page.svelte # Game Detail
│   ├── events/
│   │   ├── +page.svelte    # Events list + calendar
│   │   ├── create/
│   │   │   └── +page.svelte # Create Event form
│   │   └── [eventId]/
│   │       └── +page.svelte # Event Detail
│   ├── posts/
│   │   ├── create/
│   │   │   └── +page.svelte # Create Post form
│   │   └── [postId]/
│   │       └── +page.svelte # Post Detail
│   ├── profile/
│   │   ├── +page.svelte    # Own profile
│   │   └── [userId]/
│   │       └── +page.svelte # Other user profile
│   ├── notifications/
│   │   └── +page.svelte    # Notifications list
│   ├── matching/
│   │   └── +page.svelte    # Matching UI
│   └── auth/
│       ├── login/
│       │   └── +page.svelte
│       └── register/
│           └── +page.svelte
└── app.html                # HTML shell
```

### Tailwind Configuration
```js
// tailwind.config.js
export default {
  darkMode: "class",
  content: ["./src/**/*.{html,js,svelte,ts}"],
  theme: {
    extend: {
      colors: {
        "primary": "#895100",
        "primary-container": "#FF9F1C",
        "primary-fixed": "#FFDCBC",
        "primary-fixed-dim": "#FFB86B",
        "on-primary": "#FFFFFF",
        "on-primary-container": "#683C00",
        "on-primary-fixed": "#2C1700",
        "on-primary-fixed-variant": "#683D00",
        "secondary": "#835401",
        "secondary-container": "#FDBD68",
        "secondary-fixed": "#FFDDB5",
        "secondary-fixed-dim": "#FABB65",
        "on-secondary": "#FFFFFF",
        "on-secondary-container": "#764B00",
        "on-secondary-fixed": "#2A1800",
        "on-secondary-fixed-variant": "#643F00",
        "tertiary": "#006A62",
        "tertiary-container": "#36C9BB",
        "tertiary-fixed": "#70F8E8",
        "tertiary-fixed-dim": "#4FDBCC",
        "on-tertiary": "#FFFFFF",
        "on-tertiary-container": "#005049",
        "on-tertiary-fixed": "#00201D",
        "on-tertiary-fixed-variant": "#005049",
        "background": "#F8F9FA",
        "surface": "#F8F9FA",
        "surface-bright": "#F8F9FA",
        "surface-dim": "#D9DADB",
        "surface-container-lowest": "#FFFFFF",
        "surface-container-low": "#F3F4F5",
        "surface-container": "#EDEEEF",
        "surface-container-high": "#E7E8E9",
        "surface-container-highest": "#E1E3E4",
        "surface-tint": "#895100",
        "surface-variant": "#E1E3E4",
        "on-background": "#191C1D",
        "on-surface": "#191C1D",
        "on-surface-variant": "#544434",
        "inverse-surface": "#2E3132",
        "inverse-on-surface": "#F0F1F2",
        "inverse-primary": "#FFB86B",
        "outline": "#877462",
        "outline-variant": "#DAC2AE",
        "error": "#BA1A1A",
        "error-container": "#FFDAD6",
        "on-error": "#FFFFFF",
        "on-error-container": "#93000A",
      },
      fontFamily: {
        "headline": ["Plus Jakarta Sans", "sans-serif"],
        "body": ["Plus Jakarta Sans", "sans-serif"],
        "label": ["Manrope", "sans-serif"],
      },
      borderRadius: {
        "DEFAULT": "1rem",
        "lg": "2rem",
        "xl": "3rem",
        "full": "9999px",
      },
    },
  },
  plugins: [],
}
```

### Key Dependencies
```json
{
  "devDependencies": {
    "@sveltejs/kit": "^2.x",
    "@sveltejs/adapter-cloudflare": "^4.x",
    "svelte": "^5.x",
    "tailwindcss": "^3.x",
    "autoprefixer": "^10.x",
    "postcss": "^8.x",
    "typescript": "^5.x",
    "vite": "^5.x",
    "vitest": "^1.x",
    "@playwright/test": "^1.x"
  },
  "dependencies": {
    "svelte-sonner": "^0.x"
  }
}
```

### Auth Strategy (Frontend)
- JWT stored in `httpOnly` cookie (set by Spring Boot on login response)
- SvelteKit `+layout.server.ts` reads cookie and provides `user` to all routes
- Unauthenticated routes: `/auth/login`, `/auth/register`
- Redirect unauthenticated users to `/auth/login` in `+layout.server.ts`

### API Client
```ts
// src/lib/api/client.ts
const BASE_URL = import.meta.env.VITE_API_URL;

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE_URL}${path}`, {
    credentials: "include",   // sends cookie automatically
    headers: { "Content-Type": "application/json", ...options?.headers },
    ...options,
  });
  if (!res.ok) {
    const err = await res.json();
    throw new Error(err.error ?? "Request failed");
  }
  return res.json();
}

export const api = {
  get: <T>(path: string) => request<T>(path),
  post: <T>(path: string, body: unknown) =>
    request<T>(path, { method: "POST", body: JSON.stringify(body) }),
  put: <T>(path: string, body: unknown) =>
    request<T>(path, { method: "PUT", body: JSON.stringify(body) }),
  delete: <T>(path: string) => request<T>(path, { method: "DELETE" }),
};
```

### WebSocket Client
```ts
// src/lib/stores/websocket.ts
import { writable } from "svelte/store";

export const notifications = writable([]);

let socket: WebSocket;

export function connectWS(token: string) {
  socket = new WebSocket(`${import.meta.env.VITE_WS_URL}?token=${token}`);
  socket.onmessage = (event) => {
    const data = JSON.parse(event.data);
    notifications.update(n => [data, ...n]);
  };
}
```

### Environment Variables
```
VITE_API_URL=https://api.meeple-hearth.com
VITE_WS_URL=wss://api.meeple-hearth.com/ws
VITE_R2_PUBLIC_URL=https://cdn.meeple-hearth.com
```

### Deployment
- Platform: **Cloudflare Pages**
- Adapter: `@sveltejs/adapter-cloudflare`
- Build command: `npm run build`
- Output directory: `.svelte-kit/cloudflare`
- Auto-deploy: GitHub Actions → Cloudflare Pages on push to `main`

---

## 2. Backend — Spring Boot

### Why Spring Boot
- Mature, battle-tested Java framework
- Excellent WebSocket (STOMP) support built-in
- Spring Security for JWT auth
- Spring Data JPA for clean DB access
- Railway supports JAR deployment directly

### Tech Versions
- Java: **21** (LTS, virtual threads via Project Loom)
- Spring Boot: **3.3.x**
- Build tool: **Gradle** (Kotlin DSL)
- DB access: **Spring Data JPA** + Hibernate

### Project Structure
```
src/main/java/com/meeplehearth/
├── config/
│   ├── SecurityConfig.java          # JWT filter, CORS, auth rules
│   ├── WebSocketConfig.java         # STOMP WebSocket setup
│   ├── R2Config.java                # Cloudflare R2 S3 client config
│   └── RedisConfig.java             # Upstash Redis connection
├── auth/
│   ├── AuthController.java          # /api/auth/*
│   ├── AuthService.java
│   ├── JwtUtil.java                 # Token generation/validation
│   └── dto/                         # LoginRequest, RegisterRequest, TokenResponse
├── user/
│   ├── UserController.java          # /api/users/*
│   ├── UserService.java
│   ├── UserRepository.java
│   ├── User.java                    # Entity
│   └── dto/
├── game/
│   ├── GameController.java          # /api/games/*
│   ├── GameService.java
│   ├── GameRepository.java
│   ├── UserGameRepository.java
│   ├── BggApiClient.java            # HTTP client for BGG XML API
│   ├── Game.java
│   ├── UserGame.java
│   └── dto/
├── event/
│   ├── EventController.java
│   ├── EventService.java
│   ├── EventRepository.java
│   ├── EventParticipantRepository.java
│   ├── Event.java
│   ├── EventParticipant.java
│   └── dto/
├── post/
│   ├── PostController.java
│   ├── PostService.java
│   ├── PostRepository.java
│   ├── Post.java
│   ├── PostImage.java
│   ├── PostTag.java
│   └── dto/
├── match/
│   ├── MatchController.java
│   ├── MatchService.java             # Matching algorithm
│   ├── MatchScheduler.java           # @Scheduled job to run matching
│   ├── MatchRequestRepository.java
│   ├── MatchRequest.java
│   └── dto/
├── notification/
│   ├── NotificationController.java
│   ├── NotificationService.java      # Orchestrates DB + WS + FCM
│   ├── WebSocketNotificationService.java
│   ├── FcmService.java               # Firebase push
│   ├── NotificationRepository.java
│   ├── Notification.java
│   └── dto/
├── ai/
│   ├── AiController.java             # /api/ai/rules
│   ├── AiService.java                # RAG pipeline
│   ├── EmbeddingService.java         # OpenAI Embeddings
│   ├── RuleChunkRepository.java      # pgvector queries
│   └── dto/
├── storage/
│   └── StorageController.java        # /api/upload/presign
└── MeepleHearthApplication.java
```

### Key Dependencies (build.gradle.kts)
```kotlin
dependencies {
  implementation("org.springframework.boot:spring-boot-starter-web")
  implementation("org.springframework.boot:spring-boot-starter-security")
  implementation("org.springframework.boot:spring-boot-starter-data-jpa")
  implementation("org.springframework.boot:spring-boot-starter-websocket")
  implementation("org.springframework.boot:spring-boot-starter-data-redis")
  implementation("org.springframework.boot:spring-boot-starter-validation")
  implementation("org.springframework.boot:spring-boot-starter-actuator")

  // JWT
  implementation("io.jsonwebtoken:jjwt-api:0.12.x")
  runtimeOnly("io.jsonwebtoken:jjwt-impl:0.12.x")
  runtimeOnly("io.jsonwebtoken:jjwt-jackson:0.12.x")

  // PostgreSQL
  runtimeOnly("org.postgresql:postgresql")

  // AWS SDK (for R2 — S3-compatible)
  implementation("software.amazon.awssdk:s3:2.x")

  // Firebase Admin (FCM)
  implementation("com.google.firebase:firebase-admin:9.x")

  // HTTP client (for BGG API + OpenAI)
  implementation("org.springframework.boot:spring-boot-starter-webflux")  // WebClient

  // OpenAPI docs
  implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:2.x")

  testImplementation("org.springframework.boot:spring-boot-starter-test")
  testImplementation("org.springframework.security:spring-security-test")
}
```

### JWT Authentication
```
Flow:
1. POST /api/auth/login → validate credentials → return { accessToken, refreshToken }
2. Client stores tokens in httpOnly cookies
3. Every request: JwtAuthFilter reads cookie → validates → sets SecurityContext
4. POST /api/auth/refresh → validate refreshToken → return new accessToken
```

**Token lifetime:**
- Access token: 15 minutes
- Refresh token: 30 days

### CORS Configuration
```java
// Allow SvelteKit frontend origin
.allowedOrigins("https://meeple-hearth.com", "http://localhost:5173")
.allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
.allowCredentials(true)  // required for cookie-based auth
```

### WebSocket (STOMP)
```java
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {
  @Override
  public void configureMessageBroker(MessageBrokerRegistry registry) {
    registry.enableSimpleBroker("/topic", "/user");
    registry.setApplicationDestinationPrefixes("/app");
    registry.setUserDestinationPrefix("/user");
  }

  @Override
  public void registerStompEndpoints(StompEndpointRegistry registry) {
    registry.addEndpoint("/ws")
      .setAllowedOriginPatterns("*")
      .withSockJS();
  }
}
```

**Channels:**
- `/user/queue/notifications` — personal notifications for a specific user
- `/topic/events/{eventId}` — broadcast updates for an event (participant changes)

### Standard API Response Shape
```json
// Success
{ "data": { ... } }

// Error
{ "error": "Human-readable message", "code": "SNAKE_CASE_CODE" }

// List with pagination
{
  "data": [ ... ],
  "meta": { "page": 1, "limit": 20, "total": 150, "hasMore": true }
}
```

### Environment Variables
```properties
# application.properties (use Railway env vars)
DB_URL=jdbc:postgresql://...neon.tech/meeple?sslmode=require
DB_USERNAME=...
DB_PASSWORD=...

JWT_SECRET=<256-bit-secret>
JWT_EXPIRY_MS=900000

REDIS_URL=rediss://...upstash.io:6379
REDIS_PASSWORD=...

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
```

### Deployment (Railway)
- Connect GitHub repo → Railway auto-deploys on push to `main`
- Build: `./gradlew bootJar`
- Start: `java -jar build/libs/meeple-hearth.jar`
- Health check: `GET /actuator/health`
- Set all env vars in Railway dashboard
- Enable persistent storage not needed (all files on R2)

---

## 3. Database — Neon PostgreSQL

### Why Neon
- Serverless PostgreSQL — auto-suspends when idle (free tier)
- Branching: create DB branches for dev/staging like Git branches
- Compatible with all standard Postgres tooling
- pgvector extension available (needed for AI embeddings)

### Connection
```properties
spring.datasource.url=jdbc:postgresql://ep-xxx.us-east-1.aws.neon.tech/meeple?sslmode=require
spring.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect
spring.jpa.hibernate.ddl-auto=validate  # use migrations, not auto-create
```

### Extensions to Enable
```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";    -- UUID generation
CREATE EXTENSION IF NOT EXISTS "vector";        -- pgvector for AI embeddings
```

### Migrations (Flyway)
```
src/main/resources/db/migration/
├── V1__create_users_follows.sql
├── V2__create_games_user_games.sql
├── V3__create_events.sql
├── V4__create_posts.sql
├── V5__create_notifications.sql
├── V6__create_match_requests.sql
└── V7__create_ai_tables.sql
```

**Flyway config:**
```properties
spring.flyway.enabled=true
spring.flyway.locations=classpath:db/migration
```

### pgvector (for AI)
```sql
-- The embedding column type
embedding VECTOR(1536)

-- Create index for similarity search
CREATE INDEX ON game_rule_chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Query: find top-5 most similar chunks
SELECT content, 1 - (embedding <=> $1::vector) AS similarity
FROM game_rule_chunks
WHERE game_id = $2
ORDER BY embedding <=> $1::vector
LIMIT 5;
```

### Indexing Strategy
```sql
-- Users
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);

-- Social
CREATE INDEX idx_follows_following ON follows(following_id);

-- Games
CREATE INDEX idx_user_games_user ON user_games(user_id, status);
CREATE INDEX idx_user_games_game ON user_games(game_id);

-- Events
CREATE INDEX idx_events_host ON events(host_id);
CREATE INDEX idx_events_scheduled ON events(scheduled_at);
CREATE INDEX idx_event_participants_user ON event_participants(user_id);

-- Posts
CREATE INDEX idx_posts_author ON posts(author_id);
CREATE INDEX idx_posts_game ON posts(game_id);
CREATE INDEX idx_post_tags_user ON post_tags(tagged_user_id);

-- Notifications
CREATE INDEX idx_notifications_recipient ON notifications(recipient_id, is_read, created_at DESC);

-- Matching
CREATE INDEX idx_match_requests_status ON match_requests(user_id, status);
CREATE INDEX idx_match_requests_game ON match_requests(game_id, status);
```

---

## 4. Cache — Upstash Redis

### Why Upstash
- Serverless Redis — pay per request, not per hour
- Free tier: 10,000 commands/day
- REST API option (useful for edge environments)
- Easy connection via standard Redis client

### What to Cache
| Key Pattern | TTL | Content |
|-------------|-----|---------|
| `game:{bggId}` | 24h | BGG API game data (avoid rate limits) |
| `feed:{userId}:page:{n}` | 5min | Paginated social feed |
| `ai:cache:{gameId}:{questionHash}` | 7d | AI rule answers (expensive) |
| `ws:online:{userId}` | 30s | Whether user has active WebSocket |
| `user:collection:{userId}` | 10min | User's game collection list |

### Spring Boot Integration
```properties
spring.data.redis.url=rediss://default:<password>@<host>.upstash.io:6379
spring.cache.type=redis
spring.cache.redis.time-to-live=600000  # 10 min default
```

```java
@Cacheable(value = "games", key = "#bggId")
public GameDto getGameFromBgg(int bggId) { ... }

@CacheEvict(value = "games", key = "#bggId")
public void invalidateGameCache(int bggId) { ... }
```

---

## 5. Storage — Cloudflare R2

### Why R2
- S3-compatible API (use AWS SDK)
- No egress fees (unlike AWS S3)
- Cheap storage
- Works with Cloudflare CDN automatically

### Upload Flow (Presigned URL)
```
1. Client requests presigned URL: POST /api/upload/presign { filename, contentType }
2. Spring Boot generates presigned URL via AWS SDK → returns { uploadUrl, fileUrl }
3. Client uploads file directly to R2 using the presigned URL (PUT request)
4. Client sends fileUrl in the post/event creation request
5. Spring Boot saves fileUrl to DB — never touches the file bytes
```

### Spring Boot Config
```java
@Bean
public S3Client r2Client() {
  return S3Client.builder()
    .endpointOverride(URI.create(r2Endpoint))
    .credentialsProvider(StaticCredentialsProvider.create(
      AwsBasicCredentials.create(accessKey, secretKey)))
    .region(Region.of("auto"))
    .build();
}
```

### Bucket Structure
```
meeple-hearth-media/
├── avatars/{userId}/{filename}
├── posts/{postId}/{filename}
└── games/{gameId}/cover.jpg     # cached game cover images (optional)
```

### Public Access
- R2 bucket connected to Cloudflare CDN
- Public URL: `https://cdn.meeple-hearth.com/{key}`
- Images served via CDN — no cost for bandwidth

---

## 6. Realtime — WebSocket (Spring Boot STOMP)

### Architecture
```
Client (SvelteKit)
  └─ STOMP over WebSocket → /ws endpoint
       └─ Spring Boot Message Broker
            ├─ /user/queue/notifications  (personal channel)
            └─ /topic/events/{id}         (room channel)
```

### Sending a Notification to a User
```java
// In NotificationService.java
messagingTemplate.convertAndSendToUser(
  userId.toString(),
  "/queue/notifications",
  notificationDto
);
```

### Client Subscription (SvelteKit)
```ts
// Using @stomp/stompjs
const client = new Client({
  brokerURL: `wss://api.meeple-hearth.com/ws`,
  connectHeaders: { Authorization: `Bearer ${token}` },
  onConnect: () => {
    client.subscribe(`/user/queue/notifications`, (msg) => {
      const notification = JSON.parse(msg.body);
      notifications.update(n => [notification, ...n]);
    });
  },
});
client.activate();
```

### Online Presence
- On WebSocket connect: set Redis key `ws:online:{userId}` with TTL 30s
- On heartbeat: refresh TTL
- On disconnect: delete key
- Before sending FCM push: check `ws:online:{userId}` — if exists, skip FCM

---

## 7. Push Notifications — Firebase Cloud Messaging (FCM)

### Why FCM
- Free, reliable push for Android and iOS
- Works with Flutter (mobile phase)
- Simple REST API

### Setup
1. Create Firebase project in Firebase Console
2. Download service account JSON → base64 encode → set as env var
3. Initialize Firebase Admin SDK in Spring Boot

### Send Push (Spring Boot)
```java
Message message = Message.builder()
  .setToken(userFcmToken)
  .setNotification(Notification.builder()
    .setTitle(notificationTitle)
    .setBody(notificationBody)
    .build())
  .putData("type", "event_invite")
  .putData("eventId", eventId.toString())
  .build();

FirebaseMessaging.getInstance().send(message);
```

### FCM Token Management
- Flutter app (Phase 3) registers FCM token on login → `PUT /api/me` with `{ fcmToken }`
- Web app (SvelteKit) can also register via Firebase JS SDK (optional)
- Spring Boot stores `fcm_token` on the `users` table

---

## 8. AI System — RAG Pipeline

### Why RAG (Retrieval-Augmented Generation)
- Board game rulebooks are long — too long to send in full to GPT
- RAG: split rulebook into chunks → embed → retrieve only relevant chunks → send to GPT
- Cheaper + faster + more accurate than sending full rulebook

### Full Pipeline

```
INGESTION (one-time per game):
  Rulebook PDF/text
    → Split into 500-token chunks with 50-token overlap
    → OpenAI Embeddings API (text-embedding-3-small)
    → Store (chunk_text, embedding VECTOR(1536)) in Neon pgvector table

QUERY (per user question):
  User question: "Can I place a worker during another player's turn?"
    → Embed question with text-embedding-3-small
    → pgvector similarity search: top-5 most relevant chunks
    → Build prompt:
        "Answer based ONLY on these rules:
         [chunk1] [chunk2] [chunk3] [chunk4] [chunk5]
         Question: [user question]"
    → Send to GPT-4o-mini
    → Cache answer in Redis (key: game:{id}:question:{hash})
    → Return answer to user
```

### Cost Optimization
- Use `gpt-4o-mini` (cheapest GPT-4-level model, ~RM0.10/1M input tokens)
- Use `text-embedding-3-small` (~RM0.008/1M tokens)
- Cache answers aggressively (7-day TTL in Redis)
- Rate limit: max 20 AI queries per user per day (tracked in Redis counter)
- Only store rulebook chunks when a user first requests AI for that game

### Spring Boot AiService
```java
public String askRules(UUID gameId, String question) {
  // 1. Check cache
  String cacheKey = "ai:" + gameId + ":" + DigestUtils.sha256Hex(question);
  String cached = redisTemplate.opsForValue().get(cacheKey);
  if (cached != null) return cached;

  // 2. Embed question
  float[] questionEmbedding = embeddingService.embed(question);

  // 3. Retrieve top-5 chunks via pgvector
  List<String> chunks = ruleChunkRepository.findSimilar(gameId, questionEmbedding, 5);

  // 4. Build prompt + call GPT
  String context = String.join("\n\n", chunks);
  String answer = openAiClient.chat(buildPrompt(context, question));

  // 5. Cache result
  redisTemplate.opsForValue().set(cacheKey, answer, 7, TimeUnit.DAYS);

  return answer;
}
```

---

## 9. External Game Data — BGG API

### BoardGameGeek XML API 2
- Base URL: `https://boardgamegeek.com/xmlapi2`
- No authentication required
- Rate limit: ~2 req/sec (be respectful)

### Key Endpoints
```
GET /search?query=catan&type=boardgame
GET /thing?id=13&stats=1                   # game details + ratings
GET /collection?username=xxx&own=1         # user's collection (public)
```

### Strategy
- Search results: proxy through Spring Boot (cache in Redis 24h)
- Game detail: fetch on first request → store in Neon `games` table → serve from DB
- Never make BGG API calls from the frontend directly

### BGG API Parsing (XML → Java)
```java
// Use Spring's WebClient + Jackson XML
WebClient bggClient = WebClient.builder()
  .baseUrl("https://boardgamegeek.com/xmlapi2")
  .build();

Mono<String> xml = bggClient.get()
  .uri("/thing?id={id}&stats=1", bggId)
  .retrieve()
  .bodyToMono(String.class);
// Then parse XML with JAXB or XStream
```

---

## 10. Development Environment Setup

### Prerequisites
- Java 21 (use SDKMAN: `sdk install java 21-tem`)
- Node.js 20+
- Docker (for local PostgreSQL/Redis, optional)

### Local Backend
```bash
# Clone + run
./gradlew bootRun

# Or with specific profile
SPRING_PROFILES_ACTIVE=local ./gradlew bootRun
```

**Local `application-local.properties`:**
```properties
# Use local PostgreSQL (or Neon dev branch)
DB_URL=jdbc:postgresql://localhost:5432/meeple_dev
DB_USERNAME=postgres
DB_PASSWORD=postgres

# Use local Redis (Docker)
REDIS_URL=redis://localhost:6379

# Use real Neon dev branch URL for convenience
# DB_URL=jdbc:postgresql://ep-xxx-branch.us-east-1.aws.neon.tech/meeple?sslmode=require
```

### Local Frontend
```bash
cd frontend/
npm install
npm run dev         # http://localhost:5173
```

**.env.local:**
```
VITE_API_URL=http://localhost:8080
VITE_WS_URL=ws://localhost:8080/ws
```

### Docker Compose (local dependencies)
```yaml
version: "3.9"
services:
  postgres:
    image: pgvector/pgvector:pg16
    environment:
      POSTGRES_DB: meeple_dev
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
```

---

## 11. Repository Structure (Monorepo)

```
boardgame/
├── docs/
│   ├── PLAN.md
│   ├── DESIGN.md
│   └── TECH_STACK.md
├── reference/                  # HTML/PNG mockups
│   └── stitch_boardgame_app/
├── backend/                    # Spring Boot project
│   ├── src/
│   ├── build.gradle.kts
│   └── Dockerfile
├── frontend/                   # SvelteKit project
│   ├── src/
│   ├── package.json
│   └── tailwind.config.js
├── mobile/                     # Flutter project (Phase 3)
│   └── lib/
├── docker-compose.yml          # Local dev dependencies
└── README.md
```

---

## 12. Cost Breakdown (Monthly)

| Service | Free Tier | Paid Estimate |
|---------|-----------|---------------|
| Cloudflare Pages (frontend) | Unlimited | Free |
| Railway (backend) | $5 credit/mo | ~RM20–80 depending on usage |
| Neon PostgreSQL | 0.5 GB storage, auto-suspend | Free for MVP |
| Upstash Redis | 10K commands/day | Free for MVP; ~RM10 if heavier |
| Cloudflare R2 | 10 GB/mo + 1M ops | ~RM5–15 |
| Firebase FCM | Unlimited | Free |
| OpenAI API | Pay-per-use | ~RM0–50 depending on AI usage |
| BGG API | Free | Free |
| **Total** | | **~RM30–150/mo** |

---

## 13. Security Checklist

- [ ] All secrets in environment variables — nothing hardcoded
- [ ] JWT `httpOnly` cookies — not `localStorage` (XSS protection)
- [ ] CORS restricted to known frontend origins
- [ ] SQL injection: impossible via JPA parameterized queries
- [ ] File upload: only presigned URLs, Spring Boot never handles file bytes
- [ ] Rate limiting: `/api/auth/login` max 10 req/min per IP (Spring Security or Bucket4j)
- [ ] AI queries: max 20/user/day (Redis counter)
- [ ] Input validation: `@Valid` on all request DTOs (Bean Validation)
- [ ] HTTPS enforced in production (Railway + Cloudflare)
- [ ] Neon `sslmode=require` in JDBC URL
- [ ] R2 bucket: private by default, only public via CDN URL
