extends Node
class_name CustomerSpawner

## Tracks which phase of dialogue is currently playing.
## Used by _on_dialogue_ended to decide what to do when a timeline ends.
## timeline_ended fires EXACTLY ONCE per timeline (confirmed from Dialogic source)
const DialoguePhase = TransactionSession.Phase

const MAX_COUNTER_SLOTS := 3
const SMALLTALK_RETURN_CHANCE := 0.75
const LINGERING_RETURN_BUY_CHANCE := 0.35
const LINGERING_PASSIVE_XP_INTERVAL := 2.0
const AMBIENT_CAMEO_MIN_INTERVAL := 20.0
const AMBIENT_CAMEO_MAX_INTERVAL := 42.0
const AMBIENT_CAMEO_TRIGGER_CHANCE := 0.72
const MAX_ACTIVE_AMBIENT_CAMEOS := 3

@export var customer_scene: PackedScene = preload("res://Scenes/Customer.tscn")
@export var spawn_pos: NodePath
@export var target_pos: NodePath
@export var exit_pos: NodePath
## Number of active counter slots (1..3), gated by Store Cat upgrades (0 -> 1 slot, 1 -> 2, 2 -> 3).
@export_range(1, 3) var max_unlocked_slots: int = 1
## Lateral distance from Center slot to Left/Right side slots along the counter.
@export var slot_side_spacing: float = 1.95
## How far back (away from the counter) Left and Right slots stand relative to Center.
@export var side_slot_depth_offset: float = 0.35

var session: TransactionSession = TransactionSession.new()

## 3 shared counter slots: 0 = Center, 1 = Left, 2 = Right
var counter_slots: Array[Customer] = [null, null, null]
## Background visitors hanging out in the tambayan area (do NOT occupy counter slots)
var lingering_visitors: Array[Customer] = []
## Non-interactive pass-by / fly-by cameo instances currently crossing the street or storefront
var _ambient_cameos: Array[Customer] = []
var _ambient_cameo_session_id: int = 0
var _pending_incoming_path: String = ""

## Backward-compatible active customer accessor (returns active dialogue customer or first occupied slot)
var current_customer: Customer:
	get:
		if is_instance_valid(session.current_customer):
			return session.current_customer
		for c in counter_slots:
			if is_instance_valid(c):
				return c
		return null
	set(val):
		session.current_customer = val

var guest_customer: Customer:
	get: return session.guest_customer
	set(val): session.guest_customer = val

var _dialogue_phase: TransactionSession.Phase:
	get: return session.phase
	set(val): session.phase = val

var _is_spawning: bool = false
var _is_nokia_open: bool = false
var _wave_id: int = 0
var _is_exclusive_wave: bool = false
var _is_transitioning_wave: bool = false
var _next_arrival_order: int = 0
var _day_ended_emitted_for_day: int = -1
var _leaving_customers_count: int = 0
var _lingering_counter_departures: Dictionary = {}
var _linger_xp_timer: float = 0.0

var is_paused: bool = false:
	set(value):
		is_paused = value
		if not is_paused and not has_any_counter_customer() and not _is_spawning and not _is_transitioning_wave:
			_spawn_next_customer()

## Pending restored slot entries: Array[{ "slot": int, "ctx": TransactionContext, "greeted": bool }]
var _pending_restore_slots: Array[Dictionary] = []

func _ready() -> void:
	LogManager.debug("CustomerSpawner", "_ready() START")
	add_to_group("customer_spawner")
	add_to_group("persist")
	session.setup(self)
	SaveManager.is_quitting = false # Reset quitting flag when entering the game
	EventBus.day_started.connect(_on_day_started)
	EventBus.customer_satisfied.connect(_on_customer_dismissed)
	EventBus.customer_partial_satisfaction.connect(_on_customer_partial_satisfaction)
	EventBus.customer_dismissed.connect(_on_customer_dismissed)
	Dialogic.timeline_ended.connect(_on_dialogue_ended)
	Dialogic.signal_event.connect(_on_dialogic_signal)
	EventBus.nokia_opened.connect(_on_nokia_opened)
	EventBus.nokia_closed.connect(_on_nokia_closed)
	EventBus.closing_time_reached.connect(_on_closing_time_reached)
	EventBus.dialogue_character_speaking.connect(_on_character_speaking)
	EventBus.customer_item_offered.connect(_on_customer_item_offered)
	EventBus.tray_item_placed.connect(_on_tray_item_placed)
	EventBus.cat_upgraded.connect(_on_cat_upgraded)
	set_max_unlocked_slots(StoryManager.get_max_counter_slots())
	_schedule_next_ambient_cameo()
	LogManager.debug("CustomerSpawner", "_ready() END")

func _on_cat_upgraded(_new_level: int) -> void:
	set_max_unlocked_slots(StoryManager.get_max_counter_slots())

func set_max_unlocked_slots(count: int) -> void:
	max_unlocked_slots = clampi(count, 1, MAX_COUNTER_SLOTS)
	LogManager.info("CustomerSpawner", "Max unlocked counter slots set to %d" % max_unlocked_slots)

func has_any_counter_customer() -> bool:
	for c in counter_slots:
		if is_instance_valid(c) and not c._is_resolving:
			return true
	return false

func has_other_counter_customers(excluding: Customer) -> bool:
	for c in counter_slots:
		if is_instance_valid(c) and c != excluding and not c._is_resolving:
			return true
	if _leaving_customers_count > 1:
		return true
	return false

func get_present_character_paths() -> Array[String]:
	var paths: Array[String] = []
	for c in counter_slots:
		if is_instance_valid(c) and c.customer_data and not (c.customer_data.resource_path in paths):
			paths.append(c.customer_data.resource_path)
	for v in lingering_visitors:
		if is_instance_valid(v) and v.customer_data and not (v.customer_data.resource_path in paths):
			paths.append(v.customer_data.resource_path)
	for cam in _ambient_cameos:
		if is_instance_valid(cam) and cam.customer_data and not (cam.customer_data.resource_path in paths):
			paths.append(cam.customer_data.resource_path)
	if is_instance_valid(guest_customer) and guest_customer.customer_data:
		if not (guest_customer.customer_data.resource_path in paths):
			paths.append(guest_customer.customer_data.resource_path)
	if _pending_incoming_path != "" and not (_pending_incoming_path in paths):
		paths.append(_pending_incoming_path)
	return paths

