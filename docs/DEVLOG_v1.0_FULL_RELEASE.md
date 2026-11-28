# Sari-Saring Katha v1.0 Full Release — Back Behind the Counter After 7 Months!

Hello everyone!

After 7 months away, I finally got the time to sit back down, pour everything I wanted into **Sari-Saring Katha**, and bring it all the way to **v1.0 Full Release**.

When I last updated the game back in April (`v0.9.6-beta`), it was still a small, linear prototype: one customer at a time, a strict daily quota that kept climbing, and isolated early stories. Coming back to it, I wanted Karimlan to actually feel like a living Filipino *kanto*, a place with regulars who know each other, a counter you slowly make your own, and nights where you decide how hard to push your luck.

Here is everything new waiting for you in **v1.0**.

---

## Major New Features

### Reyna Mayari's Silver Ledger & Moon Cards
The old pass-or-fail daily quota is gone. Instead, you now work toward paying off a **₱2,000 Silver Ledger** at your own pace.
- **Choose Your Nightly Tribute:** Every evening at closing time, offer a **Meager**, **Fair**, or **Lavish** payment depending on how your day went.
- **Permanent Ledger Milestones:** Hitting key milestones along the ledger unlocks permanent perks, including draft rerolls, better card odds, picking two cards a night, and unlocking Reyna Mayari as a daytime regular.
- **62 Moon Cards (Favors & Omens):** End each night by drafting from Common, Uncommon, and Rare cards that reshape tomorrow's run. Favors give clean boosts, while Omens offer risky trade-offs (like gusts of wind blowing your fridge door open in exchange for bigger cold-drink payouts).

### Papa Ulap's Counter Radio & Daily Street Events
- **Tune the Radio:** Buy and upgrade a transistor radio for your counter to hear **Papa Ulap** broadcast weather reports, folklore tidbits, commercials, and neighborhood news.
- **33 Neighborhood Events:** From *Barangay Fiesta*, *Payday Rush*, and *Balikbayan Box Day* to tough days like *Petsa de Peligro*, *Scheduled Brownout*, and *Flooded Access Road*, every morning brings shifting cravings and store conditions.
- **Visitor Sightings & Living Street Cameos:** Watch the street outside or tune the radio to spot which regulars are in town today. Neighbors now stroll past in both directions, and friends from connected stories will even walk down the road together.

