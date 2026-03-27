# Meeple & Hearth — Screens & UI States

> Every screen. Every state (default / loading / empty / error). Every navigation flow.
> Design decisions for things not covered by reference mockups.

---

## 1. Navigation Architecture

### Web (SvelteKit)

```
Root Layout (+layout.svelte)
├── TopAppBar (fixed, z-50, glassmorphic)
├── PageContent (pt-24 pb-32, scrollable)
└── BottomNav (fixed bottom, z-50, glassmorphic)
    ├── Home      icon: home         route: /
    ├── Library   icon: library_books route: /library
    ├── [FAB]     icon: add           opens: CreateBottomSheet
    ├── Events    icon: event         route: /events
    └── Profile   icon: person        route: /profile
```

**Auth Layout** (no TopAppBar / BottomNav):
```
/auth/login
/auth/register
/auth/verify-email
/auth/forgot-password
/auth/reset-password/[token]
```

**Onboarding Layout** (no BottomNav, custom TopAppBar with step indicator):
```
/onboarding/welcome
/onboarding/profile
/onboarding/bgg-import
/onboarding/find-friends
/onboarding/add-game
```

**Modal / Sheet routes** (overlay on current page, URL changes for deep-linking):
```
/posts/create         → Create Post sheet
/events/create        → Create Event sheet
/library/games/[id]   → Game Detail (full page push)
/events/[id]          → Event Detail (full page push)
/posts/[id]           → Post Detail (full page push)
/profile/[id]         → User Profile (full page push)
/notifications        → Notifications page
/settings             → Settings page (+ nested sub-pages)
```

### Per-Tab Stack Preservation (SvelteKit)

SvelteKit does NOT preserve per-tab navigation stacks by default. Decision: use `data-sveltekit-reload` sparingly. Instead, store the last scroll position and selected tab in a Svelte store. When switching tabs, each tab resumes at its root route (no back-stack). Deep navigation within a tab uses standard browser history.

### Back Navigation

- Top-left back button shown when route is a "detail" page (not a root tab)
- `history.back()` on press — uses browser history
- If user arrived via notification deep link with no previous history: back button navigates to the relevant parent (e.g., event detail → events list)

---

## 2. Auth Screens

### 2.1 Login Screen `/auth/login`

**Layout:** Center-aligned card on mobile. No AppBar/BottomNav.

**Elements:**
- App logo + "Meeple & Hearth" wordmark (centered top)
- "Welcome back" heading
- Email/username input
- Password input (with show/hide toggle)
- "Forgot password?" link (→ `/auth/forgot-password`)
- "Log In" button (primary gradient, full-width, `rounded-full`)
- Divider: "— or —"
- "Create account" link (→ `/auth/register`)

**States:**
- **Default:** Empty inputs, button enabled
- **Loading:** Button shows spinner + "Logging in…", inputs disabled
- **Error (wrong credentials):** Red inline error below password: "Incorrect email or password."
- **Error (account locked):** "Too many attempts. Try again in X minutes."
- **Error (unverified):** Yellow banner above button: "Please verify your email. [Resend email]"

---

### 2.2 Register Screen `/auth/register`

**Elements:**
- "Create your account" heading
- Email input (real-time availability check after 500ms idle)
- Username input (real-time availability check, shows green checkmark or red X)
- Password input (strength indicator bar below: Weak / Good / Strong)
- "Create Account" button
- "Already have an account? Log in" link

**States:**
- **Username taken:** Inline red: "Username already taken"
- **Username available:** Inline green checkmark + "Username available"
- **Email taken:** Inline red: "Email already registered"
- **Loading:** Button disabled + spinner
- **Success:** Redirect to `/auth/verify-email` page

**Password strength logic:**
- Weak: < 8 chars or no letter/number mix
- Good: 8–12 chars with letter + number
- Strong: 12+ chars with letter + number + special char (optional encouragement)
- Bar colors: `error` / `secondary-container` / `tertiary`

---

### 2.3 Verify Email Screen `/auth/verify-email`

