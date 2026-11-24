class_name CustomerMotionController
extends Node

## Modular movement, procedural locomotion, and keyframed sequence controller for Customer entities.
## Replaces hardcoded walk/bob/fade logic in Customer.gd so characters and story chapters
## can compose arbitrary enter, idle, lingering, exit, and ambient cameo animations via Resources.

const MotionStepScript = preload("res://Scripts/Data/CustomerMotionStep.gd")
const MotionProfileScript = preload("res://Scripts/Data/CustomerMotionProfile.gd")

signal enter_finished
signal exit_finished
signal cameo_finished
signal reposition_finished

enum State {
	DELAYED,
	ENTERING,
	IDLE,
	REPOSITIONING,
	LINGERING,
	EXITING,
	AMBIENT_CAMEO,
}

var state: State = State.IDLE
var profile: MotionProfileScript = null
var current_opacity: float = 1.0

var _owner_node: Node3D = null
var _body_sprite: Sprite3D = null
var _base_sprite_scale: Vector3 = Vector3.ONE

# Storefront anchor frame
var _spawn_pos: Vector3 = Vector3.ZERO
var _counter_slot_pos: Vector3 = Vector3.ZERO
var _exit_pos: Vector3 = Vector3.ZERO
var _approach_dir: Vector3 = Vector3(1, 0, 0) # Street -> Counter
var _side_offset: Vector3 = Vector3(0, 0, 1)  # +Left / -Right from player POV

# Active step-sequence playback
var _steps: Array = []
var _step_idx: int = -1
var _step_substate: int = 0 # 0 = pause_before, 1 = moving, 2 = pause_after
var _step_timer: float = 0.0
var _step_duration: float = 0.0
var _step_pause_after: float = 0.0
var _step_start_pos: Vector3 = Vector3.ZERO
var _step_end_pos: Vector3 = Vector3.ZERO
var _step_start_opacity: float = 1.0
var _step_end_opacity: float = 1.0
var _step_start_scale_mult: Vector3 = Vector3.ONE
var _step_end_scale_mult: Vector3 = Vector3.ONE
var _active_scale_mult: Vector3 = Vector3.ONE

# Direct movement target (for default enter, default exit, repositioning, lingering)
var _direct_target: Vector3 = Vector3.ZERO
var _using_exit_stepback: bool = false
var _exit_fade_elapsed: float = 0.0
var _exit_fade_started: bool = false
var _default_fade_in_timer: float = 0.0
var _default_fade_in_active: bool = false
var _default_fade_in_from: float = 0.0

# Procedural locomotion & idle bob timers
var _walk_timer: float = 0.0
var _idle_timer: float = 0.0
var _idle_opacity_timer: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _fallback_speed: float = 2.0


func configure(
	owner_node: Node3D,
	body_sprite: Sprite3D,
	base_sprite_scale: Vector3,
	motion_profile: MotionProfileScript,
	spawn_pos: Vector3,
	counter_slot_pos: Vector3,
	exit_pos: Vector3,
	fallback_speed: float = 2.0
) -> void:
	_owner_node = owner_node
	_body_sprite = body_sprite
	_base_sprite_scale = base_sprite_scale
	profile = motion_profile
	_spawn_pos = spawn_pos
	_counter_slot_pos = counter_slot_pos
	_exit_pos = exit_pos if exit_pos != Vector3.ZERO else spawn_pos
	_fallback_speed = fallback_speed

	var flat_approach := Vector3(_counter_slot_pos.x - _spawn_pos.x, 0.0, _counter_slot_pos.z - _spawn_pos.z)
	if flat_approach.length_squared() > 0.001:
		_approach_dir = flat_approach.normalized()
	else:
		_approach_dir = Vector3(1, 0, 0)
	_side_offset = Vector3(-_approach_dir.z, 0.0, _approach_dir.x)

	_walk_timer = 0.0
	_idle_timer = randf() * TAU
	_active_scale_mult = Vector3.ONE

	if profile and profile.override_start_anchor:
		_owner_node.global_position = resolve_anchor(profile.start_anchor, profile.start_offset)
	_last_pos = _owner_node.global_position

	var start_a := profile.start_opacity if profile else 0.0
	set_opacity(start_a)


