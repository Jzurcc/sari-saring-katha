## NokiaClickRegion.gd
## Attached to NokiaInteractable (Area3D) in MainGame.
## Mirrors the RefrigeratorDoor pattern: find the sibling "nokia" scene node,
## collect every MeshInstance3D inside it, and toggle material_overlay on hover.
extends Area3D

const OUTLINE_SHADER := "res://Shaders/outline.gdshader"

@export var nokia_ui_scene: PackedScene
## 3D marker near the phone where Uncle Mario's speech bubble will anchor.
@export var phone_anchor: Node3D

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
		
	var is_blocked = (Dialogic.current_timeline != null)
	if is_hovered:
		if is_blocked:
			_outline_mat.set_shader_parameter("outline_color", Color.RED)
		else:
			_outline_mat.set_shader_parameter("outline_color", Color.WHITE)
			
	var target_mat = _outline_mat if is_hovered else null
	for mesh in _meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = target_mat

func on_interact() -> void:
	if Dialogic.current_timeline != null:
		return # Cannot interact while dialogue is playing
		
	if nokia_ui_scene:
		var ui := nokia_ui_scene.instantiate()
		# Pass the 3D anchor to the NokiaUI before adding to tree
		if phone_anchor:
			ui.phone_anchor = phone_anchor
		get_tree().root.add_child(ui)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Restore state when the UI closes (cancel or end of call)
		ui.nokia_closed.connect(_on_nokia_ui_closed, CONNECT_ONE_SHOT)
		var restock_menu = ui.get_node_or_null("RestockMenu")
		if restock_menu and restock_menu.has_signal("menu_close_requested"):
			restock_menu.menu_close_requested.connect(_on_restock_screen_closed.bind(ui), CONNECT_ONE_SHOT)
	else:
		push_error("[Nokia3D] Missing Nokia UI Scene in the Inspector!")

func _on_nokia_ui_closed() -> void:
	# Restore first-person input
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_restock_screen_closed(ui: Node) -> void:
	# Free the dynamically instantiated RestockScreen
	if is_instance_valid(ui):
		ui.queue_free()
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
