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

@export var starting_money: float = 350.0
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
	return 25.0 + (q_day - 1) * 15.0

func _ready() -> void:
	LogManager.info("GameManager", "_ready() START")
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
		LogManager.info("GameManager", "Found save. Requesting distribution...")
		SaveManager.request_load()
		LogManager.info("GameManager", "Save distribution complete. Story Day: %d, Story Tier: %d" % [StoryManager.day, StoryManager.current_tier])
	else:
		LogManager.info("GameManager", "No save file found. Initializing fresh session (Morning, Day 1).")
		_reset_clock_to_morning()
		EventBus.money_changed.emit(money)

	LogManager.info("GameManager", "Starting Gameplay Level at Day %d" % day)
	EventBus.day_started.emit(day)

	
	# Safety capture: ensure mouse is captured for gameplay.
	# Give a generous delay for Dialogic/tutorial to initialize.
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	LogManager.info("GameManager", "Mouse captured immediately.")
	
	# Secondary safety check after 1.5 seconds
	if get_tree():
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(self) and not is_tutorial_task_active and Dialogic.current_timeline == null:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				LogManager.info("GameManager", "Startup Safety: Mouse mode re-captured.")
		)

func _on_transaction_completed(item: ItemData, was_correct: bool, wants_debt: bool, customer_path: String) -> void:
	if was_correct and item:
		_last_earning = item.get_final_price()
		
		# If the customer wants to pay via Utang (debt), they won't give us cash yet.
		# We record this in StoryManager so it persists.
		if wants_debt and customer_path != "":
			StoryManager.record_debt(customer_path, _last_earning)
			LogManager.info("GameManager", "Item accepted via Utang. Debt recorded.")
			return

		money += _last_earning
		EventBus.money_changed.emit(money)
		LogManager.info("GameManager", "Sold %s for %.2f (Base: %.2f, Price: %.2f). TOTAL: %.2f" % [
			item.item_name, _last_earning, item.price, item.get_final_price(), money
		])

func _on_utang_accepted(_customer: Customer) -> void:
	# Since we no longer add money in _on_transaction_completed for debt transactions,
	# we don't need to deduct anything here.
	LogManager.info("GameManager", "Utang accepted! Transaction finalized with no immediate payment.")

func deduct_money(amount: float) -> bool:
	if money >= amount:
		money -= amount
		EventBus.money_changed.emit(money)
		EventBus.request_sfx.emit("money_decrease")
		LogManager.info("GameManager", "Spent %.2f. Remaining: %.2f" % [amount, money])
		return true
	else:
		LogManager.error("GameManager", "Tried to spend %.2f but only has %.2f!" % [amount, money])
		return false

