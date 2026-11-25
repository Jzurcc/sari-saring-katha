# Sari-Saring Katha — Roadmap & Todo List

> ### Original Notes
> - First, in the upgrade section, I want the trash can and the cats be buyable upgrades instead of already in there.
> - I want the refrigerator to have a feature where it has a UI bar of coldness when its opened somewhere in the UI, and the player must close it or else the cold will escape! and the items inside will lose a bit of value slowly when it's left unfilled. Closing the fridge will stop that and regenerate the coldness over time. There will be refrigerator upgrades that can decrease the rate of escaping and at the same time increasing its regen.
> - Then I want an upgrade option where the player draws their own giant rectangle signage art on top of the store!
> - Then another upgrade option for a poster in front of the store. When this is bought and you go to the main menu, the player's changes actually reflect in the main menu store (the main menu just shows the front of the store). 
> - A journal system where players can see more info about the mythical neighbors they have. This can serve double as the story progression part, but more importantly the real life trivia parts of the creatures, for educational purposes.
> - Complementing that, also a relationship system for each customer. Familiarities and all that buzz that grants them tips and tolerances and whatnots, might also be tied directly with the chapters or seperately, maybe even different endings depending on the relationship level. rejecting customers is the only way to decrease but maybe we can introduce more.
> - speaking of which, the questing system needs more options. we can't just serve products and that's it. What other thing can we do for these customers? We can introduce entirely new gameplay / minigames and objectives and whatnots for better player engagement and filipino culture.
> - more characters of course. The duwende multiple customers that always come in multiple is a great example.
> - Also, when someone visits, I think it's better to let them stay a while in the store before wandering off, and the next customer who is maybe buying (or also just hanging out and visiting) can go to the side and buy at the same time. Then also in here, maybe you can still chitchat to the visiting people in there while serving another customer for some small talk and familiarity gains?? Good idea! Oh and perhaps they can even exchange little talks to each other without player interaction??
> - More events obviously, and also more effects from events unique ones and etc.
> - oh and more customer dialogue functionalities. Maybe they can effect more than just the text that show on screen, definitely refine the persistence of player choices throughout the game and perhaps player choices on one customer can even affect dialogue on another character or on all characters.
> - Like I said, more minigames and interactive stuff, even the little thing counts. I mean, the cat that you can click/spam to produce meows is a great example that I already implemented. But ofc, interactive with the customers is also great. 
> - More music!
> - Cutscenes!
> - Better handwritten and reworked dialogue of course.

---

## 1. Store Upgrades & Customization
- [x] **Buyable Store Props (Trash Can & Cats):** Moved the Store Trash Can (`₱45`) and Store Cat (`Mingming`, `₱85`) + `Cat Food` (`₱180`) out of the starting store into the Upgrade Menu (with Uncle Mario delivery & counter-slot unlocks `1 → 2 → 3`).
- [ ] **Custom Store Signage Upgrade:** Add an upgrade that unlocks a drawing canvas where the player can paint their own giant rectangular signage mounted on top of the store.
- [ ] **Storefront Poster Upgrade & Main Menu Reflection:** Add an upgradeable poster in front of the store and persist both the signage and poster art so the player's customizations visibly appear on the Main Menu storefront.

## 2. Refrigerator Coldness & Upgrades
- [x] **Coldness Meter UI:** Display a center-right animated striped coldness bar whenever the refrigerator is open or regenerating back to 100%.
- [x] **Cold Escape & Temporary Warmth Penalty:** Leaving the fridge open drains coldness over time (`7s` default); when depleted, fridge items temporarily lose 25% value until closed and chilled back to 100%.
- [x] **Cold Regeneration:** Closing the refrigerator stops cold loss and regenerates coldness back to full (`14s` default), restoring full item value at 100%.
- [x] **Refrigerator Upgrades:** Added 3 sequential fridge upgrades in the Upgrade menu (*Magnetic Door Gasket*, *Heavy-Duty Insulation*, *Inverter Frost Compressor*) delivered/installed by Uncle Mario, strongly extending cold retention (`7s → 14s → 24s → 36s`) and speeding up recovery (`14s → 11s → 8.5s → 6.5s`).

