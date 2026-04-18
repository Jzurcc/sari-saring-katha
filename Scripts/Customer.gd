class_name Customer
extends Area3D

signal satisfied(customer: Customer)
@warning_ignore("unused_signal")
signal left
signal arrived(customer: Customer)
signal clicked(customer: Customer)

@export var movement_speed: float = 2.0
var target_position: Vector3
var is_waiting: bool = false
var is_hovered: bool = false
var has_been_greeted: bool = false
var customer_data: CustomerData = null
var transaction_context: TransactionContext

@export var vertical_follow_factor: float = 1.0
@export var min_sprite_y: float = 1.3
@export var max_sprite_y: float = 2.4
var _base_sprite_y: float = 0.0
var _is_resolving: bool = false
var _spawn_position: Vector3 = Vector3.ZERO
var _exit_position: Vector3 = Vector3.ZERO
var _walk_timer: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO

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

func setup(context: TransactionContext, target: Vector3, exit: Vector3 = Vector3.ZERO) -> void:
	# Entrance Fade In
	if body_sprite:
		body_sprite.modulate.a = 0.0
		create_tween().tween_property(body_sprite, "modulate:a", 1.0, 0.5)
	
	# Capture spawn position now — global_position is already set by CustomerSpawner.
	_spawn_position = global_position
	# If no specific exit is provided, return to spawn by default
	_exit_position = exit if exit != Vector3.ZERO else _spawn_position
	
	transaction_context = context
	if transaction_context:
		customer_data = transaction_context.customer_data
	target_position = target
	_last_pos = global_position

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
		body_sprite.scale = Vector3.ONE * char_data.sprite_scale
		
		# Position the SpeechMarker relative to the character's height and data ratio.
		var speech_marker = get_node_or_null("SpeechMarker")
		if speech_marker and char_data.sprite_texture:
			var full_height_y = char_data.sprite_texture.get_height() * body_sprite.pixel_size
			var ratio = char_data.speech_marker_height_ratio
			speech_marker.position.y = (full_height_y * ratio) * char_data.sprite_scale

		# Adjust the collision shape so it tightly fits the customer's sprite boundaries.
		var collision_shape = get_node_or_null("CollisionShape3D")
		if collision_shape and collision_shape.shape is BoxShape3D and char_data.sprite_texture:
			# Duplicate shape so changes don't affect other instances
			var shape_copy: BoxShape3D = collision_shape.shape.duplicate()
			var sprite_w = char_data.sprite_texture.get_width() * body_sprite.pixel_size * char_data.sprite_scale
			var sprite_h = char_data.sprite_texture.get_height() * body_sprite.pixel_size * char_data.sprite_scale
			shape_copy.size = Vector3(sprite_w, sprite_h, shape_copy.size.z)
			collision_shape.shape = shape_copy
			# Set position so the bottom of the shape is at 0
			collision_shape.position.y = shape_copy.size.y / 2.0

		# Ensure the root node stays at unit scale.
		self.scale = Vector3.ONE
		
		# If this is Uncle Mario (Tutorial), mark him present to block phone calls
		if char_data and char_data.get_clean_id() == "unclemario":
			MarioManager.is_mario_physically_present = true


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
	# Movement logic
	if not is_waiting:
		var distance = global_position.distance_to(target_position)
		var is_leaving = _is_resolving and target_position == _exit_position
		
		# Allow movement if not resolving OR if we are explicitly leaving
		if not _is_resolving or is_leaving:
			var speed = movement_speed if not is_leaving else movement_speed * 1.5
			global_position = global_position.move_toward(target_position, speed * delta)
			
			if not is_leaving and distance < 0.1:
				arrived_at_counter()
		
		# Procedure Bouncy Walk Logic
		# We use the velocity (actual movement) to determine if we are "walking"
		var is_actually_moving = global_position.distance_to(_last_pos) > 0.001
		_last_pos = global_position
		
		if is_actually_moving:
			_walk_timer += delta
			var speed_factor = 10.0
			var amplitude = 0.08
			var sway_amount = 0.05
			
			if _is_resolving:
				speed_factor = 6.0
				amplitude = 0.04
				sway_amount = 0.02
				
			body_sprite.position.y = abs(sin(_walk_timer * speed_factor)) * amplitude
			body_sprite.rotation.z = sin(_walk_timer * speed_factor * 0.5) * sway_amount
		else:
			# Reset visuals when still
			body_sprite.position.y = move_toward(body_sprite.position.y, 0, delta)
			body_sprite.rotation.z = move_toward(body_sprite.rotation.z, 0, delta)

