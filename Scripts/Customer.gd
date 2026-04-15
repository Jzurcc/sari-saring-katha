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
var has_been_greeted: bool = false
var customer_data: CustomerData = null
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
	# Place customers on layer 5 (value 16) so PlayerInteraction can detect
	# them with a dedicated raycast that passes through counters and items.
	collision_layer = 0
	set_collision_layer_value(5, true)

	if body_sprite:
		_base_sprite_y = body_sprite.position.y

# [REMOVED] _on_input_event moved to on_interact() to prevent double-firing with PlayerInteraction.

func setup(context: TransactionContext, target: Vector3) -> void:
	# Capture spawn position now — global_position is already set by CustomerSpawner.
	_spawn_position = global_position
	transaction_context = context
	if transaction_context:
		customer_data = transaction_context.customer_data
	target_position = target

	# Apply the character's sprite texture and scale from their CustomerData resource.
	var char_data = customer_data
	if char_data and body_sprite:
		if char_data.sprite_texture:
			body_sprite.texture = char_data.sprite_texture
			# Dynamically set the offset to half the texture height (in pixels).
			# Since 'centered' is true, this pins the texture bottom to the node origin.
			body_sprite.offset.y = char_data.sprite_texture.get_height() / 2.0
		
		# Reset sprite position to 0 so it sits at the root's origin.
		body_sprite.position.y = 0

		# Scale only the visuals and the speech marker.
		# This keeps the collision box at the original size defined in the scene.
		body_sprite.scale = Vector3.ONE * char_data.sprite_scale
		
		# Position the SpeechMarker in the middle of the scaled sprite.
		var speech_marker = get_node_or_null("SpeechMarker")
		if speech_marker and char_data.sprite_texture:
			var base_middle_y = (char_data.sprite_texture.get_height() / 2.0) * body_sprite.pixel_size
			speech_marker.position.y = base_middle_y * char_data.sprite_scale

		# Move the collision shape so its bottom is at 0 (without scaling it).
		var collision_shape = get_node_or_null("CollisionShape3D")
		if collision_shape and collision_shape.shape is BoxShape3D:
			collision_shape.position.y = collision_shape.shape.size.y / 2.0

		# Ensure the root node stays at unit scale.
		self.scale = Vector3.ONE


## Called by PlayerInteraction when the player aims at this customer and clicks.
## Only responds when waiting at the counter and not mid-animation.
func on_interact() -> void:
	if is_waiting and not _is_resolving:
		# Don't trigger if already in dialogue
		if Dialogic.current_timeline != null:
			return
			
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

	if transaction_context.fulfill_item(item):
		pulse_color(Color("#0f6e2f")) # Vibrant Green
		
		# If this was a riddle and we just solved the riddle item, clear the riddle flag
		if transaction_context.is_riddle and item == transaction_context.riddle_item:
			transaction_context.is_riddle = false
		
		if transaction_context.desired_items.is_empty():
			# Trigger the Goodbye/Satisfy dialogue flow in Spawner
			satisfied.emit()
		else:
			# Partial fulfillment: Update naming and stay at the counter.
			# We do NOT emit customer_satisfied yet, as the transaction is incomplete.
			if EventBus.has_signal("customer_partial_satisfaction"):
				EventBus.customer_partial_satisfaction.emit(self)
		return true
	else:
		reject()
		return false

func pulse_color(color: Color, duration: float = 0.5) -> void:
	if body_sprite == null: return
	var tween = create_tween()
	tween.tween_property(body_sprite, "modulate", color, duration * 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(body_sprite, "modulate", Color.WHITE, duration * 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func satisfy() -> void:
	# Immediately mark as no longer waiting so nothing else can interact with
	# or dismiss this customer while the exit animation plays.
	is_waiting = false
	_is_resolving = true
	_clear_outline()
	InventoryManager.decrement_cooldown()
	
	# We do NOT emit EventBus signs here yet, because the dialogue is about to start.
	# The EventBus signal is emitted AFTER the fade out to indicate full resolution.
	
	await get_tree().process_frame
	
	if Dialogic.current_timeline != null:
		await Dialogic.timeline_ended
	else:
		await get_tree().create_timer(1.5).timeout
	
	# Smooth fade out before freeing
	var fade_tween = create_tween()
	fade_tween.tween_property(body_sprite, "modulate:a", 0.0, 0.4)
	await fade_tween.finished
	
	# Emit completion signal only once FULLY resolved (gone from the scene)
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
