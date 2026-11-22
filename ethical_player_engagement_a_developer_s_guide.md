# Ethical Player Engagement: Findings & Developer's Guide

**Source Video:** [How to Keep Players Engaged (Without Being Evil)](https://www.youtube.com/watch?v=hbzGO_Qonu0)  
**Creator:** Mark Brown — *Game Maker's Toolkit (GMTK)*  
**Published:** April 6, 2018 | **Runtime:** 10:46  

---

## Executive Summary

Why do some games hold our attention all the way to the credits while others get abandoned on our backlog? While many modern titles rely on manipulative retention tactics—often referred to as "dark patterns"—to force habitual play, great games achieve lasting engagement through **intrinsic motivation, strong craftsmanship, and respect for the player's time**.

### Engagement vs. Addiction ("Evil" Design)
| Dimension | Ethical Engagement | Manipulative Addiction |
| :--- | :--- | :--- |
| **Core Driver** | Curiosity, mastery, flow, and genuine fun. | FOMO, obligation, compulsion, and variable-ratio conditioning. |
| **Common Mechanics** | Pacing, novelty, layered goals, fair challenge, system optimization. | Daily login streaks, energy timers, loot boxes, punishing players for stepping away. |
| **Player Feeling** | *"I want to see what happens next."* | *"I have to log in or I'll fall behind."* |

---

## Part 1: Compiled Findings (Chapter-by-Chapter Breakdown)

### 1. Pacing (`01:07`)
* **Core Finding:** Non-stop intensity leads to fatigue, while constant downtime leads to boredom. Effective games alternate between peaks of high tension and valleys of calm exploration, storytelling, or puzzle-solving.
* **Key Examples:** *Uncharted 2 & 4*, *DOOM (2016)*, *Titanfall 2*, *Resident Evil 4*, *Metro 2033*, *Vanquish*, *Dead Space 3*, *Celeste*.

### 2. Novelty (`03:11`)
* **Core Finding:** Humans crave new experiences. Introducing fresh mechanics, enemy types, environmental twists, or rule variations at regular intervals prevents the core loop from feeling repetitive.
* **Key Examples:** *Super Mario 3D World*, *Titanfall 2*, *A Hat in Time*, *Iconoclasts*, *The Witness*.

### 3. Anticipation (`03:44`)
* **Core Finding:** Giving players something to look forward to pulls them forward through the game. This can be spatial (showing a landmark or locked door early), mechanical (previewing an unlockable ability), or narrative (planting an intriguing mystery).
* **Key Examples:** *Metroid Prime 2: Echoes*, *Dark Souls*, *Bloodborne*, *Hollow Knight*, *Firewatch*, *Quantum Break*, *Inside*, *The Legend of Zelda: Twilight Princess*.

### 4. Goals (`05:36`)
* **Core Finding:** Players stay hooked when they always have a clear next objective. The strongest games layer **short-term, medium-term, and long-term goals** so they overlap—by the time one goal is finished, the player is already halfway through another.
* **Key Examples:** *Stardew Valley*, *Monster Hunter: World*, *Assassin's Creed: Origins*, *Horizon Zero Dawn*, *Far Cry 5*, *Middle-earth: Shadow of War*.

### 5. Positive Feedback Loops (`06:58`)
* **Core Finding:** When a player's effort yields rewards that directly empower their future actions (e.g., earning profit from crops to buy better tools and more seeds), progression feels tangible and snowballing.
* **Caveat:** Used in isolation without meaningful decisions, exponential growth can drift toward hollow clicker/idle addiction. It works best when paired with strategy and creativity.
* **Key Examples:** *Stardew Valley*.

### 6. Optimising Systems (`07:19`)
* **Core Finding:** Allowing players to build, tweak, and refine their own processes turns gameplay into an open-ended puzzle. The drive to make a system cleaner, faster, or more efficient is a powerful intrinsic motivator.
* **Key Examples:** *Factorio*, *Opus Magnum*.

### 7. Fantasising About the Future (`07:56`)
* **Core Finding:** Some of the most engaging games occupy the player's mind even when the controller is down. When systems are transparent and rich enough, players naturally daydream about their next farm layout, skill tree build, or factory redesign.
* **Key Examples:** *Stardew Valley*, *Factorio*, *Monster Hunter: World*.

### 8. Compelling Challenge (`08:18`)
* **Core Finding:** A well-calibrated challenge triggers the *"just one more try"* loop. When failure feels fair, understandable, and fast to recover from, players stay locked in a flow state trying to master the obstacle.
* **Key Examples:** *Celeste*, *Cuphead*, *Spelunky*, *Downwell*, *Hyper Light Drifter*, *Dark Souls*.

---

## Part 2: The Developer's Implementation Guide

Use the following actionable patterns to apply these eight pillars to your own game design.

### 1. Designing Rhythm & Pacing
* **Map an Intensity Curve:** Before building levels, sketch an intensity graph (1–10) across your campaign or session length. Ensure every major combat encounter or boss fight is followed by a "breather" (loot sorting, traversal, dialogue, or safe-room upgrades).
* **Vary Cognitive Load:** Switch between reflex-heavy gameplay (combat/platforming) and deliberate, low-pressure tasks (puzzles, exploration, inventory management).
* **Pitfall to Avoid:** *Pacing bloat*—if travel or downtime sections have nothing interesting to look at or interact with, shorten them or make movement itself fun.

### 2. Sustaining Novelty Without Feature Bloat
* **Use the 4-Step Nintendo Pattern:**
  1. Introduce a mechanic in a safe environment.
  2. Develop it with a moderate challenge.
  3. Twist it or combine it with an existing mechanic.
  4. Conclude with a climactic test, then move on.
* **Remix Before Adding:** You don't need 50 mechanics. Combining 5 well-designed mechanics in unexpected ways delivers high novelty at a fraction of the engineering cost.
* **Pitfall to Avoid:** Front-loading all your mechanics in the first hour and leaving the rest of the game to repeat the same scenarios.

### 3. Building Anticipation
* **Foreshadow Visually:** Place landmarks, boss arenas, or unreachable treasure in the player's line of sight early on (*"See that tower? You'll get there later."*).
* **Expose Locked Progression:** Show silhouettes of upcoming skills, locked crafting recipes, or sealed doors so players feel curiosity and momentum toward unlocking them.
* **Leave Narrative Breadcrumbs:** Raise small, answerable questions alongside your main mystery so players feel rewarded for paying attention.

### 4. Structuring Overlapping Goals
* **Design a 3-Tier Goal Stack:**
  * **Short-term (Seconds to Minutes):** Clear the next room, harvest today's crops, reach the next checkpoint.
  * **Medium-term (Minutes to Hours):** Craft a new armor set, finish a dungeon, upgrade a building.
  * **Long-term (Hours to Campaign):** Restore the Community Center, defeat the final boss, complete the map.
* **Stagger Completion Timers:** Never let all three tiers resolve at the exact same moment—that creates a natural "stopping point." Stagger them so finishing a medium-term goal immediately unlocks a tempting short-term goal.

### 5. Balancing Positive Feedback Loops
* **Tie Rewards to Agency:** Make sure resources earned unlock *new capabilities or choices* (e.g., sprinklers that free up time for mining), not just bigger damage numbers.
* **Introduce Soft Caps or New Sinks:** Prevent exponential growth from breaking your game's economy by introducing higher-tier challenges or creative sinks (e.g., aesthetics, base expansion, complex automation).

### 6. Enabling System Optimization
* **Expose Clear Metrics:** Give players visible feedback on bottlenecks, throughput, or efficiency (e.g., *Opus Magnum*'s cost/cycles/area histograms or *Factorio*'s production graphs).
* **Make Refactoring Frictionless:** If tearing down and rebuilding a setup is tedious or heavily penalized, players won't experiment. Allow free respecs, undo buttons, or easy deconstruction.

### 7. Sparking Future Fantasizing
* **Make Systems Legible:** Players can only plan ahead if they understand the rules. Let them inspect skill trees, upgrade paths, and crafting trees well before they can afford them.
* **Support Personal Expression:** Provide open canvases (base building, character loadouts, deckbuilding, farm layouts) where players can project their own identity and plans.

### 8. Crafting Compelling Challenges
* **Minimize Restart Friction:** Keep respawn times near-instant (like *Celeste* or *Super Meat Boy*). Long loading screens or unskippable cutscenes before a boss kill the *"one more try"* momentum.
* **Make Failure Readable:** Players should immediately understand *why* they died and *how* to avoid it next time. Telegraph enemy attacks clearly and keep hitboxes honest.
* **Provide Micro-Progress:** Even on a failed run, reward the player with knowledge, a shortcut unlocked, or a slightly better grasp of a boss phase.

---

## Part 3: Pre-Release Engagement Audit Checklist

Before shipping a vertical slice, beta, or full release, run your game through these diagnostic questions:

- [ ] **Ethical Check:** If a player takes a 3-day break, are they penalized or guilted when they return? *(Target: No)*
- [ ] **Pacing Check:** Does our playtest data show moments of exhaustion or prolonged boredom? Are peaks and valleys clearly separated?
- [ ] **Novelty Check:** Does the mid-game introduce new mechanical twists, enemy synergies, or environmental rules?
- [ ] **Anticipation Check:** Can a player name at least one upcoming area, upgrade, or mystery they are excited to reach?
- [ ] **Goal Stack Check:** At any given moment, does the player have an active short-term, medium-term, and long-term objective?
- [ ] **Restart Friction Check:** How many seconds pass between player death and regaining full control? *(Target: Under 2–3 seconds for action/platforming games)*
- [ ] **Agency & Planning Check:** Can players preview future upgrades or builds to plan their own progression path?