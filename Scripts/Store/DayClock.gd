class_name DayClock
extends RefCounted

## Manages in-game time (5:00 AM to 12:00 AM Midnight), customer wait limits,
## closing-time signals, and TimeOfDay sky/shadow updates.

const DAY_START_HOUR := 5.0
const MENU_THEME_HOUR := 16.89 ## Golden hour aesthetic for Main Menu
const CLOSING_HOUR   := 20.0  ## 8 PM — no new customers after this
const HARD_STOP_HOUR := 24.0  ## Midnight — absolute time limit
const CLOCK_SPEED_HOURS_PER_SEC := 1.0 / 50.0

var current_display_time: float = MENU_THEME_HOUR
var is_clock_running: bool = false
var is_customer_present: bool = false
var wait_limit_time: float = -1.0
var was_paused_by_limit: bool = false

var _time_of_day_node: Node = null
var _tree_owner: Node = null

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

func on_day_started() -> void:
	is_customer_present = false
	wait_limit_time = -1.0
	was_paused_by_limit = false
	current_display_time = DAY_START_HOUR
	_ensure_tod_node()
	apply_display_time(DAY_START_HOUR)
	set_clock_running(true)

func on_customer_arrived() -> void:
	is_customer_present = true
	if wait_limit_time < 0 and not was_paused_by_limit:
		wait_limit_time = current_display_time + 4.0
		LogManager.debug("DayClock", "Customer arrived. Patience limit set to %.2f" % wait_limit_time)
	else:
		LogManager.info("DayClock", "Customer arrived (Restore). Preserving patience state (Limit: %.2f, Paused: %s)" % [wait_limit_time, str(was_paused_by_limit)])

func on_customer_dismissed() -> void:
	is_customer_present = false
	if current_display_time >= CLOSING_HOUR:
		if is_clock_running:
			set_clock_running(false)
			LogManager.info("DayClock", "Grace period ended. Pausing clock for Closing Time.")
		if current_display_time > HARD_STOP_HOUR:
			current_display_time = HARD_STOP_HOUR
			apply_display_time(HARD_STOP_HOUR)
		EventBus.closing_time_reached.emit()
	elif was_paused_by_limit:
		set_clock_running(true)
		LogManager.info("DayClock", "Customer left. Resuming clock.")
	was_paused_by_limit = false
	wait_limit_time = -1.0

func is_past_closing_time() -> bool:
	return current_display_time >= CLOSING_HOUR

func reset_to_morning() -> void:
	current_display_time = DAY_START_HOUR
	set_clock_running(true)

func reset_state() -> void:
	current_display_time = DAY_START_HOUR
	wait_limit_time = -1.0
	was_paused_by_limit = false
	is_customer_present = false
	set_clock_running(false)

func _on_tod_time_changed(t: float) -> void:
	current_display_time = t
	
	# 1. Customer Wait Limit: Pause time if someone's been here for 4 hours
	if wait_limit_time > 0 and current_display_time >= wait_limit_time:
		if is_clock_running:
			LogManager.info("DayClock", "Customer wait limit reached (+4h). Pausing clock.")
			set_clock_running(false)
			was_paused_by_limit = true
		wait_limit_time = -1.0
		
	# 2. Hard Stop Limit: Never go past Midnight
	if current_display_time >= HARD_STOP_HOUR:
		if is_clock_running:
			LogManager.info("DayClock", "Midnight reached. Hard pausing clock.")
			set_clock_running(false)
		current_display_time = HARD_STOP_HOUR
		apply_display_time(HARD_STOP_HOUR)
		if not is_customer_present:
			EventBus.closing_time_reached.emit()
		return

	# 3. End of day check: strictly cap at CLOSING_HOUR ONLY if no customer is present
	if current_display_time >= CLOSING_HOUR and not is_customer_present:
		if is_clock_running:
			LogManager.info("DayClock", "Closing Time Reached (8 PM). Pausing clock.")
			set_clock_running(false)
			current_display_time = CLOSING_HOUR
			apply_display_time(CLOSING_HOUR)
			EventBus.closing_time_reached.emit()
		elif current_display_time > CLOSING_HOUR:
			current_display_time = CLOSING_HOUR
			apply_display_time(CLOSING_HOUR)

func apply_display_time(t: float) -> void:
	if not _time_of_day_node or not is_instance_valid(_tree_owner):
		return
	var tree = _tree_owner.get_tree()
	if tree.current_scene and tree.current_scene.name == "MainMenu":
		return
	var h: int = int(t)
	var m: int = int((t - h) * 60.0)
	_time_of_day_node.set_time(h, m, 0)

func _ensure_tod_node() -> void:
	if not is_instance_valid(_tree_owner):
		return
	if not is_instance_valid(_time_of_day_node):
		_time_of_day_node = _tree_owner.get_tree().root.find_child("TimeOfDay", true, false)
		if is_instance_valid(_time_of_day_node):
			var tree = _tree_owner.get_tree()
			if tree.current_scene and tree.current_scene.name == "MainMenu":
				var h: int = int(MENU_THEME_HOUR)
				var m: int = int((MENU_THEME_HOUR - h) * 60.0)
				_time_of_day_node.set_time(h, m, 0)
				_time_of_day_node.game_time_enabled = false
			if not _time_of_day_node.time_changed.is_connected(_on_tod_time_changed):
				_time_of_day_node.time_changed.connect(_on_tod_time_changed)

