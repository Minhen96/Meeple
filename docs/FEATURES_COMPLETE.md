# Meeple — Complete Feature Specification

> Every feature. Every business rule. Every edge case. Every error condition.
> This is the single source of truth before writing any code.

---

## 0. Resolved Design Decisions (Critical)

Before anything else, these architectural decisions are locked:

| Decision | Choice | Reason |
|----------|--------|--------|
| **App name** | **Meeple** | Confirmed by owner. |
| **Target audience** | **Public** (starts with friends, scales to public community) | Build for scale from day 1. |
| **Language** | **English + Chinese Simplified (zh-CN)** | Malaysia-focused; English default, Chinese as second language. |
| Follow model | **Facebook friend request** — must send request, other person must accept. Friends = accepted connections only. | Trust-based. Aligns with the personal community feel of the app. |
| Social login | **Google OAuth** supported from day 1, alongside email/password. | Common expectation; easier to add early than retrofit. |
| Collection multi-status | **Multiple boolean columns** (`is_owned`, `is_wishlisted`, `is_favorited`) | A game can be owned AND favorited simultaneously. |
| Feed type | **Strictly reverse-chronological** | No algorithm in MVP. Simplest, no black box. |
| Pagination | **Cursor-based** (timestamp cursor) for all feeds/lists | Stable across inserts; offset breaks on live feeds. |
| Post play count on delete | **Not decremented** | The game was still played regardless of post deletion. |
| Timezone storage | **UTC always** in DB. Frontend converts to user's local timezone. | Standard practice. Never store local times in DB. |
| Token storage | **httpOnly cookie** for web. `flutter_secure_storage` for mobile. | Prevents XSS token theft. |
| Soft delete | Users, posts, events, comments all get `deleted_at`. | Enables recovery; satisfies GDPR grace period. |
| API versioning | **URL prefix `/api/v1/`** from the start. | Prevents breaking Flutter clients on API changes. |
| Event visibility | **Three levels**: `invite_only` / `friends` / `public` — chosen at creation. Default: `invite_only`. | Friends can host private game nights; community can run public events. |
| WebSocket auth | JWT passed as **STOMP `connect` header** (not query param). | Query params appear in server logs — security risk. |
| Matching scope | **Mutual follows (friends) only** can match. | Prevents strangers being matched with you. |
| Image compression | **Client-side** before upload, max 1MB / 1200px, WebP. | Reduces R2 storage cost and upload time. |
| AI mode | **Conversation mode** — remembers last 3 Q&A pairs per session (client-side state, included in prompt). | Natural follow-up questions work. Tiny cost increase, big UX improvement. |
| External game data | **BGG XML API2** only. Board Game Atlas shut down in 2022. Aggressive Neon caching reduces BGG calls. | No viable alternative. Cache all game data in local DB. |
| Code standards | Industry-standard: circuit breakers (Resilience4j), monitoring (Grafana), 3 environments, daily backups, CI gates. | See `ENGINEERING_STANDARDS.md`. |

---

## 1. Authentication & Account Management

### 1.1 Registration

**Fields:**
- `email` — valid RFC 5322 format, max 255 chars, unique (case-insensitive)
- `username` — 3–30 chars, `^[a-zA-Z0-9_]+$` only, unique (case-insensitive), stored lowercase
- `password` — 8–128 chars, must contain at least 1 letter and 1 number
- `displayName` — optional at registration, 1–50 chars (prompted in onboarding)

**Real-time availability checks (debounced 500ms):**
- `GET /api/v1/auth/check-username?username=xxx` → `{ available: true|false }`
- `GET /api/v1/auth/check-email?email=xxx` → `{ available: true|false }`
- These endpoints are rate-limited: max 30 req/min per IP

**Flow:**
1. User submits form
2. Backend validates all fields, checks uniqueness
3. Hash password with **bcrypt** (cost factor 12)
4. Create user with `email_verified = false`
5. Generate 64-hex email verification token, store hashed in `email_verification_tokens` table, expires 24h
6. Send verification email via Resend
7. Return `{ message: "Check your email to verify your account" }` (HTTP 201)
8. Client redirects to `/auth/verify-email` screen (shows "check your inbox" UI)

**Verification email:**
- Subject: "Verify your Meeple account"
- CTA button: `https://meeple-hearth.com/auth/verify-email?token=xxx`
- Resend button: available on the waiting screen, cooldown 60s
- `POST /api/v1/auth/resend-verification` → { email } — always returns 200 (prevents enumeration)

**Email verification:**
- `POST /api/v1/auth/verify-email` → { token }
- Validates token not expired, not used
- Sets `email_verified = true`, deletes token
- Returns JWT access + refresh tokens (logs user in immediately)
- Client redirects to `/onboarding`

**Account lockout:**
- Track failed attempts in Redis: `auth:failures:{email}` with INCR + TTL 15 min
- After 5 failures: lock account for 15 minutes (Redis: `auth:locked:{email}`)
- Error response: `{ error: "Too many failed attempts. Try again in X minutes.", code: "ACCOUNT_LOCKED" }`
- Lockout applies to email-based login only, not token refresh

**Edge cases:**
- Register with existing email (case-insensitive match): `{ code: "EMAIL_TAKEN" }`
- Register with existing username: `{ code: "USERNAME_TAKEN" }`
- Verification link expired: link shows "This link has expired. Request a new one." with resend button
- Verification link already used: "This link has already been used."
- User tries to login before verifying: `{ code: "EMAIL_NOT_VERIFIED", message: "Please verify your email first." }` — include a "resend email" action

---

### 1.2 Login

**Fields:** `emailOrUsername`, `password`

**Flow:**
1. Normalize input (lowercase email/username lookup)
2. Check `auth:locked:{email}` in Redis — if locked, return 429
3. Find user by email OR username
4. If user not found: increment failure counter, return `{ code: "INVALID_CREDENTIALS" }` (same message as wrong password — prevents enumeration)
5. If `email_verified = false`: return `{ code: "EMAIL_NOT_VERIFIED" }`
6. If `deleted_at IS NOT NULL`: check if within 30-day grace period
   - Within grace period: `{ code: "ACCOUNT_DELETED", message: "Your account is deactivated. Reactivate?" }` with reactivation link
   - After grace period: `{ code: "INVALID_CREDENTIALS" }` (account fully gone)
7. Compare bcrypt hash — if wrong: increment failure counter, return `{ code: "INVALID_CREDENTIALS" }`
8. On success: clear failure counter
9. Generate access token (JWT, 15 min) and refresh token (opaque 64-hex, 30 days)
10. Store refresh token hashed in `refresh_tokens` table with device info
11. Set `httpOnly` cookies: `access_token` and `refresh_token`
12. If `fcmToken` provided in body: update `users.fcm_token`
13. Return `{ user: UserDto }`

**Refresh token schema:**
```sql
refresh_tokens
  id UUID PK
  user_id UUID FK(users.id)
  token_hash VARCHAR(128) NOT NULL  -- SHA-256 of the raw token
  device_info VARCHAR(255)          -- "Mozilla/5.0..." or "Flutter iOS"
  created_at TIMESTAMP
  last_used_at TIMESTAMP
  expires_at TIMESTAMP
```

