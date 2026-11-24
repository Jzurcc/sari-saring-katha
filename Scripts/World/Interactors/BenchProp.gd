extends MeshInstance3D

## Controls visibility, collision, and pop-in animation for the outside Sari-Sari Bench.
## Hidden by default until Bench Upgrade Level 1 (Sari-Sari Tambayan Bench) is purchased.

var _base_scale: Vector3 = Vector3.ONE
var _collision_shape: CollisionShape3D = null

func _ready() -> void:
	_base_scale = scale
	add_to_group("store_bench")
	var body := get_node_or_null("StaticBody3D")
	if body:
		_collision_shape = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	EventBus.bench_upgraded.connect(_on_bench_upgraded)
	refresh_visibility(false)

func _on_bench_upgraded(_new_level: int) -> void:
	refresh_visibility(true)

func refresh_visibility(play_pop_in: bool = false) -> void:
	var was_visible := visible
	var unlocked := StoryManager.bench_upgrade_level >= 1
	visible = unlocked
	if is_instance_valid(_collision_shape):
		_collision_shape.disabled = not unlocked
	if unlocked and play_pop_in:
		if not was_visible:
			scale = Vector3.ZERO
		var tw := create_tween()
		tw.tween_property(self, "scale", _base_scale * Vector3(1.12, 0.90, 1.12), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", _base_scale, 0.24).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		VisualEffectManager.spawn_heart_burst(global_position + Vector3(0, 0.5, 0))
