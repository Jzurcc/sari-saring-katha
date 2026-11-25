class_name DayClock
extends RefCounted

## Manages in-game time (5:00 AM to 12:00 AM Midnight), customer wait limits,
## closing-time signals, and TimeOfDay sky/shadow updates.

signal fast_forward_finished

const DAY_START_HOUR := 5.0
const MENU_THEME_HOUR := 16.89 ## Golden hour aesthetic for Main Menu
const CLOSING_HOUR   := 20.0  ## 8 PM — no new customers after this
const HARD_STOP_HOUR := 23.95 ## 11:57 PM — stops safely before Sky3D's 24.0 -> 0.0 wraparound
const CLOCK_SPEED_HOURS_PER_SEC := 1.0 / 50.0
const CUSTOMER_TIME_WINDOW_HOURS := 4.0
const VISIT_TIME_WINDOW_HOURS := 2.0

var current_display_time: float = MENU_THEME_HOUR
var is_clock_running: bool = false
var is_customer_present: bool = false
var wait_limit_time: float = -1.0
var active_time_window_hours: float = CUSTOMER_TIME_WINDOW_HOURS
var was_paused_by_limit: bool = false

var _time_of_day_node: Node = null
var _tree_owner: Node = null
var _fast_forward_tween: Tween = null
var _is_fast_forwarding: bool = false
var _fast_forward_target: float = -1.0

func setup(owner_node: Node) -> void:
	_tree_owner = owner_node
	_ensure_tod_node()
	if _time_of_day_node and not _time_of_day_node.time_changed.is_connected(_on_tod_time_changed):
		_time_of_day_node.time_changed.connect(_on_tod_time_changed)

func set_clock_running(value: bool) -> void:
	is_clock_running = value
	_ensure_tod_node()
	if _time_of_day_node and is_instance_valid(_tree_owner):
		var tree = _tree_owner.get_tree()
		var in_menu = tree.current_scene and tree.current_scene.name == "MainMenu"
		_time_of_day_node.game_time_enabled = is_clock_running and not in_menu

func get_customer_time_window_hours() -> float:
	if is_instance_valid(_tree_owner) and _tree_owner.has_method("get_customer_time_window_hours"):
		return _tree_owner.get_customer_time_window_hours()
	return CUSTOMER_TIME_WINDOW_HOURS

func get_visit_time_window_hours() -> float:
	if is_instance_valid(_tree_owner) and _tree_owner.has_method("get_visit_time_window_hours"):
		return _tree_owner.get_visit_time_window_hours()
	return VISIT_TIME_WINDOW_HOURS

func on_day_started() -> void:
	_cancel_fast_forward(false)
	is_customer_present = false
	wait_limit_time = -1.0
	active_time_window_hours = get_customer_time_window_hours()
	was_paused_by_limit = false
	current_display_time = DAY_START_HOUR
	_ensure_tod_node()
	apply_display_time(DAY_START_HOUR)
	set_clock_running(true)

func on_customer_arrived(is_visit: bool = false) -> void:
	if _is_fast_forwarding:
		_cancel_fast_forward(true)
	is_customer_present = true
	if wait_limit_time < 0 and not was_paused_by_limit:
		active_time_window_hours = get_visit_time_window_hours() if is_visit else get_customer_time_window_hours()
		wait_limit_time = minf(current_display_time + active_time_window_hours, HARD_STOP_HOUR)
	else:
		LogManager.info("DayClock", "Customer arrived (Restore). Preserving patience state (Limit: %.2f, Window: %.2fh, Paused: %s)" % [
			wait_limit_time, active_time_window_hours, str(was_paused_by_limit)
		])

func is_fast_forwarding() -> bool:
	return _is_fast_forwarding

func get_closing_hour() -> float:
	if is_instance_valid(_tree_owner) and _tree_owner.has_method("get_effective_closing_hour"):
		return _tree_owner.get_effective_closing_hour()
	return CLOSING_HOUR

func on_customer_dismissed() -> void:
	is_customer_present = false
	var closing := get_closing_hour()
	var limit_time := wait_limit_time
	var window_hours := active_time_window_hours
	var was_paused := was_paused_by_limit
	was_paused_by_limit = false
	wait_limit_time = -1.0
	active_time_window_hours = get_customer_time_window_hours()

	if is_past_closing_time():
		if is_clock_running:
			set_clock_running(false)
			LogManager.info("DayClock", "Grace period ended. Pausing clock for Closing Time (%.1fh)." % closing)
		if current_display_time > HARD_STOP_HOUR or current_display_time < DAY_START_HOUR:
			current_display_time = HARD_STOP_HOUR
			apply_display_time(HARD_STOP_HOUR)
		EventBus.closing_time_reached.emit()
		return

	if was_paused:
		set_clock_running(true)
		return

	if limit_time > 0.0:
		var traffic_scale := 1.0
		if is_instance_valid(_tree_owner) and _tree_owner.has_method("get_foot_traffic_time_scale"):
			traffic_scale = _tree_owner.get_foot_traffic_time_scale()
		var fast_forward_hours := (window_hours / 2.0) * traffic_scale
		var half_window_target := limit_time - (window_hours - fast_forward_hours)
		var clamped_target := minf(half_window_target, closing)
		if clamped_target > current_display_time + 0.02:
			_start_fast_forward(clamped_target)

