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
const DaySummaryOverlayScript = preload("res://Scripts/UI/DaySummaryOverlay.gd")
const MayariCardHUDScript = preload("res://Scripts/UI/MayariCardHUD.gd")
const PlayerXPHUDScript = preload("res://Scripts/UI/PlayerXPHUD.gd")
const EventsOverlayScript = preload("res://Scripts/UI/EventsOverlay.gd")
const PendingDebtHUDScript = preload("res://Scripts/UI/PendingDebtHUD.gd")

@export var starting_money: float = 250.0
var money: float = 0.0
var quota_day: int = 1
var _last_earning: float = 0.0
var _pending_quota: float = 0.0  # Quota for the day that just ended (cached before day increments)
var _is_ending_day: bool = false
var _is_tally_overlay_open: bool = false
var _pending_mayari_milestone_queue: Array[String] = []
var _mayari_milestone_said_also: bool = false
var _mayari_milestones_spoken_count: int = 0
var _mayari_tally_timeline_path: String = ""
var _is_day_summary_open: bool = false
var _day_summary_shown_for_day: int = -1
var _pending_order_tips: Dictionary = {} # customer_path -> {total_base_price, eff_step_sum, item_count}
var _mayari_card_hud: Node = null
var _player_xp_hud: Node = null
var _events_overlay: Node = null
var _pending_debt_hud: Node = null

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
	_player_xp_hud = PlayerXPHUDScript.new()
	add_child(_player_xp_hud)
	_events_overlay = EventsOverlayScript.new()
	add_child(_events_overlay)
	_pending_debt_hud = PendingDebtHUDScript.new()
	add_child(_pending_debt_hud)
	
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
			StoryManager.record_daily_item_sold(item.item_name)
			StoryManager.record_daily_stat_int("utang_granted", 1)
			LogManager.info("GameManager", "Item accepted via Utang. Debt recorded.")
			return

		# 1. Guaranteed Item Sale Bonuses (added directly to sale value, zero step/refusal impact)
		var base_sale := _last_earning
		var sale_bonus := StoryManager.get_item_sale_bonus(item, base_sale, false)
		if not wants_debt and sale_bonus > 0.0:
			_last_earning += sale_bonus
			LogManager.info("GameManager", "Item Sale Bonus applied: +₱%.2f!" % sale_bonus)

		# 2. Accumulate item into bulk-order tip tracker (resolved once when the full order completes; 0 tip if rejected early)
		var tip: float = 0.0
		if not wants_debt and customer_path != "":
			var tip_tol := 0
			if is_instance_valid(StoreEventManager):
				tip_tol += StoreEventManager.get_item_tolerance_offset(item)
			tip_tol += StoryManager.get_mayari_tolerance_offset()
			var tip_cdata: CustomerData = StoryManager._get_character_data(customer_path)
			if tip_cdata and is_instance_valid(CharacterProgressionManager):
				tip_tol += CharacterProgressionManager.get_reputation_tolerance_bonus(tip_cdata, item)
			var tip_eff_step: int = item.current_step - tip_tol
			var acc: Dictionary = _pending_order_tips.get(customer_path, {"total_base_price": 0.0, "eff_step_sum": 0, "item_count": 0})
			acc["total_base_price"] = float(acc["total_base_price"]) + item.price
			acc["eff_step_sum"] = int(acc["eff_step_sum"]) + tip_eff_step
			acc["item_count"] = int(acc["item_count"]) + 1
			_pending_order_tips[customer_path] = acc

		# Reputation Gain/Loss from Sale (based on effective pricing step, coldness, and favorite category)
		if customer_path != "" and is_instance_valid(CharacterProgressionManager):
			var c_data: CustomerData = StoryManager._get_character_data(customer_path)
			var tol := 0
			if is_instance_valid(StoreEventManager):
				tol += StoreEventManager.get_item_tolerance_offset(item)
			tol += StoryManager.get_mayari_tolerance_offset()
			if c_data:
				tol += CharacterProgressionManager.get_reputation_tolerance_bonus(c_data, item)
			var eff_step: int = item.current_step - tol
			var rep_delta: int = 0
			if eff_step <= -3:
				rep_delta = 14
			elif eff_step == -2:
				rep_delta = 13
			elif eff_step == -1:
				rep_delta = 12
			elif eff_step == 0:
				rep_delta = 11
			elif eff_step == 1:
				rep_delta = 10
			elif eff_step == 2:
				rep_delta = 8
			elif eff_step == 3:
				rep_delta = 4
			elif eff_step == 4:
				rep_delta = -4
			else:
				rep_delta = -8
			# Cold/Warm fridge bonus/penalty
			if item.category == "bottle" or item.category == "frozen":
				rep_delta += (-3 if StoryManager.is_fridge_warm else 3)
			# Favorite category match + first-time discovery (announced via dialogue, no star toast)
			if c_data and (item.category in c_data.get_favorite_categories()):
				rep_delta += 5
				if CharacterProgressionManager.discover_favorite_category(customer_path, item.category):
					rep_delta += 10
					var cat_label := StoryManager.get_category_display_name(item.category)
					StoryManager.pending_favorite_discovered_cat = cat_label
			if rep_delta != 0:
				CharacterProgressionManager.add_reputation(customer_path, rep_delta, "sale")

		StoryManager.record_daily_stat_add("cash_sales", base_sale)
		if tip > 0.0:
			StoryManager.record_daily_stat_add("tips_earned", tip)
		StoryManager.record_daily_item_sold(item.item_name)
		money += _last_earning
		EventBus.money_changed.emit(money)
		LogManager.info("GameManager", "Sold %s for %.2f (Base: %.2f, Price: %.2f, Tip: %.2f). TOTAL: %.2f" % [
			item.item_name, _last_earning, item.price, item.get_final_price(), tip, money
		])

