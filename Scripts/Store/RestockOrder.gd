class_name RestockOrder
extends RefCounted

## Pure domain model and validation rules for store restock orders.
##
## Manages basket items, calculates effective delivery quantities (including
## unpacking tier upgrade bundles), and validates against capacity limits,
## per-item maximums, shared container caps, and upgrade sequence prerequisites.

signal order_changed

var selected_items: Dictionary = {} # ItemData -> int
var total_price: float = 0.0

func clear() -> void:
	selected_items.clear()
	total_price = 0.0
	order_changed.emit()

func get_items() -> Dictionary:
	return selected_items.duplicate()

func get_actual_items() -> Dictionary:
	var actual: Dictionary = {}
	for item in selected_items:
		if selected_items[item] > 0:
			actual[item] = selected_items[item]
	return actual

func get_item_count(item: ItemData) -> int:
	return selected_items.get(item, 0)

func get_total_cost() -> float:
	return total_price

func is_empty() -> bool:
	for count in selected_items.values():
		if count > 0:
			return false
	return true

## Checks whether [param target_tier] upgrade can be selected based on story progression
## or predecessor upgrades currently in the basket.
func is_upgrade_prerequisite_met(target_tier: int) -> bool:
	if target_tier <= StoryManager.current_tier + 1:
		if target_tier == StoryManager.pending_upgrade_tier:
			return true
		if StoryManager.pending_upgrade_tier == 0 and target_tier == StoryManager.current_tier + 1:
			return true
	
	# Check if immediate predecessor is in basket
	for basket_item in selected_items.keys():
		if basket_item.get_meta("is_upgrade", false):
			var upg_tier: int = basket_item.get_meta("target_tier", 1)
			if upg_tier == target_tier - 1:
				return true
				
	return false

## Validates whether [param item] can be added to the basket.
## Returns a Dictionary with:
## - ok: bool
## - error: String ("" or "insufficient_funds", "limit_reached", "sequence_error", etc.)
## - title: String (notification title, or "" if none)
## - message: String (notification message, or "" if none)
## - sfx: String ("error" or "")
func can_add(item: ItemData, player_money: float) -> Dictionary:
	if not item:
		return {"ok": false, "error": "null_item", "title": "", "message": "", "sfx": ""}

	var is_upgrade: bool = item.get_meta("is_upgrade", false)
	if is_upgrade:
		var target_tier: int = item.get_meta("target_tier", 1)
		for basket_item in selected_items.keys():
			if basket_item.get_meta("is_upgrade", false) and basket_item.get_meta("target_tier", 1) == target_tier:
				return {
					"ok": false,
					"error": "already_in_basket",
					"title": "Already in Basket",
					"message": "You only need one package for Tier %d per order." % target_tier,
					"sfx": "error"
				}
		
		if target_tier > StoryManager.max_unlocked_tier:
			return {
				"ok": false,
				"error": "upgrade_locked",
				"title": "Upgrade Locked",
				"message": "Continue serving customers to unlock this.",
				"sfx": "error"
			}

		if not is_upgrade_prerequisite_met(target_tier):
			return {
				"ok": false,
				"error": "sequence_error",
				"title": "Sequence Error",
				"message": "You must add Tier %d first!" % (target_tier - 1),
				"sfx": "error"
			}

	if selected_items.get(item, 0) >= 99:
		return {
			"ok": false,
			"error": "limit_reached",
			"title": "Limit Reached",
			"message": "Order limit for this item reached.",
			"sfx": "error"
		}

	if total_price + item.price > player_money:
		return {
			"ok": false,
			"error": "insufficient_funds",
			"title": "",
			"message": "",
			"sfx": ""
		}

	# Simulate the basket after addition and compute effective counts
	var proposed_basket := selected_items.duplicate()
	proposed_basket[item] = proposed_basket.get(item, 0) + 1
	
	var effective_counts := get_effective_counts(proposed_basket)
	var effective_types := get_effective_types(proposed_basket)

	# Validate individual max stock limits
	for eff_item in effective_counts.keys():
		if effective_counts[eff_item] > InventoryManager.get_max_stock(eff_item):
			return {
				"ok": false,
				"error": "stock_limit_reached",
				"title": "Stock Limit Reached!",
				"message": "Not enough space for " + eff_item.item_name,
				"sfx": "error"
			}

	# Shared candy container limit (Mentor + Pocha) pre-Tier 10
	if StoryManager.current_tier < 10:
		var bowl_sum: int = 0
		for eff_item in effective_counts.keys():
			var id: String = eff_item.get_clean_id()
			if id == "mentor" or id == "pocha":
				bowl_sum += (effective_counts[eff_item] + InventoryManager.get_stock(eff_item))
		if bowl_sum > 10:
			return {
				"ok": false,
				"error": "bowl_full",
				"title": "Bowl is full!",
				"message": "Mentor + Pocha cannot exceed 10 total.",
				"sfx": "error"
			}

	# Physical surface capacity limits
	for eff_type in effective_types.keys():
		if effective_types[eff_type] > InventoryManager.get_available_capacity(eff_type):
			return {
				"ok": false,
				"error": "capacity_full",
				"title": "Shelf is full!",
				"message": "Not enough physical space.",
				"sfx": "error"
			}

	return {"ok": true, "error": "", "title": "", "message": "", "sfx": ""}

