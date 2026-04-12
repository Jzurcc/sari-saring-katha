extends Node
class_name PlayerInteraction

## Component attached to the camera or player head to handle 3D raycast interactions.
## Decouples picking logic from MainGame.gd

## Collision layers used in raycast queries.
const LAYER_ITEMS: int = 1   ## DraggableItems, transaction tray – bit 0
const LAYER_CUSTOMERS: int = 16 ## Customers only – bit 4 (layer 5).
## Using a separate layer means the customer raycast passes clean through the
## counter and any items sitting on it, so the player can always look at a
## customer even when aim is partially blocked by the tray.

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
	# While dialogue is open, dragging, or mouse is free — clear hover and exit.
	if not camera or Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED \
			or DragManager._is_dragging or Dialogic.current_timeline != null:
		if is_instance_valid(_last_hovered) and _last_hovered.has_method("on_hover"):
			_last_hovered.on_hover(false)
			_last_hovered = null
		return

	var center    := get_viewport().get_visible_rect().size / 2.0
	var ray_origin := camera.project_ray_origin(center)
	var ray_dir    := camera.project_ray_normal(center)
	var ray_end    := ray_origin + ray_dir * interaction_range

	# --- Raycast 1: items and tray (layer 1) ---
	var q_items := PhysicsRayQueryParameters3D.new()
	q_items.from               = ray_origin
	q_items.to                 = ray_end
	q_items.collide_with_areas  = true
	q_items.collide_with_bodies = false
	q_items.collision_mask     = LAYER_ITEMS
	var hit_item := camera.get_world_3d().direct_space_state.intersect_ray(q_items)

	# --- Raycast 2: customers only (layer 5) – passes through items/counter ---
	var q_customer := PhysicsRayQueryParameters3D.new()
	q_customer.from               = ray_origin
	q_customer.to                 = ray_end
	q_customer.collide_with_areas  = true
	q_customer.collide_with_bodies = false
	q_customer.collision_mask     = LAYER_CUSTOMERS
	var hit_customer := camera.get_world_3d().direct_space_state.intersect_ray(q_customer)

	# Resolve which target is "closer" to the camera.
	# Items take priority when they are in front of the customer,
	# but if no item is under the crosshair the customer comes through.
	var current_hovered: Node = null
	if hit_item and hit_customer:
		var d_item     := ray_origin.distance_squared_to(hit_item.position)
		var d_customer := ray_origin.distance_squared_to(hit_customer.position)
		current_hovered = hit_item.collider if d_item <= d_customer else hit_customer.collider
	elif hit_item:
		current_hovered = hit_item.collider
	elif hit_customer:
		current_hovered = hit_customer.collider

	# Update hover state only on change to avoid redundant calls every frame.
	if current_hovered != _last_hovered:
		if is_instance_valid(_last_hovered) and _last_hovered.has_method("on_hover"):
			_last_hovered.on_hover(false)
		if current_hovered and current_hovered.has_method("on_hover"):
			current_hovered.on_hover(true)
		_last_hovered = current_hovered

func _input(event: InputEvent) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	# Block all world interaction while dialogue is open.
	if Dialogic.current_timeline != null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_instance_valid(_last_hovered):
			if _last_hovered.has_method("on_interact"):
				get_viewport().set_input_as_handled()
				_last_hovered.on_interact()
			elif _last_hovered is DraggableItem:
				get_viewport().set_input_as_handled()
				_pickup_item(_last_hovered)

func _pickup_item(item: DraggableItem) -> void:
	DragManager.start_drag(item, item.sprite.texture)
