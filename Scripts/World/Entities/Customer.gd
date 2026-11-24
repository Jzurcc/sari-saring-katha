class_name Customer
extends WorldInteractor

const AttentionBadge3D = preload("res://Scripts/World/Entities/CustomerAttentionBadge3D.gd")
const MotionControllerScript = preload("res://Scripts/World/Entities/CustomerMotionController.gd")
const MotionProfileScript = preload("res://Scripts/Data/CustomerMotionProfile.gd")

@warning_ignore("unused_signal")
signal satisfied(customer: Customer)
signal arrived(customer: Customer)
signal clicked(customer: Customer)
signal started_leaving(customer: Customer)
signal lingering_ready_to_return(customer: Customer)
signal lingering_departed(customer: Customer)

@export var movement_speed: float = 2.0
var target_position: Vector3
var is_waiting: bool = false
var is_hovered: bool = false
var _is_drag_hovered: bool = false
var has_been_greeted: bool = false:
	set(val):
		if has_been_greeted != val:
			has_been_greeted = val
			_update_attention_badge()
var customer_data: CustomerData = null
var transaction_context: TransactionContext

# Multi-slot & per-customer dialogue state
var slot_index: int = -1
var arrival_order: int = 0
var is_guest_customer: bool = false
var dialogue_phase: TransactionSession.Phase = TransactionSession.Phase.NONE
var greeting_interrupted: bool = false
var _is_repositioning: bool = false

# Lingering Visitor (Tambayan) & Ambient Cameo state
var is_lingering_visitor: bool = false
var is_returning_for_smalltalk: bool = false
var is_lingering_departure: bool = false
var is_ambient_cameo: bool = false
var _linger_session_id: int = 0

var _is_resolving: bool = false
var _spawn_position: Vector3 = Vector3.ZERO
var _exit_position: Vector3 = Vector3.ZERO
var _delayed_target: Vector3 = Vector3.ZERO
var _motion: MotionControllerScript = null

@onready var body_sprite: Sprite3D = $Body
var _outline_material: ShaderMaterial = null
var _visual_tween: Tween = null
var _hover_scale_tween: Tween = null
var _attention_badge: AttentionBadge3D = null
var _was_dialogue_open: bool = false


func _ready() -> void:
	super._ready()
	_was_dialogue_open = Dialogic.current_timeline != null
	_ensure_motion_controller()
	_sync_collision_layer()


func _ensure_motion_controller() -> void:
	if is_instance_valid(_motion):
		return
	_motion = MotionControllerScript.new()
	_motion.name = "MotionController"
	add_child(_motion)
	_motion.enter_finished.connect(_on_motion_enter_finished)
	_motion.reposition_finished.connect(_on_motion_reposition_finished)
	_motion.cameo_finished.connect(_on_motion_cameo_finished)


func _sync_collision_layer() -> void:
	# Layer 5 (value 16) allows PlayerInteraction to raycast customers through counters.
	# Disable while walking in, resolving/leaving, lingering, or playing an ambient cameo.
	var interactable := is_waiting and not _is_resolving and not is_lingering_visitor and not is_ambient_cameo
	collision_layer = 0
	set_collision_layer_value(5, interactable)
	if not interactable and is_hovered:
		on_hover(false)


func _apply_character_visuals() -> void:
	if not customer_data or not body_sprite:
		return
	if customer_data.sprite_texture:
		body_sprite.texture = customer_data.sprite_texture
		# Dynamically set the offset to half the texture height (in pixels).
		# Since 'centered' is true, this pins the texture bottom to the node origin.
		body_sprite.offset.y = customer_data.sprite_texture.get_height() / 2.0

	body_sprite.position.y = 0
	body_sprite.scale = Vector3.ONE * customer_data.sprite_scale

	# Position the SpeechMarker relative to the character's height and data ratio.
	var speech_marker = get_node_or_null("SpeechMarker")
	if speech_marker and customer_data.sprite_texture:
		var full_height_y = customer_data.sprite_texture.get_height() * body_sprite.pixel_size
		var ratio = customer_data.speech_marker_height_ratio
		speech_marker.position.y = (full_height_y * ratio) * customer_data.sprite_scale

	# Adjust the collision shape so it tightly fits the customer's sprite boundaries.
	var collision_shape = get_node_or_null("CollisionShape3D")
	if collision_shape and collision_shape.shape is BoxShape3D and customer_data.sprite_texture:
		var shape_copy: BoxShape3D = collision_shape.shape.duplicate()
		var sprite_w = customer_data.sprite_texture.get_width() * body_sprite.pixel_size * customer_data.sprite_scale
		var sprite_h = customer_data.sprite_texture.get_height() * body_sprite.pixel_size * customer_data.sprite_scale
		shape_copy.size = Vector3(sprite_w, sprite_h, shape_copy.size.z)
		collision_shape.shape = shape_copy
		collision_shape.position.y = shape_copy.size.y / 2.0

	self.scale = Vector3.ONE


