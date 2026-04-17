extends WorldInteractor

@export var nokia_ui_scene: PackedScene
## 3D marker near the phone where Uncle Mario's speech bubble will anchor.
@export var phone_anchor: Node3D

var _meshes: Array[MeshInstance3D] = []
var _nokia_root: Node = null  # Kept so we can hide/show the 3D model

func _ready() -> void:
	super._ready()
	# Nokia outline needs to be thicker since the model is small/detailed
	outline_width = 96.0
	# RESTORE: Use the specialized 3D mesh outline shader instead of the 2D billboard one
	outline_shader = preload("res://Shaders/outline.gdshader")
	_collect_meshes()

func _collect_meshes() -> void:
	var nokia_root = get_node_or_null("../nokia")
	if not nokia_root:
		nokia_root = get_node_or_null("../nokia_phone")
		
	if not nokia_root:
		push_warning("[NokiaClickRegion] No sibling 'nokia' or 'nokia_phone' found.")
		return
	
	_nokia_root = nokia_root
	_find_meshes_recursive(nokia_root)


func _find_meshes_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		_meshes.append(node)
	for child in node.get_children():
		_find_meshes_recursive(child)

## Override base visual node detection to use our collected mesh list
func get_visual_nodes() -> Array[Node3D]:
	# Cast Array[MeshInstance3D] to Array[Node3D]
	var result: Array[Node3D] = []
	for m in _meshes:
		result.append(m)
	return result

func on_hover(is_hovered: bool) -> void:
	if is_hovered:
		var color = default_outline_color
		if MarioManager.is_mario_physically_present:
			color = Color.RED
		_apply_outline(color)
	else:
		_remove_outline()

func on_interact() -> void:
	if Dialogic.current_timeline != null:
		return # Block call while someone is already talking
		
	if MarioManager.is_mario_physically_present:
		print("[Nokia] Blocked: Uncle Mario is physically present.")
		AudioManager.play_sfx("error")
		return
		
	if nokia_ui_scene:
		var ui := nokia_ui_scene.instantiate()
		# Pass the 3D anchor to the NokiaUI before adding to tree
		if phone_anchor:
			ui.phone_anchor = phone_anchor
		get_tree().root.add_child(ui)
		EventBus.nokia_opened.emit()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Restore state when the UI closes (cancel or end of call)
		ui.nokia_closed.connect(_on_nokia_ui_closed, CONNECT_ONE_SHOT)
		var restock_menu = ui.get_node_or_null("RestockMenu")
		if restock_menu and restock_menu.has_signal("menu_close_requested"):
			restock_menu.menu_close_requested.connect(_on_nokia_ui_closed_with_parent.bind(ui), CONNECT_ONE_SHOT)
	else:
		push_error("[Nokia3D] Missing Nokia UI Scene in the Inspector!")

func _on_nokia_ui_closed() -> void:
	# Restore first-person input
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.nokia_closed.emit()

func _on_nokia_ui_closed_with_parent(ui: Node) -> void:
	# Free the dynamically instantiated Nokia UI
	if is_instance_valid(ui):
		ui.queue_free()
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.nokia_closed.emit()