func _find_open_slot(prefer_side: bool = false) -> int:
	var order: Array[int] = [0, 1, 2]
	if prefer_side:
		order = [1, 2, 0]
	for idx in order:
		if idx < max_unlocked_slots and not is_instance_valid(counter_slots[idx]):
			return idx
	return -1

## Finds an open counter slot for a lingering tambayan visitor returning for smalltalk.
## Unlocks a hidden tambayan slot one ahead of the player's customer slots:
## - 1 customer slot (no cat): prioritizes hidden Slot 1, falls back to Slot 0 if empty.
## - 2 customer slots (cat unlocked): prioritizes hidden Slot 2, falls back to Slots 1, 0.
## - 3 customer slots (fully unlocked): integrated with Slot 2, falls back to Slots 1, 0.
func _find_open_slot_for_lingering() -> int:
	var order: Array[int] = [1, 0]
	if max_unlocked_slots > 1:
		order = [2, 1, 0]
	for idx in order:
		if idx == 0 and _is_spawning:
			continue
		if not is_instance_valid(counter_slots[idx]):
			return idx
	return -1

func _on_day_started(_day: int) -> void:
	LogManager.debug("CustomerSpawner", "_on_day_started() Day starts — customers will spawn until 8 PM.")
	_day_ended_emitted_for_day = -1
	_dismiss_all_lingering_visitors()
	_clear_ambient_cameos()
	_schedule_next_ambient_cameo()
	_spawn_next_customer()

func _spawn_next_customer() -> void:
	if _is_spawning:
		LogManager.debug("CustomerSpawner", "_spawn_next_customer() IGNORED: Spawn already in progress.")
		return

	if has_any_counter_customer():
		LogManager.debug("CustomerSpawner", "_spawn_next_customer() ABORTED: counter already occupied.")
		return

	if is_paused:
		return

	max_unlocked_slots = StoryManager.get_max_counter_slots()

	# Closing time check
	if StoryManager.is_past_closing_time():
		LogManager.info("CustomerSpawner", "Store is closing. Spawning Mayari for collection.")
		spawn_mayari_for_collection()
		return

	# If a lingering visitor in the tambayan is waiting to return for smalltalk, let them step up first!
	if _try_return_waiting_lingering_visitor():
		return

	_is_spawning = true
	_wave_id += 1
	var my_wave_id := _wave_id
	_is_exclusive_wave = false

	# Case 1: Restore multi-slot customers from save
	if not _pending_restore_slots.is_empty():
		var restored_entries := _pending_restore_slots.duplicate(true)
		_pending_restore_slots.clear()
		await get_tree().create_timer(1.2).timeout
		if not is_inside_tree() or my_wave_id != _wave_id:
			_is_spawning = false
			return
		var first_customer: Customer = null
		for entry in restored_entries:
			var slot_idx: int = clampi(int(entry.get("slot", 0)), 0, MAX_COUNTER_SLOTS - 1)
			var ctx: TransactionContext = entry.get("ctx") as TransactionContext
			if ctx == null or ctx.customer_data == null:
				continue
			if is_instance_valid(counter_slots[slot_idx]):
				slot_idx = _find_open_slot(false)
				if slot_idx == -1:
					continue
			StoryManager.update_transaction_item_string(ctx)
			var spawned := _spawn_customer_into_slot(ctx, slot_idx)
			spawned.has_been_greeted = bool(entry.get("greeted", false))
			if first_customer == null:
				first_customer = spawned
		if is_instance_valid(first_customer):
			session.current_customer = first_customer
		_is_spawning = false
		return

	# Case 2: Fresh Wave Start — spawn primary customer into Center slot (0)
	var exclude_paths := get_present_character_paths()
	var transaction: TransactionContext = StoryManager.get_next_transaction(exclude_paths, false)
	if transaction == null:
		_is_spawning = false
		_end_day()
		return

	_log_incoming_transaction(transaction, 0)
	_pending_incoming_path = transaction.customer_data.resource_path if transaction.customer_data else ""

	await get_tree().create_timer(2.0).timeout
	_pending_incoming_path = ""
	if not is_inside_tree() or my_wave_id != _wave_id:
		_is_spawning = false
		return

	var primary := _spawn_customer_into_slot(transaction, 0)
	session.current_customer = primary

	# Exclusive scenes (tutorial, two-character story, nightly collector) stay solo
	_is_exclusive_wave = transaction.is_guided_tutorial \
		or transaction.secondary_customer_data != null \
		or transaction.is_nightly_collection

	_is_spawning = false

	# Wave / Burst Pacing: schedule staggered joiners into side slots (1..max_unlocked_slots-1)
	if not _is_exclusive_wave and max_unlocked_slots > 1 and not StoryManager.is_past_closing_time():
		var wave_size := _roll_wave_size()
		if wave_size > 1:
			_schedule_wave_joiners(my_wave_id, wave_size - 1)

func _roll_wave_size() -> int:
	if max_unlocked_slots <= 1:
		return 1
	var r := randf()
	if max_unlocked_slots == 2:
		return 2 if r < 0.55 else 1
	# max_unlocked_slots == 3: 25% solo, 45% pair, 30% full 3-person rush
	if r < 0.25:
		return 1
	elif r < 0.70:
		return 2
	return 3

func _schedule_wave_joiners(my_wave_id: int, joiner_count: int) -> void:
	for _i in range(joiner_count):
		var delay := randf_range(2.0, 6.5)
		await get_tree().create_timer(delay).timeout
		if not is_inside_tree() or my_wave_id != _wave_id:
			return
		if is_paused or _is_exclusive_wave or StoryManager.is_past_closing_time():
			return
		if not has_any_counter_customer():
			# Primary already finished before joiner arrived — wave is over
			return
		var slot_idx := _find_open_slot(true)
		if slot_idx == -1:
			return
		var exclude_paths := get_present_character_paths()
		var joiner_tx := StoryManager.get_next_transaction(exclude_paths, true)
		if joiner_tx == null:
			return
		_log_incoming_transaction(joiner_tx, slot_idx)
		_spawn_customer_into_slot(joiner_tx, slot_idx)

