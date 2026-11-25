class_name StoreEventManagerNode
extends Node

## Manages daily market events, customer demand boosts, and price tolerances.
## Events are active under the hood all day, but stay hidden from UI/Restock indicators
## until Papa Ulap broadcasts them over the Counter Radio.
## Autoload: StoreEventManager

signal events_changed(active_events: Array[StoreEventData])

const EVENTS_DIR := "res://Resources/events"
const DAILY_EVENT_CHANCE := 0.55
const EVENT_REVEAL_COOLDOWN_HOURS := 4.0
const CHATTER_COOLDOWN_HOURS := 1.0

var _available_events: Dictionary = {} # event_id -> StoreEventData
var _active_events: Array[StoreEventData] = []
var _revealed_event_ids: Array[String] = []
var _next_reveal_ready_hour: float = -1.0
var _next_chatter_ready_hour: float = -1.0
var _has_rolled_for_day: bool = false
var _daily_encounter_count: int = 0

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

func _get_current_hour() -> float:
	if is_instance_valid(StoryManager) and StoryManager.clock:
		return StoryManager.clock.get_effective_display_time()
	return 6.0

## Rolls daily market events that apply under the hood immediately,
## while remaining hidden in UI/Restock Menu until Papa Ulap announces them via the Radio.
## Radio upgrades unlock +1 possible daily event per tier (Lv0-1: 1, Lv2: 2, Lv3: 3).
func roll_daily_events() -> void:
	_active_events.clear()
	_revealed_event_ids.clear()
	_next_reveal_ready_hour = -1.0
	_next_chatter_ready_hour = -1.0
	_daily_encounter_count = 0
	_has_rolled_for_day = true

	var pool: Array = _available_events.values().duplicate()
	if pool.is_empty() or (is_instance_valid(StoryManager) and StoryManager.day <= 1):
		LogManager.info("StoreEventManager", "Quiet day (Day 1 or no events configured).")
		events_changed.emit(get_active_events())
		return

	if is_instance_valid(StoryManager) and StoryManager.has_mayari_card(MayariCardRegistry.CARD_QUIET_ECLIPSE):
		LogManager.info("StoreEventManager", "Quiet Eclipse Moon Card active — no market events today.")
		events_changed.emit(get_active_events())
		return

	pool.shuffle()
	var max_slots: int = StoryManager.get_max_daily_events() if (is_instance_valid(StoryManager) and StoryManager.has_method("get_max_daily_events")) else 1
	for _slot in range(max_slots):
		if pool.is_empty():
			break
		if randf() <= DAILY_EVENT_CHANCE:
			var ev: StoreEventData = pool.pop_front() as StoreEventData
			if ev:
				_active_events.append(ev)

	if _active_events.is_empty():
		LogManager.info("StoreEventManager", "Quiet day — no market events rolled today (slots=%d)." % max_slots)
	else:
		var names: Array[String] = []
		for ev in _active_events:
			names.append(ev.event_name)
		LogManager.info("StoreEventManager", "Rolled %d hidden daily event(s) (slots=%d): %s" % [_active_events.size(), max_slots, ", ".join(names)])
	events_changed.emit(get_active_events())

## Called when the player upgrades the Radio mid-day to roll any newly unlocked event slot(s).
func roll_bonus_slots_for_radio_upgrade() -> void:
	if not _has_rolled_for_day:
		return
	if is_instance_valid(StoryManager) and (StoryManager.day <= 1 or StoryManager.has_mayari_card(MayariCardRegistry.CARD_QUIET_ECLIPSE)):
		return
	var max_slots: int = StoryManager.get_max_daily_events() if is_instance_valid(StoryManager) else 1
	if _active_events.size() >= max_slots:
		return
	var pool: Array = []
	for ev in _available_events.values():
		if not _active_events.has(ev):
			pool.append(ev)
	pool.shuffle()
	while _active_events.size() < max_slots and not pool.is_empty():
		if randf() <= DAILY_EVENT_CHANCE:
			var ev: StoreEventData = pool.pop_front() as StoreEventData
			if ev:
				_active_events.append(ev)
				LogManager.info("StoreEventManager", "Bonus Radio upgrade event rolled: %s" % ev.event_name)
		else:
			break

func record_encounter() -> void:
	_daily_encounter_count += 1

# Legacy stubs kept for compatibility (Danilo no longer announces market events)
func has_pending_announcement() -> bool:
	return false

func get_pending_event() -> StoreEventData:
	return null