**Elements:**
- Email icon (large, teal/tertiary color)
- "Check your inbox" heading
- "We sent a verification link to [email]"
- "Resend email" button (ghost style, disabled 60s countdown: "Resend in 54s")
- "Open email app" button (primary, mailto: link)
- "Wrong email? Go back" link

**States:**
- **Default:** Countdown running
- **Resend success:** "Email resent!" toast

**On visiting the verification link:**
- `GET /auth/verify-email?token=xxx` → SvelteKit calls `POST /api/v1/auth/verify-email` → sets JWT cookies → redirects to `/onboarding`

---

### 2.4 Forgot Password Screen `/auth/forgot-password`

**Elements:**
- Back arrow
- "Reset your password" heading
- "Enter the email you registered with"
- Email input
- "Send Reset Link" button (primary)

**States:**
- **Loading:** Button spinner
- **Success:** Replaces form with: "Check your email. If [email] is registered, you'll receive a reset link." + "Back to Login" button
- **Error (invalid email format):** Inline field error

---

### 2.5 Reset Password Screen `/auth/reset-password/[token]`

**Elements:**
- "Create a new password" heading
- New password input (with strength indicator)
- Confirm password input
- "Update Password" button

**States:**
- **Token invalid/expired:** Full-screen error: "This link has expired. [Request a new one]"
- **Token valid:** Show form
- **Passwords don't match:** Inline: "Passwords don't match"
- **Success:** "Password updated!" → auto-redirect to `/auth/login` after 2s

---

## 3. Onboarding Screens

### 3.1 Step Progress

Top of all onboarding screens (except Welcome):
- Dots row: ● ○ ○ ○ (4 dots representing Steps 2–5)
- "Skip" button top-right (skips to next step or to Home if on last step)

### 3.2 Welcome `/onboarding/welcome`

- App logo (large, centered)
- "Meeple & Hearth" wordmark
- Tagline: "Track your games. Organize game nights. Build memories."
- Three feature teasers with icons (Library, Events, Matching)
- "Get Started" button (primary gradient, full-width)

### 3.3 Profile Setup `/onboarding/profile`

**Elements:**
- Avatar upload circle (tap to pick image)
  - Shows placeholder meeple avatar if no image
  - On tap: opens file picker (web) or image picker (Flutter)
  - After pick: shows cropped preview (1:1 crop)
- Display name input (required)
- Location input (optional, placeholder: "City, Country")
- "Continue" button
- "Skip" link

**States:**
- **Avatar uploading:** Spinner overlay on avatar circle
- **Avatar upload error:** "Upload failed. Try again." toast + fallback to placeholder

### 3.4 BGG Import `/onboarding/bgg-import`

**Elements:**
- BoardGameGeek logo + "Import your collection"
- "Enter your BGG username"
- BGG username input
- "Import Collection" button
- "Skip" link
- Privacy note: "We only read your public collection."

**States:**
- **Loading (import in progress):**
  - Shows animated progress: "Importing… 12 of 45 games"
  - Polls `GET /api/v1/me/bgg-import/status` every 2s
- **Success:** "Imported 42 games!" + preview of first 5 game covers in a horizontal row → "Continue"
- **BGG username not found:** Inline: "BGG username not found. Check the spelling."
- **BGG unavailable:** "BGG is currently slow. Skip for now and try again in Settings."

### 3.5 Find Friends `/onboarding/find-friends`

**Elements:**
- "Find your friends" heading
- `GET /api/v1/users/suggestions` renders up to 10 suggested user cards
- Each card: avatar, displayName, username, "X games in common", "Follow" button
- Search bar (triggers `GET /api/v1/users/search?q=...`)
- "Continue" button

**States:**
- **Loading:** 3 skeleton user cards
- **Empty (no suggestions):** "No suggestions yet. Search for friends by username."
- **After follow:** "Follow" button changes to "Following" chip (green) immediately (optimistic)

### 3.6 Add First Game `/onboarding/add-game`

**Elements:**
- "What do you love to play?" heading
- Game search input (calls `GET /api/v1/games/search?q=...`)
- Results grid (3-col game card thumbnails)
- Tapping a game: opens a quick-add sheet: "Add [Game Name] to your collection?" + "Add to Collection" button
- Skip link

