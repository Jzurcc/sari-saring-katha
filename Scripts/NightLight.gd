@tool
extends DirectionalLight3D

const NIGHT_START: float = 18.0
const NIGHT_END: float = 5.0
const MAX_ENERGY: float = 0.35
const FADE_DURATION: float = 2.0

var _tween: Tween = null
var _tod: Node = null

func _ready() -> void:
	if not is_inside_tree(): return
	
	# Wait one frame so Sky3D/TimeOfDay are fully initialized
	await get_tree().process_frame

	_tod = _find_time_of_day()
	if _tod:
		_tod.hour_changed.connect(_on_hour_changed)
		_tod.time_changed.connect(_on_time_changed)
		_update_state(_tod.current_time, false)
	else:
		if not Engine.is_editor_hint():
			push_warning("[NightLight] TimeOfDay node not found — defaulting to night on.")
		light_energy = MAX_ENERGY


func _find_time_of_day() -> Node:
	# Walk up to the scene root and search
	var root := get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene
	if root == null: return null
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
	if not Engine.is_editor_hint():
		_update_state(float(hour), true)


func _on_time_changed(time: float) -> void:
	# In editor, update instantly while dragging the time slider
	if Engine.is_editor_hint():
		_update_state(time, false)


func _update_state(time: float, animated: bool) -> void:
	var is_night := time >= NIGHT_START or time <= NIGHT_END
	var target := MAX_ENERGY if is_night else 0.0

	if _tween:
		_tween.kill()
		_tween = null

	if animated and is_inside_tree():
		_tween = create_tween()
		_tween.tween_property(self, "light_energy", target, FADE_DURATION).set_trans(Tween.TRANS_SINE)
	else:
		light_energy = target
