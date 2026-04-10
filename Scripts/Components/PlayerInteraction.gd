extends Node
class_name PlayerInteraction

## Component attached to the camera or player head to handle 3D raycast interactions.
## Decouples picking logic from MainGame.gd

@export var interaction_range: float = 10.0
@export var camera: Camera3D

var _last_hovered: Node = null

func _ready():
	if not camera:
		if get_node(".") is Camera3D:
			camera = get_node(".") as Camera3D
		else:
			camera = get_parent() as Camera3D

func _physics_process(_delta: float) -> void:
	if not camera or Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED or DragManager._is_dragging:
		if is_instance_valid(_last_hovered) and _last_hovered.has_method("on_hover"):
			_last_hovered.on_hover(false)
			_last_hovered = null
		return

	var center := get_viewport().get_visible_rect().size / 2.0
	var ray_origin := camera.project_ray_origin(center)
	var ray_dir := camera.project_ray_normal(center)

	var query := PhysicsRayQueryParameters3D.new()
	query.from = ray_origin
	query.to = ray_origin + ray_dir * interaction_range
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var current_hovered = null
	if result:
		current_hovered = result.get("collider")
	
	if current_hovered != _last_hovered:
		if is_instance_valid(_last_hovered) and _last_hovered.has_method("on_hover"):
			_last_hovered.on_hover(false)
		if current_hovered and current_hovered.has_method("on_hover"):
			current_hovered.on_hover(true)
		_last_hovered = current_hovered

func _input(event: InputEvent) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Ask DragManager if it's already dragging.
		# Note: We emit a global request if we want to pick something up.
		# Since it's refactored, we just call interact on the hovered object!
		if is_instance_valid(_last_hovered):
			if _last_hovered.has_method("on_interact"):
				get_viewport().set_input_as_handled()
				_last_hovered.on_interact()
			elif _last_hovered is DraggableItem:
				get_viewport().set_input_as_handled()
				_pickup_item(_last_hovered)

func _pickup_item(item: DraggableItem) -> void:
	# Avoid cyclic singleton checks if possible, or trigger EventBus
	if item.item_data and not InventoryManager.is_in_stock(item.item_data):
		print("[PlayerInteraction] Out of stock: ", item.item_data.item_name)
		return
	if item.item_data:
		InventoryManager.take_item(item.item_data)
	
	# Start dragging with DragManager
	DragManager.start_drag(item, item.sprite.texture)