func _on_utang_accepted(_customer: Customer) -> void:
	LogManager.info("GameManager", "Utang accepted! Transaction finalized with no immediate payment.")

func resolve_bulk_order_tip(customer_path: String, completed_full_order: bool) -> float:
	if customer_path == "" or not _pending_order_tips.has(customer_path):
		return 0.0
	var acc: Dictionary = _pending_order_tips[customer_path]
	_pending_order_tips.erase(customer_path)
	if not completed_full_order:
		return 0.0
	var cnt := maxi(1, int(acc.get("item_count", 1)))
	var total_base_price := float(acc.get("total_base_price", 0.0))
	var tip_eff_step: int = int(roundf(float(int(acc.get("eff_step_sum", 0))) / float(cnt)))

	var base_tip_chance: float = 0.0
	var base_tip_pct: float = 0.0
	var flat_tip: float = 0.0
	if tip_eff_step <= -5:
		var extra_below := float(-5 - tip_eff_step)
		base_tip_chance = minf(1.0, 0.95 + extra_below * 0.025)
		base_tip_pct = 0.36 + extra_below * 0.08
		flat_tip = 12.0 + extra_below * 4.0
	else:
		match tip_eff_step:
			-4:
				base_tip_chance = 0.88; base_tip_pct = 0.30; flat_tip = 10.0
			-3:
				base_tip_chance = 0.80; base_tip_pct = 0.25; flat_tip = 9.0
			-2:
				base_tip_chance = 0.70; base_tip_pct = 0.21; flat_tip = 8.0
			-1:
				base_tip_chance = 0.58; base_tip_pct = 0.17; flat_tip = 7.0
			0:
				base_tip_chance = 0.45; base_tip_pct = 0.14; flat_tip = 6.0
			1:
				base_tip_chance = 0.32; base_tip_pct = 0.12; flat_tip = 5.0
			2:
				base_tip_chance = 0.22; base_tip_pct = 0.10; flat_tip = 4.0
			3:
				base_tip_chance = 0.15; base_tip_pct = 0.09; flat_tip = 3.5
			4:
				base_tip_chance = 0.10; base_tip_pct = 0.08; flat_tip = 3.0
			_:
				base_tip_chance = 0.0; base_tip_pct = 0.0; flat_tip = 0.0

	if base_tip_chance <= 0.0:
		return 0.0
	base_tip_chance = clampf(base_tip_chance + StoryManager.get_storefront_tip_chance(), 0.0, 1.0)
	if randf() >= base_tip_chance:
		return 0.0

	var total_tip_pct := base_tip_pct + StoryManager.get_maneki_tip_bonus_pct()
	if StoryManager.has_mayari_card(MayariCardRegistry.CARD_MOONLIGHT_TIPS):
		total_tip_pct += 0.12
	if StoryManager.has_mayari_card(MayariCardRegistry.CARD_FADING_MEMORY):
		total_tip_pct += 0.10
	if is_instance_valid(CharacterProgressionManager):
		total_tip_pct += CharacterProgressionManager.get_reputation_tip_bonus_pct(customer_path)
	var pct_tip := StoryManager.calc_scaled_tip(total_base_price, total_tip_pct, 3.0, 90.0)
	var tip: float = snappedf(pct_tip + flat_tip, 0.5)
	money += tip
	EventBus.money_changed.emit(money)
	StoryManager.record_daily_stat_add("tips_earned", tip)
	Dialogic.VAR.set_variable("Global_TipActive", true)
	LogManager.info("GameManager", "Bulk order tip +₱%.2f (%d items, avg_eff_step=%d, chance=%.0f%%)!" % [tip, cnt, tip_eff_step, base_tip_chance * 100.0])
	return tip


