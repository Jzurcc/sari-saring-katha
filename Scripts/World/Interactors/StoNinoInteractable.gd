extends WorldInteractor

## Interactive Sto. Niño altar statue.
## Tapping Sto. Niño grants 1–2 random Favors (that the player doesn't currently have)
## for a timed duration (5h -> 8h) or for the entire rest of the day at Level 3.

var _visual_base_scale: Vector3 = Vector3.ONE
var _pulse_time: float = 0.0
var _sprite: Sprite3D = null

func _ready() -> void:
	super._ready()
	add_to_group("sto_nino_altar")
	outline_shader = preload("res://Assets/Shaders/item_outline_spatial.gdshader")
	default_outline_color = Color(1.0, 0.82, 0.36, 1.0)
	outline_width = 32.0

	var visuals := get_visual_nodes()
	if not visuals.is_empty():
		_visual_base_scale = visuals[0].scale
		if visuals[0] is Sprite3D:
			_sprite = visuals[0] as Sprite3D

	EventBus.sto_nino_blessing_changed.connect(_refresh_visual_state)
	EventBus.sto_nino_upgraded.connect(_on_sto_nino_upgraded)
	EventBus.day_started.connect(func(_d): _refresh_visual_state())
	_refresh_visual_state()

func _process(delta: float) -> void:
	if not visible or StoryManager.sto_nino_upgrade_level < 1 or not is_instance_valid(_sprite):
		return
	# Gentle warm golden pulse when a blessing is ready to tap
	if not StoryManager.has_active_sto_nino_blessing() and not StoryManager.is_past_closing_time():
		_pulse_time += delta * 2.4
		var glow := 0.5 + 0.5 * sin(_pulse_time)
		_sprite.modulate = Color(1.0, 0.96 + glow * 0.04, 0.88 + glow * 0.12, 1.0)
	else:
		_sprite.modulate = Color.WHITE

func _refresh_visual_state() -> void:
	var unlocked := StoryManager.sto_nino_upgrade_level >= 1
	visible = unlocked
	collision_layer = 1 if unlocked else 0
	if is_instance_valid(_sprite) and StoryManager.has_active_sto_nino_blessing():
		_sprite.modulate = Color.WHITE

func _on_sto_nino_upgraded(_new_level: int) -> void:
	_refresh_visual_state()
	_play_blessing_bounce()
	var burst_pos := _sprite.global_position + Vector3(0, 0.22, 0) if is_instance_valid(_sprite) else global_position + Vector3(0, 0.22, 0)
	VisualEffectManager.spawn_heart_burst(burst_pos)

func on_interact() -> void:
	if StoryManager.sto_nino_upgrade_level < 1:
		return
	if Dialogic.current_timeline != null:
		return
	if StoryManager.is_past_closing_time():
		return

	_play_blessing_bounce()

	if StoryManager.has_active_sto_nino_blessing():
		EventBus.request_sfx.emit("interact")
		if StoryManager.sto_nino_blessing_all_day:
			EventBus.show_notification.emit("Sto. Niño's Blessing Active", "Your Favors remain active for the rest of the day.", "interact")
		else:
			var rem := StoryManager.get_sto_nino_blessing_remaining_hours()
			EventBus.show_notification.emit("Sto. Niño's Blessing Active", "Active for ~%.1fh more. Press [C] to inspect." % rem, "interact")
		return

	var granted := StoryManager.activate_sto_nino_blessing()
	if granted.is_empty():
		return

	EventBus.request_sfx.emit("purchase")
	var burst_pos := _sprite.global_position + Vector3(0, 0.22, 0) if is_instance_valid(_sprite) else global_position + Vector3(0, 0.22, 0)
	VisualEffectManager.spawn_heart_burst(burst_pos)

	var names: Array[String] = []
	for cid in granted:
		var c := MayariCardRegistry.get_card(cid)
		if not c.is_empty():
			names.append(str(c.get("title", cid)))
	var spec := StoryManager.get_sto_nino_spec()
	var dur_str := "All Day" if bool(spec["all_day"]) else "%dh" % int(roundf(float(spec["duration_hours"])))
	EventBus.show_notification.emit(
		"Sto. Niño's Blessing!",
		"%s (%s)" % [" + ".join(names), dur_str],
		"purchase"
	)

func _play_blessing_bounce() -> void:
	var visuals := get_visual_nodes()
	if visuals.is_empty():
		return
	var visual := visuals[0]
	var tw := create_tween()
	tw.tween_property(visual, "scale", _visual_base_scale * Vector3(1.12, 0.90, 1.12), 0.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(visual, "scale", _visual_base_scale * Vector3(0.96, 1.08, 0.96), 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(visual, "scale", _visual_base_scale, 0.20).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _ensure_outline_material() -> void:
	super._ensure_outline_material()
	if _outline_mat:
		_outline_mat.set_shader_parameter("fixed_y_billboard", true)
