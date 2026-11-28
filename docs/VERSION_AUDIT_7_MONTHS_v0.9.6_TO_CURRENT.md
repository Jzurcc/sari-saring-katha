# Sari-Saring Katha — 7-Month Version Audit (`v0.9.6-beta` → Current `v0.11.0+`)

**Baseline Version:** `v0.9.6-beta` (`78ff1a9`, April 24, 2026 — `config/version="0.9"`)  
**Audited Target:** `HEAD` on `feat/store-customization-upgrades` (`5be54cb`, November 28, 2026 — `config/version="0.11.0"`)  
**Total Delta:** **607 commits** · **1,233 files changed** · **`+71,013` insertions / `-41,257` deletions**

---

## 1. Executive Comparison: 7 Months Ago vs. Today

What began in April 2026 (`v0.9.6-beta`) as a single-slot, linear point-and-click store prototype with a fixed daily quota has evolved into a full-fledged **roguelite-infused Filipino neighborhood shopkeeping & folklore RPG**.

| Pillar | 7 Months Ago (`v0.9.6-beta` · Apr 2026) | Current Build (`v0.11.0+` · Nov 2026) |
| :--- | :--- | :--- |
| **Codebase Architecture** | Flat `Scripts/` + `Scripts/Managers/` monoliths (`StoryManager` handled clock, orders, dialogue, and saves) | Domain-driven bounded contexts (`Core`, `Data`, `Progression`, `Store`, `World`, `Audio`, `Cutscene`, `UI`, `Tools`) |
| **Cast Size & Stories** | 10 neighbors with linear, isolated early story timelines | **11 neighbors** (added **Lolo Pilo**) + **Papa Ulap** radio DJ; interconnected **Triangles A/B & Pairs 1/2** with `ChapterPrerequisite` ping-pong, fail-forward arcs, reactive hooks, and **New Vegas-style Epilogues** |
| **Reyna Mayari Nightly Loop** | Flat auto-deducted daily quota (`₱25 + ₱15 × (quota_day - 1)`); pass/fail binary | **`₱2,000` Silver Ledger** with player-chosen **Meager / Fair / Lavish** tribute gauge, **6 permanent Ledger Milestones**, and **62 Moon Cards** (32 Favors / 30 Omens) across 3 color-coded rarities |
| **Daily World Events** | Simple 45% Danilo-only verbal rumor roll | **Papa Ulap Counter Radio** + **33 Neighborhood Events** (Common / Uncommon / Rare, including pure-downside hardships) + **Today's Visitors** (`+120%` spawn boost) |
| **Pricing & Haggling** | Continuous scroll price margin; static complaint lines | Discrete **`-5..+5` Price Steps**, `[L]` **Price Ledger**, on-the-go **Alt Pricing Lens** with live modifier cards, unified **Price Tolerance** refusal math, and **Tawaran Card Duel** haggle minigame |
| **Customer Flow** | Strictly 1 customer at the counter at a time; linear slide-in/out | **Up to 3 simultaneous counter slots**, staggered waves, **Tambayan lingering & returning buyers**, **19 custom motion profiles**, and ambient background street cameos |
| **Store Upgrades** | Simple tier unlock counter (`purchase_counter`) ordered by phone | Full-screen cubic-Bezier **Upgrade Skill Tree (`[U]`)** culminating in **Open the Door**: Tiers `1–10`, Fridge (`Lv.1–3`), Mingming Cat, Tambayan Bench, Business Permit, Sto. Niño Altar, Maneki-Neko, Wholesale Pass + Sulit Deals, Trash/Recycling, and **Storefront Drawing Studio** |
| **Progression & Lore** | Basic Story Progress & Collection overlays | **Indefinite Player XP/Leveling** + **6-Rank Neighbor Reputation (`I–VI`)** with perks + **Folklore Journal Archive (`[J]`)** featuring 11 illustrated folklore entries, zoom lightbox, Counter Notes, and prerequisite hints |
| **Minigames** | None | **5 full minigames**: *Tawaran Card Duel*, *Dusk Lamp Mosquito Swat*, *Endless Sipa*, *Teks Memory*, and *Anting-Anting Talisman Tracing* |
| **Save System** | Single flat save file | **3-Slot Save Browser (`LoadSlotsOverlay`)** with rolling checkpoint backups, rollback support, and Main Menu 3D store mirroring |

