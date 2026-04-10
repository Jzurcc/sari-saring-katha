## RefrigeratorDoor.gd
## Root script for the refrigerator door mesh (MeshInstance3D).
## Interaction is driven by PlayerInteraction's center-screen raycast which
## calls on_hover() / on_interact() on the Area3D child. The Area3D forwards
## those calls here via FridgeDoorInteractor.gd.
##
## PIVOT: set the `hinge` export to a clean Node3D parent (no baked rotation)
## positioned at the door's hinge edge. The script rotates that node on Y
## instead of self, giving a clean swing regardless of any baked mesh transform.
class_name RefrigeratorDoor
extends MeshInstance3D

# ----- Exports ------------------------------------------------------------------
## Node to rotate for the door swing (should be a clean Node3D at the hinge).
## Leave empty to fall back to rotating self.
@export var hinge: Node3D = null

# ----- Tunables -----------------------------------------------------------------
const OPEN_ANGLE_DEG := 90.0   ## Flip sign if the door swings the wrong way
const ANIM_DURATION   := 0.5
const OUTLINE_SHADER  := "res://Shaders/outline.gdshader"

# ----- State --------------------------------------------------------------------
var is_open: bool = false
var _tween: Tween
var _outline_mat: ShaderMaterial
var _pivot: Node3D

# ================================================================================
func _ready() -> void:
	_resolve_pivot()
	_build_outline_material()


func _resolve_pivot() -> void:
	# 1. Use the exported hinge node if it resolved correctly.
	if is_instance_valid(hinge):
		_pivot = hinge
		return
	# 2. Fall back to the direct parent Node3D (FridgeDoorPivot).
	#    Instanced-scene-root NodePath overrides are unreliable in Godot 4;
	#    get_parent() gives us the pivot reliably.
	var p := get_parent()
	if p is Node3D:
		_pivot = p as Node3D
		return
	# 3. Last resort — rotate self (hinge setup is missing entirely).
	push_warning("RefrigeratorDoor: no valid hinge found, rotating self.")
	_pivot = self


func _build_outline_material() -> void:
	var shader := load(OUTLINE_SHADER) as Shader
	if not shader:
		push_warning("RefrigeratorDoor: shader not found at %s" % OUTLINE_SHADER)
		return
	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = shader
	_outline_mat.set_shader_parameter("outline_color", Color.WHITE)
	_outline_mat.set_shader_parameter("outline_width", 8.0)


# Called by FridgeDoorInteractor (Area3D child) — matches PlayerInteraction API
func on_hover(is_hovered: bool) -> void:
	material_overlay = _outline_mat if is_hovered else null


func on_interact() -> void:
	toggle_open()

# Close open
func toggle_open() -> void:
	is_open = !is_open
	var target_rot := Vector3(0, deg_to_rad(OPEN_ANGLE_DEG), 0) if is_open \
					  else Vector3.ZERO

	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(_pivot, "rotation", target_rot, 0.65) \
		  .set_trans(Tween.TRANS_SINE) \
		  .set_ease(Tween.EASE_IN_OUT)
