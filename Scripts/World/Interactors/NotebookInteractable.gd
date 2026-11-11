extends WorldInteractor

@export var notebook_ui_scene: PackedScene

var _meshes: Array[MeshInstance3D] = []
var _is_ui_open: bool = false

func _ready() -> void:
	add_to_group("notebook_item")
	super._ready()
	# Notebook outline
	outline_width = 64.0
	outline_shader = preload("res://Shaders/outline.gdshader")
	_collect_meshes()

func _collect_meshes() -> void:
	var notebook_root = get_node_or_null("../notebook")
	if not notebook_root:
		push_warning("[NotebookInteractable] No sibling 'notebook' found.")
		return
	
	_find_meshes_recursive(notebook_root)

func _find_meshes_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		_meshes.append(node)
	for child in node.get_children():
		_find_meshes_recursive(child)

## Override base visual node detection to use our collected mesh list
func get_visual_nodes() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for m in _meshes:
		result.append(m)
	return result

func on_hover(is_hovered: bool) -> void:
	if is_hovered:
		_apply_outline(default_outline_color)
	else:
		_remove_outline()

func on_interact() -> void:
	if _is_ui_open:
		return

	if Dialogic.current_timeline != null:
		return # Block call while someone is already talking
		
	if notebook_ui_scene:
		_is_ui_open = true
		var ui := notebook_ui_scene.instantiate()
		get_tree().root.add_child(ui)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui.notebook_closed.connect(_on_notebook_ui_closed, CONNECT_ONE_SHOT)
	else:
		push_error("[NotebookInteractable] Missing Notebook UI Scene in the Inspector!")

func _on_notebook_ui_closed() -> void:
	_is_ui_open = false
	# Restore first-person input
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
