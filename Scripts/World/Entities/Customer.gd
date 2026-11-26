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
var _pending_exit_signal: Signal
var _has_pending_exit_signal: bool = false
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
	_motion.exit_finished.connect(_on_motion_exit_finished)
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
		if not EventBus.reputation_changed.is_connected(_on_reputation_changed):
			EventBus.reputation_changed.connect(_on_reputation_changed)

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


func _on_reputation_changed(char_path: String, _new_rep: int, delta: int, new_rank: int, ranked_up: bool) -> void:
	if is_ambient_cameo or not is_instance_valid(body_sprite) or customer_data == null:
		return
	if char_path != customer_data.resource_path or delta == 0:
		return
	_spawn_floating_rep_popup(delta, new_rank, ranked_up)


const TEX_REP_ICON: Texture2D = preload("res://Assets/ui/rep.png")


func _spawn_floating_rep_popup(delta: int, new_rank: int, ranked_up: bool) -> void:
	var col: Color
	if ranked_up:
		col = Color(1.0, 0.88, 0.36, 1.0)
	elif delta > 0:
		col = Color(0.72, 0.98, 0.58, 1.0)
	else:
		col = Color(1.0, 0.44, 0.40, 1.0)

	var base_y := 1.65
	if customer_data and customer_data.sprite_texture and body_sprite:
		base_y = (customer_data.sprite_texture.get_height() * body_sprite.pixel_size * customer_data.sprite_scale) + 0.10

	var start_pos := global_position + Vector3(randf_range(-0.14, 0.14), base_y, 0.05)
	var holder := Node3D.new()
	holder.top_level = true
	holder.scale = Vector3(0.65, 0.65, 0.65)
	var parent_node: Node = get_tree().current_scene if (get_tree() and get_tree().current_scene) else self
	parent_node.add_child(holder)
	holder.global_position = start_pos

	var icon := Sprite3D.new()
	icon.texture = TEX_REP_ICON
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.shaded = false
	icon.no_depth_test = true
	icon.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	icon.render_priority = 15
	icon.pixel_size = 0.00105 if ranked_up else 0.00095
	icon.offset = Vector2(138.0, 0.0)
	icon.modulate = col
	holder.add_child(icon)

	var lbl := Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.render_priority = 15
	lbl.outline_render_priority = 14
	lbl.font = UIStyle.FONT_INDER
	lbl.font_size = 42 if ranked_up else 36
	lbl.outline_size = 10
	lbl.outline_modulate = Color(0.05, 0.04, 0.03, 0.95)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.offset = Vector2(-2.0, 0.0)
	lbl.modulate = col
	if ranked_up:
		lbl.text = "+%d  ★ RANK %d!" % [delta, new_rank]
	elif delta > 0:
		lbl.text = "+%d" % delta
	else:
		lbl.text = "%d" % delta
	holder.add_child(lbl)

	var tw := holder.create_tween()
	tw.tween_property(holder, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(holder, "global_position:y", start_pos.y + 0.65, 1.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(icon, "modulate:a", 0.0, 0.70).set_delay(0.35)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.70).set_delay(0.35)
	tw.parallel().tween_property(lbl, "outline_modulate:a", 0.0, 0.70).set_delay(0.35)
	tw.tween_callback(holder.queue_free)

	# Tactile sprite bounce on positive Rep, subtle red pulse on negative Rep
	if delta > 0 and is_instance_valid(body_sprite):
		var orig_scale := body_sprite.scale
		var btw := create_tween()
		btw.tween_property(body_sprite, "scale", Vector3(orig_scale.x * 1.07, orig_scale.y * 0.94, orig_scale.z), 0.08)
		btw.tween_property(body_sprite, "scale", Vector3(orig_scale.x * 0.96, orig_scale.y * 1.06, orig_scale.z), 0.11)
		btw.tween_property(body_sprite, "scale", orig_scale, 0.10)
	elif delta < 0:
		pulse_color(Color(1.0, 0.45, 0.40, 1.0), 0.25)


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
	var target_r: float = clampf(color.r * 1.2, 0.0, 1.0)
	var target_g: float = clampf(color.g * 1.2, 0.0, 1.0)
	var target_b: float = clampf(color.b * 1.2, 0.0, 1.0)

	# Tween RGB channels only so custom motion opacity (modulate.a) is always preserved
	tween.tween_property(body_sprite, "modulate:r", target_r, duration * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(body_sprite, "modulate:g", target_g, duration * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(body_sprite, "modulate:b", target_b, duration * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
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

	# Pop Terraria-style thought bubbles frequently while hanging out in the tambayan
	await get_tree().create_timer(randf_range(1.2, 2.0)).timeout
	if not is_instance_valid(self) or not is_inside_tree() or my_session != _linger_session_id or not is_lingering_visitor:
		return
	_pop_linger_thought(my_session)

	await get_tree().create_timer(randf_range(2.6, 3.6)).timeout
	if not is_instance_valid(self) or not is_inside_tree() or my_session != _linger_session_id or not is_lingering_visitor:
		return
	if randf() < 0.80:
		_pop_linger_thought(my_session)
		await get_tree().create_timer(randf_range(2.2, 3.2)).timeout
		if not is_instance_valid(self) or not is_inside_tree() or my_session != _linger_session_id or not is_lingering_visitor:
			return

	for i in range(1, hangout_points.size()):
		if randf() > 0.85 and i >= 2:
			break
		target_position = hangout_points[i]
		if is_instance_valid(_motion):
			_motion.set_lingering_target(hangout_points[i])
		await get_tree().create_timer(randf_range(1.2, 2.0)).timeout
		if not is_instance_valid(self) or not is_inside_tree() or my_session != _linger_session_id or not is_lingering_visitor:
			return
		if randf() < 0.95:
			_pop_linger_thought(my_session)
		await get_tree().create_timer(randf_range(2.4, 3.4)).timeout
		if not is_instance_valid(self) or not is_inside_tree() or my_session != _linger_session_id or not is_lingering_visitor:
			return
		if randf() < 0.65:
			_pop_linger_thought(my_session)
			await get_tree().create_timer(randf_range(2.0, 3.0)).timeout
			if not is_instance_valid(self) or not is_inside_tree() or my_session != _linger_session_id or not is_lingering_visitor:
				return

	if is_instance_valid(_attention_badge) and _attention_badge.is_showing_thought():
		_attention_badge.set_mode(AttentionBadge3D.Mode.HIDDEN)
	lingering_ready_to_return.emit(self)

func _pop_linger_thought(my_session: int) -> void:
	if not is_instance_valid(_attention_badge) or not is_lingering_visitor or Dialogic.current_timeline != null:
		return
	var char_id := customer_data.get_clean_id() if customer_data else ""
	var pool: Array = []
	match char_id:
		"kuyakap":
			pool = [["cloud-fog", Color(0.32, 0.36, 0.44)], ["flame", Color(0.76, 0.34, 0.14)], ["coffee", Color(0.46, 0.26, 0.12)], ["moon-star", Color(0.44, 0.36, 0.62)]]
		"buboy":
			pool = [["sparkles", Color(0.84, 0.56, 0.08)], ["gift", Color(0.84, 0.24, 0.30)], ["party-popper", Color(0.78, 0.36, 0.12)], ["zap", Color(0.18, 0.52, 0.72)]]
		"manangana":
			pool = [["moon", Color(0.45, 0.32, 0.65)], ["shopping-basket", Color(0.74, 0.46, 0.12)], ["heart-handshake", Color(0.82, 0.25, 0.34)], ["sparkles", Color(0.24, 0.48, 0.46)]]
		"danilo":
			pool = [["coffee", Color(0.46, 0.26, 0.12)], ["radio", Color(0.28, 0.46, 0.58)], ["mic-vocal", Color(0.58, 0.30, 0.22)], ["clock", Color(0.36, 0.40, 0.60)]]
		"rosalyn":
			pool = [["moon-star", Color(0.34, 0.42, 0.68)], ["ghost", Color(0.42, 0.48, 0.66)], ["cloud-fog", Color(0.38, 0.40, 0.50)], ["sparkles", Color(0.72, 0.36, 0.48)]]
		"rodel":
			pool = [["cloud-rain", Color(0.14, 0.50, 0.68)], ["wind", Color(0.20, 0.56, 0.60)], ["snowflake", Color(0.18, 0.48, 0.68)], ["heart-pulse", Color(0.78, 0.30, 0.38)]]
		"sarimanok":
			pool = [["sun", Color(0.86, 0.48, 0.08)], ["sparkles", Color(0.84, 0.58, 0.10)], ["trophy", Color(0.76, 0.46, 0.12)], ["flame", Color(0.76, 0.28, 0.22)]]
		"tk":
			pool = [["wind", Color(0.34, 0.48, 0.58)], ["zap", Color(0.80, 0.38, 0.14)], ["route", Color(0.52, 0.36, 0.22)], ["sparkles", Color(0.74, 0.52, 0.12)]]
		"lolopilo":
			pool = [["coffee", Color(0.46, 0.26, 0.12)], ["gift", Color(0.76, 0.44, 0.14)], ["sun-medium", Color(0.82, 0.54, 0.10)], ["heart-handshake", Color(0.26, 0.52, 0.34)]]
		"reynamayari":
			pool = [["moon-star", Color(0.45, 0.34, 0.68)], ["moon", Color(0.34, 0.42, 0.68)], ["sparkles", Color(0.82, 0.56, 0.14)], ["award", Color(0.74, 0.50, 0.14)]]
		_:
			pool = [["coffee", Color(0.46, 0.26, 0.12)], ["sparkles", Color(0.80, 0.54, 0.10)], ["heart-handshake", Color(0.82, 0.26, 0.32)], ["shopping-basket", Color(0.28, 0.46, 0.58)]]
	var pick: Array = pool.pick_random()
	var icon_path := "res://Assets/ui/icons/%s.png" % str(pick[0])
	_attention_badge.show_thought_icon(icon_path, pick[1] as Color)
	_hide_thought_after(my_session, randf_range(2.4, 3.3))

func _hide_thought_after(my_session: int, duration: float) -> void:
	await get_tree().create_timer(duration).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if my_session == _linger_session_id and is_lingering_visitor and is_instance_valid(_attention_badge) and _attention_badge.is_showing_thought():
		_attention_badge.set_mode(AttentionBadge3D.Mode.HIDDEN)

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

func return_to_counter_for_purchase(new_slot: int, slot_target: Vector3, new_tx: TransactionContext) -> void:
	if _is_resolving or new_tx == null:
		return
	_linger_session_id += 1
	is_lingering_visitor = false
	is_returning_for_smalltalk = false
	is_lingering_departure = false
	set_meta("returned_from_lingering", true)
	set_meta("_xp_awarded", false)
	transaction_context = new_tx
	has_been_greeted = false
	dialogue_phase = TransactionSession.Phase.NONE
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
	_leave_store(lingering_departed)

func satisfy() -> void:
	StoryManager.award_customer_completion_xp(self)
	_leave_store(EventBus.customer_satisfied)


func _leave_store(completion_signal: Signal) -> void:
	if _is_resolving:
		return
	# Immediately mark as no longer waiting so nothing else can interact with
	# or dismiss this customer while the exit animation plays.
	_linger_session_id += 1
	is_waiting = false
	is_lingering_visitor = false
	_is_resolving = true
	_pending_exit_signal = completion_signal
	_has_pending_exit_signal = true
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
	else:
		get_tree().create_timer(2.0).timeout.connect(_on_motion_exit_finished, CONNECT_ONE_SHOT)


func _on_motion_exit_finished() -> void:
	if not _has_pending_exit_signal:
		return
	_has_pending_exit_signal = false

	if transaction_context and transaction_context.blocks_phone_call:
		MarioManager.is_mario_physically_present = false

	# Emit completion signal only once FULLY resolved (gone from the scene)
	_pending_exit_signal.emit(self)
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
	_leave_store(EventBus.customer_dismissed)

func _update_attention_badge() -> void:
	if not is_instance_valid(_attention_badge):
		return
	if is_lingering_visitor and not _is_resolving and Dialogic.current_timeline == null:
		# Preserve active Terraria-style thought bubbles while lingering in the tambayan
		if _attention_badge.is_showing_thought():
			return
		_attention_badge.set_mode(AttentionBadge3D.Mode.HIDDEN)
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
