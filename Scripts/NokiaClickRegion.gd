## NokiaClickRegion.gd
## Attached to NokiaInteractable (Area3D) in MainGame.
## Mirrors the RefrigeratorDoor pattern: find the sibling "nokia" scene node,
## collect every MeshInstance3D inside it, and toggle material_overlay on hover.
extends Area3D

const OUTLINE_SHADER := "res://Shaders/outline.gdshader"

@export var nokia_ui_scene: PackedScene

var _meshes: Array[MeshInstance3D] = []
var _outline_mat: ShaderMaterial
var _nokia_root: Node = null  # Kept so we can hide/show the 3D model

func _ready() -> void:
	_build_outline_material()
	_collect_meshes()

func _build_outline_material() -> void:
	var shader := load(OUTLINE_SHADER) as Shader
	if not shader:
		push_warning("[NokiaClickRegion] Outline shader not found: " + OUTLINE_SHADER)
		return
	
	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = shader
	_outline_mat.set_shader_parameter("outline_color", Color.WHITE)
	_outline_mat.set_shader_parameter("outline_width", 48.0)

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

func on_hover(is_hovered: bool) -> void:
	if not _outline_mat:
		return
		
	var target_mat = _outline_mat if is_hovered else null
	for mesh in _meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = target_mat

func on_interact() -> void:
	if nokia_ui_scene:
		var ui := nokia_ui_scene.instantiate()
		get_tree().root.add_child(ui)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Hide the 3D model while the 2D Nokia UI is open
		if is_instance_valid(_nokia_root):
			_nokia_root.visible = false
		# Restore state when the UI closes (cancel or end of call)
		ui.nokia_closed.connect(_on_nokia_ui_closed, CONNECT_ONE_SHOT)
		if ui.has_signal("menu_close_requested"):
			var restock_menu = ui.get_node_or_null("RestockMenu")
			if restock_menu:
				restock_menu.menu_close_requested.connect(_on_restock_screen_closed, CONNECT_ONE_SHOT)
	else:
		push_error("[Nokia3D] Missing Nokia UI Scene in the Inspector!")

func _on_nokia_ui_closed() -> void:
	# Restore the 3D model and first-person input
	if is_instance_valid(_nokia_root):
		_nokia_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_restock_screen_closed() -> void:
	# Hide the RestockScreen container that wraps the Nokia UI
	var restock_screen = get_tree().get_first_node_in_group("restock_screen")
	if restock_screen:
		restock_screen.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