func update_base_sprite_scale(new_scale: Vector3) -> void:
	_base_sprite_scale = new_scale


func set_opacity(alpha: float) -> void:
	current_opacity = clampf(alpha, 0.0, 1.0)
	if is_instance_valid(_body_sprite):
		_body_sprite.modulate.a = current_opacity


func get_idle_opacity() -> float:
	return profile.idle_opacity if profile else 1.0


func should_play_landing_thud() -> bool:
	return profile.play_landing_thud if profile else true


func resolve_anchor(anchor: int, local_offset: Vector3 = Vector3.ZERO) -> Vector3:
	var base := _counter_slot_pos
	match anchor:
		MotionStepScript.Anchor.SPAWN:
			base = _spawn_pos
		MotionStepScript.Anchor.APPROACH_MIDPOINT:
			base = _spawn_pos.lerp(_counter_slot_pos, 0.52)
		MotionStepScript.Anchor.COUNTER_SLOT:
			base = _counter_slot_pos
		MotionStepScript.Anchor.BEHIND_COUNTER:
			base = _counter_slot_pos + _approach_dir * 2.6
		MotionStepScript.Anchor.EXIT:
			base = _exit_pos
		MotionStepScript.Anchor.STREET_LEFT:
			base = _counter_slot_pos - _approach_dir * 2.8 + _side_offset * 15.0
		MotionStepScript.Anchor.STREET_RIGHT:
			base = _counter_slot_pos - _approach_dir * 2.8 - _side_offset * 15.0
		MotionStepScript.Anchor.CURRENT:
			base = _owner_node.global_position if is_instance_valid(_owner_node) else _counter_slot_pos

	return base + (_side_offset * local_offset.x) + (Vector3.UP * local_offset.y) + (_approach_dir * local_offset.z)


func start_delayed() -> void:
	state = State.DELAYED
	set_opacity(0.0)


func start_enter() -> void:
	state = State.ENTERING
	_using_exit_stepback = false
	_exit_fade_started = false
	if profile and not profile.enter_steps.is_empty():
		_begin_step_sequence(profile.enter_steps)
	else:
		_steps.clear()
		_direct_target = _counter_slot_pos
		_default_fade_in_active = true
		_default_fade_in_timer = 0.0
		_default_fade_in_from = current_opacity


func start_reposition(new_counter_slot_pos: Vector3) -> void:
	_counter_slot_pos = new_counter_slot_pos
	if state == State.ENTERING and _steps.is_empty():
		_direct_target = new_counter_slot_pos
		return
	if state == State.IDLE or state == State.REPOSITIONING:
		state = State.REPOSITIONING
		_steps.clear()
		_direct_target = new_counter_slot_pos


func start_lingering(first_target: Vector3) -> void:
	state = State.LINGERING
	_steps.clear()
	_default_fade_in_active = false
	_direct_target = first_target


func set_lingering_target(next_target: Vector3) -> void:
	if state == State.LINGERING:
		_direct_target = next_target


func start_return_from_lingering(new_counter_slot_pos: Vector3) -> void:
	_counter_slot_pos = new_counter_slot_pos
	state = State.ENTERING
	_steps.clear()
	_direct_target = new_counter_slot_pos
	_default_fade_in_active = false


