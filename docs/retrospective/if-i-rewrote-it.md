# Sari-Saring Katha — Architectural Retrospective

> *If I were to rebuild this game from scratch, what would I do differently?*

This document reviews the current codebase (`Scripts/`, 17 GDScript files) and identifies structural, architectural, and design-level improvements for a ground-up rewrite. Bugs and hotfixes are out of scope; this is about patterns, boundaries, and scalability.

---

## 1. Current Architecture Overview

The game is a **sari-sari (Filipino corner store) simulation** with a first-person 3D view, drag-to-interact item handling, day/night lighting transitions, customer service cycles, and dialogue via Dialogic.

**Current pattern:** A "Godot scene hierarchy" architecture where each gameplay concept maps to a node that lives either in the scene tree or as an autoload singleton. There is no explicit state machine, event bus, or service layer. Communication happens through a mix of direct node references, signals, group lookups, autoload singletons, and `get_parent().get_node()` calls.

### File Responsibility Mapping

| File | Role | Concerns |
|------|------|----------|
| `MainGame.gd` | Scene root, game loop, camera, customer lifecycle, money, dialogue | **~490 lines — God object** |
| `DragManager.gd` | FPS drag-drop coordinator (autoload) | Mostly good, but uses hardcoded paths |
| `InventoryManager.gd` | Stock tracking (autoload) | Good, but could be a proper resource manager |
| `ItemContainer.gd` | Shelf row layout, slot positioning | Clean, focused |
| `Shelf.gd` | Spawns `ItemContainer` rows | Thin wrapper, reasonable |
| `TransactionTray.gd` | Drop target signal relay | Pass-through, almost empty |
| `DraggableItem.gd` | 3D sprite + drag participation | Good separation |
| `Customer.gd` | Walk, arrive, accept/reject, leave | Mixed animation + logic |
| `Fridge.gd` | Door animation + light toggle | Clean |
| `FlickerLight.gd` | Fluorescent flicker effect | Clean |
| `NightLight.gd` | Night-time toggle light | Clean, overlaps `TimeOfDayLighting` |
| `TimeOfDayLighting.gd` | Cinematic lighting via keyframes + shader interpolation | Well-documented, but tightly bound to scene structure |
| `InputManager.gd` | Thin passthrough for camera view signals | Minimal passthrough |
| `ItemSelectionUI.gd` | Legacy icon grid (disabled) | Dead code, dynamically creates controls |
| `ConfirmationPopup.gd` | Legacy confirmation (disabled) | Dead code, dynamically creates controls |
| `MainMenu.gd` | Scene loader | Minimal |
| `ItemData.gd` | Resource definition for items | Good use of `Resource` base |

---

## 2. What I Would Change

### 2.1 Extract MainGame from Its God-Object Role

**Current:** `MainGame.gd` (~490 lines) handles free camera, FPS controls, gravity, head bobbing, FOV, collision debug visualization, view switching, customer spawning, dialogue coordination, money tracking, day progression, and item delivery. This is six responsibilities conflated into one node.

**From scratch:**

```
MainGame.tscn           — Scene root, node references only
  ├── PlayerController   (CharacterBody3D) — movement, gravity, head bob, FOV
  ├── CameraRig          (Node3D) — camera modes, view switching, free/fixed
  ├── GameLoop           (Node) — day/night cycle, customer spawning, money
  ├── InteractionSystem  (Node) — hover, interact, dialogue triggers
  └── DebugVisualization (Node) — collision shape drawing (debug only)
```

Each component answers one question: *How do I move?* vs. *Which customer is next?* vs. *What am I looking at?*

### 2.2 Decouple Dragging from Hardcoded Scene Paths

**Current:** `DragManager._ready()` and `DragManager.end_drag()` both reach for `"MainGame/CanvasLayer/CrosshairContainer"` via hardcoded path string. If the scene structure changes (rename, restructure, reuse in a different scene), it silently breaks.

**From scratch:** Use signals. `DragManager` emits `drag_started` / `drag_ended`. Any UI element that cares about the crosshair subscribes to those signals and shows/hides itself. The drag manager never knows about its consumers.

### 2.3 Resolve the Lighting Duplication

**Current:** There are three lighting systems running simultaneously:

- **`TimeOfDayLighting.gd`** — Sophisticated 6-keyframe cinematic interpolation controlling sun, moon, omni, night lights, shader parameters, and environment settings.
- **`NightLight.gd`** — Simple on/off toggle based on hour, using its own tween to fade between 0 and `MAX_ENERGY`.
- **`FlickerLight.gd`** — A separate fluorescent tube effect.

The `NightLight` node fights with `TimeOfDayLighting` — both set `light_energy` on overlapping lights. `TimeOfDayLighting` manages a `night_energy` value in its `night` keyframe, so `NightLight` is redundant.

**From scratch:** One lighting system. `TimeOfDayLighting` is kept as the master. If a flicker effect is needed for specific indoor lights, it becomes a local multiplier on top of the global energy — e.g., `actual_energy = base_energy * (1.0 + flicker_delta)`.