### Full Store Upgrade Tree & Sign Painting Studio
Press **[U]** to open the new skill tree and build up your *tindahan* step by step toward **Open the Door**:
- **Store Tiers 1–10:** Unlock new snacks, canned goods, sachets, frozen ulam, drinks, and candy jars delivered in tossed plastic bags from Uncle Mario's tricycle.
- **Fridge Upgrades & Coldness Meter:** Keep the refrigerator door shut! Letting it warm up cuts chilled drink and frozen payouts until it cools back down.
- **Mingming the Store Cat:** Feed and upgrade your counter cat to serve **up to 3 customers at once**.
- **Tambayan Bench:** Give neighbors a place to hang out after shopping for passive XP, smalltalk, and second-round snack cravings.
- **Sto. Niño Altar, Business Permits, Maneki-Neko, Trash & Recycling, and Wholesale Pass** (unlocking Uncle Mario's daily discounted *Sulit Deals*).
- **Storefront Drawing Studio:** Paint your own **Roof Sign** and **Promo Poster**! Placing matching category stickers on your poster highlights a Featured Category for extra demand and bonus cash, and your custom artwork even shows up on the Main Menu store.

### Fair Pricing, Tips & *Tawaran* Haggling
- **Simple `-5` to `+5` Price Steps:** Hold **Alt** (even while holding an item!) or press **[L]** for the Price Ledger to adjust prices with the scroll wheel and see active bonuses at a glance.
- **Customer Tips:** Fair and generous pricing can earn appreciation tips and build neighborhood trust faster.
- **Tawaran Card Duel:** Push a markup a bit too far and a customer might challenge you to a timed verbal haggling card duel instead of walking straight out.

### 5 Filipino Street & Folklore Minigames
Break up counter shifts with five short minigames woven into daily life and character stories:
1. **Tawaran** — Read customer moods and play the right banter cards to seal a marked-up sale.
2. **Endless Sipa** — Keep the washer airborne and chase neighborhood high scores.
3. **Teks** — Classic street card flips against Buboy and regulars.
4. **Dusk Lamp Mosquito Swat** — Swat mosquitoes around the storefront bulb after 4:00 PM without hitting the fireflies.
5. **Anting-Anting Tracing** — Steady your hand to trace protective talisman sigils with Brahim.

### 11 Neighbors, Connected Stories, Folklore Journal & Epilogues
- **Meet Lolo Pilo:** A retired 1968 *sipa* champion with a sharp eye and an old secret joins the cast, bringing the neighborhood roster to **11 regulars**.
- **Interwoven 6-Chapter Arcs:** Neighbors no longer live in separate bubbles. Their stories cross paths across shared storylines, and your choices (forgiving *utang*, offering substitutes when you're out of stock, winning or losing minigames) shape how their lives turn out without locking you out of finishing their story.
- **Folklore Journal (`[J]`):** Earn **Reputation Ranks I–VI** with each regular to unlock perks, Counter Notes, Chapter Prerequisite hints, and illustrated entries on real Philippine folklore creatures (with credited community/archival artwork).
- **Karimlan Epilogues:** Sealing the Silver Ledger now unlocks a multi-card ending chronicle showing what became of every neighbor based on how you treated them.

---

## v1.0 Quick Changelog (Since `v0.9.6-beta`)

**Added**
- **3 Save Slots + Automatic Checkpoint Backups:** Start multiple runs or roll back to an earlier day anytime from the Load Menu.
- **Nightly Store Summary:** End-of-day report card tracking revenue, profit, tips, reputation gains, active cards, and daily rank stamps.
- **Player Leveling:** Earn XP from sales, visits, stories, and minigames for cash bonuses on every level-up.
- **Shortcut Dock (`[J]` / `[L]` / `[U]`):** Quick bottom-left access to the Journal, Price Ledger, and Upgrade Tree, synced to custom keybinds.
- **30 Animated Card Emblem Effects:** Distinct visual effects and borderless rarity colors across Events, Favors, and Omens.
- **Expanded Soundtrack & Audio Mixing:** Time-of-day music rotation with smooth crossfades, plus dedicated Restock, Minigame, and Closing-hour tracks.
- **Streamlined Tutorial:** Faster, hands-on 4-step opening tutorial with Uncle Mario and your Nokia phone.

**Changed & Improved**
- Rebuilt the entire codebase under the hood for smoother day transitions, cleaner multi-customer queues, and reliable save states.
- Simplified price refusal rules so **Price Tolerance** directly and transparently governs what markups customers accept.
- Allowed opening and closing the refrigerator while holding items or talking to customers.
- Added an **Utang Notebook** overhaul with page flipping, pending debt alerts, and crossed-out settled tabs.

**Fixed (180+ Bug Fixes Across the Entire Game)**

*Saves, Progression & Softlocks*
- Fixed an 8:00 PM softlock when reloading a save after Reyna Mayari had already visited, and ensured her visit flag only commits after finishing the nightly ritual.
- Fixed the in-game clock resetting to 5:00 AM on save reload, and fixed midnight clock wrap edge cases.
- Fixed duplicate end-of-day triggers and blocked the Pause Menu during the Nightly Summary to prevent mid-summary save corruption.
- Fixed saved 3D store upgrades (radio, permit, bench, Sto. Niño, door, signage) and candy/sachet jars failing to visually refresh after loading a save.
- Fixed already-completed customer encounters re-spawning when reloading mid-day, and fixed New Game leaving behind stale dialogue variables.
- Fixed guided tutorial handovers on restored saves, prevented double-toggling the fridge door during the tutorial, and awarded proper tutorial XP.

*Counter, Customers & Transactions*
- Fixed transient items occasionally deducting stock twice, and marked candy/sachet jars as non-sellable so customers never order the container itself.
- Fixed multi-item orders prematurely dismissing shoppers when a `Partial` dialogue label was missing, and disabled legacy desire-refresh signals that could wipe active orders.
- Fixed rejected items snapping back into your hand instead of returning neatly to their shelf spot.
- Fixed debt-repayment intros dismissing shoppers before their actual purchase, and fixed zero-peso / partial *utang* repayment deductions.
- Fixed waves and the clock stalling when multiple shoppers or returning *tambayan* visitors exited at the same time.
- Fixed lingering visitors blocking counter slots, fixed missing Buboy riddles (*Mayti* and *Utang ni Mang Juan*), and restricted riddle orders strictly to riddle-giving neighbors.
- Fixed full-basket Reputation bonuses awarding late (now triggers right as the shopper leaves) and prevented Reyna Mayari from randomly spawning as a daytime shopper before unlocking her 30% milestone.

*Pricing, Haggling & Restocking*
- Fixed the held-item Alt Pricing Lens rendering behind dragged items or getting stuck open after dropping an item or unlocking the cursor.
- Fixed unconfigured items accidentally migrating to price step `-3` on save load instead of staying at base step `0`.
- Fixed the Price Lens leaking unrevealed radio events before Papa Ulap announced them, preserved customer hover outlines while holding priced items, and included Neighbor Reputation tolerance bonuses in high-price checks.
- Fixed *Tawaran* haggling step `0` snapping back to the refused `+5` markup and locked out scrolling back to an already-refused price.
- Fixed Uncle Mario talking over active customer conversations when arriving with a delivery.
- Fixed store upgrades purchased mid-delivery so they merge cleanly into Uncle Mario's in-transit tricycle without consuming your product restock cooldown.
- Fixed plastic bag unpacking order so containers unpack before refills, expanded top-shelf capacity from `36` to `42`, and ensured Uncle Mario's delivery cooldown resets cleanly overnight.

*Minigames*
- Fixed a crash in *Dusk Lamp Mosquito Swat* when swatting freed mosquito instances.
- Fixed *Endless Sipa* Spacebar polling and matched the visual kick-zone hitbox.
- Fixed *Anting-Anting Tracing* guide-line stalls, unlocked the mouse cursor on open, and tightened tracing accuracy with pixel-exact coverage and stray-ink scoring.
- Fixed Dialogic speech bubbles staying visible on top of active minigames.

*Audio, Performance & Stability*
- Eliminated the noticeable dusk freeze caused by random seeking on the 53 MB night-crickets audio track.
- Fixed background music getting stranded silent or stuck on the Main Menu theme during gameplay, and fixed track repeats with persistent per-phase shuffle bags.
- Fixed a rapid-sale crash in floating money delta popups (`WeakRef` safety) and fixed stacked popups colliding with each other.
- Fixed a UI freeze in the Upgrade Menu scroll container and restored missing item pickup/drop sound effects.

*UI, Controls & Visual Polish*
- Fixed mouse cursor lock issues across Reyna Mayari's card draft, Nightly Summary, and minigames (plus added hold `Shift` to free the cursor anytime).
- Fixed Pause Menu opening cleanly over Reyna Mayari's tally without accidentally unpausing dialogue.
- Fixed notification timer bars overlapping toast text, centered event diamonds cleanly (with automatic 2-column overflow for 8+ active cards), and fixed scrollbar overlaps in the Folklore Journal.
- Fixed lingering visitor thought bubbles rendering in front of counter customers, fixed out-of-stock shading on the order HUD, and removed stray hover outlines on the locked store door.

---

## Thank You & What's Next

Thank you so much to everyone who played the early builds, left comments, shared the game, and patiently waited these past 7 months. Your support genuinely kept this little store alive until I had the time to give it a proper v1.0 release.

Please share your **honest feedback** — what feels fun, what feels clunky, which neighbors you loved, and where the balance feels off. We plan to keep polishing and developing the project, and our biggest dream down the road is to **one day hire a dedicated artist for custom character art**.

Salamat, *suki*, and welcome back to Karimlan!