**States:**
- **No search query:** Shows trending/popular games (curated list from DB or BGG "hot" endpoint)
- **Loading:** Skeleton game grid
- **No results:** "No games found for '[query]'"
- **After adding:** Confirmation toast: "Added to collection!"

---

## 4. Home Screen `/`

### 4.1 Layout

```
[TopAppBar: Search icon | "Meeple & Hearth" | Notifications icon]
[Greeting section]
[Match Suggestion Card — conditional]
[Upcoming Events row — conditional]
[Activity Feed — infinite scroll]
[BottomNav]
```

### 4.2 TopAppBar

- Left: `search` icon → opens Search overlay
- Center: "Meeple & Hearth" (primary color, font-black, tracking-tight)
- Right: `notifications` icon with unread badge (red dot with count, hidden if 0)

### 4.3 Greeting Section

```
"Good [morning/afternoon/evening], [displayName]!"
"Your next session is in X days."  ← from soonest upcoming event
"No upcoming events." ← if no events
```

Time of day threshold: morning 6–12, afternoon 12–18, evening 18–6.

### 4.4 Match Suggestion Card

- Shown ONLY if `GET /api/v1/matches/suggestions` returns ≥1 result
- Shows first (most recent) match suggestion
- Dismiss button (X): calls `POST /api/v1/matches/{id}/dismiss`
- "Create Event" button: navigates to `/events/create?matchGroupId=xxx` (pre-fills the form)
- Multiple suggestions: show as a horizontal scroll of cards or a count chip: "+2 more"

### 4.5 Upcoming Events Row

- Shown only if user has ≥1 upcoming event
- Hidden if no events (section collapses entirely — no empty state widget here)
- Horizontal scroll, 3 cards visible, peek of 4th
- "View Calendar" → `/events?view=calendar`

### 4.6 Activity Feed

**Loading state (skeleton):**
```
[Skeleton avatar circle 40px]  [Skeleton lines 2x]
[Skeleton rectangle 100% height 300px]  ← post image
[Skeleton line 80%]  ← caption
[Skeleton lines 2x]  ← 2 more skeleton cards below
```

**Empty state (zero follows, new user):**
```
[Illustration: two board game pieces, one waving at the other]
"Your feed is quiet."
"Follow friends to see what they're playing."
[Button: "Find Friends" → /onboarding/find-friends]
```

