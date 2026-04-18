extends Node
class_name GameManager

## Central manager for progression out of MainGame.gd

var save_id: String = "game_manager"

const END_OF_DAY_QUOTES = [
	"The gentle Bungisngis hides in the woods not to frighten, but to share his endless, echoing giggles with the wind.",
	"A creature of a thousand eyes, the Daligmata stays awake simply to guide lost dreamers safely through the dark.",
	"High in the ancient balete tree, the Kapre watches over the forest, a quiet guardian wrapped in a cozy blanket of sweet smoke.",
	"Leaving her heavy burdens on the earth below, the Manananggal takes flight to dance freely among the quiet stars.",
	"The peaceful Litao sings lullabies to the rivers, calming the tides so tired fishermen may sail safely home.",
	"Drifting along misty roads, the gentle Kaperosa is no phantom of sorrow, but a glowing shepherd keeping lonely night-drivers company.",
	"Hidden between the folds of dusk, the golden city of Biringan waits for those whose hearts believe in everyday magic.",
	"Where the painted wings of the legendary Sarimanok catch the morning sun, bountiful blessings and peace are sure to follow.",
	"Tame the wild spirit of a Tikbalang, and you will earn a loyal, steadfast companion for all your life's winding journeys.",
	"Guided by ancient whispers and the scent of crushed leaves, the Albularyo uses gentle hands to mend both the aching body and the weary spirit."
]

@onready var sleep_overlay_scene = preload("res://Scenes/UI/SleepOverlay.tscn")

@export var starting_money: float = 200.0
var money: float = 0.0
var day: int = 1
var quota_day: int = 1
var _last_earning: float = 0.0
var _pending_quota: float = 0.0  # Quota for the day that just ended (cached before day increments)

var _is_waiting_for_tutorial_space := false
var is_tutorial_task_active := false
var is_blocking_pickup := false
var current_tutorial_task_id := ""

# --- Debt System (Dynamic) ---
func get_quota_for_day(q_day: int) -> float:
	return 50.0 + (q_day - 1) * 25.0

func _ready() -> void:
	print("[GameManager] _ready() START")
	add_to_group("game_manager")
	add_to_group("persist")
	money = starting_money
	
	# Connect early signals
	EventBus.transaction_completed.connect(_on_transaction_completed)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.utang_accepted.connect(_on_utang_accepted)
	EventBus.closing_time_reached.connect(_on_closing_time_reached)
	
	if not Dialogic.signal_event.is_connected(_on_dialogic_signal):
		Dialogic.signal_event.connect(_on_dialogic_signal)

	# --- LOAD/INITIALIZATION SEQUENCE ---
	# We use call_deferred to wait for all _ready() functions in the scene to finish
	# so that nodes are properly added to the "persist" group before we load.
	# This avoids the dreaded "await get_tree().process_frame" silent deadlock during scene transitions.
	call_deferred("_finish_initialization")

func _finish_initialization() -> void:
	
	if SaveManager.has_save():
		print("[GameManager] Loading save...")
		SaveManager.request_load()
		print("[GameManager] Save loaded.")
	else:
		print("[GameManager] No save. Resetting clock...")
		_reset_clock_to_morning()
		print("[GameManager] Clock reset done. Emitting money_changed...")
		EventBus.money_changed.emit(money)

	print("[GameManager] Started Day ", day)
	EventBus.day_started.emit(day)
	print("[GameManager] day_started emitted.")
	
	# Safety capture: ensure mouse is captured for gameplay.
	# Give a generous delay for Dialogic/tutorial to initialize.
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("[GameManager] Mouse captured immediately.")
	
	# Secondary safety check after 1.5 seconds
	if get_tree():
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(self) and not is_tutorial_task_active and Dialogic.current_timeline == null:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				print("[GameManager] Startup Safety: Mouse mode re-captured.")
		)

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
		print("[GameManager] Sold %s for %.2f (Base: %.2f, Price: %.2f). TOTAL: %.2f" % [
			item.item_name, _last_earning, item.price, item.get_final_price(), money
		])