func start_exit() -> void:
	state = State.EXITING
	_default_fade_in_active = false
	if profile and not profile.exit_steps.is_empty():
		_using_exit_stepback = false
		_exit_fade_started = false
		_begin_step_sequence(profile.exit_steps)
	else:
		_steps.clear()
		_exit_fade_started = true
		_exit_fade_elapsed = 0.0
		var to_exit := Vector3(_exit_pos.x - _owner_node.global_position.x, 0.0, _exit_pos.z - _owner_node.global_position.z)
		var exit_dir := to_exit.normalized() if to_exit.length_squared() > 0.001 else Vector3.ZERO
		if profile and profile.bypass_default_exit_stepback:
			_using_exit_stepback = false
			_direct_target = _exit_pos
		else:
			_using_exit_stepback = true
			_direct_target = _owner_node.global_position - (_approach_dir * 1.35) + (exit_dir * 0.75)


func start_ambient_cameo() -> void:
	state = State.AMBIENT_CAMEO
	_default_fade_in_active = false
	var combined: Array = []
	if profile:
		for s in profile.enter_steps:
			if s != null:
				combined.append(s)
		for s in profile.exit_steps:
			if s != null:
				combined.append(s)
	if combined.is_empty():
		cameo_finished.emit()
		return
	_begin_step_sequence(combined)


func _begin_step_sequence(step_list: Array) -> void:
	_steps = []
	for s in step_list:
		if s != null:
			_steps.append(s)
	_step_idx = -1
	_advance_to_next_step()


func _advance_to_next_step() -> void:
	_step_idx += 1
	if _step_idx >= _steps.size():
		_on_sequence_completed()
		return

	var step: MotionStepScript = _steps[_step_idx]
	_step_start_pos = _owner_node.global_position
	_step_end_pos = resolve_anchor(step.anchor, step.local_offset)
	_step_start_opacity = current_opacity
	_step_end_opacity = step.target_opacity if step.target_opacity >= 0.0 else current_opacity
	_step_start_scale_mult = _active_scale_mult
	_step_end_scale_mult = step.scale_multiplier if step.scale_multiplier != Vector3.ZERO else Vector3.ONE

	if step.duration > 0.0:
		_step_duration = step.duration
	else:
		var spd := _get_base_speed() * maxf(step.speed_multiplier, 0.05)
		var dist := _step_start_pos.distance_to(_step_end_pos)
		_step_duration = dist / spd if dist > 0.001 else 0.0

	_step_pause_after = maxf(step.pause_after, 0.0)
	if step.pause_random_extra > 0.0:
		_step_pause_after += randf_range(0.0, step.pause_random_extra)

	_step_timer = 0.0
	if step.pause_before > 0.0:
		_step_substate = 0
	else:
		_step_substate = 1


func _on_sequence_completed() -> void:
	_steps.clear()
	_step_idx = -1
	match state:
		State.ENTERING:
			state = State.IDLE
			if profile:
				set_opacity(profile.idle_opacity)
			enter_finished.emit()
		State.EXITING:
			set_opacity(0.0)
			exit_finished.emit()
		State.AMBIENT_CAMEO:
			set_opacity(0.0)
			cameo_finished.emit()


func _get_base_speed() -> float:
	return profile.base_speed if profile and profile.base_speed > 0.0 else _fallback_speed


