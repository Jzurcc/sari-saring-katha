# Sari-Saring Katha — Gameplay & Systems Guide

A comprehensive, developer-focused guide to the **actual gameplay loops, systems, player interaction mechanics, and progression cycles** implemented in the *Sari-Saring Katha* codebase.

---

## 1. High-Level Gameplay Overview

In *Sari-Saring Katha*, the player runs a rural Philippine *sari-sari* (neighborhood convenience) store in the supernatural town of Karimlan. 

The game combines:
1. **Physical First-Person Store Simulation:** Arranging shelves, opening refrigerators, grabbing goods from jars and hanging sachet wires, and inspecting profit margins.
2. **Cozy Narrative Management:** Greeting colorful mythological neighbors, deciphering item requests and riddles, managing credit/debt (*Utang*), and uncovering customer story arcs.
3. **Daily Financial & Survival Rhythm:** Earning cash to restock inventory via Uncle Mario's delivery tricycle while keeping up with the nocturnal debt quota collected by Reyna Mayari.

---

## 2. The Core Player Engagement Loops

Gameplay operates on four nested loops that keep the player engaged from moment to moment, hour to hour, and day to day:

```
[1. Moment-to-Moment Interaction (Seconds)]
  Free-Look (WASD + Mouse) ──> Center-Screen Crosshair Hover
  ──> Toggle Pricing Lens (Alt) to check margins
  ──> Pick up shelf item OR dispense candy/sachet

[2. Customer Encounter Cycle (Minutes)]
  Customer arrives at counter window
  ──> Left-click customer to trigger 3D speech bubble greeting
  ──> Customer states item desires (HUD displays item icons / riddles)
  ──> Player fetches item from shelf/dispenser and drops on tray
        ├── Wrong Item  ──> Customer shivers red; item stays in player's hand
        └── Right Item  ──> Customer flashes green, particle glimmer spawns
                            ├── Paid cash ──> Money added to player balance
                            └── Utang     ──> Debt recorded in counter notebook
  ──> Satisfaction dialogue plays ──> Customer walks away

[3. Store Management & Restock (Hourly)]
  Monitor physical shelves & digital stock levels
  ──> Click countertop Nokia 3310 phone
  ──> Dial Uncle Mario (T9 or speed-dial "*")
  ──> Order wholesale stock or Tier Upgrades in catalog menu
  ──> Uncle Mario drives 3D tricycle to storefront
  ──> Dispensers auto-fill; floor plastic bags spawn
  ──> Player manually unpacks bags onto shelves

[4. Macro Progression & Nightly Quota (Daily)]
  05:00 AM: Shop opens; daytime customers arrive sequentially
  ──> 08:00 PM: Store closes (grace period for active customer)
  ──> Night: Reyna Mayari visits to collect daily debt quota
  ──> Autosave triggers (save_game.json)
  ──> Sleep overlay displays Philippine folklore wisdom quote
  ──> Day advances (Day += 1) ──> 05:00 AM morning reset
```

---

## 3. Moment-to-Moment Interaction Systems

### 3.1 First-Person Movement & Camera (`FPSController.gd`)
* **Locomotion:** WASD movement, head-bobbing, sprint (`Shift`), and crouch (`Ctrl`).
* **Mouse Capture:** The mouse cursor is captured (`MOUSE_MODE_CAPTURED`) for standard mouse-look. Pressing `Escape` pauses the game and displays the system cursor.
* **Camera Shake & Framing:** The camera receives procedural screen-shake on sales and can dynamically tween to frame customers during dialogue.

### 3.2 Dual-Layer Raycast Targeting (`PlayerInteraction.gd`)
The player interacts with the 3D world through a center-screen crosshair that casts two physics rays simultaneously:
* **Item Layer (Layer 1):** Detects shelf goods, container dispensers, the transaction tray, the trash can, and interactive props.
* **Customer Layer (Layer 5):** Exclusively detects customer hitboxes. Because it sits on its own collision mask, customer clicks and hovers pierce through the counter and items, preventing occlusion issues.
* **Visual Hover Feedback:** Hovered objects receive a dynamic spatial outline shader (`WorldInteractor.gd`) and gently scale up (`1.05x`).

