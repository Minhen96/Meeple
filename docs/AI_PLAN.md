# Meeple — AI Features Plan

## Overview

Six AI-powered features built in dependency order.

| # | Feature | Status |
|---|---------|--------|
| 1 | Smart Search (fuzzy + language) | Planned |
| 2 | Recommended Sort | Planned |
| 3 | Rulebook Pipeline | Planned |
| 4 | How To Play Tab | Planned |
| 5 | AI Rules Assistant (RAG) | Planned |
| 6 | Admin Rulebook Review Page | Planned |

---

## Pre-build Verification Checklist

Run these probes **before writing any feature code**. If any fail, fix first.

| # | What to verify | Probe endpoint | Pass condition |
|---|----------------|---------------|----------------|
| 1 | OpenAI API key works | `GET /api/v1/admin/test/openai` | Returns embedding dims=1536, GPT reply non-empty |
| 2 | CDN PDF download | `GET /api/v1/admin/test/pdf-download` | Content-Type: application/pdf, size > 0 |
| 3 | pg_trgm on Neon | Run V23 migration | Migration applies without error |
| 4 | pgvector HNSW index | Run V26 migration | Migration applies without error |
| 5 | rule-book.org API | `GET /api/v1/admin/test/bgg-rulebook/13` | Already verified ✓ |

> Note: ivfflat requires existing vectors to train. Use **HNSW** index instead
> (`CREATE INDEX ... USING hnsw (embedding vector_cosine_ops)`) — works on empty
> tables and performs better on Neon.

---

## Feature 1 — Smart Search

### What it solves
- Typos: `cata`, `catna` → Catan
- Partial: `settlers` → The Settlers of Catan
- Chinese input: `卡坦岛` → Catan
- Aliases: stored in `games.alias_names JSONB`

### Data flow
```
Query input
  ↓
Contains CJK chars?
  YES → SearchTranslationService → OpenAI translate to English → translated query
  NO  → use original query
  ↓
GameRepository.searchTrigram(query)
  → pg_trgm similarity on name_en, name_zh, alias_names::text
  → ORDER BY similarity DESC, rank ASC
  → LIMIT 20
  ↓
Return results + { translatedFrom: "卡坦岛" } if translated
```

### New files
```
backend/
  game/repository/GameRepository.java         ← add nativeTrigram query
  ai/service/SearchTranslationService.java     ← CJK detect + OpenAI translate
  resources/db/migration/V23__add_pg_trgm.sql ← extension + GIN indexes
```

### Modified files
```
game/service/GameService.java                 ← search() uses translation + trigram
game/dto/GameSearchResult.java                ← add translatedFrom field
```

### Frontend change
```
library/+page.svelte                          ← show "Showing results for: Catan" hint
```

---

## Feature 2 — Recommended Sort

### What it solves
`GET /api/v1/games?sort=recommended` returns games ranked by personal taste + social signals instead of BGG rank.

### Scoring formula
```
mechanic overlap (favorites)   × 0.25   ← strongest taste signal
mechanic overlap (played)      × 0.20   ← revealed preference
category overlap               × 0.15
friend play count              × 0.15   ← social proof
friend own count               × 0.10
normalized BGG rating          × 0.10
personal rating similarity     × 0.05
EXCLUDE: games already owned or favorited
COLD START (no collection): fallback to sort=rank
```

### Caching
`SETEX rec:{userId} 3600 {json}` — 1 hour Redis cache per user.
Invalidated when user's collection changes.

### New files
```
backend/
  game/service/RecommendationService.java      ← taste profile + scoring query
```

### Modified files
```
game/service/GameService.java                  ← handle sort=recommended
game/controller/GameController.java            ← pass userId for recommended sort
```

### Frontend change
```
library/+page.svelte                           ← add "Recommended" sort chip
                                                  cold-start empty state message
```

---

## Feature 3 — Rulebook Pipeline

