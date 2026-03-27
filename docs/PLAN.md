# Meeple & Hearth — Product & Development Plan

## 1. Vision

A **private social board game platform** for friend groups to:
- Track their game collections
- Organize and manage game nights (events)
- Match players who want to play the same game
- Record memories (photos, notes, stats) from sessions
- Get AI-powered rule explanations

**Core differentiator:** Every other app does *tracking OR social*. Meeple & Hearth does **Tracking + Social + Events + Matching** in one cohesive experience.

---

## 2. User Personas

### Primary: The Organizer
- Hosts game nights regularly
- Manages a large collection (50+ games)
- Needs easy event creation and player coordination
- Values social proof ("what are my friends playing?")

### Secondary: The Casual Player
- Joins events, doesn't host often
- Wants to discover new games from friends' collections
- Loves sharing session memories/photos
- May not know rules well → AI assistant is key

### Tertiary: The Collector
- Tracks everything meticulously
- Cares about play counts, stats, ratings
- Manages wishlist actively
- Profile is a showpiece

---

## 3. Feature Breakdown (Detailed)

### 3.1 Home — Smart Feed

**Top Smart Section**
- Personalized greeting: "Good evening, [Name]!"
- Subtitle: "Your next session is in X days." (pulls from upcoming events)
- **Match Suggestion Card** (highest priority widget):
  - Shows: "[N] friends want to play [Game] this Saturday"
  - Buttons: `Create Event` / `Join Them`
  - Background: subtle primary-tinted card with blur orb decoration
  - Only shown when an active match suggestion exists for the user

**Upcoming Events Row**
- Horizontal scroll of `EventCard` components
- Each card shows: tag (day/time), event name, location, participant avatar stack
- Tapping opens Event Detail
- "View Calendar" link in header

**Activity Feed**
- Infinite scroll of social feed items, two types:
  - `SessionPost` — photo, caption, tagged users/game, like/comment/share actions
  - `CollectionUpdate` — compact card: "[Friend] added [Game] to their collection"
- Feed is filtered to: friends + your own activity
- Future: "Explore" tab for public posts

---

### 3.2 Library

**Tabs:**
1. **All Games** — Browsing via external Board Game Geek (BGG) API (or RAWG-equivalent for board games)
2. **My Collection** — Games the user owns
3. **Wishlist** — Games the user wants
4. **Favorites** — Games the user starred

**Search & Filters** (persistent across tabs):
- Text search (name)
- Filter by: min/max players, duration range, category/mechanic, complexity weight

**Game Card** (in list/grid):
- Thumbnail, title, player count, duration
- Colored dot indicating ownership status (owned / wishlisted / neither)

**Game Detail Page:**
- Hero image (full-bleed, gradient fade to background)
- Game title, designer, publisher
- Info bar: Players | Duration | Complexity Weight (3-column grid)
- "Owned by" — avatar stack of friends who own this game
- Action buttons:
  - `Add to Collection` (gradient primary button)
  - `Wishlist` (muted button)
  - `AI Rules Assistant` (teal/tertiary button)
- Tabs: Overview | Reviews | Sessions | Friends
  - **Overview**: description, mechanics, categories, BGG rating
  - **Reviews**: friends' ratings and notes
  - **Sessions**: past sessions logged with this game
  - **Friends**: who owns it, play counts

---

### 3.3 Events

**Calendar View:**
- Monthly calendar, days with events show a colored dot
- Tapping a day shows events for that day in a bottom sheet

**List View:**
- Toggle between Upcoming / Past
- Each event card: game thumbnail, event name, host, participants (X/Y), location, date/time, status chip

**Event Detail:**
- Header: game cover art (hero), event name
- Info: Host avatar + name, date, time, location (with map pin)
- Participant list: avatar grid, "Join Event" button if not joined, capacity bar (3/5)
- Status: `Open` / `Full` / `Completed`
- Description/notes section
- Action: `Join` / `Leave` / `Manage` (if host)

