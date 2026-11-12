extends Node
class_name GameManager

## Central manager for progression out of MainGame.gd

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

@export var starting_money: float = 250.0
var money: float = 0.0
var quota_day: int = 1
var _last_earning: float = 0.0
var _pending_quota: float = 0.0  # Quota for the day that just ended (cached before day increments)
var _is_ending_day: bool = false

# --- Tutorial Manager Instance ---
var tutorial: TutorialManager

# --- Debt System (Dynamic) ---
func get_quota_for_day(q_day: int) -> float:
	return 50.0 + (q_day - 1) * 15.0

func _ready() -> void:
	LogManager.info("GameManager", "_ready() START")
	add_to_group("game_manager")
	add_to_group("persist")
	money = starting_money
	
	tutorial = TutorialManager.new(self)
	
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
	call_deferred("_finish_initialization")

func _finish_initialization() -> void:
	if SaveManager.has_save():
		LogManager.info("GameManager", "Found save. Requesting distribution...")
		SaveManager.request_load()
		LogManager.info("GameManager", "Save distribution complete. Story Day: %d, Story Tier: %d" % [StoryManager.day, StoryManager.current_tier])
	else:
		LogManager.info("GameManager", "No save file found. Initializing fresh session (Morning, Day 1).")
		StoryManager.reset_to_morning()
		EventBus.money_changed.emit(money)

	LogManager.info("GameManager", "Starting Gameplay Level at Day %d" % StoryManager.day)
	EventBus.day_started.emit(StoryManager.day)

	# Safety capture: ensure mouse is captured for gameplay.
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	LogManager.info("GameManager", "Mouse captured immediately.")
	
	# Secondary safety check after 1.5 seconds
	if get_tree():
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(self) and not tutorial.is_tutorial_task_active and Dialogic.current_timeline == null:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				LogManager.info("GameManager", "Startup Safety: Mouse mode re-captured.")
		)

func _on_transaction_completed(item: ItemData, was_correct: bool, wants_debt: bool, customer_path: String) -> void:
	if was_correct and item:
		_last_earning = item.get_final_price()
		
		# If the customer wants to pay via Utang (debt), they won't give us cash yet.
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
	if _is_ending_day:
		LogManager.warn("GameManager", "Duplicate day_ended signal ignored for Day %d." % ended_day_number)
		return
	_is_ending_day = true
	LogManager.info("GameManager", "Day %d ended!" % ended_day_number)
	
	# 1. Start cinematic transition and fade music
	AudioManager.fade_out_everything(2.0)
	await SceneTransition.blink_and_blackout()
	if not is_inside_tree():
		_is_ending_day = false
		return
	
	# 2. Show Sleep Overlay
	var completed = await _play_sleep_sequence(ended_day_number)
	if not completed or not is_inside_tree():
		_is_ending_day = false
		return

	# Advance Day
	StoryManager.day += 1
	StoryManager.reset_to_morning()
	EventBus.day_started.emit(StoryManager.day)
	
	# 3. Open eyes for the new day
	await SceneTransition.open_eyes()
	_is_ending_day = false

func _play_sleep_sequence(ended_day_number: int) -> bool:
	var overlay = sleep_overlay_scene.instantiate()
	add_child(overlay)
	
	# Phase A: Closed shop message
	overlay.display_text("You closed the shop and went to sleep.")
	await overlay.completed
	if not is_inside_tree() or not is_instance_valid(overlay):
		return false
	
	# Phase B: Sequential/Random Folklore Quote
	var quote_index = (ended_day_number - 1)
	var quote = END_OF_DAY_QUOTES[quote_index] if quote_index < END_OF_DAY_QUOTES.size() else END_OF_DAY_QUOTES.pick_random()
		
	overlay.display_text(quote)
	await overlay.completed
	if not is_inside_tree() or not is_instance_valid(overlay):
		return false
	
	# Phase C: Clean up
	await overlay.fade_out()
	if is_instance_valid(overlay):
		overlay.queue_free()
	return is_inside_tree()

