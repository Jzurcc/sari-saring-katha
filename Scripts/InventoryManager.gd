extends Node

## Tracks item stock counts across the game.
## Key: ItemData.resource_path → Value: current stock count.

var _stock: Dictionary = {}
var _items: Array[ItemData] = []

## Load all ItemData resources from subfolders and set initial stock.
func initialize() -> void:
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
	return true

## Add stock back (e.g. when a drag is cancelled).
func return_item(item: ItemData) -> void:
	var count: int = _stock.get(item.resource_path, 0)
	_stock[item.resource_path] = mini(count + 1, item.max_stock)

## Restock an item to a specific count (capped at max_stock).
func restock_item(item: ItemData, count: int = -1) -> void:
	if count < 0:
		count = item.max_stock
	_stock[item.resource_path] = mini(count, item.max_stock)
