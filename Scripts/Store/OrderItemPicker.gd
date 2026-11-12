class_name OrderItemPicker
extends RefCounted

## Stateless item-selection rules for customer orders.
## Every function takes the player's current tier explicitly so callers never
## have to share mutable state with this module.


## Chance that a tier-gated item is drawn from the shelves rather than the full catalogue.
const NEXT_TIER_WEIGHT := 0.5
const BEST_IN_CATEGORY_BASE_WEIGHT := 1.0
const BEST_IN_CATEGORY_TIER_BONUS := 0.1
const OLDER_TIER_DECAY := 0.25
const OLDER_TIER_FLOOR_WEIGHT := 0.2


static func is_unlocked(item: ItemData, current_tier: int) -> bool:
	return item.tier <= current_tier


## Maps designer-facing category aliases ("drinks", "noodles"...) to item.category values.
## Falls back to treating `cat` as an item name, then as a literal category.
static func mapped_categories(cat: String) -> Array[String]:
	var c := cat.to_lower()
	match c:
		"bottle", "drinks", "beverage": return ["bottle"]
		"cigarette", "cigars", "cigarettes": return ["cigarette"]
		"candy", "candies": return ["candy"]
		"snack", "snacks": return ["snack"]
		"sachet", "sachets": return ["sachet"]
		"pack", "packs", "noodles": return ["pack"]
		"frozen": return ["frozen"]
		"can", "cans", "cannedgoods": return ["can"]

	for item in InventoryManager.get_all_items():
		if item.item_name.to_lower() == c:
			return [item.category]

	return [c]


## Highest unlocked tier of every sellable item category.
static func max_tier_per_category(current_tier: int) -> Dictionary:
	var max_tiers := {}
	for item in InventoryManager.get_all_items():
		if item.tier <= current_tier and item.can_be_sold:
			var cat := item.category
			if not max_tiers.has(cat) or item.tier > max_tiers[cat]:
				max_tiers[cat] = item.tier
	return max_tiers


## Weighted draw from `pool`:
## 1. Next-tier items (tier > current): fixed teaser weight.
## 2. Best-in-category: 1.0 plus a small bonus for higher tiers.
## 3. Older items: linear decay per tier gap, floored.
static func pick_weighted(pool: Array[ItemData], current_tier: int, max_tiers_by_cat: Dictionary) -> ItemData:
	if pool.is_empty():
		return null

	var total_weight := 0.0
	var weights: Array[float] = []

	for item in pool:
		var weight: float
		if item.tier > current_tier:
			weight = NEXT_TIER_WEIGHT
		else:
			var gap: int = max_tiers_by_cat.get(item.category, item.tier) - item.tier
			if gap <= 0:
				weight = BEST_IN_CATEGORY_BASE_WEIGHT + float(item.tier) * BEST_IN_CATEGORY_TIER_BONUS
			else:
				weight = max(OLDER_TIER_FLOOR_WEIGHT, 1.0 - float(gap) * OLDER_TIER_DECAY)
		if is_instance_valid(StoreEventManager):
			weight *= StoreEventManager.get_item_demand_multiplier(item)
		weights.append(weight)
		total_weight += weight

	var roll := randf() * total_weight
	var cursor := 0.0
	for i in range(pool.size()):
		cursor += weights[i]
		if roll <= cursor:
			return pool[i]

	return pool.pick_random()


## Best sellable item (up to next tier) in the category of `cat`.
## Returns `current_item` untouched if it is already at the peak tier.
static func best_for_category(cat: String, current_tier: int, current_item: ItemData = null) -> ItemData:
	var categories := mapped_categories(cat)
	var max_tier := -1
	for item in InventoryManager.get_all_items():
		if item.category in categories and item.tier <= current_tier + 1 and item.can_be_sold:
			max_tier = maxi(max_tier, item.tier)

	if max_tier == -1:
		return null

	if current_item and current_item.tier == max_tier and current_item.category in categories:
		return current_item

	var pool: Array[ItemData] = []
	for item in InventoryManager.get_all_items():
		if item.category in categories and item.tier == max_tier and item.can_be_sold:
			pool.append(item)

	return pool.pick_random()


## Any sellable item (up to next tier) in the category, weighted; falls back to any orderable item.
static func any_for_category(cat: String, current_tier: int, prefer_hint: bool = false) -> ItemData:
	var categories := mapped_categories(cat)
	var pool: Array[ItemData] = []
	for item in InventoryManager.get_all_items():
		if item.category in categories and item.tier <= current_tier + 1 and item.can_be_sold:
			pool.append(item)

	if prefer_hint:
		var hint_pool: Array[ItemData] = pool.filter(func(i): return i.item_hint != "")
		if not hint_pool.is_empty():
			pool = hint_pool

	var item := pick_weighted(pool, current_tier, max_tier_per_category(current_tier))
	if not item:
		LogManager.warn("OrderItemPicker", "Category Search FAILURE: '%s'. Attempting global fallback." % cat)
		item = random_orderable(current_tier)
	return item


## Random unlocked sellable item. Falls back to any sellable item so dialogue never
## gets an empty "something" request.
static func random_orderable(current_tier: int) -> ItemData:
	var all_unlocked: Array[ItemData] = []
	var absolute_fallback: Array[ItemData] = []

	for item in InventoryManager.get_all_items():
		if item.can_be_sold:
			absolute_fallback.append(item)
			if is_unlocked(item, current_tier):
				all_unlocked.append(item)

	if not all_unlocked.is_empty():
		return all_unlocked.pick_random()

	if not absolute_fallback.is_empty():
		push_warning("[OrderItemPicker] No Tier %d items unlocked. Falling back to absolute random item pool." % current_tier)
		return absolute_fallback.pick_random()

	push_warning("[OrderItemPicker] No sellable items available at all for fallback filler.")
	return null


## How many items a purchase order contains.
## T1-2: 40/30/30, T3-6: 30/40/30, T7+: 10/40/50 for 1/2/3 items.
static func item_count_for_tier(current_tier: int) -> int:
	var roll := randf() * 100.0
	var one_up_to := 40.0
	var two_up_to := 70.0
	if current_tier > 6:
		one_up_to = 10.0
		two_up_to = 50.0
	elif current_tier > 2:
		one_up_to = 30.0

	if roll < one_up_to:
		return 1
	if roll < two_up_to:
		return 2
	return 3


## Case-insensitive item lookup by name (exact -> starts-with -> contains).
static func find_by_name(item_name: String) -> ItemData:
	var search := item_name.to_lower()
	var starts_match: ItemData = null
	var contains_match: ItemData = null
	for item in InventoryManager.get_all_items():
		var n := item.item_name.to_lower()
		if n == search:
			return item
		if starts_match == null and n.begins_with(search):
			starts_match = item
		elif contains_match == null and n.contains(search):
			contains_match = item
	return starts_match if starts_match else contains_match


