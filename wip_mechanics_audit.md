# 🏪 Sari-Saring Katha — WIP Mechanics Audit

> A honest, system-by-system map of what currently exists, what is stubbed out,
> and what the GDD calls for but hasn't been touched yet.
> Use this as the master reference before any overhaul sprint.

---

## How to Read This Document

Each system is rated on a simple three-state scale:

| Symbol | Meaning |
|--------|---------|
| ✅ | Working and functional as described |
| 🟡 | Partly implemented — code exists but is incomplete or hardcoded |
| ❌ | Missing entirely — needed per GDD but zero code exists |

---

## 1. Customer Loop

> The core gameplay rhythm: customer arrives → dialogue plays → player finds item → item dropped on tray → result.

| Feature | State | Notes |
|---|---|---|
| Customer walks to counter | ✅ | `move_toward()` in `Customer._process()` works |
| Customer speech bubble appears | ✅ | `bubble.visible = true` on arrival |
| Item icon shown in bubble | ✅ | `item_icon.texture` set from `desire.texture` |
| Arrival triggers dialogue | ✅ | `CustomerSpawner._on_customer_arrived()` calls `Dialogic.start()` |
| Correct item → satisfaction animation | ✅ | Squish tween + fade + `queue_free()` in `Customer.satisfy()` |
| Wrong item → rejection flash | ✅ | Red bubble flash, text reverts after 1s |
| Item check logic | ✅ | `Customer.check_item()` compares `item.id == desire.id` |
| Multiple customers per day | ✅ | `customers_per_day` counter in `CustomerSpawner` |
| Customer desires random/varied items | ❌ | **Hardcoded** to `Cigarettes.tres` every time — no pool or selection logic |
| Multiple customer characters (Manang Ana, T.K., etc.) | ❌ | Only Kuya Kap exists in dialogue and scene |
| Customer spawns from data profile | ❌ | No `CustomerProfile` resource — customer type, desires, and story are all fused with hardcode |
| Customer patience / time limit | ❌ | GDD says "no time limit" but also implies customers can leave — no leave logic exists |
| Customer navigation around furniture | ❌ | `move_toward()` cuts through anything; no `NavigationAgent3D` |
| Satisfaction emits `EventBus.customer_satisfied` | 🟡 | Signal exists on `EventBus`, but `Customer.satisfy()` only emits its own `satisfied` signal, not the bus signal — `CustomerSpawner` listens to `EventBus.customer_satisfied` which is never actually emitted from `Customer` |

> **Critical bug:** `EventBus.customer_satisfied` is wired in `CustomerSpawner._ready()` to count served customers, but `Customer.satisfy()` emits only its local `satisfied` signal. The spawner never knows a customer was satisfied unless `MainGame` happens to call something. The chain is broken.

---

## 2. Transaction / Item Submission

> The physical act of picking up an item and placing it on the tray.

| Feature | State | Notes |
|---|---|---|
| Drag item from shelf (FPS crosshair mode) | ✅ | `PlayerInteraction` raycasts and calls `on_interact()` |
| Item hides in 3D during drag | ✅ | `sprite.hide()` in `_on_drag_started_by_manager()` |
| 2D drag ghost follows cursor/crosshair | ✅ | `DragManager._dragged_texture_rect` with spring physics |
| Drop on tray via raycast | ✅ | `DragManager.end_drag()` raycasts and calls `tray.receive_item()` |
| Item returns to shelf on failed drop | ✅ | `return_to_start()` tween |
| Tray glows / activates on drag start | 🟡 | `DragManager` calls `activate_dropzone()` — **but `TransactionTray.gd` has no such method**; the call silently does nothing |
| Tray deactivates on drop | 🟡 | Same — `deactivate_dropzone()` call exists in `DragManager` but is not implemented on the tray |
| Item returned to inventory on cancel | ✅ | `InventoryManager.return_item()` called in `_on_drag_cancelled_by_manager()` |
| Double `take_item()` risk | 🟡 | Both `DraggableItem.on_interact()` and `PlayerInteraction._pickup_item()` call `InventoryManager.take_item()` — if both paths ever fire for the same click, stock is double-decremented |
| Drag in cursor-visible (non-FPS) mode | 🟡 | Code paths exist but the game currently forces FPS mouse capture — cursor mode untested |
| Item price shown before confirmation | ❌ | No price display anywhere in the transaction flow |
| Player sets custom price per item | ❌ | `ItemData.price` exists but is never read at transaction time as a player-set value |
| Change-making / cash calculation UI | ❌ | No UI for this — money just increments by `item.price` |

