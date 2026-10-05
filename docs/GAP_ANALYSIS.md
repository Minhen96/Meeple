# Meeple gap analysis: docs vs. implementation (read-only)

Snapshot: branch `claude/repo-review-bw2kq3` at HEAD `f7d4ec0`. The latest migration is V34. All paths below are relative to `/home/user/Meeple`.

## 0. Headline findings

1. **What is genuinely complete:**
   - Auth: email, Google on web, refresh rotation, lockout.
   - Friend requests and blocks.
   - Matching: scheduler, 48h expiry, friends-only and block-aware.
   - The AI stack (RAG, conversation mode, rulebook pipeline, how-to-play, smart search, recommended sort).
   - Basic events, posts, collection and play-log CRUD.
   - WebSocket per-user notifications on web and mobile.
2. **Push is a stub.** `backend/.../notification/service/FcmService.java` is an empty class with a "Phase 2" comment. There is no `firebase-admin` dependency. There is no FCM token endpoint, even though the `user_fcm_tokens` table exists from V1. Nothing on web uses FCM. On mobile, `main.dart` imports `firebase_options.dart`, which does not exist, and the `android/` and `ios/` folders are missing, so the app cannot build.
3. **No i18n anywhere** (no web, mobile or backend setup), even though English + zh-CN is a locked decision (FEATURES_COMPLETE §0) and Phase 2 in CLAUDE.md.
4. **The notifications domain is minimal.** It has no title/body/data (V13 dropped them), no preferences, no quiet hours, no per-item read or delete, no presence, no Redis unread counter, and offset pagination.
5. **Events lack** invites, a participant list, cancel, kick, the reminder job, the auto-complete job, past events, a monthly calendar, and the community tab.
6. **Feed and posts lack** activity items, cursor pagination, play-count increment from tags, edit, comment delete/edit, mentions, bookmarks, reports, tag-friends validation and the tag notification.
7. **Account lacks** password-confirmed deletion, reactivation, the hard-delete job, export, change-email, active sessions, profile stats, block-404 on profiles, and a blocked-users list.
8. **`is_wishlisted` was dropped by V22** (commit `d8ecbb1`, no rationale given). This contradicts CLAUDE.md "Database" and FEATURES §0 (locked) and §3.1. The mobile model still has `isWishlisted`; the web has no Wishlist tab.
9. **Infra gaps:** no Sentry or PostHog on backend or web (mobile declares both, PostHog is not initialised), no global rate limiting, no `@Cacheable`/Spring Cache, no JSON logging, no `.well-known` files, no Flutter CI job.
10. **Three items need an owner decision before work starts** (detail in §4):
    - Restore wishlist (C4).
    - Pagination: cursor vs. offset (C6).
    - Notification schema (C7).

## 1. Phase-model conflicts (CLAUDE.md vs. PLAN.md §6)

| Item | CLAUDE.md | PLAN.md §6 | Other docs | Status |
|---|---|---|---|---|
| Calendar view | (Events, P1) | P1 wk3 | SCREENS §6.3 monthly grid | Missing: only a 7-day strip in `frontend/src/routes/(app)/events/+page.svelte` lines 22–74 |
| Profile page stats | P1 | P1 wk4 | FEATURES §9.1 | Partial: sessions summed client-side; no stats API |
| Friends / social graph | P2 "friend requests" | P2 wk5 "Follow system" | FEATURES §2.1 locks friend_requests | Backend done; web has no incoming-requests inbox |
| Social feed of friends' activities | P2 (implied) | P2 wk5 | FEATURES §5.1 / §5.5 | Posts only; no `activity_events` |
| Notification centre | P2 | P2 wk6 | SCREENS §9, FEATURES §7 | Partial |
| FCM push | **P2** | **P3** wk8 | TECH_STACK §7, FEATURES §7.3 | Stub |
| i18n | **P2** | absent | FEATURES §0 locked; ENGINEERING_STANDARDS §7 | Missing |
| Matching | P2 | P2 wk7 | FEATURES §6 | Mostly done |
| AI assistant | P3 | P3 wk8 | AI_PLAN | Done on web; missing on mobile |
| Search, infinite scroll, Redis caching, onboarding | not listed | P3 wk9–10 | SCREENS §4.6, §13, §3; ENGINEERING_STANDARDS §6 | Partial |
| Flutter | **P3** | **P4** | MOBILE_FLUTTER | Skeleton; most screens are stubs |
| Stories, DMs, leaderboards | P4 | absent | Only DMs appear, in SCREENS §8.2 ("Message" button, *Phase 2 — DMs*) | Not started; **no spec exists**, so do not build |

CLAUDE.md says "Phase 1 (current)". In practice Phase 2 and Phase 3 work (matching, AI) has already shipped, so the "do not skip ahead" rule is stale and the orchestrator should restate the current phase.

## 2. Gap list

Labels: `P_C` = CLAUDE.md phase, `P_P` = PLAN.md phase. Sizes: S < ½ day, M 1–3 days, L > 3 days. "BE" = backend.

### Phase 1 (CLAUDE.md) gaps

| # | P_C / P_P | Area | Doc says | Exists now | Size |
|---|---|---|---|---|---|
| 1.1 | P1 / P1 | BE + DB | `user_games.is_wishlisted` (CLAUDE.md DB rules; FEATURES §0, §3.1). All-false row is invalid, so delete it instead (§3.1). | V22 drops the column. `game/entity/UserGame.java` and `game/dto/UserGameRequest.java` have no wishlist field. `GameService.updateCollection` can leave an all-false row. | M |
| 1.2 | P1 / P1 | Web | Library tabs: All / My Collection / **Wishlist** / Favorites (PLAN §3.2; SCREENS §5.1, §5.3). | `routes/(app)/library/+page.svelte` has no wishlist tab. | S |
| 1.3 | P1 / P1 | BE + Web | Monthly calendar; tapping a day opens a bottom sheet with that day's events (PLAN §3.3; SCREENS §6.3). Needs a range query. | 7-day strip only. No `from`/`to` endpoint. | M |
| 1.4 | P1 / P1 | BE | Past events list (PLAN §5 `GET /events?status=past`; SCREENS §6.2). | `EventController.getEvents` returns upcoming only; `/events/me` returns accepted only. | S |
| 1.5 | P1 / P1 | BE + Web | Invite friends at creation (`invitedUserIds`, mutual friends only, no self-invite), plus an `event_invite` notification for each (FEATURES §4.1; SCREENS §6.5 item 6). | `event/dto/CreateEventRequest.java` has no `invitedUserIds`. `EVENT_INVITE` is never sent. | M |
| 1.6 | P1 / P1 | BE + Web | Event detail DTO includes a `participants[]` list, `isHost` and `reminderSent` (FEATURES §4.6). | `event/dto/EventResponse.java` has counts only. The web shows a "participants placeholder" at `events/[eventId]/+page.svelte:228`. | S |
| 1.7 | P1 / P1 | BE + Web | Cancel: `POST /events/{id}/cancel`, which notifies accepted participants. Kick: `DELETE /events/{id}/participants/{userId}`, status `KICKED`. Leave becomes state `LEFT` instead of deleting the row (FEATURES §4.2, §4.4). Host "Manage" dropdown (SCREENS §6.4). | Only soft-delete (`DELETE /events/{id}`) exists, with no notifications. Leave deletes the row. The participant CHECK constraint (V30) allows only `INVITED`/`ACCEPTED`/`DECLINED`. | M |
| 1.8 | P1 / P1 | BE | Update rules (FEATURES §4.4): `event_updated` notification when time changes; cannot reduce max below accepted count; cannot change game after completion. Validation: max 2–50; `scheduledAt` ≥ now − 5 min; title 1–100; location ≤ 100. | None of the update rules are enforced. `CreateEventRequest` uses title 3–255, location 255 and `@Future`. | S |
| 1.9 | P1 / P2 | BE | Jobs: `event_auto_complete` every 30 min (plus `event_completed` notification) and `event_reminder` hourly (plus `reminder_sent` column), both with Redis locks (FEATURES §4.4–4.5; TECH_STACK_ADDITIONS §21). | Missing. | M |
| 1.10 | P1 / – | BE + Web | Community tab: `GET /events/community`. Public events show `location_display` until the viewer joins (ENGINEERING_STANDARDS §10). FRIENDS-visibility events still require an invite to join. | Missing. `EventService.rsvp` lets anyone who can see the event accept, including FRIENDS events. | M |
| 1.11 | P1 / P1 | BE | Post creation (FEATURES §5.2): tagged users must be friends; tags from users who blocked the author are silently dropped; `play_count` incremented for tagged users + game; `post_tag` notification; `activity_events` row; `eventId` honoured. | `PostService.createPost` (lines 104–147) tags any user, increments nothing, sends nothing, and ignores `req.eventId()`. | M |
| 1.12 | P1 / P1 | BE + Web | Post edit `PUT /posts/{id}` within 48h, with `edited_at` (FEATURES §5.4). Comment edit `PUT` within 24h and delete `DELETE /posts/{id}/comments/{cid}` (FEATURES §5.7; PLAN §5). `@mention` notifications. | Missing (PostController has only GET/POST comments). | M |
| 1.13 | P1 / P1 | Web | Images optional on posts; client-side compression to WebP, max 1 MB / 1200px (FEATURES §0; TECH_STACK_ADDITIONS §18); per-image progress; "Discard this post?" guard (SCREENS §7.1). | `posts/create/+page.svelte:92` requires an image. No compression code anywhere in web (grep `compress\|webp\|canvas` finds nothing). | M |
| 1.14 | P1 / P1 | BE + Web | Bookmarks: `POST`/`DELETE /posts/{id}/bookmark`, `GET /users/me/bookmarks` (FEATURES §5.8). Share via `navigator.share` with clipboard fallback (§5.9). | Missing. The share icon is decorative (`PostCard.svelte:146`). | S |
| 1.15 | P1 / P1 | BE + Web | Profile stats bento (owned, sessions, friends) plus most-played game, favourite category, most-played-with (PLAN §3.6; FEATURES §9.1). Tabs Posts / Tagged / Collection (SCREENS §8.1). | No stats endpoint. `profile/+page.svelte:18` sums play counts on the client. No Tagged tab. | M |
| 1.16 | P1 / P1 | BE | `GET /users/{id}` returns 404 if blocked either way (FEATURES §2.2, §9.3). `/users/{id}/games` and `/users/{id}/plays` enforce privacy and blocks. | `UserService.getUser` has no block check. `GameController:143-155` comments "friends only, enforced by frontend". | S |
| 1.17 | P1 / P1 | BE + Web | Account deletion (FEATURES §1.6; SCREENS §11.5): `DELETE /users/me` requires `{password}`; confirmation email; collection, match requests and notifications deleted immediately; "Deleted User" rendering; `POST /auth/reactivate`; login returns code `ACCOUNT_DELETED` inside the 30-day grace; hard-delete job at 3am; `GET /users/me/export`. | `UserService.deleteMe` only sets `deleted_at` and revokes sessions. The web asks the user to type "DELETE" and the copy says "permanent". Login throws a generic 401 (`AuthService:189-191`). No reactivate, no job, no export. | L |
| 1.18 | P1 / P1 | BE + Web | Settings (FEATURES §10.1; SCREENS §11): change email (`POST /users/me/change-email`), active sessions list and revoke, username change once per 30 days, bio limit 200, About section, Privacy and Theme greyed out. | Missing (there is a password page). `UpdateProfileRequest` has bio 300 and displayName min 2; no username change. | M |
| 1.19 | P1 / P1 | BE | `users` columns: `bgg_username`, `is_verified`, `username_changed_at`, `quiet_hours_*`, `preferred_language` (FEATURES §1.7; ENGINEERING_STANDARDS §7). | None exist (`user/entity/User.java`). | S |
| 1.20 | P1 / P1 | BE + Web | Google OAuth (CLAUDE P1). | Web done (`GoogleButton.svelte`, `/auth/google`). Mobile is a "coming soon" snackbar (`login_screen.dart:318`). | M (mobile) |
| 1.21 | P1 / P1 | BE | Hard-coded dev path in `GameController.runImport`: `"c:\\Users\\Minhen\\..."` (line 41). Violates ENGINEERING_STANDARDS. | Admin-only, but broken outside one dev machine. | S |