### Sources (priority order)
```
1. rule-book.org API   GET /games?search={nameEn}&language=en
                       → { results: [{ id, name, link, language }] }
                       → link is direct cdn.1j1ju.com PDF URL
                       → auto-approved, ingest immediately

2. en.1jour-1jeu.com   GET /rules/search?q={nameEn}
                       → scrape HTML for cdn.1j1ju.com PDF links
                       → same CDN as rule-book.org, wider coverage
                       → auto-approved, ingest immediately

3. Not found           → skip, wait for user/admin upload
```

### Approval matrix
| Source | Status on create | Who approves |
|--------|-----------------|--------------|
| rule-book.org auto | `approved` immediately | Nobody — auto |
| 1jour1jeu auto | `approved` immediately | Nobody — auto |
| Admin upload | `approved` immediately | Nobody — auto |
| User upload | `pending_review` | Admin |

### User upload queue
```
User A uploads for Catan → pending_review (position 0)
User B uploads for Catan → queued (position 1)
User C uploads for Catan → queued (position 2)

Admin approves A → B and C auto-cancelled → both notified
Admin rejects A  → B moves to pending_review → B notified
```

### Ingestion pipeline (runs on every approval)
```
@Async RulebookIngestionService.ingest(rulebookId)
  1. Download PDF (from R2 or CDN URL)
  2. PDFBox: extract text
  3. Clean: strip headers/footers, normalize whitespace
  4. Chunk: 375 words / 50-word overlap
  5. For each chunk: EmbeddingService.embed(chunkText) → float[1536]
  6. Batch upsert into game_rules
     (DELETE existing chunks for this game first, then insert — atomic tx)
  7. Trigger HowToPlayExtractionService.extractAsync(gameId)
```

### Background job
```java
@Scheduled(cron = "0 2 * * *")   // 2am daily
RulebookAutoFetchJob.run()
  - Redis lock: setIfAbsent("job:rulebook-fetch", ..., 23h) → skip if locked
  - Query: games WHERE no approved rulebook, ORDER BY rank ASC, LIMIT 200/run
  - For each game:
      1. Try rule-book.org
      2. Try 1jour1jeu
      3. Skip if neither found
  - Release lock
```

### Endpoints
```
User-facing:
  POST /api/v1/games/{gameId}/rulebook          multipart PDF upload
  GET  /api/v1/games/{gameId}/rulebook/status   { status, queuePosition }

Admin:
  GET  /api/v1/admin/rulebooks?status=pending_review
  POST /api/v1/admin/rulebooks/{id}/approve
  POST /api/v1/admin/rulebooks/{id}/reject      { reason? }
  POST /api/v1/admin/games/{gameId}/rulebook    multipart, auto-approved
```

### New migrations
```
V24__create_game_rulebooks.sql
V25__create_game_how_to_play.sql
V26__add_hnsw_index.sql          ← HNSW on game_rules.embedding (not ivfflat)
V27__create_ai_rule_queries.sql  ← Logging user questions for analytics
```

### New files
```
backend/
  ai/client/RuleBookOrgClient.java
  ai/client/OnjRulebookClient.java
  ai/service/RulebookIngestionService.java
  ai/service/RulebookQueueService.java
  ai/job/RulebookAutoFetchJob.java
  ai/entity/GameRulebook.java
  ai/entity/AiRuleQuery.java          ← New: query logging entity
  ai/repository/GameRulebookRepository.java
  ai/repository/AiRuleQueryRepository.java ← New: query logging repository
  ai/controller/RulebookUserController.java
  ai/controller/RulebookAdminController.java
  ai/dto/RulebookStatusResponse.java
  ai/dto/RulebookQueueItem.java
```

### Notification types added
`RULEBOOK_APPROVED`, `RULEBOOK_REJECTED`, `RULEBOOK_UNDER_REVIEW`

---

## Feature 4 — How To Play Tab

### Tab placement
`Overview | How to Play | Details | My Stats`