func setup(context: TransactionContext, target: Vector3, exit: Vector3 = Vector3.ZERO, delayed_arrival: bool = false) -> void:
	_ensure_motion_controller()
	_spawn_position = global_position
	_exit_position = exit if exit != Vector3.ZERO else _spawn_position
	target_position = target

	transaction_context = context
	if transaction_context:
		customer_data = transaction_context.customer_data

	_apply_character_visuals()

	# Floating attention indicator ("!" when ungreeted, "..." when returning for smalltalk)
	if customer_data and body_sprite and not is_ambient_cameo:
		var speech_marker = get_node_or_null("SpeechMarker")
		_attention_badge = AttentionBadge3D.new()
		add_child(_attention_badge)
		var badge_y := 1.8
		if customer_data.sprite_texture:
			badge_y = (customer_data.sprite_texture.get_height() * body_sprite.pixel_size * customer_data.sprite_scale) + 0.24
		elif speech_marker:
			badge_y = speech_marker.position.y + 0.55
		_attention_badge.position = Vector3(0.0, badge_y, 0.0)
		_attention_badge.set_base_y(badge_y)
		_update_attention_badge()

	if transaction_context and transaction_context.blocks_phone_call:
		MarioManager.is_mario_physically_present = true

	var motion_profile: MotionProfileScript = null
	if transaction_context and transaction_context.motion_profile != null:
		motion_profile = transaction_context.motion_profile
	elif customer_data != null:
		var ch := CharacterProgressionManager.get_chapter(customer_data.resource_path)
		var is_story := transaction_context != null and transaction_context.transaction_type == TransactionContext.Type.STORY
		motion_profile = customer_data.pick_motion_profile(ch, is_story)

	_motion.configure(
		self,
		body_sprite,
		_get_base_sprite_scale(),
		motion_profile,
		_spawn_position,
		target,
		_exit_position,
		movement_speed
	)

	if delayed_arrival:
		_delayed_target = target
		_motion.start_delayed()
	else:
		_motion.start_enter()


## Configures this Customer instance as a non-interactive background/pass-by ambient cameo
## (e.g. Manang Ana flying across the sky, Rosalyn gliding past the counter and vanishing).
func setup_ambient_cameo(
	char_data: CustomerData,
	cameo_profile: MotionProfileScript,
	spawn_pos: Vector3,
	counter_pos: Vector3,
	exit_pos: Vector3
) -> void:
	_ensure_motion_controller()
	is_ambient_cameo = true
	is_waiting = false
	customer_data = char_data
	_spawn_position = spawn_pos
	_exit_position = exit_pos
	target_position = counter_pos
	_sync_collision_layer()
	_apply_character_visuals()
	if body_sprite:
		body_sprite.sorting_offset = -1.0
	_motion.configure(
		self,
		body_sprite,
		_get_base_sprite_scale(),
		cameo_profile,
		spawn_pos,
		counter_pos,
		exit_pos,
		movement_speed
	)
	_motion.start_ambient_cameo()


## Forces a delayed customer to start their arrival sequence.
func trigger_arrival() -> void:
	if _delayed_target != Vector3.ZERO:
		target_position = _delayed_target
		_delayed_target = Vector3.ZERO
		if is_instance_valid(_motion):
			_motion.start_enter()


func _on_motion_enter_finished() -> void:
	if not is_waiting and not _is_resolving and not is_lingering_visitor and not is_ambient_cameo:
		arrived_at_counter()


func _on_motion_reposition_finished() -> void:
	_is_repositioning = false