### Phase 2 (CLAUDE.md) gaps

| # | P_C / P_P | Area | Doc says | Exists now | Size |
|---|---|---|---|---|---|
| 2.1 | P2 / P3 | BE | FCM (FEATURES §7.3; TECH_STACK §7; ENGINEERING_STANDARDS §2):<br>• Firebase Admin, `@Async("notificationExecutor")`, Resilience4j `fcm` breaker<br>• push only when offline, preferences allow, and outside quiet hours<br>• delete stale tokens<br>• `user_fcm_tokens` register/unregister<br>• `is_pushed` flag | `FcmService` is an empty class. No dependency, no `fcm` circuit-breaker config in `application.yml` (only `bgg` and `openai`), no endpoints. | L |
| 2.2 | P2 / P3 | BE | Presence (TECH_STACK §6): `ws:online:{userId}` with 30s TTL, refreshed on heartbeat, deleted on disconnect. | Missing. | S |
| 2.3 | P2 / P2 | BE | Notification schema (FEATURES §7.1): title, body, `data.path`, sender, `is_pushed`. Plus `notification_preferences` (in-app/push per type) and quiet hours. | V13 dropped title/body/data. Entity has `actorId`/`referenceId`/`referenceType`. No preferences table. | M |
| 2.4 | P2 / P2 | BE | Endpoints (FEATURES §7.5):<br>• `PUT /notifications/{id}/read`<br>• `GET /notifications?cursor&limit`<br>• `GET`/`PUT /notifications/preferences`<br>• Redis unread counter included in the WS payload<br>• swipe delete (SCREENS §9) | Only list (page/size), unread-count and read-all exist. | M |
| 2.5 | P2 / P2 | BE | All notification types in FEATURES §7.2: event leave, kicked, cancelled, updated, reminder, completed; comment_mention; post_tag; match accepted. AI_PLAN §3: `RULEBOOK_APPROVED`, `RULEBOOK_REJECTED`, `RULEBOOK_UNDER_REVIEW`. Like batching, one per post per hour (FEATURES §5.6). | Enum has 9 values (`Notification.java`). No like batching. | M |
| 2.6 | P2 / P2 | Web | Notification centre (SCREENS §9): grouped Today / This Week / Earlier; tap marks read and navigates; per-item read and delete; actor avatar/name; infinite scroll. | `notifications/+page.svelte` (157 lines): flat list, mark-all only, no actor names (the DTO has only `actorId`). | M |
| 2.7 | P2 / P2 | Web | Notification preferences table plus quiet hours (SCREENS §11.3). | `settings/notifications/+page.svelte` is a "Coming soon" stub. | M |
| 2.8 | P2 / P3 | Web | Web push via Firebase JS SDK and a `firebase-messaging-sw.js` service worker. TECH_STACK §7 says this is optional. | Missing. | M |
| 2.9 | P2 / P2 | BE + Web | Feed is a union of posts and activity items (`collection_add`, `event_created`, `event_joined`), friends + self, cursor pagination, 1-min Redis cache (FEATURES §5.1, §5.5). | `PostService.getFeed` returns posts from friends + self with page/size. No `activity_events` table. | L |
| 2.10 | P2 / P3 | Web | Home feed (SCREENS §4.3–4.6):<br>• infinite scroll at 80% depth, "Loading more…", "You're all caught up!"<br>• three distinct empty states plus an error state<br>• greeting "next session in X days"<br>• "View Calendar" link<br>• "+N more" chip for multiple match cards | `routes/(app)/+page.ts` loads one page of 20. Single empty state; subtitle counts events instead. | M |
| 2.11 | P2 / P2 | Web | Friend-request inbox (received/sent, accept/decline). SCREENS §8.3 friends list. Block/Report in the profile "···" menu (§8.2). | `friendsApi.getReceived`, `getSent` and `decline` exist in `lib/api/friends.ts` but nothing calls them. No block/report UI in `profile/[userId]`. | M |
| 2.12 | P2 / P2 | BE | Social rules (FEATURES §2.1–2.4):<br>• 7-day re-request cooldown after decline<br>• max 50 pending outgoing<br>• `GET /users/me/blocked`<br>• `friendshipStatus` on search results<br>• blocked users excluded from search<br>• suggestions ranked by game overlap, excluding pending<br>• `POST /reports` (5/day) plus `reports` table | Suggestions sorted by `createdAt` (`UserRepository:38-45`). Cooldown, 50-cap, blocked list, `friendshipStatus` and reports are all missing. | M |
| 2.13 | P2 / – | All | i18n en + zh-CN (FEATURES §0; ENGINEERING_STANDARDS §7):<br>• Paraglide on web, error-code → localised message map, language switcher, browser-language detection<br>• `users.preferred_language` column<br>• Flutter ARB files (`flutter_localizations` is declared in pubspec but unused) | Nothing implemented. | L |
| 2.14 | P2 / – | BE | Matching contract drift: doc `GET /matches/requests/mine`, implementation `/requests/me`. `match_request_expire` hourly job (TECH_STACK_ADDITIONS §21). | Group expiry exists; request expiry is unclear (done only inside the matching run). | S |
| 2.15 | P2 / – | BE | WS destination `/topic/events/{eventId}` for live participant updates (PLAN §5). | Only `/user/queue/notifications` and `/topic/how-to-play/{gameId}`. | S |

### Phase 3 (CLAUDE.md: AI + Flutter); PLAN Phase 3 polish items also listed here