### Extracted JSON schema
```json
{
  "metadata": { "type", "players", "playtime", "complexity", "genres" },
  "overview": "",
  "objective": "",
  "gameStructure": { "mode", "phases": [{ "name", "description", "actions" }], "turnOrder" },
  "components": [{ "name", "type", "description", "quantity" }],
  "board": { "exists", "type", "description" },
  "pieces": [{ "name", "type", "movementRules", "abilities" }],
  "resources": [{ "name", "type", "usedFor", "gainedBy" }],
  "cardSystem": { "exists", "cardTypes": [{ "name", "description", "variants" }], "deckRules", "handRules" },
  "actions": [{ "name", "type", "cost", "effect", "constraints" }],
  "rules": { "coreRules", "specialRules": [{ "name", "description" }], "edgeCases" },
  "playerInteraction": { "type", "interactionMechanics" },
  "information": { "visibility", "hiddenElements" },
  "winCondition": { "type", "details" },
  "loseCondition": { "exists", "details" },
  "scoring": { "exists", "methods": [{ "item", "points" }] },
  "endCondition": { "trigger", "notes" },
  "roles": { "exists", "list": [{ "name", "abilities", "winCondition" }] },
  "scenarios": { "exists", "list": [{ "name", "description" }] },
  "variants": [{ "name", "description" }],
  "tags": [],
  "faq": [{ "question", "answer" }],
  "tips": []
}
```
Only fields relevant to the game are populated. Empty/null/false fields are omitted.

### Extraction (two-pass GPT)
```
Pass 1 — structure
  Context: top 20 rule chunks (or BGG description + general knowledge)
  Prompt:  "Extract game rules as JSON matching this schema. Only include relevant fields."
  Output:  JSON blob (all fields except faq/tips)

Pass 2 — FAQ + tips
  Context: same as pass 1
  Prompt:  "Generate 3–5 beginner FAQ pairs and 3–5 practical tips as JSON."
  Output:  { faq: [...], tips: [...] }

Merge → store in game_how_to_play.content JSONB
```

### Generation flow
```
GET /api/v1/games/{gameId}/how-to-play
  → record exists                → 200 { status: "ready", data: {...} }
  → no record, lock acquired     → trigger async, 200 { status: "generating" }
  → no record, lock exists       → 200 { status: "generating" }

Frontend polls every 2s while status = "generating"
Skeleton loader shown during wait (~8-15s first time)
Stored permanently once done
Re-generated when rulebook is replaced (RulebookIngestionService triggers it)
```

### Extraction Prompt (System)
```text
You are a rule extraction engine. Analyze the provided game rules for {gameTitle} and output a structured JSON representing the "How to Play" guide. 
Focus on:
1. Setup: Step-by-step physical arrangement.
2. Gameplay: Detailed turn structure and core actions.
3. Scoring: How to win and final tallying.
Omit fields that are not applicable to this specific game.
```

### JSONB Mapping (Spring Boot)
Use `@JdbcTypeCode(SqlTypes.JSON)` for the `content` field in `HowToPlay` entity to map directly to PostgreSQL `JSONB`.
```java
@JdbcTypeCode(SqlTypes.JSON)
@Column(name = "content", columnDefinition = "jsonb")
private HowToPlayData data; 
```

### Source modes
```
Rulebook mode  — game_rules rows exist → RAG extraction
                 Badge: "📖 Based on official rulebook"

General mode   — no game_rules → GPT general knowledge + BGG description
                 Badge: "🤖 Based on AI general knowledge ⚠️"
                 Show: [+ Submit Rulebook] button
```

### AI Assistant Call-to-action
- Located at bottom of "How to Play" tab.
- Triggers `AiAssistantDrawer` with `gameTitle` context.

### New files
```
backend/
  ai/entity/GameHowToPlay.java
  ai/repository/GameHowToPlayRepository.java
  ai/service/HowToPlayExtractionService.java
  ai/controller/HowToPlayController.java
  ai/dto/HowToPlayResponse.java

frontend/
  src/lib/components/game/HowToPlayTab.svelte
  src/lib/components/game/HowToPlaySection.svelte   ← collapsible wrapper
  src/lib/components/game/ResourceChips.svelte
  src/lib/components/game/TurnPhaseCards.svelte
  src/lib/components/game/RulesAccordion.svelte
  src/lib/components/game/FaqAccordion.svelte
  src/lib/components/game/AiAssistantDrawer.svelte    ← Floating Sidebar / Bottom Drawer
  src/lib/api/howtoplay.ts
```

