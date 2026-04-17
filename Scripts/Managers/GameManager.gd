extends Node
class_name GameManager

## Central manager for progression out of MainGame.gd

const MAX_DAYS := 7

@export var starting_money: float = 200.0
var money: float = 0.0
var day: int = 1
var _last_earning: float = 0.0
var _pending_quota: float = 0.0  # Quota for the day that just ended (cached before day increments)

var _is_waiting_for_tutorial_space := false

# --- Debt System ---
const DAILY_QUOTAS = {
	1: 50.0,
	2: 75.0,
	3: 100.0,
	4: 125.0,
	5: 150.0,
	6: 175.0,
	7: 200.0
}

func _ready() -> void:
	add_to_group("game_manager")
	
	# Load state before emitting money_changed
	_load_state()
	
	# Wait two frames so every node's _ready() — including CustomerSpawner's
	# signal connections — completes before we broadcast day_started.
	await get_tree().process_frame
	await get_tree().process_frame
	EventBus.money_changed.emit(money)
	
	EventBus.transaction_completed.connect(_on_transaction_completed)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.utang_accepted.connect(_on_utang_accepted)
	
	if not Dialogic.signal_event.is_connected(_on_dialogic_signal):
		Dialogic.signal_event.connect(_on_dialogic_signal)

	# Only reset to morning if we are on Day 1 and have no money (initial state)
	# or if we want to ensure Day 1 starts at 5 AM.
	# Otherwise, _load_state() and StoryManager's own loading will have restored the time.
	if day == 1 and money == starting_money:
		_reset_clock_to_morning()

	print("[GameManager] Started Day ", day)
	EventBus.day_started.emit(day)
	save_state() # Save immediately on startup/day start

func _on_transaction_completed(item: ItemData, was_correct: bool) -> void:
	if was_correct and item:
		_last_earning = item.get_final_price()
		money += _last_earning
		EventBus.money_changed.emit(money)
		save_state()
		print("[GameManager] Sold %s for %.2f (Base: %.2f, Price: %.2f). TOTAL: %.2f" % [
			item.item_name, _last_earning, item.price, item.get_final_price(), money
		])

func _on_utang_accepted(_customer: Customer) -> void:
	money -= _last_earning
	EventBus.money_changed.emit(money)
	print("[GameManager] Utang accepted! Reverted %.2f. New balance: %.2f" % [_last_earning, money])
	
	# Future: We could update a persistent Debt dictionary here if needed for more complex logic.
	# For now, Dialogic handles its own {Stats.Debt} variable via [set] events in the timeline.

func deduct_money(amount: float) -> void:
	if money >= amount:
		money -= amount
		EventBus.money_changed.emit(money)
		print("[GameManager] Spent %.2f. Remaining: %.2f" % [amount, money])
	else:
		print("[GameManager] Error: Tried to spend %.2f but only has %.2f!" % [amount, money])

func _on_day_ended(ended_day_number: int) -> void:
	print("[GameManager] Day %d ended!" % ended_day_number)
	
	# 2. Debt Collection Logic Setup — cache quota BEFORE day increments
	_pending_quota = DAILY_QUOTAS.get(ended_day_number, 0.0)
	var was_successful = money >= _pending_quota
	
	Dialogic.VAR.set_variable("Global.TodayQuota", _pending_quota)
	Dialogic.VAR.set_variable("Global.HasEnoughMoney", 1.0 if was_successful else 0.0)
	
	print("[GameManager] End of Day %d. Quota: %.2f, Money: %.2f, Success: %s" % [
		ended_day_number, _pending_quota, money, was_successful
	])
	
	# 4. Advance Day
	if day >= MAX_DAYS:
		print("[GameManager] Final day complete!")
		return
	
	day += 1
	_reset_clock_to_morning()
	EventBus.day_started.emit(day)