func _log_incoming_transaction(transaction: TransactionContext, slot_idx: int) -> void:
	var type_name: String = (["STORY", "PURCHASE", "VISIT"])[transaction.transaction_type]
	var item_list: Array[String] = []
	for item in transaction.desired_items:
		item_list.append(item.item_name)
	LogManager.info("Customer", "Incoming [Slot %d]: Character=%s, Type=%s, Wants=%s" % [
		slot_idx,
		transaction.customer_data.get_clean_id(),
		type_name,
		", ".join(item_list) if item_list.size() > 0 else "(nothing — visit)"
	])

func _spawn_customer_into_slot(transaction: TransactionContext, slot_idx: int) -> Customer:
	var has_guest := transaction.secondary_customer_data != null
	var pos_data := _calculate_positions(has_guest, slot_idx)
	var spawn_global: Vector3 = pos_data.spawn_pos
	var target_global: Vector3 = pos_data.target_pos
	var exit_global: Vector3 = pos_data.exit_pos
	var final_target: Vector3 = pos_data.primary_target

	# If the customer is Kuya Kap, offset him back so he doesn't hit his head on the roof.
	if transaction.customer_data and transaction.customer_data.get_clean_id() == "kuyakap":
		var dir_back := (spawn_global - target_global).normalized()
		final_target += (dir_back * 0.7)

	var customer := _create_customer(transaction, spawn_global, final_target, exit_global)
	customer.slot_index = slot_idx
	_next_arrival_order += 1
	customer.arrival_order = _next_arrival_order
	counter_slots[slot_idx] = customer

	# Spawn Guest Customer if present (exclusive two-character story scene)
	if has_guest:
		var guest_context := TransactionContext.new()
		guest_context.customer_data = transaction.secondary_customer_data
		guest_context.transaction_type = TransactionContext.Type.VISIT

		var guest_target: Vector3 = pos_data.guest_target
		guest_customer = customer_scene.instantiate()
		guest_customer.is_guest_customer = true
		get_parent().add_child(guest_customer)
		guest_customer.global_position = spawn_global
		guest_customer.setup(guest_context, guest_target, exit_global, transaction.guest_spawns_later)
		guest_customer.clicked.connect(_on_guest_clicked)
		LogManager.info("Customer", "Guest spawned: %s" % transaction.secondary_customer_data.get_clean_id())

	EventBus.customer_spawned.emit(customer)
	return customer

func _calculate_positions(has_guest: bool, slot_idx: int = 0) -> Dictionary:
	if not spawn_pos or not target_pos:
		return {}

	var spawn_global: Vector3 = get_node(spawn_pos).global_position
	var target_global: Vector3 = get_node(target_pos).global_position
	var exit_global: Vector3 = get_node(exit_pos).global_position if exit_pos else spawn_global

	var approach_dir := (target_global - spawn_global).normalized()
	var side_offset := Vector3(-approach_dir.z, 0, approach_dir.x) # Left perpendicular

	var primary_target := target_global
	var guest_target := target_global

	if has_guest:
		primary_target = target_global + (side_offset * -0.9) # Shift Primary to Right
		guest_target = target_global + (side_offset * 0.9) # Shift Guest to Left
	elif slot_idx == 1:
		primary_target = target_global + (side_offset * slot_side_spacing) - (approach_dir * side_slot_depth_offset) # Left slot (slightly back)
	elif slot_idx == 2:
		primary_target = target_global + (side_offset * -slot_side_spacing) - (approach_dir * side_slot_depth_offset) # Right slot (slightly back)

	return {
		"spawn_pos": spawn_global,
		"target_pos": target_global,
		"exit_pos": exit_global,
		"primary_target": primary_target,
		"guest_target": guest_target,
		"approach_dir": approach_dir,
		"side_offset": side_offset
	}

func _get_background_hangout_points() -> Array[Vector3]:
	var pos_data := _calculate_positions(false, 0)
	if pos_data.is_empty():
		return []
	var target_global: Vector3 = pos_data.target_pos
	var dir_back: Vector3 = - pos_data.approach_dir
	var side: Vector3 = pos_data.side_offset

	var points: Array[Vector3] = []
	var waypoint_count := randi_range(3, 5)
	# First move is always behind AND clearly off-center (left or right) so incoming customers don't clip
	var first_side_sign := 1.0 if randf() < 0.5 else -1.0
	var prev_side := first_side_sign * randf_range(2.2, 3.5)
	var prev_back := randf_range(2.6, 3.6)
	points.append(target_global + dir_back * prev_back + side * prev_side)

	for _i in range(waypoint_count - 1):
		var is_long_stroll := randf() < 0.60
		var next_side: float
		if is_long_stroll:
			# Cross-street / wider stroll to the opposite side (avoid stopping dead center)
			var dir_sign := -1.0 if prev_side >= 0.0 else 1.0
			next_side = clampf(prev_side + dir_sign * randf_range(3.2, 5.2), -3.9, 3.9)
		else:
			# Short casual hop nearby on the same side
			var hop_sign := 1.0 if randf() < 0.5 else -1.0
			next_side = clampf(prev_side + hop_sign * randf_range(0.7, 1.4), -3.9, 3.9)
		# Keep lingering spots out of the center approach lane
		if absf(next_side) < 1.5:
			next_side = (1.0 if next_side >= 0.0 else -1.0) * randf_range(1.7, 2.4)
		var next_back := randf_range(2.5, 4.0)
		points.append(target_global + dir_back * next_back + side * next_side)
		prev_side = next_side
		prev_back = next_back

	return points

func _on_customer_started_leaving(customer: Customer) -> void:
	if customer == null or customer == guest_customer:
		return

	var vacated_slot := -1
	for i in range(counter_slots.size()):
		if counter_slots[i] == customer:
			counter_slots[i] = null
			vacated_slot = i
			break

	if vacated_slot != -1:
		_leaving_customers_count += 1
		if customer.is_lingering_departure:
			_lingering_counter_departures[customer] = true

	if session.current_customer == customer:
		session.current_customer = null

	# Immediately promote the earliest side customer into Center as soon as Center starts leaving
	if vacated_slot == 0 and has_any_counter_customer():
		_promote_earliest_side_customer_to_center()

