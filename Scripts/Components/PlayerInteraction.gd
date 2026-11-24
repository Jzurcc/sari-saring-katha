extends Camera3D
class_name PlayerInteraction

## Component attached to the camera or player head to handle 3D raycast interactions.
## Uses the typed WorldInteractor interface for hover, pricing, and click interactions.

## Collision layers used in raycast queries.
const LAYER_ITEMS: int = 1   ## DraggableItems, containers, props, transaction tray – bit 0
const LAYER_CUSTOMERS: int = 16 ## Customers only – bit 4 (layer 5).
## Using a separate layer means the customer raycast passes clean through the
## counter and any items sitting on it, so the player can always look at a
## customer even when aim is partially blocked by the tray.

@export var interaction_range: float = 10.0

var pricing_mode_active: bool = false

var _q_items: PhysicsRayQueryParameters3D
var _q_customer: PhysicsRayQueryParameters3D
var _last_hovered: WorldInteractor = null

# Cached node references
var _game_manager: GameManager = null

# Scroll sensitivity accumulator (1 scroll notch = 1 discrete price step)
var _scroll_event_count: int = 0
const SCROLL_THRESHOLD: int = 1
var _was_lmb_pressed: bool = false
var _was_dragging: bool = false
var _last_fridge_toggle_ms: int = -1000

func _ready() -> void:
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

	EventBus.drag_ended.connect(_on_drag_ended)

func _on_drag_ended(_item: DraggableItem, _dropped_successfully: bool) -> void:
	# Force fresh hover + pricing lens evaluation on the next frame after dropping an item
	if is_instance_valid(_last_hovered):
		_last_hovered.on_hover(false)
		_last_hovered.set_pricing_ui_active(false)
	_last_hovered = null
	_was_dragging = false
	EventBus.customer_hover_changed.emit(null, false)

	call_deferred("_cache_node_refs")

func _cache_node_refs() -> void:
	_game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager

func _resolve_interactor(node: Node) -> WorldInteractor:
	if not is_instance_valid(node):
		return null
	if node is WorldInteractor:
		return node as WorldInteractor
	var parent := node.get_parent()
	if is_instance_valid(parent) and parent is WorldInteractor:
		return parent as WorldInteractor
	return null

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_game_manager):
		_game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager

	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		if is_instance_valid(_last_hovered):
			_last_hovered.on_hover(false)
			_last_hovered = null
			EventBus.customer_hover_changed.emit(null, false)
		_was_dragging = DragManager.is_dragging
		return

	var center := get_viewport().get_visible_rect().size / 2.0
	var ray_origin := project_ray_origin(center)
	var ray_dir := project_ray_normal(center)
	var ray_end := ray_origin + ray_dir * interaction_range

	# --- Raycast 1: items and tray (layer 1) ---
	_q_items.from = ray_origin
	_q_items.to = ray_end
	var hit_item = get_world_3d().direct_space_state.intersect_ray(_q_items)

	# --- Raycast 2: customers only (layer 5) – passes through items/counter ---
	_q_customer.from = ray_origin
	_q_customer.to = ray_end
	var hit_customer = get_world_3d().direct_space_state.intersect_ray(_q_customer)

	var current_hovered: WorldInteractor = null

	if DragManager.is_dragging:
		# When dragging, highlight valid drop targets:
		# customer, trash bin, blinking container placement slot, or a matching placed dispenser for refills.
		var dragged_data: ItemData = DragManager.get_dragged_item_data()
		if hit_item and hit_item.collider.is_in_group("container_drop_slot"):
			current_hovered = _resolve_interactor(hit_item.collider)
		elif hit_item and hit_item.collider.is_in_group("fridge_door"):
			current_hovered = _resolve_interactor(hit_item.collider)
		elif hit_item and hit_item.collider.is_in_group("dispenser_containers") and hit_item.collider.has_method("accepts_refill") and hit_item.collider.accepts_refill(dragged_data):
			current_hovered = _resolve_interactor(hit_item.collider)
		elif hit_customer and not DispenserContainerItem.is_container_prop(dragged_data):
			current_hovered = _resolve_interactor(hit_customer.collider)
		elif hit_item and hit_item.collider.is_in_group("trash") and not DispenserContainerItem.is_container_prop(dragged_data):
			current_hovered = _resolve_interactor(hit_item.collider)
	else:
		# Items take priority when they are in front of the customer,
		# but if no item is under the crosshair the customer comes through.
		if hit_item and hit_customer:
			current_hovered = _resolve_interactor(hit_item.collider)
		elif hit_item:
			current_hovered = _resolve_interactor(hit_item.collider)
		elif hit_customer:
			current_hovered = _resolve_interactor(hit_customer.collider)

	# Update hover state only on change to avoid redundant calls every frame.
	if current_hovered != _last_hovered:
		if is_instance_valid(_last_hovered):
			_last_hovered.on_hover(false)
			_last_hovered.set_pricing_ui_active(false)
		if is_instance_valid(current_hovered):
			if current_hovered is Customer:
				(current_hovered as Customer).set_drag_hover(DragManager.is_dragging)
			current_hovered.set_pricing_ui_active(pricing_mode_active)
			current_hovered.on_hover(true)
		_last_hovered = current_hovered
	elif current_hovered is Customer and DragManager.is_dragging != _was_dragging:
		var hovered_cust := current_hovered as Customer
		hovered_cust.set_drag_hover(DragManager.is_dragging)
		EventBus.customer_hover_changed.emit(hovered_cust, DragManager.is_dragging)

	_was_dragging = DragManager.is_dragging

	# Allow opening/closing the refrigerator door during active (unpaused) dialogue even if Dialogic's layout consumes MOUSE_BUTTON_LEFT
	var lmb_now := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if lmb_now and not _was_lmb_pressed and Dialogic.current_timeline != null and not Dialogic.paused:
		if is_instance_valid(_last_hovered) and _last_hovered.is_in_group("fridge_door"):
			_try_interact_fridge_door(_last_hovered)
	_was_lmb_pressed = lmb_now