---

## 2. Macro-Architecture & Codebase Overhaul (May & Nov 10–12, 2026)

Before building the November feature wave, the flat `v0.9.6-beta` script layout underwent a complete domain-driven refactoring (`114d794`, `1f3ed9e`):

- **Bounded Context Directory Reorganization:**
  - `Scripts/Core/` — `EventBus`, `SaveManager`, `LogManager`, `SceneTransitionManager`, `DialogicBridge`, `DialogueContextResolver`.
  - `Scripts/Data/` — `CustomerData`, `ChapterData` (consolidating parallel chapter arrays), `ItemData`, `StoreEventData`, `TransactionContext`, `CustomerMotionProfile`, `CustomerMotionStep`, and `Prerequisites/`.
  - `Scripts/Progression/` — `StoryManager`, `CharacterProgressionManager` (new autoload), `MayariCardRegistry`, `UpgradeTreeRegistry`, `FolkloreCatalog`, `EpilogueCatalog`.
  - `Scripts/Store/` — `InventoryManager`, `StoreEventManager` (new autoload), `DayClock`, `TransactionBuilder`, `TransactionSession`, `OrderItemPicker`, `RestockOrder`, and `Layout/` strategies.
  - `Scripts/World/` — `MainGame`, `GameManager`, `CustomerSpawner`, `MarioManager`, `TutorialManager`, `DragManager`, `VisualEffectManager`, `Entities/` (`DispenserContainerItem` base class unifying candy & sachet containers), `Interactors/` (polymorphic `WorldInteractor` raycast targets), and `Environment/`.
  - `Scripts/Audio/` — Decomposed monolithic `AudioManager` into `AudioManager`, `AudioSettings`, and `SFXPool`.
  - `Scripts/UI/` — Centralized `UIStyle.gd` styling helper, `TopBannerQueue.gd`, `HadesDiamondEmblem.gd`, `DiamondFXLibrary.gd`, overlays, HUDs, and `Minigames/`.
- **State & Lifecycle Hardening:**
  - Eliminated runtime `.tres` `CustomerData` mutation (`7e4879b`) in favor of pure save-state dictionaries in `CharacterProgressionManager`.
  - Guarded async Uncle Mario deliveries and day transitions against scene-exit race conditions (`64d8c9d`).
  - Fixed New Game state resets by calling `Dialogic.VAR.reset()` instead of `reset_all()` (`ab2b772`) and centralizing manager resets.

---

## 3. New Major Gameplay Systems & Features

### 3.1 Reyna Mayari's Silver Ledger & Moon Card Roguelike Draft
- **Goal-Based Tribute Ritual (`MayariTallyOverlay.gd`):** Replaced the old auto-deducted daily quota with a **`₱2,000` Silver Ledger** pact. Every night at closing, players slide a tribute gauge across **Meager**, **Fair**, and **Lavish** thresholds with subtle camera FOV zoom and Reyna Mayari dialogue reactions.
- **6 Permanent Silver Ledger Milestones (`StoryManager.LEDGER_MILESTONES`):**
  1. **15% (`₱300`) — Moon's Grace:** `+1` nightly Moon Card reroll.
  2. **30% (`₱600`) — Daylight Audience:** Unlocks Reyna Mayari as a daytime shopper & her 6-chapter story arc.
  3. **50% (`₱1,000`) — Silver Favor:** Shifts Fair draft odds from `80/20` Omen/Favor to `50/50` (Meager `25%` Favor) + `+1` extra reroll (`2` total).
  4. **66% (`₱1,320`) — Gilded Crescent:** `+20%` Increased Rarity weight on Uncommon & Rare Moon Cards.
  5. **75% (`₱1,500`) — Twin Moons:** Draft `1` or `2` Moon Cards every night.
  6. **100% (`₱2,000`) — Patron of the Moon:** Permanently seals the Silver Ledger (unlocking free nightly Favor drafts, an optional *Include Omens* toggle, post-ledger closing dialogues, and the Karimlan Epilogue Chronicle).