---

## 3. Inventory System

> Tracking what items exist, their stock counts, and how they flow through the store.

| Feature | State | Notes |
|---|---|---|
| Load all `.tres` items from `Resources/items/` | ✅ | `InventoryManager.initialize()` scans subfolders |
| Track stock count per item | ✅ | `_stock` dictionary works |
| Decrement stock on drag | ✅ | `take_item()` |
| Return stock on cancel | ✅ | `return_item()` |
| Items sorted alphabetically | ✅ | `naturalnocasecmp_to` sort in `initialize()` |
| Refresh shelf visibility when stock changes | 🟡 | `refresh_visibility()` exists but must be called manually — no event fires when stock changes |
| Only 3 items exist | 🟡 | `Candy.tres`, `Cigarettes.tres`, `Vinegar.tres` — far short of GDD's described product range |
| Items only in one category (`food`) | 🟡 | `ItemData.ItemType` has `SHELF` and `FRIDGE` but only `SHELF` items are present |
| Restocking via Uncle Mario call | ❌ | Mentioned in GDD as a core mechanic — no phone node, no call UI, no delivery sequence |
| Uncle Mario delivery cooldown | ❌ | Not implemented |
| Backroom / storage area with extra stock | ❌ | No backroom scene exists; all stock is on shelves |
| Stock carries over between days | ❌ | `_stock` resets to `max_stock` every time `initialize()` is called (which happens on autoload `_ready()`) |
| Player-set custom prices per item | ❌ | `ItemData.price` is read-only from the resource — no runtime price override system |
| Item categories beyond `food` (sachets, candy, frozen) | ❌ | Only one subfolder exists under `Resources/items/` |
| Save/load inventory state | ❌ | No persistence — stock resets every session |

---

## 4. Shelf & Item Display

> How items are physically shown in the 3D store.

| Feature | State | Notes |
|---|---|---|
| Shelf creates `ItemContainer` rows at runtime | ✅ | `Shelf._create_containers()` |
| Items arranged horizontally with spacing | ✅ | `_get_slot_position()` centers items across slots |
| Items filtered by type (SHELF vs FRIDGE) | ✅ | `accepted_type` filter in `ItemContainer` |
| Items filtered by category | ✅ | `accepted_categories` filter exists |
| Items with no texture are skipped | ✅ | `if not item_data.texture: continue` |
| Out-of-stock items hidden | 🟡 | `refresh_visibility()` method exists but must be called externally; shelves do not auto-hide when stock hits 0 during a session |
| Player manually drags items from backroom to shelf | ❌ | GDD calls for this restocking ritual at day start — not implemented; items just appear on shelves |
| String racks for sachets | ❌ | No scene or container type exists |
| Candy jars with picking mechanic | ❌ | Not implemented |
| Freezer for frozen goods | ❌ | Only the fridge exists; no separate freezer |
| Shelf customization / player-placed items | ❌ | Items are procedurally placed by `ItemContainer` — player cannot rearrange them |

---

## 5. Fridge

> The refrigerator behind the counter for chilled goods.

| Feature | State | Notes |
|---|---|---|
| Fridge door opens/closes with tween | ✅ | `toggle_open()` rotates `DoorPivot` 90° smoothly |
| Interior light turns on when open | ✅ | `interior_light` energy tweened 0 → 1 |
| Cold mist particle effect when open | 🟡 | Code references `$ColdMist` via `get_node_or_null` — no `play()` method exists on `GPUParticles3D` in Godot 4; this silently does nothing unless the node has a custom method |
| Fridge contains FRIDGE-type items | ❌ | No `FRIDGE` `ItemData` resources exist; fridge interior is empty |
| Player retrieves frozen item and brings it to counter | ❌ | No interaction flow for taking an item from the fridge to the tray; the GDD describes a specific two-step "open → drag to tray" sequence |
| Fridge hover highlight | 🟡 | `on_hover()` exists but is a no-op (`pass`) — no visual feedback |

---

## 6. Dialogue System

> Powered by Dialogic 2. Customer conversations, story beats, day transitions.