func mark_event_announced(event_id: String = "") -> void:
	if event_id.is_empty():
		reveal_next_event()
		return
	for ev in _active_events:
		if ev.event_id == event_id and not _revealed_event_ids.has(event_id):
			_revealed_event_ids.append(event_id)
			events_changed.emit(get_active_events())
			EventBus.restock_catalog_refresh.emit()
			return

func is_event_revealed(event_id: String) -> bool:
	return _revealed_event_ids.has(event_id)

func get_unrevealed_events() -> Array[StoreEventData]:
	var result: Array[StoreEventData] = []
	for ev in _active_events:
		if not _revealed_event_ids.has(ev.event_id):
			result.append(ev)
	return result

func has_unrevealed_events() -> bool:
	return not get_unrevealed_events().is_empty()

func get_chatter_cooldown_remaining_hours() -> float:
	if _next_chatter_ready_hour < 0.0:
		return 0.0
	var rem := _next_chatter_ready_hour - _get_current_hour()
	if rem <= 0.01:
		_next_chatter_ready_hour = -1.0
		return 0.0
	return rem

func is_chatter_on_cooldown() -> bool:
	return get_chatter_cooldown_remaining_hours() > 0.0

func start_chatter_cooldown() -> void:
	_next_chatter_ready_hour = _get_current_hour() + CHATTER_COOLDOWN_HOURS

func get_reveal_cooldown_remaining_hours() -> float:
	if not has_unrevealed_events() or _next_reveal_ready_hour < 0.0:
		return 0.0
	var rem := _next_reveal_ready_hour - _get_current_hour()
	if rem <= 0.01:
		_next_reveal_ready_hour = -1.0
		return 0.0
	return rem

func is_radio_on_cooldown() -> bool:
	return get_reveal_cooldown_remaining_hours() > 0.0

func get_radio_cooldown_remaining_hours() -> float:
	return get_reveal_cooldown_remaining_hours()

func can_reveal_next_event() -> bool:
	if not has_unrevealed_events():
		return false
	return get_reveal_cooldown_remaining_hours() <= 0.0

func peek_next_unrevealed_event() -> StoreEventData:
	var unrev := get_unrevealed_events()
	return unrev[0] if not unrev.is_empty() else null

## Reveals the next unrevealed daily event via Papa Ulap's Radio broadcast.
## Starts the 4-hour cooldown before an extra upgraded event can be revealed,
## and starts the 1-hour chatter cooldown.
func reveal_next_event() -> StoreEventData:
	if not can_reveal_next_event():
		return null
	var ev := peek_next_unrevealed_event()
	if ev == null:
		return null
	_revealed_event_ids.append(ev.event_id)
	if has_unrevealed_events():
		var cd_hours := EVENT_REVEAL_COOLDOWN_HOURS
		if is_instance_valid(StoryManager):
			if StoryManager.has_mayari_card(MayariCardRegistry.CARD_ECHOES_ON_THE_DIAL):
				cd_hours *= 0.50
			if StoryManager.has_mayari_card(MayariCardRegistry.CARD_STATIC_AIRWAVES):
				cd_hours *= 1.50
		_next_reveal_ready_hour = _get_current_hour() + cd_hours
	else:
		_next_reveal_ready_hour = -1.0
	start_chatter_cooldown()
	LogManager.info("StoreEventManager", "Papa Ulap revealed event '%s' (%d/%d revealed)." % [
		ev.event_name, _revealed_event_ids.size(), _active_events.size()
	])
	events_changed.emit(get_active_events())
	EventBus.restock_catalog_refresh.emit()
	return ev

## Returns REVEALED active events for UI display (EventsOverlay, HUD, Restock, Summary).
func get_active_events() -> Array[StoreEventData]:
	var revealed: Array[StoreEventData] = []
	for ev in _active_events:
		if _revealed_event_ids.has(ev.event_id):
			revealed.append(ev)
	return revealed

## Returns ALL active events (including hidden ones) for gameplay simulation.
func get_all_active_events() -> Array[StoreEventData]:
	return _active_events

## Gameplay modifier: applies to ALL active events (even if not yet revealed by Radio).
func get_item_demand_multiplier(item: ItemData) -> float:
	if not item:
		return 1.0
	var multiplier := 1.0
	for event in _active_events:
		if event.affects_item(item):
			multiplier = maxf(multiplier, event.demand_multiplier)
	return multiplier

