class_name CandyContainerItem
extends DispenserContainerItem

## An interactable candy bowl that spawns a random [DraggableItem] when clicked.
##
## On interact, picks a random in-stock candy from [member possible_candies],
## deducts one unit from [InventoryManager], and hands it off to [DragManager]
## as a transient item ready to drag to the transaction tray.

@export var possible_candies: Array[ItemData] = []

func adjust_price(delta: float) -> bool:
	if possible_candies.is_empty():
		return false
	InventoryManager.adjust_item_price(possible_candies, delta)
	return true

func get_available_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	if current_stock > 0:
		for candy in possible_candies:
			if candy and InventoryManager.is_in_stock(candy):
				if not items.has(candy):
					items.append(candy)
	return items

func update_pricing_ui() -> void:
	if possible_candies.is_empty() or not is_hovered or not _pricing_mode_active:
		return
	var ref_item = possible_candies[0]
	if is_instance_valid(PricingOverlay):
		var stock_info = "Stock: %d / %d" % [current_stock, max_stock]
		PricingOverlay.show_item(ref_item, global_position, true, "Candies", stock_info)

func _check_unlock_status() -> void:
	var tier = StoryManager.current_tier
	var within_range = false
	
	if min_unlock_tier > 0:
		within_range = (tier >= min_unlock_tier)
	elif not possible_candies.is_empty():
		var min_candy_tier = 999
		for candy in possible_candies:
			if candy.tier < min_candy_tier:
				min_candy_tier = candy.tier
		within_range = (tier >= min_candy_tier)
		
	if disable_at_tier >= 0 and tier >= disable_at_tier:
		within_range = false
		
	_is_unlocked = within_range
	visible = _is_unlocked
	process_mode = Node.PROCESS_MODE_INHERIT if _is_unlocked else Node.PROCESS_MODE_DISABLED

func on_interact() -> void:
	if not _is_unlocked or DragManager.is_dragging:
		return
	
	_update_local_stock()

	# Build a proportional weighted pool based on current stock levels.
	var pool: Array[ItemData] = []
	for candy in possible_candies:
		var s = InventoryManager.get_stock(candy)
		for i in range(s):
			pool.append(candy)

	if pool.is_empty():
		_play_error_animation()
		return

	var chosen_candy: ItemData = pool.pick_random()
	if InventoryManager.take_item(chosen_candy):
		_spawn_and_drag_item(chosen_candy)

func _update_local_stock() -> void:
	current_stock = 0
	for candy in possible_candies:
		current_stock += InventoryManager.get_stock(candy)
	
	# The capacity for these candy containers is capped at 10 total.
	max_stock = 10
	
	if is_instance_valid(PricingOverlay) and is_hovered and _pricing_mode_active:
		update_pricing_ui()

func _on_inventory_stock_changed(item: ItemData, _new_stock: int) -> void:
	if item in possible_candies:
		_update_local_stock()