func _start_fast_forward(target_time: float) -> void:
	_cancel_fast_forward(false)
	if not is_instance_valid(_tree_owner) or not _tree_owner.is_inside_tree():
		current_display_time = target_time
		apply_display_time(target_time)
		return

	var start_time := current_display_time
	var remaining := target_time - start_time
	var duration := clampf(remaining * 1.6, 1.5, 3.5)

	_is_fast_forwarding = true
	_fast_forward_target = target_time
	set_clock_running(false)

	LogManager.info("DayClock", "Customer finished early. Easing time %.2f -> %.2f over %.2fs." % [start_time, target_time, duration])

	_fast_forward_tween = _tree_owner.create_tween()
	_fast_forward_tween.tween_method(_apply_fast_forward_time, start_time, target_time, duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	_fast_forward_tween.tween_callback(_on_fast_forward_finished.bind(target_time))

func _apply_fast_forward_time(t: float) -> void:
	current_display_time = t
	apply_display_time(t)

func _on_fast_forward_finished(target_time: float) -> void:
	_is_fast_forwarding = false
	_fast_forward_target = -1.0
	_fast_forward_tween = null
	current_display_time = target_time
	apply_display_time(target_time)

	var closing := get_closing_hour()
	if current_display_time >= closing:
		set_clock_running(false)
		if not is_customer_present:
			LogManager.info("DayClock", "Fast-forward reached Closing Time (%.1fh). Pausing clock." % closing)
			EventBus.closing_time_reached.emit()
	else:
		set_clock_running(true)
	fast_forward_finished.emit()

func _cancel_fast_forward(snap_to_target: bool) -> void:
	var was_running := _is_fast_forwarding
	if _fast_forward_tween and _fast_forward_tween.is_valid():
		_fast_forward_tween.kill()
	_fast_forward_tween = null
	if _is_fast_forwarding and snap_to_target and _fast_forward_target > current_display_time:
		current_display_time = _fast_forward_target
		apply_display_time(current_display_time)
		set_clock_running(current_display_time < get_closing_hour())
	_is_fast_forwarding = false
	_fast_forward_target = -1.0
	if was_running:
		fast_forward_finished.emit()

func get_effective_display_time() -> float:
	if _is_fast_forwarding and _fast_forward_target > current_display_time:
		return _fast_forward_target
	return current_display_time

func is_past_closing_time() -> bool:
	var t := get_effective_display_time()
	return t >= get_closing_hour() or t < DAY_START_HOUR

func reset_to_morning() -> void:
	_cancel_fast_forward(false)
	current_display_time = DAY_START_HOUR
	set_clock_running(true)

func reset_state() -> void:
	_cancel_fast_forward(false)
	current_display_time = DAY_START_HOUR
	wait_limit_time = -1.0
	active_time_window_hours = CUSTOMER_TIME_WINDOW_HOURS
	was_paused_by_limit = false
	is_customer_present = false
	set_clock_running(false)

func _on_tod_time_changed(t: float) -> void:
	if _is_fast_forwarding:
		return
	current_display_time = t
	
	# 1. Customer Wait Limit: Pause time if someone's been here for the active time window
	if wait_limit_time > 0 and current_display_time >= wait_limit_time:
		if is_clock_running:
			LogManager.info("DayClock", "Customer wait limit reached (+%.2fh). Pausing clock." % active_time_window_hours)
			set_clock_running(false)
			was_paused_by_limit = true
		wait_limit_time = -1.0
		
	# 2. Hard Stop Limit: Never wrap past Midnight (Sky3D wraps 24.0 -> 0.0, so t < DAY_START_HOUR is post-midnight)
	if current_display_time >= HARD_STOP_HOUR or current_display_time < DAY_START_HOUR:
		if is_clock_running:
			LogManager.info("DayClock", "Midnight reached. Hard pausing clock.")
			set_clock_running(false)
		current_display_time = HARD_STOP_HOUR
		apply_display_time(HARD_STOP_HOUR)
		if not is_customer_present:
			EventBus.closing_time_reached.emit()
		return

	# 3. End of day check: strictly cap at effective closing hour ONLY if no customer is present
	var closing := get_closing_hour()
	if current_display_time >= closing and not is_customer_present:
		if is_clock_running:
			LogManager.info("DayClock", "Closing Time Reached (%.1fh). Pausing clock." % closing)
			set_clock_running(false)
			current_display_time = closing
			apply_display_time(closing)
			EventBus.closing_time_reached.emit()
		elif current_display_time > closing:
			current_display_time = closing
			apply_display_time(closing)

func apply_display_time(t: float) -> void:
	_ensure_tod_node()
	if not is_instance_valid(_time_of_day_node) or not is_instance_valid(_tree_owner):
		return
	var tree = _tree_owner.get_tree()
	if tree.current_scene and tree.current_scene.name == "MainMenu":
		return
	var h: int = int(t)
	var m: int = int((t - h) * 60.0)
	var s: int = int((((t - h) * 60.0) - m) * 60.0)
	_time_of_day_node.set_time(h, m, s)

func _ensure_tod_node() -> void:
	if not is_instance_valid(_tree_owner):
		return
	if not is_instance_valid(_time_of_day_node) or not _time_of_day_node.is_inside_tree():
		var tree := _tree_owner.get_tree()
		if tree.current_scene:
			_time_of_day_node = tree.current_scene.find_child("TimeOfDay", true, false)
		if not is_instance_valid(_time_of_day_node):
			_time_of_day_node = tree.root.find_child("TimeOfDay", true, false)
		if is_instance_valid(_time_of_day_node):
			if tree.current_scene and tree.current_scene.name == "MainMenu":
				var h: int = int(MENU_THEME_HOUR)
				var m: int = int((MENU_THEME_HOUR - h) * 60.0)
				_time_of_day_node.set_time(h, m, 0)
				_time_of_day_node.game_time_enabled = false
			if not _time_of_day_node.time_changed.is_connected(_on_tod_time_changed):
				_time_of_day_node.time_changed.connect(_on_tod_time_changed)