### 3.3 The Drag-and-Drop System (`DragManager.gd`)
* **Grabbing Items:** Left-clicking a loose shelf item or clicking a container dispenser picks up a product.
* **2D Hand Visual:** The physical 3D item hides, and a 2D sprite icon appears on screen. The icon trails the player's view using a spring-damper physics model that tilts and sways dynamically with mouse movement.
* **3D Shelf Ghost Preview:** While holding an item near a shelf, a 3D ghost preview appears in the target slot, tinting white if the shelf accepts the item or red if the item category is disallowed or the shelf is full.
* **Drop Resolution:**
  * **Counter Tray / Customer:** Submits the item to fulfill the customer's active order.
  * **Shelf Surface:** Snaps the item into the nearest unoccupied shelf slot.
  * **Floor Delivery Bag:** Places the item back inside an active delivery bag.
  * **Trash Can:** Discards and deletes the item with a dust-puff VFX.
  * **Invalid Drop (Cancel):** Shelf items return to their original spot; transient items from jars/bags poof away and refund digital inventory stock.

---

## 4. The Economy & Pricing System

Unlike automated shop games, *Sari-Saring Katha* lets the player actively control profit margins on an item-by-item basis.

```
Wholesale Cost (price)
  │  (Paid to Uncle Mario)
  ▼
Player Markup (+₱0.50 steps via Mouse Wheel)
  │
  ▼
Final Selling Price (Paid by Customers)
  │
  ├── Within Markup Ceiling ──> Pricing Lens Heatmap:
  │                             [Green: Fair] -> [Yellow: High] -> [Red: Max]
  │
  └── Reaches Max Ceiling   ──> Customer Awareness (50% chance):
                                Customer complains about steep prices
```

### 4.1 The Pricing Lens (`Alt` + Scroll Wheel)
* Holding or toggling **`Alt`** activates the **Pricing Lens**.
* Hovering over any item or container displays a floating 3D billboard tooltip (`PricingOverlay.gd`):
  * **Item Name & Stock Level**
  * **Final Selling Price (`₱XX.XX`)**
  * **Profit Margin (`+₱X.XX (XX%)`)**
  * **Heatmap Indicator:** Color shifts smoothly from soft green (low margin) to yellow (moderate) to red (maximum markup).
* **Adjusting Prices:** Scrolling the mouse wheel up or down while hovering alters the selling price in **`₱0.50` increments**.
* **Price Ceilings:** Prices cannot be set below wholesale cost (`price`), nor can they exceed `get_max_selling_price()`. The legal markup ceiling scales from **35% at Tier 1 up to 60% at Tier 10** (with a `+₱3.00` buffer on low-cost items).

### 4.2 Cash vs. Utang (Debt Ledger)
When a sale concludes, the customer pays in one of two ways:
1. **Immediate Cash:** Cash is added to `GameManager.money`. The HUD money counter flashes green and plays a chime.
2. **Utang (Credit / I.O.U.):** Certain customers (like Manang Ana) may ask to take goods on credit.
   * If accepted, no cash is received immediately.
   * The owed amount is logged in `StoryManager.customer_debts`.
   * The player can click the 3D **Notebook** on the counter (`NotebookUI.gd`) at any time to open the ledger and view who currently owes money.
   * Customers periodically return on later visits to repay their debt in full or in half.

---

## 5. Physical Store Organization

The store interior contains three distinct storage formats that require different player habits:

```
+-------------------------------------------------------------+
|                       REFRIGERATOR                          |
|  - Hinged swinging door (click to toggle open/close)        |
|  - Spawns cold mist particles and hums                      |
|  - Holds 12 cold beverages (Coke, Gin, Water)               |
+-------------------------------------------------------------+
|                      DRY-GOODS SHELVES                      |
|  - 4 wooden shelf surfaces across the back/side walls       |
|  - Holds 36 dry products (canned goods, instant noodles,     |
|    snacks, cigarettes) in organic randomized slot layouts   |
+-------------------------------------------------------------+
|                      COUNTER DISPENSERS                     |
|  - Hanging Sachet Wire: Aryel, KneesToes, Kopimo            |
|  - Glass Candy Jars: Chubs, Mentor, Pocha, Assorted Mix     |
|  - Dispenses transient items on click; stock tracked digitally|
+-------------------------------------------------------------+
```

* **Interactive Props:**
  * **Store Cat:** Clicking the countertop cat plays a random meow, triggers a heart burst particle effect, and squashes the sprite.
  * **Overhead Fluorescent Light:** Emits subtle voltage flickers and occasional realistic glitch dips.
  * **Countertop Trash Can:** Drops here instantly destroy unwanted items with a squash animation and dust puff.

