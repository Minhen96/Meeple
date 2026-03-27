# Meeple & Hearth — Design System

## 1. Creative North Star: "The Curated Playroom"

The design philosophy moves away from sterile utility-app grids. Instead, it blends:
- The **warmth** of a high-end editorial magazine
- The **tactile invitation** of a modern board game café
- A **"Notion meets Airbnb" vibe**: structured and clean, yet deeply human

Key visual principles:
- **Intentional asymmetry** — layouts feel hand-assembled, not templated
- **Tonal depth** — depth through color layering, not borders or shadows
- **Generous whitespace** — even complex game data feels light
- **Editorial scale** — large type creates "chapters" in the UI

App name displayed as: **Meeple & Hearth**

---

## 2. Color System

The palette is rooted in sun-drenched ambers and soft neutrals — evoking the "golden hour" of a social gathering.

### Full Token Reference

| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | `#895100` | Core actions, links, active states |
| `primary-container` | `#FF9F1C` | Button gradients, highlights |
| `primary-fixed` | `#FFDCBC` | Subtle primary tints |
| `primary-fixed-dim` | `#FFB86B` | Dimmed primary tints |
| `on-primary` | `#FFFFFF` | Text on primary buttons |
| `on-primary-container` | `#683C00` | Text on primary-container backgrounds |
| `on-primary-fixed` | `#2C1700` | Text on primary-fixed |
| `on-primary-fixed-variant` | `#683D00` | Variant text on primary-fixed |
| `secondary` | `#835401` | Supporting accents, secondary buttons |
| `secondary-container` | `#FDBD68` | Status chips, secondary highlights |
| `secondary-fixed` | `#FFDDB5` | Subtle secondary tints |
| `secondary-fixed-dim` | `#FABB65` | Dimmed secondary |
| `on-secondary` | `#FFFFFF` | Text on secondary buttons |
| `on-secondary-container` | `#764B00` | Text on secondary-container |
| `on-secondary-fixed` | `#2A1800` | Text on secondary-fixed |
| `on-secondary-fixed-variant` | `#643F00` | Variant text on secondary-fixed |
| `tertiary` | `#006A62` | AI features, success states, special categories |
| `tertiary-container` | `#36C9BB` | AI button backgrounds |
| `tertiary-fixed` | `#70F8E8` | Subtle teal tints |
| `tertiary-fixed-dim` | `#4FDBCC` | Dimmed teal |
| `on-tertiary` | `#FFFFFF` | Text on tertiary buttons |
| `on-tertiary-container` | `#005049` | Text on tertiary-container |
| `on-tertiary-fixed` | `#00201D` | Text on tertiary-fixed |
| `on-tertiary-fixed-variant` | `#005049` | Variant text on tertiary-fixed |
| `background` | `#F8F9FA` | Page background (warm off-white, NOT pure white) |
| `surface` | `#F8F9FA` | Default surface (same as background) |
| `surface-bright` | `#F8F9FA` | Bright surface variant |
| `surface-dim` | `#D9DADB` | Dimmed/subtle surface |
| `surface-container-lowest` | `#FFFFFF` | Cards on surface (pure white lift) |
| `surface-container-low` | `#F3F4F5` | Slightly elevated containers |
| `surface-container` | `#EDEEEF` | Standard containers |
| `surface-container-high` | `#E7E8E9` | Higher elevation containers |
| `surface-container-highest` | `#E1E3E4` | Highest elevation (inputs, chips) |
| `surface-tint` | `#895100` | Tint overlay color |
| `surface-variant` | `#E1E3E4` | Alternative surface |
| `on-background` | `#191C1D` | Body text on background |
| `on-surface` | `#191C1D` | Body text on surface |
| `on-surface-variant` | `#544434` | Muted/secondary text |
| `inverse-surface` | `#2E3132` | Dark snackbar/toast backgrounds |
| `inverse-on-surface` | `#F0F1F2` | Text on inverse-surface |
| `inverse-primary` | `#FFB86B` | Primary color on dark surfaces |
| `outline` | `#877462` | Subtle borders (use sparingly) |
| `outline-variant` | `#DAC2AE` | Ghost borders, divider alternatives |
| `error` | `#BA1A1A` | Error states |
| `error-container` | `#FFDAD6` | Error backgrounds |
| `on-error` | `#FFFFFF` | Text on error buttons |
| `on-error-container` | `#93000A` | Text on error-container |

### Key Semantic Rules

**Background colors (layering order, lowest to highest):**
```
background (#F8F9FA)
  └─ surface-container-low (#F3F4F5)
       └─ surface-container (#EDEEEF)
            └─ surface-container-high (#E7E8E9)
                 └─ surface-container-highest (#E1E3E4)
                      └─ surface-container-lowest (#FFFFFF) ← cards that "float"
```

