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
const MayariTallyOverlayScript = preload("res://Scripts/UI/MayariTallyOverlay.gd")
const MayariCardHUDScript = preload("res://Scripts/UI/MayariCardHUD.gd")

@export var starting_money: float = 250.0
var money: float = 0.0
var quota_day: int = 1
var _last_earning: float = 0.0
var _pending_quota: float = 0.0  # Quota for the day that just ended (cached before day increments)
var _is_ending_day: bool = false
var _is_tally_overlay_open: bool = false
var _mayari_card_hud: Node = null

# --- Tutorial Manager Instance ---
var tutorial: TutorialManager

# --- Debt System (Dynamic) ---
func get_quota_for_day(q_day: int) -> float:
	var step := float(maxi(0, q_day - 1))
	var linear_base := 50.0 + step * 15.0
	var scaled := linear_base * (1.0 + 0.03 * step)
	return roundf(scaled / 5.0) * 5.0

func _ready() -> void:
	LogManager.info("GameManager", "_ready() START")
	add_to_group("game_manager")
	add_to_group("persist")
	money = starting_money
	
	tutorial = TutorialManager.new(self)
	_mayari_card_hud = MayariCardHUDScript.new()
	add_child(_mayari_card_hud)
	
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
		LogManager.info("GameManager", "Resuming Gameplay Level at Day %d" % StoryManager.day)
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

		# Temporary warmth penalty: fridge items lose 25% value while fridge coldness is depleted
		if item.type == ItemData.ItemType.FRIDGE and StoryManager.is_fridge_warm:
			_last_earning = maxf(1.0, snapped(_last_earning * StoryManager.FRIDGE_WARM_VALUE_MULTIPLIER, 0.5))
			LogManager.info("GameManager", "Warm fridge penalty applied to %s (-25%% -> %.2f)" % [item.item_name, _last_earning])
		
		# If the customer wants to pay via Utang (debt), they won't give us cash yet.
		if wants_debt and customer_path != "":
			StoryManager.queue_pending_debt(customer_path, _last_earning)
			LogManager.info("GameManager", "Item accepted via Utang. Debt recorded.")
			return

		# Tip Windfall on Loss Leaders (step <= -1) + Moonlight Tips Moon Card (+₱3)
		var tip: float = 0.0
		if item.current_step < 0 and not wants_debt:
			tip = snapped(float(abs(item.current_step)) * 1.5 + 1.0, 1.0)
			_last_earning += tip
			LogManager.info("GameManager", "Loss leader discount rewarded with a tip of +₱%.2f!" % tip)
		if not wants_debt and StoryManager.has_mayari_card(MayariCardRegistry.CARD_MOONLIGHT_TIPS):
			tip += 3.0
			_last_earning += 3.0
			LogManager.info("GameManager", "Moonlight Tips card granted +₱3.00 bonus tip!")

		money += _last_earning
		EventBus.money_changed.emit(money)
		LogManager.info("GameManager", "Sold %s for %.2f (Base: %.2f, Price: %.2f, Tip: %.2f). TOTAL: %.2f" % [
			item.item_name, _last_earning, item.price, item.get_final_price(), tip, money
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
	if is_inside_tree() and not _is_tally_overlay_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
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
	if argument == "open_tally_offer" or argument == "deduct_quota":
		_handle_open_tally_offer()
	
	# Let TutorialManager handle tutorial-specific signals
	elif tutorial.handle_dialogic_signal(argument):
		return
		
	elif argument == "repay_debt":
		var amount: float = float(Dialogic.VAR.get_variable("Transaction_RepaymentAmount", 0.0))
		if amount <= 0.0:
			return
		money += amount
		EventBus.money_changed.emit(money)
		Dialogic.VAR.set_variable("Transaction_RepaymentAmount", 0.0)
		Dialogic.VAR.set_variable("Transaction_IsRepaying", 0.0)
		var spawners = get_tree().get_nodes_in_group("customer_spawner")
		if spawners.size() > 0:
			var spawner := spawners[0] as CustomerSpawner
			var customer = spawner.current_customer
			if customer and customer.customer_data:
				if customer.transaction_context:
					customer.transaction_context.is_repaying = false
					customer.transaction_context.repayment_amount = 0.0
				StoryManager.reduce_debt(customer.customer_data.resource_path, amount)
		
		LogManager.info("GameManager", "Customer repaid %.2f pesos." % amount)

func _handle_open_tally_offer() -> void:
	if _is_tally_overlay_open:
		return
	_is_tally_overlay_open = true
	prepare_nightly_quota()

	var timeline_path := Dialogic.current_timeline.resource_path if Dialogic.current_timeline else ""
	Dialogic.paused = true
	var dialog_layout = Dialogic.Styles.get_layout_node()
	if is_instance_valid(dialog_layout):
		dialog_layout.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var overlay := MayariTallyOverlayScript.new()
	overlay.setup(
		money,
		StoryManager.tally_total_paid,
		StoryManager.TALLY_GOAL,
		StoryManager.get_nightly_min_tally(),
		StoryManager.get_nightly_generous_tally()
	)
	add_child(overlay)

	var result: Array = await overlay.completed
	_is_tally_overlay_open = false
	if not is_inside_tree():
		return

	# Restore FPS captured mouse mode and Dialogic layout as soon as the tally & card draft overlay closes
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if is_instance_valid(dialog_layout):
		dialog_layout.show()

	var offer_amount: float = float(result[0])
	var tier: String = str(result[1])
	var selected_card_id: String = str(result[2])

	if offer_amount > 0.0:
		deduct_money(offer_amount)

	StoryManager.tally_total_paid = minf(StoryManager.TALLY_GOAL, StoryManager.tally_total_paid + offer_amount)
	StoryManager.last_tally_tier = tier
	StoryManager.pending_mayari_card = selected_card_id

	var is_sufficient := (tier == "balanced" or tier == "generous" or tier == "cleared")
	if is_sufficient:
		StoryManager.tally_sufficient_nights += 1
		quota_day = StoryManager.tally_sufficient_nights + 1

	if tier == "cleared" or StoryManager.tally_total_paid >= StoryManager.TALLY_GOAL - 0.01:
		StoryManager.tally_total_paid = StoryManager.TALLY_GOAL
		StoryManager.is_mayari_debt_active = false
		var mayari_path := "res://Resources/customers/ReynaMayari.tres"
		while CharacterProgressionManager.get_chapter(mayari_path) < 8:
			CharacterProgressionManager.advance_story_direct(mayari_path)

	Dialogic.VAR.set_variable("Global_HasEnoughMoney", 1.0 if is_sufficient else 0.0)
	Dialogic.VAR.set_variable("Global_TallyOffer", offer_amount)
	Dialogic.VAR.set_variable("Global_TallyTotalPaid", StoryManager.tally_total_paid)
	Dialogic.VAR.set_variable("Global_TallyRemaining", StoryManager.get_tally_remaining())
	Dialogic.VAR.set_variable("Global_TallyGoal", StoryManager.TALLY_GOAL)
	Dialogic.VAR.set_variable("Global_TallyTier", tier)
	Dialogic.VAR.set_variable("Global_QuotaDay", float(quota_day))

	EventBus.tally_contribution_made.emit(offer_amount, tier, StoryManager.tally_total_paid, StoryManager.TALLY_GOAL)
	EventBus.debt_quota_met.emit(is_sufficient)

	LogManager.info("GameManager", "Tally committed: Offer=₱%.2f, Tier=%s, Total=₱%.2f/₱%.2f, Card=%s" % [
		offer_amount, tier, StoryManager.tally_total_paid, StoryManager.TALLY_GOAL, selected_card_id
	])

	Dialogic.paused = false
	var target_label := ""
	if tier == "cleared" and StoryManager.is_label_in_timeline(timeline_path, "LedgerCleared"):
		target_label = "LedgerCleared"
	elif tier == "generous" and StoryManager.is_label_in_timeline(timeline_path, "Generous"):
		target_label = "Generous"
	elif is_sufficient and quota_day == 2 and StoryManager.is_label_in_timeline(timeline_path, "SuccessFirst"):
		target_label = "SuccessFirst"
	elif is_sufficient and StoryManager.is_label_in_timeline(timeline_path, "Success"):
		target_label = "Success"
	elif not is_sufficient and StoryManager.is_label_in_timeline(timeline_path, "Shortfall"):
		target_label = "Shortfall"
	elif not is_sufficient and StoryManager.is_label_in_timeline(timeline_path, "Angry"):
		target_label = "Angry"

	if target_label != "":
		Dialogic.Jump.jump_to_label(target_label)
	else:
		LogManager.warn("GameManager", "No matching tally reaction label in %s for tier '%s'. Ending timeline." % [timeline_path, tier])
		Dialogic.end_timeline()

## Calculates and syncs today's nightly tally thresholds to Dialogic before Mayari arrives.
func prepare_nightly_quota() -> float:
	_pending_quota = StoryManager.get_nightly_min_tally()
	var generous_amt := StoryManager.get_nightly_generous_tally()
	var can_meet_min := money >= _pending_quota
	Dialogic.VAR.set_variable("Global_TodayQuota", _pending_quota)
	Dialogic.VAR.set_variable("Global_TallyMin", _pending_quota)
	Dialogic.VAR.set_variable("Global_TallyGenerous", generous_amt)
	Dialogic.VAR.set_variable("Global_TallyGoal", StoryManager.TALLY_GOAL)
	Dialogic.VAR.set_variable("Global_TallyTotalPaid", StoryManager.tally_total_paid)
	Dialogic.VAR.set_variable("Global_TallyRemaining", StoryManager.get_tally_remaining())
	Dialogic.VAR.set_variable("Global_HasEnoughMoney", 1.0 if can_meet_min else 0.0)
	Dialogic.VAR.set_variable("Global_QuotaDay", float(quota_day))
	LogManager.info("GameManager", "Prepared Nightly Tally: Min=₱%.0f, Generous=₱%.0f, Paid=₱%.0f/₱%.0f" % [
		_pending_quota, generous_amt, StoryManager.tally_total_paid, StoryManager.TALLY_GOAL
	])
	return _pending_quota

func _on_closing_time_reached() -> void:
	prepare_nightly_quota()

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

	# Backward-compatible migration for older saves before goal-based tally:
	if quota_day > 1 and StoryManager.tally_total_paid <= 0.0 and StoryManager.tally_sufficient_nights == 0:
		var migrated_paid := 0.0
		for q in range(1, quota_day):
			migrated_paid += get_quota_for_day(q)
		StoryManager.tally_sufficient_nights = quota_day - 1
		if StoryManager.is_mayari_debt_active:
			StoryManager.tally_total_paid = minf(migrated_paid, StoryManager.TALLY_GOAL - 50.0)
		else:
			StoryManager.tally_total_paid = StoryManager.TALLY_GOAL
		LogManager.info("GameManager", "Migrated legacy quota_day=%d -> tally_total_paid=₱%.0f" % [quota_day, StoryManager.tally_total_paid])
	
	prepare_nightly_quota()
	EventBus.money_changed.emit(money)
	LogManager.info("GameManager", "State loaded. Day %d, Money %.2f, Quota Day %d" % [StoryManager.day, money, quota_day])

func reset_state() -> void:
	money = starting_money
	quota_day = 1
	_pending_quota = 0.0
	_is_ending_day = false
	StoryManager.reset_to_morning()
	LogManager.info("GameManager", "State reset to defaults for New Game.")

