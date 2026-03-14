# Godot 4 Comprehensive Scripting & Game Development Guide

A thorough reference compiled from official documentation, community best practices, and developer insights. Covers GDScript patterns, project architecture, performance, and more.

---

## 1. GDScript Coding Style & Conventions

Consistent style makes code readable and reduces errors. GDScript 4's style guide is inspired by Python's PEP 8.

### Naming Convention Cheat Sheet

| Element | Convention | Example |
|---|---|---|
| Files, folders, scenes, scripts | `snake_case` | `player_controller.gd` |
| Variables & functions | `snake_case` | `get_health()` |
| Private vars / methods | `_snake_case` | `_recalculate_path()` |
| Constants | `CONSTANT_CASE` | `MAX_SPEED = 300` |
| Classes (`class_name`) | `PascalCase` | `class_name PlayerStats` |
| Signals | `past_tense_snake_case` | `signal health_changed` |
| Enum names | `PascalCase` | `enum Element` |
| Enum members | `CONSTANT_CASE` | `Element.FIRE` |
| Node names in scene tree | `PascalCase` | `PlayerMovement` |

### Key Annotations

```gdscript
## A docstring (double ##) generates Inspector tooltips.
@export var speed: float = 200.0

## Organize Inspector properties into groups
@export_group("Combat Stats")
@export var damage: int = 10
@export var armor: int = 5
@export_subgroup("Special")
@export var crit_chance: float = 0.1

## Export with enum dropdown
@export_enum("Easy", "Normal", "Hard") var difficulty: int = 1

## Export file path filter
@export_file("*.png") var icon_path: String
```

> [!TIP]
> Always use `static var` and `static func` for shared helpers/data before reaching for a full Autoload. It's lighter weight.

---

## 2. Script Structure Order

The official GDScript style guide recommends this order within a script:

```gdscript
class_name MyNode
extends Node2D

## Tool annotation (if needed)
@tool

# 1. Signals
signal item_collected(item_data)

# 2. Enums & Constants
enum State { IDLE, RUNNING, JUMPING }
const GRAVITY: float = 980.0

# 3. @export variables
@export var speed: float = 200.0

# 4. Public variables
var current_state: State = State.IDLE

# 5. Private variables
var _velocity: Vector2 = Vector2.ZERO

# 6. @onready variables
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

# 7. Built-in virtual functions (_ready, _process, etc.)
func _ready() -> void:
    pass

func _physics_process(delta: float) -> void:
    pass

# 8. Public functions
func take_damage(amount: int) -> void:
    pass

# 9. Private functions
func _apply_gravity(delta: float) -> void:
    _velocity.y += GRAVITY * delta
```

---

## 3. Static Typing

Godot 4 strongly encourages static typing. It:
- Catches bugs earlier (compile-time vs. runtime)
- Improves readability
- Gives the engine more optimization opportunities

```gdscript
# ❌ Avoid — untyped, error-prone
var health = 100
func heal(amount):
    health += amount

# ✅ Prefer — typed, self-documenting
var health: int = 100
func heal(amount: int) -> void:
    health += amount

# Type inference with := (enforces type consistency)
var speed := 200.0  # Inferred as float

# Typing arrays and dictionaries
var inventory: Array[String] = []
var stats: Dictionary = {}  # Can't type dict values yet, but type the var
```

---

## 4. Signals & the Observer Pattern

Signals are Godot's built-in implementation of the **Observer Pattern**. They are the primary tool for loose coupling between nodes.

### The Golden Rule: "Call Down, Signal Up"

- **Parent → Child:** Call methods directly on child nodes.
- **Child → Parent:** Never call parent methods directly. Emit a signal and let the parent connect to it.

```gdscript
# ❌ Anti-pattern: child directly accessing parent
func _on_health_zero():
    get_parent().game_over()  # Tight coupling!

# ✅ Best practice: child emits a signal
signal died
func _on_health_zero():
    died.emit()  # Parent decides what "dying" means
```

### Connecting Signals

```gdscript
# Connecting in code (preferred for dynamic nodes)
$Enemy.died.connect(_on_enemy_died)

# Connecting with arguments (using lambdas in Godot 4)
$Enemy.health_changed.connect(func(new_health): print(new_health))

# One-shot connection (auto-disconnects after first call)
$Enemy.died.connect(_on_enemy_died, CONNECT_ONE_SHOT)
```

> [!IMPORTANT]
> Avoid connecting signals by **string names** (old Godot 3 style). Always connect using the **signal object** directly for type safety and IDE support.

### Global Event Bus (for Cross-System Events)

