class_name StoreEventManagerNode
extends Node

## Manages daily market events, rumors, customer demand boosts, and price tolerances.
## Autoload: StoreEventManager

signal events_changed(active_events: Array[StoreEventData])

const EVENTS_DIR := "res://Resources/events"

var _available_events: Dictionary = {} # event_id -> StoreEventData
var _active_events: Array[StoreEventData] = []
var _pending_event: StoreEventData = null
var _has_rolled_for_day: bool = false
var _daily_encounter_count: int = 0
var _announcement_encounter_slot: int = 1

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

## Rolls a random daily market event that begins in a pending state until Danilo announces it.
func roll_daily_events() -> void:
	_active_events.clear()
	_pending_event = null
	var pool := _available_events.values().duplicate()
	if pool.is_empty():
		events_changed.emit(_active_events)
		return

	pool.shuffle()
	_pending_event = pool[0]
	_has_rolled_for_day = true
	_daily_encounter_count = 0
	_announcement_encounter_slot = randi_range(1, 4)
	LogManager.info("StoreEventManager", "Daily event queued for Danilo's announcement (Encounter #%d): %s" % [_announcement_encounter_slot, _pending_event.event_name])
	events_changed.emit(_active_events)

func record_encounter() -> void:
	_daily_encounter_count += 1

func has_pending_announcement() -> bool:
	return _pending_event != null and _daily_encounter_count >= _announcement_encounter_slot

func get_pending_event() -> StoreEventData:
	return _pending_event

## Marks the pending event as officially announced by Danilo, moving it to active events.
func mark_event_announced(event_id: String = "") -> void:
	var event_to_activate: StoreEventData = null
	if _pending_event and (event_id.is_empty() or _pending_event.event_id == event_id):
		event_to_activate = _pending_event
		_pending_event = null
	elif not event_id.is_empty() and _available_events.has(event_id):
		event_to_activate = _available_events[event_id]

	if event_to_activate and not _active_events.has(event_to_activate):
		_active_events.append(event_to_activate)
		LogManager.info("StoreEventManager", "Danilo announced event '%s'. Event is now ACTIVE!" % event_to_activate.event_name)
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
		"pending_event_id": _pending_event.event_id if _pending_event else "",
		"has_rolled_for_day": _has_rolled_for_day,
		"daily_encounter_count": _daily_encounter_count,
		"announcement_encounter_slot": _announcement_encounter_slot
	}

func load_save_data(data: Dictionary) -> void:
	_active_events.clear()
	_pending_event = null
	var ids: Array = data.get("active_event_ids", [])
	for id in ids:
		var event_id_str := str(id)
		if _available_events.has(event_id_str):
			_active_events.append(_available_events[event_id_str])
	var pending_id: String = str(data.get("pending_event_id", ""))
	if not pending_id.is_empty() and _available_events.has(pending_id):
		_pending_event = _available_events[pending_id]
	_has_rolled_for_day = data.get("has_rolled_for_day", false)
	_daily_encounter_count = int(data.get("daily_encounter_count", 0))
	_announcement_encounter_slot = clampi(int(data.get("announcement_encounter_slot", 1)), 1, 4)
	events_changed.emit(_active_events)
	LogManager.info("StoreEventManager", "Restored %d active events and pending (%s, slot %d/%d) from save." % [
		_active_events.size(), pending_id, _daily_encounter_count, _announcement_encounter_slot
	])

func reset_state() -> void:
	_active_events.clear()
	_pending_event = null
	_has_rolled_for_day = false
	_daily_encounter_count = 0
	_announcement_encounter_slot = 1
	events_changed.emit(_active_events)