**Primary gradient (for buttons and CTAs):**
```css
background: linear-gradient(to right, #895100, #FF9F1C);
```

**Glass/blur (for nav, modals, floating elements):**
```css
background: rgba(248, 249, 250, 0.80);
backdrop-filter: blur(24px);
```

---

## 3. The No-Line Rule

**Never use 1px solid borders for structural separation.**

Structural boundaries must be created ONLY through:
1. **Background color shifts** — place `surface-container-low` against `surface` background
2. **Tonal transitions** — nest containers using the surface token hierarchy
3. **Ghost Border Fallback** — if accessibility absolutely requires a stroke, use `outline-variant` at **15% opacity** (felt, not seen)

**Wrong:**
```html
<div class="border border-gray-300">...</div>
```

**Right:**
```html
<div class="bg-surface-container-low rounded-xl">...</div>
```

---

## 4. Typography

### Typefaces
| Role | Font | Google Fonts |
|------|------|-------------|
| Headlines, body, display | **Plus Jakarta Sans** | `wght@400;500;600;700;800` |
| Labels, data, technical text | **Manrope** | `wght@400;500;600;700` |

**Google Fonts import:**
```html
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:ital,wght@0,400;0,500;0,600;0,700;0,800;1,400;1,700&family=Manrope:wght@400;500;600;700&display=swap" rel="stylesheet"/>
```

### Tailwind Font Families
```js
fontFamily: {
  "headline": ["Plus Jakarta Sans"],
  "body": ["Plus Jakarta Sans"],
  "label": ["Manrope"],
}
```

### Type Scale Usage

| Scale | Class | Usage |
|-------|-------|-------|
| Display Large | `text-5xl font-extrabold tracking-tight font-headline` | Win screens, hero moments |
| Display Medium | `text-4xl font-extrabold tracking-tight font-headline` | Profile name, hero titles |
| Headline Large | `text-3xl font-extrabold tracking-tight font-headline` | Page greeting ("Good evening") |
| Headline Medium | `text-2xl font-bold font-headline` | Section titles |
| Headline Small | `text-xl font-bold font-headline` | App bar brand name |
| Title Large | `text-lg font-bold font-headline` | Card titles, event names |
| Title Medium | `text-base font-semibold` | Sub-headers |
| Body Large | `text-base` | Post captions, descriptions |
| Body Medium | `text-sm` | Feed text, form labels |
| Body Small | `text-xs` | Supporting text |
| Label Large | `text-sm font-bold font-label` | Button text, tab labels |
| Label Medium | `text-xs font-bold font-label uppercase tracking-widest` | Stat labels, category chips |
| Label Small | `text-[10px] font-bold font-label` | Timestamps, micro-labels |

**Key rule:** Use `-2%` letter spacing (`tracking-tight`) on Display sizes for editorial feel.

---

## 5. Border Radius

```js
borderRadius: {
  "DEFAULT": "1rem",   // 16px — standard cards, inputs
  "lg": "2rem",        // 32px — top-level containers, hero sections
  "xl": "3rem",        // 48px — full buttons (pill shape)
  "full": "9999px",    // Avatars, chips, FAB
}
```

**Nesting rule:** Use `rounded-lg` (2rem) for top-level containers, `rounded-xl` (1.5rem, default) for nested elements inside. This "nested rounding" creates organic, sophisticated flow.

**Nothing less than `rounded` (16px).** Sharp corners are prohibited.

---

## 6. Elevation & Depth

Depth is achieved through **tonal layering**, not drop shadows.

### The Layering Principle
Treat the UI as stacked sheets of fine cardstock:
- A `surface-container-lowest` card sitting on a `surface-container-low` background creates natural lift
- No explicit shadows needed for standard cards

### When to Use Ambient Shadows
Only for truly "floating" elements (FAB, modals, sticky headers):
```css
box-shadow: 0 12px 32px rgba(25, 28, 29, 0.06);
/* Tailwind: shadow-[0_12px_32px_rgba(25,28,29,0.06)] */
```

### Primary action shadow (for gradient buttons):
```css
box-shadow: 0 8px 24px rgba(137, 81, 0, 0.20);
/* Tailwind: shadow-[0_8px_24px_rgba(137,81,0,0.20)] */
```

---

## 7. Glassmorphism

Used for: top nav bar, bottom nav bar, modals, floating action sheet.

```css
background: rgba(248, 249, 250, 0.80);   /* surface at 80% opacity */
backdrop-filter: blur(24px);
-webkit-backdrop-filter: blur(24px);
```