For events that need to reach unrelated, distant nodes (e.g., game-wide events like pausing), use an Autoload singleton as a centralized signal bus:

```gdscript
# GlobalEvents.gd (Autoload)
extends Node

signal game_paused(is_paused: bool)
signal score_changed(new_score: int)
```

```gdscript
# Any node can emit to the bus
GlobalEvents.score_changed.emit(new_score)

# Any node can listen
GlobalEvents.game_paused.connect(_on_game_paused)
```

> [!WARNING]
> Don't overuse the Event Bus. Reserve it for **truly global** events. Too many cross-system signals make dataflow hard to debug.

---

## 5. Scene Architecture & Node Communication

### Design for Independence

Each scene should be **self-sufficient**. It should work when run in isolation (F6 in the editor). If a scene needs external data, it should expose it via `@export` properties or signals — not by reaching out to the scene tree on its own.

```gdscript
# ❌ Brittle: scene assumes a specific tree structure
var player = get_node("/root/Main/World/Player")

# ✅ Robust: parent injects the reference
@export var player: CharacterBody2D
```

### Recommended Game Tree Structure

```
Main (Node)           ← main.gd: primary controller
├── World (Node2D)    ← game level (swappable for scene transitions)
│   ├── Player
│   ├── Enemies (spawner node)
│   └── Environment
└── GUI (CanvasLayer) ← kept separate so it survives scene transitions
    ├── HUD
    └── PauseMenu
```

### When to Use Nodes vs. Autoloads

| Scenario | Use |
|---|---|
| Logic scoped to a scene or entity | Regular node inside that scene |
| Shared functionality across scenes (with dependencies) | Regular node, injected via `@export` |
| Shared stateless helpers / libraries | `static func` in a named class |
| Game-wide state that persists across scene changes | Autoload (Singleton) |
| Broad events reaching many unrelated nodes | Autoload Event Bus |

---

## 6. State Machines

State machines are essential for managing complex entity behavior (player, enemies, AI, UI).

### Approach 1: Enum + Match (Simple)

Best for entities with a handful of straightforward states.

```gdscript
enum State { IDLE, RUNNING, JUMPING, DEAD }
var current_state: State = State.IDLE

func _physics_process(delta: float) -> void:
    match current_state:
        State.IDLE:    _process_idle(delta)
        State.RUNNING: _process_running(delta)
        State.JUMPING: _process_jumping(delta)

func _change_state(new_state: State) -> void:
    current_state = new_state
```

### Approach 2: Node-Based State Pattern (Scalable)

Best for complex entities where each state has substantial logic. Each state is a separate node/script.

```
Player (CharacterBody2D)
└── StateMachine (Node)
    ├── IdleState (Node)
    ├── RunState (Node)
    └── JumpState (Node)
```

```gdscript
# state.gd — base class for all states
class_name State extends Node

var state_machine  # reference to owning StateMachine

func enter() -> void: pass
func exit() -> void: pass
func update(delta: float) -> void: pass
func physics_update(delta: float) -> void: pass
```

```gdscript
# state_machine.gd
class_name StateMachine extends Node

@export var initial_state: State
var current_state: State

func _ready() -> void:
    for child in get_children():
        child.state_machine = self
    transition_to(initial_state)

func transition_to(new_state: State) -> void:
    if current_state: current_state.exit()
    current_state = new_state
    current_state.enter()

func _physics_process(delta: float) -> void:
    current_state.physics_update(delta)
```

> [!TIP]
> For even more complex AI (behavior trees, etc.), consider the **LimboAI** addon from the Asset Library.

---

## 7. Custom Resources (Data-Driven Design)

Custom Resources are Godot's equivalent of Unity's ScriptableObjects. They are perfect for decoupling data from logic.

### Creating a Custom Resource

```gdscript
# item_data.gd
class_name ItemData
extends Resource

@export var item_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var max_stack_size: int = 1
@export var sell_price: int = 0
```

Once defined, you can create `.tres` files from the Inspector and fill them in the editor — no code needed.

### ⚠️ The Shared Instance Gotcha

Resources loaded at runtime are **shared by default**. Modifying data on one reference changes it for ALL references.

```gdscript
# ❌ DANGER: modifying the shared template
func take_damage(amount: int) -> void:
    stats.health -= amount  # Changes the original Resource file!

# ✅ SAFE: duplicate the resource on _ready() to get a unique copy
func _ready() -> void:
    stats = stats.duplicate()  # Now we have our own copy
```

Or enable **"Local to Scene"** in the Inspector for embedded sub-resources — Godot will auto-duplicate them on instantiation.

### Saving & Loading