| # | P_C / P_P | Area | Doc says | Exists now | Size |
|---|---|---|---|---|---|
| 3.1 | P3 / P3 | BE + Web | AI conversation mode, last 3 Q&A pairs (CLAUDE.md; ENGINEERING_STANDARDS §11). | **Done:** `AiQueryRequest.conversationHistory @Size(max=3)`, `AiService.buildMessages`, `AiAssistantDrawer.svelte` with localStorage. Minor drift: doc uses `{role, content}` messages, implementation uses `{question, answer}` pairs; keep the implementation. | – |
| 3.2 | P3 / P3 | Mobile | AI Rules Assistant sheet (SCREENS §12). | Absent from mobile (no `ai/rules` constant or feature). | M |
| 3.3 | P3 / P3 | BE + Web | BGG collection import (FEATURES §3.2; SCREENS §3.4):<br>• `POST /me/bgg-import` with progress in Redis `bgg:import:{userId}`<br>• `GET .../status` polled every 2s<br>• result `{imported, skipped, failed}`<br>• 202 retry ×10, then 503 `BGG_API_UNAVAILABLE`<br>• save `bgg_username` | Missing:<br>• `settings/bgg/+page.svelte` runs a game-name search and says "Phase 2"<br>• `onboarding/bgg-import/+page.svelte` is a static stub<br>• `BggApiClient` notes xmlapi2 now needs Bearer auth, and `search()` returns an empty list | L |
| 3.4 | P3 / P1 | BE + Web | Play logging and stats: play log with `playedAt`, players and notes; delete a play; per-game and overall stats. Posts with a game record plays (FEATURES §5.2 step 4). | `POST .../log-play` increments by 1 with no body; no delete. `log-play/+page.svelte` exists. Not linked to posts. | M |
| 3.5 | P3 / P1 | BE + Web | Game detail (SCREENS §5.4):<br>• "Owned by X friends" avatar stack<br>• tabs Overview / Reviews (friends' ratings and notes) / Sessions (posts tagged with the game) / Friends<br>• friend average rating (FEATURES §3.3)<br>• `GET /games/{id}/sessions` (PLAN §5) | Current tabs are Overview / My Stats / Details (plus How-to-Play). No friend data or sessions endpoint. | M |
| 3.6 | – / P3 | BE | Redis caching (ENGINEERING_STANDARDS §6; TECH_STACK §4): game detail 7d, user profile 10m, unread count 5m, event detail 5m, collection 10m, feed 1m; `spring.cache.type=redis`. | Only ad-hoc keys (AI answers, recommendations). No `@EnableCaching` or `@Cacheable`. | M |
| 3.7 | – / P3 | Web | Search overlay (SCREENS §13): games + players + events, recent searches, 400ms debounce. Needs a unified search endpoint. | The search icon goes to `/people` (`AppBar.svelte:47`). | M |
| 3.8 | – / P3 | Web | Onboarding (SCREENS §3; FEATURES §11):<br>• step dots and Skip<br>• avatar upload with crop<br>• live BGG import<br>• find-friends list (suggestions + search + inline Add Friend)<br>• add-game search, grid and quick-add, with trending results when empty<br>• re-entry at step 2 | `find-friends` is "coming soon"; `add-game` has an unwired input; `bgg-import` is static. | M |
| 3.9 | – / P3 | Web | Global components (SCREENS §14): offline banner, pull-to-refresh, shimmer skeletons, bottom-sheet confirmations, FAB create sheet (PLAN §3.8), per-tab scroll memory (§15.4), deep-link logical back (§15.1). | Partial (`Skeleton`, `ConfirmDialog` exist); no offline banner or pull-to-refresh. Verify the FAB sheet. | M |
| 3.10 | P3 / P4 | Mobile | Platform scaffolding: `android/` and `ios/` directories, `lib/firebase_options.dart` (imported by `main.dart`, absent), `.well-known` assetlinks / apple-app-site-association (FEATURES §12.3). | Missing, so the app cannot compile or run. | M |
| 3.11 | P3 / P4 | Mobile | Stub screens, each labelled "Phase 1/2 stub" in its own source: home feed, library, events (create button `onPressed: () {}`), notifications, search, settings, own profile, post detail. Missing entirely: user profile, friends/requests, matching, AI, edit profile, notification prefs, sessions, delete account, BGG import, calendar (`table_calendar` declared but unused). | – | L |
| 3.12 | P3 / P4 | Mobile | FCM (MOBILE_FLUTTER §8): permission pre-prompt, `getToken`/`onTokenRefresh` → backend register, foreground local notifications, Android channels, deep-link on open (§5). | Only a background handler. `secure_storage.saveFcmToken` exists but is never called. | M |
| 3.13 | P3 / P4 | Mobile | Google sign-in, event visibility picker (the repository already supports `visibility`), biometric auth (§12), offline write guard (§11), Isar caching per screen (§6), PostHog init. | Missing. Sentry init exists, gated on `SENTRY_DSN`. | M |
| 3.14 | P3 / P4 | Mobile | Contract fixes: `user_game_model.dart` and `collection_repository.dart` use `isWishlisted` / filter `wishlisted`; the backend accepts only `owned` / `favorited` / `all`. | Will drift unless the wishlist decision is applied. | S |

### Phase 4 (CLAUDE.md only)

| # | Item | Notes |
|---|---|---|
| 4.1 | Stories, DMs, leaderboards | No schema, API or screens are specified in any doc. SCREENS §8.2 marks DMs as "Phase 2". **Recommendation: spec first, out of scope for this round.** Size: L each. |

### Cross-cutting infra (TECH_STACK / TECH_STACK_ADDITIONS / ENGINEERING_STANDARDS)

| # | Area | Doc | Exists | Size |
|---|---|---|---|---|
| I.1 | Backend Sentry (`sentry-spring-boot-starter-jakarta`, no PII) | TECH_STACK_ADDITIONS §15 | Missing from `backend/build.gradle.kts` | S |
| I.2 | Web Sentry (`@sentry/sveltekit`, `setUser` on login, cleared on logout) | §15 | Missing | S |
| I.3 | PostHog on web (`posthog-js`, identify) | §16 | Missing (mobile declares the dependency but never initialises it) | S |
| I.4 | Global rate limits: 200/min per user, 20/min per IP unauthenticated, 10/min on login | FEATURES §12.6 | Only auth, email and AI limits via `common/ratelimit/RedisRateLimiter`. No servlet filter. | M |
| I.5 | JSON logging (logstash encoder, prod profile); mask FCM tokens | TECH_STACK_ADDITIONS §22 | Missing | S |
| I.6 | Background-job lock pattern for every job | §21 | `MatchScheduler` complies. The new jobs (events, notifications cleanup, hard delete, image cleanup, BGG refresh) do not exist yet. | – |
| I.7 | `post_image_cleanup` and `notification_cleanup` (90-day) jobs | §21; FEATURES §5.3 | Missing | S |
| I.8 | Flutter CI (analyze + test) | TECH_STACK_ADDITIONS §17 | `.github/workflows/ci.yml` covers backend and frontend only | S |
| I.9 | Graceful shutdown; `ddl-auto=validate` in prod | ENGINEERING_STANDARDS §12 | Verify in `application-prod.yml` | S |
| I.10 | Email provider: Resend | TECH_STACK_ADDITIONS §14 | Uses Spring Mail (`JavaMailSender`). Works with Resend SMTP. No templates for deletion or change-email. | S |

## 3. Requires external accounts or secrets (can be coded, cannot be verified here)

- **Firebase:**
  - Backend: `FIREBASE_SERVICE_ACCOUNT_JSON` (TECH_STACK_ADDITIONS §24).
  - Web: `VITE_FIREBASE_*` config plus a VAPID key.
  - Mobile: `google-services.json`, `GoogleService-Info.plist`, and `firebase_options.dart` generated by `flutterfire configure`; APNs key.
  - Build FCM behind a no-op when credentials are absent, and test with a mocked sender.
- **Google OAuth on mobile:** iOS/Android OAuth client IDs, the `google_sign_in` package (not in pubspec), SHA-1 fingerprints. The backend already verifies ID tokens (`GoogleAuthService`); its `audience` must include the mobile client IDs.
- **Sentry:** `SENTRY_DSN` and `VITE_SENTRY_DSN`. **PostHog:** `VITE_POSTHOG_KEY`, plus the mobile key.
- **BGG:** collection import needs `xmlapi2/collection`, which now requires a registered BGG application token (`BggApiClient` javadoc lines 20–27). New secret `BGG_API_TOKEN`. Without it, return 503 `BGG_API_UNAVAILABLE`.
- **Apple / Android deep links:** team ID and signing SHA-256 for the `.well-known` files.
- **Resend/SMTP** credentials for the new emails.

## 4. Doc conflicts and decisions needed

| ID | Conflict | Recommendation |
|---|---|---|
| C1 | Phase ordering, CLAUDE.md vs. PLAN.md (§1 above). | Treat CLAUDE.md as authoritative for phase. Update CLAUDE.md "current phase". |
| C2 | Follow model. PLAN §3.6/§4/§5 and FEATURES §3.3, §6.2 and §9.1 SQL use `follows`; SCREENS §3.5/§8.2 say "Follow". | Locked decision is friend_requests (FEATURES §0, §2.1). Use friends queries and the "Add Friend / Pending / Friends" wording. |
| C3 | FCM token storage. TECH_STACK §7 says `users.fcm_token` via `PUT /api/me`. FEATURES §1.4 says the `user_fcm_tokens` table (already in V1). | Use the table and a dedicated endpoint. |
| C4 | Wishlist. CLAUDE.md and FEATURES §0 (locked) require `is_wishlisted`; V22 dropped it. | **Owner confirmation needed.** Default: restore it (the locked decision wins), in WP4 migration V50. |
| C5 | Collection API paths. FEATURES §3.1 has `/api/v1/me/games` with POST/PATCH; the implementation has `/api/v1/users/me/games` with PUT. BGG import doc path is `/api/v1/me/bgg-import`. | Keep the `/users/me/...` family; put BGG import at `/api/v1/users/me/bgg-import`. |
| C6 | Pagination. FEATURES §0 locks cursor pagination for all feeds/lists; the implementation uses page/size everywhere. ENGINEERING_STANDARDS §10 uses `page=`. | Cursor for feed, notifications and bookmarks (live lists). Keep offset elsewhere. Owner sign-off. |
| C7 | Notification schema. FEATURES §7.1 has title/body/data JSONB; V13 replaced these with actor/reference. Type names: doc lowercase (`post_liked`, `new_follower`); implementation uppercase enum (`POST_LIKE`, `FRIEND_REQUEST`). | Keep actor/reference and the uppercase enum. Add `title`, `body`, `data jsonb` (with `path`), `is_pushed`, computed server-side by one factory. `new_follower` maps to `FRIEND_REQUEST`/`FRIEND_ACCEPTED`. |
| C8 | Deep links. FEATURES §12.3 uses `/library/games/{id}`; web uses `/library/[gameId]`; mobile uses `/library/:gameId`. | Standardise on `/library/{gameId}` and fix the doc. |
| C9 | Event join. FEATURES §4.2 says no uninvited join in MVP; ENGINEERING_STANDARDS §10 says PUBLIC events are open-join and FRIENDS events still need an invite. | Follow ENGINEERING_STANDARDS §10 (newer, matches the locked visibility decision). The implementation currently allows FRIENDS-visible events to be joined without an invite; fix this. |
| C10 | AI without a rulebook. FEATURES §8.1 and SCREENS §12 disable the assistant ("Request Rulebook"); AI_PLAN §5 answers in "general" mode. | Keep the AI_PLAN behaviour (implemented); update SCREENS. |
| C11 | Account deletion requires `{password}` (FEATURES §1.6), but Google-only users have no password (V1 `password_hash` nullable). | Accept a password **or** a fresh Google ID token **or** typed "DELETE" for passwordless accounts. Needs owner sign-off. |
| C12 | Validation limits (FEATURES §12.1) vs. code: bio 200 vs. 300; displayName 1–50 vs. 2–50; event title 1–100 vs. 3–255; location 100 vs. 255. | Align to FEATURES (migrations not required; DTO only). |
| C13 | Matching path: `/requests/mine` (doc) vs. `/requests/me` (code). | Keep `/me` and fix the doc. |
| C14 | "Rate limiting with Bucket4j" (FEATURES §12.6). | Reuse the existing `RedisRateLimiter`; do not add Bucket4j. |
| C15 | BGG "XML API2 only" (FEATURES §0) vs. the implementation using the `api.geekdo.com` JSON API (xmlapi2 now requires auth). | Collection import needs xmlapi2 with a token (see §3). |
| C16 | PLAN §6 Phase 4 says Flutter is post-launch; CLAUDE.md says Phase 3; MOBILE_FLUTTER says Phase 3. | Use Phase 3. |
| C17 | CLAUDE.md AI section says the RAG source is a `game_rules` table; PLAN uses `game_rule_chunks`; the implementation uses `RuleChunk` (V10 `game_rules`, V24+ rulebooks). | Doc-only drift. No action. |

## 5. Work breakdown

### Step 0: bootstrap (one agent, sequential, merge first, size S)

This step exists so the parallel packages never touch the same file.

1. **`backend/build.gradle.kts`:** add
   - `com.google.firebase:firebase-admin:9.x`
   - `io.sentry:sentry-spring-boot-starter-jakarta:7.x`
   - `net.logstash.logback:logstash-logback-encoder:7.x`
   - `org.springframework.boot:spring-boot-starter-cache`
2. **`application.yml`:**
   - `resilience4j.circuitbreaker.instances.fcm`
   - `app.fcm.service-account-json: ${FIREBASE_SERVICE_ACCOUNT_JSON:}`
   - `app.bgg.api-token: ${BGG_API_TOKEN:}`
   - `sentry.*` (empty-safe)
   - `spring.cache.type: redis`
   - `spring.flyway.out-of-order: true` in `application-local.yml` and `application-staging.yml` only. Packages merge in any order, so V50 may land before V36. Prod requires in-order merge or a one-time out-of-order deploy.
3. **`notification/entity/Notification.java`:** add every enum value listed in §6.4. This is the only edit to that file before WP1 takes ownership.
4. **New `common/event/` records** (Spring `ApplicationEvent` payloads):
   - `ActivityRecordedEvent(UUID userId, String type, Map<String,Object> data, Instant at)`
   - `SessionPlayedEvent(List<UUID> userIds, UUID gameId, Instant playedAt, UUID postId)`
   - `UserSoftDeletedEvent(UUID userId)`
   - `UserHardDeletedEvent(UUID userId)`
5. **New `common/job/JobLock.java`:** helper `runWithLock(String name, Duration ttl, Runnable)` using `setIfAbsent` + `finally delete`.
6. **Migration `V35__users_profile_columns.sql`** and `User.java` fields: `bgg_username VARCHAR(50)`, `is_verified BOOLEAN DEFAULT FALSE`, `username_changed_at TIMESTAMPTZ`, `preferred_language VARCHAR(10) DEFAULT 'en'`, `timezone VARCHAR(50)`.
7. **Frontend types:**
   - Turn `frontend/src/lib/types/index.ts` into a barrel that re-exports `./notifications`, `./events`, `./social`, `./library`, `./account`.
   - Move existing types into those files.
   - Each package edits only its own file afterwards.
8. **Frontend i18n scaffold:**
   - Paraglide setup with `src/lib/i18n/index.ts`.
   - Messages split by namespace prefix: each package owns keys `notif.*`, `event.*`, `social.*`, `library.*`, `account.*`.
   - To avoid conflicts on the single `messages/en.json`, use the inlang multi-file pattern `messages/{locale}/{namespace}.json`. If Paraglide cannot do this, use per-namespace TS dictionaries in `src/lib/i18n/{ns}.ts` behind the same `m()` API.
   - Add `src/lib/i18n/errors.ts`.
9. **Root `frontend/src/routes/+layout.svelte` and `hooks.client.ts`:** Sentry and PostHog init (env-gated), plus mount points for an OfflineBanner component (owned by WP5).

### Package and directory ownership

| WP | Backend dirs (`backend/src/main/java/com/meeplehearth/...`) | Web dirs (`frontend/src/...`) | Mobile | Migrations |
|---|---|---|---|---|
| WP1 Notifications & Push | `notification/**` | `routes/(app)/notifications/**`, `routes/(app)/settings/notifications/**`, `lib/api/notifications.ts`, `lib/stores/notifications.ts`, `lib/stores/websocket.ts`, `lib/types/notifications.ts`, new `lib/push/**`, `static/firebase-messaging-sw.js` | – | V36–V39 |
| WP2 Events & Matching | `event/**`, `match/**` | `routes/(app)/events/**`, `routes/(app)/match/**`, `lib/api/events.ts`, `lib/api/matches.ts`, `lib/components/match/**`, new `lib/components/event/**`, `lib/types/events.ts` | – | V40–V44 |
| WP3 Social, Feed & Posts | `post/**`, `social/**`, new `feed/**`, new `search/**`, new `report/**` | `routes/(app)/+page.svelte`, `routes/(app)/+page.ts`, `routes/(app)/posts/**`, `routes/(app)/people/**`, `routes/(app)/profile/friends/**`, new `routes/(app)/search/**`, `lib/components/social/**`, `lib/api/posts.ts`, `lib/api/friends.ts`, `lib/api/upload.ts`, `lib/stores/peopleSearch.ts`, `lib/types/social.ts`, new `lib/utils/image.ts` | – | V45–V49 |
| WP4 Library, Collection, Plays, BGG & AI | `game/**`, `ai/**` | `routes/(app)/library/**`, `routes/(app)/log-play/**`, `routes/(app)/settings/bgg/**`, `routes/onboarding/bgg-import/**`, `routes/onboarding/add-game/**`, `lib/api/games.ts`, `ai.ts`, `howtoplay.ts`, `rulebook.ts`, `ruleNotes.ts`, `lib/components/game/**`, `lib/stores/library.ts`, `lib/types/library.ts`, `routes/(app)/admin/**` | – | V50–V54 |
| WP5 Account, Profile, Settings, Onboarding & Infra | `auth/**`, `user/**`, `config/**`, `common/**` (except the Step 0 files), `storage/**`, `resources/static/.well-known/**`, `resources/logback-spring.xml` | `routes/auth/**`, `routes/onboarding/{welcome,profile,find-friends}/**`, `routes/onboarding/+layout.svelte`, `routes/(app)/profile/+page.*`, `routes/(app)/profile/[userId]/**`, `routes/(app)/settings/**` (except `notifications` and `bgg`), `routes/(app)/+layout.svelte`, `lib/components/layout/**`, `lib/components/ui/**`, `lib/api/{auth,users,client,server,load,admin,setup}.ts`, `lib/stores/auth.ts`, `lib/session.ts`, `lib/types/account.ts`, `.github/workflows/**` | – | V55–V59 |
| WP6 Mobile (Flutter) | – | – | `mobile/**` entirely, including the new `android/` and `ios/` | none |

Sizes: WP1 L, WP2 L, WP3 L, WP4 L, WP5 L, WP6 L.

**Note on `routes/onboarding/find-friends`:** it calls WP3 APIs through `lib/api/friends.ts`. WP5 may only import from that file, never edit it.

**General rule:** a package may *import* any other package's classes or TS modules, but must not *edit* them. Any change needed in another package goes through a contract in §6.

### WP1: Notifications & Push (CLAUDE P2 / PLAN P2–P3)

Tasks:
- **V36 notifications schema:**
  - Add `title VARCHAR(255)`, `body TEXT`, `data JSONB`, `is_pushed BOOLEAN DEFAULT FALSE`, `deleted_at`.
  - Add index `(recipient_id, created_at DESC, id)`.
- **V37 `notification_preferences`:** `user_id`, `type`, `in_app_enabled`, `push_enabled`; PK `(user_id, type)`.
- **V38 `notification_settings`:** `user_id` PK, `quiet_hours_start TIME`, `quiet_hours_end TIME`. Quiet hours stay out of `users`, so WP1 never touches `User.java`. Use `users.timezone` (from V35) for evaluation, falling back to UTC.
- **Message factory:** a single `NotificationMessageFactory` builds title, body and `data.path` (FEATURES §7.2) from type, actor and reference.
- **Keep the existing `send(...)` signature** and add `send(recipientId, type, actorId, refId, refType, Map<String,Object> extra)`. The delivery pipeline:
  1. Check preferences.
  2. Save.
  3. Check quiet hours.
  4. Send over WS and increment `notif:unread:{id}` in Redis.
  5. If offline (`ws:online:{id}` absent) and push is enabled, call `FcmService.sendAsync`.
- **FcmService:**
  - Firebase Admin initialised from base64 JSON; a disabled no-op bean when the secret is blank.
  - `@CircuitBreaker(name="fcm")` and `@Async("notificationExecutor")`.
  - Multicast to `user_fcm_tokens`.
  - Delete stale tokens on `UNREGISTERED` / `INVALID_ARGUMENT`.
  - Set `is_pushed`.
- **Presence:** `WebSocketPresenceListener` handles `SessionConnectedEvent`, `SessionDisconnectEvent` and heartbeat, and maintains `ws:online:{userId}` with a 30s TTL refresh. It lives in its own file and does not edit `WebSocketConfig`.
- **Endpoints:** see §6.1. Cursor list, per-item read, per-item delete, preferences and settings, FCM token register/unregister.
- **Like batching:** at most one `POST_LIKE` per post per hour, with an "X and N others" body. Implement it inside WP1 by coalescing on `(recipient, type=POST_LIKE, referenceId)` within 1h, so WP3 keeps calling `send` unchanged.
- **Cleanup job:** `notification_cleanup` daily, removing rows older than 90 days, via `JobLock`.
- **Account deletion listener:** on `UserSoftDeletedEvent`, delete the user's notifications and FCM tokens.
- **Web notification centre** (SCREENS §9): grouping, tap → `data.path` + mark read, swipe/delete, infinite scroll, skeleton, empty state, actor avatar and name (the DTO gains an `actor` summary).
- **Web preferences page:** toggle table plus quiet hours.
- **Web push:** `lib/push/fcm.ts` requests permission after login via a settings toggle, registers the token with platform `web`, and unregisters on logout (logout calls `pushApi.unregister()` exported by WP1; WP5 calls it).
- **WS payload:** `{ notification, unreadCount }`; update `notificationCount` live.

Acceptance criteria:
- Integration tests run against real Postgres and Redis.
- Preferences off means no WS and no push, but the row is still saved.
- Quiet hours suppress WS and push.
- Online means no FCM; offline means FCM is called (mocked `FirebaseMessaging`).
- A stale token is deleted.
- read-all resets the Redis counter; single read decrements it.
- Cursor pagination is stable across inserts.
- The web page shows the grouped list and navigates on tap.
- With an empty Firebase config the app still boots, and FCM is a logged no-op.
- No TODOs. JaCoCo coverage of the `notification` package ≥ 70%.

### WP2: Events & Matching (CLAUDE P1–P2 / PLAN P1–P2)

Tasks:
- **V40:** `event_participants` CHECK adds `LEFT` and `KICKED`.
- **V41:** `events.reminder_sent BOOLEAN DEFAULT FALSE` and `events.location_display VARCHAR(100)`.
- **Create:** `CreateEventRequest` adds `invitedUserIds`, restricted to friends (403 `NOT_FRIENDS` otherwise), no self-invite, and validation per FEATURES §4.1 / §12.1.
  - Each invite gets an `INVITE` row and an `EVENT_INVITE` notification.
  - Mark `reminder_sent=true` if the start is within 24h.
- **Update** gets a separate `UpdateEventRequest` with all fields optional. Enforces: no max below the accepted count; no game change after `COMPLETED`; `EVENT_UPDATED` notification when the time changes.
- **Cancel** `POST /events/{id}/cancel`: sets `CANCELLED` and `deleted_at`, and notifies accepted participants with `EVENT_CANCELLED`. Keep the existing `DELETE` as an alias.
- **Kick** `DELETE /events/{id}/participants/{userId}`: status `KICKED`, `EVENT_KICKED` notification, `FULL`→`OPEN`.
- **Leave:** status becomes `LEFT` (not row delete), with `EVENT_LEAVE` to the host.
- **Join rules:** PUBLIC events are open-join; FRIENDS and INVITE_ONLY require an existing `INVITED` row.
- **Response:** `EventResponse` adds `participants[]`, `isHost` and `reminderSent`; `location` is masked to `locationDisplay` for non-joined viewers of PUBLIC events. Avoid N+1 queries.
- **List endpoints:** `GET /events?scope=upcoming|past|mine` and `GET /events/calendar?from=&to=`; `GET /events/community?gameId=&cursor=`.
- **Jobs:** `event_auto_complete` (30 min, plus `EVENT_COMPLETED` to the host) and `event_reminder` (hourly), both via `JobLock`.
- **Activity:** publish `ActivityRecordedEvent` for `event_created` (non-INVITE_ONLY only) and `event_joined`.
- **Live updates:** `convertAndSend("/topic/events/{id}", EventParticipantsChanged)`. The subscribe permission check stays as is, since `WebSocketConfig` is owned by WP5. If WP5's topic authorisation blocks this topic, coordinate via the §6.3 contract.
- **Matching:**
  - Add the `/requests/mine` alias.
  - `match_request_expire` hourly job.
  - `acceptMatch` passes the invited user IDs (fixes the current `CreateEventRequest` construction in `MatchService:182`).
  - `MATCH_ACCEPTED` notification to the other members.
- **Web:**
  - List/Calendar toggle with a monthly grid, dots and a day bottom sheet (`?view=calendar`).
  - Upcoming / Past / Community tabs.
  - Create form: friend multi-select with chips, `?matchGroupId` prefill, stepper 2–50.
  - Detail: participant grid, RSVP state table (SCREENS §6.4), host Manage menu (edit / cancel / kick), cancelled and completed banners, "View Memories" (posts by `eventId`, using the WP3 endpoint).
  - Export `EventCardCompact.svelte` and `MatchSuggestionCard` for the home page (WP3 composes them).

Acceptance criteria:
- Tests for:
  - the invite-only join being refused
  - the last-spot race (two concurrent accepts, exactly one succeeds)
  - kick reopening a FULL event
  - the reminder firing once, and not for events created less than 24h out
  - auto-complete after 12h
  - past and calendar range queries
  - match accept creating an event with invites
- Notifications are sent through `NotificationService.send` only.
- Every new job uses `JobLock`.

### WP3: Social, Feed & Posts (CLAUDE P1–P2 / PLAN P1–P3)

Tasks:
- **V45 `activity_events`:** `id`, `user_id`, `type`, `data JSONB`, `created_at`, `deleted_at`; index `(user_id, created_at DESC)`.
- **V46:** `posts.edited_at`; `bookmarks(user_id, post_id, saved_at, PK)`.
- **V47 `reports`:** `id`, `reporter_id`, `target_type`, `target_id`, `reason`, `created_at`; UNIQUE `(reporter_id, target_type, target_id)`.
- **Feed** `GET /feed?cursor=&limit=`: union of posts and `activity_events` for friends + self, minus blocks; returns `FeedPage{items, nextCursor, hasMore}`; Redis 60s cache keyed `feed:{userId}:{cursor}`.
- **Activity listener:** `ActivityRecordedEvent` → insert. The existing `/feed?page=` path stays supported for mobile backward compatibility for one release.
- **Post creation:**
  - Tags restricted to friends (or self); tags from users who blocked the author are silently dropped.
  - Max 10 images.
  - `playedAt` not in the future.
  - Honour `eventId`.
  - Publish `SessionPlayedEvent(author + tagged users, gameId, playedAt, postId)` when a game is set (WP4 records the plays).
  - `POST_TAG` notifications.
- **Post edit** within 48h with tag diffs: new tagged users get `SessionPlayedEvent` and a notification. Decrementing for removed tags is skipped (documented). `GET /posts?eventId=` serves "View Memories".
- **Comments:** edit within 24h, delete by author or post author, `@mention` → `COMMENT_MENTION`. Bookmarks endpoints.
- **Social:**
  - 7-day decline cooldown in Redis, 50-pending cap.
  - `GET /users/me/blocked`; `UserSummaryWithStatus` with `friendshipStatus` for search.
  - Suggestions by game overlap (`GET /users/suggestions` is mapped in WP5's `UserController`; WP3 instead provides `SocialQueryService.suggestions(userId, limit)` and `searchWithStatus(q)`, which WP5's controller calls).
  - `POST /reports` (5/day).
- **Unified search** `GET /api/v1/search?q=&limit=` returns `{games[], users[], events[]}`, using game and event repository reads without editing those packages.
- **Account deletion listener:** on `UserSoftDeletedEvent`, delete friendships and pending requests.
- **Web:**
  - Home: greeting "next session in X days" via `eventsApi`; match cards plus a "+N more" chip; upcoming row with a "View Calendar" link; infinite feed via IntersectionObserver at 80% depth; activity item renderer; three empty states plus an error state with retry; "You're all caught up!".
  - Search overlay route at `/search`, wired from the AppBar search icon via a `href` change requested from WP5.
  - People page: Requests tab with received and sent, accept/decline/cancel.
  - Post create: optional images; compression in `lib/utils/image.ts` (canvas → WebP, ≤ 1200px, ≤ 1 MB); per-image progress, failure and retry; discard guard.
  - Post detail: delete, edit (within 48h), comment edit/delete, bookmark, share, "Edited" label.

Acceptance criteria:
- Tests: feed cursor stability; block hides content both ways; tag of a non-friend is rejected (or dropped when blocked); `SessionPlayedEvent` published with the correct user set; 48h and 24h edit windows; cooldown and 50-cap; report rate limit.
- The web feed loads page 2 on scroll.
- Images over 1 MB are compressed before presign.

### WP4: Library, Collection, Plays, BGG Import & AI touch-ups (CLAUDE P1 / P3; PLAN P1–P3)

Tasks:
- **V50 (pending the wishlist decision):** `ALTER TABLE user_games ADD COLUMN is_wishlisted BOOLEAN NOT NULL DEFAULT FALSE`.
  - Update `UserGame`, `UserGameRequest`, `UserGameResponse`.
  - Collection `filter=wishlisted`.
  - If all flags are false and there is no rating, notes or play count, delete the row.
- **V51:** `play_logs` adds `notes TEXT`, `post_id UUID NULL REFERENCES posts`, `duration_minutes INT NULL`, `player_count INT NULL`; plus `bgg_imports` audit (`user_id`, `bgg_username`, `status`, `imported`, `skipped`, `failed`, `started_at`, `finished_at`).
- **Play logging:**
  - `POST /users/me/games/{gameId}/plays` with body `{playedAt?, notes?, durationMinutes?, playerCount?}`; keep `log-play` as an alias.
  - `DELETE /users/me/plays/{playId}` decrements `play_count`.
  - `SessionPlayedEvent` listener: upsert `user_games` (flags unchanged), increment `play_count`, insert `play_logs` with `post_id`. Idempotent per `(user, post)`.
  - On `ActivityRecordedEvent`, publish `collection_add` when `isOwned` flips to true.
- **Stats:** `GET /users/{id}/stats` (FEATURES §9.1; the friends count comes from `FriendRequestRepository`, read-only). Block-aware: 404 if blocked. Privacy checks on `/users/{id}/games` and `/plays` (block-aware).
- **Game detail additions:**
  - `GET /games/{id}/friends` (friends who own it, with play count and rating).
  - `GET /games/{id}/reviews` (friends' ratings and notes).
  - `GET /games/{id}/sessions?cursor=` (posts tagged with the game; read the post repository).
  - `friendAvgRating`, `friendRatingCount`, `ownedByFriends[]` (up to 5 avatars) in `GameDetailResponse` (computed per viewer).
- **BGG import** (`game/service/BggCollectionImportService`, `@Async("notificationExecutor")`):
  - `POST /users/me/bgg-import {bggUsername}`, `GET /users/me/bgg-import/status`.
  - xmlapi2 `/collection?username=&own=1&excludesubtype=boardgameexpansion` with Bearer `app.bgg.api-token`.
  - 202 retry ×10 at 2s intervals; 404 → `BGG_USER_NOT_FOUND`; otherwise 503 `BGG_API_UNAVAILABLE`.
  - Progress in Redis `bgg:import:{userId}`.
  - Upsert games via the existing hydration path and `user_games.is_owned=true`.
  - Save `users.bgg_username` (V35 column) via `UserRepository`.
- **Caching:** `@EnableCaching` config in `game/config/CacheConfig.java` (owned by WP4, not `config/`).
  - `@Cacheable` for game detail (7d) and collection (10m), with eviction on update.
  - Event and profile caches are left to their owners.
- **Cleanup:** remove the hard-coded `runImport` path (use `app.seed.csv-url` or delete the endpoint).
- **AI:** send `RULEBOOK_APPROVED`, `RULEBOOK_REJECTED` and `RULEBOOK_UNDER_REVIEW` notifications to the uploader (AI_PLAN §3).
- **Web:**
  - Wishlist tab and button, with filled bookmark state.
  - Inline star rating.
  - Game-detail tabs Reviews / Sessions / Friends, plus an "Owned by X friends" stack.
  - `log-play` form with date, notes, duration and players.
  - `settings/bgg` and `onboarding/bgg-import` running the real import with "Importing 12 of 45" progress, success preview of 5 covers, and username-not-found / BGG-unavailable states.
  - `onboarding/add-game`: debounced search grid, quick-add sheet, popular games when empty, toast; then sets `onboardingCompleted` (via `usersApi`, import only).

Acceptance criteria:
- Tests: wishlist round-trip; all-false row deletion; `SessionPlayedEvent` idempotency; stats SQL against seeded data; a BGG import against a WireMock-style stub (202 then 200, then 404); cache eviction on update; block-404 on stats and collection.
- With no `BGG_API_TOKEN`, the import returns 503 `BGG_API_UNAVAILABLE` cleanly.

### WP5: Account, Profile, Settings, Onboarding & Platform infra (CLAUDE P1–P2; PLAN P1–P3)

Tasks:
- **V55 `data_export_requests`:** `id`, `user_id`, `status`, `file_key`, `created_at`, `completed_at`.
- **V56:** index `users(deleted_at) WHERE deleted_at IS NOT NULL`.
- **Deletion:** `DELETE /users/me {password? | googleIdToken? | confirm:"DELETE"}` (per C11).
  - Revoke sessions.
  - Publish `UserSoftDeletedEvent`; WP1, WP3, WP4 and WP2 listeners clear their data (collection, match requests, notifications, friendships).
  - Confirmation email.
- **Login** returns 401 `ACCOUNT_DELETED` within 30 days.
- **Reactivate:** `POST /auth/reactivate {emailOrUsername, password}`.
- **`account_hard_delete` job** (3am, `JobLock`): publish `UserHardDeletedEvent`, delete R2 avatars, delete the user. FK cascade or anonymisation per FEATURES §1.6. Posts are hard-deleted; events and comments stay as "Deleted User" (authors rendered by DTOs as `deleted=true`).
- **Export:** `GET /users/me/export` (async JSON zip to R2, emailed link).
- **Change email:** `POST /users/me/change-email` with verification to the new address.
- **Username change** once per 30 days (`username_changed_at`).
- **Sessions:** `GET /auth/sessions`, `DELETE /auth/sessions/{id}`, `POST /auth/sessions/revoke-others`.
- **Profiles:**
  - `GET /users/{id}` returns 404 when blocked either way.
  - `UserProfileResponse` adds `isVerified`, `bggUsername` (self only), `preferredLanguage`, `usernameChangeAvailableAt`.
  - Align validation per C12.
  - The `UserController` search and suggestions mappings delegate to WP3's `SocialQueryService`.
- **Infra:**
  - Global rate-limit filter in `config/`: 200/min per user, 20/min per IP unauthenticated, 10/min login.
  - `.well-known/assetlinks.json` and `apple-app-site-association` served and permitted in `SecurityConfig`.
  - `logback-spring.xml` with JSON output in prod.
  - Sentry user scope without PII.
  - Graceful shutdown.
  - `post_image_cleanup` job lives in `storage/` (`storage/job/PostImageCleanupJob`, R2 delete of `post_images` for posts deleted more than 30 days ago; reads post tables natively).
  - Flutter CI job in `.github/workflows/ci.yml`.
- **Web:**
  - Settings root per SCREENS §11.1 (About section, greyed Privacy and Theme, language switcher en/中文 stored in `preferred_language`).
  - Change-email and sessions pages; delete-account with password/confirm plus a bottom-sheet modal and correct 30-day copy.
  - Login handling for `ACCOUNT_DELETED` with a reactivate flow.
  - Own profile: stats bento from WP4's `/users/{id}/stats`; Favorites scroll; Posts / Tagged / Collection tabs.
  - Other profile: Add Friend states plus a "···" menu with Block and Report (calls WP3 APIs).
  - Onboarding: step dots and Skip in the layout; profile step with avatar crop; find-friends step with suggestions, search and inline Add Friend.
  - AppBar search icon → `/search`.
  - Offline banner, pull-to-refresh helper, bottom-sheet confirm in `lib/components/ui`.
- **i18n:** extract the strings of every route this package owns. After WP1–WP4 merge, a follow-up i18n sweep extracts the remaining strings. Each package must use `m()` for every *new* string it adds.

Acceptance criteria:
- Tests: deletion → reactivate → login; hard-delete job removes the user after 30 days; blocked profile returns 404; session revoke; rate-limit filter returns 429 with `RATE_LIMIT_EXCEEDED`; change-email verification.
- `.well-known` files are served unauthenticated.
- The app boots with all secrets empty.

### WP6: Mobile Flutter (CLAUDE P3 / PLAN P4)

Ownership: `mobile/**`.

Tasks:
- `flutter create --platforms=android,ios .` inside `mobile/` to add the platform folders (preserving `lib/`).
- Add a committed `lib/firebase_options.dart` *template* that reads `--dart-define`s and falls back to disabled Firebase, so the app compiles without real config.
- Android channels, iOS entitlements; `AndroidManifest` and `Info.plist` deep links for `/events/*`, `/posts/*`, `/profile/*`, `/library/*`.
- Implement the stub screens against the current and §6 contracts:
  - home feed: infinite scroll with `FeedPage`, activity items, Isar cache
  - library: tabs per the wishlist decision, search and filters
  - events: tabs plus a `table_calendar` month view, create button wired, visibility picker, invite friends
  - notifications: list, read, deep-link, preferences
  - search: unified `/search`
  - settings: profile, notifications, sessions, delete account, BGG import, language
  - own and other profile: stats, friends, block/report
  - post detail: comments, like, bookmark, share via `share_plus`
- New features: friends and requests, matching, AI assistant sheet with 3-pair history (`AiQueryRequest.conversationHistory` as `{question, answer}`), play logging.
- **FCM:** pre-permission screen; `getToken` and `onTokenRefresh` → `POST /users/me/fcm-tokens {platform: ios|android}`; unregister on logout; foreground `flutter_local_notifications`; `onMessageOpenedApp` and `getInitialMessage` → `router.go(data.path)`.
- **Google sign-in** via `google_sign_in` → `POST /auth/google {idToken, ...}` (check `AuthController.google` for the exact body).
- Biometric unlock (MOBILE_FLUTTER §12), offline write guard (§11), PostHog init gated on a define.
- **l10n:** `l10n/app_en.arb`, `app_zh.arb`, `flutter gen-l10n`, locale from `preferredLanguage`.
- Fix `isWishlisted` and `filter=wishlisted` per the decision.

Acceptance criteria:
- `flutter analyze` is clean; `flutter test` passes, including the existing `test/api_contract_test.dart` extended for the new DTOs.
- The app builds for Android debug with no Firebase config.
- No screen remains labelled "stub".
- Every route in MOBILE_FLUTTER §5 exists.

### Order and dependencies

1. Step 0 merges first.
2. WP1–WP5 run in parallel.
3. Recommended merge order: WP1 (notification types and `send` used by everyone) → WP2, WP3, WP4 → WP5.
4. WP6 can start immediately against existing endpoints and mocks of the §6 contracts. It finalises after the backend packages merge.
5. A final i18n string-extraction sweep happens after all web packages merge (WP5 owns the sweep or a follow-up agent does).
6. Phase ordering inside packages:
   - CLAUDE P1 items first (wishlist, calendar, invites, cancel/kick, past, profile stats, deletion).
   - Then P2 (notifications, FCM, feed activities, friends UI, i18n).
   - Then P3 (BGG import, caching, search, mobile).

## 6. Shared contracts (all packages must agree)

All responses use the existing `ApiResponse` wrapper / `ResponseWrappingAdvice` and the error shape `{error, code}`. IDs are UUID; times are ISO-8601 UTC.

### 6.1 New and changed REST endpoints (owner in brackets)

**[WP1] Notifications**
- `GET /api/v1/notifications?cursor={ISO}&limit=30` returns `{items: NotificationDto[], nextCursor: string|null, hasMore: boolean}`. The old `page`/`size` parameters stay accepted.
- `NotificationDto` shape:
  ```
  {
    id, type,
    actor: {id, username, displayName, avatarUrl} | null,
    referenceId, referenceType,
    title, body,
    data: {path: string, ...},
    read, createdAt
  }
  ```
- Other notification endpoints:
  - `PUT /notifications/{id}/read` → 204
  - `DELETE /notifications/{id}` → 204
  - `PUT /notifications/read-all` (existing)
  - `GET /notifications/unread-count` → `{count}` (existing)
- Preferences and settings:
  - `GET /notifications/preferences` → `[{type, inAppEnabled, pushEnabled}]`
  - `PUT /notifications/preferences` with that same array as the body
  - `GET`/`PUT /notifications/settings` → `{quietHoursEnabled, quietHoursStart:"HH:mm"|null, quietHoursEnd, timezone}`
- Device tokens:
  - `POST /api/v1/users/me/fcm-tokens {token, platform:"web"|"ios"|"android", deviceInfo?}` → 204
  - `DELETE /api/v1/users/me/fcm-tokens/{token}` → 204
  - These are mapped in a WP1 controller; Spring allows this alongside `UserController`.

**[WP2] Events**
- `POST /events` body `{title, description?, location?, locationDisplay?, scheduledAt, gameId?, maxParticipants?, visibility, invitedUserIds?: UUID[]}`.
- `PUT /events/{id}` with the same fields, all optional (`UpdateEventRequest`).
- `POST /events/{id}/cancel`.
- `POST /events/{id}/invites {userIds: UUID[]}`.
- `DELETE /events/{id}/participants/{userId}` (kick).
- `POST /events/{id}/rsvp {status}` (existing).
- `DELETE /events/{id}/rsvp` (now sets status `LEFT`).
- `GET /events?scope=upcoming|past|mine&limit=`.
- `GET /events/calendar?from=&to=`, a range of at most 62 days.
- `GET /events/community?gameId=&cursor=&limit=`.
- `EventResponse` adds:
  - `participants: [{id, username, displayName, avatarUrl, status}]`
  - `isHost: boolean`
  - `reminderSent: boolean`
  - `locationDisplay: string|null`
  - `myRsvp` may also be `LEFT` or `KICKED`

**[WP2] Matching**
- `GET /matches/requests/mine` (alias of `/me`).

**[WP3] Feed and posts**
- `GET /feed?cursor=&limit=20` returns `{items: FeedItem[], nextCursor, hasMore}`. `FeedItem` is one of:
  - `{kind:"post", createdAt, post: PostResponse}`
  - `{kind:"activity", createdAt, activity: {id, type: "collection_add"|"event_created"|"event_joined", user: UserSummary, data}}`
- Posts:
  - `PUT /posts/{id}` (within 48h)
  - `GET /posts?eventId=&cursor=`
  - `POST`/`DELETE /posts/{id}/bookmark`
  - `GET /users/me/bookmarks?cursor=`
  - `PostResponse` adds `editedAt`, `isBookmarked`, and `author.deleted`
- Comments:
  - `PUT /posts/{id}/comments/{cid}` (within 24h)
  - `DELETE /posts/{id}/comments/{cid}`
- Social:
  - `DELETE /users/{id}/friend-request` (cancel by target, per the doc)
  - `GET /users/me/blocked`
  - `POST /reports {targetType:"user"|"post"|"comment", targetId, reason}` → 201
- Search:
  - `GET /search?q=&limit=3` returns `{games: GameSummary[], users: UserSummaryWithStatus[], events: EventSummary[]}`
  - `UserSummaryWithStatus` = `{id, username, displayName, avatarUrl, friendshipStatus: "none"|"pending_sent"|"pending_received"|"friends"}`. `/users/search` also returns this shape.

**[WP4] Collection, plays, stats, BGG**
- Collection:
  - `PUT /users/me/games/{gameId}` body adds `isWishlisted?`
  - `UserGameResponse` adds `isWishlisted`
  - `GET /users/me/games?filter=all|owned|wishlisted|favorited`
- Plays:
  - `POST /users/me/games/{gameId}/plays {playedAt?, notes?, durationMinutes?, playerCount?}` → `PlayLogResponse`
  - `DELETE /users/me/plays/{playId}`
- Stats: `GET /users/{id}/stats` returns:
  ```
  {
    gamesOwned, sessions, friends,
    mostPlayedGame: {gameId, title, playCount} | null,
    favoriteCategory: string | null,
    mostPlayedWith: {userId, displayName, sharedSessions} | null,
    totalPlayMinutes
  }
  ```
- Game detail:
  - `GET /games/{id}/friends` → `[{user: UserSummary, playCount, personalRating, isOwned}]`
  - `GET /games/{id}/reviews` → `[{user, personalRating, notes, playCount}]`
  - `GET /games/{id}/sessions?cursor=` → feed-style `PostResponse` page
  - `GameDetailResponse` adds `friendAvgRating`, `friendRatingCount`, `ownedByFriends: UserSummary[]` (up to 5)
- BGG import:
  - `POST /users/me/bgg-import {bggUsername}` → 202 `{status:"running"}`
  - `GET /users/me/bgg-import/status` → `{status: "idle"|"running"|"done"|"failed", total, processed, imported, skipped, failed, errorCode?}`
  - `errorCode` is one of `BGG_USER_NOT_FOUND` | `BGG_API_UNAVAILABLE`

**[WP5] Account**
- `DELETE /users/me {password?, googleIdToken?, confirm?}`
- `POST /auth/reactivate {emailOrUsername, password}`
- `GET /users/me/export` → 202
- `POST /users/me/change-email {currentPassword, newEmail}`
- `POST /auth/confirm-email-change {token}`
- Sessions:
  - `GET /auth/sessions` → `[{id, deviceInfo, createdAt, lastUsedAt, current}]`
  - `DELETE /auth/sessions/{id}`
  - `POST /auth/sessions/revoke-others`
- `PUT /users/me` adds `username?`, `preferredLanguage?: "en"|"zh-CN"`, `timezone?`.
- `UserProfileResponse` adds `isVerified`, `preferredLanguage`, `usernameChangeAvailableAt`, and `bggUsername` (self only).
- `UserSummary` (shared shape everywhere) = `{id, username, displayName, avatarUrl, deleted: boolean}`.

**Error codes added:** `ACCOUNT_DELETED`, `NOT_FRIENDS`, `EVENT_CANCELLED`, `EVENT_COMPLETED`, `NOT_HOST`, `EDIT_WINDOW_EXPIRED`, `REQUEST_COOLDOWN`, `PENDING_LIMIT`, `REPORT_LIMIT_EXCEEDED`, `BGG_USER_NOT_FOUND`, `BGG_API_UNAVAILABLE`, `RATE_LIMIT_EXCEEDED`, `USERNAME_CHANGE_TOO_SOON`.

### 6.2 Backend in-process contracts (created in Step 0)

**`NotificationService.send`**
- Existing signature is unchanged: `send(UUID recipientId, NotificationType type, UUID actorId, UUID referenceId, String referenceType)`.
- New overload adds `Map<String,Object> extra`; keys can be `eventTitle`, `gameName`, `count`, `path`.
- Callers never build title, body or path themselves.

**Spring application events** (publish with `ApplicationEventPublisher`; listeners use `@TransactionalEventListener(AFTER_COMMIT)` unless noted)

| Event | Published by | Consumed by |
|---|---|---|
| `ActivityRecordedEvent` | WP2 (`event_created`, `event_joined`), WP4 (`collection_add`) | WP3 |
| `SessionPlayedEvent` | WP3 | WP4 |
| `UserSoftDeletedEvent` | WP5 | WP1 (notifications, FCM tokens), WP2 (match requests; future event invites), WP3 (friendships, requests, bookmarks), WP4 (collection, play logs) |
| `UserHardDeletedEvent` | WP5 | WP3 (posts hard delete), WP1 (cleanup) |

**`JobLock`:** `common/job/JobLock.runWithLock(name, ttl, runnable)`. Redis key `lock:{name}`.

**Redis key names**
- `ws:online:{userId}` (WP1)
- `notif:unread:{userId}` (WP1)
- `feed:{userId}:{cursor|first}` (WP3)
- `fr:cooldown:{sender}:{receiver}` (WP3)
- `bgg:import:{userId}` (WP4)
- `report:count:{userId}:{yyyy-MM-dd}` (WP3)
- Spring Cache names: `game-detail` and `user-collection` (WP4), `user-profile` (WP5), `event-detail` (WP2)

### 6.3 WebSocket (STOMP) destinations

- `/user/queue/notifications` (existing) carries `{notification: NotificationDto, unreadCount: number}`. This changes the old bare-`NotificationResponse` payload: **WP1 updates web `websocket.ts` and WP6 updates mobile `realtime_service.dart`**.
- `/topic/events/{eventId}` (new, WP2) carries `{eventId, participantCount, status, participants: [...]}`.
  - Subscription must be authorised to viewers who can see the event.
  - WP5 owns `WebSocketConfig`'s subscribe interceptor and must allow `/topic/events/*` with a visibility check that calls `EventRepository.isVisibleTo`. This is the one cross-package touchpoint; WP5 implements it.
- `/topic/how-to-play/{gameId}` is unchanged.

### 6.4 NotificationType enum (complete; added in Step 0)

```
EVENT_INVITE, EVENT_RSVP, EVENT_LEAVE, EVENT_KICKED, EVENT_CANCELLED,
EVENT_UPDATED, EVENT_REMINDER, EVENT_COMPLETED,
MATCH_FOUND, MATCH_ACCEPTED,
POST_LIKE, POST_COMMENT, COMMENT_MENTION, POST_TAG,
FRIEND_REQUEST, FRIEND_ACCEPTED,
RULE_NOTE_APPROVED, RULE_NOTE_REJECTED,
RULEBOOK_APPROVED, RULEBOOK_REJECTED, RULEBOOK_UNDER_REVIEW,
BGG_IMPORT_COMPLETED
```

`data.path` values follow FEATURES §12.3, using `/library/{gameId}` per C8.

### 6.5 Flyway migration numbers

| Range | Owner | Contents |
|---|---|---|
| V35 | Step 0 | users profile columns |
| V36–V39 | WP1 | V36 notifications columns, V37 `notification_preferences`, V38 `notification_settings`, V39 spare |
| V40–V44 | WP2 | V40 participant statuses `LEFT`/`KICKED`, V41 `reminder_sent` + `location_display`, V42–V44 spare |
| V45–V49 | WP3 | V45 `activity_events`, V46 `posts.edited_at` + `bookmarks`, V47 `reports`, V48–V49 spare |
| V50–V54 | WP4 | V50 `is_wishlisted` (after confirmation), V51 `play_logs` columns + `bgg_imports`, V52–V54 spare |
| V55–V59 | WP5 | V55 `data_export_requests`, V56 users deleted index, V57–V59 spare |

Migration rules:
- Every migration is self-contained, idempotent where possible (`IF NOT EXISTS`), and touches only its owner's tables (or, for Step 0, `users`).
- Uppercase enum CHECK values, matching V30.
- `out-of-order=true` in local and staging only.
- Production deploy happens after all packages merge, in version order.

### 6.6 Frontend shared rules

- Types live only in `lib/types/{area}.ts` (barrel in `index.ts`).
- All HTTP goes through `lib/api/client.ts` (CLAUDE.md).
- New strings use `m()` from `$lib/i18n` with namespace prefixes `notif.`, `event.`, `social.`, `library.`, `account.`.
- No raw hex colours; no border utilities except `border-white/10` (CLAUDE.md No-Line Rule).
- A package that needs a nav or layout change asks WP5. Pre-agreed changes:
  - AppBar search → `/search`
  - BottomNav FAB sheet with Post / Event / Add Game / Find Match

### Critical files for implementation

- `/home/user/Meeple/backend/src/main/java/com/meeplehearth/notification/service/NotificationService.java` (plus the stub `FcmService.java` and `entity/Notification.java`)
- `/home/user/Meeple/backend/src/main/java/com/meeplehearth/event/service/EventService.java` (plus `event/dto/CreateEventRequest.java`, `match/service/MatchService.java`)
- `/home/user/Meeple/backend/src/main/java/com/meeplehearth/post/service/PostService.java` (feed and createPost)
- `/home/user/Meeple/backend/src/main/java/com/meeplehearth/game/service/GameService.java` (plus `game/entity/UserGame.java`, `game/client/BggApiClient.java`)
- `/home/user/Meeple/backend/src/main/java/com/meeplehearth/user/service/UserService.java` (plus `auth/service/AuthService.java` login lines 150–198)
- `/home/user/Meeple/backend/build.gradle.kts` and `/home/user/Meeple/backend/src/main/resources/application.yml` (Step 0)
- `/home/user/Meeple/frontend/src/lib/types/index.ts` and `/home/user/Meeple/frontend/src/routes/(app)/+page.svelte`
- `/home/user/Meeple/mobile/lib/main.dart` and `/home/user/Meeple/mobile/lib/core/router/app_router.dart`