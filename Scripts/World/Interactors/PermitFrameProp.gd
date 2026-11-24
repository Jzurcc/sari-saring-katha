extends Sprite3D

## Controls visibility and pop-in animation for the framed Business Permit prop.
## Hidden until Level 1 (Barangay Business Permit) is unlocked, then pops in on display.

var _base_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	_base_scale = scale
	add_to_group("permit_frame")
	EventBus.permit_upgraded.connect(_on_permit_upgraded)
	refresh_visibility(false)

func _on_permit_upgraded(_new_level: int) -> void:
	refresh_visibility(true)

func refresh_visibility(play_pop_in: bool = false) -> void:
	var was_visible := visible
	var unlocked := StoryManager.permit_upgrade_level >= 1
	visible = unlocked
	if unlocked and play_pop_in:
		if not was_visible:
			scale = Vector3.ZERO
		var tw := create_tween()
		tw.tween_property(self, "scale", _base_scale * Vector3(1.18, 0.88, 1.18), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", _base_scale, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		VisualEffectManager.spawn_heart_burst(global_position + Vector3(0, 0.2, 0))