**Create Event Form:**
- Select game (search/pick from collection)
- Date + time picker
- Location (text input + optional map)
- Max participants (slider or number input)
- Invite friends (multi-select from friend list)
- Description (optional)
- Submit: creates event, sends invites as notifications

---

### 3.4 Matching System

**User Side:**
- Set "I want to play [Game]"
- Set "I'm available [Day/Time range]"
- These are stored as `match_requests`

**System Side:**
- Background job (or on-request check) that:
  1. Finds users who have overlapping game interest
  2. Checks time availability overlap
  3. Surfaces a "Match Found" suggestion to the relevant users
- Suggestion appears on Home feed as a Match Card
- Options: `Create Event Together` / `Ignore`

**Match Found Notification:**
- Push (FCM) if offline
- WebSocket if online
- Message: "[N] friends are available to play [Game] this [Day]"

---

### 3.5 Posts / Memories

**Create Post:**
- Upload 1–10 images (stored on Cloudflare R2)
- Write a caption/description
- Tag: players (friend list), game (search), location (text), date/time
- On submit:
  - Creates `post` record in DB
  - Creates `post_images` records
  - Creates `post_tags` for users and games
  - **Auto-increments** `play_count` in `user_games` for all tagged users + game

**Post Card (Feed):**
- User avatar + name + timestamp + location
- Image carousel (if multiple)
- Caption
- Action bar: Like | Comment | Share
- Tagged game chip (tapping opens Game Detail)

**Memory Log:**
- A filtered view of posts (your own + tagged in)
- Grouped by game or by date
- Acts as a personal game journal

---

### 3.6 Profile

**Header:**
- Avatar (slightly rotated card style, `verified` badge)
- Username + location
- `Follow` / `Unfollow` button
- Stats bento grid:
  - **Games Owned** — count from `user_games`
  - **Sessions** — total play count
  - **Friends** — follower/following count

**Sections:**
- **Favorite Games** — horizontal scroll of user's starred games
- **Recent Sessions** — posts the user created or was tagged in
- **Collection** — link to their Library filtered to their collection
- **About** — bio, join date

**Own Profile extras:**
- Edit profile button
- Settings link
- Collection stats: favorite category, most-played game, avg session length

---

### 3.7 Notifications

**Types:**
| Type | Trigger | Channel |
|------|---------|---------|
| Event Invite | Someone invites you to an event | In-app + WebSocket + FCM |
| Match Found | System finds a match | In-app + WebSocket + FCM |
| Friend Activity | Friend adds game, posts, joins event | In-app |
| Event Reminder | 24h before event you joined | In-app + FCM |
| New Follower | Someone follows you | In-app |
| Comment/Like | Activity on your post | In-app |

**Notification Flow:**
```
Action occurs
    → Save notification to DB (always)
    → Is user online? (check WebSocket session)
        YES → push via WebSocket
        NO  → send via FCM (push notification)
```

**Notifications Screen:**
- List of notifications, grouped by "Today" / "This Week" / "Earlier"
- Unread dot indicator
- Tap to navigate to relevant content
- "Mark all as read" action

---

### 3.8 Global Create Button (FAB)

Floating Action Button in bottom navigation:
- Tap opens a bottom sheet with:
  - `Post` — opens Create Post flow
  - `Event` — opens Create Event form
  - `Add Game` — opens Library search to add to collection

---

## 4. Database Schema (Detailed)

### Users & Social
```sql
users
  id UUID PK
  username VARCHAR(50) UNIQUE NOT NULL
  email VARCHAR(255) UNIQUE NOT NULL
  password_hash VARCHAR NOT NULL
  display_name VARCHAR(100)
  bio TEXT
  avatar_url VARCHAR
  location VARCHAR(100)
  created_at TIMESTAMP DEFAULT NOW()
  updated_at TIMESTAMP

follows
  follower_id UUID FK(users.id)
  following_id UUID FK(users.id)
  created_at TIMESTAMP
  PRIMARY KEY (follower_id, following_id)
```

