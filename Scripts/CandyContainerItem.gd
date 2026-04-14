class_name CandyContainerItem
extends Area3D

## An interactable candy bowl that spawns a random [DraggableItem] when clicked.
##
## On interact, picks a random in-stock candy from [member possible_candies],
## deducts one unit from [InventoryManager], and hands it off to [DragManager]
## as a transient item ready to drag to the transaction tray.

const DRAGGABLE_ITEM_SCENE: PackedScene = preload("res://Scenes/DraggableItem.tscn")

@export var possible_candies: Array[ItemData] = []

@onready var sprite: Sprite3D = $Sprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var outline_material: ShaderMaterial = null
var camera: Camera3D

func _ready() -> void:
	camera = get_viewport().get_camera_3d()

	# Failsafe: seed any candy with zero stock to 10 so the jar is usable out of the box.
	for candy in possible_candies:
		if InventoryManager.get_stock(candy) == 0:
			InventoryManager.restock_item(candy, 10)

func _process(_delta: float) -> void:
	if camera and is_instance_valid(collision_shape):
		var dir := camera.global_position - collision_shape.global_position
		if dir.length_squared() > 0.001 and abs(dir.normalized().dot(Vector3.UP)) < 0.99:
			collision_shape.look_at(camera.global_position, Vector3.UP)


func on_hover(is_hovered: bool) -> void:
	if is_hovered:
		_ensure_outline_material()
		sprite.material_overlay = outline_material
	else:
		sprite.material_overlay = null
		_reset_outline_color()

func on_interact() -> void:
	if DragManager._is_dragging:
		return

	var available_candies: Array[ItemData] = []
	for candy in possible_candies:
		if InventoryManager.get_stock(candy) > 0:
			available_candies.append(candy)

	if available_candies.is_empty():
		_play_error_animation()
		return

	var chosen_candy: ItemData = available_candies[randi() % available_candies.size()]

	if InventoryManager.take_item(chosen_candy):
		var drag_item: DraggableItem = DRAGGABLE_ITEM_SCENE.instantiate()
		get_tree().current_scene.add_child(drag_item)
		drag_item.is_transient = true
		drag_item.setup(chosen_candy, self.global_transform)
		drag_item.sprite.hide()
		DragManager.start_drag(drag_item, chosen_candy.texture)

func _input_event(_camera: Camera3D, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			on_interact()


# --- Private ---

## Lazily create the shared outline ShaderMaterial the first time it is needed.
func _ensure_outline_material() -> void:
	if outline_material or not sprite.texture:
		return
	outline_material = ShaderMaterial.new()
	outline_material.shader = preload("res://Assets/Shaders/item_outline_spatial.gdshader")
	outline_material.set_shader_parameter("albedo_texture", sprite.texture)
	outline_material.set_shader_parameter("outline_color", Color.WHITE)
	outline_material.set_shader_parameter("outline_width", 16.0)

## Reset outline to white (safe to call even when no material exists yet).
func _reset_outline_color() -> void:
	if outline_material:
		outline_material.set_shader_parameter("outline_color", Color.WHITE)

## Flash the outline red and shake the sprite to signal an empty stock error.
func _play_error_animation() -> void:
	_ensure_outline_material()
	if outline_material:
		outline_material.set_shader_parameter("outline_color", Color(1.0, 0.2, 0.2))

	var tween := create_tween()
	var base_x := sprite.position.x
	const INTENSITY := 0.05
	const STEP := 0.05
	tween.tween_property(sprite, "position:x", base_x - INTENSITY, STEP)
	tween.tween_property(sprite, "position:x", base_x + INTENSITY, STEP)
	tween.tween_property(sprite, "position:x", base_x - INTENSITY, STEP)
	tween.tween_property(sprite, "position:x", base_x + INTENSITY, STEP)
	tween.tween_property(sprite, "position:x", base_x, STEP)

	get_tree().create_timer(0.4).timeout.connect(_reset_outline_color)
