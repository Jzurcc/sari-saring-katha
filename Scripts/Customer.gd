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
var transaction_context: TransactionContext

@export var vertical_follow_factor: float = 1.0
@export var min_sprite_y: float = 1.3
@export var max_sprite_y: float = 2.4
var _base_sprite_y: float = 0.0
var _is_resolving: bool = false
var _spawn_position: Vector3 = Vector3.ZERO

@onready var body_sprite: Sprite3D = $Body
var _outline_material: ShaderMaterial = null

func _ready() -> void:
	input_event.connect(_on_input_event)

	# Place customers on layer 5 (value 16) so PlayerInteraction can detect
	# them with a dedicated raycast that passes through counters and items.
	collision_layer = 0
	set_collision_layer_value(5, true)

	if body_sprite:
		_base_sprite_y = body_sprite.position.y

func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(self)

func setup(context: TransactionContext, target: Vector3) -> void:
	# Capture spawn position now — global_position is already set by CustomerSpawner.
	_spawn_position = global_position
	transaction_context = context
	if transaction_context:
		character_id = transaction_context.character_id
	target_position = target

	# Apply the character's sprite texture and scale from their CustomerData resource.
	var char_data = StoryManager._get_character_data(character_id)
	if char_data and body_sprite:
		if char_data.sprite_texture:
			body_sprite.texture = char_data.sprite_texture
		body_sprite.scale = Vector3.ONE * char_data.sprite_scale

## Called by PlayerInteraction when the player aims at this customer and clicks.
## Only responds when waiting at the counter and not mid-animation.
func on_interact() -> void:
	if is_waiting and not _is_resolving:
		clicked.emit(self)

func _process(delta: float) -> void:
	# Skip movement and arrival while waiting at the counter OR while a
	# resolve/dismiss animation is playing. Without the _is_resolving check,
	# dismiss() sets is_waiting=false on the same frame, _process resumes,
	# and arrived_at_counter() fires a second time → double dialogue.
	if is_waiting or _is_resolving:
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
		
	if item == null or transaction_context == null:
		reject()
		return false

	if transaction_context.is_item_desired(item):
		satisfy()
		return true
	else:
		reject()
		return false

func satisfy() -> void:
	# Immediately mark as no longer waiting so nothing else can interact with
	# or dismiss this customer while the exit animation plays.
	is_waiting = false
	_is_resolving = true
	_clear_outline()
	InventoryManager.decrement_cooldown()
	
	await get_tree().process_frame
	
	if Dialogic.current_timeline != null:
		await Dialogic.timeline_ended
	else:
		await get_tree().create_timer(1.5).timeout
	
	# Smooth fade out before freeing
	var fade_tween = create_tween()
	fade_tween.tween_property(body_sprite, "modulate:a", 0.0, 0.4)
	await fade_tween.finished
	
	satisfied.emit()
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
	_clear_outline()

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

## Show or hide the hover outline on the customer sprite.
## Only shows when the customer is actively waiting and can be interacted with.
func on_hover(hovered: bool) -> void:
	if hovered and is_waiting and not _is_resolving:
		if _outline_material == null and body_sprite and body_sprite.texture:
			_outline_material = ShaderMaterial.new()
			_outline_material.shader = preload("res://Assets/Shaders/item_outline_spatial.gdshader")
			_outline_material.set_shader_parameter("albedo_texture", body_sprite.texture)
			_outline_material.set_shader_parameter("outline_color", Color.WHITE)
			_outline_material.set_shader_parameter("outline_width", 16.0)
			# Match the Sprite3D's billboard = 2 (Fixed Y) so the outline never
			# tilts when the player looks up or down.
			_outline_material.set_shader_parameter("fixed_y_billboard", true)
		if body_sprite:
			body_sprite.material_overlay = _outline_material
	else:
		_clear_outline()

func _clear_outline() -> void:
	if body_sprite:
		body_sprite.material_overlay = null