---

## 6. The Customer Experience

Customers arrive at the counter one by one throughout the day. Each encounter follows a structured lifecycle:

### 6.1 Arrival & Greeting
1. The customer walks up to the counter window with a bouncy walk cycle.
2. An arrival sound plays (unique voice blip per character).
3. The customer waits patiently. A 16px white outline appears when hovered.
4. The player left-clicks the customer. A Dialogic 3D speech bubble anchors above their head displaying their greeting and dialog choices.

### 6.2 Order Types
Once greeted, the customer's request appears in the top-right HUD:
* **Standard Purchase:** The customer requests 1 to 3 items (e.g. *"Pabili ng Coke at Chubs"*). Icons appear in the HUD.
* **Riddle Requests:** Certain playful characters (like Buboy) or random rolls will describe an item instead of naming it (e.g., *"Yung pampagising sa umaga"* for coffee, or *"is crispy and cheesy"*). The HUD displays a mysterious `?` silhouette; the player must deduce the item from its clue.
* **Social Visits:** Some encounters are pure neighborly check-ins (e.g., Danilo sharing neighborhood gossip, or Kuya Kap dropping by). No items are requested.
* **Next-Tier Teasers:** Customers occasionally ask for an item from one tier above the player's current store level, hinting at what can be unlocked next.

### 6.3 Handover & Resolution
* Dropping an item onto the counter tray validates the product:
  * **Wrong Item:** The customer shivers with a red outline, an error buzz sounds, and the item stays in the player's hand so it isn't accidentally dropped.
  * **Correct Item:** The customer flashes green, a golden particle glimmer spawns, the camera shakes subtly, the icon pops off the HUD, and cash/debt is processed.
* If all items in an order are fulfilled, the customer delivers their satisfaction dialogue, turns around, and walks away into the distance.

---

## 7. The Restock & Delivery Pipeline

When shelves run low, the player restocks through Uncle Mario, the local wholesale distributor:

```
1. CALLING UNCLE MARIO
   [Countertop Nokia 3310] ──(Click)──> [Nokia 2D Keypad Screen]
   ──(Dial "MARIO", "62777444666", or speed-dial "*")──> [Phone rings]
   ──(Uncle Mario answers)──> [Restock Catalog Menu Opens]

2. ORDERING IN THE CATALOG
   [Select Product Quantities / Tier Upgrades]
   ──(RestockOrder validates wallet, caps, and shelf space)──>
   [Confirm Order] ──(Deducts wholesale cost from money)──> [Menu Closes]

3. TRICYCLE DELIVERY
   [Uncle Mario drives 3D tricycle to storefront with engine rumble & honk]
   ──> Candies & Sachets: Automatically replenish digital dispensers
   ──> Tier Upgrades: Advance store tier + deliver 2 sample units per item
   ──> Shelf & Fridge Goods: Spawn in floor plastic bags around PlasticMarker
   ──> [Uncle Mario waves and drives away]

4. MANUAL UNPACKING
   [Click floor plastic delivery bag] ──> [Transient item picked up in hand]
   ──> [Drop item on shelf or fridge slot] ──> [Item reparents to shelf slot]
   ──> [When bag is completely emptied, bag pops with a puff and vanishes]
```

* **Uncle Mario Cooldown:** Uncle Mario needs time between trips. After every delivery, you must serve **2 customers** before he will take another order.
* **Floor Delivery Bags:** Shelf and fridge goods arrive in white plastic *sando* bags on the floor (up to 5 items per bag). The player manually clicks a bag to pull out an item and places it on display. Empty bags vanish with a puff animation.

---

## 8. Progression & Unlock Systems

Progression is designed to feel satisfying and steady across two complementary layers:

### 8.1 Store Tier Expansion (`Tiers 1 to 10`)
* **How to Advance:** Serving paying customers increments a hidden `purchase_counter`.
* **Threshold Formula:**
  $$\text{Required Purchases} = \text{clamp}\left(5 + \left\lfloor\frac{\text{Tier}}{2}\right\rfloor + \max(0, (\text{Tier} - 6) \times 2), 5, 15\right)$$