func _on_utang_accepted(_customer: Customer) -> void:
	# Since we no longer add money in _on_transaction_completed for debt transactions,
	# we don't need to deduct anything here.
	print("[GameManager] Utang accepted! Transaction finalized with no immediate payment.")

func deduct_money(amount: float) -> bool:
	if money >= amount:
		money -= amount
		EventBus.money_changed.emit(money)
		print("[GameManager] Spent %.2f. Remaining: %.2f" % [amount, money])
		return true
	else:
		print("[GameManager] Error: Tried to spend %.2f but only has %.2f!" % [amount, money])
		return false

func _on_day_ended(ended_day_number: int) -> void:
	print("[GameManager] Day %d ended!" % ended_day_number)
	
	# 1. Start cinematic transition and fade music
	AudioManager.fade_out_everything(2.0)
	await SceneTransition.blink_and_blackout()
	
	# 2. Show Sleep Overlay
	var overlay = sleep_overlay_scene.instantiate()
	add_child(overlay)
	
	# Phase A: Closed shop message
	overlay.display_text("You closed the shop and went to sleep.")
	await overlay.completed
	
	# Phase B: Sequential/Random Folklore Quote
	var quote_index = (ended_day_number - 1)
	var quote = ""
	if quote_index < END_OF_DAY_QUOTES.size():
		quote = END_OF_DAY_QUOTES[quote_index]
	else:
		quote = END_OF_DAY_QUOTES.pick_random()
		
	overlay.display_text(quote)
	await overlay.completed
	
	# Phase C: Clean up
	await overlay.fade_out()
	overlay.queue_free()

	# Advance Day
	day += 1
	_reset_clock_to_morning()
	EventBus.day_started.emit(day)
	
	# 3. Open eyes for the new day
	await SceneTransition.open_eyes()

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
		
		EventBus.debt_quota_met.emit(was_successful)
	
	# --- Tutorial: Skip path cleans up any dangling task ---
	elif argument == "refuse_service":
		cancel_tutorial_tasks()
	elif argument == "tutorial_skipped":
		StoryManager.complete_tutorial()
		cancel_tutorial_tasks()
	
	# --- Interactive Tutorial Tasks ---
	elif argument == "allow_sale_early":
		is_tutorial_task_active = true
		current_tutorial_task_id = "allow_sale_early"
		
	elif argument == "wait_for_fridge":
		_start_tutorial_task("wait_for_fridge", "Click the handle to open the Refrigerator.", EventBus.refrigerator_opened)
		
	elif argument == "wait_for_pricing":
		is_blocking_pickup = true
		_start_tutorial_task("wait_for_pricing", "Press ALT to toggle Pricing Mode.", EventBus.pricing_mode_changed)
		
	elif argument == "wait_for_price_increase" or argument == "wait_for_profit_increase":
		_start_tutorial_task("wait_for_price_increase", "Use Mouse Wheel / Click to increase the price.", EventBus.price_increased)

	elif argument == "wait_for_pickup":
		is_blocking_pickup = false
		_start_tutorial_task("wait_for_pickup", "Left-Click an Anoba to pick it up.", EventBus.drag_started)
	
	elif argument == "wait_for_sale":
		_start_tutorial_task("wait_for_sale", "Drag the item onto Uncle Mario to sell it.", EventBus.transaction_completed)
	
	elif argument == "wait_look_at_fridge":
		_start_tutorial_task_timer("wait_look_at_fridge", "Look at the Refrigerator.", 2.0)
		
	elif argument == "wait_look_at_shelf":
		_start_tutorial_task_timer("wait_look_at_shelf", "Look at the shelves on your left.", 2.0)

	elif argument == "wait_look_at_phone":
		_start_tutorial_task_timer("wait_look_at_phone", "Look at the Phone.", 2.0)

	elif argument == "wait_look_at_notebook":
		_start_tutorial_task_timer("wait_look_at_notebook", "Look at the Notebook.", 2.0)

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
		
		print("[GameManager] Customer repaid %.2f pesos." % amount)

