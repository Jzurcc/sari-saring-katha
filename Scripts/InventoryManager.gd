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
	var base_path := "res://Resources/items"
	var base_dir := DirAccess.open(base_path)
	if not base_dir:
		push_error("InventoryManager: cannot open " + base_path)
		return
	base_dir.list_dir_begin()
	var subdir := base_dir.get_next()
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
	var dir := DirAccess.open(folder_path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res: Resource = load(folder_path + "/" + file_name)
			if res is ItemData:
				res.id = file_name.get_basename()
				_items.append(res)
				_stock[res.resource_path] = res.max_stock
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
	_stock[item.resource_path] = mini(count + 1, item.max_stock)
	save_state()

## Restock an item to a specific count (capped at max_stock).
func restock_item(item: ItemData, count: int = -1) -> void:
	if count < 0:
		count = item.max_stock
	_stock[item.resource_path] = mini(count, item.max_stock)
	save_state()

## Add a delta amount of stock (e.g. ordered quantity), capped at max_stock.
func add_stock(item: ItemData, amount: int) -> void:
	var current: int = _stock.get(item.resource_path, 0) as int
	_stock[item.resource_path] = mini(current + amount, item.max_stock)
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
		"stock": _stock,
		"customers_needed_for_delivery": customers_needed_for_delivery
	}
	SaveManager.save_game(save_data)

func load_state() -> void:
	var save_data = SaveManager.load_game()
	if save_data.has("stock"):
		var saved_stock = save_data["stock"]
		for key in saved_stock.keys():
			_stock[key] = saved_stock[key]
	if save_data.has("customers_needed_for_delivery"):
		customers_needed_for_delivery = int(save_data["customers_needed_for_delivery"])
