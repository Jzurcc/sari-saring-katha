class_name DraggableItem
extends Area3D

signal drag_started
signal drag_ended

@export var item_data: ItemData

var _original_position: Vector3 = Vector3.ZERO

@onready var sprite: Sprite3D = $Sprite3D
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var label: Label3D = $Label3D

func _ready() -> void:
	if item_data:
		setup(item_data)

func setup(data: ItemData) -> void:
	item_data = data
	if item_data and item_data.texture:
		sprite.texture = item_data.texture
		# Bottom-align: shift the sprite upward so its bottom edge
		# sits at Y=0 of this node (the container floor).
		# Sprite3D offset is in pixel coords; negative Y = up in world.
		sprite.offset.y = -item_data.texture.get_height() / 2.0
		# Move the collision shape up to match the sprite's visual center.
		var sprite_scale: float = sprite.transform.basis.get_scale().y
		var rendered_height: float = item_data.texture.get_height() * sprite.pixel_size * sprite_scale
		collider.position.y = rendered_height / 2.0
	if label:
		label.hide()
	# Defer position capture so parent transforms are fully applied.
	_capture_origin.call_deferred()

func _capture_origin() -> void:
	_original_position = global_position

var outline_material: ShaderMaterial = null

func on_hover(is_hovered: bool) -> void:
	if is_hovered:
		if not outline_material and sprite.texture:
			outline_material = ShaderMaterial.new()
			outline_material.shader = preload("res://Assets/Shaders/item_outline_spatial.gdshader")
			outline_material.set_shader_parameter("albedo_texture", sprite.texture)
			outline_material.set_shader_parameter("outline_color", Color.WHITE)
			outline_material.set_shader_parameter("outline_width", 0.05)
		sprite.material_overlay = outline_material
	else:
		sprite.material_overlay = null

func on_interact() -> void:
	if DragManager._is_dragging: return
	# Check stock before allowing drag
	if item_data and not InventoryManager.is_in_stock(item_data):
		print("[DraggableItem] Out of stock: ", item_data.item_name)
		return
	# Take from inventory when drag starts
	if item_data:
		InventoryManager.take_item(item_data)
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
	# Return the item to inventory since the drag was cancelled
	if item_data:
		InventoryManager.return_item(item_data)
	show_visuals()
	drag_ended.emit()

func show_visuals() -> void:
	sprite.show()

func return_to_start() -> void:
	show_visuals()
	var tween := create_tween()
	tween.tween_property(self, "global_position", _original_position, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