func _on_closing_time_reached() -> void:
	# Calculate quota based on the player's successful payment history (quota_day)
	# following the +25 growth pattern.
	_pending_quota = get_quota_for_day(quota_day)
	var was_successful = money >= _pending_quota
	
	Dialogic.VAR.set_variable("Global.TodayQuota", _pending_quota)
	Dialogic.VAR.set_variable("Global.HasEnoughMoney", 1.0 if was_successful else 0.0)
	Dialogic.VAR.set_variable("Global.QuotaDay", float(quota_day))
	
	print("[GameManager] Store Closed. Pre-calculated Quota (Day %d): %.2f, Success: %s" % [
		quota_day, _pending_quota, was_successful
	])

func _input(event: InputEvent) -> void:
	# 1. Tutorial Space Handling: Resumes Dialogic after camera pan
	if _is_waiting_for_tutorial_space:
		if event.is_action_pressed("dialogic_default_action") or event.is_action_pressed("ui_accept"):
			_is_waiting_for_tutorial_space = false
			Dialogic.paused = false
			get_viewport().set_input_as_handled()
			return

	# 2. Block Dialogue Advancement during Tutorial Tasks or Pause
	# This prevents Space/Enter from "punching through" tutorial wait-states
	if is_tutorial_task_active or Dialogic.paused:
		if event.is_action_pressed("dialogic_default_action") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			return

	# 3. Debug Jump to Evening (L key)
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_L and not event.echo:
		print("[GameManager] DEBUG: Jump to 7:30 PM triggered via L key")
		
		var tod = get_tree().root.find_child("TimeOfDay", true, false)
		if tod and tod.has_method("set_time"):
			tod.set_time(19, 30, 0)

	# 3. Debug Advance Tier (K key)
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_K and not event.echo:
		var next_tier = StoryManager.current_tier + 1
		if next_tier <= 10:
			if StoryManager.max_unlocked_tier < next_tier:
				StoryManager.max_unlocked_tier = next_tier
			
			var cost = StoryManager.get_upgrade_cost(next_tier)
			money += cost
			EventBus.money_changed.emit(money)
			EventBus.show_notification.emit("UPGRADE UNLOCKED!", "You now have enough money to upgrade to Tier %d." % next_tier, "")
			print("[GameManager] DEBUG: Gave money and unlocked Tier %d" % next_tier)


## Helper to highlight an object during the tutorial
func _flash_outline(node: Node, duration: float) -> void:
	if node and node.has_method("on_hover"):
		node.on_hover(true)
		await get_tree().create_timer(duration).timeout
		if is_instance_valid(node):
			node.on_hover(false)

# --- Tutorial Milestone Logic ---
var _current_task_signal: Signal

func _start_tutorial_task(task_id: String, prompt: String, completion_signal: Signal) -> void:
	is_tutorial_task_active = true
	current_tutorial_task_id = task_id
	Dialogic.paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Hide Dialogic UI temporarily to focus on the task
	var layout = Dialogic.Styles.get_layout_node()
	if layout: layout.hide()
	
	EventBus.helper_prompt_requested.emit(prompt, true)
	_current_task_signal = completion_signal
	
	if not _current_task_signal.is_connected(_on_tutorial_task_completed):
		_current_task_signal.connect(_on_tutorial_task_completed)

func _start_tutorial_task_gaze(task_id: String, prompt: String, target_id: String, group_name: String) -> void:
	var interaction = get_tree().get_first_node_in_group("player_interaction")
	if interaction and interaction.has_method("setup_gaze_task"):
		interaction.setup_gaze_task(target_id, group_name)
	
	_start_tutorial_task(task_id, prompt, EventBus.target_gazed)