func _on_day_ended(ended_day_number: int) -> void:
	LogManager.info("GameManager", "Day %d ended!" % ended_day_number)
	
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
		
		# Keep the variable synced in case any other system reads it
		StoryManager._set_dvar("Global_HasEnoughMoney", 1.0 if was_successful else 0.0)
		
		if was_successful:
			quota_day += 1 # Only increase the quota demand if the player paid
			LogManager.info("GameManager", "Quota met! Subtracted %.2f. New balance: %.2f. Next Quota Day: %d" % [quota, money, quota_day])
			
			var timeline_path = Dialogic.current_timeline.resource_path if Dialogic.current_timeline else ""
			
			# First successful collection gets the shop-visit hint line
			if quota_day == 2 and StoryManager.is_label_in_timeline(timeline_path, "SuccessFirst"):
				Dialogic.Jump.jump_to_label("SuccessFirst")
			elif StoryManager.is_label_in_timeline(timeline_path, "Success"):
				Dialogic.Jump.jump_to_label("Success")
			else:
				LogManager.warn("GameManager", "Success labels missing in current timeline. Ending dialogue safely.")
				Dialogic.end_timeline()
		else:
			LogManager.info("GameManager", "Quota FAILED! Only had %.2f / %.2f needed. Quota Day remains at: %d" % [money, quota, quota_day])
			
			var timeline_path = Dialogic.current_timeline.resource_path if Dialogic.current_timeline else ""
			if StoryManager.is_label_in_timeline(timeline_path, "Angry"):
				Dialogic.Jump.jump_to_label("Angry")
			else:
				LogManager.warn("GameManager", "Angry labels missing in current timeline. Ending dialogue safely.")
				Dialogic.end_timeline()
		
		EventBus.debt_quota_met.emit(was_successful)
	
	# --- Tutorial: Skip path cleans up any dangling task ---
	elif argument == "refuse_service":
		# If this is Uncle Mario leaving on Day 1, mark the tutorial as complete automatically.
		# This prevents a loop if the player skips or finishes without the specific success signal.
		if day == 1 and _is_mario_tutorial_active():
			StoryManager.complete_tutorial()
		cancel_tutorial_tasks()
	elif argument == "tutorial_skipped" or argument == "tutorial_completed":
		StoryManager.complete_tutorial()
		cancel_tutorial_tasks()
		
		# If it's already 8 PM, skip Mayari and end the day
		if StoryManager._current_display_time >= StoryManager.CLOSING_HOUR:
			LogManager.info("GameManager", "Tutorial ended at 8 PM. Skipping Mayari and ending day.")
			StoryManager.has_mayari_visited = true
			EventBus.day_ended.emit(day)
	
	# --- Interactive Tutorial Tasks ---
	elif argument == "allow_sale_early":
		is_tutorial_task_active = true
		current_tutorial_task_id = "allow_sale_early"
		
	elif argument == "wait_for_fridge":
		_start_tutorial_task("wait_for_fridge", "Click the handle to open the Refrigerator.", EventBus.refrigerator_opened)
		
	elif argument == "wait_for_pricing":
		is_blocking_pickup = false
		_start_tutorial_task("wait_for_pricing", "Press ALT to toggle Pricing Mode.", EventBus.pricing_mode_changed)
		
	elif argument == "wait_for_pricing_tutorial":
		_start_tutorial_task_timed(3.0, "Adjust each item's price using scroll wheel.")
		
	elif argument == "wait_for_price_increase" or argument == "wait_for_profit_increase":
		_start_tutorial_task("wait_for_price_increase", "Use Mouse Wheel / Click to increase the price.", EventBus.price_increased)

	elif argument == "wait_for_pickup":
		is_blocking_pickup = false
		_start_tutorial_task("wait_for_pickup", "Left-Click an Anoba to pick it up.", EventBus.drag_started)
	
	elif argument == "wait_for_sale":
		_start_tutorial_task("wait_for_sale", "Drag the item onto Uncle Mario to sell it.", EventBus.transaction_completed)
	
	elif argument == "wait_look_at_fridge":
		_start_tutorial_task_timed(3.0, "Look at the Refrigerator.")
		
	elif argument == "wait_look_at_shelf":
		_start_tutorial_task_timed(3.0, "Look at the shelves on your left.")

	elif argument == "wait_look_at_phone":
		_start_tutorial_task_timed(3.0, "Look at the Phone.")

	elif argument == "wait_look_at_notebook":
		_start_tutorial_task_timed(3.0, "Look at the Notebook.")

	elif argument == "repay_debt":
		var amount = Dialogic.VAR.get_variable("Transaction_RepaymentAmount")
		money += amount
		EventBus.money_changed.emit(money)
		
		# Get the customer path to clear the debt in StoryManager
		var spawners = get_tree().get_nodes_in_group("customer_spawner")
		if spawners.size() > 0:
			var spawner := spawners[0] as CustomerSpawner
			var customer = spawner.current_customer
			if customer and customer.customer_data:
				StoryManager.clear_debt(customer.customer_data.resource_path)
		
		LogManager.info("GameManager", "Customer repaid %.2f pesos." % amount)

