extends WorldInteractor

## Interactive 3D Wall Calendar in the store.
## Hovering highlights the calendar mesh; clicking opens the Calendar & Events overlay (same as pressing C).

var _meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("calendar_item")
	super._ready()
	outline_width = 48.0
	outline_shader = preload("res://Shaders/outline.gdshader")
	_collect_meshes()

func _collect_meshes() -> void:
	var cal_root := get_node_or_null("../Calendar")
	if not cal_root:
		push_warning("[CalendarInteractable] No sibling 'Calendar' found.")
		return
	_find_meshes_recursive(cal_root)

func _find_meshes_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		_meshes.append(node)
	for child in node.get_children():
		_find_meshes_recursive(child)

func get_visual_nodes() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for m in _meshes:
		result.append(m)
	return result

func on_interact() -> void:
	if Dialogic.current_timeline != null or get_tree().paused:
		return
	EventBus.events_overlay_toggled.emit(true)