## Adds [param item] to the basket and increments [member total_price].
func add_item(item: ItemData) -> void:
	if not item:
		return
	selected_items[item] = selected_items.get(item, 0) + 1
	total_price += item.price
	order_changed.emit()

## Decrements or removes [param item] from the basket.
## For upgrade items, cascades removal to all dependent higher-tier upgrades in the basket.
## Returns a Dictionary with:
## - is_upgrade: bool
## - new_count: int
## - removed: bool
## - cascaded: Array[ItemData]
func remove_item(item: ItemData) -> Dictionary:
	var count: int = selected_items.get(item, 0)
	if count <= 0:
		return {"is_upgrade": false, "new_count": 0, "removed": false, "cascaded": []}

	var is_upgrade: bool = item.get_meta("is_upgrade", false)
	var new_count: int = count - 1

	if is_upgrade or new_count <= 0:
		var cascaded: Array[ItemData] = []
		if is_upgrade:
			var removed_tier: int = item.get_meta("target_tier", 1)
			for basket_item in selected_items.keys():
				if basket_item.get_meta("is_upgrade", false):
					var upg_tier: int = basket_item.get_meta("target_tier", 1)
					if upg_tier > removed_tier:
						cascaded.append(basket_item)
			
			for rip in cascaded:
				total_price -= rip.price
				selected_items.erase(rip)
		
		total_price -= item.price
		selected_items.erase(item)
		order_changed.emit()
		return {"is_upgrade": is_upgrade, "new_count": 0, "removed": true, "cascaded": cascaded}

	selected_items[item] = new_count
	total_price -= item.price
	order_changed.emit()
	return {"is_upgrade": false, "new_count": new_count, "removed": false, "cascaded": []}

## Computes the effective item quantities for the given basket (or current basket if omitted),
## unpacking tier upgrade bundles into individual sellable products.
func get_effective_counts(basket: Dictionary = selected_items) -> Dictionary:
	var counts: Dictionary = {}
	for k in basket.keys():
		var count: int = basket[k]
		if k.get_meta("is_upgrade", false):
			var upg_tier: int = k.get_meta("target_tier", 1)
			for i in InventoryManager.get_all_items():
				if i.tier == upg_tier and i.can_be_sold:
					counts[i] = counts.get(i, 0) + (count * 2)
		else:
			counts[k] = counts.get(k, 0) + count
	return counts

## Computes the effective item type quantities (SHELF vs FRIDGE) for the given basket.
func get_effective_types(basket: Dictionary = selected_items) -> Dictionary:
	var types: Dictionary = {}
	for k in basket.keys():
		var count: int = basket[k]
		if k.get_meta("is_upgrade", false):
			var upg_tier: int = k.get_meta("target_tier", 1)
			for i in InventoryManager.get_all_items():
				if i.tier == upg_tier and i.can_be_sold:
					types[i.type] = types.get(i.type, 0) + (count * 2)
		else:
			types[k.type] = types.get(k.type, 0) + count
	return types