## 3. Mythical Journal & Relationship System
- [ ] **Folklore Journal / Compendium:** Build an in-game journal tracking each mythical neighbor's story progression alongside real-life Philippine folklore trivia for educational value.
- [ ] **Customer Familiarity / Relationship System:** Track per-customer familiarity that grants tangible perks (higher tips, better price tolerance, special reactions) and can tie into story chapters or unlock multiple endings.
- [ ] **Relationship Modifiers:** Expand ways to gain and lose familiarity beyond simple rejections (e.g., fair pricing, chitchat, honoring utang, fulfilling side requests, or neglecting/overcharging).
- [ ] **Visual Relationship & Character Progression UI:** Add tangible visual UI elements for familiarity, relationship tiers, and character progression (e.g., familiarity bars/hearts, floating gain/loss & rank-up feedback during interactions, visible milestone badges, and end-of-day progression recaps) so players actively feel their bonds and progress growing each day—not just through dialogue.

## 4. Living Storefront & Multi-Customer Visits
- [x] **Lingering Visitors:** Visiting customers hang out around the store and stroll between spots before leaving or returning for smalltalk.
- [x] **Simultaneous Side-by-Side Customers:** Up to 3 counter slots (`1 → 2 → 3` unlocked via Store Cat upgrades) with wave/burst pacing and immediate center-slot promotion.
- [~] **Ambient Chitchat & Cross-NPC Banter:** **Smalltalk with returning lingering visitors is implemented**; still need familiarity gains and autonomous NPC-to-NPC banter bubbles without player input.

## 5. Quests, Minigames & Tactile Interactions
- [ ] **Expanded Customer Objectives:** Introduce non-purchase tasks, cultural minigames, and interactive favors beyond simply handing over products.
- [ ] **Small Tactile World Interactions:** Add more playful, bite-sized interactive details (in the spirit of clicking the cat to meow) and interactive moments directly with customers.

## 6. Characters, Events & World Reactivity
- [ ] **New Mythical Characters:** Expand the cast (e.g., Duwende groups that always arrive together in multiples).
- [ ] **More Market Events & Unique Effects:** Add a wider pool of daily neighborhood events with distinct gameplay modifiers beyond demand/tolerance boosts.
- [ ] **Persistent Cross-Character Dialogue Choices:** Refine choice persistence so decisions made with one customer can trigger world effects or alter dialogue on other characters (or the whole neighborhood).

## 7. Audio, Presentation & Writing
- [ ] **More Music:** Expand morning, afternoon, dusk, and character-specific soundtracks.
- [ ] **Cutscenes:** Add dedicated story/milestone cutscenes.
- [ ] **Handwritten Dialogue Rework:** Polish and rewrite character dialogues for stronger voice, warmth, and cultural authenticity.

## 8. Economy & Reyna Mayari Tally Rework
- [x] **Player-Chosen Tally Contributions, Goal System & Moon-Card Draft:** Reworked Reyna Mayari's nightly tally into a **₱750** goal-based *Silver Ledger of Biringan* (with Option A sufficient-night scaling) followed by a Slay-the-Spire style **3-Card Moon Draft** (7 *Biringan's Favor* buffs + 5 *Biringan's Chill* quirks/debuffs) and an active-card HUD badge.

## 9. Restocking UX & Inventory Clarity
- [ ] **Prerequisite — Visible Current Stock in Restock Menu:** Display each product's current owned/shelf stock (e.g. `Stock: 1 / 5` or `OUT OF STOCK` badge) directly on every Restock Menu card and detail view so players immediately know what they already have while shopping.
- [ ] **Restocking Decision-Fatigue Overhaul:** Introduce clarity and convenience systems so restocking doesn't feel confusing or overwhelming as the catalog grows (e.g., **Low Stock / Out of Stock** filter or priority sorting, **"In Demand / Event"** highlights, **Quick Restock / Fill Low Stock** one-click preset bundles, and clear shelf/fridge capacity bars).

---

## Design Notes & Discussion