### Games & Collections
```sql
games
  id UUID PK
  bgg_id INTEGER UNIQUE          -- BoardGameGeek external ID
  name VARCHAR(255) NOT NULL
  description TEXT
  image_url VARCHAR
  min_players INTEGER
  max_players INTEGER
  min_duration INTEGER            -- minutes
  max_duration INTEGER
  complexity DECIMAL(3,2)         -- 1.0–5.0
  category VARCHAR(100)[]         -- array of categories
  mechanics VARCHAR(100)[]        -- array of mechanics
  designer VARCHAR(255)
  publisher VARCHAR(255)
  bgg_rating DECIMAL(4,2)
  created_at TIMESTAMP

user_games
  id UUID PK
  user_id UUID FK(users.id)
  game_id UUID FK(games.id)
  status VARCHAR(20)              -- 'owned' | 'wishlist' | 'favorite'
  play_count INTEGER DEFAULT 0
  personal_rating DECIMAL(3,1)   -- 1.0–10.0
  notes TEXT
  added_at TIMESTAMP
  UNIQUE(user_id, game_id)
```

### Events
```sql
events
  id UUID PK
  host_id UUID FK(users.id)
  game_id UUID FK(games.id)
  title VARCHAR(255) NOT NULL
  description TEXT
  location VARCHAR(255)
  location_lat DECIMAL(9,6)       -- optional GPS
  location_lng DECIMAL(9,6)
  scheduled_at TIMESTAMP NOT NULL
  max_participants INTEGER DEFAULT 8
  status VARCHAR(20) DEFAULT 'open'   -- 'open' | 'full' | 'completed' | 'cancelled'
  created_at TIMESTAMP

event_participants
  event_id UUID FK(events.id)
  user_id UUID FK(users.id)
  status VARCHAR(20) DEFAULT 'invited'  -- 'invited' | 'accepted' | 'declined'
  joined_at TIMESTAMP
  PRIMARY KEY (event_id, user_id)
```

### Posts & Memories
```sql
posts
  id UUID PK
  author_id UUID FK(users.id)
  game_id UUID FK(games.id) NULL     -- optional game tag
  caption TEXT
  location VARCHAR(255)
  played_at TIMESTAMP NULL           -- when the session happened
  created_at TIMESTAMP
  updated_at TIMESTAMP

post_images
  id UUID PK
  post_id UUID FK(posts.id)
  url VARCHAR NOT NULL               -- Cloudflare R2 URL
  display_order INTEGER DEFAULT 0

post_tags
  id UUID PK
  post_id UUID FK(posts.id)
  tagged_user_id UUID FK(users.id) NULL
  tagged_game_id UUID FK(games.id) NULL

post_likes
  post_id UUID FK(posts.id)
  user_id UUID FK(users.id)
  created_at TIMESTAMP
  PRIMARY KEY (post_id, user_id)

post_comments
  id UUID PK
  post_id UUID FK(posts.id)
  author_id UUID FK(users.id)
  body TEXT NOT NULL
  created_at TIMESTAMP
```

### Notifications
```sql
notifications
  id UUID PK
  recipient_id UUID FK(users.id)
  type VARCHAR(50) NOT NULL          -- 'event_invite' | 'match_found' | 'friend_activity' | etc.
  title VARCHAR(255)
  body TEXT
  data JSONB                         -- flexible payload (event_id, post_id, etc.)
  is_read BOOLEAN DEFAULT FALSE
  created_at TIMESTAMP
```

### Matching
```sql
match_requests
  id UUID PK
  user_id UUID FK(users.id)
  game_id UUID FK(games.id)
  available_from TIMESTAMP
  available_until TIMESTAMP
  status VARCHAR(20) DEFAULT 'active'   -- 'active' | 'matched' | 'expired'
  created_at TIMESTAMP

match_groups
  id UUID PK
  game_id UUID FK(games.id)
  suggested_at TIMESTAMP
  status VARCHAR(20) DEFAULT 'pending'

match_group_members
  match_group_id UUID FK(match_groups.id)
  user_id UUID FK(users.id)
  match_request_id UUID FK(match_requests.id)
```