**Tailwind:**
```html
<nav class="bg-[#F8F9FA]/80 backdrop-blur-xl shadow-[0_12px_32px_rgba(0,0,0,0.06)]">
```

---

## 8. Animation & Interaction

### Spring Bounce (all interactive elements)
```css
/* Active/press state */
transform: scale(0.95);
transition: all 0.15s cubic-bezier(0.4, 0, 0.2, 1.2);

/* Tailwind utility class: */
.spring-bounce:active { transform: scale(0.95); transition: all 0.15s cubic-bezier(0.4, 0, 0.2, 1.2); }
```

### Hover Lift (buttons, cards with actions)
```css
transform: scale(1.02);
/* Tailwind: hover:scale-[1.02] */
```

### Icon interactions
```css
transition: transform 0.2s ease;
/* Hover: hover:scale-105 */
```

### Ease Spring (for list animations, sheet reveals)
```css
transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1.2);
```

---

## 9. Component Library

### Primary Button (Gradient CTA)
```html
<button class="bg-gradient-to-r from-primary to-primary-container text-on-primary
               py-4 px-8 rounded-full font-headline font-bold text-lg
               shadow-[0_8px_24px_rgba(137,81,0,0.20)]
               hover:scale-[1.02] active:scale-95 transition-all">
  Create Event
</button>
```

### Secondary Button (Muted)
```html
<button class="bg-surface-container-high text-on-surface-variant
               py-4 px-8 rounded-full font-headline font-bold text-lg
               hover:bg-surface-container-highest active:scale-95 transition-colors">
  Wishlist
</button>
```

### Tertiary Button (AI / Teal)
```html
<button class="bg-tertiary-container text-on-tertiary-container
               py-4 px-8 rounded-full font-headline font-bold text-lg
               hover:bg-tertiary-container/80 active:scale-95 transition-colors
               border border-tertiary/10">
  AI Rules Assistant
</button>
```

### Ghost Button (Glass effect)
```html
<button class="bg-white/50 backdrop-blur-md text-on-surface-variant
               px-4 py-2 rounded-lg text-xs font-bold
               border border-outline-variant/30 hover:bg-white transition-all">
  Join Them
</button>
```

### Top App Bar
```html
<header class="fixed top-0 w-full z-50 bg-[#F8F9FA]/80 backdrop-blur-xl
               shadow-[0_12px_32px_rgba(0,0,0,0.06)]">
  <div class="flex justify-between items-center px-6 py-4 w-full">
    <!-- left: back arrow or search icon -->
    <!-- center: brand name -->
    <h1 class="font-headline text-primary font-black tracking-tighter text-xl">
      Meeple &amp; Hearth
    </h1>
    <!-- right: notification / more icon -->
  </div>
</header>
```

### Bottom Navigation Bar
```html
<nav class="fixed bottom-0 w-full z-50 bg-[#F8F9FA]/80 backdrop-blur-xl
            shadow-[0_-4px_24px_rgba(0,0,0,0.04)]">
  <!-- Nav items: Home | Library | [FAB] | Events | Profile -->
</nav>
```
- 5 items with center FAB
- Active icon: filled + `text-primary`
- Inactive icon: outlined + `text-on-surface-variant`
- Labels: `text-[10px] font-label font-bold`

### Game Card (Grid/List)
```html
<div class="bg-surface-container-lowest rounded-xl overflow-hidden
            shadow-[0_12px_32px_rgba(25,28,29,0.06)] group cursor-pointer">
  <div class="aspect-[3/4] overflow-hidden">
    <img class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"/>
  </div>
  <div class="p-3">
    <h4 class="font-headline font-bold text-on-surface leading-tight">Game Title</h4>
    <p class="text-xs text-on-surface-variant font-label mt-1">Publisher</p>
  </div>
</div>
```

### Event Card (Horizontal Scroll)
```html
<div class="flex-shrink-0 w-64 bg-surface-container-low rounded-xl p-4
            border border-outline-variant/20 shadow-sm">
  <div class="flex justify-between items-start mb-3">
    <span class="bg-secondary-container text-on-secondary-container
                 px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-tighter">
      Friday Night
    </span>
  </div>
  <h4 class="font-bold text-base mb-1">Heavy Euro Night</h4>
  <p class="text-xs text-stone-500 flex items-center gap-1 mb-3">
    <span class="material-symbols-outlined text-[14px]">location_on</span>
    The Rookery Cafe
  </p>
  <!-- Avatar stack -->
</div>
```

