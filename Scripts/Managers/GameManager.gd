extends Node
class_name GameManager

## Central manager for progression out of MainGame.gd

const MAX_DAYS := 7

const RANDOM_QUOTES = [
	"Daig ng maagap ang masipag. (Promptness beats industriousness.)",
	"Kung may isinuksok, may madudukot. (If you saved something, you have something to pull out.)",
	"A sari-sari store is the heartbeat of the barangay.",
	"Small sachets, big dreams.",
	"The smell of fresh coffee in the morning is the best alarm clock.",
	"Patience is a virtue, especially when counting coins.",
	"Sa sari-sari store, bawal ang utang kung hindi ka kakilala.",
	"The best snack is the one shared with a friend."
]

@onready var sleep_overlay_scene = preload("res://Scenes/UI/SleepOverlay.tscn")

@export var starting_money: float = 200.0
var money: float = 0.0
var day: int = 1
var quota_day: int = 1
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
	EventBus.closing_time_reached.connect(_on_closing_time_reached)
	
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

func _on_transaction_completed(item: ItemData, was_correct: bool, wants_debt: bool, customer_path: String) -> void:
	if was_correct and item:
		_last_earning = item.get_final_price()
		
		# If the customer wants to pay via Utang (debt), they won't give us cash yet.
		# We record this in StoryManager so it persists.
		if wants_debt and customer_path != "":
			StoryManager.record_debt(customer_path, _last_earning)
			print("[GameManager] Item accepted via Utang. Debt recorded.")
			return

		money += _last_earning
		EventBus.money_changed.emit(money)
		save_state()
		print("[GameManager] Sold %s for %.2f (Base: %.2f, Price: %.2f). TOTAL: %.2f" % [
			item.item_name, _last_earning, item.price, item.get_final_price(), money
		])

func _on_utang_accepted(_customer: Customer) -> void:
	# Since we no longer add money in _on_transaction_completed for debt transactions,
	# we don't need to deduct anything here.
	print("[GameManager] Utang accepted! Transaction finalized with no immediate payment.")
	save_state()

func deduct_money(amount: float) -> bool:
	if money >= amount:
		money -= amount
		EventBus.money_changed.emit(money)
		save_state()
		print("[GameManager] Spent %.2f. Remaining: %.2f" % [amount, money])
		return true
	else:
		print("[GameManager] Error: Tried to spend %.2f but only has %.2f!" % [amount, money])
		return false

func _on_day_ended(ended_day_number: int) -> void:
	print("[GameManager] Day %d ended!" % ended_day_number)
	
	# 1. Start cinematic transition
	await SceneTransition.blink_and_blackout()
	
	# 2. Show Sleep Overlay
	var overlay = sleep_overlay_scene.instantiate()
	add_child(overlay)
	
	# Phase A: Closed shop message
	overlay.display_text("You closed the shop and went to sleep.")
	await overlay.completed
	
	# Phase B: Random Quote
	var quote = RANDOM_QUOTES.pick_random()
	overlay.display_text(quote)
	await overlay.completed
	
	# Phase C: Clean up
	await overlay.fade_out()
	overlay.queue_free()

	# Advance Day
	if day >= MAX_DAYS:
		print("[GameManager] Final day complete!")
		# TODO: Handle game win/end state if needed
		return
	
	day += 1
	_reset_clock_to_morning()
	EventBus.day_started.emit(day)
	
	# 3. Open eyes for the new day
	await SceneTransition.open_eyes()
	save_state()

func _on_dialogic_signal(argument: String) -> void:
	if argument == "deduct_quota":
		# Use the cached quota from _on_closing_time_reached.
		var quota := _pending_quota
		var was_successful := deduct_money(quota)
		
		if was_successful:
			quota_day += 1 # Only increase the quota demand if the player paid
			print("[GameManager] Quota met! Subtracted %.2f. New balance: %.2f. Next Quota Day: %d" % [quota, money, quota_day])
		else:
			print("[GameManager] Quota FAILED! Only had %.2f / %.2f (quota: %.2f). Quota Day remains at: %d" % [money, quota, quota, quota_day])
		
		save_state()
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
	
	elif argument == "repay_debt":
		var amount = Dialogic.VAR.get_variable("Transaction.RepaymentAmount")
		money += amount
		EventBus.money_changed.emit(money)
		
		# Get the customer path to clear the debt in StoryManager
		var spawners = get_tree().get_nodes_in_group("customer_spawner")
		if spawners.size() > 0:
			var spawner := spawners[0] as CustomerSpawner
			var customer = spawner.current_customer
			if customer and customer.customer_data:
				StoryManager.clear_debt(customer.customer_data.resource_path)
		
		save_state()
		print("[GameManager] Customer repaid %.2f pesos." % amount)

func _on_closing_time_reached() -> void:
	# Calculate quota based on the player's successful payment history (quota_day)
	# rather than the literal calendar day.
	_pending_quota = DAILY_QUOTAS.get(quota_day, 0.0)
	var was_successful = money >= _pending_quota
	
	Dialogic.VAR.set_variable("Global.TodayQuota", _pending_quota)
	Dialogic.VAR.set_variable("Global.HasEnoughMoney", 1.0 if was_successful else 0.0)
	
	print("[GameManager] Store Closed. Pre-calculated Quota (Day %d): %.2f, Success: %s" % [
		quota_day, _pending_quota, was_successful
	])

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

	# 3. Debug Advance Tier (K key)
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_K and not event.echo:
		print("[GameManager] DEBUG: Advance Tier triggered via K key")
		StoryManager.advance_tier("Debug Keybind")

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
			"day": day,
			"quota_day": quota_day
		}
	}
	SaveManager.save_game(save_data)

func _load_state() -> void:
	var save_data = SaveManager.load_game()
	if save_data.has("manager"):
		var m = save_data["manager"]
		# Cast to correct types — JSON parser returns all numbers as floats.
		money = float(m.get("money", starting_money))
		day = int(m.get("day", 1))
		quota_day = int(m.get("quota_day", 1))
		print("[GameManager] State loaded. Money: %.2f, Day: %d, Quota Day: %d" % [money, day, quota_day])
	else:
		money = starting_money
		day = 1

func reset_state() -> void:
	money = starting_money
	day = 1
	quota_day = 1
	_reset_clock_to_morning()
	save_state()
	print("[GameManager] State reset to defaults for New Game.")
