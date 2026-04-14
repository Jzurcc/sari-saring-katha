class_name WorldInteractor
extends Area3D

## Base class for interactable 3D objects (items, containers, props).
## Centralizes hover outlines and optional collision billboarding.

@export_group("Interaction Settings")
## If enabled, the collision shape will rotate to face the camera every frame.
## Useful for 2D sprites in 3D space to ensure picking matches visuals.
@export var billboard_collision: bool = false

@export_group("Visuals")
## The shader to use for the hover outline.
## Use res://Assets/Shaders/item_outline_spatial.gdshader for 2D sprites.
## Use res://Shaders/outline.gdshader for 3D meshes.
@export var outline_shader: Shader = preload("res://Assets/Shaders/item_outline_spatial.gdshader")
## Width of the outline on hover.
@export var outline_width: float = 32.0
## The color of the outline when hovered under normal conditions.
@export var default_outline_color: Color = Color.WHITE

var _camera: Camera3D
var _outline_mat: ShaderMaterial = null

func _ready() -> void:
	_camera = get_viewport().get_camera_3d()

func _process(_delta: float) -> void:
	if billboard_collision and _camera:
		_billboard_node(get_collision_node())

## Returns the node to billboard. Defaults to the first CollisionShape3D.
func get_collision_node() -> Node3D:
	for child in get_children():
		if child is CollisionShape3D:
			return child
	return null

## Returns the nodes to apply the outline to. Defaults to children of type [Sprite3D] or [MeshInstance3D].
## Override this if you want to target specific nested meshes.
func get_visual_nodes() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in get_children():
		if child is Sprite3D or child is MeshInstance3D:
			result.append(child)
	return result

func on_hover(is_hovered: bool) -> void:
	if is_hovered:
		_apply_outline(default_outline_color)
	else:
		_remove_outline()

func on_interact() -> void:
	# Virtual method to be overridden by subclasses
	pass

func _input_event(_viewport_camera: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			on_interact()

# --- Internal ---

func _billboard_node(node: Node3D) -> void:
	if not is_instance_valid(node): return
	var dir := _camera.global_position - node.global_position
	if dir.length_squared() > 0.001 and abs(dir.normalized().dot(Vector3.UP)) < 0.99:
		node.look_at(_camera.global_position, Vector3.UP)

func _apply_outline(color: Color) -> void:
	_ensure_outline_material()
	if not _outline_mat: return
	
	_outline_mat.set_shader_parameter("outline_color", color)
	for visual in get_visual_nodes():
		visual.material_overlay = _outline_mat

func _remove_outline() -> void:
	for visual in get_visual_nodes():
		visual.material_overlay = null

func _ensure_outline_material() -> void:
	if _outline_mat: return
	if not outline_shader: return
	
	# Try to find a reference texture from the first visual node to feed the shader (if it's the sprite billboard shader)
	var ref_tex: Texture2D = null
	var visuals = get_visual_nodes()
	if not visuals.is_empty():
		if visuals[0] is Sprite3D:
			ref_tex = visuals[0].texture
	
	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = outline_shader
	_outline_mat.set_shader_parameter("outline_width", outline_width)
	
	# Only set albedo_texture if the shader has that parameter and we have a texture
	# Standard mesh outlines don't need this.
	if ref_tex:
		_outline_mat.set_shader_parameter("albedo_texture", ref_tex)
