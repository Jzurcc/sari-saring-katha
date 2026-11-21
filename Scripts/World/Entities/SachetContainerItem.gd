class_name SachetContainerItem
extends DispenserContainerItem

## An interactable sachet strip/hanger that dispenses a [DraggableItem] on click.
##
## Unlike [CandyContainerItem], this is dedicated to a single [ItemData] sachet type.

@export var sachet_item: ItemData

func adjust_price(delta: float) -> bool:
	if not sachet_item:
		return false
	InventoryManager.adjust_item_price([sachet_item], delta)
	return true

func get_available_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	if sachet_item and current_stock > 0:
		items.append(sachet_item)
	return items

func _has_uninspected_items() -> bool:
	return sachet_item != null and not InventoryManager.is_item_inspected(sachet_item)

func update_pricing_ui() -> void:
	if not sachet_item or not is_hovered or not _pricing_mode_active:
		return
	InventoryManager.mark_item_inspected(sachet_item)
	if is_instance_valid(PricingOverlay):
		var stock_info = "Stock: %d / %d" % [current_stock, max_stock]
		PricingOverlay.show_item(sachet_item, global_position, true, "", stock_info)

func _check_unlock_status() -> void:
	var tier = StoryManager.current_tier
	var within_range = false
	
	if min_unlock_tier > 0:
		within_range = tier >= min_unlock_tier
	elif sachet_item:
		within_range = sachet_item.tier <= tier
	
	if disable_at_tier >= 0 and tier >= disable_at_tier:
		within_range = false
		
	_is_unlocked = within_range
	_apply_visibility_state()

func accepts_refill(item: ItemData) -> bool:
	return is_placed_and_active() and item != null and sachet_item != null and (item == sachet_item or (item.resource_path != "" and item.resource_path == sachet_item.resource_path))

func on_interact() -> void:
	if not is_placed_and_active() or DragManager.is_dragging:
		return
	
	_update_local_stock()

	if not sachet_item:
		push_warning("[SachetContainerItem] No sachet_item assigned to %s" % name)
		return

	if InventoryManager.get_stock(sachet_item) <= 0:
		_play_error_animation()
		return

	if InventoryManager.take_item(sachet_item):
		_spawn_and_drag_item(sachet_item)

func _update_local_stock() -> void:
	if sachet_item:
		current_stock = InventoryManager.get_stock(sachet_item)
		max_stock = InventoryManager.get_max_stock(sachet_item)
	
	if is_instance_valid(PricingOverlay) and is_hovered and _pricing_mode_active:
		update_pricing_ui()

func _on_inventory_stock_changed(item: ItemData, _new_stock: int) -> void:
	if item == sachet_item:
		_update_local_stock()