func _process(delta: float) -> void:
	if not is_instance_valid(_owner_node) or not is_instance_valid(_body_sprite):
		return

	if state == State.DELAYED:
		return

	var use_bob := true
	var is_moving := false

	if not _steps.is_empty() and _step_idx >= 0 and _step_idx < _steps.size():
		var step: MotionStepScript = _steps[_step_idx]
		use_bob = step.use_locomotion_bob
		_step_timer += delta

		if _step_substate == 0:
			# Pause before step
			if _step_timer >= step.pause_before:
				_step_timer = 0.0
				_step_substate = 1
		elif _step_substate == 1:
			# Moving through step
			is_moving = _step_duration > 0.0
			var raw_t := 1.0 if _step_duration <= 0.0001 else clampf(_step_timer / _step_duration, 0.0, 1.0)
			var eased_t := _sample_ease(raw_t, step.transition, step.ease_type)
			var pos := _step_start_pos.lerp(_step_end_pos, eased_t)
			if absf(step.height_arc) > 0.001:
				pos.y += sin(raw_t * PI) * step.height_arc
			if absf(step.side_arc) > 0.001:
				pos += _side_offset * (sin(raw_t * PI) * step.side_arc)
			_owner_node.global_position = pos

			if step.target_opacity >= 0.0:
				var frac := clampf(step.opacity_fade_fraction, 0.05, 1.0)
				var ot: float
				if step.opacity_fade_at_end:
					var start_at := 1.0 - frac
					ot = clampf((raw_t - start_at) / frac, 0.0, 1.0)
				else:
					ot = clampf(raw_t / frac, 0.0, 1.0)
				set_opacity(lerpf(_step_start_opacity, _step_end_opacity, ot))

			_active_scale_mult = _step_start_scale_mult.lerp(_step_end_scale_mult, eased_t)
			if _active_scale_mult != Vector3.ONE or _step_start_scale_mult != Vector3.ONE:
				_body_sprite.scale = _base_sprite_scale * _active_scale_mult

			if raw_t >= 1.0:
				_owner_node.global_position = _step_end_pos
				if step.target_opacity >= 0.0:
					set_opacity(_step_end_opacity)
				_step_timer = 0.0
				if _step_pause_after > 0.0:
					_step_substate = 2
				else:
					_advance_to_next_step()
		else:
			# Pause after step
			if _step_timer >= _step_pause_after:
				_advance_to_next_step()
	else:
		# Direct movement states (default enter, default exit, repositioning, lingering, idle)
		match state:
			State.ENTERING:
				if _default_fade_in_active:
					_default_fade_in_timer += delta
					var ft := clampf(_default_fade_in_timer / 0.22, 0.0, 1.0)
					set_opacity(lerpf(_default_fade_in_from, get_idle_opacity(), ft))
					if ft >= 1.0:
						_default_fade_in_active = false
				var speed := _get_base_speed()
				_owner_node.global_position = _owner_node.global_position.move_toward(_direct_target, speed * delta)
				is_moving = _owner_node.global_position.distance_to(_last_pos) > 0.0005
				if _owner_node.global_position.distance_to(_direct_target) < 0.1:
					_owner_node.global_position = _direct_target
					set_opacity(get_idle_opacity())
					_default_fade_in_active = false
					state = State.IDLE
					enter_finished.emit()

			State.REPOSITIONING:
				var speed := _get_base_speed() * 1.15
				_owner_node.global_position = _owner_node.global_position.move_toward(_direct_target, speed * delta)
				is_moving = _owner_node.global_position.distance_to(_last_pos) > 0.0005
				if _owner_node.global_position.distance_to(_direct_target) < 0.05:
					_owner_node.global_position = _direct_target
					state = State.IDLE
					reposition_finished.emit()

			State.LINGERING:
				var speed := _get_base_speed() * 0.65
				_owner_node.global_position = _owner_node.global_position.move_toward(_direct_target, speed * delta)
				is_moving = _owner_node.global_position.distance_to(_last_pos) > 0.0005

			State.EXITING:
				var speed := _get_base_speed() * 1.55
				_owner_node.global_position = _owner_node.global_position.move_toward(_direct_target, speed * delta)
				is_moving = _owner_node.global_position.distance_to(_last_pos) > 0.0005
				if _using_exit_stepback and _owner_node.global_position.distance_to(_direct_target) < 0.25:
					_using_exit_stepback = false
					_direct_target = _exit_pos
				if _exit_fade_started:
					_exit_fade_elapsed += delta
					if _exit_fade_elapsed >= 2.0:
						var fade_t := clampf((_exit_fade_elapsed - 2.0) / 0.5, 0.0, 1.0)
						set_opacity(lerpf(get_idle_opacity(), 0.0, fade_t))
						if fade_t >= 1.0:
							_exit_fade_started = false
							exit_finished.emit()

			State.IDLE:
				is_moving = false
				if profile and profile.idle_opacity_pulse_speed > 0.0 and profile.idle_opacity_pulse_max > profile.idle_opacity_pulse_min:
					_idle_opacity_timer += delta
					var pulse_t := 0.5 + 0.5 * cos(_idle_opacity_timer * profile.idle_opacity_pulse_speed)
					set_opacity(lerpf(profile.idle_opacity_pulse_min, profile.idle_opacity_pulse_max, pulse_t))

	_last_pos = _owner_node.global_position
	_apply_locomotion_visuals(delta, is_moving, use_bob)