| Feature | State | Notes |
|---|---|---|
| First-meeting greeting for Kuya Kap | ✅ | `customer_greeting.dtl` — branching choices present |
| Returning visit dialogue | ✅ | `customer_returning.dtl` — short but functional |
| Satisfaction dialogue fires on correct item | ✅ | `customer_satisfied.dtl` called in `MainGame._on_tray_item_placed()` |
| Rejection dialogue fires on wrong item | ✅ | `customer_rejected.dtl` called |
| Day ended dialogue | ✅ | `day_ended.dtl` fires from `GameManager` |
| Item name injected into dialogue | ✅ | `{InventoryManager.current_item_name}` variable works |
| Dialogue choice options affect story | 🟡 | Branching choices exist in `customer_greeting.dtl` but have no consequence — they all converge to the same line, no flags set |
| Dialogue unlocks after specific game events | ❌ | No story flag / variable system in place |
| Multiple characters with unique personalities | ❌ | Only `KuyaKap.dch` exists — Manang Ana, T.K., Queen Mayari, etc. have no character sheets |
| Character-specific dialogue trees | ❌ | One greeting, one reject, one satisfied — shared across all future customers |
| Dialogue-gated item unlocks | ❌ | e.g., Kuya Kap buying bubblegum instead of cigarettes after story progress — not implemented |
| Kiwig deception dialogue | ❌ | Not started |
| Duwende encounter text | ❌ | Not started |
| Queen Mayari nightly visit dialogue | ❌ | Not started |
| Loan / credit dialogue branch (Manang Ana storyline) | ❌ | Not started |

---

## 7. Economy & Day Progression

> Money, debt quota, and the daily loop.

| Feature | State | Notes |
|---|---|---|
| Money increments on correct transaction | ✅ | `GameManager._on_transaction_completed()` adds `item.price` |
| Money displayed in UI | ✅ | `MoneyLabelUI` listens to `EventBus.money_changed` |
| Day counter increments | ✅ | `GameManager.day` increments after `day_ended` signal |
| Day start → customer spawn chain | ✅ | `EventBus.day_started` → `CustomerSpawner._on_day_started()` |
| Day ends after N customers served | 🟡 | Logic exists but relies on broken `EventBus.customer_satisfied` (see Customer Loop bug above) |
| Day fires immediately on scene load | 🟡 | `GameManager._ready()` emits `day_started` with no player trigger — customers spawn 2 seconds after the scene loads with no preamble |
| Queen Mayari debt quota system | ❌ | `daily_quota`, `debt_remaining`, installment payment — zero code exists |
| Overpayment / underpayment consequences | ❌ | No spirit threat escalation variable |
| Summary screen at end of day | ❌ | Day just loops; no earnings summary shown |
| Save / persist money and day between sessions | ❌ | All state is in RAM — resets on restart |
| Player sets item prices | ❌ | No price-setting UI or runtime price override |
| Loan system (give items on credit) | ❌ | Not started |
| Seasonal / quota scaling over days | ❌ | `daily_quota` doesn't exist at all yet |

---

## 8. Player Movement & Interaction

> The FPS character controller and how the player interacts with the 3D world.

| Feature | State | Notes |
|---|---|---|
| WASD first-person movement | ✅ | `FPSController.gd` |
| Mouse-look camera | ✅ | Pitch/yaw with `mouse_sensitivity` |
| Sprint (Shift) | ✅ | `sprint_speed` on keypress |
| Head bobbing | ✅ | Sine/cosine procedural bob |
| Dynamic FOV on sprint | ✅ | Lerped FOV delta |
| Step-up for small ledges | ✅ | `test_move()` stair-stepping logic |
| Raycast hover highlight on items | ✅ | `PlayerInteraction` highlights hovered `DraggableItem` |
| Click to pick up items | ✅ | `PlayerInteraction._input()` → `on_interact()` |
| Crosshair hides during drag | ✅ | `CrosshairUI` reacts to `drag_started` |
| Escape / pause to release mouse | 🟡 | No pause menu built — mouse lock can't be released in-game by the player |
| Camera shift to back of store (R key) | ❌ | GDD explicitly describes an "R key" to shift between storefront and backroom — not implemented |
| Interact with phone to call Uncle Mario | ❌ | No phone object; no call menu |
| Player can open/close back door | ❌ | No door interaction in store layout |
| Jump | ❌ | No jump — intentional for a store game, but gravity is still applied |
| Cursor mode for point-and-click sections | 🟡 | Code paths exist in `DragManager` but the game locks to FPS mouse capture; no explicit toggle |

---

## 9. Spirit Encounter Systems

> The Duwende Trio and Kiwig — obstacle/disruption mechanics.

| Feature | State | Notes |
|---|---|---|
| Duwende replaces stock with fakes | ❌ | Not started |
| Player clicks Duwende to undo effect | ❌ | Not started |
| Duwende spawn rate scales with debt | ❌ | Not started |
| Kiwig disguises as other customers | ❌ | Not started |
| Player accuses someone of being Kiwig | ❌ | Not started |
| Wrong accusation causes relationship damage | ❌ | Not started |
| Queen Mayari nightly debt collection | ❌ | Not started |
| Buntot Pagi item to repel Kiwig | ❌ | Not started |
| Duwende offerings as appeasement | ❌ | Not started |