func _start_tutorial_task_timer(task_id: String, prompt: String, duration: float) -> void:
	is_tutorial_task_active = true
	current_tutorial_task_id = task_id
	Dialogic.paused = true
	
	# Hide standard dialogue window to show the prompt clearly
	var layout = Dialogic.Styles.get_layout_node()
	if layout: layout.hide()
	
	EventBus.helper_prompt_requested.emit(prompt, true)
	_current_task_signal = Signal() # Clear any previous signal
	
	# Wait for the duration
	await get_tree().create_timer(duration).timeout
	
	# Only complete if this task is still the active one (prevent race conditions)
	if current_tutorial_task_id == task_id:
		_on_tutorial_task_completed()

func _on_tutorial_task_completed(arg1=null, _b=null, _c=null, _d=null) -> void:
	# For gaze tasks, verify the target matches
	if current_tutorial_task_id.begins_with("wait_look_at"):
		var expected_id = current_tutorial_task_id.replace("wait_look_at_", "")
		if str(arg1) != expected_id:
			return # Keep waiting, it was the wrong target
	
	# Disconnect first to prevent double-firing
	if _current_task_signal and not _current_task_signal.is_null() and _current_task_signal.is_connected(_on_tutorial_task_completed):
		_current_task_signal.disconnect(_on_tutorial_task_completed)
	
	is_tutorial_task_active = false
	current_tutorial_task_id = ""
	EventBus.helper_prompt_requested.emit("", false)
	
	# Small delay before resuming for juice
	await get_tree().create_timer(0.5).timeout
	
	var layout = Dialogic.Styles.get_layout_node()
	if layout: layout.show()
	Dialogic.paused = false
	# Resume dialogue flow naturally (removed handle_next_event to prevent skipping)


## Immediately cancels any in-flight tutorial task, unpauses Dialogic,
## and releases the mouse. Safe to call when the player skips the tutorial.
func cancel_tutorial_tasks() -> void:
	print("[GameManager] Tutorial tasks cancelled/cleaned up.")
	
	# 1. Clear interaction blocks
	is_blocking_pickup = false
	_is_waiting_for_tutorial_space = false
	
	# 2. Cleanup MarioManager (Uncle Mario tutorial special states)
	if MarioManager:
		MarioManager.is_restocking_active = false
		MarioManager.is_mario_physically_present = false
		# If he was in the middle of a phone call or similar, clear it
		if MarioManager.has_method("cancel_restock"):
			MarioManager.cancel_restock()
	
	# 3. Disconnect the task completion signal if connected
	if _current_task_signal and _current_task_signal.is_connected(_on_tutorial_task_completed):
		_current_task_signal.disconnect(_on_tutorial_task_completed)
	
	is_tutorial_task_active = false
	current_tutorial_task_id = ""
	
	# 3. Clear gaze task if any
	var interaction = get_tree().get_first_node_in_group("player_interaction")
	if interaction and interaction.has_method("clear_gaze_task"):
		interaction.clear_gaze_task()
	
	# 4. Force Stop Dialogic if it was blocking
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()
	
	# 5. Restore UI and mouse
	EventBus.helper_prompt_requested.emit("", false)
	Dialogic.paused = false
	
	var layout = Dialogic.Styles.get_layout_node()
	if layout: layout.show()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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


# ── Persistence ──────────────────────────────────────────────────────────

func get_save_id() -> String:
	return "manager"

func get_save_data() -> Dictionary:
	return {
		"money": money,
		"day": day,
		"quota_day": quota_day,
	}

func load_save_data(data: Dictionary) -> void:
	money = data.get("money", starting_money)
	day = data.get("day", 1)
	quota_day = data.get("quota_day", 1)
	
	EventBus.money_changed.emit(money)
	# day_started is now explicitly emitted in _ready() after load finishes
	print("[GameManager] State loaded. Day %d, Money %.2f, Quota Day %d" % [day, money, quota_day])

func reset_state() -> void:
	money = starting_money
	day = 1
	quota_day = 1
	_reset_clock_to_morning()
	print("[GameManager] State reset to defaults for New Game.")