### 1. Store Upgrades & Customization
- **Why it hits hard:** Seeing *your* hand-drawn sari-sari sign and storefront poster on the Main Menu every time you launch the game turns the store from a level into *your* tindahan.
- **UX tip for non-artists:** Pair freehand drawing (a few brush sizes + 6–8 marker/paint colors + undo/clear) with quick **sari-sari stamps/presets** (e.g., *"SARI-SARI STORE"*, *"ICE FOR SALE"*, *"LOAD HERE"*, *"BAWAL UTANG"*, stars/hearts) so players who don't draw can still make something funny and personal in 30 seconds.
- **Tech note:** Save both canvases as `.png` files in `user://` and load them onto the storefront mesh materials in both `MainGame` and `MainMenu`.
- **More Store Upgrade & Customization Ideas (beyond Trash Can, Cats & Signage):**
  - **Outside *Bangko* / Monoblock Chairs:** Directly unlocks or expands the *Tambayan* side-visitor slot so more neighbors can hang out at the store (also visible on the Main Menu).
  - **Counter Radio & Oscillating Electric Fan:** Tactile clickable props — clicking the radio cycles BGM tracks or plays short barangay announcements; the fan adds cozy hum and motion.
  - **Fiesta *Banderitas* / Warm String Lights:** Lights up the storefront at dusk/night and shows up on the Main Menu golden-hour view.
  - **Storefront Awning (*Tolda*) & Shelf Linoleum Themes:** Color/pattern swaps for the awning stripes, counter cloth, or painted trim.
  - **Wall Bulletin Board / Barangay Corkboard:** Displays pinned market event flyers and neighborhood doodles in 3D space.
  - **Counter *Alkansiya* (Coin Jar) or Lucky Charm Altar:** Visual prop that fills up as you earn money, or gives a tiny passive tip-chance bump.

### 2. Refrigerator Coldness & Upgrades
- **Why it works:** Every Filipino player instantly relates to *"isara mo yung ref, sayang kuryente!"* — it turns opening the fridge into a quick, memorable micro-ritual.
- **Balance tip:** Instead of permanently ruining item value if a player forgets once, consider a **temporary "Lukewarm" penalty** (e.g., below 25% coldness, chilled items lose ~20% value/appeal while warm, and automatically recover once the door is closed and coldness regenerates). Pairing the UI bar with subtle audio/visual cues (hum pitch shift or fading frost) makes it feel physical.

### 3. Living Storefront (*Tambayan*), Side-by-Side Customers & Autonomous Banter
- **Standout feature:** A real sari-sari store is a neighborhood *tambayan*, not a drive-thru. Letting visitors linger on the side while a buyer steps up to the main counter makes the barangay feel genuinely alive.
- **Clean architecture:** Generalize `CustomerSpawner`'s `current_customer` + `guest_customer` into a small multi-slot counter (**Main Buyer Slot** + **Side Tambay Slot(s)**). That single system unlocks **both** lingering visitors **and** multi-character Duwende groups at once!
- **Autonomous banter:** Keep NPC-to-NPC exchanges as short, non-blocking floating speech bubbles (1–2 lines) so they add warmth without interrupting the player while they're dragging items or pricing shelves.

### 4. Folklore Journal, Educational Trivia & Relationship (Familiarity) System
- **Chapters vs. Familiarity:** Keep **Familiarity separate from story chapters**, with soft bridges between them:
  - *Chapters* pace the scripted narrative arc.
  - *Familiarity* reflects day-to-day treatment (fair/low prices, honoring utang, quick service, chitchat with lingering visitors, completing favors).