**Token rotation:** Every refresh generates a NEW refresh token. Old token is deleted. This detects token theft (if attacker uses a stale token, the legitimate user's token becomes invalid and they get logged out).

**Concurrent sessions:** Allowed. Each device has its own `refresh_tokens` row. A user can be logged into web, iOS, and Android simultaneously.

---

### 1.3 Token Refresh

- `POST /api/v1/auth/refresh` — reads `refresh_token` cookie
- Validates: exists in DB, not expired
- Detects rotation theft: if token hash not found, assume theft → revoke ALL refresh tokens for this user, return 401
- Issues new access token + new refresh token
- Updates `last_used_at` on the token row

---

### 1.4 Logout

- `POST /api/v1/auth/logout` — reads `refresh_token` cookie
- Deletes the specific refresh token row from DB
- Clears `users.fcm_token` for this device (set to NULL or use per-device FCM tokens — see note)
- Clears cookies (Set-Cookie with expired date)
- Returns 200

**Note on FCM tokens:** Store FCM tokens per device in a separate table `user_fcm_tokens` (user_id, token, device_info, updated_at) rather than a single column on users. On logout, delete the row for this device token. This allows push to multiple devices.

```sql
user_fcm_tokens
  id UUID PK
  user_id UUID FK(users.id)
  fcm_token VARCHAR(255) NOT NULL
  device_info VARCHAR(255)
  platform VARCHAR(20)   -- 'web' | 'ios' | 'android'
  updated_at TIMESTAMP
  UNIQUE(user_id, fcm_token)
```

---

### 1.5 Password Reset

**Request:**
- `POST /api/v1/auth/forgot-password` → { email }
- Always returns `{ message: "If that email is registered, you'll receive a reset link." }` (HTTP 200) — prevents enumeration
- If email exists + verified: generate 32-byte hex token, store hashed in `password_reset_tokens` (expires 1h), send email

**Reset email:**
- Subject: "Reset your Meeple password"
- Link: `https://meeple-hearth.com/auth/reset-password?token=xxx`
- Token valid for 1 hour, one-time use

**Confirm reset:**
- `POST /api/v1/auth/reset-password` → { token, newPassword }
- Validates token not expired, not used
- Updates password hash, marks token as used
- **Revokes all refresh tokens** (forces re-login on all devices)
- Returns `{ message: "Password updated. Please log in." }` — client redirects to login

**Edge cases:**
- Token expired: clear error "This link has expired. Request a new one."
- Token already used: "This link has already been used."
- New password same as old: allowed (no restriction)

---

### 1.6 Account Deletion

**Request:**
- `DELETE /api/v1/users/me` → { password } (password confirmation required)
- Validates password
- Sets `users.deleted_at = NOW()`
- Revokes all sessions (delete all refresh tokens)
- Sends confirmation email: "Your account has been scheduled for deletion in 30 days."

**Content handling on soft delete:**
- Posts: kept, `author_id` remains, but display name shows as "Deleted User" (frontend checks `author.deleted_at`)
- Events hosted: kept, shown as "by Deleted User"
- Comments: kept, shown as "Deleted User"
- Collection, follows, match requests: immediately deleted
- Notifications: immediately deleted

**Reactivation (within 30 days):**
- `POST /api/v1/auth/reactivate` → { email, password }
- Sets `deleted_at = NULL`
- Returns JWT, redirects to home

**Hard delete (after 30 days):**
- Scheduled job: daily at 3am UTC, finds users where `deleted_at < NOW() - 30 days`
- Hard deletes: user row, all posts, all images from R2 (via a cleanup queue)
- Anonymises remaining event/comment references ("Deleted User" becomes permanent)

**Data export (GDPR right to portability):**
- `GET /api/v1/users/me/export`
- Async: triggers background job, sends download link via email when ready
- Export contains: profile, collection, posts, events participated in, notifications (JSON zip)

---

### 1.7 Profile Updates

**Schema changes needed:**
```sql
ALTER TABLE users ADD COLUMN email_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMP;
ALTER TABLE users ADD COLUMN quiet_hours_start TIME;   -- e.g. '22:00'
ALTER TABLE users ADD COLUMN quiet_hours_end TIME;     -- e.g. '08:00'
ALTER TABLE users ADD COLUMN bgg_username VARCHAR(50);
ALTER TABLE users ADD COLUMN is_verified BOOLEAN DEFAULT FALSE;  -- platform-verified badge
```

**Edit profile:**
- `PUT /api/v1/users/me` → { displayName, bio, location, avatarUrl, bggUsername }
- Avatar: upload via presigned URL first, then pass key here
- Username changes: allowed once per 30 days (track `username_changed_at` on users)
- Email change: requires `POST /api/v1/users/me/change-email` → { currentPassword, newEmail } → sends verification to new email

---

## 2. Social Graph

### 2.1 Friend Request System (Facebook Model)

**Schema (replaces `follows` table entirely):**
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

**Friends = rows where `status = 'accepted'`** (bidirectional — either user can be sender).

**Is-friends query:**
```sql
SELECT EXISTS(
  SELECT 1 FROM friend_requests
  WHERE status = 'accepted'
    AND ((sender_id = $a AND receiver_id = $b)
      OR (sender_id = $b AND receiver_id = $a))
) AS are_friends;
```

**API Endpoints:**
```
POST   /api/v1/users/{id}/friend-request          — send friend request
DELETE /api/v1/users/{id}/friend-request          — cancel sent request (sender only)
POST   /api/v1/friend-requests/{id}/accept         — accept incoming request
POST   /api/v1/friend-requests/{id}/decline        — decline incoming request
DELETE /api/v1/friends/{userId}                    — unfriend (removes accepted row)
GET    /api/v1/friends                             — list my friends (accepted)
GET    /api/v1/friend-requests/received            — incoming pending requests
GET    /api/v1/friend-requests/sent                — outgoing pending requests
```

**Business rules:**
- Cannot send request to yourself: 400 `{ code: "CANNOT_FRIEND_SELF" }`
- Cannot send request to a blocked user: 403 `{ code: "BLOCKED_USER" }`
- Cannot send request if one already exists (any direction, any status): 409 `{ code: "REQUEST_EXISTS" }`
  - Exception: if the other person already sent YOU a request, calling this endpoint auto-accepts it (mutual intent)
- Decline is silent — the sender gets no notification
- After decline: sender can try again after 7 days (Redis cooldown: `fr:cooldown:{senderId}:{receiverId}`)
- Max pending outgoing requests: 50 (prevents spam)
- Unfriending: hard-delete the row (no soft delete for friendships)

**Notifications:**
- On send: `friend_request` notification to receiver
- On accept: `friend_request_accepted` notification to sender
- On decline: **no notification** (keep it private)

**Feed filtering:**
- Your feed shows posts from your **accepted friends only** + your own posts
- Public events are visible to everyone (no friendship required)
- Private events/matching/tagging: accepted friends only

### 2.2 Block / Mute

**Block effects (when A blocks B):**
- B cannot view A's profile (returns 404, not 403 — avoids confirming block)
- B's posts disappear from A's feed (immediate, on next load)
- A's posts disappear from B's feed (B doesn't know why)
- Existing A↔B friendship is silently removed (delete `friend_requests` row)
- Any pending friend request between them is cancelled
- B cannot comment on A's posts
- B cannot join events hosted by A (event join returns 404 for the event)
- B cannot tag A in posts (tag is silently dropped)
- B cannot send match request that would match with A
- Block is private — no notification sent to B
- Block is unidirectional: A blocks B ≠ B blocks A

```sql
blocked_users
  blocker_id UUID FK(users.id)
  blocked_id UUID FK(users.id)
  created_at TIMESTAMP
  PRIMARY KEY (blocker_id, blocked_id)
```

**Mute (Phase 2):** User X's posts are hidden from your feed but X doesn't know. No mute in MVP.

**Block endpoints:**
- `POST /api/v1/users/{id}/block`
- `DELETE /api/v1/users/{id}/block`
- `GET /api/v1/users/me/blocked` — list blocked users

### 2.3 User Search & Discovery

- `GET /api/v1/users/search?q=xxx&limit=20` — search by username or displayName
- Blocked users excluded from search results
- Results include a `friendshipStatus` field: `'none'` | `'pending_sent'` | `'pending_received'` | `'friends'`
- `GET /api/v1/users/suggestions` — users who own games in your collection (sorted by overlap count, max 10, exclude existing friends and pending requests)

### 2.4 Report

- `POST /api/v1/reports` → { targetType: 'user'|'post'|'comment', targetId, reason: string }
- Rate limit: 5 reports per user per day (Redis: `report:count:{userId}:{date}`)
- Store in `reports` table for manual admin review (no automated action in MVP)
- Returns 201 always (even if already reported same target — idempotent for reporter experience)

---

## 3. Game Library & Collection

### 3.1 Revised user_games Schema

```sql
-- REPLACES the old single-status design
user_games
  id UUID PK
  user_id UUID FK(users.id)
  game_id UUID FK(games.id)
  is_owned BOOLEAN DEFAULT FALSE
  is_wishlisted BOOLEAN DEFAULT FALSE
  is_favorited BOOLEAN DEFAULT FALSE
  play_count INTEGER DEFAULT 0
  personal_rating SMALLINT CHECK (personal_rating BETWEEN 1 AND 10)  -- NULL = not rated
  notes TEXT
  added_at TIMESTAMP DEFAULT NOW()
  updated_at TIMESTAMP DEFAULT NOW()
  UNIQUE(user_id, game_id)
  -- At least one flag must be true (enforced in application layer)
```

**Status combinations allowed:**
| is_owned | is_wishlisted | is_favorited | Meaning |
|----------|--------------|--------------|---------|
| true | false | false | Owned only |
| true | false | true | Owned + Favorited |
| false | true | false | On wishlist |
| false | false | true | Favorited (played elsewhere, not owned) |
| true | true | true | Owned, favorited, still on wishlist (weird but allowed) |
| false | false | false | **INVALID** — delete the row instead |

**API:**
- `POST /api/v1/me/games` → { gameId, isOwned?, isWishlisted?, isFavorited? } — creates or updates row
- `PATCH /api/v1/me/games/{gameId}` → { isOwned?, isWishlisted?, isFavorited?, personalRating?, notes? }
- `DELETE /api/v1/me/games/{gameId}` — removes row entirely (removes from all statuses)
- `GET /api/v1/me/games?owned=true&wishlisted=false&favorited=false&page=1&limit=30`

### 3.2 BGG API Integration

**Games table needs:**
```sql
ALTER TABLE games ADD COLUMN last_fetched_at TIMESTAMP;
ALTER TABLE games ADD COLUMN bgg_url VARCHAR(255);  -- https://boardgamegeek.com/boardgame/{id}
ALTER TABLE games ADD COLUMN year_published SMALLINT;
ALTER TABLE games ADD COLUMN age_minimum SMALLINT;
```

**Search flow:**
1. `GET /api/v1/games/search?q=catan&page=1&limit=20`
2. Spring Boot checks Redis: `bgg:search:{normalized_q}:{page}` — TTL 1h
3. Cache MISS: call BGG `/search?query=catan&type=boardgame`
4. BGG returns list of `{id, name, yearPublished}` objects (NO details)
5. Extract all IDs, batch-fetch details: `GET /thing?id=1,2,3,...20&stats=1` (BGG supports comma-separated IDs — max 20 per request)
6. Parse XML response (JAXB) — extract primary name, image, players, duration, complexity, description
7. Upsert each game into Neon `games` table (INSERT … ON CONFLICT DO UPDATE if last_fetched_at < 7 days)
8. Cache result in Redis 1h
9. Return JSON array of GameDto

**BGG queuing behavior (202 response):**
- BGG sometimes returns HTTP 202 with a text body: "Your request for this collection has been accepted and will be processed. Please try again later."
- Spring Boot handles this with a retry loop: check every 2s, up to 10 retries (20s total)
- If still not ready after 10 retries: return HTTP 503 with `{ code: "BGG_API_UNAVAILABLE" }`

**BGG rate limiting:**
- Use a `Semaphore(1)` in BggApiClient + minimum 500ms between calls
- If BGG returns 429: back off 5s, retry once
- BGG base URL: `https://boardgamegeek.com/xmlapi2`

**BGG XML parsing notes:**
- Game name: `<name type="primary" ...>` — there are multiple `<name>` elements, filter `type="primary"`
- Description: HTML-encoded, needs unescaping (`&amp;amp;` → `&`, etc.)
- Categories: `<link type="boardgamecategory" value="...">`
- Mechanics: `<link type="boardgamemechanic" value="...">`
- Designer: `<link type="boardgamedesigner" value="...">`
- Publisher: `<link type="boardgamepublisher" value="...">`
- Min/max players: `<minplayers value="2">`, `<maxplayers value="5">`
- Min/max playtime: `<minplaytime value="60">`, `<maxplaytime value="90">`
- Complexity: `<averageweight value="2.5">` (inside `<statistics>`)
- BGG rating: `<average value="7.8">` (inside `<statistics>`)
- Image URL: `<image>` text content (full URL starting with `//cf.geekdo-images.com`)

**BGG image URL handling:**
- BGG image URL starts with `//` (protocol-relative). Store as `https://cf.geekdo-images.com/...`
- If image is missing: store NULL, frontend uses `/images/game-placeholder.svg`
- Phase 2: mirror BGG images to R2 (background job: `games_image_mirror`)

**BGG collection import:**
- `POST /api/v1/me/bgg-import` → { bggUsername }
- Save `bgg_username` to `users.bgg_username`
- Call BGG `/collection?username=X&own=1&excludesubtype=boardgameexpansion`
- Handle 202 queuing with polling (same retry logic)
- For each game: upsert `games`, upsert `user_games` (isOwned=true, keep existing is_wishlisted/is_favorited)
- Track progress in Redis: `bgg:import:{userId}` = `{ total: 45, processed: 12, status: 'running' }`
- Client polls: `GET /api/v1/me/bgg-import/status` until status = 'done' or 'failed'
- Result: `{ imported: 42, skipped: 3, failed: 0 }`

### 3.3 Game Ratings

- `personalRating`: 1–10 integer, NULL if not rated
- Display mapping: 1–2 = 1★, 3–4 = 2★, 5–6 = 3★, 7–8 = 4★, 9–10 = 5★ (simplified display)
- Rate via PATCH: `PATCH /api/v1/me/games/{gameId}` → { personalRating: 8 }
- Rate inline on My Collection list (tap stars)
- Rate on Game Detail page via a modal
- "Friend average rating": compute on Game Detail request as:
  ```sql
  SELECT AVG(ug.personal_rating)
  FROM user_games ug
  JOIN follows f1 ON f1.following_id = ug.user_id AND f1.follower_id = $currentUserId
  JOIN follows f2 ON f2.following_id = $currentUserId AND f2.follower_id = ug.user_id
  WHERE ug.game_id = $gameId AND ug.personal_rating IS NOT NULL
  ```

---

## 4. Events

### 4.1 Event Creation Rules

**Required fields:** title, scheduledAt, (game is optional)
**Optional:** description, location, maxParticipants, invitedUserIds[]

**Validations:**
- `scheduledAt` must be >= NOW() - 5 minutes (allow slight clock drift)
- `maxParticipants`: min 2, max 50, default 8
- Game must exist in DB if provided
- Invited users must be mutual follows (cannot invite strangers)
- Cannot invite yourself (you're auto-added as host)
- Title max 100 chars, description max 1000 chars, location max 100 chars

**Host auto-participation:**
- On event creation: INSERT `event_participants` (eventId, hostId, status='accepted')
- Host always counts toward participant limit

**After creation:**
- For each `invitedUserIds`: create `event_participants` row with `status='invited'`
- For each invite: create `event_invite` notification → deliver via WS/FCM

### 4.2 RSVP States

```
invited   → accepted   (user taps "Accept")
invited   → declined   (user taps "Decline")
accepted  → left       (user taps "Leave")
invited   → (expired)  (event is cancelled)
```

Note: `left` is a terminal state per session (user can re-join if they're re-invited, but cannot un-leave on their own in MVP).

**Join (uninvited user):** NOT allowed in MVP. Events are invite-only. Phase 2: public events with open join.

### 4.3 Race Condition Handling (Last Spot)

```sql
-- In EventService.joinEvent(), inside a transaction:
SELECT COUNT(*) FROM event_participants
WHERE event_id = $eventId AND status = 'accepted'
FOR UPDATE;  -- row-level lock on the event's participant count

-- If count >= event.max_participants:
--   ROLLBACK, throw EventFullException → HTTP 409

-- Otherwise:
INSERT INTO event_participants (event_id, user_id, status)
VALUES ($eventId, $userId, 'accepted');

-- If event now full: UPDATE events SET status='full' WHERE id=$eventId
COMMIT;
```

### 4.4 Event Status Machine

```
open ──────────────────────────────────────────────────────► cancelled
open ──────► full (max participants reached)                      ▲
full ◄────── open (participant leaves, host kicks)                │
open/full ──► completed (host action or auto after 12h)          │
open/full ──────────────────────────────────────────────────────►┘
```

**Auto-complete job:**
- Runs every 30 minutes (Spring `@Scheduled`)
- Query: `SELECT id FROM events WHERE scheduled_at + interval '12 hours' < NOW() AND status IN ('open', 'full')`
- Mark as `completed`
- Send notification to host: `event_completed` → "How did [Event Name] go? Share the memories!"

**Event cancellation (`POST /api/v1/events/{id}/cancel`):**
- Host only
- Sets `status = 'cancelled'`
- Sends `event_cancelled` notification to all accepted participants
- Soft-deletes the event (`deleted_at = NOW()` — keeps it in history)

**Event update (`PUT /api/v1/events/{id}`):**
- Host only
- Can change: title, description, location, scheduledAt, maxParticipants, gameId
- If scheduledAt changes: send `event_updated` notification to all accepted participants
- Cannot reduce maxParticipants below current accepted count
- Cannot change game after event is `completed`

**Host leaving their own event:**
- HTTP 400 `{ code: "HOST_CANNOT_LEAVE", message: "Cancel the event or transfer host." }`
- Transfer host: Phase 2 feature

**Kick participant (`DELETE /api/v1/events/{id}/participants/{userId}`):**
- Host only
- Cannot kick yourself (host)
- Sets participant status to `'kicked'`
- Sends `event_kicked` notification to kicked user
- If event was `full`, reverts status to `open`

### 4.5 Event Reminder

- Scheduled job runs every hour
- Query: events where `scheduled_at BETWEEN NOW() + interval '23 hours' AND NOW() + interval '25 hours'` AND `reminder_sent = false`
- For each event: send `event_reminder` notification to all `accepted` participants
- Set `reminder_sent = true` on the event
- Add `reminder_sent BOOLEAN DEFAULT FALSE` to events table

**Edge case:** Event created less than 24h before start → reminder fires as soon as the event is created (on creation, check if start is within 24h and immediately mark `reminder_sent = true` — no reminder for very last-minute events)

### 4.6 Event Detail Response (DTO)

```json
{
  "id": "uuid",
  "title": "Heavy Euro Night",
  "game": { "id": "uuid", "name": "Wingspan", "imageUrl": "..." },
  "host": { "id": "uuid", "username": "alex", "displayName": "Alex", "avatarUrl": "..." },
  "scheduledAt": "2026-04-05T19:00:00Z",
  "location": "The Rookery Cafe",
  "maxParticipants": 5,
  "status": "open",
  "description": "Bring your best engine-building strategies!",
  "participants": [
    { "id": "uuid", "username": "sarah", "displayName": "Sarah", "avatarUrl": "...", "status": "accepted" }
  ],
  "acceptedCount": 3,
  "myStatus": "accepted",   // null if not a participant
  "isHost": false,
  "reminderSent": false
}
```

---

## 5. Posts & Memories

### 5.1 Post Types

Two types of items appear in the feed:

**Type 1: `post`** — user-created, can have images, caption, tags

**Type 2: `activity`** — system-generated, compact, no images
  - `collection_add`: "[User] added [Game] to their collection"
  - `event_created`: "[User] is hosting [Event Name]"
  - `event_joined`: "[User] joined [Event Name]"

Activity events stored in:
```sql
activity_events
  id UUID PK
  user_id UUID FK(users.id)
  type VARCHAR(50) NOT NULL   -- 'collection_add' | 'event_created' | 'event_joined'
  data JSONB NOT NULL          -- flexible payload
  created_at TIMESTAMP
  deleted_at TIMESTAMP
```

Feed endpoint returns a union of both, sorted by `created_at DESC`.

### 5.2 Post Creation

**Request:** `POST /api/v1/posts` (multipart or JSON after presigned upload)

```json
{
  "caption": "Finally beat Wingspan with 87 points!",
  "gameId": "uuid",
  "location": "Sarah's Hearth",
  "playedAt": "2026-04-05T20:00:00Z",
  "imageKeys": ["posts/temp/abc123.webp", "posts/temp/def456.webp"],
  "taggedUserIds": ["uuid1", "uuid2"]
}
```

**Validations:**
- `caption`: optional, max 2000 chars
- `gameId`: must exist if provided
- `playedAt`: cannot be in the future
- `imageKeys`: max 10, each key must exist in R2 (Spring Boot verifies via S3 HeadObject)
- `taggedUserIds`: must be mutual follows (or the user themselves — they can tag themselves explicitly)
- Tagged users who have blocked the post author: silently excluded from tags

**Processing on creation:**
1. Create `posts` row
2. Create `post_images` rows (move keys from `posts/temp/` to `posts/{postId}/`)
3. Create `post_tags` rows for tagged users and game
4. For each tagged user (including author if they tagged game): upsert `user_games` row, INCREMENT `play_count`
   - If `user_games` row doesn't exist: create it with `is_owned=false, is_wishlisted=false, is_favorited=false, play_count=1`
5. Create `activity_events` (if post has gameId) — for feed of author's followers
6. Notify tagged users: `post_tag` notification

**Image presigned URL flow:**
1. `POST /api/v1/upload/presign` → { count: 3, contentType: "image/webp" }
2. Spring Boot generates N presigned PUT URLs to R2 with key `posts/temp/{uuid}.webp`, expiry 15min
3. Returns: `[{ uploadUrl: "https://...", fileKey: "posts/temp/..." }]`
4. Client uploads each file directly to R2 (PUT request, no Spring Boot involved)
5. Client creates post with `imageKeys` containing the temp keys
6. Spring Boot moves/copies keys to `posts/{postId}/0.webp` etc. (R2 copy + delete)

**Presigned URL expiry edge case:** If upload takes >15 minutes (very slow connection): the PUT will fail with 403. Client should display "Upload expired — please try again." and re-request presigned URLs.

**Partial upload failure:**
- If 2 of 5 images fail to upload: post is created with the 2 successful images
- Client shows a warning: "2 images failed to upload" with a retry option (retry just those images and link to post)
- Phase 2: retry mechanism using the original presigned URLs if still valid

### 5.3 Post Deletion

- `DELETE /api/v1/posts/{id}` — author or admin only
- Soft delete: sets `posts.deleted_at = NOW()`
- Play counts: NOT decremented (game was still played)
- R2 images: NOT immediately deleted. A cleanup job runs daily: find `post_images` where `post.deleted_at < NOW() - 30 days`, delete R2 objects, delete `post_images` rows

### 5.4 Post Editing

- `PUT /api/v1/posts/{id}` — author only, within 48h of creation
- Can update: caption, location, playedAt, taggedUserIds, gameId
- **Cannot change images** (MVP simplification — too complex to add/remove images after upload)
- Sets `edited_at = NOW()` on the post
- Frontend displays "Edited" label if `edited_at IS NOT NULL`

**Tag changes on edit:**
- New tagged users: increment play_count, send notification
- Removed tagged users: decrement play_count only if this was the only post tagging them for this game

### 5.5 Feed Pagination

```
GET /api/v1/feed?cursor=2026-04-05T20:00:00Z&limit=20
```
- Cursor = `created_at` of the last item on the previous page (ISO 8601 UTC)
- Query: `WHERE (posts.created_at < $cursor OR activity_events.created_at < $cursor) ORDER BY created_at DESC LIMIT 20`
- First page: no cursor (returns newest 20)
- Response includes `nextCursor` for the next page, `hasMore: boolean`
- Cache: `feed:{userId}:cursor:{cursor}` in Redis, TTL 1 min (short TTL — feed is live)

### 5.6 Likes

- `POST /api/v1/posts/{id}/like` — idempotent (200 if already liked)
- `DELETE /api/v1/posts/{id}/like` — idempotent (200 if not liked)
- Like count returned in all post DTOs
- "Did I like this?" — `isLiked: boolean` field on post DTO (based on requesting user)

**Like notifications (batched):**
- Redis sorted set: `likes:notify:{postId}` with members = likerUserId, score = timestamp
- Rule: only one notification per post per hour per author
  - Check Redis: `likes:notified:{postId}:{authorId}` — if exists (TTL 1h): skip notification
  - If not exists: set key, send notification "X liked your post", store likerIds in the key value for batching
- After 1h cooldown: next like triggers a new notification with count: "X, Y, and 3 others liked your post"

### 5.7 Comments

**Create:** `POST /api/v1/posts/{id}/comments` → { body: "Great session!" }
- Body: 1–500 chars
- `@username` mentions: parse with regex `/@([a-zA-Z0-9_]+)/g`, validate each username exists, create notification for each

**Edit:** `PUT /api/v1/posts/{id}/comments/{commentId}` — author only, within 24h
**Delete:** `DELETE /api/v1/posts/{id}/comments/{commentId}` — author or post author

**Threading:** Flat (no nested replies) in MVP.

**Comment notifications:**
- Post author: `post_comment` notification (NOT sent if commenter IS the author)
- @mentioned users: `comment_mention` notification

### 5.8 Bookmarks / Save Post

- `POST /api/v1/posts/{id}/bookmark` / `DELETE` to unsave
```sql
bookmarks
  user_id UUID FK(users.id)
  post_id UUID FK(posts.id)
  saved_at TIMESTAMP
  PRIMARY KEY (user_id, post_id)
```
- `GET /api/v1/me/bookmarks?cursor=...&limit=20` — returns saved posts feed

### 5.9 Share

- Web: `navigator.share({ url: "https://meeple-hearth.com/posts/{id}" })` — falls back to copy-to-clipboard
- Flutter: `share_plus` package, native share sheet
- No in-app resharing in MVP

---

## 6. Matching System

### 6.1 Match Request

**Create:** `POST /api/v1/matches/requests` → { gameId, availableFrom, availableUntil }
- `gameId` is required (match by specific game)
- `availableFrom`: must be in the future
- `availableUntil`: must be after `availableFrom`, max 7 days into future
- Max 5 active match requests per user (HTTP 429 if exceeded)
- Duplicate: if user already has an active request for this game overlapping these times → 409 conflict

**Cancel:** `DELETE /api/v1/matches/requests/{id}` — own request only

**List mine:** `GET /api/v1/matches/requests/mine` — returns active requests

### 6.2 Matching Algorithm

**Runs every 30 minutes** via Spring `@Scheduled(fixedDelay = 1800000)`

**Distributed lock (Redis SETNX):**
```java
boolean locked = redisTemplate.opsForValue()
  .setIfAbsent("lock:matching_job", "1", Duration.ofMinutes(5));
if (!locked) return;  // another instance is running this job
```

**Algorithm:**
```sql
-- Find all pairs of active requests for the same game with overlapping time windows
SELECT r1.user_id AS user1_id, r2.user_id AS user2_id, r1.game_id,
       GREATEST(r1.available_from, r2.available_from) AS overlap_start,
       LEAST(r1.available_until, r2.available_until) AS overlap_end
FROM match_requests r1
JOIN match_requests r2 ON r1.game_id = r2.game_id AND r1.user_id < r2.user_id
-- Time overlap
WHERE r1.available_from < r2.available_until
  AND r2.available_from < r1.available_until
  AND r1.status = 'active' AND r2.status = 'active'
-- Mutual follows only
JOIN follows f1 ON f1.follower_id = r1.user_id AND f1.following_id = r2.user_id
JOIN follows f2 ON f2.follower_id = r2.user_id AND f2.following_id = r1.user_id
-- Exclude blocked pairs
WHERE NOT EXISTS (SELECT 1 FROM blocked_users b
  WHERE (b.blocker_id = r1.user_id AND b.blocked_id = r2.user_id)
     OR (b.blocker_id = r2.user_id AND b.blocked_id = r1.user_id))
```

**Group formation:**
- Collect all compatible users per game into groups
- Check game's `min_players` is met (if game has min_players=3, need at least 3 matching users)
- Create `match_groups` row, `match_group_members` rows
- Update involved `match_requests.status = 'matched'`
- Notify all members: `match_found` notification

**Match group lifecycle:**
```
pending → accepted (any member creates an event from the match)
pending → dismissed (all members dismiss)
pending → expired (48h passes with no action)
```

**Accept a match:** `POST /api/v1/matches/{matchGroupId}/accept`
- Creates an event pre-filled with: game, matched users as invited participants, suggested time = overlap_start
- Host = the accepting user
- Sets match_group status = 'accepted'
- Notifies other members: "Alex created an event for your game night!"

**Dismiss:** `POST /api/v1/matches/{matchGroupId}/dismiss`
- Sets `match_group_members.status = 'dismissed'` for the requesting user
- If ALL members dismiss: set match_group status = 'dismissed', reactivate their match_requests (status back to 'active')

### 6.3 Match Suggestions on Home

- `GET /api/v1/matches/suggestions` — returns match groups where current user is a member and status = 'pending'
- Displayed as "Match Suggestion Card" on Home feed
- One card per pending match group

---

## 7. Notifications

### 7.1 Notification Schema (Updated)

```sql
notifications
  id UUID PK
  recipient_id UUID FK(users.id)
  sender_id UUID FK(users.id) NULL  -- who triggered it (null for system notifications)
  type VARCHAR(50) NOT NULL
  title VARCHAR(255)
  body TEXT
  data JSONB                         -- { path: "/events/123", eventId: "...", etc. }
  is_read BOOLEAN DEFAULT FALSE
  is_pushed BOOLEAN DEFAULT FALSE   -- was FCM push sent?
  created_at TIMESTAMP

notification_preferences
  user_id UUID FK(users.id)
  type VARCHAR(50) NOT NULL
  in_app_enabled BOOLEAN DEFAULT TRUE
  push_enabled BOOLEAN DEFAULT TRUE
  PRIMARY KEY (user_id, type)
```

### 7.2 Complete Notification Types

| Type | Title | Body | data.path |
|------|-------|------|-----------|
| `event_invite` | "Game Night Invite" | "[Name] invited you to [Event]" | `/events/{id}` |
| `event_join` | "New Player!" | "[Name] joined [Event]" | `/events/{id}` |
| `event_leave` | "Player Left" | "[Name] left [Event]" | `/events/{id}` |
| `event_kicked` | "Removed from Event" | "You were removed from [Event]" | `/events` |
| `event_cancelled` | "Event Cancelled" | "[Event] has been cancelled" | `/events` |
| `event_updated` | "Event Updated" | "[Event] time has changed" | `/events/{id}` |
| `event_reminder` | "Game Night Tonight!" | "[Event] starts in 24 hours" | `/events/{id}` |
| `event_completed` | "Share Your Memories" | "How did [Event] go?" | `/posts/create` |
| `match_found` | "Play Together?" | "[N] friends want to play [Game]" | `/home` |
| `new_follower` | "New Follower" | "[Name] started following you" | `/profile/{id}` |
| `post_liked` | "New Like" | "[Name] liked your post" | `/posts/{id}` |
| `post_comment` | "New Comment" | "[Name] commented on your post" | `/posts/{id}` |
| `comment_mention` | "Mentioned You" | "[Name] mentioned you in a comment" | `/posts/{id}` |
| `post_tag` | "Tagged in Post" | "[Name] tagged you in a post" | `/posts/{id}` |

### 7.3 Delivery Logic

```java
// NotificationService.send(recipientId, type, title, body, data, senderId)
public void send(...) {
  // 1. Check notification preferences
  NotificationPreference pref = prefsRepo.findByUserIdAndType(recipientId, type)
    .orElse(DEFAULT_PREFS);  // default: all enabled

  // 2. Always save to DB
  Notification n = notificationRepo.save(...);

  // 3. Check quiet hours
  User recipient = userRepo.findById(recipientId);
  boolean inQuietHours = isQuietHours(recipient);

  // 4. WebSocket (in-app, real-time)
  if (pref.isInAppEnabled() && !inQuietHours) {
    wsService.sendToUser(recipientId, n);
    // Update unread count in Redis
    redisTemplate.opsForValue().increment("notif:unread:" + recipientId);
  }

  // 5. FCM push (only if offline AND not quiet hours)
  boolean isOnline = Boolean.TRUE.equals(
    redisTemplate.hasKey("ws:online:" + recipientId));
  if (pref.isPushEnabled() && !isOnline && !inQuietHours) {
    fcmService.sendAsync(recipientId, n);  // @Async
  }
}
```

**Quiet hours check:**
```java
boolean isQuietHours(User user) {
  if (user.getQuietHoursStart() == null) return false;
  LocalTime now = LocalTime.now(ZoneOffset.UTC); // or user's timezone
  LocalTime start = user.getQuietHoursStart();
  LocalTime end = user.getQuietHoursEnd();
  if (start.isBefore(end)) return now.isAfter(start) && now.isBefore(end);
  // Overnight range (e.g., 22:00–08:00)
  return now.isAfter(start) || now.isBefore(end);
}
```

**Stale FCM token handling:**
```java
// fcmService — if FCM throws InvalidRegistrationException or NotRegistredException:
fcmTokenRepo.deleteByToken(staleToken);
// Don't retry — the device is simply no longer registered
```

### 7.4 Unread Count

- Redis key: `notif:unread:{userId}` — integer counter
- Incremented on each new in-app notification
- Reset to 0 when user calls `PUT /api/v1/notifications/read-all`
- Decremented when individual notification is read (`PUT /api/v1/notifications/{id}/read`)
- Served via WebSocket as part of notification payload (so bell icon updates live)
- If Redis key missing: query DB as fallback

### 7.5 Notification Endpoints

```
GET  /api/v1/notifications?cursor={timestamp}&limit=30
PUT  /api/v1/notifications/{id}/read
PUT  /api/v1/notifications/read-all
GET  /api/v1/notifications/unread-count
GET  /api/v1/notifications/preferences
PUT  /api/v1/notifications/preferences  → [{ type, inAppEnabled, pushEnabled }]
```

---

## 8. AI Rules Assistant

### 8.1 Rulebook Ingestion

**Admin endpoint:** `POST /api/v1/admin/games/{id}/rulebook` (multipart PDF, auth: admin role)

**Processing (runs async via `@Async`):**
1. Extract text from PDF using **Apache PDFBox** (`pdfbox-app`)
2. Clean text: remove headers/footers, normalize whitespace
3. Split into chunks: 500 tokens with 50-token overlap (use simple word-count approximation: 500 words = ~375 tokens, use 375 words per chunk with 50-word overlap)
4. For each chunk: call OpenAI `text-embedding-3-small`, get 1536-dim vector
5. Batch insert into `game_rule_chunks`
6. On re-ingestion: DELETE existing chunks for this game first, then insert new ones (atomic via transaction)

**Track progress in Redis:** `ai:ingest:{gameId}` = `{ status: 'processing', total: 45, done: 12 }`
**Admin poll:** `GET /api/v1/admin/games/{id}/rulebook/status`

**No rulebook state:**
- `GET /api/v1/games/{id}` includes `hasRulebook: boolean` field
- If `hasRulebook = false`: AI button shows with tooltip "Rulebook not available yet"
- Clicking it shows: "No rulebook for this game yet. Want to request it?" → feedback form

### 8.2 Query Flow

**Endpoint:** `POST /api/v1/ai/rules` → { gameId, question }
- Max question length: 500 chars

**Rate limiting:**
- Redis: `INCR ai:ratelimit:{userId}:{YYYY-MM-DD}` → if > 20: HTTP 429 `{ code: "AI_RATE_LIMIT_EXCEEDED", message: "Daily limit of 20 questions reached. Resets at midnight UTC." }`
- Set TTL of the key to end of day UTC (calculate seconds until midnight)

**Cache check:**
- Normalize question: lowercase, strip extra whitespace, strip trailing punctuation
- Cache key: `ai:answer:{gameId}:{sha256(normalizedQuestion)}`
- Redis GET — if HIT: return cached answer + `{ cached: true }`

**Embedding + retrieval:**
```java
// 1. Embed the question
float[] embedding = openAiClient.embed(question);  // text-embedding-3-small

// 2. pgvector similarity search
List<String> chunks = jdbcTemplate.query("""
  SELECT content FROM game_rule_chunks
  WHERE game_id = ?
  ORDER BY embedding <=> ?::vector
  LIMIT 5
""", rowMapper, gameId, formatVector(embedding));

// 3. Build prompt
String system = """
  You are a board game rules assistant for %s.
  Answer ONLY based on the rulebook excerpts below.
  If the answer is not in the excerpts, say "I couldn't find that in the rulebook."
  Be concise and direct. Do not make up rules.
""".formatted(gameName);

String userMsg = "Rulebook excerpts:\n\n" + String.join("\n\n---\n\n", chunks)
  + "\n\nQuestion: " + question;
```

**GPT call:**
- Model: `gpt-4o-mini`
- Max tokens: 500 (answers should be concise)
- Temperature: 0.1 (factual, not creative)

**Cache result:** `SETEX ai:answer:{gameId}:{hash} 604800 {answer}` (7 days)

**Response:**
```json
{
  "answer": "Yes, you can play a Bird card during any phase of your turn...",
  "cached": false,
  "disclaimer": "This answer is AI-generated. Verify with the official rulebook for tournament play."
}
```

---

## 9. Profile & Stats

### 9.1 Stats Computation

**Games Owned:** `SELECT COUNT(*) FROM user_games WHERE user_id=? AND is_owned=true`
**Sessions:** `SELECT SUM(play_count) FROM user_games WHERE user_id=?` (total logged plays)
**Friends:** `SELECT COUNT(*) FROM follows WHERE follower_id=?` (following count) + `SELECT COUNT(*) FROM follows WHERE following_id=?` (followers count)

**Most played game:**
```sql
SELECT g.name, ug.play_count
FROM user_games ug JOIN games g ON g.id = ug.game_id
WHERE ug.user_id = ? ORDER BY ug.play_count DESC LIMIT 1
```

**Favorite category:**
```sql
SELECT unnest(g.category) AS cat, SUM(ug.play_count) AS total_plays
FROM user_games ug JOIN games g ON g.id = ug.game_id
WHERE ug.user_id = ? GROUP BY cat ORDER BY total_plays DESC LIMIT 1
```

**Most played with (friend):**
```sql
SELECT pt.tagged_user_id, u.display_name, COUNT(*) AS shared_sessions
FROM post_tags pt
JOIN posts p ON p.id = pt.post_id
JOIN users u ON u.id = pt.tagged_user_id
WHERE p.author_id = ? AND pt.tagged_user_id != ?
GROUP BY pt.tagged_user_id, u.display_name
ORDER BY shared_sessions DESC LIMIT 1
```

### 9.2 Verified Badge

- `users.is_verified BOOLEAN DEFAULT FALSE`
- Set manually by admin (no public request flow in MVP)
- Displayed on profile as a gold checkmark badge (Material Symbol `verified` filled)
- Does NOT change any permissions — purely cosmetic

### 9.3 Profile Privacy

- In MVP: all profiles are public (any authenticated user can view)
- `GET /api/v1/users/{id}` returns 404 if the viewer has been blocked by this user (prevent profile stalking)
- Future: private profiles where only followers see full stats

---

## 10. Settings

### 10.1 Settings Screen Sections

**Account:**
- Edit profile → `/settings/profile` (name, bio, location, avatar, username)
- Change email → `/settings/change-email`
- Change password → `/settings/change-password`
- BGG import → `/settings/bgg-import`
- View active sessions → `/settings/sessions`
- Delete account → `/settings/delete-account` (confirm with password)

**Notifications:**
- Per-type toggles (in-app + push separately for each type)
- Quiet hours: toggle + time range picker

**Privacy:**
- (MVP: display only, all public — settings visible but greyed out)
- Phase 2: who can follow, who can see collection, who can tag

**Appearance:**
- Theme: Light / Dark / System (MVP: Light only, others greyed out)

**App:**
- Clear cache (web: localStorage + service worker; Flutter: Hive clear)
- App version string
- Terms of Service (external link)
- Privacy Policy (external link)
- Send Feedback (mailto: link or in-app form)

---

## 11. Onboarding Flow

**Trigger:** After first-ever login (check `onboarding_completed BOOLEAN DEFAULT FALSE` on users)

**Steps:**

**Step 1 — Welcome (static, no API call)**
- Screen: "Welcome to Meeple 🎲"
- Tagline: "Track your games. Organize game nights. Build memories."
- Button: "Get Started"

**Step 2 — Profile Setup**
- Avatar upload (optional)
- Display name (required, pre-filled from registration if provided)
- Location (optional, text input)
- Skip allowed
- `PUT /api/v1/users/me` on submit

**Step 3 — BGG Import (optional)**
- "Do you have a BoardGameGeek account?"
- Text input for BGG username
- "Import Collection" button → triggers `POST /api/v1/me/bgg-import`, shows progress
- Skip allowed

**Step 4 — Find Friends**
- `GET /api/v1/users/suggestions` — shows up to 10 suggested users (by game overlap or shared BGG connections)
- Inline follow buttons
- Skip allowed

**Step 5 — Add First Game (if BGG import was skipped)**
- Library search shown inline
- Add at least one game to see the value
- Skip allowed

**Completion:**
- `PUT /api/v1/users/me` → { onboardingCompleted: true }
- Redirect to Home

**Onboarding re-entry:** If user leaves mid-onboarding and returns later, check `onboarding_completed` on app load. If false: show onboarding from Step 2 (skip Step 1).

---

## 12. Global / Cross-cutting

### 12.1 Input Validation (All Endpoints)

| Field | Rules |
|-------|-------|
| username | 3–30 chars, `^[a-zA-Z0-9_]+$`, stored lowercase |
| email | RFC 5322, max 255 chars, stored lowercase |
| password | 8–128 chars, ≥1 letter, ≥1 number |
| displayName | 1–50 chars, any Unicode |
| bio | 0–200 chars |
| post caption | 0–2000 chars |
| event title | 1–100 chars |
| event description | 0–1000 chars |
| comment | 1–500 chars |
| location text | 0–100 chars |
| question (AI) | 1–500 chars |

All validated with Spring's `@Valid` + Bean Validation annotations. Responses: HTTP 400 + `{ code: "VALIDATION_ERROR", fields: { fieldName: "message" } }`

### 12.2 Standard Error Codes

```
// Auth
AUTH_REQUIRED, INVALID_CREDENTIALS, EMAIL_NOT_VERIFIED, ACCOUNT_LOCKED,
ACCOUNT_DELETED, INVALID_TOKEN, TOKEN_EXPIRED, EMAIL_TAKEN, USERNAME_TAKEN

// Resources
USER_NOT_FOUND, GAME_NOT_FOUND, EVENT_NOT_FOUND, POST_NOT_FOUND,
COMMENT_NOT_FOUND, MATCH_REQUEST_NOT_FOUND

// Business Logic
EVENT_FULL, EVENT_CANCELLED, EVENT_COMPLETED, ALREADY_JOINED, NOT_PARTICIPANT,
NOT_HOST, HOST_CANNOT_LEAVE, BLOCKED_USER, CANNOT_FOLLOW_SELF,
CANNOT_TAG_SELF_EXPLICITLY, INVALID_STATUS_TRANSITION, MATCH_REQUEST_LIMIT,
BGG_API_ERROR, BGG_API_UNAVAILABLE, REPORT_LIMIT_EXCEEDED

// Rate Limits
RATE_LIMIT_EXCEEDED, AI_RATE_LIMIT_EXCEEDED

// AI Specific
AI_NO_RULEBOOK, AI_PROCESSING

// Generic
VALIDATION_ERROR, CONFLICT, FORBIDDEN, INTERNAL_ERROR
```

### 12.3 Deep Link URL Schema

Used consistently across web routes, FCM notification payloads, and Flutter routes:

| Content | Web Path | FCM `data.path` |
|---------|----------|-----------------|
| Home | `/` | `/` |
| Game Detail | `/library/games/{gameId}` | `/library/games/{gameId}` |
| Event Detail | `/events/{eventId}` | `/events/{eventId}` |
| Post Detail | `/posts/{postId}` | `/posts/{postId}` |
| User Profile | `/profile/{userId}` | `/profile/{userId}` |
| Create Post | `/posts/create` | `/posts/create` |
| Notifications | `/notifications` | `/notifications` |
| Match Suggestions | `/home` | `/home` |

**Flutter Universal Links:** The web paths above are the same as Flutter deep links. Requires:
- iOS: `/.well-known/apple-app-site-association` served by Spring Boot
- Android: `/.well-known/assetlinks.json` served by Spring Boot

Both are static JSON files served by Spring Boot at the well-known paths.

### 12.4 Image URL Standards

| Type | R2 Key | Public URL |
|------|--------|------------|
| Avatar | `avatars/{userId}/avatar.webp` | `https://cdn.meeple-hearth.com/avatars/{userId}/avatar.webp` |
| Post image | `posts/{postId}/{index}.webp` | `https://cdn.meeple-hearth.com/posts/{postId}/0.webp` |
| Temp upload | `posts/temp/{uuid}.webp` | (not served publicly) |
| Game cover | `games/{bggId}/cover.jpg` | `https://cdn.meeple-hearth.com/games/{bggId}/cover.jpg` |

Avatar change: generate new filename with timestamp to bust cache: `avatar-{timestamp}.webp`

### 12.5 Offline Behavior

**Web (SvelteKit):**
- No offline mode in Phase 1
- On network error: show inline "Can't connect" banner with Retry button
- No service worker / cache in MVP

**Flutter (Phase 3):**
- Read-only offline mode: cached collection, events, and feed visible
- Write actions blocked with: "You're offline. This will sync when you reconnect."
- Offline detection: `connectivity_plus` package
- Cache: Hive local DB stores last-fetched data per screen

### 12.6 API Rate Limiting (Global)

All authenticated endpoints: max 200 req/min per user (Redis token bucket)
All unauthenticated endpoints: max 20 req/min per IP
Login endpoint: 10 req/min per IP (stricter)
BGG proxy: 2 req/sec globally (semaphore in BggApiClient)

Implement with **Bucket4j** library in Spring Boot:
```java
@Bean
public RateLimiter apiRateLimiter() {
  BandwidthLimit limit = BandwidthLimit.classic(200, Refill.intervally(200, Duration.ofMinutes(1)));
  return Bucket4j.builder().addLimit(limit).build();
}
```

### 12.7 Accessibility (WCAG 2.1 AA Targets)

**Contrast ratios (verified):**
- `primary` (#895100) on `background` (#F8F9FA): ~5.8:1 ✅ (passes AA for normal + large text)
- `on-surface-variant` (#544434) on `surface` (#F8F9FA): ~4.9:1 ✅ (passes AA for normal text)
- `secondary-container` (#FDBD68) background with `on-secondary-container` (#764B00) text: ~5.2:1 ✅

**Implementation requirements:**
- All icon-only buttons: `aria-label` attribute
- All images: meaningful `alt` text (game name for game covers, "Post by [name]" for post images)
- Interactive touch targets: minimum 44×44px
- Focus management: when modal opens, focus moves to first element; when modal closes, focus returns to trigger
- Color independence: ownership status is NOT conveyed by color alone — also use an icon
- Keyboard navigation: all actions accessible without mouse (Tab, Enter, Space, Escape for modals)
