class_name Customer
extends Area3D

signal satisfied
@warning_ignore("unused_signal")
signal left
signal arrived(customer: Customer)
signal clicked(customer: Customer)

@export var movement_speed: float = 2.0
var target_position: Vector3
var is_waiting: bool = false
@export var character_id: String = "KuyaKap"
var desire: ItemData

@export var vertical_follow_factor: float = 1.0
@export var min_sprite_y: float = 1.3
@export var max_sprite_y: float = 2.4
var _base_sprite_y: float = 0.0
var _is_resolving: bool = false
var _spawn_position: Vector3 = Vector3.ZERO

@onready var body_sprite: Sprite3D = $Body

func _ready() -> void:
	input_event.connect(_on_input_event)
	
	# Store the initial position of the body sprite for the vertical follow logic
	if body_sprite:
		_base_sprite_y = body_sprite.position.y

func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(self)

func setup(data: ItemData, target: Vector3) -> void:
	# Capture spawn position now — global_position is already set by CustomerSpawner.
	_spawn_position = global_position
	desire = data
	target_position = target

## Called by PlayerInteraction when the player aims at this customer and clicks.
## Only responds when waiting at the counter and not mid-animation.
func on_interact() -> void:
	if is_waiting and not _is_resolving:
		clicked.emit(self)

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera and body_sprite:
		var pitch_deg := rad_to_deg(camera.global_rotation.x)
		var target_y := _base_sprite_y + (pitch_deg * 0.01 * vertical_follow_factor)
		body_sprite.position.y = clamp(target_y, min_sprite_y, max_sprite_y)

	# Early return optimization: skip processing when waiting at counter
	if is_waiting:
		return
	
	global_position = global_position.move_toward(target_position, movement_speed * delta)
	if global_position.distance_to(target_position) < 0.1:
		arrived_at_counter()

func arrived_at_counter() -> void:
	is_waiting = true
	arrived.emit(self)

func check_item(item: ItemData) -> bool:
	# Ignore new drops while a satisfaction/rejection animation is playing.
	if _is_resolving:
		return false
	if item == null or desire == null:
		reject()
		return false

	# Prefer the explicit id field; fall back to resource_path which is always
	# unique per .tres file. This prevents blank ids from matching everything.
	var item_key := item.id if item.id not in ["", "unset"] else item.resource_path
	var desire_key := desire.id if desire.id not in ["", "unset"] else desire.resource_path

	if item_key == desire_key:
		satisfy()
		return true
	else:
		reject()
		return false

func satisfy() -> void:
	# Lock against re-entry during the animation chain.
	_is_resolving = true
	InventoryManager.decrement_cooldown() #
	
	await get_tree().create_timer(2.0).timeout
	
	# Smooth fade out before freeing
	var fade_tween = create_tween()
	fade_tween.tween_property(body_sprite, "modulate:a", 0.0, 0.4)
	await fade_tween.finished
	
	satisfied.emit()
	# Broadcast on the EventBus so CustomerSpawner._on_customer_finished fires.
	EventBus.customer_satisfied.emit(self)
	queue_free()

func reject() -> void:
	_is_resolving = true
	await get_tree().create_timer(1.0).timeout
	_is_resolving = false
	# Notify EventBus so CustomerSpawner can track rejections.
	EventBus.customer_rejected.emit(self)

## Called by CustomerSpawner after the player chooses "Refuse service".
## Plays a brief leaving animation then notifies the EventBus.
func dismiss() -> void:
	is_waiting = false
	_is_resolving = true

	# Walk back toward the spawn edge
	var walk_tween = create_tween()
	walk_tween.tween_property(self, "global_position", _spawn_position, 1.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Fade out over the same duration
	var fade_tween = create_tween()
	fade_tween.tween_property(body_sprite, "modulate:a", 0.0, 1.2)

	await walk_tween.finished
	EventBus.customer_dismissed.emit(self)
	queue_free()
