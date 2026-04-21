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
var _q_gaze: PhysicsRayQueryParameters3D
var _last_hovered: Node = null

# Tutorial Gaze Tracking
var active_gaze_target_id: String = ""
var active_gaze_group: String = ""
var _gaze_timer: float = 0.0

# Scroll sensitivity accumulator (taking more scroll notches per 0.50 increment)
var _scroll_event_count: int = 0
const SCROLL_THRESHOLD: int = 3

func _ready() -> void:
	# Ensure interaction_range is valid
	if interaction_range <= 0.0:
		interaction_range = 10.0
			
	_q_items = PhysicsRayQueryParameters3D.new()
	_q_items.collide_with_areas = true
	_q_items.collide_with_bodies = false
	_q_items.collision_mask = LAYER_ITEMS # Layer 1 only again
	
	_q_gaze = PhysicsRayQueryParameters3D.new()
	_q_gaze.collide_with_areas = true
	_q_gaze.collide_with_bodies = true
	# Gaze targets can be Layer 1 (Items) or Layer 2 (Drop Zones/Surfaces)
	_q_gaze.collision_mask = LAYER_ITEMS | 2

	_q_customer = PhysicsRayQueryParameters3D.new()
	_q_customer.collide_with_areas = true
	_q_customer.collide_with_bodies = false
	_q_customer.collision_mask = LAYER_CUSTOMERS

func _physics_process(_delta: float) -> void:
	# While dialogue is open, we still allow raycasting if the mouse is captured
	# (so players can see the pricing UI/hover outlines).
	# However, we block it if the mouse is free (mouse mode != captured).
	var is_in_timeline = Dialogic.current_timeline != null
	var gm = get_tree().get_first_node_in_group("game_manager")
	var is_tutorial_task = gm and gm.is_tutorial_task_active
	var is_mario_tutorial = is_in_timeline and _is_mario_tutorial_active()

	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
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

	# --- Raycast 3: tutorial gaze only (layer 1 | 2) ---
	var hit_gaze = {}

	# Resolve which target is "closer" to the camera.
	var current_hovered: Node = null
	
	if DragManager._is_dragging:
		# When dragging, completely ignore items so we don't highlight shelves/containers.
		# Only allow hovering over the customer to indicate they can receive the item,
		# or the trash bin for deletion.
		if hit_customer:
			current_hovered = hit_customer.collider
		elif hit_item and hit_item.collider.is_in_group("trash"):
			current_hovered = hit_item.collider
	else:
		# Items take priority when they are in front of the customer,
		# but if no item is under the crosshair the customer comes through.
		if hit_item and hit_customer:
			# Items and containers take hard priority over customers.
			# This ensures smaller interactables on the counter remain reachable
			# even if a customer's large collision box overlaps them.
			current_hovered = hit_item.collider
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
			# If we just hovered something and pricing mode is on, sync the UI state
			if current_hovered.has_method("set_pricing_ui_active"):
				current_hovered.set_pricing_ui_active(pricing_mode_active)
		_last_hovered = current_hovered

	# --- Removed Tutorial Gaze Detection ---
	# The gaze tutorial is now simply a 2-second automated wait from GameManager.

func _is_in_group_recursive(node: Node, group_name: String, max_depth: int) -> bool:
	if not node or max_depth < 0:
		return false
	if node.is_in_group(group_name):
		return true
		
	# Fallback for environment collision shapes in the final store scene
	# This allows looking at physical models that might not have the specific groups applied.
	var lower_name = node.name.to_lower()
	match group_name:
		"shelf_surface":
			if "shelf" in lower_name: return true
		"fridge_surfaces":
			if "fridge" in lower_name or "cube_001" in lower_name or "refrigerator" in lower_name: return true
		"nokia_phone":
			if "nokia" in lower_name or "phone" in lower_name: return true
		"notebook_item":
			if "notebook" in lower_name: return true
			
	return _is_in_group_recursive(node.get_parent(), group_name, max_depth - 1)


func setup_gaze_task(target_id: String, group_name: String) -> void:
	active_gaze_target_id = target_id
	active_gaze_group = group_name
	_gaze_timer = 0.0
	print("[PlayerInteraction] Setup gaze task: ", target_id, " (group: ", group_name, ")")


func clear_gaze_task() -> void:
	active_gaze_target_id = ""
	active_gaze_group = ""
	_gaze_timer = 0.0

