extends Node

## Tracks item stock counts across the game.
## Key: ItemData.resource_path → Value: current stock count.

## Exposed for Dialogic timelines — set before calling Dialogic.start().
## Reference in .dtl files as: {InventoryManager.current_item_name}
var current_item_name: String = ""
## The display name of the current customer. Use as {InventoryManager.current_character_name} in .dtl files.
var current_character_name: String = ""

## Number of customers that must be served before Uncle Mario can restock again.
var customers_needed_for_delivery: int = 0

var _initialized: bool = false

var _stock: Dictionary = {}
var _items: Array[ItemData] = []

func _ready() -> void:
	initialize()

## Load all ItemData resources from subfolders and set initial stock.
func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	_items.clear()
	_stock.clear()
	var base_path: String = "res://Resources/items"
	var base_dir: DirAccess = DirAccess.open(base_path)
	if not base_dir:
		push_error("InventoryManager: cannot open " + base_path)
		return
	base_dir.list_dir_begin()
	var subdir: String = base_dir.get_next()
	while subdir != "":
		if base_dir.current_is_dir() and subdir != "." and subdir != "..":
			_load_folder(base_path + "/" + subdir)
		subdir = base_dir.get_next()
	base_dir.list_dir_end()
	
	load_state()
	
	# Sort items alphabetically for deterministic display order across platforms.
	_items.sort_custom(func(a: ItemData, b: ItemData): return a.item_name.naturalnocasecmp_to(b.item_name) < 0)
	print("[InventoryManager] Loaded ", _items.size(), " items")

