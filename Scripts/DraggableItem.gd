class_name DraggableItem
extends Area3D

signal drag_started
signal drag_ended

@export var item_data: ItemData

## Full local transform at spawn time — used to tween item back to its slot.
var _original_transform: Transform3D = Transform3D.IDENTITY

@onready var sprite: Sprite3D = $Sprite3D
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var label: Label3D = $Label3D

func _ready() -> void:
	if item_data:
		setup(item_data)

## Configure this item with [param data] and place it at [param local_transform]
## in the parent surface's local coordinate space.
##
## [param local_transform] is supplied by the parent [ShelfSurface] via its
## [LayoutStrategy]. Defaults to [constant Transform3D.IDENTITY] so that
## items configured directly in the Inspector (without a ShelfSurface) stay
## at the position set in the scene tree.
func setup(data: ItemData, local_transform: Transform3D = Transform3D.IDENTITY) -> void:
	item_data = data

	# Apply the strategy-computed transform (position + tilt rotation)
	transform = local_transform
	# Store immediately — no deferred capture needed since transform is applied above
	_original_transform = local_transform

	if item_data and item_data.texture:
		sprite.texture = item_data.texture

		# --- Sizing ---
		# Guard against invalid display height
		var h: float = item_data.display_height_meters
		if h <= 0.0:
			push_warning("[DraggableItem] '%s': display_height_meters is <= 0, defaulting to 0.2" % item_data.item_name)
			h = 0.2

		# Reset any scale baked into the scene so pixel_size is the sole control
		sprite.scale = Vector3.ONE

		# --- Sizing ---
		var rect = item_data.get_used_rect()
		var v_h = float(rect.size.y) if rect.has_area() else float(item_data.texture.get_height())

		# pixel_size maps true visible height to real-world meters
		sprite.pixel_size = h / v_h

		# --- Offset & Alignment ---
		# Center the actual opaque pixels at the node's origin
		var tex_center = Vector2(item_data.texture.get_width(), item_data.texture.get_height()) / 2.0
		var opaque_center = Vector2(rect.position) + Vector2(rect.size) / 2.0

		# In Godot Sprite3D:
		# positive X offset moves texture right
		# positive Y offset moves texture UP
		var offset_x = tex_center.x - opaque_center.x
		var offset_y = opaque_center.y - tex_center.y 
		sprite.offset = Vector2(offset_x, offset_y)

		# Now that it's perfectly centered, shift it up to sit on the shelf
		sprite.position = Vector3.ZERO
		sprite.position.y = h / 2.0

		# --- Tilt (Z-axis roll on the Sprite3D) ---
		# Applied on the sprite itself so it's visible even with billboard=ENABLED.
		# The strategy encodes roll in the transform basis; extract and re-apply
		# to the sprite so the DraggableItem's own transform stays axis-aligned
		# (cleaner for physics / drag positioning).
		var roll_rad := local_transform.basis.get_euler().z
		sprite.rotation.z = roll_rad
		# Keep the DraggableItem's position-only transform (no rotation pollution)
		var pos_only := Transform3D(Basis(), local_transform.origin)
		transform = pos_only
		_original_transform = pos_only

		# --- Collision shape resize ---
		# Resize BoxShape3D to match the rendered sprite dimensions so picking
		# works correctly regardless of item size.
		var rendered_h: float = h
		var aspect: float = item_data.get_visual_aspect()
		var rendered_w: float = (
			item_data.display_width_override
			if item_data.display_width_override > 0.0
			else rendered_h * aspect
		)
		# Duplicate the shape resource so changing this item's collision box
		# doesn't accidentally resize the boxes of every other item in the scene!
		if collider.shape is BoxShape3D:
			collider.shape = collider.shape.duplicate()
			collider.shape.size = Vector3(rendered_w, rendered_h, max(0.1, rendered_w))
		collider.position.y = rendered_h / 2.0

	if label:
		label.hide()

var outline_material: ShaderMaterial = null

func on_hover(is_hovered: bool) -> void:
	if is_hovered:
		if not outline_material and sprite.texture:
			outline_material = ShaderMaterial.new()
			outline_material.shader = preload("res://Assets/Shaders/item_outline_spatial.gdshader")
			outline_material.set_shader_parameter("albedo_texture", sprite.texture)
			outline_material.set_shader_parameter("outline_color", Color.WHITE)
			outline_material.set_shader_parameter("outline_width", 0.05)
			outline_material.set_shader_parameter("z_roll_rad", sprite.rotation.z)
		sprite.material_overlay = outline_material
	else:
		sprite.material_overlay = null

func on_interact() -> void:
	if DragManager._is_dragging: return
	DragManager.start_drag(self, sprite.texture)

func _input_event(_camera: Camera3D, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			on_interact()

func _on_drag_started_by_manager() -> void:
	sprite.hide()
	label.hide()
	drag_started.emit()

func _on_drag_cancelled_by_manager() -> void:
	show_visuals()
	drag_ended.emit()

func show_visuals() -> void:
	sprite.show()

func return_to_start() -> void:
	show_visuals()
	var tween := create_tween()
	# Restore full local transform (position only — tilt lives on the sprite node)
	tween.tween_property(self, "transform", _original_transform, 0.25)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