func _input(event: InputEvent) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	# Block world interaction triggers while dialogue is open,
	# unless we are currently in the tutorial or a tutorial task.
	var is_in_timeline = Dialogic.current_timeline != null
	var gm = get_tree().get_first_node_in_group("game_manager")
	var is_tutorial_task = gm and gm.is_tutorial_task_active
	var is_mario_tutorial = is_in_timeline and _is_mario_tutorial_active()
	
	# Detect if Dialogic UI is actually visible
	var is_dialogue_ui_visible = false
	var layout = Dialogic.Styles.get_layout_node()
	if is_instance_valid(layout) and layout.visible:
		is_dialogue_ui_visible = true
	
	# NEW: Interaction rules - Fully permissive for Mario tutorial as requested
	var allow_interaction = false
	if not is_in_timeline or not is_dialogue_ui_visible:
		allow_interaction = true
	elif is_tutorial_task or is_mario_tutorial:
		allow_interaction = true
	
	if not allow_interaction:
		return
	
	if event is InputEventMouseButton and event.pressed:
		pass
	
	# Pricing Mode Toggle (Alt) - Always allowed regardless of dialogue
	if event.is_action_pressed("pricing_lens") and not event.echo:
		pricing_mode_active = !pricing_mode_active
		EventBus.pricing_mode_changed.emit(pricing_mode_active)
		print("[PlayerInteraction] Pricing Mode: ", "ON" if pricing_mode_active else "OFF")
		
		# Update currently hovered item immediately
		if is_instance_valid(_last_hovered) and _last_hovered.has_method("set_pricing_ui_active"):
			_last_hovered.set_pricing_ui_active(pricing_mode_active)
		return

	if not allow_interaction:
		return

	# Pricing Adjustments (Direct Price Mode)
	if pricing_mode_active and is_instance_valid(_last_hovered):
		var delta := 0.0
		if event.is_action_pressed("price_up"):
			delta = 0.5 # 0.5 Peso
		elif event.is_action_pressed("price_down"):
			delta = -0.5 # -0.5 Peso
		
		if delta != 0.0:
			var trigger_adj = false
			
			if event is InputEventMouseButton:
				_scroll_event_count += 1
				if _scroll_event_count >= SCROLL_THRESHOLD:
					trigger_adj = true
					_scroll_event_count = 0
			else:
				# Keyboard adjustments (, and .) trigger immediately
				trigger_adj = true
				_scroll_event_count = 0
				
			if trigger_adj:
				EventBus.request_sfx.emit("price_change")
				if _last_hovered.has_method("adjust_price"):
					_last_hovered.adjust_price(delta)
					get_viewport().set_input_as_handled()
					return
				
				# Check parent if it's an Area3D (standard for our items)
				var target = _last_hovered
				if target is Area3D:
					var p = target.get_parent()
					if p and (p.has_method("adjust_price") or p.is_in_group("draggable_items")):
						target = p
				
				if target.has_method("adjust_price"):
					target.adjust_price(delta)
					get_viewport().set_input_as_handled()
					return
				
				if target.is_in_group("draggable_items"):
					var item = target
					if item.item_data:
						# ... (logic remains same)
						var base_price : float = item.item_data.price
						var current_price : float = item.item_data.get_final_price()
						var min_price : float = base_price
						var max_price : float = item.item_data.get_max_selling_price()
						var new_price : float = clamp(current_price + delta, min_price, max_price)
						
						if new_price > current_price:
							EventBus.price_increased.emit(item.item_data)
						item.item_data.selling_price = new_price
						get_tree().call_group("draggable_items", "update_pricing_ui")
						get_tree().call_group("pricing_ui_containers", "update_pricing_ui")
					get_viewport().set_input_as_handled()
					return
		else:
			pass

	# Block interaction triggers if we are actively dragging/holding an item
	if DragManager._is_dragging:
		if event is InputEventMouseButton and event.pressed:
			print("[PI-DEBUG] Click ignored: Already dragging.")
		return

	if event is InputEventMouseButton and event.pressed:
		pass

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var target = _last_hovered
		if is_instance_valid(target):
			# Check parent if direct collision didn't have the methods
			if not target.has_method("on_interact") and not target.is_in_group("draggable_items"):
				var p = target.get_parent()
				if p and (p.has_method("on_interact") or p.is_in_group("draggable_items")):
					target = p
					# print("[PI-DEBUG] Switching target to parent: ", target.name)
					pass
					
			if target.has_method("on_interact"):
				get_viewport().set_input_as_handled()
				target.on_interact()
			elif target.is_in_group("draggable_items"):
				if gm and gm.is_blocking_pickup:
					return
				get_viewport().set_input_as_handled()
				_pickup_item(target)
			else:
				print("[PI-DEBUG] Left click on valid hovered object, but no interact/drag method: ", target.name, " (Original: ", _last_hovered.name, ")")
		else:
			print("[PI-DEBUG] Left click, but _last_hovered is null/invalid")

## Returns true if the currently active Dialogic timeline is the Uncle Mario tutorial.
## Safe to call even when current_timeline is a String (Dialogic sometimes stores it that way).
func _is_mario_tutorial_active() -> bool:
	var tl = Dialogic.current_timeline
	if tl == null:
		return false
	var res = false
	if typeof(tl) == TYPE_STRING:
		res = tl.to_lower().contains("unclemario")
	elif "resource_path" in tl:
		res = tl.resource_path.to_lower().contains("unclemario")
	
	return res

func _pickup_item(item: DraggableItem) -> void:
	DragManager.start_drag(item, item.sprite.texture)