### Status Chip
```html
<!-- Active/Open -->
<span class="bg-secondary-container text-on-secondary-container
             px-3 py-1 rounded-full text-xs font-bold font-label">
  Open
</span>

<!-- Completed -->
<span class="bg-surface-container-highest text-on-surface-variant
             px-3 py-1 rounded-full text-xs font-bold font-label">
  Completed
</span>
```

### Avatar Stack (overlapping)
```html
<div class="flex -space-x-2">
  <img class="w-6 h-6 rounded-full border-2 border-surface-container-low object-cover"/>
  <img class="w-6 h-6 rounded-full border-2 border-surface-container-low object-cover"/>
  <div class="w-6 h-6 rounded-full border-2 border-surface-container-low
              bg-surface-container-high flex items-center justify-center
              text-[8px] font-bold text-on-surface">
    +3
  </div>
</div>
```

### Input Field (Ghost style)
```html
<input class="w-full bg-surface-container-highest rounded-xl px-4 py-3
              text-on-surface placeholder:text-on-surface-variant
              focus:ring-2 focus:ring-primary/20 focus:outline-none
              font-body text-sm"/>
```
- No border by default
- On focus: `ring-primary/20` (ghost border at 20% opacity)
- Background: `surface-container-highest`

### Info Bar (Game Stats Grid)
```html
<div class="grid grid-cols-3 gap-1 bg-surface-container-lowest p-2 rounded-xl
            shadow-[0_12px_32px_rgba(0,0,0,0.06)]">
  <div class="flex flex-col items-center py-4 bg-surface-container-low rounded-lg">
    <span class="material-symbols-outlined text-primary mb-1">groups</span>
    <span class="font-label text-[10px] text-stone-500 uppercase tracking-widest font-bold">Players</span>
    <span class="font-headline font-bold text-on-surface">1-5</span>
  </div>
  <!-- repeat for Duration, Weight -->
</div>
```

### Stats Bento Grid (Profile)
```html
<div class="grid grid-cols-3 gap-4">
  <div class="bg-surface-container-low p-4 rounded-lg text-center">
    <p class="font-label text-[11px] font-bold uppercase tracking-widest text-secondary opacity-70">Games Owned</p>
    <p class="text-2xl font-extrabold font-headline">142</p>
  </div>
  <div class="bg-surface-container-low p-4 rounded-lg text-center border-l-4 border-primary">
    <!-- highlighted stat -->
  </div>
</div>
```

### Post Card (Feed)
```html
<div class="bg-white rounded-2xl border border-outline-variant/10 overflow-hidden shadow-sm">
  <!-- Header: avatar + name + timestamp -->
  <div class="p-4 flex items-center gap-3">...</div>
  <!-- Image: square aspect ratio -->
  <div class="aspect-square bg-surface-container-low overflow-hidden">
    <img class="w-full h-full object-cover"/>
  </div>
  <!-- Footer: actions + caption + comments -->
  <div class="p-4 space-y-2">
    <!-- like | comment | share -->
    <div class="flex items-center gap-4 text-on-surface-variant">
      <span class="material-symbols-outlined cursor-pointer hover:text-red-500 transition-colors">favorite</span>
      <span class="material-symbols-outlined cursor-pointer hover:text-primary transition-colors">chat_bubble</span>
      <span class="material-symbols-outlined cursor-pointer ml-auto">share</span>
    </div>
    <!-- caption -->
    <!-- comment count -->
  </div>
</div>
```

### Floating Action Button (FAB)
```html
<button class="w-14 h-14 bg-gradient-to-br from-primary to-primary-container
               rounded-full flex items-center justify-center
               shadow-[0_8px_24px_rgba(137,81,0,0.30)]
               hover:scale-110 active:scale-95 transition-all">
  <span class="material-symbols-outlined text-on-primary text-2xl">add</span>
</button>
```

### Match Suggestion Card (Home)
```html
<div class="bg-primary-container/10 border border-primary/10 rounded-2xl p-5 relative overflow-hidden group">
  <!-- Decorative blur orb -->
  <div class="absolute -right-4 -top-4 w-24 h-24 bg-primary/10 rounded-full blur-2xl
              group-hover:bg-primary/20 transition-colors"></div>
  <div class="flex gap-4 items-start relative z-10">
    <!-- game thumbnail -->
    <!-- match info + action buttons -->
  </div>
</div>
```

---

## 10. Icons

**Library:** Material Symbols Outlined (variable font)

```html
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&display=swap" rel="stylesheet"/>
```

**Base style:**
```css
.material-symbols-outlined {
  font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24;
}
```