**Empty state (has follows but they've posted nothing):**
```
"Nothing new yet."
"Your friends haven't posted recently."
[Button: "Create a Post" → /posts/create]
```

**Error state (network failure):**
```
[Warning icon]
"Couldn't load your feed."
[Retry button]
```

**Infinite scroll:**
- Load 20 items at a time
- At 80% scroll depth: fetch next page
- "Loading more…" spinner at bottom during fetch
- "You're all caught up!" message when `hasMore = false`

---

## 5. Library Screen `/library`

### 5.1 Tab Layout

```
[Search bar — sticky]
[Tabs: All Games | My Collection | Wishlist | Favorites]
[Tab content — scrollable]
```

### 5.2 All Games Tab (BGG Search)

**Default state:** Show popular/trending games (hardcoded top 20 BGG IDs or "hot" endpoint)

**While typing (debounce 400ms):** "Searching…" placeholder

**Results:** 3-column grid of GameCards (thumbnail + name + year)

**Filter bar** (below search, horizontal scroll of chips):
- Players: `2+`, `3+`, `4+`, `5+`
- Duration: `< 30m`, `30-60m`, `1-2h`, `2h+`
- Category chips (Strategy, Family, Party, Cooperative)
- Weight: Light, Medium, Heavy

Filters apply client-side from search results (MVP simplification).

**States:**
- **Loading:** 9 skeleton game cards (3×3 grid)
- **No results:** "No games found for '[query]'. Try a different spelling."
- **BGG API error:** "Game database unavailable. Try again." + Retry

### 5.3 My Collection / Wishlist / Favorites Tabs

**Default state:** Alphabetically sorted grid (same GameCard component)
- Shows owned/wishlisted/favorited badge overlay on card

**States:**
- **Loading:** 6 skeleton cards
- **Empty (My Collection):**
  ```
  [Shelf illustration]
  "Your shelf is empty."
  "Search for games to add to your collection."
  [Button: "Browse Games" → switches to All Games tab]
  ```
- **Empty (Wishlist):**
  ```
  "No games on your wishlist yet."
  "Browse the library and add games you want."
  [Button: "Browse Games"]
  ```
- **Empty (Favorites):**
  ```
  "No favorites yet."
  "Favorite a game you love."
  ```

### 5.4 Game Detail `/library/games/[id]`

**Layout (top to bottom):**

**1. Hero section (400px tall):**
- Full-bleed game cover image
- Gradient fade: `bg-gradient-to-t from-surface via-surface/20 to-transparent`
- Bottom overlay: category badge, game title, designer/publisher, "Owned by X friends" avatar stack

**2. Game Info Bar:**
- 3-column grid: Players | Duration | Complexity
- Background: `surface-container-lowest` with ambient shadow
- Each cell: icon + label + value

**3. Action buttons:**
- "Add to Collection" — primary gradient full-width rounded-full
  - If already owned: "In Collection" chip (secondary-container) + "Remove" option on long-press
- "Wishlist" — secondary muted button
  - If already wishlisted: filled bookmark icon + "On Wishlist" label
- "AI Rules Assistant" — tertiary teal button (shows only if `hasRulebook = true`, grayed out with tooltip if false)
- All three can be active simultaneously (owned + wishlisted + favorited)

**4. Tabs: Overview | Reviews | Sessions | Friends**

**Overview tab:**
- BGG description (truncated to 3 lines, "Read more" toggle)
- Categories (chips)
- Mechanics (chips)
- BGG Average Rating (gold star + number)
- Friend Average Rating (if ≥1 friend has rated: avatar stack + "X.X avg from N friends")

**Reviews tab:**
- List of friends' (mutual follows) personal ratings + notes
- Each: avatar + name + star rating + note (if any) + "X plays"
- Empty: "No reviews from friends yet."

**Sessions tab:**
- Posts tagged with this game (feed style, compact)
- Empty: "No sessions logged yet."

**Friends tab:**
- Mutual follows who own this game
- Each: avatar + name + play count + personal rating
- Empty: "None of your friends own this yet."

**States:**
- **Loading:** Skeleton hero (gray 400px rectangle) + skeleton info bar + skeleton buttons
- **Game not found (404):** "This game doesn't exist or was removed." + Back button

---

## 6. Events Screen `/events`

### 6.1 View Toggle

```
[TopAppBar: Back | "Events" | Calendar icon]
[Toggle: List | Calendar]
[Content]
[FAB: "Create Event"]
```

### 6.2 List View

**Tabs:** Upcoming | Past

**Upcoming list:**
- Sorted ascending by `scheduled_at`
- Each EventCard: game thumbnail, event title, host avatar + name, date/time, location, participant count bar (X/Y), status chip

**Past list:**
- Sorted descending by `scheduled_at`
- Same EventCard, muted appearance (`opacity-70`)

**States:**
- **Loading:** 3 skeleton EventCards
- **Empty (upcoming):**
  ```
  [Illustration: calendar with game pieces]
  "No upcoming events."
  "Host your next game night!"
  [Button: "Create Event"]
  ```
- **Empty (past):**
  ```
  "No past events."
  "Your game night history will appear here."
  ```

### 6.3 Calendar View

- Monthly calendar (7-column grid)
- Days with events: colored dot below the date (primary color)
- Tapping a date with events: opens a bottom sheet listing events for that day
- Navigation: prev/next month arrows
- Today: highlighted with `primary` background circle

### 6.4 Event Detail `/events/[id]`

**Layout:**
```
[Hero: game art or gradient placeholder, 280px]
  [Gradient fade]
  [Event title overlaid]
[Host row: avatar + "Hosted by [Name]" + Follow button if not following]
[Info cards: Date/Time | Location | Players (X/Y)]
[Status chip: Open / Full / Completed / Cancelled]
[Description (if any)]
[Participants section: avatar grid + "Join" button or status]
[Action bar: Join / Leave / Manage (host)]
[Activity section: comments/updates (Phase 2)]
```

**RSVP action bar states:**
| My status | Button shown |
|-----------|-------------|
| Not invited | (no button — private events) |
| Invited | "Accept" + "Decline" |
| Accepted | "Leave Event" |
| Declined | "Change to Going" |
| Event full + not joined | "Event is Full" (disabled) |
| Host | "Manage Event" dropdown |

**"Manage Event" dropdown (host only):**
- Edit event
- Cancel event
- View participant list (with kick option per participant)

**States:**
- **Loading:** Skeleton hero + skeleton info cards
- **Event cancelled:** Banner at top: "This event has been cancelled." (all action buttons hidden)
- **Event completed:** Banner: "This event has ended." + "View Memories" button (→ posts tagged to this event)
- **Event not found:** "This event doesn't exist or was removed."

### 6.5 Create Event `/events/create`

**Layout:** Full-page form with sticky "Create Event" button at bottom

**Fields:**

1. **Game** (tap to search)
   - Shows: game thumbnail + name when selected
   - "Add without a game" option

2. **Event Title** (text input, auto-fills with game name + "Night" if game selected)

3. **Date & Time**
   - Date: calendar picker
   - Time: time picker (30-min increments)
   - Shows: "Saturday, April 5 · 7:00 PM"

4. **Location** (text input, placeholder: "Address, venue name, or 'Online'")

5. **Max Players** (number input or +/- stepper, 2–50, default 8)

6. **Invite Friends** (multi-select)
   - Shows mutual follows as a scrollable list with checkboxes
   - Search to filter
   - Shows selected as avatar chips above the list

7. **Description** (optional, textarea, max 1000 chars, char counter)

**States:**
- **Date in the past:** Inline: "Please choose a future date."
- **Loading (submit):** Button spinner + "Creating…"
- **Error:** Toast with error message
- **Success:** Redirects to `/events/{newEventId}` with success toast: "Event created! Invites sent."

**Pre-fill from match:** If `?matchGroupId=xxx` param exists, auto-fill game + invited friends from the match group.

---

## 7. Posts & Memories

### 7.1 Create Post `/posts/create`

**Layout:** Full-page form

**Step 1 — Images (optional):**
- Large image picker area with dashed border
- "Add Photos" button + camera icon
- Web: `<input type="file" multiple accept="image/*">`
- Flutter: `image_picker` with gallery + camera options
- After picking: horizontal scroll of image previews with X to remove each
- Reorder: drag-and-drop on web, long-press drag on Flutter
- Max 10 images counter: "3/10"
- Each image shows compression progress: "Compressing…" → compressed size shown

**Step 2 — Details:**
- Caption input (textarea, `bg-surface-container-highest`, no border, 2000-char counter)
- Game tag: search + select (shows game chip when selected, tap to remove)
- Tag friends: multi-select from mutual follows (shows avatar chips)
- Location: text input
- Date played: date/time picker (defaults to "now", can be set to past)

**Unsaved changes guard:**
- If user tries to navigate away with content filled: "Discard this post?" modal with "Discard" and "Keep Editing" options

**States:**
- **Compressing images:** Progress bar below each thumbnail
- **Uploading:** "Uploading 2/5 images…" progress indicator
- **Upload error:** "Image upload failed. Tap to retry." on the failed thumbnail
- **Submitting:** Button spinner
- **Success:** Navigates to Home feed with "Posted!" toast

### 7.2 Post Detail `/posts/[id]`

**Layout:**
```
[TopAppBar with back + share icon]
[Post author row: avatar + name + timestamp + location]
[Image carousel (if images)]
[Action bar: like + comment + share + bookmark]
[Like count + "Liked by [Name] and X others"]
[Caption: full, untruncated]
[Game chip (if tagged)]
[Tags section: "With: [avatars]"]
[Divider]
[Comments section: flat list]
[Comment input: pinned at bottom above keyboard]
```

**Image carousel:**
- Swipe between images
- Dot indicators below
- Tap to view fullscreen (pinch-to-zoom)

**States:**
- **Loading:** Skeleton post header + skeleton image + skeleton caption
- **Post not found:** "This post has been removed."
- **No comments:** "Be the first to comment!"
- **Comments loading:** 3 skeleton comment rows

### 7.3 Feed Item (Post Card in Feed)

**Compact version (feed):**
- Author avatar + name + "X hours ago" + "· Location"
- Image (single, square aspect ratio, or carousel indicator for multiple)
- Action bar (like, comment, share)
- Like count
- Caption (truncated to 3 lines, "more" link)
- "View X comments" link → tapping opens Post Detail

**Activity item (compact):**
```
[Avatar 40px] [Name] added [Game name in italic primary color] to their collection.
              [10px ago · From Library]
```

---

## 8. Profile Screens

### 8.1 Own Profile `/profile`

**Layout:**
```
[TopAppBar: [Avatar 32px] "The Social Tabletop" | Notifications icon]
[Hero: Avatar (rotated 3deg) + Verified badge]
[Name + location]
[Follow/Following counts]
[Stats Bento: Games Owned | Sessions | Friends]
["Edit Profile" button + "···" menu]
[Favorite Games — horizontal scroll]
[Tabs: Posts | Tagged | Collection]
```

**"···" menu:** Share profile, Settings, Log out

**Stats bento:** 3 cards in a row. Middle card has `border-l-4 border-primary` for emphasis.

**Favorite Games scroll:** Shows games where `is_favorited = true`. Empty state: "No favorites yet. Star a game you love."

**Posts tab:** Grid of post thumbnails (3-column). Tap → Post Detail.

**Tagged tab:** Posts where user was tagged. Same grid.

**Collection tab:** Short list view of owned games. "See all →" link to `/library?filter=collection`.

### 8.2 Other User Profile `/profile/[id]`

Same as own profile but:
- Replace "Edit Profile" with "Follow / Following" button
- Show "Message" button (Phase 2 — DMs)
- Show "···" menu with: Block, Report
- If viewer has blocked this user or is blocked: this route returns 404

**Follow button states:**
| State | Button |
|-------|--------|
| Not following | "Follow" (primary gradient) |
| Following | "Following" (muted, secondary-container) |
| Mutual follows | "Friends" with checkmark (tertiary chip) |
| Following (tap) | Shows "Unfollow?" confirmation inline |

### 8.3 Followers / Following Lists `/profile/[id]/followers` and `/following`

- Simple list: avatar + displayName + username + follow/unfollow button per row
- **Loading:** 5 skeleton rows
- **Empty:** "No followers yet." / "Not following anyone yet."

---

## 9. Notifications Screen `/notifications`

**Layout:**
```
[TopAppBar: Back | "Notifications" | "Mark all read" (text button, top right)]
[Grouped list: Today | This Week | Earlier]
```

**Notification row:**
- Sender avatar (left)
- Title + body (right)
- Timestamp (right corner, small)
- Blue dot (left edge) if unread
- Background: `surface-container-low` if unread, `surface` if read

**Actions:**
- Tap anywhere: navigate to `data.path` + mark as read
- Swipe left (mobile): "Mark as read" action (teal) + "Delete" action (red)

**States:**
- **Loading:** 5 skeleton notification rows
- **Empty:**
  ```
  [Checkmark circle illustration]
  "You're all caught up!"
  "Notifications will appear here."
  ```

---

## 10. Matching Screen (embedded in Home or `/matching`)

### 10.1 Match Request Form

Accessible via: Home → "Find Players" button, or FAB → "Find Match"

**Fields:**
- Game: search + select (required)
- Available from: date/time picker
- Available until: date/time picker
- "Let's Play!" submit button

**Active requests list** (below form):
- Each request: game name + "Available [date range]" + "Cancel" button
- Empty: "No active match requests."

**Match suggestion cards** (separate section):
- Each pending match group: "[N] friends want to play [Game]" card
- "Create Event" + "Dismiss" buttons

---

## 11. Settings `/settings`

### 11.1 Settings Root

List layout with section headers:

```
ACCOUNT
  › Edit Profile
  › Change Email
  › Change Password
  › BGG Import
  › Active Sessions
  › Delete Account

NOTIFICATIONS
  › Notification Preferences
  › Quiet Hours

PRIVACY
  › Privacy Settings (greyed out in MVP)

APPEARANCE
  › Theme (Light / Dark / System) — Light active, others greyed

ABOUT
  › App Version: 1.0.0
  › Terms of Service →
  › Privacy Policy →
  › Send Feedback →
  › Rate the App → (Flutter only)
```

### 11.2 Edit Profile `/settings/profile`

- Avatar (tap to change)
- Display name
- Username (shows "Can change in X days" if changed recently)
- Bio (textarea, 200-char counter)
- Location
- "Save" button (sticky at bottom)

### 11.3 Notification Preferences `/settings/notifications`

Table of toggles per type:
```
                          In-App    Push
Event Invites             [ON]      [ON]
Match Found               [ON]      [ON]
New Follower              [ON]      [OFF]
Post Liked                [ON]      [OFF]
Post Comment              [ON]      [ON]
Comment Mention           [ON]      [ON]
Post Tagged               [ON]      [ON]
Event Reminders           [ON]      [ON]
Friend Activity           [ON]      [OFF]
```

**Quiet Hours toggle:**
- "Do Not Disturb" toggle
- Time range pickers (start / end) — enabled when toggle is ON
- "Push notifications paused during quiet hours"

### 11.4 Active Sessions `/settings/sessions`

List of `refresh_tokens` for current user:
- Device info string + platform icon (web/mobile)
- "Last active: X hours ago"
- "This device" badge on current session
- "Sign Out" button per row (disabled for current session)
- "Sign Out All Other Devices" button at bottom

### 11.5 Delete Account `/settings/delete-account`

- Warning text explaining consequences (30-day grace period, data handled, etc.)
- Password confirmation input
- "Delete My Account" button (error/red color)
- Confirmation modal: "Are you absolutely sure? This will delete your account. You have 30 days to reactivate."

---

## 12. AI Rules Assistant (Modal Overlay)

**Trigger:** Tap "AI Rules Assistant" button on Game Detail

**Layout:** Bottom sheet, draggable, up to 80% screen height

```
[Handle bar]
[Header: smart_toy icon | "[Game Name] Rules Assistant" | Close X]
[Disclaimer: "AI-generated answers may not be 100% accurate."]
[Chat area: messages (Q+A pairs)]
[Input bar: "Ask a question..." | Send button]
```

**Message bubble styles:**
- User question: right-aligned, `bg-primary text-on-primary`
- AI answer: left-aligned, `bg-surface-container-low text-on-surface`
- Loading (answer generating): left-aligned bubble with "..." typing indicator

**States:**
- **No rulebook:** Shows centered message: "No rulebook available for [Game Name] yet." + "Request Rulebook" button
- **Rate limit hit:** "You've reached the 20 questions/day limit. Resets at midnight UTC."
- **AI error:** "Something went wrong. Try again."
- **Empty (first open):** Quick-start prompts: "How do you win?", "Setup instructions", "What happens on your turn?" (tapping inserts question into input)

---

## 13. Search Overlay

**Trigger:** Tap search icon in TopAppBar

**Layout:** Full-screen overlay (slides down from top)

```
[Search input with X to close]
[Recent searches]  ← shows when input is empty
[Results:]
  Games: [3 game cards]
  Players: [3 user rows]
  Events: [2 event rows]
```

**States:**
- **Empty input:** Recent searches + "Search for games, players, or events"
- **Typing:** Results appear live, debounced 400ms
- **No results:** "No results for '[query]'"
- **Loading:** Skeleton rows per category

---

## 14. Global Components

### 14.1 Toast / Snackbar (via svelte-sonner)

**Position:** Bottom center on mobile (above BottomNav), top right on desktop

**Types:**
- Success: `bg-tertiary text-on-tertiary` — "Game added to collection!"
- Error: `bg-error text-on-error` — "Failed to join event."
- Info: `bg-inverse-surface text-inverse-on-surface` — "Event reminder set."
- Duration: 3s for success, 5s for errors (user needs time to read)

**Rules:**
- Always shown for: successful create/delete actions, error states from API
- Never shown for: routine navigation, passive reads, like/unlike (handle those with UI state only)

### 14.2 Confirmation Dialogs

Used for: Cancel event, Delete post, Delete account, Kick participant, Block user

**Layout:** Bottom sheet (not centered modal — feels more native)

```
[Handle]
[Icon + "Are you sure?" heading]
[Consequence text]
[Confirm button (red for destructive, primary for neutral)]
[Cancel button (ghost)]
```

### 14.3 Loading Spinner

- Full-screen: for initial page loads (auth check, onboarding redirect)
  - Centered large spinner on `bg-background`
  - "Loading…" text below
- Inline: for button loading states (small spinner replaces button text)
- Overlay: for blocking operations (import, upload)
  - Semi-transparent `bg-surface/80` over content + centered spinner

### 14.4 Offline Banner

- Slim `h-8` banner pinned below TopAppBar
- `bg-on-surface text-inverse-on-surface`
- Text: "No internet connection"
- Automatically hides when connection restored (with a brief "Back online ✓" flash)

### 14.5 Pull-to-Refresh

Implemented on: Home feed, Events list, Notifications, Profile posts tab

- On pull: spinner appears below AppBar
- Triggers refetch of first page
- Implemented with SvelteKit: listen to `touchstart`/`touchmove`/`touchend` events + CSS transform on the scroll container

### 14.6 Skeleton Screen Patterns

**Standard post card skeleton:**
```
[Circle 40px] [Lines: 120px | 80px]
[Rectangle full-width 300px]
[Lines: 60px | 140px | 90px]
```

**Game card skeleton:**
```
[Rectangle 4:3 aspect]
[Line 80px]
[Line 50px]
```

**User row skeleton:**
```
[Circle 48px] [Lines: 100px | 70px] [Rectangle 80px (button)]
```

All skeleton elements use `bg-surface-container` with a shimmer animation:
```css
@keyframes shimmer {
  0% { background-position: -1000px 0; }
  100% { background-position: 1000px 0; }
}
.skeleton {
  background: linear-gradient(90deg,
    #EDEEEF 25%, #F3F4F5 50%, #EDEEEF 75%);
  background-size: 1000px 100%;
  animation: shimmer 1.5s infinite linear;
}
```

---

## 15. Navigation Edge Cases

### 15.1 Notification Deep Link Navigation

When the user opens the app from a push notification:
- App is killed: starts fresh, navigates directly to `data.path`
- App is in background: resume, navigate to `data.path`
- App is in foreground: show in-app notification banner, tap to navigate

Back button after deep-link jump:
- `/events/123` arrived from notification → back → `/events` (events list root, not browser history back)
- `/posts/456` arrived from notification → back → `/` (home feed)
- Rule: always navigate to the logical parent when deep-linked

### 15.2 Redirect After Login

- User visits `meeple-hearth.com/events/123` while unauthenticated
- SvelteKit redirects to `/auth/login?redirect=/events/123`
- After login: redirect to `/events/123`
- Implemented: store `redirectTo` in URL param, read in auth callback

### 15.3 Onboarding Check

On every authenticated page load, `+layout.server.ts` checks:
1. Is user authenticated? (valid cookie) — if no: redirect to `/auth/login`
2. Is `onboarding_completed = false`? — if yes: redirect to `/onboarding/welcome`
3. Otherwise: proceed normally

### 15.4 Tab Memory (per-tab scroll position)

- Home tab: store `scrollY` in a Svelte store; restore on return
- Library tab: store selected tab + search query + scroll position
- Events tab: store view mode (list/calendar) + selected filter
- Profile tab: store scroll position

---

## 16. Responsive Breakpoints

App is mobile-first (`max-w-lg mx-auto` content width = 512px).

| Breakpoint | Layout |
|-----------|--------|
| Mobile (`< 768px`) | Full-width, BottomNav |
| Tablet (`768px–1024px`) | `max-w-xl`, BottomNav or sidebar |
| Desktop (`> 1024px`) | `max-w-2xl`, left sidebar nav (Phase 2) |

**Phase 1:** Only mobile layout. Content is `max-w-lg mx-auto` centered with `bg-background` fill on wider screens. No desktop-specific layout.