func _load_folder(folder_path: String) -> void:
	var dir: DirAccess = DirAccess.open(folder_path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res: Resource = load(folder_path + "/" + file_name)
			if res is ItemData:
				_items.append(res)
				# Initial stock is now 0 by default; items must be ordered or delivered.
				_stock[res.resource_path] = 0
		file_name = dir.get_next()
	dir.list_dir_end()

## Get all loaded items.
func get_all_items() -> Array[ItemData]:
	return _items

## Get items filtered by type (SHELF or FRIDGE).
func get_items_by_type(type: ItemData.ItemType) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in _items:
		if item.type == type:
			result.append(item)
	return result

## Get current stock of an item.
func get_stock(item: ItemData) -> int:
	return _stock.get(item.resource_path, 0)

## Returns true if item has stock > 0.
func is_in_stock(item: ItemData) -> bool:
	return get_stock(item) > 0

## Returns the dynamic max stock for a specific item based on unlocked containers/day.
func get_max_stock(item: ItemData) -> int:
	var id: String = item.get_clean_id()
	var tier: int = StoryManager.current_tier
	
	# Shared Limit logic for Mix Container era
	if tier < 10:
		if id == "pocha":
			var mentor = _get_item_by_id("mentor")
			var mentor_stock = get_stock(mentor) if mentor else 0
			return clampi(10 - mentor_stock, 0, 10)
		if id == "mentor":
			var pocha = _get_item_by_id("pocha")
			var pocha_stock = get_stock(pocha) if pocha else 0
			return clampi(10 - pocha_stock, 0, 10)

	return _get_max_stock_internal(id, StoryManager.day)

func _get_max_stock_internal(id: String, day: int) -> int:
	# Progression logic
	match id:
		"pocha", "mentor":
			return 10 if StoryManager.current_tier >= 10 else 5
		"chubs":
			return 5 # Always 5 once unlocked (Day 7+)
		"aryel", "ariel", "kneestoes", "kopimo": 
			return 5
		_:
			return 99 # Default for snacks/packs

func _get_item_by_id(target_id: String) -> ItemData:
	for item in _items:
		if item.get_clean_id() == target_id:
			return item
	return null

func get_capacity_limit(type: ItemData.ItemType) -> int:
	match type:
		ItemData.ItemType.SHELF: return 36
		ItemData.ItemType.FRIDGE: return 12
		_: return 999 # Containers don't have a shared physical surface limit

func get_count_on_shelves(type: ItemData.ItemType) -> int:
	var total: int = 0
	var surfaces: Array[Node] = get_tree().get_nodes_in_group("shelf_surface")
	for s in surfaces:
		if s is ShelfSurface and s.surface_type == type:
			for occupant in s._slot_occupants:
				if occupant != null and is_instance_valid(occupant):
					total += 1
	return total

func get_total_owned_count(type: ItemData.ItemType) -> int:
	var total: int = get_count_on_shelves(type)
	for item in _items:
		if item.type == type:
			total += get_stock(item)
	return total

func get_available_capacity(type: ItemData.ItemType) -> int:
	return get_capacity_limit(type) - get_total_owned_count(type)

## Returns a unique list of items currently placed on shelves or available in containers.
func get_items_available_on_display() -> Array[ItemData]:
	var result: Array[ItemData] = []
	
	# 1. Check all ShelfSurface nodes for physical items
	var surfaces = get_tree().get_nodes_in_group("shelf_surface")
	for s in surfaces:
		if s is ShelfSurface:
			for occupant in s._slot_occupants:
				if occupant != null and is_instance_valid(occupant) and occupant.item_data:
					if not result.has(occupant.item_data):
						result.append(occupant.item_data)
						
	# 2. Check all Containers (Sachet and Candy)
	var containers = get_tree().get_nodes_in_group("pricing_ui_containers")
	for c in containers:
		# Check if the container is unlocked/visible and has stock
		if not c.visible:
			continue
			
		if c is SachetContainerItem:
			if c.sachet_item and c.current_stock > 0:
				if not result.has(c.sachet_item):
					result.append(c.sachet_item)
		elif c is CandyContainerItem:
			if c.current_stock > 0:
				for candy in c.possible_candies:
					if is_in_stock(candy):
						if not result.has(candy):
							result.append(candy)
							
	return result


## Take one item from stock. Returns false if out of stock.
func take_item(item: ItemData) -> bool:
	var count: int = _stock.get(item.resource_path, 0)
	if count <= 0:
		return false
	_stock[item.resource_path] = count - 1
	save_state()
	return true

## Add stock back (e.g. when a drag is cancelled).
func return_item(item: ItemData) -> void:
	var count: int = _stock.get(item.resource_path, 0)
	_stock[item.resource_path] = mini(count + 1, get_max_stock(item))
	save_state()

## Restock an item to a specific count (capped at get_max_stock).
func restock_item(item: ItemData, count: int = -1) -> void:
	var limit: int = get_max_stock(item)
	if count < 0:
		count = limit
	_stock[item.resource_path] = mini(count, limit)
	save_state()

## Add a delta amount of stock (e.g. ordered quantity), capped at get_max_stock.
func add_stock(item: ItemData, amount: int) -> void:
	var current: int = _stock.get(item.resource_path, 0) as int
	_stock[item.resource_path] = mini(current + amount, get_max_stock(item))
	save_state()

func decrement_cooldown() -> void:
	if customers_needed_for_delivery > 0:
		customers_needed_for_delivery -= 1
		save_state()

## Set the post-order delivery cooldown (randomised 3–5 customers).
func start_delivery_cooldown() -> void:
	customers_needed_for_delivery = randi() % 3 + 3
	save_state()

func save_state() -> void:
	var save_data = {
		"inventory": {
			"stock": _stock,
			"customers_needed_for_delivery": customers_needed_for_delivery
		}
	}
	SaveManager.save_game(save_data)

func reset_state() -> void:
	_stock.clear()
	# Re-initialize stock to 0 for all items
	for item in _items:
		_stock[item.resource_path] = 0
		
	customers_needed_for_delivery = 0
	save_state()
	print("[InventoryManager] Inventory reset for New Game.")


func load_state() -> void:
	var save_data = SaveManager.load_game()
	if save_data.has("inventory"):
		var inv = save_data["inventory"]
		var saved_stock = inv.get("stock", {})
		# Merge saved stock into our initialized stock (which has all items at 0).
		# Cast to int because Godot 4's JSON parser returns all numbers as floats.
		for path in saved_stock:
			_stock[path] = int(saved_stock[path])
			
		customers_needed_for_delivery = int(inv.get("customers_needed_for_delivery", 0))
		print("[InventoryManager] State loaded from 'inventory' key.")
	elif save_data.has("stock"):
		# Fallback for old save format
		var saved_stock = save_data["stock"]
		for key in saved_stock.keys():
			_stock[key] = int(saved_stock[key])
		if save_data.has("customers_needed_for_delivery"):
			customers_needed_for_delivery = int(save_data["customers_needed_for_delivery"])
		print("[InventoryManager] State loaded from legacy keys.")