func _apply_locomotion_visuals(delta: float, is_moving: bool, use_bob: bool) -> void:
	var style: int = profile.locomotion_style if profile else MotionProfileScript.LocomotionStyle.WALK_BOUNCE
	var base_y: float = profile.idle_height_offset if profile else 0.0
	var freq: float = profile.bob_frequency if profile else 10.0
	var amp: float = profile.bob_amplitude if profile else 0.08
	var sway: float = profile.sway_amount if profile else 0.05

	if is_moving and use_bob and style != MotionProfileScript.LocomotionStyle.STILL:
		_walk_timer += delta
		match style:
			MotionProfileScript.LocomotionStyle.WALK_BOUNCE:
				_body_sprite.position.y = base_y + absf(sin(_walk_timer * freq)) * amp
				_body_sprite.rotation.z = sin(_walk_timer * freq * 0.5) * sway
			MotionProfileScript.LocomotionStyle.FLOAT_GLIDE:
				_body_sprite.position.y = base_y + sin(_walk_timer * freq * 0.35) * amp
				_body_sprite.rotation.z = sin(_walk_timer * freq * 0.25) * sway
			MotionProfileScript.LocomotionStyle.FLAP_HOVER:
				var beat := pow(absf(sin(_walk_timer * freq * 0.7)), 0.65)
				_body_sprite.position.y = base_y + beat * amp * 1.35
				_body_sprite.rotation.z = sin(_walk_timer * freq * 0.7) * sway * 1.25
			MotionProfileScript.LocomotionStyle.HEAVY_STOMP:
				var stomp := pow(absf(sin(_walk_timer * freq * 0.55)), 1.6)
				_body_sprite.position.y = base_y + stomp * amp * 0.9
				_body_sprite.rotation.z = sin(_walk_timer * freq * 0.275) * sway * 1.1
			MotionProfileScript.LocomotionStyle.SKIP_HOP:
				var hop := absf(sin(_walk_timer * freq * 0.85)) + 0.35 * absf(sin(_walk_timer * freq * 1.7))
				_body_sprite.position.y = base_y + hop * amp
				_body_sprite.rotation.z = sin(_walk_timer * freq * 0.85) * sway * 1.2
	else:
		var idle_amp: float = profile.idle_bob_amplitude if profile else 0.0
		var idle_spd: float = profile.idle_bob_speed if profile else 2.4
		var idle_sway: float = profile.idle_sway_amount if profile else 0.0
		if idle_amp > 0.0005 or idle_sway > 0.0005:
			_idle_timer += delta
			var target_y := base_y + sin(_idle_timer * idle_spd) * idle_amp
			var target_rot := sin(_idle_timer * idle_spd * 0.7) * idle_sway
			_body_sprite.position.y = lerpf(_body_sprite.position.y, target_y, clampf(delta * 6.0, 0.0, 1.0))
			_body_sprite.rotation.z = lerpf(_body_sprite.rotation.z, target_rot, clampf(delta * 6.0, 0.0, 1.0))
		else:
			_body_sprite.position.y = move_toward(_body_sprite.position.y, base_y, delta * 1.5)
			_body_sprite.rotation.z = move_toward(_body_sprite.rotation.z, 0.0, delta * 1.5)


func _sample_ease(t: float, trans: Tween.TransitionType, ease_t: Tween.EaseType) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0
	return float(Tween.interpolate_value(0.0, 1.0, t, 1.0, trans, ease_t))
