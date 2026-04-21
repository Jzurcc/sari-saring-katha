extends WorldInteractor

@export var meow_sounds: Array[AudioStream] = []

var _visual_base_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	super._ready()
	# The cat is a Sprite3D with Billboard = 2 (Fixed Y)
	# We need to tell the outline shader to match this.
	outline_shader = preload("res://Assets/Shaders/item_outline_spatial.gdshader")
	
	var visuals = get_visual_nodes()
	if not visuals.is_empty():
		_visual_base_scale = visuals[0].scale

func on_interact() -> void:
	if meow_sounds.is_empty():
		return
		
	var random_meow = meow_sounds.pick_random()
	
	# Create a temporary player for "stacking"
	var temp_player = AudioStreamPlayer3D.new()
	add_child(temp_player)
	temp_player.bus = &"SFX"
	temp_player.stream = random_meow
	temp_player.pitch_scale = randf_range(0.9, 1.1)
	temp_player.volume_db = -12.0
	# Copy spatial settings if needed, but defaults are usually fine for Area3D children
	temp_player.play()
	
	# Clean up when finished
	temp_player.finished.connect(temp_player.queue_free)
	
	# VFX: Heart Burst (using pink stars)
	VisualEffectManager.spawn_heart_burst(global_position + Vector3(0, 0.2, 0))
	
	_play_pet_animation()

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