func _on_closing_time_reached() -> void:
	# Calculate quota based on the player's successful payment history (quota_day)
	# following the +25 growth pattern.
	_pending_quota = get_quota_for_day(quota_day)
	var was_successful = money >= _pending_quota
	
	StoryManager._set_dvar("Global_TodayQuota", _pending_quota)
	StoryManager._set_dvar("Global_HasEnoughMoney", 1.0 if was_successful else 0.0)
	StoryManager._set_dvar("Global_QuotaDay", float(quota_day))
	
	LogManager.info("GameManager", "Store Closed. Pre-calculated Quota (Day %d): %.2f, Success: %s" % [
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
	# Note: We no longer consume the click here because it blocks world interaction.
	# The PlayerInteraction script now handles tutorial-safe clicks.
	if is_tutorial_task_active or Dialogic.paused:
		if event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			return
	
	if event is InputEventMouseButton and event.pressed:
		pass

	# 3. Debug Jump to Evening (L key)
	# if event is InputEventKey and event.pressed and event.keycode == KEY_L and not event.echo:
	# 	print("[GameManager] DEBUG: Jump to 7:30 PM triggered via L key")
	# 	var tod = get_tree().root.find_child("TimeOfDay", true, false)
	# 	if tod and tod.has_method("set_time"):
	# 		tod.set_time(19, 30, 0)

	# 4. Debug Advance Tier (K key)
	# (Disabled for export)


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

func _start_tutorial_task_timed(duration: float, prompt: String) -> void:
	is_tutorial_task_active = true
	Dialogic.paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var layout = Dialogic.Styles.get_layout_node()
	if layout: layout.hide()
	
	EventBus.helper_prompt_requested.emit(prompt, true)
	
	await get_tree().create_timer(duration).timeout
	
	is_tutorial_task_active = false
	is_blocking_pickup = false # Clear pickup block after timed tasks
	Dialogic.paused = false
	if layout: layout.show()
	EventBus.helper_prompt_requested.emit("", false)
	# Explicitly ensure the cursor remains captured so the player can keep looking around
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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
	is_blocking_pickup = false # Clear blocking state when a task is done
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
	LogManager.info("GameManager", "Tutorial tasks cancelled/cleaned up.")
	
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
	
	# 3. Disconnect the task
	_cancel_tutorial_signal_connection()
	
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
		"pending_quota": _pending_quota,
	}

func load_save_data(data: Dictionary) -> void:
	money = data.get("money", starting_money)
	day = data.get("day", 1)
	quota_day = data.get("quota_day", 1)
	_pending_quota = data.get("pending_quota", 0.0)
	
	# RE-SYNC: Ensure Dialogic variables match these loaded values immediately
	StoryManager._set_dvar("Global_TodayQuota", _pending_quota)
	StoryManager._set_dvar("Global_QuotaDay", float(quota_day))
	
	# Re-calculate HasEnoughMoney for the UI/Timeline if we loaded at closing time
	var has_enough = money >= _pending_quota
	StoryManager._set_dvar("Global_HasEnoughMoney", 1.0 if has_enough else 0.0)
	
	EventBus.money_changed.emit(money)
	# day_started is now explicitly emitted in _ready() after load finishes
	LogManager.info("GameManager", "State loaded. Day %d, Money %.2f, Quota Day %d" % [day, money, quota_day])

func reset_state() -> void:
	money = starting_money
	day = 1
	quota_day = 1
	_reset_clock_to_morning()
	LogManager.info("GameManager", "State reset to defaults for New Game.")


func _cancel_tutorial_signal_connection() -> void:
	if _current_task_signal and _current_task_signal.is_connected(_on_tutorial_task_completed):
		_current_task_signal.disconnect(_on_tutorial_task_completed)


## Returns true if the currently active Dialogic timeline is the Uncle Mario tutorial.
func _is_mario_tutorial_active() -> bool:
	var tl = Dialogic.current_timeline
	if tl == null:
		return false
	
	if typeof(tl) == TYPE_STRING:
		return tl.to_lower().contains("unclemario")
	elif "resource_path" in tl:
		return tl.resource_path.to_lower().contains("unclemario")
	
	return false
