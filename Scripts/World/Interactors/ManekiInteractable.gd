extends WorldInteractor

## Lucky Waving Cat (Maneki-Neko) counter prop.
## Hidden until Maneki-Neko Lv.1 is unlocked; gently sways (brisker with Lv.2 Fresh Batteries)
## and wiggles happily when tapped.

var _sprite: Sprite3D = null
var _maneki_base_scale: Vector3 = Vector3.ONE
var _wave_time: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group("store_maneki")
	billboard_collision = true
	outline_shader = preload("res://Assets/Shaders/item_outline_spatial.gdshader")
	default_outline_color = Color(1.0, 0.84, 0.42, 1.0)
	outline_width = 24.0

	_sprite = get_node_or_null("ManekiNeko") as Sprite3D
	if _sprite == null:
		var visuals := get_visual_nodes()
		if not visuals.is_empty() and visuals[0] is Sprite3D:
			_sprite = visuals[0] as Sprite3D
	if is_instance_valid(_sprite):
		_maneki_base_scale = _sprite.scale

	refresh_visibility(false)


func _process(delta: float) -> void:
	super._process(delta)
	if not visible or StoryManager.maneki_upgrade_level < 1 or not is_instance_valid(_sprite):
		return
	var speed := 4.4 if StoryManager.maneki_upgrade_level >= 2 else 2.6
	_wave_time += delta * speed
	_sprite.rotation.z = sin(_wave_time) * (0.065 if StoryManager.maneki_upgrade_level >= 2 else 0.04)


func refresh_visibility(play_pop_in: bool = false) -> void:
	var was_visible := visible
	var unlocked := StoryManager.maneki_upgrade_level >= 1
	visible = unlocked
	monitoring = unlocked
	monitorable = unlocked
	collision_layer = 1 if unlocked else 0
	if not unlocked:
		on_hover(false)
		return

	if play_pop_in and is_instance_valid(_sprite):
		if not was_visible:
			_sprite.scale = Vector3.ZERO
		var tw := create_tween()
		tw.tween_property(_sprite, "scale", _maneki_base_scale * Vector3(1.18, 0.88, 1.18), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_sprite, "scale", _maneki_base_scale, 0.24).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		VisualEffectManager.spawn_heart_burst(_sprite.global_position + Vector3(0.0, 0.22, 0.0))


func on_interact() -> void:
	if StoryManager.maneki_upgrade_level < 1 or not is_instance_valid(_sprite):
		return
	AudioManager.play_sfx("interact")
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", _maneki_base_scale * Vector3(1.14, 0.90, 1.14), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sprite, "scale", _maneki_base_scale, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