func _on_dialogic_signal(argument: String) -> void:
	if argument == "deduct_quota":
		# Use the cached quota from _on_day_ended to avoid the post-increment day value.
		var quota := _pending_quota
		var was_successful := money >= quota
		
		if was_successful:
			money -= quota
			EventBus.money_changed.emit(money)
			save_state()
			print("[GameManager] Quota met! Subtracted %.2f. New balance: %.2f" % [quota, money])
		else:
			print("[GameManager] Quota FAILED! Only had %.2f / %.2f (quota: %.2f)" % [money, quota, quota])
		
		EventBus.debt_quota_met.emit(was_successful)
	
	# --- Tutorial Camera Movements ---
	elif argument == "look_at_fridge":
		Dialogic.paused = true
		_is_waiting_for_tutorial_space = true
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("face_pos"):
			# Using updated coordinates for the fridge framing
			player.face_pos(Vector3(0.575, 2.335, -3.767), 0.6)
			
			# Flash white outline on the fridge (found via group)
			var door = get_tree().get_first_node_in_group("refrigerator_door")
			_flash_outline(door, 3.0)
			
	elif argument == "look_at_nokia":
		Dialogic.paused = true
		_is_waiting_for_tutorial_space = true
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("face_pos"):
			# Using requested coordinates: 2.143, 2.206, -0.198
			player.face_pos(Vector3(2.143, 2.206, -0.198), 0.6)
			
			# Flash white outline on the Nokia phone
			var nokia = get_tree().root.find_child("NokiaInteractable", true, false)
			_flash_outline(nokia, 3.0)

func _unhandled_input(event: InputEvent) -> void:
	# 1. Tutorial Space Handling: Resumes Dialogic after camera pan
	if _is_waiting_for_tutorial_space:
		if event.is_action_pressed("dialogic_default_action") or event.is_action_pressed("ui_accept"):
			_is_waiting_for_tutorial_space = false
			Dialogic.paused = false
			get_viewport().set_input_as_handled()
			return

	# 2. Debug Skip Day (L key)
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_L and not event.echo:
		print("[GameManager] DEBUG: Skip to next day triggered via L key")
		
		# End any current dialogue to prevent locking
		if Dialogic.current_timeline != null:
			Dialogic.end_timeline()
			
		# Despawn any active customers safely
		var customers = get_tree().get_nodes_in_group("customer")
		for c in customers:
			EventBus.customer_dismissed.emit(c)
			c.queue_free()
			
		# Trigger the normal end of day sequence
		_on_day_ended(day)

## Helper to highlight an object during the tutorial
func _flash_outline(node: Node, duration: float) -> void:
	if node and node.has_method("on_hover"):
		node.on_hover(true)
		await get_tree().create_timer(duration).timeout
		if is_instance_valid(node):
			node.on_hover(false)


func _reset_clock_to_morning() -> void:
	# Set the initial hour in StoryManager context
	StoryManager._current_display_time = StoryManager.DAY_START_HOUR

	# Configure the sky / TimeOfDay node
	var tod = get_tree().root.find_child("TimeOfDay", true, false)
	if tod and tod.has_method("set_time"):
		tod.system_sync = false
		tod.minutes_per_day = 10.0 # 25s/hour * 24h = 600s = 10m
		tod.set_time(int(StoryManager.DAY_START_HOUR), 0, 0)
	
	# Start the clock via StoryManager's managed property
	# This automatically sets tod.game_time_enabled = true
	StoryManager.is_clock_running = true


func save_state() -> void:
	var save_data = {
		"manager": {
			"money": money,
			"day": day
		}
	}
	SaveManager.save_game(save_data)

func _load_state() -> void:
	var save_data = SaveManager.load_game()
	if save_data.has("manager"):
		var m = save_data["manager"]
		money = m.get("money", starting_money)
		day = m.get("day", 1)
		print("[GameManager] State loaded. Money: %.2f, Day: %d" % [money, day])
	else:
		money = starting_money
		day = 1

func reset_state() -> void:
	money = starting_money
	day = 1
	_reset_clock_to_morning()
	save_state()
	print("[GameManager] State reset to defaults for New Game.")