- **62 Moon Cards (`MayariCardRegistry.gd`):**
  - **32 Favors** (10 Common / 12 Uncommon / 10 Rare) and **30 Double-Edged Omens** (10 Common / 10 Uncommon / 10 Rare), all using single-number stats, 27 Hades-style hover **Keywords**, and borderless rarity color labels (**Common** Warm Stone, **Uncommon** Emerald Jade, **Rare** Celestial Amethyst).
  - Includes unique mechanical quirks such as **Disembodied Wind** (`25%/hr` chance to blow the fridge door open, max once per half-skip), **Slamming Draft** (`20%/hr` fridge gust), **Bargain Chorus** (`+₱15` flat Haggle win payout), **Silver Bell Counter** (`+20%` multi-item bundle bonus), **Blessing of the Full Moon** (9:00 PM close), **Borrowed Hour** (7:00 PM close + `+30%` traffic), and **Blood Moon Bargain** (`-2` Price Tolerance for `+25%` on all cash sales).

### 3.2 Papa Ulap Counter Radio & 33 Neighborhood Events
- **Counter Radio (`RadioInteractable.gd` & `PapaUlap.dtl`):** Buyable/upgradeable counter radio with rhythmic speaking squash-and-stretch + hop animation when a broadcast is ready, live `Global_RadioTimeCheck` & `Global_TimeOfDayPhase` (`before_noon` / `after_noon`), Philippine folklore trivia, sari-sari commercials, and cooldown ready notifications.
- **Hidden-Until-Tuned Broadcasts (`StoreEventManager.gd`):** Daily events are active under the hood from 5:00 AM, but tuning into Papa Ulap reveals:
  - **33 Neighborhood Events** (`Resources/events/*.tres`: 15 Common / 11 Uncommon / 6 Rare daily + 1 encounter-only *Mosquito Swarm*), spanning category demand surges, mixed folklore twists (*Duwende Coin Trail*, *Kapre's Smoke Drift*, *Basaan Street Festival*), and **6 pure-downside hardships** (*Petsa de Peligro*, *Flooded Access Road*, *Wholesale Fuel Hike*, *Stifling Dry Spell*, *Tiktik Curfew Whisper*, *Grid Voltage Drop*).
  - **Today's Visitors:** Reveals specific regular neighbors heading to the store (`+120%` / `2.2x` spawn weight) with favorite-category hover cards.
- **Calendar & Events Overlay (`EventsOverlay.gd`, `[K]` / `[C]`):** Unified view of active Events, Visitors, Moon Cards, and Sto. Niño Blessings alongside a monthly Karimlan Calendar prop/tab.

### 3.3 Pricing Steps (`-5..+5`), Price Ledger (`[L]`), Alt Lens & Tawaran Haggling
- **Discrete `-5..+5` Pricing System:** Tapered flat-plus-percentage step formula across Tiers `1–10`, distinct `-5..+5` step colors and generosity/markup labels (`Charitable` to `Outrageous`).
- **Unified Refusal & Price Tolerance Math:** Removed separate refusal-chance modifiers so refusal risk is governed strictly by `effective_step = current_step - effective_tolerance` (`+2` safe baseline; `+3` and above risks pushback/refusal).
- **Separated Tips vs. Guaranteed Sale Bonuses:** Appreciation Tips roll once per completed cash order (`GameManager.resolve_bulk_order_tip`) using a curved formula, cleanly separated from guaranteed per-item sale bonuses (Cold Sale Bonus, Featured Category `+₱3`, Fair-Price bonuses).
- **Alt Pricing Lens (`PricingOverlay.gd`) & Price Ledger (`PriceLedgerOverlay.gd`):** Hold `Alt` (even while dragging an item in mid-air on Layer 110) or open `[L]` to adjust prices with scroll wheel, inspect discovered shopper favorites, and read live right-side modifier cards. Uninspected items display a bobbing 3D `AltBadge3D` keycap.
- **Tawaran Card Duel (`HaggleOverlay.gd`):** When a shopper pushes back on price, a `60%` base trigger chance (modifiable by Moon Cards) offers a pre-haggle dialogue prompt into a strategic timed verbal card duel (*BOLD / CHARM / PITCH / CALM / DEAL* cards, rotating *Skeptical / Impatient / Open* customer stances, stale-repeat penalties, and timed *Counter!* ring parries to *So What* BGM).

### 3.4 Store Customization & Full-Screen Upgrade Skill Tree (`[U]`)
- **Skill Tree (`UpgradeTreeOverlay.gd` & `UpgradeTreeRegistry.gd`):** Replaced the old phone list with a dark-espresso, 10-column cubic-Bezier skill tree (`[U]`) with flowing path sparks, incremental stat deltas, bespoke lore descriptions, and a top-center capstone: **Open the Door**.
- **Physical 3D Store Upgrades & Props:**
  - **Store Tiers `1/10 → 10/10`:** Central root node unlocking higher product tiers (including separated Tier 10 *Mentor* & *Pocha* candy jars); Uncle Mario calls on Nokia when new tiers unlock and delivers physical plastic bags tossed in a curved arc from his tricycle.
  - **Refrigerator (`Lv. 1–3`) & Coldness Meter (`FridgeColdnessHUD.gd`):** *Magnetic Door Gasket*, *Heavy-Duty Insulation*, and *Inverter Frost Compressor*. Leaving the fridge door open drains Coldness; hitting `0%` triggers a `-25%` Warm Fridge sale penalty until re-chilled to `50%`.
  - **Mingming the Store Cat (`CatInteractable.gd`):** Unlocks Counter Slots `2` and `3` (overflow slots beyond `3` convert into `+10%` Foot Traffic each).
  - **Tambayan Bench (`Lv. 1–3`, `BenchProp.gd`):** Lets satisfied shoppers linger outside with Lucide thought bubbles, earn passive XP, chat via `Smalltalk.dtl`, and return to the counter (`75–90%` return chance) for bonus purchases.
  - **Business Permit (`Lv. 1–3`, `PermitFrameProp.gd`):** Framed wall permits scaling all Player XP earned.
  - **Sto. Niño Altar (`Lv. 1–3`, `StoNinoInteractable.gd`):** Interactive daily prayer altar granting temporary Favor Blessings with a 1-hour cooldown and ready toast.
  - **Maneki-Neko (`Lv. 1–2`, `ManekiInteractable.gd`):** Animated waving lucky cat shortening customer arrival windows and boosting Cash Tip Bonus.
  - **Wholesale Pass (`Lv. 1–2`):** Cuts Uncle Mario's `5h` base delivery cooldown by `30%` and unlocks daily discounted **Sulit Deals** in `RestockMenu`.
  - **Trash Can & Recycling Program (`TrashInteractable.gd`):** Buyable trash bin + recycling cash recovery on discarded/expired items.
  - **Storefront Drawing Studio (`StorefrontCanvasOverlay.gd` & `StorefrontCustomDisplay.gd`):** Full pixel/brush canvas studio (`ColorWheelControl`, layers, text, image upload, zoom, stickers) for custom **Roof Signage** and **Promo Poster** — placing `3/3` category stickers activates a daily **Featured Category** (`+₱3` per sale + boosted demand). Mirrored live onto the 3D store on the Main Menu (`TitleScreenStoreSync.gd`)!

### 3.5 Player Leveling, 6-Rank Reputation & Folklore Journal Archive (`[J]`)
- **Indefinite Player XP & Leveling (`PlayerXPHUD.gd`):** Auto-hiding striped XP bar earned from sales, multi-item baskets, visits, stories, tambayan, and minigames. Every level-up awards a scaling cash bonus (`₱60+`) via `TierAdvanceOverlay` with bobbing item previews.
- **6-Rank Neighbor Reputation (`CharacterProgressionManager.gd` & `RepRankUpHUD.gd`):** Per-neighbor Reputation (`Ranks I–VI`, ~20 visits to max) unlocking price tolerance bonuses, tip bonuses, favorite category discovery dialogues (`favorite_discovered.dtl`), and 6 tiers of folklore documentation.
- **Folklore Journal Archive (`FolkloreJournalOverlay.gd`):** Replaced the old `StoryProgressOverlay` / `CollectionOverlay` / raw spiral-notebook prototype with a full-screen editorial archive:
  - Left neighbor roster with star rank & pulsing unread indicators.
  - Real-world researched **Philippine Folklore Entries** (`FolkloreCatalog.gd`) across all 11 neighbors, paired with **11 credited portrait illustrations**, click-to-zoom **Lightbox**, and external artist URL confirmation modal.
  - **Integrated Story Progression & Counter Notes:** Smart single/multi-arc chapter list showing `✓` completed chapters, `◆ Ready` available chapters, `◇ Waiting` prerequisite-locked chapters with human-readable sub-hints (`↳ Waiting on Lolo Pilo (Ch. 2)`), and delayed-consequence `COUNTER NOTES`.

### 3.6 5 Filipino Street & Folklore Minigames (`Scripts/UI/Minigames/`)
1. **Tawaran Card Duel (`HaggleOverlay.gd`)** — Tactical timed verbal haggling card game.
2. **Dusk Lamp Mosquito Swat (`MosquitoSwatMinigame.gd`)** — 4:00 PM+ daily encounter (`65%` roll via `MosquitoSwarm.dtl`); swat mosquitoes around the store lamp while sparing golden barrio fireflies.
3. **Endless Sipa (`SipaMinigame.gd`)** — Physics kick-keep-up challenge with day-scaled speed ramp, personal bests, and neighbor Barangay Records leaderboards.
4. **Teks Card Memory (`TeksMemoryMinigame.gd`)** — Classic street *teks* card-flipping duel with stacked Power ratings (integrated with Buboy & regulars).
5. **Anting-Anting Talisman Tracing (`TalismanTraceMinigame.gd`)** — Pixel-exact raster-mask sigil tracing with mixed per-stroke brush widths, F1 coverage/stray-ink accuracy scoring, and deep integration into Brahim's albularyo story & visits.

### 3.7 Narrative Overhaul, 11th Neighbor & Epilogue Chronicle
- **New 11th Neighbor — Lolo Pilo (`LoloPilo.tres`):** Retired 1968 sipa champion & disguised Tikbalang elder with full Purchase, Visit, and 6-chapter Story timelines.
- **Interconnected Neighborhood Story Web (6 Chapters per Neighbor):**
  - **Triangle A (*Street & Survival*):** Kuya Kap ↔ Manang Ana ↔ Buboy.
  - **Triangle B (*Sight, Healing & The Unseen*):** Brahim (reworked as former corporate apprentice albularyo) ↔ Danilo ↔ Rosalyn.
  - **Pair 1 (*Old Tricks & New Trails*):** Lolo Pilo ↔ T.K.
  - **Pair 2 (*Forgotten Tide & Painted Crown*):** Rodel ↔ Sarimanok (with expressive physical `Ba-kawk` variations).
  - **Pillars:** Overhauled **Reyna Mayari** (daytime disguise as "Maria" + Biringan envoy arc) and **Uncle Mario** (streamlined 4-step hands-on Nokia tutorial + missed-call & chained delivery dialogues).
- **Reactive Mechanics & Fail-Forward Choices:** Added debt forgiveness (`forgive_debt`), debt deferral, out-of-stock substitute item pivots, in-character `Global_TipActive` reactions, and fail-forward minigame/choice branching so losing a minigame or refusing utang shifts `outcome:<id>` rather than hard-blocking progression.
- **Karimlan Epilogue Chronicle (`EpilogueCatalog.gd` & `EpilogueOverlay.gd`):** Sealing the Silver Ledger triggers a curated multi-card epilogue sequence reflecting each of the 11 neighbors' earned outcome tier (`TRUE ALLY`, `WARM REGULAR`, `EXACT CHANGE`, or `STILL UNFOLDING`).

### 3.8 UI/Visual FX, Audio Director, Save Slots & Dev Tooling
- **30-Effect Diamond Emblem System (`DiamondFXLibrary.gd` & `HadesDiamondEmblem.gd`):** Shared across HUD mini-diamonds, Tally drafts, Events, Morning Toasts, and Day Summary — featuring 30 procedural + 18-icon Lucide particle, chromatic/gilded/filigree/frost/barbed border, aurora/eclipse inner wash, and clarity-safe center glyph micro-motions.
- **Nightly Day Summary (`DaySummaryOverlay.gd`):** Animated end-of-day ledger grading gross revenue, net profit, buyers served, reputation gains, active condition hover diamonds, rank stamps, and a post-summary Reyna Mayari quip.
- **HUD Modernization:** Permanent bottom-left double-ring **Shortcut Dock (`[J] / [L] / [U]`)** synced with custom keybinds, FIFO `TopBannerQueue`, rolling `MoneyLabelUI` with elastic squash-and-stretch delta popups, diegetic cross-off **Utang Notebook** pagination + `PendingDebtHUD`, and universal **Fredoka** typography.
- **Dynamic Audio Director (`AudioManager.gd`):** Clock-driven time-of-day BGM phases using persistent non-repeating shuffle-bags, smooth `1.25s` linear-amplitude crossfades, dedicated Restock/Minigame BGM overrides, and looping *The Sneaky Plan* during closing hours.
- **3-Slot Save & Checkpoint Browser (`SaveManager.gd` & `LoadSlotsOverlay.gd`):** 3 independent save slots with metadata summaries, overwrite/delete confirmations, and rolling checkpoint backups for instant rollback.
- **Developer Tooling:** Interactive browser-based **Dialogue Simulator** (`Tools/build_dialogue_simulator.py` + `Tools/dialogue_simulator.html`) and Lucide SVG-to-PNG asset pipeline.

---

## 4. Key Bug Fixes Since `v0.9.6-beta`

### Save, Load & Softlock Fixes
- Fixed **8:00 PM softlock** when reloading a save after Reyna Mayari had already visited (`39712e5`) and deferred autosave triggers so `has_mayari_visited` resets cleanly (`4b6fd02`, `fce1b0c`).
- Prevented saving/restoring already-completed customer encounters (`27a0ff9`) and prevented clock resets to 5:00 AM on reload (`2c76697`).
- Blocked `PauseMenu` while `DaySummaryOverlay` is open to prevent mid-summary save corruption (`537a343`) and persisted `day_summary_shown_for_day` (`57b89d8`).
- Refreshed all 3D upgrade props (`faf1afd`) and dispenser containers (`1f13308`) immediately after loading save data.
- Fixed `GameManager` calling nonexistent `is_ledger_settled()` instead of `StoryManager.is_tally_cleared()` (`dde769d`).

### Customer Spawning, Inventory & Transaction Fixes
- Prevented **double stock deduction** on transient item sales (`f2aa048`) and marked candy/sachet container props `can_be_sold = false` so customers never order the jar itself (`0e2959a`).
- Replaced `await` on customer exit with signal callbacks so script reloads or multi-slot departures never stall waves or Mayari's arrival (`d260b95`, `e8aa18e`, `433d4df`).
- Prevented missing `Partial` timeline labels from falling back to `Satisfy` and prematurely dismissing multi-item orders (`df42f45`), and disabled legacy `refresh_desires` signals that wiped `desired_items` (`1cbd6b2`, `7b5985a`).
- Prevented debt-repayment preambles from dismissing shoppers before their actual order (`25423db`) and guarded zero-peso/partial debt deductions (`862135d`).
- Merged upgrades purchased mid-restock into Uncle Mario's in-transit tricycle (`e9bc721`, `59e20ea`) without consuming product restock cooldowns (`251f45e`).
- Allowed opening/closing the refrigerator while holding an item (`afa9f00`) and during active Dialogic conversations (`92d9402`).

### Audio, Performance & Engine Stability Fixes
- Eliminated the **dusk freeze hitch** by removing random MP3 seeking on the 53 MB night crickets ambient stream (`56b898c`).
- Fixed `MoneyLabelUI` `SIGSEGV` crash by storing `WeakRef`s for active delta popups (`984f729`) and wrapping stacked popups in outer slot nodes so nudge tweens never fight pop-in tweens (`b1a53c3`).
- Fixed BGM getting stranded silent or stuck on *An Autumn Wind* across day/menu transitions by driving gameplay BGM phase directly from `StoryManager.clock` (`9dec5d7`, `4a027b3`).
- Resolved Godot 4 strict static-typing errors (typed `Array[T]` ternary crashes in `CustomerSpawner`, `StoryManager`, and `CharacterProgressionManager`, shadowed identifiers, and cyclic `class_name` autoload shadowing).

### UI, Input & Z-Ordering Fixes
- Rendered held-item Pricing Lens on `CanvasLayer 110` above `DragManager`'s held item (`Layer 100`) and auto-hid it on `drag_ended`/mouse unlock so it never gets stuck (`e0a8a0d`, `09a48e3`).
- Preserved customer hover outlines while holding an item with Pricing Lens open (`765b9af`).
- Kept mouse cursor unlocked across `MayariTallyOverlay`, `DaySummaryOverlay`, and `TalismanTraceMinigame`, plus added hold-`Shift` cursor unlock (`df77317`).
- Fixed `UpgradeMenu` `ScrollContainer` layout hang (`ff48025`), `RepRankUpHUD` parallel tween height bug (`6999272`), and scrollbar/gutter overlaps in `FolkloreJournalOverlay` (`ec8165d`).

---

## 5. Removals, Deprecations & Intentional Simplifications

1. **Removed Fixed Auto-Deduct Daily Quota (`quota_day` / `₱25 + ₱15n`):** Replaced entirely by the player-paced `₱2,000` Silver Ledger and Moon Card draft.
2. **Removed Flat Root `Scripts/` & `Scripts/Managers/` Files:** Migrated or superseded 22 legacy root/manager scripts (`Fridge.gd`, `ItemContainer.gd`, `CutsceneShot.gd`, etc.) into bounded domain folders.
3. **Removed `HeldItemLabelUI.gd`:** Superseded by the richer 3D/Layer-110 `PricingOverlay` Alt Lens and `CustomerRequestHUD` interactive item sway/lift feedback.
4. **Removed Legacy Phone-List Store Upgrades:** Replaced by the visual `[U]` `UpgradeTreeOverlay` skill tree.
5. **Removed Legacy Notebook/Card Progress Screens:** Superseded `CollectionOverlay` / `StoryProgressOverlay` / spiral-checkbox mockups with the unified `[J]` `FolkloreJournalOverlay`.
6. **Removed Danilo-Exclusive Rumor Bottleneck:** Daily events and visitor sightings moved to Papa Ulap's Counter Radio so Danilo could have a full personal story arc inside Triangle B.
7. **Removed Separate `markup_refusal`, `walkout_chance`, and `shelf_capacity` Card Modifiers (`f316dd3`):** Consolidated all price pushback strictly under **Price Tolerance** to eliminate hidden math layers, removed `1–2` range ambiguity on Moon Cards in favor of flat single numbers, and converted overflow counter slots (`> 3`) into `+10%` Foot Traffic.
8. **Removed Forced Day-1 Purchase & Forced Close-Fridge Tutorial Lock (`7a0060f`, `8deae6e`):** Replaced rigid tutorial locks with natural Uncle Mario dialogue guidance and a brisk 4-step Nokia test call.
9. **Removed `addons/gdUnit4`, Legacy `Tests/`, and `wip_mechanics_audit.md` (`9805499`, `b58e247`):** Cleaned out unused third-party test runner bloat and obsolete early-prototype notes.
10. **Removed `theme_player` Node & Random Ambient MP3 Seek (`750b16a`, `56b898c`):** Unified music playback under `AudioManager`'s crossfading phase director.
