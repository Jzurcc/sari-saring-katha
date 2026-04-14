extends Camera3D
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

var pricing_mode_active: bool = false

var _q_items: PhysicsRayQueryParameters3D
var _q_customer: PhysicsRayQueryParameters3D
var _last_hovered: Node = null

func _ready() -> void:
	# Ensure interaction_range is valid
	if interaction_range <= 0.0:
		interaction_range = 10.0
			
	_q_items = PhysicsRayQueryParameters3D.new()
	_q_items.collide_with_areas = true
	_q_items.collide_with_bodies = false
	_q_items.collision_mask = LAYER_ITEMS

	_q_customer = PhysicsRayQueryParameters3D.new()
	_q_customer.collide_with_areas = true
	_q_customer.collide_with_bodies = false
	_q_customer.collision_mask = LAYER_CUSTOMERS

func _physics_process(_delta: float) -> void:
	# While dialogue is open or mouse is free — clear hover and exit.
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED \
			or Dialogic.current_timeline != null:
		if is_instance_valid(_last_hovered) and _last_hovered.has_method("on_hover"):
			_last_hovered.on_hover(false)
			_last_hovered = null
		return

	var center    := get_viewport().get_visible_rect().size / 2.0
	var ray_origin := project_ray_origin(center)
	var ray_dir    := project_ray_normal(center)
	var ray_end    := ray_origin + ray_dir * interaction_range

	# --- Raycast 1: items and tray (layer 1) ---
	_q_items.from = ray_origin
	_q_items.to = ray_end
	var hit_item = get_world_3d().direct_space_state.intersect_ray(_q_items)

	# --- Raycast 2: customers only (layer 5) – passes through items/counter ---
	_q_customer.from = ray_origin
	_q_customer.to = ray_end
	var hit_customer = get_world_3d().direct_space_state.intersect_ray(_q_customer)

	# Resolve which target is "closer" to the camera.
	var current_hovered: Node = null
	
	if DragManager._is_dragging:
		# When dragging, completely ignore items so we don't highlight shelves/containers.
		# Only allow hovering over the customer to indicate they can receive the item.
		if hit_customer:
			current_hovered = hit_customer.collider
	else:
		# Items take priority when they are in front of the customer,
		# but if no item is under the crosshair the customer comes through.
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
			print("[PlayerInteraction] Hovering: ", current_hovered.name)
			current_hovered.on_hover(true)
			# If we just hovered something and pricing mode is on, sync the UI state
			if current_hovered.has_method("set_pricing_ui_active"):
				current_hovered.set_pricing_ui_active(pricing_mode_active)
		elif _last_hovered:
			print("[PlayerInteraction] Hover cleared")
		_last_hovered = current_hovered

func _input(event: InputEvent) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	# Block all world interaction while dialogue is open.
	if Dialogic.current_timeline != null:
		return
	
	# Pricing Mode Toggle (Alt)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ALT and not event.echo:
		pricing_mode_active = !pricing_mode_active
		EventBus.pricing_mode_changed.emit(pricing_mode_active)
		print("[PlayerInteraction] Pricing Mode: ", "ON" if pricing_mode_active else "OFF")
		
		# Update currently hovered item immediately
		if is_instance_valid(_last_hovered) and _last_hovered.has_method("set_pricing_ui_active"):
			_last_hovered.set_pricing_ui_active(pricing_mode_active)
		return

	# Pricing Adjustments (Direct Price Mode)
	if pricing_mode_active and is_instance_valid(_last_hovered) and _last_hovered is DraggableItem:
		var delta := 0.0
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				delta = 1.0 # 1 Peso
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				delta = -1.0 # -1 Peso
		elif event is InputEventKey:
			if event.keycode == KEY_PERIOD:
				delta = 1.0
			elif event.keycode == KEY_COMMA:
				delta = -1.0
		
		if delta != 0.0:
			var item: DraggableItem = _last_hovered
			if item.item_data:
				var base_price : float = item.item_data.price
				var current_price : float = item.item_data.get_final_price()
				
				# Range Rules: 
				# 1. Minimum: Base price.
				# 2. Maximum: Progressive margin based on tier. 15% (Tier 1) to 35% (Tier 10).
				var min_price : float = base_price
				var tier : int = item.item_data.tier
				var max_margin : float = 0.15 + (float(max(1, tier)) - 1.0) * (0.20 / 9.0)
				var max_price : float = round(base_price * (1.0 + max_margin))
				
				var new_price : float = clamp(current_price + delta, min_price, max_price)
				
				item.item_data.selling_price = new_price
					
				# Refresh all items of this type (they share the resource)
				get_tree().call_group("draggable_items", "update_pricing_ui")
			get_viewport().set_input_as_handled()
			return

	# Block interaction triggers if we are actively dragging/holding an item
	if DragManager._is_dragging:
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