### AI (RAG)
```sql
game_rule_chunks
  id UUID PK
  game_id UUID FK(games.id)
  chunk_index INTEGER
  content TEXT NOT NULL
  embedding VECTOR(1536)             -- pgvector extension
  token_count INTEGER
  created_at TIMESTAMP

ai_query_cache
  id UUID PK
  game_id UUID FK(games.id)
  question_hash VARCHAR(64)          -- SHA-256 of normalized question
  answer TEXT
  created_at TIMESTAMP
  expires_at TIMESTAMP
```

---

## 5. API Endpoints (Spring Boot REST)

### Auth
```
POST   /api/auth/register
POST   /api/auth/login
POST   /api/auth/refresh
POST   /api/auth/logout
```

### Users
```
GET    /api/users/{id}
GET    /api/users/{id}/collection
GET    /api/users/{id}/posts
GET    /api/users/{id}/followers
GET    /api/users/{id}/following
PUT    /api/users/me
POST   /api/users/{id}/follow
DELETE /api/users/{id}/follow
```

### Games
```
GET    /api/games?search=&category=&players=&duration=
GET    /api/games/{id}
GET    /api/games/{id}/sessions
GET    /api/games/search/bgg?q=        -- proxies BGG API
```

### User Games (Collection)
```
GET    /api/me/games?status=owned|wishlist|favorite
POST   /api/me/games                   -- add game to collection
PUT    /api/me/games/{gameId}          -- update status/rating/notes
DELETE /api/me/games/{gameId}
```

### Events
```
GET    /api/events?status=upcoming|past
GET    /api/events/{id}
POST   /api/events
PUT    /api/events/{id}
DELETE /api/events/{id}
POST   /api/events/{id}/join
DELETE /api/events/{id}/leave
GET    /api/events/{id}/participants
```

### Posts
```
GET    /api/feed                       -- social feed (friends + self)
GET    /api/posts/{id}
POST   /api/posts                      -- multipart (images + JSON body)
DELETE /api/posts/{id}
POST   /api/posts/{id}/like
DELETE /api/posts/{id}/like
GET    /api/posts/{id}/comments
POST   /api/posts/{id}/comments
DELETE /api/posts/{id}/comments/{commentId}
```

### Matching
```
GET    /api/matches/suggestions        -- get current match suggestions for user
POST   /api/matches/request            -- set match request (game + availability)
DELETE /api/matches/request/{id}       -- cancel match request
POST   /api/matches/{id}/accept        -- accept match suggestion → create event
POST   /api/matches/{id}/dismiss
```

### Notifications
```
GET    /api/notifications?page=&limit=
PUT    /api/notifications/read-all
PUT    /api/notifications/{id}/read
```

### AI
```
POST   /api/ai/rules                   -- { gameId, question }
```

### WebSocket
```
WS /ws                                 -- authenticated WebSocket connection
  SUBSCRIBE /user/queue/notifications  -- personal notification channel
  SUBSCRIBE /topic/events/{eventId}    -- event-specific updates
```

### Storage
```
POST   /api/upload/presign             -- get presigned R2 URL for direct upload
```

---

## 6. Development Phases

### Phase 1 — MVP (Weeks 1–4)

**Goal:** Working app with core loop: add games → create events → join events → post memories

| Week | Tasks |
|------|-------|
| 1 | Project scaffolding (SvelteKit + Spring Boot), Auth (register/login/JWT), Neon DB setup, basic routing |
| 2 | Game Library (BGG API integration), Collection CRUD (add/remove/status), Game Detail page |
| 3 | Events CRUD (create/list/detail/join/leave), Calendar view, Event Detail |
| 4 | Posts CRUD (create with images via R2, feed display), Profile page (stats, posts) |

**Deliverable:** Deployable MVP on Railway + Vercel/Cloudflare Pages. Users can sign up, build a collection, create events, and post session memories.

---

### Phase 2 — Social & Realtime (Weeks 5–7)

**Goal:** Make it feel alive with notifications and matching