---

## Feature 5 — AI Rules Assistant (RAG)

### Pipeline
```
POST /api/v1/ai/rules
  { gameId, question, conversationHistory: ConversationTurn[max=3] }

1. Rate limit
   Redis INCR ai:ratelimit:{userId}:{YYYY-MM-DD}
   > 20 → 429 AI_RATE_LIMIT_EXCEEDED

2. Cache check
   Normalize question (lowercase, strip punctuation)
   Key: ai:answer:{gameId}:{sha256(normalizedQuestion)}
   HIT → return { answer, cached: true, mode, disclaimer }

3. Context mode
   game_rules WHERE game_id = ? EXISTS?
     YES → embed question → pgvector HNSW search top 5 chunks → RAG mode
     NO  → use BGG description → general mode

4. Build prompt
   System: "You are a rules assistant for {gameName}. Answer ONLY from context below."
   Context: chunks (RAG) or description (general)
   History: last 3 Q&A turns from conversationHistory
   User: question

5. gpt-4o-mini
   temperature: 0.1, max_tokens: 500

6. Cache result
   SETEX ai:answer:{gameId}:{hash} 604800 {answer}   ← 7 days

7. Log Query (Backend Persistence)
   INSERT INTO ai_rule_queries { userId, gameId, question, answer, sourceMode }
   → Used to improve rules and FAQ over time.

### Memory & Persistence
- **Query Rewriting**: Before RAG search, use the LLM to consolidate `conversationHistory` + `question` into a standalone query.
  - **Prompt**: "Given the chat history: {history}, rewrite the user's latest question '{question}' as a self-contained search query for a rulebook."
- **Frontend Persistence**: Store message array in `localStorage` keyed by `ai_chat_{gameId}`.
- **Backend Logging**: Every non-cached query MUST be logged to `ai_rule_queries` for dataset collection.

### Error Codes
| Code | Meaning |
|------|---------|
| `AI_CONTEXT_BUSY` | Rulebook ingestion/extraction in progress |
| `AI_PROVIDER_ERROR` | OpenAI / LLM provider failed (Circuit record) |
| `AI_RATE_LIMIT` | User exceeded daily question quota |
| `RULE_NOT_FOUND` | RAG score too low, no relevant context found |

### Disclaimers
```
rulebook: "AI-generated from the official rulebook. Verify for tournament play."
general:  "No rulebook uploaded yet. Based on AI general knowledge — may not be fully accurate."
```

### Services
```
backend/
  ai/service/EmbeddingService.java          ← text-embedding-3-small, circuit breaker
  ai/service/OpenAiCompletionService.java   ← gpt-4o-mini, circuit breaker
  ai/service/AiService.java                 ← full pipeline (fill existing stub)
  ai/controller/AiController.java           ← POST /api/v1/ai/rules (fill existing stub)
  ai/dto/AiAnswerResponse.java
  ai/dto/AiQueryRequest.java                ← already exists
```

---

## Feature 6 — Admin Rulebook Review Page

### Access
Profile page → "Admin Panel" button (visible only when `user.role === 'ADMIN'`) → `/admin/rulebooks`

### Page content
```
Pending Rulebooks (N)
┌──────────────────────────────────────────────────────────┐
│ [cover] Catan          Uploaded by: minhen   2026-03-01  │
│         Source: user   [View PDF]  [Approve] [Reject ▾]  │
└──────────────────────────────────────────────────────────┘
```
Reject opens a small optional reason input → sends `RULEBOOK_REJECTED` notification to uploader.

### New files
```
frontend/
  src/routes/(app)/admin/rulebooks/+page.svelte
  src/routes/(app)/admin/rulebooks/+page.ts
  src/lib/api/admin.ts
```

### Modified files
```
src/routes/(app)/profile/+page.svelte     ← Admin button for ROLE_ADMIN
```

---

## Config changes

### build.gradle.kts — add dependencies
```kotlin
implementation("org.apache.pdfbox:pdfbox:3.0.3")    // PDF text extraction
implementation("org.jsoup:jsoup:1.18.1")             // 1jour1jeu HTML scraping
```

### AppProperties.java — add OpenAI section
```yaml
app:
  openai:
    api-key: ${OPENAI_API_KEY:}
    embedding-model: text-embedding-3-small
    completion-model: gpt-4o-mini