> **This entire pillar of the GDD has zero implementation.**

---

## 10. Store Customization

> Player-directed layout and pricing.

| Feature | State | Notes |
|---|---|---|
| Items display on shelves | ✅ | `ItemContainer` populates from inventory |
| Player can freely place items anywhere | ❌ | Items are procedurally positioned by `ItemContainer` — no drag-to-place mode |
| Player sets custom price per product | ❌ | No price UI or runtime price data |
| Purchase new shelves / candy jars / racks | ❌ | No upgrade system |
| Permanent upgrades persist between days | ❌ | No save system |

---

## 11. Time of Day & Atmosphere

> The 24-hour sky cycle, lighting, and ambient feel.

| Feature | State | Notes |
|---|---|---|
| Sky color interpolates across 24h | ✅ | `SkyColorController.gd` with keyframe palettes |
| Sun/moon directional light rotates | ✅ | `TimeOfDayLighting.gd` |
| Golden hour tint overlay (screen filter) | ✅ | `GoldenHourFilter.gd` fades with time |
| Flickering interior lights | ✅ | `FlickerLight.gd` |
| Time advances per customer (dialogue-gated) | ❌ | Sky time runs in real-time, not per-customer turn — currently decorative only |
| Night triggers Mayari's visit | ❌ | Time of day has no gameplay hook |
| Rain / weather system | 🟡 | `Resources/weather_system/` folder exists but is empty |

---

## 12. UI

> The heads-up display and menus.

| Feature | State | Notes |
|---|---|---|
| Money label updates live | ✅ | `MoneyLabelUI` |
| Crosshair shows/hides during drag | ✅ | `CrosshairUI` |
| Held item name label on correct sale | 🟡 | `HeldItemLabelUI` appears on correct sale but **never hides** — once visible, the label stays on screen forever |
| Dialogic dialogue box | ✅ | Dialogic 2 panels render during conversations |
| Item selection UI | 🟡 | `ItemSelectionUI.tscn` exists as a scene file but has no attached script — appears to be an abandoned/unused panel |
| Confirmation popup | 🟡 | `ConfirmationPopup.tscn` scene exists with no integration in any script |
| Day summary screen | ❌ | No end-of-day earnings recap |
| Debt / quota tracker | ❌ | No UI for Queen Mayari's quota |
| Pause / main menu in-game | ❌ | `MainMenu.tscn` exists for the title screen but no in-game pause |
| Uncle Mario call menu (phone UI) | ❌ | Not started |
| Price-setting UI per shelf item | ❌ | Not started |
| Collectibles / quest log | ❌ | Not started |

---

## Quick-Reference Priority Table

Organizes what to tackle first based on impact to the core loop.

| Priority | System | What's Needed |
|---|---|---|
| 🔴 **Blocker** | Customer loop | Fix broken `EventBus.customer_satisfied` chain |
| 🔴 **Blocker** | Customer loop | Replace hardcoded `Cigarettes.tres` with `CustomerProfile` data |
| 🔴 **Blocker** | TransactionTray | Implement `activate_dropzone()` / `deactivate_dropzone()` |
| 🔴 **Blocker** | HeldItemLabelUI | Add auto-hide after N seconds |
| 🟠 **Core** | Economy | Day-open trigger (don't fire `day_started` on `_ready()`) |
| 🟠 **Core** | Economy | Day summary screen + debt quota basics |
| 🟠 **Core** | Inventory | Save/load stock and money between sessions |
| 🟠 **Core** | Inventory | `stock_changed` signal so shelves react without polling |
| 🟠 **Core** | Fridge | Add real `FRIDGE`-type items; implement the pick-up-from-fridge flow |
| 🟡 **Content** | Dialogue | Add remaining characters (Manang Ana, T.K., etc.) |
| 🟡 **Content** | Dialogue | Story flags / consequences for dialogue choices |
| 🟡 **Content** | Player | R-key camera shift to backroom |
| 🟡 **Content** | Player | Phone object + Uncle Mario call UI |
| 🟡 **Content** | Time | Tie sky time to customer turns, not real-time |
| ⚪ **Later** | Spirits | Duwende + Kiwig systems |
| ⚪ **Later** | Customization | Item placement + price-setting UI |
| ⚪ **Later** | Collectibles | Quest rewards, trinkets, log |