### 2.4 Replace Group-Based Discovery with Explicit Dependencies

**Current:** `DragManager` and `MainGame` find the `TransactionTray` by calling `get_tree().get_nodes_in_group("transaction_tray")` and grabbing `[0]`. This is fragile — if there are two trays (e.g., two counters), behavior becomes unpredictable. It's also a runtime search on an operation that should be wired at scene creation.

**From scratch:** Scene nodes expose signal/property dependencies as `@export var tray: TransactionTray` in the inspector, or register themselves on an event bus. Scene composition replaces runtime discovery.

### 2.5 Remove Dead Code

**Current:** `ItemSelectionUI.gd` and `ConfirmationPopup.gd` are disabled in `_ready()` with explicit "kept for future use" comments. They have been present and disabled for multiple commits. Dynamic UI creation (creating Buttons and TextureRects in code rather than scenes) makes them painful to style via the editor.

**From scratch:** Delete both. If a selection UI is needed later, build it as a scene with proper anchors, themes, and inspector-tweakable layout rather than programmatically constructing a `GridContainer`.

### 2.6 Separate Customer Animation from Customer Logic

**Current:** `Customer.satisfy()` embeds the entire animation sequence inline — stretch, jump, particle callback, squish, recover, fade, free — all in one function using nested tweens and `await`. Adding a different customer type (angry, confused, regular) would require copy-pasting or branching logic.

**From scratch:**

```
Customer               — State machine: Walking → Waiting → Interacting → Leaving
  ├── CustomerAnimation  — Reusable tween/animation sequences (satisfy, reject, leave)
  ├── CustomerAI         -- Decision logic (wants X, checks Y)
  └── CustomerVisuals    — Sprite, bubble, particles, label
```

State transitions emit signals. The animation component subscribes to `satisfied` / `rejected` signals. Different customer types swap out the AI component without touching animation or visuals.

### 2.7 Use an Event Bus Instead of Autocoupling Signals

**Current:** The signal graph is ad-hoc:

- `Dialogic.timeline_ended` → `MainGame`
- `Customer.satisfied` → `MainGame`
- `Customer.arrived` → `MainGame`
- `tray.item_placed` → `MainGame`
- `InputManager.view_requested` → `MainGame`
- `TimeOfDay.time_changed` → `TimeOfDayLighting`

Every signal goes to `MainGame`. As the game grows, `MainGame` will accumulate listeners for every system.

**From scratch:** A lightweight event bus (singleton with typed signals) that decouples senders from receivers:

```gdscript
# EventBus.gd (autoload)
signal customer_arrived(customer: Customer)
signal customer_satisfied(customer: Customer)
signal day_ended(day: int)
signal transaction_completed(item: ItemData, was_correct: bool)
signal money_changed(new_amount: int)

# Systems subscribe to what they care about, not just MainGame.
```

This means `DayProgression` could listen to `customer_satisfied` directly without `MainGame` counting and forwarding.

### 2.8 Make Item Comparison Robust and Data-Driven

**Current:** `Customer.check_item()` compares `item.resource_path == desire.resource_path`. This works because items are loaded as `.tres` resources, but it means two logically identical items from different paths are different customers' desires. It also means items must be files on disk (no runtime-generated items).

**From scratch:** Add a unique ID field to `ItemData`:

```gdscript
@export var id: String = ""  # e.g., "cigarettes_rolling_500"
```

Compare by `id` instead of `resource_path`. This allows items to exist in memory, be procedurally generated, or be shared across game modes without path collisions.

### 2.9 Remove the Unused `InputManager`

**Current:** `InputManager.gd` is a thin passthrough — it re-emits `_input` events that were already mapped to actions, so `InputManager.view_requested` just tells `MainGame` which action fired. `MainGame` already has access to `Input.is_action_just_pressed()` directly.

**From scratch:** Delete `InputManager.gd` entirely. If the game needs a centralized input abstraction (e.g., for rebinding or input buffering), build a proper input action map. Otherwise, `MainGame._input()` reads actions directly.

### 2.10 Improve InventoryManager's Role Boundary

**Current:** `InventoryManager` is an autoload that loads items from the filesystem at startup. This is a good choice (single source of truth for stock). However, it also holds `current_item_name` as a bridge variable for Dialogic timelines, which is a domain leak — a stock manager should not know about dialogue.

**From scratch:** The dialogue system should read from its own state or from a dedicated `DialogueState` singleton. `InventoryManager` handles stock only: `get_stock()`, `take_item()`, `return_item()`, `get_items_by_type()`.

### 2.11 Customer Wants Should Be Configurable, Not Hardcoded

**Current:** `MainGame.spawn_customer()` always loads Cigarettes:

```gdscript
var desired_item: ItemData = load("res://Resources/items/food/Cigarettes.tres")
```

This is fine for testing but not extensible.

**From scratch:** A `CustomerSpawner` or `EncounterTable` that defines what items customers want, with weights, day-progression rules, and unlock conditions:

```gdscript
class EncounterTable:
  var entries: Array[EncounterEntry]  # { item: ItemData, weight: float, min_day: int }

  func pick() -> ItemData:
    # weighted random selection
```