```

### application.yml — add circuit breaker
```yaml
resilience4j:
  circuitbreaker:
    instances:
      openai:
        slidingWindowSize: 10
        failureRateThreshold: 50
        waitDurationInOpenState: 30s
        permittedNumberOfCallsInHalfOpenState: 3
        automaticTransitionFromOpenToHalfOpenEnabled: true
  timelimiter:
    instances:
      openai:
        timeoutDuration: 15s
```

---

## Build order

```
Step 1  Config + build.gradle (AppProperties, application.yml)
Step 2  Migrations V23–V26
Step 3  EmbeddingService + OpenAiCompletionService   ← everything depends on these
Step 4  SearchTranslationService + GameRepository trigram + GameService.search()
Step 5  RecommendationService + GameService.browse() + sort=recommended
Step 6  RuleBookOrgClient + OnjRulebookClient
Step 7  RulebookIngestionService + RulebookAutoFetchJob
Step 8  RulebookQueueService + RulebookUserController + RulebookAdminController
Step 9  AiService + AiController (RAG pipeline + logging)
Step 10 HowToPlayExtractionService + HowToPlayController
Step 11 GameDetailResponse.hasRulebook field
Step 12 Frontend: types/index.ts + api clients (ai.ts, rulebook.ts, admin.ts, howtoplay.ts)
Step 13 Frontend: HowToPlay components (HowToPlayTab + children)
Step 14 Frontend: AiAssistantDrawer (Sidebar/Drawer UI)
Step 15 Frontend: library page (Recommended chip, search translation hint)
Step 16 Frontend: admin rulebook page
Step 17 Frontend: profile page (Admin button)
```

---

## Security & Rate Limiting

### Backend (Security)
- **Role-based Access**: Admin endpoints (`/api/v1/admin/**`) must be protected with `PreAuthorize("hasRole('ROLE_ADMIN')")`.
- **Upload Sanitization**: PDF uploads must be checked for `application/pdf` magic bytes. Max size: 25MB.
- **Data Privacy**: Ensure user-specific chat logs in `ai_rule_queries` do not leak PII (only store `userId` as reference, not name/email).

### Rate Limiting (Redis)
- **AI Questions**: 20 per user/day.
- **Rulebook Uploads**: 5 per user/day to prevent spam ingestion.
- **Search Translation**: 50 per user/day (low cost but prevent abuse).
- **Implementation**: Use a Spring `HandlerInterceptor` or a dedicated `RateLimitService` with Redis `INCR` + `EXPIRE`.

---

## Verification probes (build before Step 1)

Two endpoints to add to `AiAdminController` and run manually:

### 1. OpenAI probe
`GET /api/v1/admin/test/openai`
- Calls `text-embedding-3-small` with input `"test"` → verify returns 1536 dimensions
- Calls `gpt-4o-mini` with `"Say hello in one word"` → verify non-empty response
- Returns `{ embeddingDims, completionResponse, latencyMs }`

**Why:** EmbeddingService and OpenAiCompletionService are built on this. If the key is wrong or the model names changed, everything else fails.

### 2. CDN PDF download probe
`GET /api/v1/admin/test/pdf-download`
- Downloads `https://cdn.1j1ju.com/medias/7a/18/fd-catan-rulebook.pdf`
- Returns `{ contentType, sizeBytes, downloadable }`
- Does NOT store the file — just checks the download works

**Why:** The entire rulebook pipeline depends on being able to download from this CDN. If the CDN blocks server-side requests (bot protection, IP blocking), the background job won't work and we need to rethink.

### 3. pg_trgm (verify via migration)
Just run V23 migration. If `CREATE EXTENSION pg_trgm` succeeds on Neon, it works. No separate probe needed.

### 4. HNSW index (verify via migration)
Just run V26 migration. If `CREATE INDEX ... USING hnsw` succeeds, it works.