func deduct_money(amount: float, is_mayari_tribute: bool = false) -> bool:
	if money >= amount:
		money -= amount
		if is_mayari_tribute:
			StoryManager.record_daily_stat_add("mayari_tribute", amount)
		else:
			StoryManager.record_daily_stat_add("spent_restock", amount)
		EventBus.money_changed.emit(money)
		EventBus.request_sfx.emit("money_decrease")
		LogManager.info("GameManager", "Spent %.2f. Remaining: %.2f" % [amount, money])
		return true
	else:
		LogManager.error("GameManager", "Tried to spend %.2f but only has %.2f!" % [amount, money])
		return false

func show_day_summary(show_mayari: bool = true) -> Dictionary:
	if _is_day_summary_open:
		return {"grade": "B", "quip": ""}
	_is_day_summary_open = true
	_day_summary_shown_for_day = StoryManager.day
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var overlay := DaySummaryOverlayScript.new()
	overlay.setup(StoryManager.day, StoryManager.ensure_daily_stats(), show_mayari)
	add_child(overlay)

	var res: Array = await overlay.completed
	_is_day_summary_open = false
	if not is_inside_tree():
		return {"grade": "B", "quip": ""}

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var grade: String = str(res[0]) if res.size() > 0 else "B"
	var quip: String = str(res[1]) if res.size() > 1 else ""
	Dialogic.VAR.set_variable("Global_DaySummaryQuip", quip)
	return {"grade": grade, "quip": quip}