```gdscript
# Save
var save = MySaveData.new()
save.player_name = "Hero"
ResourceSaver.save(save, "user://save_data.tres")

# Load
var loaded: MySaveData = ResourceLoader.load("user://save_data.tres")
```

> [!IMPORTANT]
> Always use `user://` for runtime save files. `res://` is **read-only** in exported builds.

---

## 8. Input Handling

### The Correct Pattern: Action Maps

Always use the **Input Map** (Project Settings → Input Map) and check by logical action name — never hardcode physical keys.

```gdscript
func _physics_process(delta: float) -> void:
    # Continuous actions (held down)
    var direction := Input.get_axis("move_left", "move_right")
    velocity.x = direction * speed

func _unhandled_input(event: InputEvent) -> void:
    # One-shot actions (single frame)
    if event.is_action_pressed("jump"):
        jump()
    if event.is_action_pressed("ui_cancel"):
        pause()
```

### Choosing the Right Input Callback

| Callback | When to Use |
|---|---|
| `_process()` / `_physics_process()` with `Input.is_action_pressed()` | Continuous checks (movement, holding shoot) |
| `_input(event)` | Process ALL input events (including mouse motion) |
| `_unhandled_input(event)` | Game input that should be consumed by UI first (most game actions) |
| `_gui_input(event)` | Input specific to a Control node |

> [!TIP]
> Use `_unhandled_input` for game inputs — it respects UI focus so a button click won't also trigger your attack action.

---

## 9. Performance Optimization

### Profile First, Optimize Second

Use Godot's built-in **Profiler** (Debugger → Profiler tab) to find actual bottlenecks. Don't guess.

### Top Scripting Optimizations

| Technique | Why It Helps |
|---|---|
| Remove empty `_process()` | Empty process still has overhead every frame |
| Use `@onready` for node caching | Avoids repeated `get_node()` calls in hot paths |
| Object Pooling for bullets/particles | Eliminates expensive instantiate/free calls each frame |
| Use `Tween` for simple animations | More efficienet than manual lerp in `_process()` |
| Use `Timer` nodes for delayed logic | More efficient than manual delta counters |
| Add type hints | Helps the runtime optimize method dispatch |
| Avoid `get_node()` with long paths | Cache references in `_ready()` |
| `set_process(false)` for inactive entities | Stops processing for off-screen/inactive objects |

### When GDScript Isn't Enough

For performance-critical inner loops (physics simulations, pathfinding, procedural generation):
1. Try C# first (significant speedup, same API).
2. Use **GDExtension** (C/C++) for maximum performance.
3. GDScript can remain as the "glue" layer.

---

## 10. Project Folder Structure

### Recommended Structure (Entity-Based)

```
res://
├── addons/          ← Third-party plugins
├── assets/
│   ├── audio/
│   │   ├── music/
│   │   └── sfx/
│   ├── fonts/
│   ├── textures/
│   └── shaders/
├── entities/        ← One folder per game entity
│   ├── player/
│   │   ├── Player.tscn
│   │   ├── player.gd
│   │   └── player_sprite.png
│   ├── enemies/
│   │   ├── Slime.tscn
│   │   └── Goblin.tscn
│   └── items/
├── scenes/          ← Full game levels and screens
│   ├── MainMenu.tscn
│   ├── GameOver.tscn
│   └── levels/
├── systems/         ← Game-wide systems
│   ├── inventory/
│   ├── dialogue/
│   └── quest/
├── data/            ← Custom Resource (.tres) data files
│   ├── items/
│   └── enemies/
└── autoloads/       ← Singleton scripts
    ├── GlobalEvents.gd
    └── GameState.gd
```

### Key Rules
- Use `snake_case` for all files and folders.
- Name the script after its scene's root node.
- Keep folder depth to ≤ 5 levels.
- Use `.gdignore` files in folders with raw art assets (`.blend`, `.psd`) to prevent them from being imported by Godot.
- Commit to **Git** frequently, especially before renaming or moving files.

---

## Quick-Reference Summary

| Topic | Key Takeaway |
|---|---|
| **Architecture** | Design scenes to be independent and self-contained |
| **Communication** | "Call Down, Signal Up" — use signals for child→parent messages |
| **Autoloads** | Only for truly global state; use `static var` for simple data sharing |
| **State Machines** | Enum+Match for simple, Node-Pattern for complex |
| **Resources** | Use for data definitions; always `.duplicate()` before mutating |
| **Input** | Use the Input Map; prefer `_unhandled_input` for game actions |
| **Performance** | Profile first with Godot's profiler; use Object Pooling |
| **Code Style** | Snake_case files, PascalCase classes, CONSTANT_CASE constants |