func _on_customer_dismissed(customer: Customer) -> void:
	if customer == null or customer.is_lingering_departure:
		return

	if customer == guest_customer:
		guest_customer = null
		return

	if _leaving_customers_count > 0:
		_leaving_customers_count = maxi(0, _leaving_customers_count - 1)

	for i in range(counter_slots.size()):
		if counter_slots[i] == customer:
			counter_slots[i] = null
			break

	if session.current_customer == customer:
		session.current_customer = null

	if is_instance_valid(guest_customer) and not has_any_counter_customer():
		guest_customer.dismiss()
		guest_customer = null

	EventBus.customer_order_cleared.emit(customer.get_order_hud_key())

	# If other customers are still at the counter (or still walking out), keep the wave alive
	if has_any_counter_customer():
		_promote_earliest_side_customer_to_center()
		_try_return_waiting_lingering_visitor()
		return
	if _leaving_customers_count > 0:
		return

	_on_wave_cleared()

func _promote_earliest_side_customer_to_center() -> void:
	if is_instance_valid(counter_slots[0]) or _is_exclusive_wave:
		return

	var best_slot := -1
	var best_customer: Customer = null
	for idx in [1, 2]:
		var c := counter_slots[idx]
		if not is_instance_valid(c) or c._is_resolving or c.is_lingering_visitor or c.is_returning_for_smalltalk:
			continue
		if best_customer == null or c.arrival_order < best_customer.arrival_order:
			best_customer = c
			best_slot = idx

	if best_customer == null or best_slot == -1:
		return

	counter_slots[best_slot] = null
	counter_slots[0] = best_customer

	var pos_data := _calculate_positions(false, 0)
	var center_target: Vector3 = pos_data.primary_target
	if best_customer.customer_data and best_customer.customer_data.get_clean_id() == "kuyakap":
		var dir_back: Vector3 = (pos_data.spawn_pos - pos_data.target_pos).normalized()
		center_target += dir_back * 0.7

	LogManager.info("CustomerSpawner", "Promoting %s from Slot %d -> Center (Slot 0)." % [best_customer.get_order_hud_key(), best_slot])
	best_customer.move_to_slot(0, center_target)

func _on_wave_cleared() -> void:
	if _is_transitioning_wave:
		return
	_is_transitioning_wave = true

	# Cancel any unspawned joiners for the finished wave
	_wave_id += 1
	_is_exclusive_wave = false

	# Check if we have a pending tier unlock now that the counter is clear
	StoryManager.process_pending_unlock()

	# Wait for the single post-wave time-skip timelapse to finish
	if StoryManager.clock.is_fast_forwarding():
		await StoryManager.clock.fast_forward_finished
		if not is_inside_tree():
			_is_transitioning_wave = false
			return

	var delay := randf_range(0.4, 1.4) * StoryManager.get_foot_traffic_time_scale()
	if StoryManager.is_past_closing_time():
		delay = 1.0 # Short delay for Mayari arrival

	await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		_is_transitioning_wave = false
		return

	_is_transitioning_wave = false
	if not has_any_counter_customer():
		_spawn_next_customer()

# ── Lingering Visitors (Tambayan) ────────────────────────────────────────────

func handle_social_visit_finished(customer: Customer) -> void:
	if not is_instance_valid(customer):
		return

	var ctx := customer.transaction_context
	if not customer.get_meta("visit_stat_recorded", false) \
		and (ctx == null or (not ctx.is_guided_tutorial and not ctx.is_nightly_collection)):
		customer.set_meta("visit_stat_recorded", true)
		StoryManager.award_customer_completion_xp(customer)
		StoryManager.record_daily_stat_int("visits_served", 1)
	var can_linger: bool = not StoryManager.is_past_closing_time() \
		and not _is_exclusive_wave \
		and not customer.get_meta("returned_from_lingering", false) \
		and lingering_visitors.size() < StoryManager.get_bench_max_lingering() \
		and ctx != null \
		and not ctx.is_guided_tutorial \
		and not ctx.is_visit_story \
		and (customer.customer_data == null or not customer.customer_data.is_collector()) \
		and randf() < StoryManager.get_bench_linger_chance()

	if not can_linger:
		customer.dismiss()
		return

	# Release their counter slot so new customers can arrive while they hang out in the background
	for i in range(counter_slots.size()):
		if counter_slots[i] == customer:
			counter_slots[i] = null
			break

	if session.current_customer == customer:
		session.current_customer = null

	lingering_visitors.append(customer)
	if not customer.lingering_ready_to_return.is_connected(_on_lingering_ready_to_return):
		customer.lingering_ready_to_return.connect(_on_lingering_ready_to_return)
	if not customer.lingering_departed.is_connected(_on_lingering_departed):
		customer.lingering_departed.connect(_on_lingering_departed)

	InventoryManager.decrement_cooldown()
	LogManager.info("CustomerSpawner", "%s is lingering in the background (slot freed)." % customer.get_order_hud_key())
	customer.enter_lingering_mode(_get_background_hangout_points())

	# If freeing this visitor's slot emptied the counter, close out the wave & trigger soft timeskip
	if not has_any_counter_customer():
		StoryManager.clock.on_customer_dismissed()
		_on_wave_cleared()
	else:
		_promote_earliest_side_customer_to_center()
		_try_return_waiting_lingering_visitor()

func _on_lingering_ready_to_return(customer: Customer) -> void:
	if not is_instance_valid(customer) or customer._is_resolving:
		return

	if StoryManager.is_past_closing_time() or is_paused:
		customer.leave_from_lingering()
		return

	if randf() >= SMALLTALK_RETURN_CHANCE:
		LogManager.info("CustomerSpawner", "Lingering visitor %s leaving directly from background." % customer.get_order_hud_key())
		customer.leave_from_lingering()
		return

	var open_slot := _find_open_slot_for_lingering()
	if open_slot != -1 and not _is_exclusive_wave and not _is_transitioning_wave:
		_bring_lingering_visitor_to_counter(customer, open_slot)
		return

	# Counter is currently full or transitioning — wait in the tambayan for the next open slot!
	customer.set_meta("ready_to_return_for_smalltalk", true)
	LogManager.info("CustomerSpawner", "Lingering visitor %s waiting for an open counter slot to return for smalltalk." % customer.get_order_hud_key())
	_expire_waiting_lingering_visitor(customer)

