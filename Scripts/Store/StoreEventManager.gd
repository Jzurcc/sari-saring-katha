class_name StoreEventManagerNode
extends Node

## Manages daily market events, rumors, customer demand boosts, and price tolerances.
## Autoload: StoreEventManager

signal events_changed(active_events: Array[StoreEventData])

const EVENTS_DIR := "res://Resources/events"

var _available_events: Dictionary = {} # event_id -> StoreEventData
var _active_events: Array[StoreEventData] = []
var _has_rolled_for_day: bool = false

func _ready() -> void:
	add_to_group("persist")
	_load_available_events()
	EventBus.day_started.connect(_on_day_started)

func _load_available_events() -> void:
	_available_events.clear()
	var dir := DirAccess.open(EVENTS_DIR)
	if not dir:
		LogManager.warning("StoreEventManager", "Could not open events directory: %s" % EVENTS_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := EVENTS_DIR + "/" + file_name
			var event_res := load(path) as StoreEventData
			if event_res and not event_res.event_id.is_empty():
				_available_events[event_res.event_id] = event_res
		file_name = dir.get_next()
	dir.list_dir_end()
	LogManager.info("StoreEventManager", "Loaded %d market events." % _available_events.size())

func _on_day_started(_day_number: int) -> void:
	roll_daily_events()

## Rolls 1-2 random market events for the new day.
func roll_daily_events() -> void:
	_active_events.clear()
	var pool := _available_events.values().duplicate()
	if pool.is_empty():
		events_changed.emit(_active_events)
		return

	pool.shuffle()
	# 70% chance for 1 event, 30% chance for 2 events
	var count := 2 if (randf() < 0.30 and pool.size() >= 2) else 1
	for i in range(mini(count, pool.size())):
		_active_events.append(pool[i])

	_has_rolled_for_day = true
	LogManager.info("StoreEventManager", "Rolled %d daily events: %s" % [
		_active_events.size(),
		", ".join(_active_events.map(func(e): return e.event_name))
	])
	events_changed.emit(_active_events)

func get_active_events() -> Array[StoreEventData]:
	return _active_events

## Returns the highest demand multiplier among active events that affect this item.
func get_item_demand_multiplier(item: ItemData) -> float:
	if not item:
		return 1.0
	var multiplier := 1.0
	for event in _active_events:
		if event.affects_item(item):
			multiplier = maxf(multiplier, event.demand_multiplier)
	return multiplier

## Returns the highest price tolerance offset among active events affecting this item.
func get_item_tolerance_offset(item: ItemData) -> int:
	if not item:
		return 0
	var offset := 0
	for event in _active_events:
		if event.affects_item(item):
			offset = maxi(offset, event.tolerance_offset)
	return offset

## Returns true if any active event targets this item.
func is_item_in_demand(item: ItemData) -> bool:
	if not item:
		return false
	for event in _active_events:
		if event.affects_item(item):
			return true
	return false

# ─── Persistence ──────────────────────────────────────────────────────────────

func get_save_id() -> String:
	return "store_events"

func get_save_data() -> Dictionary:
	var ids: Array[String] = []
	for e in _active_events:
		ids.append(e.event_id)
	return {
		"active_event_ids": ids,
		"has_rolled_for_day": _has_rolled_for_day
	}

func load_save_data(data: Dictionary) -> void:
	_active_events.clear()
	var ids: Array = data.get("active_event_ids", [])
	for id in ids:
		var event_id_str := str(id)
		if _available_events.has(event_id_str):
			_active_events.append(_available_events[event_id_str])
	_has_rolled_for_day = data.get("has_rolled_for_day", false)
	events_changed.emit(_active_events)
	LogManager.info("StoreEventManager", "Restored %d active events from save." % _active_events.size())

func reset_state() -> void:
	_active_events.clear()
	_has_rolled_for_day = false
	events_changed.emit(_active_events)