| Week | Tasks |
|------|-------|
| 5 | Follow system (follow/unfollow), Social feed (friends' activities), Notification DB layer |
| 6 | WebSocket setup (Spring Boot STOMP), Realtime notifications, In-app notification center |
| 7 | Matching system (match_requests, background matching job, match suggestions on Home) |

**Deliverable:** App feels social. Friends' activities show on feed. Match suggestions appear. Real-time notifications arrive without refresh.

---

### Phase 3 — AI & Polish (Weeks 8–10)

**Goal:** Add AI assistant and production-level polish

| Week | Tasks |
|------|-------|
| 8 | FCM push notifications (offline users), AI Rules Assistant (RAG pipeline with OpenAI + pgvector) |
| 9 | Search improvements, filter UX, infinite scroll optimization, caching (Upstash Redis) |
| 10 | Performance audit, error handling, loading states, empty states, onboarding flow |

**Deliverable:** Full-featured, polished web app ready for real users.

---

### Phase 4 — Mobile (Post-launch)

- Flutter app development
- Shares the same Spring Boot backend API
- Platform-specific: FCM push handling, camera access, biometric auth
- App Store + Google Play submission

---

## 7. Testing Strategy

### Backend (Spring Boot)
- **Unit tests:** Service layer logic (matching algorithm, notification routing)
- **Integration tests:** Repository layer with real Neon test DB (not mocked)
- **API tests:** Controller endpoints via MockMvc or REST Assured

### Frontend (SvelteKit)
- **Component tests:** Vitest + Svelte Testing Library for UI components
- **E2E tests:** Playwright for critical flows (auth, create event, post flow)

### Manual QA Checklist (per phase)
- Auth flow (register, login, token refresh, logout)
- Game search + add to collection
- Event creation, join, leave
- Post creation with images
- Notification delivery (online + offline)
- Responsive layout on mobile viewport

---

## 8. Deployment Architecture

```
User Browser / Flutter App
        │
        ▼
Cloudflare (CDN + DNS)
        │
   ┌────┴────┐
   │         │
SvelteKit  Flutter
(Cloudflare  (app stores)
  Pages)
   │
   ▼
Spring Boot API
(Railway — auto-deploy from main branch)
   │
   ├─► Neon PostgreSQL (serverless, auto-suspend)
   ├─► Upstash Redis (optional cache)
   ├─► Cloudflare R2 (images, via presigned URLs)
   ├─► OpenAI API (AI rules)
   └─► Firebase (FCM push)
```

**CI/CD:**
- GitHub → Railway (backend auto-deploy on push to `main`)
- GitHub → Cloudflare Pages (frontend auto-deploy)
- Environment variables managed in Railway dashboard + Cloudflare Pages settings

---

## 9. Engineering Rules

**Do:**
- Use environment variables for ALL secrets (never hardcode)
- Keep backend stateless (JWT auth, no server-side sessions)
- Design clean, RESTful API with consistent error shapes: `{ error: string, code: string }`
- Normalize the database (no JSON blobs except `notifications.data`)
- Write DB migrations as versioned SQL files (Flyway or Liquibase)
- Use presigned URLs for all file uploads (never proxy through Spring Boot)

**Don't:**
- Don't over-engineer — no microservices, no Kafka, no complex infrastructure early
- Don't store files in the backend — all uploads go direct to R2
- Don't mock the database in integration tests
- Don't use God-class services — each service handles one domain

---

## 10. Open Questions / Future Decisions

- **BGG API vs. own game database:** BGG API is rate-limited and XML-based. Consider seeding a local Neon table from BGG data for frequently accessed games.
- **Rating system:** Use BGG ratings as baseline + allow personal ratings. Show average friend rating.
- **Privacy model:** For MVP, assume all users are "friends of friends" — open social graph. Later: private accounts.
- **AI cost control:** Cache AI responses per (game, question_hash). Limit to N queries per user per day.
- **Mobile-first vs. desktop:** Reference designs are mobile-first. SvelteKit app should be responsive but optimized for mobile viewport (max-w-lg centered).