func _expire_waiting_lingering_visitor(customer: Customer) -> void:
	await get_tree().create_timer(16.0).timeout
	if not is_instance_valid(customer) or not is_inside_tree() or customer._is_resolving:
		return
	if customer.is_lingering_visitor and customer.get_meta("ready_to_return_for_smalltalk", false):
		customer.set_meta("ready_to_return_for_smalltalk", false)
		LogManager.info("CustomerSpawner", "Lingering visitor %s waited too long for a slot and is heading home." % customer.get_order_hud_key())
		customer.leave_from_lingering()

func _try_return_waiting_lingering_visitor() -> bool:
	if StoryManager.is_past_closing_time() or _is_exclusive_wave or is_paused:
		return false
	var returned_any := false
	for v in lingering_visitors.duplicate():
		if not is_instance_valid(v) or not v.is_lingering_visitor or v._is_resolving:
			continue
		if not v.get_meta("ready_to_return_for_smalltalk", false):
			continue
		var open_slot := _find_open_slot_for_lingering()
		if open_slot == -1:
			break
		_bring_lingering_visitor_to_counter(v, open_slot)
		returned_any = true
	return returned_any

func _bring_lingering_visitor_to_counter(customer: Customer, open_slot: int) -> void:
	customer.set_meta("ready_to_return_for_smalltalk", false)
	var pos_data := _calculate_positions(false, open_slot)
	var slot_target: Vector3 = pos_data.primary_target
	if customer.customer_data and customer.customer_data.get_clean_id() == "kuyakap":
		var dir_back: Vector3 = (pos_data.spawn_pos - pos_data.target_pos).normalized()
		slot_target += dir_back * 0.7
	counter_slots[open_slot] = customer
	_next_arrival_order += 1
	customer.arrival_order = _next_arrival_order

	# Bench Lv. 3: chance for a lingering visitor to return with a real purchase order (then leave after!)
	if StoryManager.can_bench_return_to_buy() and randf() < LINGERING_RETURN_BUY_CHANCE:
		var buy_tx := TransactionBuilder.build_lingering_purchase_transaction(StoryManager, customer.customer_data)
		if buy_tx != null:
			lingering_visitors.erase(customer)
			StoryManager.record_daily_stat_int("returning_buyers", 1)
			LogManager.info("CustomerSpawner", "Lingering visitor %s returning to Slot %d to BUY (%d item(s))!" % [
				customer.get_order_hud_key(), open_slot, buy_tx.desired_items.size()
			])
			customer.return_to_counter_for_purchase(open_slot, slot_target, buy_tx)
			return

	LogManager.info("CustomerSpawner", "Lingering visitor %s returning to Slot %d for smalltalk." % [customer.get_order_hud_key(), open_slot])
	customer.return_to_counter_for_smalltalk(open_slot, slot_target)

func _on_lingering_departed(customer: Customer) -> void:
	lingering_visitors.erase(customer)
	var was_on_counter: bool = _lingering_counter_departures.erase(customer)
	for i in range(counter_slots.size()):
		if counter_slots[i] == customer:
			counter_slots[i] = null
			was_on_counter = true
			break
	if session.current_customer == customer:
		session.current_customer = null
	if was_on_counter:
		if _leaving_customers_count > 0:
			_leaving_customers_count = maxi(0, _leaving_customers_count - 1)
		if has_any_counter_customer():
			_promote_earliest_side_customer_to_center()
			_try_return_waiting_lingering_visitor()
		elif _leaving_customers_count == 0:
			StoryManager.clock.on_customer_dismissed()
			_on_wave_cleared()

func _dismiss_all_lingering_visitors() -> void:
	var to_leave := lingering_visitors.duplicate()
	for v in to_leave:
		if is_instance_valid(v):
			v.leave_from_lingering()
	lingering_visitors.clear()

# ── Ambient Pass-By / Fly-By Cameos ──────────────────────────────────────────

const CAMEO_STORY_PARTNERS: Dictionary = {
	"lolopilo": ["tk"],
	"tk": ["lolopilo"],
	"kuyakap": ["buboy", "manangana"],
	"buboy": ["kuyakap", "manangana"],
	"manangana": ["kuyakap", "buboy"],
	"brahim": ["danilo", "rosalyn"],
	"danilo": ["brahim", "rosalyn"],
	"rosalyn": ["danilo", "brahim"],
	"rodel": ["sarimanok"],
	"sarimanok": ["rodel"],
}

func _schedule_next_ambient_cameo() -> void:
	_ambient_cameo_session_id += 1
	var my_session := _ambient_cameo_session_id
	_run_ambient_cameo_loop(my_session)

func _run_ambient_cameo_loop(my_session: int) -> void:
	while is_inside_tree() and my_session == _ambient_cameo_session_id:
		var traffic_scale: float = StoryManager.get_foot_traffic_time_scale() if is_instance_valid(StoryManager) else 1.0
		var wait_s := randf_range(AMBIENT_CAMEO_MIN_INTERVAL, AMBIENT_CAMEO_MAX_INTERVAL) * clampf(traffic_scale, 0.60, 1.45)
		await get_tree().create_timer(wait_s).timeout
		if not is_inside_tree() or my_session != _ambient_cameo_session_id:
			return
		# Scale trigger chance & burst size dynamically with active Foot Traffic / Events
		var eff_trigger := clampf(AMBIENT_CAMEO_TRIGGER_CHANCE / maxf(0.55, traffic_scale), 0.35, 0.92)
		if randf() > eff_trigger:
			continue
		var busy_bonus := clampf((1.0 - traffic_scale) * 0.35, -0.07, 0.12)
		var pair_thresh := clampf(0.66 - busy_bonus, 0.54, 0.73)
		var triple_thresh := clampf(0.91 - busy_bonus * 0.5, 0.84, 0.95)
		var roll := randf()
		var burst_count := 1
		if roll >= triple_thresh:
			burst_count = 3
		elif roll >= pair_thresh:
			burst_count = 2
		_spawn_ambient_cameo_burst(my_session, burst_count)

