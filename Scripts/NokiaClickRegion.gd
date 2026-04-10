extends CollisionObject3D

@export var nokia_ui_scene: PackedScene
@export var target_mesh_path: NodePath
var mesh_node: MeshInstance3D = null

func _ready() -> void:
	if target_mesh_path:
		mesh_node = get_node(target_mesh_path) as MeshInstance3D
	else:
		mesh_node = get_parent() as MeshInstance3D

func on_hover(is_hovered: bool) -> void:
	pass

func on_interact() -> void:
	if nokia_ui_scene:
		var ui = nokia_ui_scene.instantiate()
		get_tree().root.add_child(ui)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		push_error("[Nokia3D] Missing Nokia UI Scene in the Inspector!")