func _on_dialogic_signal(argument: String) -> void:
	if argument == "deduct_quota":
		_handle_deduct_quota()
	
	# Let TutorialManager handle tutorial-specific signals
	elif tutorial.handle_dialogic_signal(argument):
		return
		
	elif argument == "repay_debt":
		var amount = Dialogic.VAR.get_variable("Transaction_RepaymentAmount")
		money += amount
		EventBus.money_changed.emit(money)
		
		var spawners = get_tree().get_nodes_in_group("customer_spawner")
		if spawners.size() > 0:
			var spawner := spawners[0] as CustomerSpawner
			var customer = spawner.current_customer
			if customer and customer.customer_data:
				StoryManager.clear_debt(customer.customer_data.resource_path)
		
		LogManager.info("GameManager", "Customer repaid %.2f pesos." % amount)

func _handle_deduct_quota() -> void:
	var quota := _pending_quota
	var was_successful := deduct_money(quota)
	
	Dialogic.VAR.set_variable("Global_HasEnoughMoney", 1.0 if was_successful else 0.0)
	
	var timeline_path = Dialogic.current_timeline.resource_path if Dialogic.current_timeline else ""
	
	if was_successful:
		quota_day += 1 
		LogManager.info("GameManager", "Quota met! Subtracted %.2f. New balance: %.2f. Next Quota Day: %d" % [quota, money, quota_day])
		if quota_day == 2 and StoryManager.is_label_in_timeline(timeline_path, "SuccessFirst"):
			Dialogic.Jump.jump_to_label("SuccessFirst")
		elif StoryManager.is_label_in_timeline(timeline_path, "Success"):
			Dialogic.Jump.jump_to_label("Success")
		else:
			LogManager.warn("GameManager", "Success labels missing in current timeline. Ending dialogue safely.")
			Dialogic.end_timeline()
	else:
		LogManager.info("GameManager", "Quota FAILED! Only had %.2f / %.2f needed. Quota Day remains at: %d" % [money, quota, quota_day])
		if StoryManager.is_label_in_timeline(timeline_path, "Angry"):
			Dialogic.Jump.jump_to_label("Angry")
		else:
			LogManager.warn("GameManager", "Angry labels missing in current timeline. Ending dialogue safely.")
			Dialogic.end_timeline()
	
	EventBus.debt_quota_met.emit(was_successful)

func _on_closing_time_reached() -> void:
	_pending_quota = get_quota_for_day(quota_day)
	var was_successful = money >= _pending_quota
	
	Dialogic.VAR.set_variable("Global_TodayQuota", _pending_quota)
	Dialogic.VAR.set_variable("Global_HasEnoughMoney", 1.0 if was_successful else 0.0)
	Dialogic.VAR.set_variable("Global_QuotaDay", float(quota_day))
	
	LogManager.info("GameManager", "Store Closed. Pre-calculated Quota (Day %d): %.2f, Success: %s" % [
		quota_day, _pending_quota, was_successful
	])

func _input(event: InputEvent) -> void:
	if tutorial and tutorial.handle_input(event, get_viewport()):
		return


# ── Persistence ──────────────────────────────────────────────────────────

func get_save_id() -> String:
	return "manager"

func get_save_data() -> Dictionary:
	return {
		"money": money,
		"quota_day": quota_day,
		"pending_quota": _pending_quota,
	}

func load_save_data(data: Dictionary) -> void:
	money = data.get("money", starting_money)
	quota_day = data.get("quota_day", 1)
	_pending_quota = data.get("pending_quota", 0.0)
	
	Dialogic.VAR.set_variable("Global_TodayQuota", _pending_quota)
	Dialogic.VAR.set_variable("Global_QuotaDay", float(quota_day))
	
	var has_enough = money >= _pending_quota
	Dialogic.VAR.set_variable("Global_HasEnoughMoney", 1.0 if has_enough else 0.0)
	
	EventBus.money_changed.emit(money)
	LogManager.info("GameManager", "State loaded. Day %d, Money %.2f, Quota Day %d" % [StoryManager.day, money, quota_day])

func reset_state() -> void:
	money = starting_money
	quota_day = 1
	_pending_quota = 0.0
	_is_ending_day = false
	StoryManager.reset_to_morning()
	LogManager.info("GameManager", "State reset to defaults for New Game.")