func _spawn_ambient_cameo_burst(my_session: int, count: int) -> void:
	var shared_ltr: bool = randf() < 0.5
	# Distinct street depth lanes (-further into street, +closer to curb) so cameos never stack on one Z rail
	var depth_lanes: Array[float] = [-2.4, -0.9, 0.55]
	depth_lanes.shuffle()
	var lead_depth: float = depth_lanes[0] + randf_range(-0.35, 0.35)
	var lead_data: CustomerData = _try_spawn_ambient_cameo(null, true, shared_ltr, lead_depth)
	if lead_data == null:
		return

	# Keep solo rolls genuinely solo (~88% of triggers); on multi-person bursts, mix independent
	# passersby with occasional story-connected buddy strolls, staggered 1-2s per character.
	var forced_partner: CustomerData = _pick_connected_cameo_partner(lead_data) if (count >= 2 and randf() < 0.38) else null

	for i in range(1, count):
		var partner_for_slot: CustomerData = forced_partner if i == 1 else null
		var delay_s := randf_range(0.95, 1.85) if partner_for_slot != null else randf_range(1.10, 2.35)
		await get_tree().create_timer(delay_s).timeout
		if not is_inside_tree() or my_session != _ambient_cameo_session_id:
			return
		var use_same_dir := true if partner_for_slot != null else (randf() < 0.5)
		var slot_ltr := shared_ltr if use_same_dir else (not shared_ltr)
		var depth_nudge: float
		if partner_for_slot != null:
			# Connected buddies walk slightly staggered alongside each other (0.85m..1.35m deeper)
			depth_nudge = lead_depth - randf_range(0.85, 1.35)
		else:
			var lane_base: float = depth_lanes[i % depth_lanes.size()]
			depth_nudge = lane_base + randf_range(-0.40, 0.40)
		_try_spawn_ambient_cameo(partner_for_slot, true, slot_ltr, depth_nudge)

func _get_eligible_cameo_candidates() -> Array[CustomerData]:
	_ambient_cameos = _ambient_cameos.filter(func(c): return is_instance_valid(c))
	var blocked_paths := get_present_character_paths()
	for cam in _ambient_cameos:
		if cam.customer_data and not (cam.customer_data.resource_path in blocked_paths):
			blocked_paths.append(cam.customer_data.resource_path)

	var candidates: Array[CustomerData] = []
	for char_data in StoryManager.available_characters:
		if char_data == null or char_data.ambient_cameo_motions.is_empty():
			continue
		if char_data.is_collector():
			if not StoryManager.is_daytime_mayari_unlocked():
				continue
		elif char_data.unlock_tier > StoryManager.current_tier:
			continue
		if char_data.resource_path in blocked_paths:
			continue
		candidates.append(char_data)
	return candidates

func _pick_connected_cameo_partner(lead: CustomerData) -> CustomerData:
	if lead == null or not is_instance_valid(CharacterProgressionManager):
		return null
	var lead_id := lead.get_clean_id()
	if not CAMEO_STORY_PARTNERS.has(lead_id):
		return null
	# Require at least one of the pair to have started their story so relationship cameos feel earned
	var lead_ch := CharacterProgressionManager.get_chapter(lead.resource_path)
	var partner_ids: Array = CAMEO_STORY_PARTNERS[lead_id]
	var candidates := _get_eligible_cameo_candidates()
	var valid_partners: Array[CustomerData] = []
	for cand in candidates:
		if cand.get_clean_id() in partner_ids:
			var cand_ch := CharacterProgressionManager.get_chapter(cand.resource_path)
			if lead_ch >= 1 or cand_ch >= 1:
				valid_partners.append(cand)
	if valid_partners.is_empty():
		return null
	return valid_partners.pick_random()

func _pick_weighted_cameo_candidate(candidates: Array[CustomerData]) -> CustomerData:
	if candidates.is_empty():
		return null
	var eerie_active := false
	if is_instance_valid(StoreEventManager):
		for ev in StoreEventManager.get_all_active_events():
			if ev and (ev.event_id in ["aswang_curfew_rumor", "kapre_cigar_fog", "biringan_silver_mist", "duwende_penny_trail"]):
				eerie_active = true
				break

	var weights: Array[float] = []
	var total_w: float = 0.0
	for c in candidates:
		var w: float = maxf(0.2, c.spawn_weight)
		# #2 Diegetic Gameplay Tell: Today's Expected Visitors appear 3.0x more often on the street!
		if is_instance_valid(StoryManager) and (c.resource_path in StoryManager.todays_expected_regulars):
			w *= 3.0
		if eerie_active and (c.get_clean_id() in ["rosalyn", "manangana", "reynamayari", "lolopilo", "brahim"]):
			w *= 2.2
		weights.append(w)
		total_w += w

	var r := randf() * total_w
	var acc := 0.0
	for i in range(candidates.size()):
		acc += weights[i]
		if r <= acc:
			return candidates[i]
	return candidates.back()

func _profile_naturally_left_to_right(cameo_profile: Resource) -> bool:
	if cameo_profile == null:
		return true
	if bool(cameo_profile.get("override_start_anchor")):
		var sa := int(cameo_profile.get("start_anchor"))
		# Anchor 5 = STREET_LEFT (travels Left -> Right), Anchor 6 = STREET_RIGHT (travels Right -> Left)
		if sa == 6:
			return false
		if sa == 5:
			return true
	return true