func arrived_at_counter() -> void:
	is_waiting = true
	_update_outline()
	
	# Landing Thud (Squash and Stretch)
	if body_sprite:
		var landing_tween = create_tween()
		var base_scale = Vector3.ONE * (customer_data.sprite_scale if customer_data else 1.0)
		# Squash down
		landing_tween.tween_property(body_sprite, "scale", Vector3(base_scale.x * 1.15, base_scale.y * 0.85, base_scale.z), 0.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		# Snap back with overshoot
		landing_tween.tween_property(body_sprite, "scale", Vector3(base_scale.x * 0.95, base_scale.y * 1.05, base_scale.z), 0.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Settle
		landing_tween.tween_property(body_sprite, "scale", base_scale, 0.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			
	arrived.emit(self)

func check_item(item: ItemData) -> bool:
	# Ignore new drops while a satisfaction/rejection animation is playing.
	if _is_resolving:
		return false
		
	# --- Special Case: Uncle Mario Tutorial ---
	# He is set as a VISIT type during the tutorial to bypass regular greeting logic,
	# but we need him to accept an item to finish the tutorial properly.
	if customer_data and customer_data.get_clean_id() == "unclemario":
		var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
		if gm and gm.is_tutorial_task_active:
			if gm.current_tutorial_task_id in ["allow_sale_early", "wait_for_sale"]:
				if transaction_context and transaction_context.fulfill_item(item):
					_on_item_accepted(item)
					
					# Complete the task
					gm._on_tutorial_task_completed()
					return true
			return false

	# Visiting customers should never receive items — silent red outline.
	if transaction_context and transaction_context.transaction_type == TransactionContext.Type.VISIT:
		reject()
		return false
		
	# Purchase customers must be greeted before they accept items — silent red pulse.
	if not has_been_greeted:
		reject()
		return false

	if item == null or transaction_context == null:
		reject()
		return false

	if transaction_context.fulfill_item(item):
		_on_item_accepted(item)
		return true
	else:
		reject()
		return false

func _on_item_accepted(item: ItemData) -> void:
	pulse_color(Color("#88d698")) # Soft Light Green
	
	# Excited Pop (Squash and Stretch)
	if body_sprite:
		var pop_tween = create_tween()
		var base_scale = Vector3.ONE * (customer_data.sprite_scale if customer_data else 1.0)
		# Squash down (matching talk timing)
		pop_tween.tween_property(body_sprite, "scale", Vector3(base_scale.x * 1.1, base_scale.y * 0.9, base_scale.z), 0.15) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Snap up with overshoot
		pop_tween.tween_property(body_sprite, "scale", Vector3(base_scale.x * 0.95, base_scale.y * 1.05, base_scale.z), 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Settle
		pop_tween.tween_property(body_sprite, "scale", base_scale, 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# If this was a riddle and we just solved the riddle item, clear the riddle flag
	if transaction_context.is_riddle and item == transaction_context.riddle_item:
		transaction_context.is_riddle = false
	
	if transaction_context.desired_items.is_empty():
		# Trigger the Goodbye/Satisfy dialogue flow in Spawner
		satisfied.emit(self)
	else:
		# Partial fulfillment: Update naming and stay at the counter.
		# We do NOT emit customer_satisfied yet, as the transaction is incomplete.
		if EventBus.has_signal("customer_partial_satisfaction"):
			EventBus.customer_partial_satisfaction.emit(self)

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
	
	# Points toward the custom exit marker and let _process handle the walk
	target_position = _exit_position
	
	var exit_tween = create_tween()
	exit_tween.tween_interval(2.0)
	exit_tween.tween_property(body_sprite, "modulate:a", 0.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	await exit_tween.finished
	
	if customer_data and customer_data.get_clean_id() == "unclemario":
		MarioManager.is_mario_physically_present = false
		
	# Emit completion signal only once FULLY resolved (gone from the scene)
	EventBus.customer_satisfied.emit(self)
	queue_free()


func reject() -> void:
	_is_resolving = true
	EventBus.request_sfx.emit("error")
	
	if _outline_material and body_sprite:
		body_sprite.material_overlay = _outline_material
		_outline_material.set_shader_parameter("outline_color", Color.RED)
		
	await get_tree().create_timer(0.3).timeout
	
	if _outline_material:
		_outline_material.set_shader_parameter("outline_color", Color.WHITE)
		
	_is_resolving = false
	_update_outline()

## Called by CustomerSpawner after the player chooses "Refuse service".
## Plays a brief leaving animation then notifies the EventBus.
func dismiss() -> void:
	is_waiting = false
	_is_resolving = true
	_clear_outline()
	InventoryManager.decrement_cooldown()

	# Point toward the custom exit marker and let _process handle the walk
	target_position = _exit_position
	
	var exit_tween = create_tween()
	exit_tween.tween_interval(2.0)
	exit_tween.tween_property(body_sprite, "modulate:a", 0.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await exit_tween.finished
	
	if customer_data and customer_data.get_clean_id() == "unclemario":
		MarioManager.is_mario_physically_present = false
		
	EventBus.customer_dismissed.emit(self)
	queue_free()

## Show or hide the hover outline on the customer sprite.
## Only shows when the customer is actively waiting and can be interacted with.
func on_hover(hovered: bool) -> void:
	is_hovered = hovered
	_update_outline()

func _update_outline() -> void:
	if is_hovered and is_waiting:
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


## One-shot animation played when the customer starts speaking.
func play_speak_animation() -> void:
	if not body_sprite: return
	
	var base_scale = Vector3.ONE * (customer_data.sprite_scale if customer_data else 1.0)
	var speak_tween = create_tween()
	
	# Two quick, subtle vertical pulses (1.0s total)
	# Two quick, subtle vertical pulses (0.6s total)
	# Pulse 1
	speak_tween.tween_property(body_sprite, "scale", Vector3(base_scale.x * 1.05, base_scale.y * 0.95, base_scale.z), 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	speak_tween.tween_property(body_sprite, "scale", base_scale, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Pulse 2
	speak_tween.tween_property(body_sprite, "scale", Vector3(base_scale.x * 1.05, base_scale.y * 0.95, base_scale.z), 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	speak_tween.tween_property(body_sprite, "scale", base_scale, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