### 2.12 Proper Customer Variety

**Current:** Only one customer scene exists. All customers share the same `Customer.gd` script with the same sprites, bubble, and animation sequence.

**From scratch:** Data-driven customer definitions:

```gdscript
class_name CustomerDefinition extends Resource
@export var body_texture: Texture2D
@export var walk_speed: float
@export var greeting_timeline: String
@export var satisfaction_timeline: String
```

The `Customer` node is generic; its appearance, behavior, and dialogue are driven by the definition resource it receives in `setup()`.

---

## 3. Architecture Comparison: Current vs. Proposed

### Current Structure

```
MainGame (490 lines)
├── Handles: camera, gravity, bob, FOV, debug draw, view switching
├── Handles: customer spawn, dialogue, money, day tracking
├── Handles: item placement, rejection flow
├── Knows about: InputManager, DragManager, Tray, Dialogic, InventoryManager
└── Connects: every signal in the game

DragManager (autoload)
├── Hardcodes "MainGame/CanvasLayer/CrosshairContainer"
├── Queries groups for tray
└── Calls methods on DraggableItem directly

InventoryManager (autoload)
├── Loads items from filesystem
├── Manages stock
└── Holds current_item_name (dialogue concern)

TimeOfDayLighting + NightLight
├── Both adjust light_energy independently
└── Potential visual conflict
```

### Proposed Structure

```
MainGame (scene root — lightweight)
├── PlayerController — movement, physics, camera
├── CameraRig — view modes, transitions
├── GameLoop — day/night cycle, customer spawning, progression
├── TransactionHandler — item validation, money, customer response
└── DebugOverlay (optional, stripped in release)

Systems (singletons / sub-nodes)
├── EventBus — typed signals, decoupled communication
├── InventoryManager — stock only (no dialogue state)
├── DragManager — drag/orchestration with signals, not hardcoded paths
├── DialogueManager — bridges game state to Dialogic
├── LightingController — single source (TimeOfDayLighting only)
└── CustomerSpawner — encounter tables, variety

Data (resources, not scripts)
├── CustomerDefinition — appearance, behavior, dialogue per type
├── ItemData — item properties with unique IDs
└── EncounterTable — weighted customer/item definitions
```

---

## 4. Per-File Recommendations

| File | Keep | Change | Delete |
|------|------|--------|--------|
| `MainGame.gd` | Signal connections, game state variables | Extract player controls, camera, debug draw, transaction logic into separate nodes | |
| `DragManager.gd` | Drag lifecycle, sway physics | Replace hardcoded paths with signals | |
| `InventoryManager.gd` | Stock tracking, item loading | Remove `current_item_name` bridge variable | |
| `ItemContainer.gd` | | Nothing — clean design | |
| `Shelf.gd` | | Nothing — thin, appropriate wrapper | |
| `TransactionTray.gd` | Signal relay pattern | `activate_dropzone` / `deactivate_dropzone` are no-ops; implement or remove | The empty pass functions if never implemented |
| `DraggableItem.gd` | | Remove `label.hide()` dead reference (label is hidden and never shown) | |
| `Customer.gd` | Signal design, arrival logic | Extract animation sequences, make sprite/animation type-agnostic | |
| `Fridge.gd` | | Nothing — clean | |
| `FlickerLight.gd` | | Nothing — clean, self-contained | |
| `NightLight.gd` | | Entire script — superseded by `TimeOfDayLighting` | Delete |
| `TimeOfDayLighting.gd` | Keyframe architecture, interpolation logic | Accept node references via `@export` instead of `get_parent().get_node()` | |
| `InputManager.gd` | | Entire script — unnecessary passthrough | Delete |
| `ItemSelectionUI.gd` | | Entire script — disabled legacy code | Delete |
| `ConfirmationPopup.gd` | | Entire script — disabled legacy code | Delete |
| `MainMenu.gd` | | Nothing — minimal, appropriate | |
| `ItemData.gd` | Resource pattern | Add `id: String` field | |

---

## 5. Summary: What I Would Do Differently

1. **Split MainGame into focused components** — movement, camera, game loop, transactions, debug. No file should cross ~150 lines.
2. **Use an event bus** — decouple signal senders from receivers. Systems communicate through events, not through MainGame.
3. **Single lighting controller** — remove `NightLight.gd`; make `TimeOfDayLighting` the sole source.
4. **Delete all dead code** — `ItemSelectionUI`, `ConfirmationPopup`, and empty `TransactionTray` methods.
5. **Data-driven customers** — `CustomerDefinition` resource instead of hardcoded single type.
6. **Customer variety engine** — `EncounterTable` with weighted selection, not hardcoded Cigarettes.
7. **Unique item IDs** — compare by `id` field, not `resource_path`.
8. **Remove `InputManager.gd`** — unnecessary indirection layer.
9. **Use `@export` exports, not group lookups** — scene composition through inspection, not runtime discovery.
10. **Signal-based cross-system communication** — `DragManager` never knows node paths; it emits and the world reacts.
