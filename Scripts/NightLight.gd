## NightLight.gd
## A faint directional fill light that simulates ambient moonlight/starlight.
## Fades in after 18:00 and fades out before 05:00.

extends DirectionalLight3D

const NIGHT_START: float = 18.0
const NIGHT_END: float = 5.0
const MAX_ENERGY: float = 0.35
const FADE_DURATION: float = 2.0

var _tween: Tween = null


func _ready() -> void:
	# Wait one frame so Sky3D/TimeOfDay are fully initialized
	await get_tree().process_frame

	var tod := _find_time_of_day()
	if tod:
		tod.hour_changed.connect(_on_hour_changed)
		# Apply immediately based on current time
		_set_night(tod.current_time >= NIGHT_START or tod.current_time < NIGHT_END, false)
	else:
		push_warning("[NightLight] TimeOfDay node not found — defaulting to night on.")
		light_energy = MAX_ENERGY


func _find_time_of_day() -> Node:
	# Walk up to the scene root and search
	var root := get_tree().current_scene
	return _search(root, "TimeOfDay")


func _search(node: Node, target: String) -> Node:
	if node.name == target:
		return node
	for child in node.get_children():
		var found := _search(child, target)
		if found:
			return found
	return null


func _on_hour_changed(hour: int) -> void:
	var is_night := hour >= int(NIGHT_START) or hour < int(NIGHT_END)
	_set_night(is_night, true)


func _set_night(is_night: bool, animated: bool) -> void:
	var target := MAX_ENERGY if is_night else 0.0
	if _tween:
		_tween.kill()
	if animated:
		_tween = create_tween()
		_tween.tween_property(self, "light_energy", target, FADE_DURATION).set_trans(Tween.TRANS_SINE)
	else:
		light_energy = target