func _try_interact_fridge_door(target: WorldInteractor) -> void:
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_fridge_toggle_ms < 150:
		return
	_last_fridge_toggle_ms = now_ms
	target.on_interact()

func _input(event: InputEvent) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	# Block world interaction triggers while dialogue is open,
	# unless permitted by the active guided interaction / tutorial state.
	if not is_instance_valid(_game_manager):
		_game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	var gm := _game_manager
	var allow_interaction: bool = gm.tutorial.can_interact_with_world() if (gm and gm.tutorial) else (Dialogic.current_timeline == null)
	if not allow_interaction:
		# Allow opening/closing the refrigerator door even while dialogue is active
		if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed \
			and is_instance_valid(_last_hovered) \
			and _last_hovered.is_in_group("fridge_door"):
			get_viewport().set_input_as_handled()
			_try_interact_fridge_door(_last_hovered)
		return

	# Pricing Mode Toggle (Alt) - Always allowed regardless of dialogue
	if event.is_action_pressed("pricing_lens") and not event.echo:
		pricing_mode_active = !pricing_mode_active
		EventBus.pricing_mode_changed.emit(pricing_mode_active)
		LogManager.info("PlayerInteraction", "Pricing Mode: %s" % ("ON" if pricing_mode_active else "OFF"))

		if is_instance_valid(_last_hovered):
			_last_hovered.set_pricing_ui_active(pricing_mode_active)
		return

	# Price Ledger Toggle (L)
	var is_ledger_press := false
	if event.is_action_pressed("toggle_ledger") and not event.echo:
		is_ledger_press = true
	elif event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_L or event.keycode == KEY_L):
		is_ledger_press = true

	if is_ledger_press and allow_interaction:
		EventBus.price_ledger_toggled.emit(true)
		get_viewport().set_input_as_handled()
		return

	# Calendar & Events Menu Toggle (C)
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_C or event.keycode == KEY_C):
		if allow_interaction:
			EventBus.events_overlay_toggled.emit(true)
			get_viewport().set_input_as_handled()
			return

	# Pricing Adjustments (Direct Price Mode)
	if pricing_mode_active and is_instance_valid(_last_hovered):
		var delta := 0.0
		if event.is_action_pressed("price_up"):
			delta = 1.0
		elif event.is_action_pressed("price_down"):
			delta = -1.0

		if delta != 0.0:
			var trigger_adj := false
			if event is InputEventMouseButton:
				_scroll_event_count += 1
				if _scroll_event_count >= SCROLL_THRESHOLD:
					trigger_adj = true
					_scroll_event_count = 0
			else:
				trigger_adj = true
				_scroll_event_count = 0

			if trigger_adj and _last_hovered.can_adjust_price():
				EventBus.request_sfx.emit("price_change")
				_last_hovered.adjust_price(delta)
				get_viewport().set_input_as_handled()
				return

	# Block interaction triggers if we are actively dragging/holding an item
	if DragManager.is_dragging:
		if event is InputEventMouseButton and event.pressed:
			LogManager.debug("PlayerInteraction", "Click ignored: Already dragging.")
		return

	# Left-Click Interaction
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_instance_valid(_last_hovered):
			if _last_hovered.can_pickup():
				if gm and gm.tutorial and not gm.tutorial.can_pickup_item():
					return
				get_viewport().set_input_as_handled()
				_pickup_item(_last_hovered as DraggableItem)
			else:
				get_viewport().set_input_as_handled()
				if _last_hovered.is_in_group("fridge_door"):
					_try_interact_fridge_door(_last_hovered)
				else:
					_last_hovered.on_interact()
		else:
			LogManager.debug("PlayerInteraction", "Left click, but _last_hovered is null/invalid")

func _pickup_item(item: DraggableItem) -> void:
	if item and item.sprite and item.sprite.texture:
		DragManager.start_drag(item, item.sprite.texture)
