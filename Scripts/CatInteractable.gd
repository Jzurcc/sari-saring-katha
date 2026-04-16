extends WorldInteractor

@export var meow_sounds: Array[AudioStream] = []

func _ready() -> void:
	super._ready()
	# The cat is a Sprite3D with Billboard = 2 (Fixed Y)
	# We need to tell the outline shader to match this.
	outline_shader = preload("res://Assets/Shaders/item_outline_spatial.gdshader")

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
	# Copy spatial settings if needed, but defaults are usually fine for Area3D children
	temp_player.play()
	
	# Clean up when finished
	temp_player.finished.connect(temp_player.queue_free)
	
	# VFX: Heart Burst (using pink stars)
	VisualEffectManager.spawn_heart_burst(global_position + Vector3(0, 0.2, 0))

func _ensure_outline_material() -> void:
	super._ensure_outline_material()
	if _outline_mat:
		_outline_mat.set_shader_parameter("fixed_y_billboard", true)
