# Design System Document: The Social Tabletop

## 1. Overview & Creative North Star
**The Creative North Star: "The Curated Playroom"**

This design system moves away from the sterile, grid-heavy aesthetics of traditional utility apps. Instead, it adopts the warmth of a high-end editorial magazine blended with the tactile invitation of a modern board game cafe. We aim for a "Notion meets Airbnb" vibe: structured and clean, yet deeply human and approachable.

To break the "template" look, we prioritize **intentional asymmetry** and **tonal depth**. Rather than rigid columns, we use overlapping elements and varying "paper weights" to create a layout that feels assembled by hand. Large typographic scales and generous whitespace (breathing room) ensure that even complex game data feels light and manageable.

---

### 2. Colors & Surface Philosophy
The palette is rooted in sun-drenched ambers and soft neutrals, designed to evoke the "golden hour" of a social gathering.

*   **Primary (#895100 / #FF9F1C):** Used for core actions. It’s a sophisticated "Burnt Orange" that provides more depth than a standard neon orange.
*   **Secondary (#835401 / #FDBD68):** A "Sunny Harvest" yellow for supportive accents and secondary highlights.
*   **Tertiary (#006A62):** A "Deep Teal" used sparingly for contrast, such as success states or specialized game categories.

#### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders (`outline`) for sectioning. Structural boundaries must be defined solely through:
1.  **Background Color Shifts:** Placing a `surface-container-low` section against a `surface` background.
2.  **Tonal Transitions:** Using the hierarchy of `surface-container` tokens (Lowest to Highest) to "nest" importance.

#### The Glass & Gradient Rule
To achieve a premium feel, floating elements (modals, navigation bars) should utilize **Glassmorphism**. 
*   **Token:** `surface-container-lowest` at 80% opacity with a `24px` backdrop-blur.
*   **CTAs:** Use subtle linear gradients (e.g., `primary` to `primary-container`) to give buttons a "tactile glow" rather than a flat, plastic look.

---

### 3. Typography
We use **Plus Jakarta Sans** for its geometric yet friendly personality, paired with **Manrope** for high-performance labels.

*   **Display (Lg/Md/Sm):** Set in `plusJakartaSans`. Use these for hero game titles or high-impact social stats. They should feel "editorial" with tight tracking (-2%).
*   **Headline & Title:** These drive the narrative. Use `headline-md` for section headers to create a clear "chapter" feel in the UI.
*   **Body:** `plusJakartaSans` provides a clean, open counter-form that makes long rulebook snippets or game descriptions easy to digest.
*   **Labels:** `manrope` is used for technical data (player counts, playtimes) because of its exceptional legibility at small sizes.

---

### 4. Elevation & Depth
We reject the "drop shadow" of the 2010s. Depth is achieved through **Tonal Layering**.

*   **The Layering Principle:** Treat the UI as stacked sheets of fine cardstock. A `surface-container-lowest` card sitting on a `surface-container-low` background creates a natural, soft lift.
*   **Ambient Shadows:** If a card must "float" (e.g., a draggable meeple or game card), use an ultra-diffused shadow: `Y: 12px, Blur: 32px, Color: on-surface (6% opacity)`. This mimics natural light.
*   **The "Ghost Border" Fallback:** If accessibility requires a stroke, use `outline-variant` at **15% opacity**. It should be felt, not seen.

---

### 5. Components

#### Buttons & Interaction
*   **Primary Button:** Rounded at `full` or `xl` (3rem). Features the Primary-to-Container gradient. 
*   **State Change:** On hover, the button should "lift" (subtle shadow increase) and scale 2%.
*   **Micro-interaction:** Use a "spring" curve (0.4, 0, 0.2, 1.2) for all button presses to mimic the bounce of a game piece.

#### Cards & Lists
*   **No Dividers:** Forbid the use of horizontal lines. Use `spacing-6` (2rem) of vertical whitespace or a shift to `surface-container-high` to separate items.
*   **Corners:** Use `lg` (2rem) for top-level containers and `md` (1.5rem) for nested elements. This "nested rounding" creates a sophisticated, organic flow.

#### Social & Game Primitives
*   **Status Chips:** Use `secondary-container` for active game states. The text should be `on-secondary-container`.
*   **Input Fields:** Ghost-style inputs. Use `surface-container-highest` for the background with no border. On focus, transition to a `primary` "Ghost Border" (20% opacity).

#### Specialized Components
*   **The "Meeple Tracker":** A horizontal scroll of `surface-container-low` circles representing players, using `primary-fixed` for the current turn.
*   **The "Dice Tray":** A glassmorphic bottom sheet that utilizes `backdrop-blur` to show the game board underneath while rolling.

---

### 6. Do's and Don'ts

**Do:**
*   **Do** use asymmetrical margins (e.g., `spacing-8` on the left, `spacing-12` on the right) for editorial layouts.
*   **Do** use `plusJakartaSans` Display-Lg for "Win" or "Game Over" screens to celebrate the moment.
*   **Do** lean into the "Warm Neutral" background (`#F8F9FA`). Pure white is too sterile; this creamier white feels like a premium board game box.

**Don't:**
*   **Don't** use 1px solid black or grey borders. They break the "soft" social immersion.
*   **Don't** use sharp corners. Nothing in this system should be less than `sm` (0.5rem) rounded.
*   **Don't** clutter the screen. If a game has many stats, use `surface-container` nesting to group them, rather than lines or boxes.