* When the quota is reached, a **Tier Upgrade Package** becomes available in Uncle Mario's phone catalog.
* **Tier Rewards:**
  * Unlocks new product categories (snacks $\rightarrow$ canned goods $\rightarrow$ noodles $\rightarrow$ frozen meats $\rightarrow$ cigarettes $\rightarrow$ beverages).
  * Automatically delivers **2 free sample units** of every newly unlocked product into the store.
  * Increases maximum allowable pricing margins (from 35% at Tier 1 up to 60% at Tier 10).
  * Unlocks new customer characters who only visit higher-tier stores.

### 8.2 Character Storylines & Narrative Arcs
* Every customer has **3 narrative arcs**, each spanning **3 story chapters** (9 chapters total per customer; Buboy has 10).
* **The Story Flow:**
  1. **Debut Encounter:** The character's first visit is always guaranteed to trigger Chapter 0.
  2. **Story Encounters vs. Generic Visits:** After a story chapter concludes, a cooldown of 1 to 3 generic visits occurs before another story chapter can trigger, keeping the store rhythm natural.
  3. **Daily Focus Character:** Each day, the game selects one character as the "Daily Focus" (weighted 30% to spawn). After experiencing 3 story moments in a single day, the focus shifts to another neighbor.
  4. **Branching Choices:** Narrative choices made during Dialogic conversations (e.g. choosing whether to encourage Kuya Kap to quit smoking) are saved permanently into `customer_story_branches`.

---

## 9. The Daily Cycle & Nightly Quota

Each in-game day runs from **5:00 AM to 8:00 PM**, governed by `DayClock.gd`:

| Time | In-Game Event | Gameplay Implication |
| :--- | :--- | :--- |
| **05:00 AM** | **Store Opens** | Morning ambience begins. Time advances at `1 in-game hour = 50 real seconds`. First customer spawns. |
| **Daytime** | **Store Operations** | Customers arrive sequentially. If a customer is left waiting at the counter for >4 in-game hours, time pauses to prevent unfair loss of daylight. |
| **06:00 PM** | **Dusk Transition** | Street lights turn on outside. Music shifts to mellow dusk playlists. Night crickets fade in. |
| **08:00 PM** | **Store Closing** | Clock snaps to 20:00 and halts regular customer spawns. If a customer is currently at the counter, a grace period lets you finish serving them (up to midnight). |
| **Night** | **Reyna Mayari's Visit** | Queen Mayari descends from Biringan to collect the store's daily debt installment. |
| **Bedtime** | **Autosave & Sleep** | Screen fades black with an eyelid blink. A Philippine folklore quote displays. Day counter increments, time resets to 5:00 AM, and your eyes open to the morning sun. |

### The Reyna Mayari Debt Installment
At closing time, Reyna Mayari visits the store:
* **The Formula:**
  $$\text{Daily Quota} = 50.0 + (\text{Quota Day} - 1) \times 15.0$$
* **If You Have Enough Cash:**
  * The quota is deducted from `GameManager.money`.
  * `quota_day` increments by 1.
  * Mayari departs pleased, and her narrative storyline advances.
* **If You Fall Short:**
  * Mayari delivers an angry warning.
  * `quota_day` does not advance (giving you another chance to pay the same amount tomorrow).
  * No instant "Game Over" occurs—the game allows you to rebuild earnings, maintaining its cozy simulation feel.

---

## 10. Player Interface & HUD Elements

```
+-------------------------------------------------------------------------+
| [₱ 250.00] (Top Left)                          [Customer Order HUD] (Top Right) |
| Flashes green on sale                         Shows requested item icons       |
| Shakes red on insufficient funds               or '?' for riddle items          |
|                                                                         |
|                                    +                                    |
|                             (Crosshair)                                 |
|                                                                         |
| [Helper Prompt Banner] (Bottom Center)         [Now Playing Indicator]  |
| Pops up during tutorial instructions           Displays active BGM title|
+-------------------------------------------------------------------------+
```

* **Customer Request HUD:** Displays item icons requested by the active customer. As items are placed on the tray, icons pop with a squash tween and disappear.
* **Collection Overlay:** Accessible from the menu or notebook. Lets the player inspect discovered products, view silhouettes of locked items, and read flavor lore.
* **Story Progress Overlay:** A clean three-level view (`Characters` $\rightarrow$ `Arcs` $\rightarrow$ `Chapters`) showing silhouette badges for locked neighbors and checkmarks for completed chapters.