**Filled icons** (for active nav states, special moments):
```css
font-variation-settings: 'FILL' 1, 'wght' 400, 'GRAD' 0, 'opsz' 24;
/* Tailwind inline: style="font-variation-settings: 'FILL' 1;" */
```

### Key Icons Used
| Purpose | Icon name |
|---------|-----------|
| Home | `home` |
| Library | `library_books` |
| Events | `event` |
| Profile | `person` |
| Notifications | `notifications` |
| Search | `search` |
| Add | `add` / `add_circle` |
| Back | `arrow_back` |
| Settings | `settings` |
| Location | `location_on` |
| Schedule | `schedule` |
| Players | `groups` |
| Complexity | `psychology` |
| Like | `favorite` |
| Comment | `chat_bubble` |
| Share | `share` |
| Bookmark/Wishlist | `bookmark` |
| Collection | `shelves` |
| AI assistant | `smart_toy` |
| More options | `more_horiz` / `more_vert` |
| Verified badge | `verified` |
| Star/Rating | `stars` |
| Filter | `tune` |
| Calendar | `calendar_month` |
| Game night | `sports_esports` |

---

## 11. Layout & Spacing

**Page container:**
```html
<main class="pt-24 px-4 max-w-lg mx-auto pb-32">
  <!-- pt-24: clears fixed header -->
  <!-- pb-32: clears fixed bottom nav -->
  <!-- max-w-lg: mobile-first, centered on larger screens -->
</main>
```

**Section spacing:** `space-y-8` between major sections on a page.

**Card internal padding:** `p-4` (1rem) standard, `p-5` (1.25rem) for featured cards.

**Scrollbar hiding (horizontal scroll rows):**
```css
.hide-scrollbar::-webkit-scrollbar { display: none; }
.hide-scrollbar { -ms-overflow-style: none; scrollbar-width: none; }
```

**Horizontal scroll rows:**
```html
<div class="flex gap-3 overflow-x-auto hide-scrollbar -mx-4 px-4">
  <!-- negative margin + padding = edge-to-edge scroll with visual padding -->
</div>
```

---

## 12. Hero Image Pattern (Game Detail, Event Detail)

```html
<div class="relative w-full h-[400px] overflow-hidden">
  <img class="w-full h-full object-cover"/>
  <!-- Gradient fade to page background -->
  <div class="absolute inset-0 bg-gradient-to-t from-surface via-surface/20 to-transparent"></div>
  <!-- Content overlaid at bottom -->
  <div class="absolute bottom-0 left-0 w-full px-6 pb-8">
    ...title, badges, meta...
  </div>
</div>
```

---

## 13. Page Backgrounds

- Default page: `bg-background` (`#F8F9FA`) — warm off-white, never pure white
- Cards that float: `bg-surface-container-lowest` (`#FFFFFF`) or `bg-white`
- Subtle sections: `bg-surface-container-low` (`#F3F4F5`)
- Game library / collection grid: `bg-surface` with card-level lift

---

## 14. Do's and Don'ts

**Do:**
- Use `bg-[#F8F9FA]` as the page base — the creamier off-white feels premium
- Use `font-headline font-extrabold tracking-tight` for all hero text
- Use `font-label` (Manrope) for all numerical data, stats, timestamps
- Use gradient buttons (`from-primary to-primary-container`) for primary CTAs
- Use `rounded-full` or `rounded-xl` for all interactive elements
- Add `hover:scale-105` and `active:scale-95` to all buttons
- Use glassmorphism for the nav bar and bottom sheet headers
- Use avatar stacks with `-space-x-2` and a `+N` overflow chip
- Show the primary color `#895100` for interactive text links

**Don't:**
- Don't use `border border-gray-300` or similar for layout separation
- Don't use sharp corners (`rounded-none` or `rounded-sm`) anywhere
- Don't use heavy drop shadows (`shadow-lg` with dark colors)
- Don't use pure white (`#FFFFFF`) as the page background
- Don't use `text-gray-500` — use `text-on-surface-variant` (`#544434`) for warm muted text
- Don't clutter — use surface nesting instead of adding more elements
- Don't use line dividers (`<hr>` or `border-b`) between list items — use spacing instead
- Don't use emoji in UI unless it's in user-generated content

---

## 15. Dark Mode (Future)

The Tailwind config includes `darkMode: "class"`. Dark mode tokens should be:
- `dark:bg-stone-900` for base background
- `dark:text-stone-100` for on-surface
- `dark:bg-stone-800/80` for glass nav
- Inverse primary: `#FFB86B` (token: `inverse-primary`)
- Inverse surface: `#2E3132` (token: `inverse-surface`)

**Phase 1:** Build light mode only. Wire up dark mode toggle in Phase 3.