func _on_day_ended(ended_day_number: int) -> void:
	if _is_ending_day:
		LogManager.warn("GameManager", "Duplicate day_ended signal ignored for Day %d." % ended_day_number)
		return
	_is_ending_day = true
	LogManager.info("GameManager", "Day %d ended!" % ended_day_number)

	# Show Day Summary if it wasn't already shown before Mayari's closing quip
	if _day_summary_shown_for_day != ended_day_number:
		await show_day_summary(false)
		if not is_inside_tree():
			_is_ending_day = false
			return
	
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
	elif argument == "check_mayari_milestones":
		_handle_check_mayari_milestones()
	
	# Let TutorialManager handle tutorial-specific signals
	elif tutorial.handle_dialogic_signal(argument):
		return
		
	elif argument == "repay_debt":
		var amount: float = float(Dialogic.VAR.get_variable("Transaction_RepaymentAmount", 0.0))
		if amount <= 0.0:
			return
		money += amount
		StoryManager.record_daily_stat_add("utang_repaid", amount)
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
				StoryManager.queue_pending_repayment(customer.customer_data.resource_path, amount)
		
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
	var selected_cards_raw = result[2]
	var selected_cards: Array[String] = []
	if selected_cards_raw is Array:
		for cid in selected_cards_raw:
			if str(cid) != "" and not (str(cid) in selected_cards):
				selected_cards.append(str(cid))
	elif str(selected_cards_raw) != "":
		selected_cards.append(str(selected_cards_raw))

	if offer_amount > 0.0:
		deduct_money(offer_amount, true)

	var prev_paid := StoryManager.tally_total_paid
	StoryManager.tally_total_paid = minf(StoryManager.TALLY_GOAL, StoryManager.tally_total_paid + offer_amount)
	_pending_mayari_milestone_queue.clear()
	_mayari_milestone_said_also = false
	_mayari_milestones_spoken_count = 0
	_mayari_tally_timeline_path = timeline_path
	for m in StoryManager.LEDGER_MILESTONES:
		var m_amt := float(m["amount"])
		if prev_paid < m_amt - 0.01 and StoryManager.tally_total_paid >= m_amt - 0.01:
			var m_id := str(m["id"])
			StoryManager.record_daily_list_entry("milestones_unlocked", str(m["title"]), false)
			EventBus.show_notification.emit("Ledger Milestone: %s!" % str(m["title"]), str(m["desc"]), "purchase")
			LogManager.info("GameManager", "Unlocked Silver Ledger Milestone: %s (₱%.0f)" % [str(m["title"]), m_amt])
			if m_id != "sealed_ledger":
				_pending_mayari_milestone_queue.append(m_id)

	StoryManager.last_tally_tier = tier
	StoryManager.pending_mayari_cards = selected_cards
	StoryManager.pending_mayari_card = selected_cards[0] if not selected_cards.is_empty() else ""
	StoryManager.has_mayari_visited = true
	StoryManager.is_mayari_met = true

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
	Dialogic.VAR.set_variable("Global_TallyOffer", int(roundf(offer_amount)))
	Dialogic.VAR.set_variable("Global_TallyTotalPaid", int(roundf(StoryManager.tally_total_paid)))
	Dialogic.VAR.set_variable("Global_TallyRemaining", int(roundf(StoryManager.get_tally_remaining())))
	Dialogic.VAR.set_variable("Global_TallyGoal", int(roundf(StoryManager.TALLY_GOAL)))
	Dialogic.VAR.set_variable("Global_TallyMin", int(roundf(StoryManager.get_nightly_min_tally())))
	Dialogic.VAR.set_variable("Global_TallyGenerous", int(roundf(StoryManager.get_nightly_generous_tally())))
	Dialogic.VAR.set_variable("Global_TallyTier", tier)
	Dialogic.VAR.set_variable("Global_QuotaDay", float(quota_day))

	EventBus.tally_contribution_made.emit(offer_amount, tier, StoryManager.tally_total_paid, StoryManager.TALLY_GOAL)
	EventBus.debt_quota_met.emit(is_sufficient)

	LogManager.info("GameManager", "Tally committed: Offer=₱%.2f, Tier=%s, Total=₱%.2f/₱%.2f, Cards=%s" % [
		offer_amount, tier, StoryManager.tally_total_paid, StoryManager.TALLY_GOAL, str(selected_cards)
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

## Advances through any Silver Ledger milestones newly unlocked tonight,
## bridging multiple milestones with Reyna Mayari's "Also..." conjunction (Uncle Mario pattern).
func _handle_check_mayari_milestones() -> void:
	if _pending_mayari_milestone_queue.is_empty():
		return
	var tl_path := Dialogic.current_timeline.resource_path if Dialogic.current_timeline else _mayari_tally_timeline_path
	if tl_path == "":
		_pending_mayari_milestone_queue.clear()
		return
	if _mayari_milestones_spoken_count > 0 and not _mayari_milestone_said_also and StoryManager.is_label_in_timeline(tl_path, "MilestoneAlso"):
		_mayari_milestone_said_also = true
		Dialogic.Jump.jump_to_label("MilestoneAlso")
		return
	while not _pending_mayari_milestone_queue.is_empty():
		var next_id: String = _pending_mayari_milestone_queue.pop_front()
		var target_lbl := "Milestone_" + next_id
		if StoryManager.is_label_in_timeline(tl_path, target_lbl):
			_mayari_milestones_spoken_count += 1
			_mayari_milestone_said_also = false
			Dialogic.Jump.jump_to_label(target_lbl)
			return

## Calculates and syncs today's nightly tally thresholds to Dialogic before Mayari arrives.
func prepare_nightly_quota() -> float:
	_pending_quota = StoryManager.get_nightly_min_tally()
	var generous_amt := StoryManager.get_nightly_generous_tally()
	var can_meet_min := money >= _pending_quota
	Dialogic.VAR.set_variable("Global_TodayQuota", int(roundf(_pending_quota)))
	Dialogic.VAR.set_variable("Global_TallyMin", int(roundf(_pending_quota)))
	Dialogic.VAR.set_variable("Global_TallyGenerous", int(roundf(generous_amt)))
	Dialogic.VAR.set_variable("Global_TallyGoal", int(roundf(StoryManager.TALLY_GOAL)))
	Dialogic.VAR.set_variable("Global_TallyTotalPaid", int(roundf(StoryManager.tally_total_paid)))
	Dialogic.VAR.set_variable("Global_TallyRemaining", int(roundf(StoryManager.get_tally_remaining())))
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
