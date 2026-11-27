# Neighbor Dialogue Authoring Workflow (Pilot Standard)

> Practical step-by-step playbook distilled from building **Pilot Character #1: Kuya Kap** ([KuyaKap.tres](file:///c:/Users/John%20Reniel/sari-saring-katha/Resources/customers/KuyaKap.tres), [Story.dtl](file:///c:/Users/John%20Reniel/sari-saring-katha/Dialogue/Timelines/Kuyakap/Story.dtl), [Purchase.dtl](file:///c:/Users/John%20Reniel/sari-saring-katha/Dialogue/Timelines/Kuyakap/Purchase.dtl), [Visit.dtl](file:///c:/Users/John%20Reniel/sari-saring-katha/Dialogue/Timelines/Kuyakap/Visit.dtl)). Follow this exact process for every neighbor customer to keep quality, Filipino warmth, and technical stability consistent across the cast.

---

## Step 1: Read Context & Code Before Writing Anything

Before drafting a single line for a neighbor, read these files in parallel:

1. **Core Craft & Worldbuilding Bibles:**
   - [MASTER_DIALOGUE_AND_NARRATIVE_DESIGN_GUIDE.md](file:///c:/Users/John%20Reniel/sari-saring-katha/docs/MASTER_DIALOGUE_AND_NARRATIVE_DESIGN_GUIDE.md) (Fixed subtext / fluid surface, 6-16 word vertical rhythm, late entry / early exit, Type-B offset replies, Trapdoors, three-posture choice triads, fail-forward, delayed consequences, 8-point editing pass).
   - [MASTER_STORY_PACING_AND_WORLDBUILDING_GUIDE.md](file:///c:/Users/John%20Reniel/sari-saring-katha/docs/MASTER_STORY_PACING_AND_WORLDBUILDING_GUIDE.md) (Counter as crossroads, orders as emotional keys, *Kishotenketsu* turns, shared street landmarks, mundane-meets-mythic iceberg worldbuilding).
   - [MACRO_NARRATIVE_ARCHITECTURE_SPEC.md](file:///c:/Users/John%20Reniel/sari-saring-katha/docs/MACRO_NARRATIVE_ARCHITECTURE_SPEC.md) (6-chapter / 2-arc budget, bespoke outcome strings, Priority-Bucket `P1`-`P3` openers).
   - The character's cluster bible in `docs/misc/stories/` (for example, [TriangleA_Street_And_Survival.md](file:///c:/Users/John%20Reniel/sari-saring-katha/docs/misc/stories/TriangleA_Street_And_Survival.md)).
2. **Existing Character & Item Data:**
   - `Resources/customers/<Character>.tres` and their existing `Dialogue/Timelines/<Character>/*.dtl` (to understand spawn rules, favorite categories, motion profiles, and what charm in their original voice should be elevated).
   - `Resources/items/` (to verify exact `category` names like `candy`, `cigarette`, `bottle`, `can`, `frozen`, `pack`, `sachet`, `snack`, and unlock `tier` numbers).
   - Reference gold-standard implementation: [Dialogue/Timelines/Kuyakap/Story.dtl](file:///c:/Users/John%20Reniel/sari-saring-katha/Dialogue/Timelines/Kuyakap/Story.dtl) and [Purchase.dtl](file:///c:/Users/John%20Reniel/sari-saring-katha/Dialogue/Timelines/Kuyakap/Purchase.dtl).
3. **Engine Touchpoints (When Adding Flags, Substitutions, or Openers):**
   - [DialogicBridge.gd](file:///c:/Users/John%20Reniel/sari-saring-katha/Scripts/Core/DialogicBridge.gd) and [project.godot](file:///c:/Users/John%20Reniel/sari-saring-katha/project.godot) (registering and syncing `Flag_*` variables).
   - [DialogueContextResolver.gd](file:///c:/Users/John%20Reniel/sari-saring-katha/Scripts/Core/DialogueContextResolver.gd) (`P1_WEB_RULES` cross-character callbacks and `P2_OUTCOME_LINES` memory openers).
   - [TransactionSession.gd](file:///c:/Users/John%20Reniel/sari-saring-katha/Scripts/Store/TransactionSession.gd) and [TransactionBuilder.gd](file:///c:/Users/John%20Reniel/sari-saring-katha/Scripts/Store/TransactionBuilder.gd) (how greetings, `Repayment`, `Partial`, `SubstituteItem`, `utang`, and fail-forwards execute).

---

## Step 2: Lock Voice & House Writing Rules

Fill out a quick mental (or story-bible) 5-Axis Voice Dossier before writing, and enforce every house rule below without exception:

1. **Mainly English With Light Filipino Sprinkles (CRITICAL LANGUAGE BALANCE):**
   - Dialogue MUST be **90-95% natural, idiomatic English**, with only **small, effortless Filipino words sprinkled in** (`anak`, `apo`, `Kuya`, `Manang`, `Aba`, `Sus`, `Jusko`, `Susmaryosep`, `Salamat`, `lista`, `ulam`, `merienda`, `karinderya`, `ha`).
   - **NEVER** write full Tagalog sentences or heavy Taglish blocks. Match Kuya Kap's exact balance: any English reader should understand 100% of every sentence immediately while still feeling the homey Filipino barangay warmth.
   - Karimlan is a warm, lived-in neighborhood where everyone already knows each other's folklore nature. Keep characters grounded in relatable Filipino archetypes (an affectionate elderly Tito; a tired, caring karinderya Tita; an energetic kid who forgets his mom's errand list) rather than cold noir stereotypes or fortune-cookie philosophers.
2. **100% Spoken Voice Only (Zero Parenthesis Narration):**
   - Every NPC dialogue box plays that character's audio blip. **Never** write stage directions or narrator thoughts in parentheses like `(He coughs and drops a paper.)`.
   - Show physical business purely through spoken reactions (`"Wait, sandali, [shake rate=18 level=7]khhk, khhk![/shake]"`, `"Ay, sandali, something fell out with my coins."`, `"I'll stand a step back so the smoke doesn't drift inside your shop."`).
   - On player choices, use spoken lines or direct physical counter actions (`[Slide the yellow slip back to him without reading a word.]`), never `[Think: ...]`.
3. **Storefront & Street Geography:**
   - The player works behind an open **counter** (never write `grille`).
   - Use natural shared landmarks (`across the road`, `down the road`, `the acacia`, `the karinderya`, `the barangay clinic`, `the tricycle stand`; never `Mabini Street`).
4. **Zero Time-of-Day or Calendar-Day Words:**
   - Customers spawn and repay debt randomly across shift hours and calendar days. **Ban** `tonight`, `morning`, `afternoon`, `evening`, `dusk`, `dawn`, `midnight`, `today`, `yesterday`, `tomorrow`, `weekend`, and specific weekdays (`Monday` through `Sunday`) from timelines, chapter titles, and reactive openers. Use calendar-neutral anchors (`payday`, `next pass`, `this round`, `when my pay clears`).
5. **Count-Neutral `{Transaction_ItemWants}` Grammar:**
   - Orders can roll single or multiple items (`"Champyon"` or `"Champyon and Water"`). Never write `"One {Transaction_ItemWants}"`, `"isa lang"`, or `"the {Transaction_ItemWants}"`. Use count-neutral phrasing (`"Pahingi nga ng {Transaction_ItemWants}"`, `"{Transaction_ItemWants} lang"`, `"Just sell me {Transaction_ItemWants}"`, `"Set my order aside"`).
6. **Clean Cadence & Punctuation:**
   - **Never** use em-dashes, `...` ellipses crutches, or `[pause=0.8]` spam.
   - Keep 90% of bubbles to **6 to 16 words** (hard cap ~20 words, one clear thought per click).
   - **Short Player Choices (`3 to 7 words`, hard max 8 words):** Keep every `- Choice` button punchy and scannable so Dialogic choice buttons never wrap into bulky sentences.
   - Include playful, human micro-reactive choices (like Kuya Kap's Chapter 1 height tease) alongside meaningful Three-Posture Triads (*Accept* / *Challenge* / *Deflect or Quiet Action*).

---

## Step 3: Set Up the 3-File Architecture & `.tres` Resource

Every neighbor uses **3 clean Dialogic timelines** wired into `Resources/customers/<Character>.tres`:

1. **`CustomerData` (`.tres`) Configuration:**
   - **6 `ChapterData` resources** (`chapter_0` to `chapter_5`) grouped into **2 `ArcData` entries** (`arc_0`, `arc_1`), both pointing to the same unified `Purchase.dtl` and `Visit.dtl`.
   - Leave static `substitute_item_ids` and `substitute_categories` empty on `ChapterData` when substitutions are meant to be chosen by the player in dialogue.
   - For neighbors who occasionally ask for credit on everyday runs, set `requests_utang = true` with a **low `utang_chance`** (`0.10` to `0.20`, lower than Manang Ana's `0.80`) and an appropriate `repayment_chance`.
2. **`Story.dtl`:**
   - `label Greeting`: Optional `{Transaction_HasReactiveOpener}` (only fires on `story_out_of_stock` White-Check retries) followed by `if {Transaction_Chapter} == 0.0:` through `5.0`.
   - Dialogue-driven substitutions use **categories** (`[signal arg="allow_sub_cat:candy"]`), secretly pivoting the HUD request while preserving the character's spoken item string until handover.
   - Shared labels at the bottom:
     - `label Talk` (with out-of-stock `[signal arg="refuse_service"]` White-Check retry).
     - `label Partial` (3 randomized variants via `set {Variation} = range(1,4).pick_random()`).
     - `label SubstituteItem` (if used across multiple chapters, branch on `{Transaction_Chapter}` so reactions never repeat).
     - `label Satisfy` (handles `{Transaction_StoryGouged}` begrudging buy, `{Global_TipActive}`, and `[signal arg="story_success"]`).
     - `label WrongItem`.
3. **`Purchase.dtl` (Unified 3-Slot Sandwich):**
   - Per-arc purchase pools are **deprecated**. Shift Slot 2's 4-line request pool **only** on meaningful story flags (for example, `Flag_KapQuitSmoking` / `Flag_KapSubCandy` / default).
   - Put `{Transaction_WantsDebt}` utang choices upfront in `label Greeting` (never in `label Satisfy`), and include `label Talk`, `label Partial` (3 random variants), `label Satisfy` (`{Global_TipActive}` + 3 `{Transaction_SatisfyVar}` closers + `[signal arg="story_success"]`), **`label Repayment`** (with `[signal arg="repay_debt"]`), and `label WrongItem`.
4. **`Visit.dtl`:**
   - `label Greeting` (`{Transaction_HasReactiveOpener}` + 3 `{Transaction_VisitVar}` variations + `[signal arg="story_success"]`) and `label Smalltalk` (3 `{Transaction_VisitVar}` variations).

---

## Step 4: Author in Two 3-Chapter Batches & Enforce the 4-Point Tally Budget

Never rush all 6 chapters in one wall of text. Split authoring into two focused passes:

1. **Batch 1: Chapters 1 to 3 (`0.0` to `2.0`) + `Purchase.dtl` + `Visit.dtl`**
   - Establish the character's late-entry voice, playful human rapport, habitual defense filter, early clue/flag setup, and first Trapdoor or category substitution.
   - Stop and review Batch 1 with the user to lock the voice before writing the back half.
2. **Batch 2: Chapters 4 to 6 (`3.0` to `5.0`) + Cross-Web Callbacks**
   - Wire incoming delayed consequences from other neighbors, parallel emotional lanes, boundary tests, and Chapter 6's accumulated-tally resolution (`[signal arg="outcome:<bespoke_id>"]`, zero last-minute "pick ending" buttons).
   - Add the character's `P1` and `P2` reactive lines in [DialogueContextResolver.gd](file:///c:/Users/John%20Reniel/sari-saring-katha/Scripts/Core/DialogueContextResolver.gd).
3. **Strict 4-Point Inflection Tally Budget (Anti-Inflation Rule):**
   - **Never award `[signal arg="tally:+1"]` for basic politeness, smalltalk, Chapter 1 introductions, or Chapter 5/6 payoff scenes.** Polite choices should be `0`, neutral/transactional choices `0`, and harsh/dismissive choices `-1`.
   - **Zero everyday purchase tally noise:** Routine utang acceptance/refusal and routine purchase haggling never shift story tallies (only Story Chapter price-gouging deducts `-1`).
   - **Reserve positive tallies strictly for 3 to 4 genuine moral or mechanical inflection points** across the entire 6-chapter arc (typically max `+4` or `+5` total, with best Chapter 6 outcomes gated at `Tally >= 3` plus a decisive mechanical flag like `Flag_KapSubCandy` or `Flag_BuboyTrustedErrand`). If a category substitution grants `+1` or `+2` in `label SubstituteItem`, do **not** also grant `+1` on the dialogue prompt that unlocked it (no double-dipping).

---

## Step 5: Technical Wiring & Zero-Error Verification Pass

Before calling a neighbor finished, run every check below:

1. **Variable & Bridge Sync:**
   - Every new `{Flag_*}` variable used in `.dtl` must be declared in [project.godot](file:///c:/Users/John%20Reniel/sari-saring-katha/project.godot) under `dialogic/variables` **and** synced in `DialogicBridge.sync_transaction()`.
2. **Strict GDScript Typing:**
   - Never use `:=` when the right-hand expression touches an untyped `Variant` (`Dialogic.VAR.get_variable(...)` or an unwrapped `dict.get(...)`). Always write explicit types (`var x: bool = ...`, `var s: String = str(...)`).
   - Verify modified scripts compile cleanly via `Godot.exe --headless --path . --check-only --script res://...`.
3. **Automated `.dtl` Hygiene Check:**
   - Tab indentation only (zero leading spaces on indented `.dtl` lines).
   - Balanced BBCode tags (`[color=#0f6e2f]...[/color]`, `[shake ...]...[/shake]`).
   - Exact `.dch` character identifier and exact folder casing (`res://Dialogue/Timelines/...`).
   - Zero parentheses, zero `grille`, zero em-dashes, zero `...`, zero time-of-day words, and count-neutral `{Transaction_ItemWants}` grammar.
4. **Editor Reload Reminder:**
   - Whenever `project.godot` is edited externally while Godot is open, remind the user to run **`Project -> Reload Current Project`** before pressing Play so Project Settings do not overwrite the new Dialogic variables.