- **Ways to lose familiarity (beyond rejection):** Repeatedly overcharging at `+3`, refusing utang during a vulnerable beat, or repeatedly handing the wrong item.
- **Rewarding payoffs:** Higher familiarity can unlock **deeper real-life Philippine folklore trivia** in the Journal, better tips/tolerance, occasional neighbor gifts (like Manang Ana's adobo), and **ending/epilogue variations** (who shows up for you at the end).
- **Journal & Educational Trivia Ideas:**
  - **Two-Page Scrapbook Spread:** Styled like Lola's handwritten notebook — **Left Page:** Neighbor profile, favorite snacks, relationship hearts/stars, and story chapter recap; **Right Page:** *"Real-Life Folklore Field Notes"* clearly separating game fiction from authentic Philippine mythology.
  - **Progressive Discovery:** Entries start as vague silhouettes/rumors on first meeting and unlock **regional origins** (Tagalog, Visayan, Bicolano, Maranao, etc.), **traditional beliefs/taboos** (e.g., *"Tabi-tabi po"* for Duwende, salt/garlic myths for Manananggal, turning shirts inside-out for Tikbalang), and **cultural/historical context** as you befriend them.
  - **Folklore Stamps & Doodles:** Unlockable hand-drawn sketches, polaroids, or sticker stamps in the margins when you finish a character's arc or hit max familiarity.
  - **Casual Trivia Callbacks:** Occasional playful quiz lines from Buboy or Danilo referencing real folklore facts you've unlocked in the journal for a bonus familiarity/tip boost.
- **Visible Daily Progress (Beyond Dialogue):** Surface relationship and character progression through clear UI feedback—such as compact familiarity hearts/meters when a regular visits, subtle floating `+Familiarity` / rank-up popups after great service or favors, milestone/chapter progress indicators in the journal, and a quick end-of-day summary showing whose bond or arc moved forward that day.

### 5. Non-Purchase Quests & Filipino Cultural Minigames
Great fits that stay grounded at the counter and reuse existing mechanics:
- **Nokia *Paload* (E-Load):** Customer reads out a number/promo and you dial it on the Nokia keypad you already built!
- **Neighbor Errands / Message Passing:** *"Can you hand this to Kuya Kap when he passes by?"* — simple item/message handoffs that make the neighborhood feel interconnected.
  - *Note:* **Add a new Filipino myth character that parodies online deliveries to neighbors!** (e.g., a folklore parcel-rider yelling *"Parcel po! Pa-receive muna dito!"* and leaving a neighbor's package at your sari-sari store for you to hold and hand off when they drop by.)
- ***Barya-barya* / Exact Change:** Occasional big bill (₱100 / ₱500) requiring quick change-making.
- **Expanded *Bugtong* (Riddles):** Folklore-themed Filipino riddles with bonus familiarity/tips.

### 6. Persistent Cross-Character Choices
- Introduce a lightweight global **Neighborhood Flags** dictionary (e.g., `world_flags["helped_ana_utang"] = true`) persisted in `StoryManager` and queryable in Dialogic.
- Even 6–10 key flags referenced by *other* characters (*"Manang Ana told me you let her put dinner on her tab..."*) create huge narrative payoff without ballooning dialogue trees.

### 7. Suggested Build Order (Highest Impact First)
1. **Store Ownership Polish:** Buyable Trash Can & Cats → Fridge Coldness Bar & Upgrades → Custom Signage & Poster (synced to Main Menu).
2. **Depth & Education:** Folklore Journal + Familiarity System → Global Cross-Character Choice Flags.
3. **Signature Barangay Life:** Multi-slot *Tambayan* (lingering visitors + side-by-side buyers + autonomous banter + Duwende groups) → Cultural Minigames (starting with Nokia *Paload*) → More Events, Music, Cutscenes & Dialogue Rework.

### 8. Restocking UX & Reducing Decision Fatigue
- **The Problem:** Once Tiers 3–10 unlock dozens of products across categories, opening the Restock Menu without knowing what's empty on your shelves creates instant decision fatigue.
- **Prerequisite:** Show live **current stock vs. cap** (`0/5 OUT`, `1/5 LOW`, `5/5 FULL`) directly on every item card in `RestockMenu` before adding smarter restocking tools.
- **High-Impact Systems to Reduce Friction:**
  - **"Needs Restock" / Low-Stock Tab:** One dedicated view showing only `0` or low-stock items (plus any active Market Event `[IN DEMAND]` items) sorted by urgency.
  - **One-Click "Fill Low Stock" / Smart Restock Suggestions:** Auto-queues a balanced basket of your out-of-stock/low items within your current budget that you can tweak before confirming.
  - **Shelf & Fridge Capacity Meters:** Visual bar showing remaining Shelf vs. Fridge slots as you add items so you never hit surprise `"Shelf is full!"` errors.

misc todo

for events like payday rush or intense heatwave, let's jsut do it always like:

Highlighted Demand:
Highlighted Price Tolerance:

and just bold the items that are highlighted in the description, like *Snacks, Canend Goods, and Noodles*

also center the calendar in the calendar menu and enlargen the fonts of the month and year there a bit too.

the space indicator in the dialogue should just be light cream like the dialogue, and can it be like on the edge of the bottom right instead of inside the dialogue?

the +1 XP of lingering visitors every 2 seconds should actively bring up the player's level bar and the +1 in there, oh and perhaps the +1 XP should also float up from the character as if it's the source of it, also that is unlocked by default yes!

also, make sure that the event/calendar menu has the same width and height size as the card selection menu in mayari, and that the card sizes and font sizes are the same as in there too, as I notice the event menu UI has font sizes of the description larger than that in the mayari menus.



the animation from the offer menu to the card selection menu should be that the unrevealed favors etc etc SHOULD FLIP IN PLACE, as in it animates to reveal its card, not this current where it animates from below like out of place. also, the keywords should show at the center right of the hovered card, not at a select place, so it pops up from the card height middle of it, then multiple keywords there align nicely to the middle of it. also actually widen the event menu and mayari selection menus so that the event and cards will have more space for descriptions, wider, and retain the triangle so that it will not touch the 2nd stat when a card has one.

also when customers dont tolerate prices, make them actually refuse and leave!