func _on_motion_cameo_finished() -> void:
	queue_free()


## Called by PlayerInteraction when the player aims at this customer and clicks.
## Only responds when waiting at the counter and not mid-animation.
func on_interact() -> void:
	if is_waiting and not _is_resolving and not is_ambient_cameo:
		# Don't trigger if already in dialogue, unless it's paused (e.g. tutorial tasks)
		if Dialogic.current_timeline != null and not Dialogic.paused:
			return
			
		clicked.emit(self)
		EventBus.customer_clicked.emit(self)

func _process(_delta: float) -> void:
	if is_ambient_cameo:
		return
	var dialogue_open := Dialogic.current_timeline != null
	if dialogue_open != _was_dialogue_open:
		_was_dialogue_open = dialogue_open
		_update_attention_badge()

func arrived_at_counter() -> void:
	is_waiting = true
	_sync_collision_layer()
	_update_outline()
	_update_attention_badge()
	
	# Landing Thud (Squash and Stretch) — skipped for floating/ghostly motion profiles
	var should_thud := true
	if is_instance_valid(_motion):
		should_thud = _motion.should_play_landing_thud()
	if body_sprite and should_thud:
		if _visual_tween: _visual_tween.kill()
		_visual_tween = create_tween()
		var base_scale = _get_base_sprite_scale()
		# Squash down
		_visual_tween.tween_property(body_sprite, "scale", Vector3(base_scale.x * 1.15, base_scale.y * 0.85, base_scale.z), 0.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		# Snap back with overshoot
		_visual_tween.tween_property(body_sprite, "scale", Vector3(base_scale.x * 0.95, base_scale.y * 1.05, base_scale.z), 0.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Settle
		_visual_tween.tween_property(body_sprite, "scale", base_scale, 0.1) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			
	if customer_data:
		AudioManager.play_dialogue_blip(customer_data)
		
	arrived.emit(self)

func check_item(item: ItemData) -> bool:
	# NEW: Ensure customer is settled at the counter before accepting items.
	# This prevents race conditions where items are given while the customer is walking,
	# cause the Spawner's is_waiting check to reject the dialogue start.
	if not is_waiting or _is_resolving:
		return false
		
	# --- Guided Tutorial Encounter ---
	# Guided tutorial encounters use VISIT to bypass regular greeting logic,
	# and delegate item acceptance to TutorialManager when a sale task is active.
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	var is_guided: bool = (transaction_context and transaction_context.is_guided_tutorial) or (gm and gm.tutorial and gm.tutorial.is_guided_timeline_active())
	if is_guided:
		if gm and gm.tutorial and gm.tutorial.can_accept_guided_item():
			var accepted: bool = false
			if transaction_context and not transaction_context.desired_items.is_empty():
				accepted = transaction_context.fulfill_item(item)
			elif item and item.get_clean_id() == "anoba":
				# Fallback for restored tutorial saves where desired_items was empty
				accepted = true
			if accepted:
				_on_item_accepted(item)
				gm.tutorial.complete_active_task()
				return true
		return false

	if not transaction_context or item == null:
		reject()
		return false

	# Visiting customers (including Visit-type story chapters) should never receive items — silent red outline.
	if transaction_context.transaction_type == TransactionContext.Type.VISIT or transaction_context.is_visit_story:
		reject()
		return false
		
	# Purchase customers must be greeted before they accept items — silent red pulse.
	if not has_been_greeted:
		# Special case for Mario: if MainGame handles the early start, don't pulse here.
		return false

	# Story fallback: If this is a STORY but the dev forgot to populate items (and it's not a visit-story), accept anything.
	if transaction_context.transaction_type == TransactionContext.Type.STORY and transaction_context.desired_items.is_empty():
		LogManager.info("Customer", "STORY type with empty wants detected. Accepting any item as 'gift'.")
		_on_item_accepted(item)
		return true

	if transaction_context.fulfill_item(item):
		_on_item_accepted(item)
		return true

	reject()
	return false

func _get_base_sprite_scale() -> Vector3:
	return Vector3.ONE * (customer_data.sprite_scale if customer_data else 1.0)

func _start_visual_tween() -> Tween:
	if _visual_tween:
		_visual_tween.kill()
	_visual_tween = create_tween()
	return _visual_tween

func _on_item_accepted(item: ItemData) -> void:
	# VISUAL: Stronger green pulse for success
	pulse_color(Color("#9CFFB0"), 0.6) 
	
	# Excited Pop (Exaggerated Squash and Stretch)
	if body_sprite:
		var tw = _start_visual_tween()
		var base_scale = _get_base_sprite_scale()
		# Squash down
		tw.tween_property(body_sprite, "scale", Vector3(base_scale.x * 1.2, base_scale.y * 0.8, base_scale.z), 0.1) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# Snap up (Stretch)
		tw.tween_property(body_sprite, "scale", Vector3(base_scale.x * 0.85, base_scale.y * 1.2, base_scale.z), 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		# Settle
		tw.tween_property(body_sprite, "scale", base_scale, 0.3) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# If this was a riddle and we just solved the riddle item, clear the riddle flag
	if transaction_context.is_riddle and item == transaction_context.riddle_item:
		transaction_context.is_riddle = false
	
	if not transaction_context.desired_items.is_empty():
		# Partial fulfillment: Update naming and stay at the counter.
		# We do NOT emit customer_satisfied yet, as the transaction is incomplete.
		if EventBus.has_signal("customer_partial_satisfaction"):
			EventBus.customer_partial_satisfaction.emit(self)

func pulse_color(color: Color, duration: float = 0.5) -> void:
	if body_sprite == null: return
	var tween = create_tween().set_parallel(true)
	var tr: float = clampf(color.r * 1.2, 0.0, 1.0)
	var tg: float = clampf(color.g * 1.2, 0.0, 1.0)
	var tb: float = clampf(color.b * 1.2, 0.0, 1.0)

	# Tween RGB channels only so custom motion opacity (modulate.a) is always preserved
	tween.tween_property(body_sprite, "modulate:r", tr, duration * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(body_sprite, "modulate:g", tg, duration * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(body_sprite, "modulate:b", tb, duration * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var back = tween.chain().set_parallel(true)
	back.tween_property(body_sprite, "modulate:r", 1.0, duration * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	back.tween_property(body_sprite, "modulate:g", 1.0, duration * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	back.tween_property(body_sprite, "modulate:b", 1.0, duration * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func move_to_slot(new_slot: int, new_target: Vector3) -> void:
	if _is_resolving or is_lingering_visitor or is_ambient_cameo:
		return
	slot_index = new_slot
	target_position = new_target
	if is_waiting:
		_is_repositioning = true
	if is_instance_valid(_motion):
		_motion.start_reposition(new_target)

func get_order_hud_key() -> String:
	if customer_data:
		return customer_data.character_name if customer_data.character_name != "" else customer_data.get_clean_id()
	return name

func enter_lingering_mode(hangout_points: Array[Vector3]) -> void:
	if _is_resolving:
		return
	is_lingering_visitor = true
	is_returning_for_smalltalk = false
	is_waiting = false
	slot_index = -1
	_sync_collision_layer()
	_clear_outline()
	_update_attention_badge()
	_linger_session_id += 1
	var my_session := _linger_session_id

	if not hangout_points.is_empty():
		target_position = hangout_points[0]
		if is_instance_valid(_motion):
			_motion.start_lingering(hangout_points[0])

	_run_linger_routine(hangout_points, my_session)

func _run_linger_routine(hangout_points: Array[Vector3], my_session: int) -> void:
	if not is_inside_tree():
		return

	# Pause briefly at the first spot, then stroll between 2–4 more background spots
	await get_tree().create_timer(randf_range(4.0, 7.5)).timeout
	if not is_instance_valid(self) or not is_inside_tree() or my_session != _linger_session_id or not is_lingering_visitor:
		return

	for i in range(1, hangout_points.size()):
		if randf() > 0.85 and i >= 2:
			break
		target_position = hangout_points[i]
		if is_instance_valid(_motion):
			_motion.set_lingering_target(hangout_points[i])
		# Give them time to walk there + pause briefly before the next stroll
		await get_tree().create_timer(randf_range(4.5, 8.5)).timeout
		if not is_instance_valid(self) or not is_inside_tree() or my_session != _linger_session_id or not is_lingering_visitor:
			return

	lingering_ready_to_return.emit(self)

func return_to_counter_for_smalltalk(new_slot: int, slot_target: Vector3) -> void:
	if _is_resolving:
		return
	_linger_session_id += 1
	is_lingering_visitor = false
	is_returning_for_smalltalk = true
	slot_index = new_slot
	is_waiting = false
	_sync_collision_layer()
	_update_attention_badge()
	target_position = slot_target
	if is_instance_valid(_motion):
		_motion.start_return_from_lingering(slot_target)

func leave_from_lingering() -> void:
	if _is_resolving:
		return
	_linger_session_id += 1
	is_lingering_visitor = false
	is_returning_for_smalltalk = false
	is_lingering_departure = true
	await _leave_store(lingering_departed)

func satisfy() -> void:
	await _leave_store(EventBus.customer_satisfied)


func _leave_store(completion_signal: Signal) -> void:
	# Immediately mark as no longer waiting so nothing else can interact with
	# or dismiss this customer while the exit animation plays.
	_linger_session_id += 1
	is_waiting = false
	is_lingering_visitor = false
	_is_resolving = true
	_sync_collision_layer()
	_clear_outline()
	_update_attention_badge()
	if body_sprite:
		body_sprite.sorting_offset = -1.5
	EventBus.customer_order_cleared.emit(get_order_hud_key())
	started_leaving.emit(self)
	if not is_lingering_departure:
		InventoryManager.decrement_cooldown()

	if is_instance_valid(_motion):
		_motion.start_exit()
		await _motion.exit_finished
	else:
		await get_tree().create_timer(2.0).timeout

	if transaction_context and transaction_context.blocks_phone_call:
		MarioManager.is_mario_physically_present = false

	# Emit completion signal only once FULLY resolved (gone from the scene)
	completion_signal.emit(self)
	queue_free()


func reject() -> void:
	_is_resolving = true
	_sync_collision_layer()
	_update_attention_badge()
	EventBus.request_sfx.emit("error")
	
	# VISUAL: Disappointed Squash and Stretch + Shiver
	if body_sprite:
		var tw = _start_visual_tween()
		var base_scale = _get_base_sprite_scale()
		
		# Pulse red
		if _outline_material:
			body_sprite.material_overlay = _outline_material
			_outline_material.set_shader_parameter("outline_color", Color.RED)
		
		# Squash down and vibrate (Shiver)
		tw.set_parallel(true)
		tw.tween_property(body_sprite, "scale", Vector3(base_scale.x * 1.08, base_scale.y * 0.92, base_scale.z), 0.1) \
			.set_trans(Tween.TRANS_SINE)
		
		# Quick horizontal shiver sequence
		var shiver_tween = create_tween()
		shiver_tween.tween_property(body_sprite, "position:x", 0.04, 0.05)
		shiver_tween.tween_property(body_sprite, "position:x", -0.04, 0.05)
		shiver_tween.tween_property(body_sprite, "position:x", 0.03, 0.05)
		shiver_tween.tween_property(body_sprite, "position:x", -0.03, 0.05)
		shiver_tween.tween_property(body_sprite, "position:x", 0.0, 0.05)
		
		tw.set_parallel(false)
		
		# Bounce back
		tw.tween_property(body_sprite, "scale", base_scale, 0.2) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			
	await get_tree().create_timer(0.3).timeout
	
	if _outline_material:
		_outline_material.set_shader_parameter("outline_color", Color.WHITE)
		
	# Reset state
	if is_waiting:
		_is_resolving = false
	_sync_collision_layer()
	_update_outline()
	_update_attention_badge()
	


## Called by CustomerSpawner after the player chooses "Refuse service".
## Plays a brief leaving animation then notifies the EventBus.
func dismiss() -> void:
	await _leave_store(EventBus.customer_dismissed)

func _update_attention_badge() -> void:
	if not is_instance_valid(_attention_badge):
		return
	if not is_waiting or _is_resolving or is_lingering_visitor or is_guest_customer or Dialogic.current_timeline != null:
		_attention_badge.set_mode(AttentionBadge3D.Mode.HIDDEN)
	elif is_returning_for_smalltalk:
		_attention_badge.set_mode(AttentionBadge3D.Mode.SMALLTALK)
	elif not has_been_greeted:
		_attention_badge.set_mode(AttentionBadge3D.Mode.UNGREETED)
	else:
		_attention_badge.set_mode(AttentionBadge3D.Mode.HIDDEN)

## Returns true when this customer is ready to receive a dragged item handover.
## Intentionally never checks specific desired items so riddles stay unspoiled.
func can_receive_item_handover() -> bool:
	if not is_waiting or _is_resolving or is_lingering_visitor or is_returning_for_smalltalk:
		return false
	if dialogue_phase == TransactionSession.Phase.SATISFIED:
		return false
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	var is_guided: bool = (transaction_context and transaction_context.is_guided_tutorial) or (gm and gm.tutorial and gm.tutorial.is_guided_timeline_active())
	if is_guided:
		return gm != null and gm.tutorial != null and gm.tutorial.can_accept_guided_item()
	if not has_been_greeted or transaction_context == null:
		return false
	if transaction_context.transaction_type == TransactionContext.Type.VISIT or transaction_context.is_visit_story:
		return false
	return true

func set_drag_hover(active: bool) -> void:
	if _is_drag_hovered == active:
		return
	_is_drag_hovered = active
	_update_outline()
	_update_drag_hover_scale()

## Show or hide the hover outline on the customer sprite.
## Only shows when the customer is actively waiting and can be interacted with.
func on_hover(hovered: bool) -> void:
	is_hovered = hovered
	if not hovered:
		_is_drag_hovered = false
	_update_outline()
	_update_drag_hover_scale()
	var emitted_customer: Customer = self if (hovered and is_waiting and not _is_resolving) else null
	EventBus.customer_hover_changed.emit(emitted_customer, _is_drag_hovered)

func _update_outline() -> void:
	if is_hovered and is_waiting and not _is_resolving:
		if _outline_material == null and body_sprite and body_sprite.texture:
			_outline_material = ShaderMaterial.new()
			_outline_material.shader = preload("res://Assets/Shaders/item_outline_spatial.gdshader")
			_outline_material.set_shader_parameter("albedo_texture", body_sprite.texture)
			# Match the Sprite3D's billboard = 2 (Fixed Y) so the outline never
			# tilts when the player looks up or down.
			_outline_material.set_shader_parameter("fixed_y_billboard", true)
		if _outline_material:
			if _is_drag_hovered:
				if can_receive_item_handover():
					_outline_material.set_shader_parameter("outline_color", Color("#8CF5A2"))
					_outline_material.set_shader_parameter("outline_width", 20.0)
				else:
					_outline_material.set_shader_parameter("outline_color", Color(0.88, 0.72, 0.42, 0.85))
					_outline_material.set_shader_parameter("outline_width", 14.0)
			else:
				_outline_material.set_shader_parameter("outline_color", Color.WHITE)
				_outline_material.set_shader_parameter("outline_width", 16.0)
		if body_sprite:
			body_sprite.material_overlay = _outline_material
	else:
		_clear_outline()

func _update_drag_hover_scale() -> void:
	if not body_sprite or (_visual_tween and _visual_tween.is_valid() and _visual_tween.is_running()):
		return
	if _hover_scale_tween and _hover_scale_tween.is_valid():
		_hover_scale_tween.kill()
	var base := _get_base_sprite_scale()
	var target := base * 1.035 if (is_hovered and _is_drag_hovered and can_receive_item_handover()) else base
	_hover_scale_tween = create_tween()
	_hover_scale_tween.tween_property(body_sprite, "scale", target, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _clear_outline() -> void:
	if body_sprite:
		body_sprite.material_overlay = null


## One-shot animation played when the customer starts speaking.
func play_speak_animation() -> void:
	if not body_sprite: return
	
	var tw = _start_visual_tween()
	var base_scale = _get_base_sprite_scale()
	
	# Two quick, subtle vertical pulses (0.6s total)
	# Pulse 1
	tw.tween_property(body_sprite, "scale", Vector3(base_scale.x * 1.04, base_scale.y * 0.96, base_scale.z), 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(body_sprite, "scale", base_scale, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Pulse 2
	tw.tween_property(body_sprite, "scale", Vector3(base_scale.x * 1.04, base_scale.y * 0.96, base_scale.z), 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(body_sprite, "scale", base_scale, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