## Gameplay modifier: applies to ALL active events (even if not yet revealed by Radio).
func get_item_tolerance_offset(item: ItemData) -> int:
	if not item:
		return 0
	var offset := 0
	for event in _active_events:
		if event.affects_item(item):
			offset = maxi(offset, event.tolerance_offset)
	return offset

func get_foot_traffic_time_scale() -> float:
	var scale := 1.0
	for event in _active_events:
		scale *= event.foot_traffic_scale
	return clampf(scale, 0.50, 1.50)

func get_multi_item_chance_bonus() -> float:
	var bonus := 0.0
	for event in _active_events:
		bonus += event.multi_item_chance_bonus
	return clampf(bonus, 0.0, 0.65)

func get_cash_tip_bonus_pct() -> float:
	var pct := 0.0
	for event in _active_events:
		pct += event.tip_bonus_pct
	return clampf(pct, 0.0, 0.50)

func get_xp_multiplier() -> float:
	var mult := 1.0
	for event in _active_events:
		mult *= event.xp_multiplier
	return clampf(mult, 0.50, 2.50)

func get_restock_cost_multiplier() -> float:
	var mult := 1.0
	for event in _active_events:
		mult *= event.restock_cost_multiplier
	return clampf(mult, 0.50, 2.0)

func get_delivery_cooldown_multiplier() -> float:
	var mult := 1.0
	for event in _active_events:
		mult *= event.delivery_cooldown_multiplier
	return clampf(mult, 0.40, 2.0)

func get_fridge_drain_multiplier() -> float:
	var mult := 1.0
	for event in _active_events:
		mult *= event.fridge_drain_multiplier
	return clampf(mult, 0.40, 2.50)

func get_extra_counter_slots() -> int:
	var extra := 0
	for event in _active_events:
		extra += event.extra_counter_slots
	return extra

func get_linger_chance_bonus() -> float:
	var bonus := 0.0
	for event in _active_events:
		bonus += event.linger_chance_bonus
	return clampf(bonus, 0.0, 0.50)

## UI indicator check: returns true ONLY if a REVEALED event targets this item.
func is_item_in_demand(item: ItemData) -> bool:
	if not item:
		return false
	for event in get_active_events():
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
		"revealed_event_ids": _revealed_event_ids.duplicate(),
		"next_reveal_ready_hour": _next_reveal_ready_hour,
		"next_chatter_ready_hour": _next_chatter_ready_hour,
		"has_rolled_for_day": _has_rolled_for_day,
		"daily_encounter_count": _daily_encounter_count,
	}

func load_save_data(data: Dictionary) -> void:
	_active_events.clear()
	_revealed_event_ids.clear()
	var ids: Array = data.get("active_event_ids", [])
	for id in ids:
		var event_id_str := str(id)
		if _available_events.has(event_id_str):
			_active_events.append(_available_events[event_id_str])

	if data.has("revealed_event_ids"):
		var rev_ids: Array = data.get("revealed_event_ids", [])
		for rid in rev_ids:
			var rstr := str(rid)
			if _available_events.has(rstr) and not _revealed_event_ids.has(rstr):
				_revealed_event_ids.append(rstr)
	else:
		# Legacy save compatibility: previously active_event_ids were already announced
		for ev in _active_events:
			_revealed_event_ids.append(ev.event_id)

	# Legacy pending_event_id migration: treat as an active unrevealed event
	var legacy_pending := str(data.get("pending_event_id", ""))
	if not legacy_pending.is_empty() and _available_events.has(legacy_pending):
		var pev: StoreEventData = _available_events[legacy_pending]
		if not _active_events.has(pev):
			_active_events.append(pev)

	_next_reveal_ready_hour = float(data.get("next_reveal_ready_hour", -1.0))
	_next_chatter_ready_hour = float(data.get("next_chatter_ready_hour", -1.0))
	_has_rolled_for_day = bool(data.get("has_rolled_for_day", false))
	_daily_encounter_count = int(data.get("daily_encounter_count", 0))
	events_changed.emit(get_active_events())
	LogManager.info("StoreEventManager", "Restored %d active event(s) (%d revealed) from save." % [
		_active_events.size(), _revealed_event_ids.size()
	])

func reset_state() -> void:
	_active_events.clear()
	_revealed_event_ids.clear()
	_next_reveal_ready_hour = -1.0
	_next_chatter_ready_hour = -1.0
	_has_rolled_for_day = false
	_daily_encounter_count = 0
	events_changed.emit(get_active_events())
