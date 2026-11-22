extends WorldInteractor

@export var required_cat_level: int = 1
@export var meow_pitch_min: float = 0.9
@export var meow_pitch_max: float = 1.1

@export var meow_sounds: Array[AudioStream] = []

var _visual_base_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	super._ready()
	add_to_group("store_cats")
	# The cat is a Sprite3D with Billboard = 2 (Fixed Y)
	# We need to tell the outline shader to match this.
	outline_shader = preload("res://Assets/Shaders/item_outline_spatial.gdshader")
	
	var visuals = get_visual_nodes()
	if not visuals.is_empty():
		_visual_base_scale = visuals[0].scale

	EventBus.cat_upgraded.connect(_on_cat_upgraded)
	refresh_visibility(false)

func _on_cat_upgraded(_new_level: int) -> void:
	refresh_visibility(true)

func refresh_visibility(play_pop_in: bool = false) -> void:
	var was_visible := visible
	var unlocked := StoryManager.cat_upgrade_level >= required_cat_level
	visible = unlocked
	monitoring = unlocked
	monitorable = unlocked
	collision_layer = 1 if unlocked else 0
	if not unlocked:
		on_hover(false)

	if unlocked and not was_visible and play_pop_in:
		var visuals = get_visual_nodes()
		if not visuals.is_empty():
			var visual = visuals[0]
			visual.scale = Vector3.ZERO
			var tw = create_tween()
			tw.tween_property(visual, "scale", _visual_base_scale * Vector3(1.18, 0.86, 1.18), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(visual, "scale", _visual_base_scale, 0.24).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			VisualEffectManager.spawn_heart_burst(visual.global_position + Vector3(0, 0.25, 0))
		_play_meow(-14.0)

func on_interact() -> void:
	if not visible or meow_sounds.is_empty():
		return

	_play_meow(-12.0)

	# VFX: Heart Burst (using pink stars) at the actual Sprite3D position
	var visuals = get_visual_nodes()
	var burst_pos: Vector3 = visuals[0].global_position + Vector3(0, 0.2, 0) if not visuals.is_empty() else global_position + Vector3(0, 0.2, 0)
	VisualEffectManager.spawn_heart_burst(burst_pos)

	_play_pet_animation()

func _play_meow(volume_db: float) -> void:
	if meow_sounds.is_empty():
		return
	var random_meow = meow_sounds.pick_random()
	var temp_player = AudioStreamPlayer3D.new()
	add_child(temp_player)
	temp_player.bus = &"SFX"
	temp_player.stream = random_meow
	temp_player.pitch_scale = randf_range(meow_pitch_min, meow_pitch_max)
	temp_player.volume_db = volume_db
	temp_player.play()
	temp_player.finished.connect(temp_player.queue_free)

func _play_pet_animation() -> void:
	var visuals = get_visual_nodes()
	if visuals.is_empty(): return
	
	var visual = visuals[0]
	var tw = create_tween()
	var start_scale = _visual_base_scale
	
	# Fast Squash (Wider and shorter)
	tw.tween_property(visual, "scale", start_scale * Vector3(1.15, 0.85, 1.15), 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Fast Stretch (Taller and thinner)
	tw.tween_property(visual, "scale", start_scale * Vector3(0.95, 1.1, 0.95), 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# Overshoot bounce back to normal
	tw.tween_property(visual, "scale", start_scale, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _ensure_outline_material() -> void:
	super._ensure_outline_material()
	if _outline_mat:
		_outline_mat.set_shader_parameter("fixed_y_billboard", true)