func _try_spawn_ambient_cameo(
	forced_char: CustomerData = null,
	use_explicit_dir: bool = false,
	want_left_to_right: bool = true,
	extra_depth_offset: float = 0.0
) -> CustomerData:
	_ambient_cameos = _ambient_cameos.filter(func(c): return is_instance_valid(c))
	if _ambient_cameos.size() >= MAX_ACTIVE_AMBIENT_CAMEOS:
		return null
	if is_paused or _is_exclusive_wave or StoryManager.is_past_closing_time():
		return null
	var pos_data := _calculate_positions(false, 0)
	if pos_data.is_empty():
		return null

	var candidates := _get_eligible_cameo_candidates()
	if candidates.is_empty():
		return null

	var chosen: CustomerData = null
	if forced_char != null and (forced_char in candidates):
		chosen = forced_char
	else:
		chosen = _pick_weighted_cameo_candidate(candidates)
	if chosen == null:
		return null

	var cameo_profile := chosen.pick_ambient_cameo_motion()
	if cameo_profile == null:
		return null

	var target_ltr := want_left_to_right if use_explicit_dir else (randf() < 0.5)
	var natural_ltr := _profile_naturally_left_to_right(cameo_profile)
	var mirror_lateral := (natural_ltr != target_ltr)

	var eff_depth := 0.0 if cameo_profile.resource_path.contains("pass_through") else extra_depth_offset
	var cameo: Customer = customer_scene.instantiate()
	get_parent().add_child(cameo)
	cameo.global_position = pos_data.spawn_pos
	cameo.setup_ambient_cameo(
		chosen,
		cameo_profile,
		pos_data.spawn_pos,
		pos_data.target_pos,
		pos_data.exit_pos,
		mirror_lateral,
		eff_depth
	)
	_ambient_cameos.append(cameo)
	return chosen

func _clear_ambient_cameos() -> void:
	_ambient_cameo_session_id += 1
	for cam in _ambient_cameos:
		if is_instance_valid(cam):
			cam.queue_free()
	_ambient_cameos.clear()

# ── Interaction & Session Forwarding ─────────────────────────────────────────

func _process(delta: float) -> void:
	session.update_watchdog(delta)
	var passive_xp := StoryManager.get_bench_passive_xp()
	if passive_xp > 0 and not is_paused and not StoryManager.is_past_closing_time():
		var active_visitors: Array[Node3D] = []
		for v in lingering_visitors:
			if is_instance_valid(v) and v.is_lingering_visitor and not v._is_resolving:
				active_visitors.append(v)
		if not active_visitors.is_empty():
			_linger_xp_timer += delta
			if _linger_xp_timer >= LINGERING_PASSIVE_XP_INTERVAL:
				_linger_xp_timer -= LINGERING_PASSIVE_XP_INTERVAL
				for i in range(active_visitors.size()):
					var visitor: Node3D = active_visitors[i]
					if i == 0:
						var gained: int = StoryManager.add_player_xp(passive_xp, "Tambayan")
						if gained > 0:
							VisualEffectManager.spawn_floating_xp(visitor, gained)
					else:
						get_tree().create_timer(0.18 * float(i)).timeout.connect(func():
							if is_instance_valid(visitor) and visitor.is_lingering_visitor and not visitor._is_resolving:
								var gained: int = StoryManager.add_player_xp(passive_xp, "Tambayan")
								if gained > 0:
									VisualEffectManager.spawn_floating_xp(visitor, gained)
						)
		else:
			_linger_xp_timer = 0.0
	else:
		_linger_xp_timer = 0.0

func _on_customer_arrived(customer: Customer) -> void:
	EventBus.customer_arrived.emit(customer)
	session.on_customer_arrived(customer)
	if is_instance_valid(customer) and customer.has_been_greeted and customer.transaction_context and not customer.transaction_context.desired_items.is_empty() and not customer.is_returning_for_smalltalk:
		EventBus.customer_order_updated.emit(customer.get_order_hud_key(), customer.transaction_context.desired_items, customer.transaction_context.is_riddle)

func _on_customer_finished(customer: Customer) -> void:
	session.on_item_delivered(customer, true)

func _on_customer_clicked(customer: Customer) -> void:
	session.on_customer_clicked(customer, _is_nokia_open)

func _on_guest_clicked(_guest: Customer) -> void:
	if is_instance_valid(current_customer):
		session.on_customer_clicked(current_customer, _is_nokia_open)

func _on_dialogic_signal(argument: String) -> void:
	session.on_dialogic_signal(argument)

func _on_customer_partial_satisfaction(customer: Customer) -> void:
	session.on_item_delivered(customer, false)

func start_dialogue(timeline, customer: Customer, phase: TransactionSession.Phase = TransactionSession.Phase.NONE, label: String = "") -> void:
	session.start_dialogue(timeline, customer, phase, label)

func _on_dialogue_ended() -> void:
	session.on_dialogue_ended()

func _on_customer_item_offered(customer: Customer, item: DraggableItem, drop_pos: Vector3) -> void:
	session.process_item_placed(item, drop_pos, customer)

func _on_tray_item_placed(item: DraggableItem, tray_pos: Vector3) -> void:
	session.process_item_placed(item, tray_pos, current_customer)

# ── Closing Time & Mayari ────────────────────────────────────────────────────

func _on_closing_time_reached() -> void:
	_dismiss_all_lingering_visitors()
	_clear_ambient_cameos()
	# If time hit 8 PM and no one is at the counter, spawn Mayari immediately.
	if not has_any_counter_customer() and not _is_spawning:
		spawn_mayari_for_collection()

func spawn_mayari_for_collection() -> void:
	if _is_spawning or has_any_counter_customer():
		return

	_dismiss_all_lingering_visitors()
	_is_spawning = true
	_wave_id += 1
	_is_exclusive_wave = true

	# Ensure tonight's quota is always calculated and synced to Dialogic before Mayari spawns
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm:
		gm.prepare_nightly_quota()

	# Request the special collection transaction from StoryManager
	var transaction = StoryManager.get_collection_transaction()
	if transaction == null:
		_is_spawning = false
		_end_day()
		return

	LogManager.info("Customer", "Incoming Debt Collection: Character=Reyna Mayari, Type=VISIT (Collection)")

	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree():
		_is_spawning = false
		return

	var spawn_global: Vector3 = get_node(spawn_pos).global_position
	var target_global: Vector3 = get_node(target_pos).global_position

	var mayari := _create_customer(transaction, spawn_global, target_global)
	mayari.slot_index = 0
	counter_slots[0] = mayari
	session.current_customer = mayari

	if is_instance_valid(AudioManager):
		AudioManager.set_mayari_present(true)
		mayari.tree_exiting.connect(func():
			if is_instance_valid(AudioManager):
				AudioManager.set_mayari_present(false)
		, CONNECT_ONE_SHOT)

	EventBus.customer_spawned.emit(mayari)
	_is_spawning = false

## Emit day_ended when no more customers will come today.
func _end_day() -> void:
	if _day_ended_emitted_for_day == StoryManager.day:
		return
	_day_ended_emitted_for_day = StoryManager.day
	EventBus.day_ended.emit(StoryManager.day)

func _on_nokia_opened() -> void:
	_is_nokia_open = true

func _on_nokia_closed() -> void:
	_is_nokia_open = false

# ── Persistence ──────────────────────────────────────────────────────────────

func get_save_id() -> String:
	return "customer_spawner"

func _is_completed_order(ctx: TransactionContext) -> bool:
	if ctx == null:
		return false
	if ctx.is_guided_tutorial or ctx.transaction_type == TransactionContext.Type.VISIT or ctx.is_visit_story:
		return false
	return ctx.original_count > 0 and ctx.desired_items.is_empty() and not ctx.delivered_items.is_empty()

func get_save_data() -> Dictionary:
	var data := {
		"max_unlocked_slots": max_unlocked_slots
	}
	var saved_slots: Array[Dictionary] = []

	for i in range(counter_slots.size()):
		var c := counter_slots[i]
		if not is_instance_valid(c) or not c.transaction_context:
			continue
		if c.is_lingering_visitor or c.is_returning_for_smalltalk or c.is_lingering_departure:
			continue
		if c.transaction_context.is_nightly_collection:
			continue
		var is_already_done: bool = c._is_resolving \
			or c.dialogue_phase == TransactionSession.Phase.SATISFIED \
			or _is_completed_order(c.transaction_context)
		if not is_already_done:
			saved_slots.append({
				"slot": i,
				"ctx": c.transaction_context.to_dict(),
				"greeted": c.has_been_greeted
			})

	if not saved_slots.is_empty():
		data["slots"] = saved_slots

	if is_instance_valid(guest_customer) and guest_customer.transaction_context:
		if not guest_customer._is_resolving:
			data["guest_customer"] = guest_customer.transaction_context.to_dict()
			data["guest_greeted"] = guest_customer.has_been_greeted

	return data

func load_save_data(data: Dictionary) -> void:
	_dialogue_phase = DialoguePhase.NONE
	session._greeting_interrupted = false
	_pending_restore_slots.clear()

	max_unlocked_slots = StoryManager.get_max_counter_slots()

	# New multi-slot save format
	if data.has("slots") and data["slots"] is Array:
		for entry in data["slots"]:
			if not (entry is Dictionary) or not entry.has("ctx"):
				continue
			var ctx := TransactionContext.from_dict(entry["ctx"])
			if ctx and ctx.customer_data and not _is_completed_order(ctx):
				_pending_restore_slots.append({
					"slot": int(entry.get("slot", 0)),
					"ctx": ctx,
					"greeted": bool(entry.get("greeted", false))
				})
	# Backward compatibility for legacy single-customer saves
	elif data.has("current_customer"):
		var ctx := TransactionContext.from_dict(data["current_customer"])
		if ctx and ctx.customer_data:
			if _is_completed_order(ctx):
				LogManager.info("CustomerSpawner", "Skipping already-completed restored customer (%s); spawning next." % ctx.customer_data.character_name)
				StoryManager.clock.is_customer_present = false
				StoryManager.clock.wait_limit_time = -1.0
				StoryManager.clock.was_paused_by_limit = false
			else:
				_pending_restore_slots.append({
					"slot": 0,
					"ctx": ctx,
					"greeted": bool(data.get("current_greeted", false))
				})

	if not _pending_restore_slots.is_empty():
		LogManager.info("CustomerSpawner", "Queuing %d restored customer(s) for fresh walk-in." % _pending_restore_slots.size())
		get_tree().create_timer(1.0).timeout.connect(_spawn_next_customer)
		return

	# If no active customer was at the counter at save time, resume spawning or closing sequence
	if not StoryManager.is_past_closing_time():
		get_tree().create_timer(1.0).timeout.connect(_spawn_next_customer)
	elif not StoryManager.has_mayari_visited:
		get_tree().create_timer(1.0).timeout.connect(spawn_mayari_for_collection)
	else:
		LogManager.info("CustomerSpawner", "Loaded past closing time with Mayari already visited. Triggering end-of-day transition.")
		get_tree().create_timer(1.0).timeout.connect(_end_day)

func reset_state() -> void:
	_pending_restore_slots.clear()
	_wave_id += 1
	_is_exclusive_wave = false
	_is_transitioning_wave = false
	_leaving_customers_count = 0
	_lingering_counter_departures.clear()
	for i in range(counter_slots.size()):
		counter_slots[i] = null
	lingering_visitors.clear()
	_clear_ambient_cameos()
	session.current_customer = null
	guest_customer = null
	_is_spawning = false
	_dialogue_phase = DialoguePhase.NONE
	session._greeting_interrupted = false
	max_unlocked_slots = StoryManager.get_max_counter_slots()
	LogManager.info("CustomerSpawner", "State reset for New Game.")

func _create_customer(transaction: TransactionContext, spawn: Vector3, target: Vector3, exit: Vector3 = Vector3.ZERO) -> Customer:
	var customer: Customer = customer_scene.instantiate()
	get_parent().add_child(customer)
	customer.global_position = spawn
	customer.setup(transaction, target, exit)
	customer.arrived.connect(_on_customer_arrived)
	customer.clicked.connect(_on_customer_clicked)
	customer.satisfied.connect(_on_customer_finished)
	customer.started_leaving.connect(_on_customer_started_leaving)
	return customer

func _on_character_speaking(data: CustomerData) -> void:
	if not data:
		return

	var target_id := data.get_clean_id()
	var candidates: Array[Customer] = []
	for c in counter_slots:
		if is_instance_valid(c):
			candidates.append(c)
	if is_instance_valid(guest_customer):
		candidates.append(guest_customer)

	for c in candidates:
		if c.customer_data and c.customer_data.get_clean_id() == target_id:
			c.play_speak_animation()
