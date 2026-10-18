extends Node


## StoryManager — manages story progression and builds customer transactions.
## The clock runs freely from DAY_START_HOUR to CLOSING_HOUR with no event slots.

const DAY_START_HOUR := 5.0
const MENU_THEME_HOUR := 16.89 ## Golden hour aesthetic for Main Menu
const CLOSING_HOUR   := 20.0  ## 8 PM — no new customers after this
const HARD_STOP_HOUR := 24.0  ## Midnight — absolute time limit
## 1 in-game hour = 50 real seconds.
const CLOCK_SPEED_HOURS_PER_SEC := 1.0 / 50.0

var day: int = 1


var _label_cache: Dictionary = {}
var is_clock_running: bool = false:
	set(value):
		is_clock_running = value
		_ensure_tod_node()
		if _time_of_day_node:
			var in_menu = get_tree().current_scene and get_tree().current_scene.name == "MainMenu"
			_time_of_day_node.game_time_enabled = is_clock_running and not in_menu

var _last_character_path: String = ""
var _pending_tier_advance_source: String = ""
var has_mayari_visited: bool = false
var is_mayari_debt_active: bool = true
var is_mayari_met: bool = false
var last_mayari_collection_successful: bool = true
var customer_debts: Dictionary = {}
var is_customer_present: bool = false
var wait_limit_time: float = -1.0
var was_paused_by_limit: bool = false
var _save_requested: bool = false




# --- Story Progression ---
var _first_customer_of_day: bool = true

var _char_lookup: Dictionary = {}   # resource_path -> CustomerData


# Cached node references — populated after scene is ready to avoid null captures during _ready
var _game_manager: GameManager = null


# --- Tier Progression ---
var current_tier: int = 1
var max_unlocked_tier: int = 1
var _last_tier_unlocked_notification: int = 0
var _last_notified_tier: int = 0
var purchase_counter: int = 0:
	set(value):
		purchase_counter = value
		var required = get_required_purchases_for_next_tier()
		if purchase_counter >= required:
			if max_unlocked_tier < 10:
				max_unlocked_tier += 1
				_pending_tier_advance_source = "Activity"
				_last_tier_unlocked_notification = max_unlocked_tier
			purchase_counter = 0

func get_required_purchases_for_next_tier() -> int:
	# Formula: 5 + floor(current_tier / 2) with a steeper curve for the end game
	var base = 5 + floori(current_tier / 2.0)
	
	# Late game ramp-up (T7+) to hit the user's target of 15 at T10
	if current_tier >= 7:
		base += (current_tier - 6) * 2
		
	return clampi(base, 5, 15)

var pending_upgrade_tier: int = 0

const CATEGORY_DISPLAY_NAMES = {
	"snack": "snack",
	"sachet": "sachet",
	"can": "can",
	"candy": "candy",
	"cigarette": "cigarette",
	"pack": "noodles",
	"frozen": "frozen",
	"bottle": "beverage"
}
var pending_upgrade_cost: float = 0.0
var _upgrade_item_cache: Dictionary = {}


@export_group("Transaction Probabilities")
## Chance (0.0 to 1.0) that a customer will start with a rumor.
@export_range(0, 1) var rumor_chance: float = 0.45
## Chance (0.0 to 1.0) that a customer will ask for debt (utang).
## NOTE: Random utang is disabled for the initial version — utang only comes from Manang Ana.
@export_range(0, 1) var debt_chance: float = 0.0
## Chance (0.0 to 1.0) that a customer will just visit without buying.
@export_range(0, 1) var visit_chance: float = 0.35
## Chance (0.0 to 1.0) that a customer's request will be a riddle.
@export_range(0, 1) var riddle_chance: float = 0.35

## Safely sets a Dialogic variable only if it exists in the Dialogic system.
## Also automatically mirrors the value to the local Autoload properties (e.g. "Dialogic.VAR.get_variable("Transaction_ItemWants", "")")


## Float representation of the currently displayed in-game hour (0–24).
var _current_display_time: float = 16.89
## Cached reference to the TimeOfDay node (searched once on first use).
var _time_of_day_node: Node = null

## Pool of characters that can arrive as regular customers.
## UncleMario is excluded — he is the delivery uncle, not a regular customer.
@export var available_characters: Array[CustomerData] = [
	preload("res://Resources/customers/KuyaKap.tres"),
	preload("res://Resources/customers/ManangAna.tres"),
	preload("res://Resources/customers/ReynaMayari.tres"),
	preload("res://Resources/customers/Rosalyn.tres"),
	preload("res://Resources/customers/TK.tres"),
	preload("res://Resources/customers/Buboy.tres"),
	preload("res://Resources/customers/Sarimanok.tres"),
	preload("res://Resources/customers/Danilo.tres"),
	preload("res://Resources/customers/Brahim.tres"),
	preload("res://Resources/customers/Rodel.tres")
]

func _ready() -> void:
	LogManager.info("StoryManager", "StoryManager._ready() START")
	add_to_group("persist")
	EventBus.day_started.connect(_on_day_started)
	EventBus.customer_satisfied.connect(_on_customer_satisfied)
	EventBus.customer_arrived.connect(_on_customer_arrived)
	EventBus.customer_dismissed.connect(_on_customer_dismissed)
	Dialogic.VAR.variable_changed.connect(_on_dialogic_variable_changed)
	Dialogic.signal_event.connect(_on_dialogic_signal)
	
	_ensure_tod_node()
	if _time_of_day_node and not _time_of_day_node.time_changed.is_connected(_on_tod_time_changed):
		_time_of_day_node.time_changed.connect(_on_tod_time_changed)
	
	EventBus.debt_quota_met.connect(_on_debt_quota_met)
	
	# Initial child character data into a lookup map for faster retrieval
	for c in available_characters:
		if c:
			_char_lookup[c.resource_path] = c
	
	randomize()
	call_deferred("_cache_node_refs")
	LogManager.info("StoryManager", "StoryManager._ready() END")

func _cache_node_refs() -> void:
	_game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	LogManager.debug("StoryManager", "Cached GameManager: %s" % str(is_instance_valid(_game_manager)))
	
func _on_tod_time_changed(t: float) -> void:
	_current_display_time = t
	
	# 1. Customer Wait Limit: Pause time if someone's been here for 4 hours
	if wait_limit_time > 0 and _current_display_time >= wait_limit_time:
		if is_clock_running:
			LogManager.info("StoryManager", "Customer wait limit reached (+4h). Pausing clock.")
			is_clock_running = false
			was_paused_by_limit = true
		wait_limit_time = -1.0 # Limit reached, don't trigger again for this customer
		
	# 2. Hard Stop Limit: Never go past Midnight
	if _current_display_time >= HARD_STOP_HOUR:
		if is_clock_running:
			LogManager.info("StoryManager", "Midnight reached. Hard pausing clock.")
			is_clock_running = false
		_current_display_time = HARD_STOP_HOUR
		_apply_display_time(HARD_STOP_HOUR)
		# If someone is here, they can still be served, but time won't move.
		# If no one is here, trigger closing immediately.
		if not is_customer_present:
			EventBus.closing_time_reached.emit()
		return # Stop further checks

	# 3. End of day check: strictly cap at CLOSING_HOUR ONLY if no customer is present
	if _current_display_time >= CLOSING_HOUR and not is_customer_present:
		if is_clock_running:
			LogManager.info("StoryManager", "Closing Time Reached (8 PM). Pausing clock.")
			is_clock_running = false
			_current_display_time = CLOSING_HOUR
			_apply_display_time(CLOSING_HOUR)
			EventBus.closing_time_reached.emit()
		elif _current_display_time > CLOSING_HOUR:
			# Safety clamp to prevent time creep while paused
			_current_display_time = CLOSING_HOUR
			_apply_display_time(CLOSING_HOUR)

func _on_day_started(new_day: int) -> void:
	LogManager.info("StoryManager", "StoryManager._on_day_started(%d) CALLED" % new_day)
	day = new_day
	has_mayari_visited = false
	_first_customer_of_day = true
	LogManager.info("StoryManager", "Day %d starts." % day)
	is_customer_present = false
	wait_limit_time = -1.0
	was_paused_by_limit = false
	_current_display_time = DAY_START_HOUR
	_ensure_tod_node()
	_apply_display_time(DAY_START_HOUR)
	is_clock_running = true


func advance_tier(source: String = "Manual") -> void:
	if current_tier >= 10:
		return
		
	current_tier += 1
	purchase_counter = 0
	pending_upgrade_tier = 0
	pending_upgrade_cost = 0.0
	LogManager.info("StoryManager", "TIER ADVANCED to %d via %s" % [current_tier, source])
	
	# Save state
	_save_progression()
	
	# Trigger rewards
	EventBus.tier_advanced.emit(current_tier, source)

func get_upgrade_cost(target_tier: int) -> float:
	return 80.0 + float(target_tier - 2) * 20.0

## Returns a virtual ItemData representating a store upgrade for a specific tier.
func get_tier_upgrade_item(target_tier: int) -> ItemData:
	if _upgrade_item_cache.has(target_tier):
		return _upgrade_item_cache[target_tier]
		
	var item = ItemData.new()
	item.item_name = "Tier %d Upgrade Package" % target_tier
	item.price = get_upgrade_cost(target_tier)
	item.can_be_sold = false
	item.tier = target_tier
	item.category = "upgrades"
	
	var rep = get_representative_item_for_tier(target_tier)
	if rep:
		item.texture = rep.texture
	
	# We use metadata to identify it as an upgrade later
	item.set_meta("is_upgrade", true)
	item.set_meta("target_tier", target_tier)
	
	_upgrade_item_cache[target_tier] = item
	return item

## Finds the first item loaded in the inventory that belongs to a specific tier.
func get_representative_item_for_tier(target_tier: int) -> ItemData:
	for item in InventoryManager.get_all_items():
		if item.tier == target_tier:
			return item
	return null

func process_pending_unlock() -> void:
	if _pending_tier_advance_source != "":
		# Safety Guard: Never notify for the same tier twice
		if max_unlocked_tier <= _last_notified_tier:
			LogManager.info("StoryManager", "Skip redundant notification for Tier %d" % max_unlocked_tier)
			_pending_tier_advance_source = ""
			return
			
		# Always offer the NEXT sequential upgrade for purchase
		pending_upgrade_tier = current_tier + 1
		pending_upgrade_cost = get_upgrade_cost(pending_upgrade_tier)
		
		# But the notification highlights the specific tier that was JUST unlocked
		var notify_tier = _last_tier_unlocked_notification if _last_tier_unlocked_notification > 0 else pending_upgrade_tier
		
		# Collect items belonging specifically to the newly unlocked tier
		var new_items: Array[ItemData] = []
		for item in InventoryManager.get_all_items():
			if item.tier == notify_tier:
				new_items.append(item)
		
		_pending_tier_advance_source = ""
		_last_tier_unlocked_notification = 0 # Reset after notification
		_last_notified_tier = notify_tier
		
		# Notify the player. We show the items for notify_tier, 
		# but the cost is for the NEXT purchaseable upgrade (pending_upgrade_tier).
		EventBus.upgrade_available.emit(notify_tier, pending_upgrade_cost, new_items)
		_save_progression()

func _save_progression() -> void:
	if not _save_requested:
		_save_requested = true
		call_deferred("_flush_save")

func _flush_save() -> void:
	_save_requested = false
	SaveManager.force_save()

# ── Persistence ──────────────────────────────────────────────────────────
## Persistence ID
func get_save_id() -> String:
	return "StoryManager"

func get_save_data() -> Dictionary:
	_ensure_tod_node()
	if is_instance_valid(_time_of_day_node) and _time_of_day_node.has_method("get"):
		var tod_time = _time_of_day_node.get("current_time")
		if tod_time != null: _current_display_time = tod_time
	return {
		"day": day,
		"current_tier": current_tier,
		"max_unlocked_tier": max_unlocked_tier,
		"purchase_counter": purchase_counter,
		"customer_debts": customer_debts.duplicate(),
		"pending_upgrade_tier": pending_upgrade_tier,
		"pending_upgrade_cost": pending_upgrade_cost,
		"has_mayari_visited": has_mayari_visited,
		"is_mayari_debt_active": is_mayari_debt_active,
		"is_mayari_met": is_mayari_met,
		"last_mayari_collection_successful": last_mayari_collection_successful,
		"current_display_time": _current_display_time,
		"is_clock_running": is_clock_running,
		"wait_limit_time": wait_limit_time,
		"was_paused_by_limit": was_paused_by_limit,
		"is_customer_present": is_customer_present,
		"_last_notified_tier": _last_notified_tier,
	}
func load_save_data(data: Dictionary) -> void:
	day = data.get("day", day)
	current_tier = data.get("current_tier", current_tier)
	max_unlocked_tier = data.get("max_unlocked_tier", max_unlocked_tier)
	purchase_counter = data.get("purchase_counter", purchase_counter)
	customer_debts = data.get("customer_debts", {})
	pending_upgrade_tier = data.get("pending_upgrade_tier", 0)
	pending_upgrade_cost = data.get("pending_upgrade_cost", 0.0)
	has_mayari_visited = data.get("has_mayari_visited", false)
	is_mayari_debt_active = data.get("is_mayari_debt_active", true)
	is_mayari_met = data.get("is_mayari_met", false)
	last_mayari_collection_successful = data.get("last_mayari_collection_successful", true)
	_current_display_time = data.get("current_display_time", DAY_START_HOUR)
	is_clock_running = data.get("is_clock_running", false)
	wait_limit_time = data.get("wait_limit_time", -1.0)
	was_paused_by_limit = data.get("was_paused_by_limit", false)
	is_customer_present = data.get("is_customer_present", false)
	_last_notified_tier = data.get("_last_notified_tier", 0)

	DialogicBridge.sync_global(day, current_tier, max_unlocked_tier, 1)

	_ensure_tod_node()
	if is_instance_valid(_time_of_day_node):
		_apply_display_time(_current_display_time)
		_time_of_day_node.game_time_enabled = is_clock_running
	else:
		get_tree().process_frame.connect(func():
			_ensure_tod_node()
			if is_instance_valid(_time_of_day_node):
				_apply_display_time(_current_display_time)
				_time_of_day_node.game_time_enabled = is_clock_running
		, CONNECT_ONE_SHOT)

func reset_state() -> void:
	day = 1
	current_tier = 1
	max_unlocked_tier = 1
	purchase_counter = 0
	pending_upgrade_tier = 0
	pending_upgrade_cost = 0.0
	customer_debts = {}
	has_mayari_visited = false
	is_mayari_debt_active = true
	is_mayari_met = false
	last_mayari_collection_successful = true
	_current_display_time = DAY_START_HOUR
	wait_limit_time = -1.0
	was_paused_by_limit = false
	is_customer_present = false
	_last_tier_unlocked_notification = 0
	_pending_tier_advance_source = ""
	_last_notified_tier = 0
	SaveManager.delete_save()

func get_next_transaction() -> TransactionContext:
	# 1. Special Encounters (Tutorial / Kuya Kap injection)
	var special_transaction = _inject_special_customer()
	if special_transaction: return special_transaction

	if available_characters.is_empty():
		return null

	var char_data: CustomerData = null
	var force_story = false
	
	# 2. Character Selection via Progression Manager
	var selection = _select_character()
	char_data = selection["customer"]
	force_story = selection["force_story"]

	if not char_data:
		return null

	_last_character_path = char_data.resource_path
	
	var transaction = TransactionContext.new()
	transaction.customer_data = char_data
	
	# 3. Build context & choose timeline
	_build_transaction_context(transaction, char_data, force_story)
	
	if not force_story:
		_first_customer_of_day = false
	
	# 4. Independent Feature Rolls (Awareness, Riddle, Price, Debt)
	_apply_feature_rolls(transaction)
	
	# Track the initial count for progress UI
	transaction.original_count = transaction.desired_items.size()
	
	# Record first encounter
	if not CharacterProgressionManager.has_encountered(char_data.resource_path):
		CharacterProgressionManager.record_encounter(char_data.resource_path)
		_save_progression()
		
	var chapter = CharacterProgressionManager.get_chapter(char_data.resource_path)
	var branch_value = CharacterProgressionManager.get_branch(char_data.resource_path)
	var current_arc = float(char_data.get_arc_index(chapter) + 1)
	
	# 5. Sync to Dialogic
	DialogicBridge.sync_transaction(transaction, chapter, branch_value, current_arc)
	
	return transaction

func _inject_special_customer() -> TransactionContext:
	var tutorial_path := "res://Resources/customers/UncleMario.tres"
	var tutorial_chapter = CharacterProgressionManager.get_chapter(tutorial_path)
	if day == 1 and tutorial_chapter == 0:
		var tutorial_char_data = preload("res://Resources/customers/UncleMario.tres")
		var tutorial_t = TransactionContext.new()
		tutorial_t.customer_data = tutorial_char_data
		tutorial_t.transaction_type = TransactionContext.Type.VISIT
		tutorial_t.timeline = tutorial_char_data.story_timeline
		var anoba = preload("res://Resources/items/snack/Anoba.tres")
		tutorial_t.desired_items.append(anoba)
		LogManager.info("STORY", "Spawning Uncle Mario Tutorial")
		return tutorial_t

	var kuyakap_tut_path := "kuyakap_day1_spawned"
	var kuyakap_spawned = CharacterProgressionManager.get_chapter(kuyakap_tut_path)
	if day == 1 and tutorial_chapter >= 1 and kuyakap_spawned == 0:
		var kuyakap_data = preload("res://Resources/customers/KuyaKap.tres")
		var kuyakap_t = TransactionContext.new()
		kuyakap_t.customer_data = kuyakap_data
		_build_transaction_context(kuyakap_t, kuyakap_data, true)
		CharacterProgressionManager.advance_story_direct(kuyakap_tut_path)
		CharacterProgressionManager.record_encounter(kuyakap_data.resource_path)
		_first_customer_of_day = false
		LogManager.info("STORY", "Spawning Kuya Kap after Tutorial (Story Chapter 0)")
		return kuyakap_t
		
	return null

func _select_character() -> Dictionary:
	var char_data: CustomerData = null
	var force_story = false
	
	var unlocked = CharacterProgressionManager.get_unlocked_characters(current_tier, day)
	
	# Priority 0: Forced First-Time Encounters (Ignores Cooldown)
	var new_characters = unlocked.filter(func(c: CustomerData) -> bool:
		var c_ch = CharacterProgressionManager.get_chapter(c.resource_path)
		var is_new_or_chapter_zero = not CharacterProgressionManager.has_encountered(c.resource_path) or c_ch == 0
		var has_story = c_ch < c.max_story_chapters and c.story_timeline != null
		var prereqs_met = CharacterProgressionManager.is_story_chapter_available(c, c_ch)
		var is_not_mayari = c.get_clean_id() != "reynamayari"
		return is_new_or_chapter_zero and has_story and prereqs_met and is_not_mayari
	)
	
	if not new_characters.is_empty():
		char_data = new_characters.pick_random()
		force_story = true
		LogManager.info("StoryManager", "FIRST ENCOUNTER: Forcing story for new character: %s" % char_data.get_clean_id())
		return {"customer": char_data, "force_story": force_story}
		
	# Priority 1: Cooldown is 0, check for available story chapters
	if CharacterProgressionManager.global_story_cooldown <= 0:
		var story_candidates = unlocked.filter(func(c):
			if c.resource_path == CharacterProgressionManager.last_story_advancer_path: return false
			if c.resource_path == _last_character_path: return false
			if c.get_clean_id() == "reynamayari": return false
			var c_chapter = CharacterProgressionManager.get_chapter(c.resource_path)
			return c_chapter < c.max_story_chapters and c.story_timeline != null and CharacterProgressionManager.is_story_chapter_available(c, c_chapter)
		)
		
		if not story_candidates.is_empty():
			char_data = CharacterProgressionManager.pick_character_weighted(story_candidates)
			force_story = true
			LogManager.info("StoryManager", "Cooldown 0: Forcing chapter %d for: %s" % [CharacterProgressionManager.get_chapter(char_data.resource_path), char_data.get_clean_id()])
		else:
			# Soft Lock override
			var fallback = unlocked.filter(func(c):
				if c.resource_path == _last_character_path: return false
				var c_chapter = CharacterProgressionManager.get_chapter(c.resource_path)
				return c_chapter < c.max_story_chapters and c.story_timeline != null and CharacterProgressionManager.is_story_chapter_available(c, c_chapter)
			)
			if not fallback.is_empty():
				char_data = fallback.pick_random()
				force_story = true
				LogManager.info("StoryManager", "Cooldown 0: Soft-lock override. Forcing story for: %s" % char_data.get_clean_id())

	# Priority 2: Generic flow if no story is forced
	if not char_data:
		var possible_chars = unlocked.filter(func(c): return c.resource_path != _last_character_path)
		if possible_chars.is_empty(): possible_chars = unlocked
		char_data = CharacterProgressionManager.pick_character_weighted(possible_chars)
		
	return {"customer": char_data, "force_story": force_story}

func _apply_feature_rolls(transaction: TransactionContext) -> void:
	# Awareness
	var awareness_active = randf() < 0.4
	
	# Price Sensitivity
	var any_item_at_max = false
	for item in transaction.desired_items:
		if item.get_final_price() >= item.get_max_selling_price():
			any_item_at_max = true
			break
	var high_price_active = any_item_at_max and randf() < 0.5
	
	# Stock Status
	var total_stock = InventoryManager.get_total_owned_count(ItemData.ItemType.SHELF) + 		InventoryManager.get_total_owned_count(ItemData.ItemType.FRIDGE) + 		InventoryManager.get_total_owned_count(ItemData.ItemType.CANDY_CONTAINER) + 		InventoryManager.get_total_owned_count(ItemData.ItemType.SACHET_CONTAINER)
	var stock_status = "Normal"
	if total_stock == 0: stock_status = "Empty"
	elif total_stock < 10: stock_status = "Low"
	
	Dialogic.VAR.set_variable("Global_AwarenessActive", 1.0 if awareness_active else 0.0)
	Dialogic.VAR.set_variable("Global_HighPriceActive", 1.0 if high_price_active else 0.0)
	Dialogic.VAR.set_variable("Global_StockStatus", stock_status)
	
	# Rumor Mill (Danilo)
	var last_cust = Dialogic.VAR.get_variable("Global_LastCustomer")
	if transaction.customer_data.get_clean_id() == "danilo" and last_cust != "" and last_cust != "Danilo" and randf() < rumor_chance:
		transaction.rumor_active = true
		transaction.rumor_type = 1.0 if randf() < 0.5 else 0.0
	
	# Utang (Debt) - Manang Ana only
	if transaction.transaction_type == TransactionContext.Type.PURCHASE and transaction.customer_data.resource_path.contains("ManangAna"):
		transaction.wants_debt = true
		
	# Repayment
	var current_debt = customer_debts.get(transaction.customer_data.resource_path, 0.0)
	if current_debt > 0 and randf() < 0.30:
		transaction.is_repaying = true
		transaction.repayment_amount = current_debt
		
	# Riddle (Buboy / random chance)
	if not transaction.desired_items.is_empty() and transaction.transaction_type != TransactionContext.Type.VISIT:
		var main_item = transaction.desired_items[0]
		var final_riddle_chance = 1.0 if transaction.customer_data.get_clean_id() == "buboy" else riddle_chance
		if main_item.item_hint != "" and randf() < final_riddle_chance:
			transaction.is_riddle = true
			transaction.riddle_item = main_item
			# Trim to 1 item
			if transaction.desired_items.size() > 1:
				transaction.desired_items.assign([main_item])

func get_collection_transaction() -> TransactionContext:
	if has_mayari_visited:
		return null
		
	var data = _get_character_data("res://Resources/customers/ReynaMayari.tres")
	if not data: data = _get_character_data("reynamayari")
	if not data:
		push_error("[StoryManager] Could not find Reyna Mayari data for collection!")
		return null
		
	var transaction = TransactionContext.new()
	transaction.customer_data = data
	
	var path = data.resource_path
	var chapter = CharacterProgressionManager.get_chapter(path)
	
	var should_play_story = false
	if not is_mayari_met:
		should_play_story = true
		is_mayari_met = true
		LogManager.info("StoryManager", "Mayari DEBUT nightly visit.")
	elif last_mayari_collection_successful and chapter < data.max_story_chapters:
		should_play_story = true
		LogManager.info("StoryManager", "Mayari STORY nightly visit (Chapter %d)." % chapter)
	
	if should_play_story:
		transaction.transaction_type = TransactionContext.Type.STORY
		transaction.timeline = data.story_timeline
	else:
		transaction.transaction_type = TransactionContext.Type.VISIT
		transaction.timeline = "res://Dialogue/Timelines/mayari_collect.dtl"
		if not last_mayari_collection_successful:
			LogManager.info("StoryManager", "Mayari RECOVERY nightly visit (Generic).")
	
	DialogicBridge.sync_transaction(transaction, chapter, 0, 0)
	
	has_mayari_visited = true
	CharacterProgressionManager.record_encounter(path)
	return transaction

func _on_debt_quota_met(was_successful: bool) -> void:
	last_mayari_collection_successful = was_successful
	if was_successful:
		# Narrative advancement is usually handled by [signal arg="story_success"] in the dtl,
		# but we can add a safety check here or handle it manually for the nightly cycle.
		pass
	_save_progression()

func record_debt(customer_path: String, amount: float) -> void:
	var current = customer_debts.get(customer_path, 0.0)
	customer_debts[customer_path] = current + amount
	LogManager.info("StoryManager", "Recorded Debt for %s: +%.2f (Total: %.2f)" % [customer_path.get_file(), amount, customer_debts[customer_path]])
	_save_progression()

func clear_debt(customer_path: String) -> void:
	if customer_debts.has(customer_path):
		customer_debts.erase(customer_path)
		LogManager.info("StoryManager", "Debt CLEARED for %s" % customer_path.get_file())
		_save_progression()

## Tick the clock every frame — runs continuously from DAY_START_HOUR to CLOSING_HOUR.
## No caps, no tweens, no toggling. The sky just moves.
func _process(_delta: float) -> void:
	# Continuous sync check — primarily uses signals now, but ensures
	# StoryManager logic stays informed if external factors change TOD time.
	pass

## Write the float hour value to the TimeOfDay node (drives sky/shadow).
func _apply_display_time(t: float) -> void:
	if not _time_of_day_node:
		return
	
	# Guard: The main menu should have its own constant lighting (16.89).
	# Do not overwrite the main menu background with loaded game time or resets.
	if get_tree().current_scene and get_tree().current_scene.name == "MainMenu":
		return

	var h: int = int(t)
	var m: int = int((t - h) * 60.0)
	_time_of_day_node.set_time(h, m, 0)

func _ensure_tod_node() -> void:
	if not is_instance_valid(_time_of_day_node):
		_time_of_day_node = get_tree().root.find_child("TimeOfDay", true, false)
		if is_instance_valid(_time_of_day_node):
			# If we are in the Main Menu, force the special aesthetic time immediately
			if get_tree().current_scene and get_tree().current_scene.name == "MainMenu":
				var h: int = int(MENU_THEME_HOUR)
				var m: int = int((MENU_THEME_HOUR - h) * 60.0)
				_time_of_day_node.set_time(h, m, 0)
				_time_of_day_node.game_time_enabled = false # Keep it static for the menu
			
			if not _time_of_day_node.time_changed.is_connected(_on_tod_time_changed):
				_time_of_day_node.time_changed.connect(_on_tod_time_changed)

func complete_tutorial() -> void:
	var tutorial_path := "res://Resources/customers/UncleMario.tres"
	CharacterProgressionManager.advance_story_direct(tutorial_path)
	LogManager.info("StoryManager", "Uncle Mario tutorial marked as complete (Manually).")

func _get_character_data(path_or_id: String) -> CustomerData:
	if path_or_id.to_lower() == "unclemariotutorial":
		return preload("res://Resources/customers/UncleMario.tres")

	# Try path lookup first (fix branch style)
	var data = _char_lookup.get(path_or_id)
	if data: return data
	
	# Fallback: search by id (main branch style)
	for c in available_characters:
		if c.get_clean_id() == path_or_id.to_lower():
			return c
	return null


## Build the transaction context by choosing the appropriate timeline.
func _build_transaction_context(transaction: TransactionContext, data: CustomerData, force_story: bool = false) -> void:
	transaction.is_riddle = false
	transaction.wants_debt = false
	
	var chapter = CharacterProgressionManager.get_chapter(data.resource_path)
	var story_pending = chapter < data.max_story_chapters and data.story_timeline != null
	var is_mayari = data.get_clean_id() == "reynamayari"
	var story_available = story_pending and CharacterProgressionManager.is_story_chapter_available(data, chapter)
	
	if (chapter == 0 or force_story) and story_available and not is_mayari:
		transaction.transaction_type = TransactionContext.Type.STORY
		transaction.timeline = data.story_timeline
	elif story_available and CharacterProgressionManager.global_story_cooldown <= 0 and not is_mayari:
		if randf() < 0.25:
			transaction.transaction_type = TransactionContext.Type.STORY
			transaction.timeline = data.story_timeline
		else:
			_build_generic_transaction(transaction, data, chapter)
	else:
		_build_generic_transaction(transaction, data, chapter)
		
	# Assign Desired Items
	if transaction.transaction_type != TransactionContext.Type.VISIT and not transaction.is_visit_story:
		var pinned_request = data.get_chapter_request(chapter)
		if pinned_request != null:
			for entry in pinned_request.items:
				var item = entry.item if "item" in entry else entry
				var item_auto_upgrade = entry.auto_upgrade if "auto_upgrade" in entry else false
				
				if item:
					if item_auto_upgrade or pinned_request.upgrade_all or item.tier > current_tier:
						var best_in_cat = get_best_item_for_category(item.category, item)
						item = best_in_cat if best_in_cat else _pick_random_orderable_item()
					if item: transaction.desired_items.append(item)
		else:
			# Dynamic category requests via CustomerData.chapter_categories
			var dynamic_cat = data.get_chapter_category(chapter)
			if dynamic_cat != "":
				transaction.requested_category = dynamic_cat

			if transaction.transaction_type == TransactionContext.Type.PURCHASE and transaction.requested_category != "":
				if randf() > 0.5: transaction.requested_category = ""
				
			var target_item_count = _get_item_count_for_tier(current_tier) if transaction.transaction_type == TransactionContext.Type.PURCHASE else 1
			
			if transaction.requested_category != "":
				var prefer_hint = (data.get_clean_id() == "buboy")
				var item = get_any_item_for_category(transaction.requested_category, prefer_hint)
				if item:
					transaction.desired_items.append(item)
					transaction.best_item_name = item.item_name
				else:
					transaction.requested_category = ""
					
			var pool: Array[ItemData] = []
			var selection_roll = randf()
			if selection_roll < 0.6:
				var display_pool = InventoryManager.get_items_available_on_display()
				for item in display_pool:
					if is_item_unlocked(item) and item.can_be_sold: pool.append(item)
			
			if selection_roll >= 0.6 or pool.is_empty():
				for item in InventoryManager.get_all_items():
					if item.tier <= current_tier + 1 and item.can_be_sold: pool.append(item)
				
				if data.get_clean_id() == "buboy":
					var hint_pool = pool.filter(func(i): return i.item_hint != "")
					if not hint_pool.is_empty(): pool = hint_pool
					
				var pool_max_tiers = _get_max_tier_per_category()
				for i in range(target_item_count - transaction.desired_items.size()):
					var picked = _pick_weighted_item(pool, pool_max_tiers)
					if picked: transaction.desired_items.append(picked)
					
			var remaining_items = target_item_count - transaction.desired_items.size()
			var current_max_tiers = _get_max_tier_per_category()
			for i in range(remaining_items):
				if not pool.is_empty():
					var item = _pick_weighted_item(pool, current_max_tiers)
					if transaction.upgrade_to_best_tier:
						var best = get_best_item_for_category(item.category, item)
						if best: item = best
					transaction.desired_items.append(item)
				else:
					var fallback = _pick_random_orderable_item()
					if fallback: transaction.desired_items.append(fallback)
					
			if transaction.desired_items.is_empty() and transaction.transaction_type != TransactionContext.Type.VISIT:
				var fallback = _pick_random_orderable_item()
				if fallback: transaction.desired_items.append(fallback)

			if transaction.desired_items.is_empty():
				if transaction.transaction_type == TransactionContext.Type.PURCHASE:
					transaction.transaction_type = TransactionContext.Type.VISIT
					transaction.timeline = "res://Dialogue/Timelines/Generic/Visit.dtl"

			for item in transaction.desired_items:
				if item.tier > current_tier:
					transaction.is_next_tier_request = true
					break

func _build_generic_transaction(transaction: TransactionContext, data: CustomerData, chapter: int) -> void:
	var is_purchase = randf() < (1.0 - visit_chance)

	if is_purchase and data.get_clean_id() == "danilo" and chapter < data.max_story_chapters - 1:
		is_purchase = false

	var purchase_pool = data.get_purchase_timelines(chapter)
	var visit_pool = data.get_visit_timelines(chapter)
	
	if is_purchase and not purchase_pool.is_empty():
		transaction.transaction_type = TransactionContext.Type.PURCHASE
		transaction.timeline = purchase_pool.pick_random()
	elif not visit_pool.is_empty():
		transaction.transaction_type = TransactionContext.Type.VISIT
		transaction.timeline = visit_pool.pick_random()
	elif is_purchase:
		transaction.transaction_type = TransactionContext.Type.PURCHASE
		transaction.timeline = "res://Dialogue/Timelines/Generic/Purchase.dtl"
	else:
		transaction.transaction_type = TransactionContext.Type.VISIT
		transaction.timeline = "res://Dialogue/Timelines/Generic/Visit.dtl"

	if transaction.transaction_type == TransactionContext.Type.STORY:
		if data.is_visit_story_chapter(chapter):
			transaction.is_visit_story = true

func _get_item_count_for_tier(t_val: int) -> int:
	var roll = randf() * 100.0
	
	# Early game (T1-T2): 40/30/30 distribution
	# Mid game (T3-T6): 30/40/30 distribution
	# Late game (T7-T10): 10/40/50 distribution
	
	if t_val <= 2:
		if roll < 40: return 1
		elif roll < 70: return 2
		else: return 3
	elif t_val <= 6:
		if roll < 30: return 1
		elif roll < 70: return 2
		else: return 3
	else:
		if roll < 10: return 1
		elif roll < 50: return 2
		else: return 3

## Returns a random item that is unlocked for the current day.
## Prioritizes items that are currently in stock. 
## Fallback: picks an unlocked item even if out of stock (prevents "something" dialogue gap).
func _pick_random_orderable_item() -> ItemData:
	var all_unlocked: Array[ItemData] = []
	var absolute_fallback: Array[ItemData] = []
	
	for item in InventoryManager.get_all_items():
		if item.can_be_sold:
			absolute_fallback.append(item)
			if is_item_unlocked(item):
				all_unlocked.append(item)

	if not all_unlocked.is_empty():
		return all_unlocked.pick_random()
		
	if not absolute_fallback.is_empty():
		push_warning("[StoryManager] No Tier %d items unlocked. Falling back to absolute random item pool." % current_tier)
		return absolute_fallback.pick_random()
		
	push_warning("[StoryManager] No sellable items available at all for fallback filler.")
	return null

## Helper to check if an item is available based on the current tier.
func is_item_unlocked(item: ItemData) -> bool:
	return item.tier <= current_tier


var _processed_satisfied_customers: Array[Customer] = []

func _on_customer_satisfied(customer) -> void:
	# Double-processing guard: ensure we don't process the same customer twice
	if customer in _processed_satisfied_customers:
		return
	_processed_satisfied_customers.append(customer)
	# Keep the list small — only need to remember recent ones
	if _processed_satisfied_customers.size() > 5:
		_processed_satisfied_customers.pop_front()

	_set_last_customer_info(customer)
	Dialogic.VAR.set_variable("Global_LastSatisfaction", "Happy")
	
	_process_story_cooldown(customer)
	
	# Increment purchase counter for activity-based progression
	if customer.transaction_context and customer.transaction_context.transaction_type != TransactionContext.Type.VISIT:
		purchase_counter += 1
		
	# Tutorial Persistence: If this was Uncle Mario, mark the tutorial as complete now.
	if customer.customer_data and customer.customer_data.get_clean_id() == "unclemario":
		var tutorial_path := "res://Resources/customers/UncleMario.tres"
		CharacterProgressionManager.advance_story_direct(tutorial_path)
		CharacterProgressionManager.record_encounter(tutorial_path)
		LogManager.info("StoryManager", "Uncle Mario tutorial successfully completed and saved.")

func _on_customer_arrived(_customer: Customer) -> void:
	is_customer_present = true
	
	# Only set the 4-hour limit if it hasn't been set yet (e.g., fresh arrival vs restore from save).
	# If was_paused_by_limit is true, we also skip setting it because they already hit it.
	if wait_limit_time < 0 and not was_paused_by_limit:
		wait_limit_time = _current_display_time + 4.0
		LogManager.debug("StoryManager", "Customer arrived. Patience limit set to %.2f" % wait_limit_time)
	else:
		LogManager.info("StoryManager", "Customer arrived (Restore). Preserving patience state (Limit: %.2f, Paused: %s)" % [wait_limit_time, str(was_paused_by_limit)])

func _on_customer_dismissed(_customer: Customer) -> void:
	is_customer_present = false
	
	# If we are past 8 PM, the day ends as soon as the customer leaves
	if _current_display_time >= CLOSING_HOUR:
		if is_clock_running:
			is_clock_running = false
			LogManager.info("StoryManager", "Grace period ended. Pausing clock for Closing Time.")
		
		# Clamp to Midnight if we somehow drifted past it
		if _current_display_time > HARD_STOP_HOUR:
			_current_display_time = HARD_STOP_HOUR
			_apply_display_time(HARD_STOP_HOUR)
		
		# Note: We don't snap back to 8 PM; the late display time stands.
		EventBus.closing_time_reached.emit()
	
	# Otherwise, if we were paused by the wait limit, resume time
	elif was_paused_by_limit:
		is_clock_running = true
		LogManager.info("StoryManager", "Customer left. Resuming clock.")
	
	# Cleanup flags
	was_paused_by_limit = false
	wait_limit_time = -1.0

	# Original logic: Update LastCustomer info
	_set_last_customer_info(_customer)
	Dialogic.VAR.set_variable("Global_LastSatisfaction", "Unhappy")
	
	_process_story_cooldown(_customer)

func _set_last_customer_info(customer: Customer) -> void:
	if customer == null:
		Dialogic.VAR.set_variable("Global_LastCustomer", "Uncle Mario")
		Dialogic.VAR.set_variable("Global_LastItem", "Stock Delivery")
		return
		
	if customer.transaction_context:
		var data = customer.transaction_context.customer_data
		var display_name = data.character_name if data.character_name != "" else data.get_clean_id()
			
		Dialogic.VAR.set_variable("Global_LastCustomer", display_name)
		
		# Mark as encountered so they leave the Priority 0 "Forced First Encounter" list
		var path = data.resource_path
		CharacterProgressionManager.record_encounter(path)
		
		# Save specific item for rumors if applicable
		if not customer.transaction_context.desired_items.is_empty():
			Dialogic.VAR.set_variable("Global_LastItem", customer.transaction_context.desired_items[0].item_name)
		else:
			Dialogic.VAR.set_variable("Global_LastItem", "")

func _process_story_cooldown(customer) -> void:
	CharacterProgressionManager.process_story_cooldown(customer, last_mayari_collection_successful)

func _get_unlocked_characters() -> Array:
	return []
func _pick_character_weighted(_candidates) -> CustomerData:
	return null
func get_best_item_for_category(cat: String, current_item: ItemData = null) -> ItemData:
	var mapped_categories = _get_mapped_categories(cat)
	var max_tier = -1
	for item in InventoryManager.get_all_items():
		if item.category in mapped_categories and item.tier <= current_tier + 1 and item.can_be_sold:
			if item.tier > max_tier:
				max_tier = item.tier
	
	if max_tier == -1: return null
	
	# Optimization: If the current item is already at the peak available tier, don't reroll it.
	if current_item and current_item.tier == max_tier and current_item.category in mapped_categories:
		return current_item
	
	var pool: Array[ItemData] = []
	for item in InventoryManager.get_all_items():
		if item.category in mapped_categories and item.tier == max_tier and item.can_be_sold:
			pool.append(item)
			
	return pool.pick_random()

func get_any_item_for_category(cat: String, prefer_hint: bool = false) -> ItemData:
	var mapped_categories = _get_mapped_categories(cat)
	var pool: Array[ItemData] = []
	for item in InventoryManager.get_all_items():
		if item.category in mapped_categories and item.tier <= current_tier + 1 and item.can_be_sold:
			pool.append(item)
	
	if prefer_hint:
		var hint_pool = pool.filter(func(i): return i.item_hint != "")
		if not hint_pool.is_empty():
			pool = hint_pool
			
	var max_tiers_by_cat = _get_max_tier_per_category()
	var item = _pick_weighted_item(pool, max_tiers_by_cat) if not pool.is_empty() else null
	if not item:
		LogManager.warn("StoryManager", "Category Search FAILURE: '%s'. Attempting global fallback." % cat)
		item = _pick_random_orderable_item()
	return item

## Calculates the highest unlocked tier for every item category.
func _get_max_tier_per_category() -> Dictionary:
	var max_tiers = {}
	for item in InventoryManager.get_all_items():
		if item.tier <= current_tier and item.can_be_sold:
			var cat = item.category
			if not max_tiers.has(cat) or item.tier > max_tiers[cat]:
				max_tiers[cat] = item.tier
	return max_tiers

## Picks an item from the pool with weighting based on its tier relative to the max tier in its category.
## 1. Next-Tier Items (item.tier > current_tier): Fixed 0.3 weight.
## 2. Best-in-Category Items (item.tier == max_tier_for_cat): 1.0 weight.
## 3. Older Items: Gradual linear decay (-25% per tier gap, max(0.2, 1.0 - gap * 0.25)).
func _pick_weighted_item(pool: Array[ItemData], max_tiers_by_cat: Dictionary) -> ItemData:
	if pool.is_empty():
		return null
		
	var total_weight: float = 0.0
	var weights: Array[float] = []
	
	for item in pool:
		var weight: float = 0.0
		
		# Priority 1: Next-Tier uncommon items
		if item.tier > current_tier:
			# Increased weight for "teasing" next tier items
			weight = 0.5
		else:
			# Priority 2: Gradual category-based decay
			var max_tier_in_cat = max_tiers_by_cat.get(item.category, item.tier)
			var gap = max_tier_in_cat - item.tier
			
			if gap <= 0:
				# Best currently unlocked in this category
				# Steering: Add a bonus if this item's tier is high relative to player level
				# to favor selling more profitable, higher-tier items the player has stocked.
				weight = 1.0 + (float(item.tier) * 0.1)
			else:
				# Gradual linear decay: 1.0 -> 0.75 -> 0.50 -> 0.25 -> 0.20 floor
				weight = max(0.2, 1.0 - (float(gap) * 0.25))
		
		weights.append(weight)
		total_weight += weight
		
	var roll = randf() * total_weight
	var cursor = 0.0
	for i in range(pool.size()):
		cursor += weights[i]
		if roll <= cursor:
			return pool[i]
			
	return pool.pick_random() # Absolute fallback

func _get_mapped_categories(cat: String) -> Array[String]:
	var c = cat.to_lower()
	match c:
		"bottle", "drinks", "beverage": return ["bottle"]
		"cigarette", "cigars", "cigarettes": return ["cigarette"]
		"candy", "candies": return ["candy"]
		"snack", "snacks": return ["snack"]
		"sachet", "sachets": return ["sachet"]
		"pack", "packs", "noodles": return ["pack"]
		"frozen": return ["frozen"]
		"can", "cans", "cannedgoods": return ["can"]
	
	# Fallback: if it's not a keyword, check if it's an item name
	for item in InventoryManager.get_all_items():
		if item.item_name.to_lower() == c:
			return [item.category]
			
	return [c]

func _get_current_customer() -> Node:
	var spawners = get_tree().get_nodes_in_group("customer_spawner")
	if spawners.size() > 0:
		var spawner = spawners[0] as CustomerSpawner
		if spawner and is_instance_valid(spawner.current_customer):
			return spawner.current_customer
	return null

func _on_dialogic_variable_changed(info: Dictionary) -> void:
	var var_path = str(info.get("variable", ""))
	
	if var_path == "Transaction_Branch":
		var customer = _get_current_customer()
		if is_instance_valid(customer) and customer.customer_data:
			var new_val = float(info.get("new_value", 0.0))
			CharacterProgressionManager.save_branch(customer.customer_data.resource_path, new_val)
			LogManager.info("StoryManager", "Captured Transaction_Branch change for %s -> %s" % [customer.customer_data.character_name, str(new_val)])
			_save_progression()
			
	elif var_path == "Transaction_ItemWants":
		# Manual morphing implemented via upgrade_desires() instead of automatic listeners
		pass

func _on_dialogic_signal(argument: String) -> void:
	if argument == "refresh_desires":
		refresh_desires()
	elif argument == "upgrade_desires":
		upgrade_desires()
	elif argument.begins_with("set_desire:"):
		var item_name := argument.substr(len("set_desire:")).strip_edges()
		set_desire(item_name)
	elif argument.begins_with("story_success"):
		var override_path = ""
		if argument.begins_with("story_success:"):
			override_path = argument.substr(len("story_success:")).strip_edges()
			
		if override_path != "":
			CharacterProgressionManager.advance_story_direct(override_path)
			return

		var customer = _get_current_customer()
		if customer:
			LogManager.info("StoryManager", "Direct Advance: 'story_success' payload matched active spawner: %s" % customer.customer_data.character_name)
			_process_story_cooldown(customer)
			_save_progression()
		else:
			push_error("[StoryManager] Direct Advance FAILED: 'story_success' signal received with no active customer and no explicit path.")

func refresh_desires() -> void:
	var customer = _get_current_customer()
	if not is_instance_valid(customer) or not customer.transaction_context:
		LogManager.warn("StoryManager", "REFRESH FAILED: No active customer or context.")
		return
		
	var transaction = customer.transaction_context
	var old_desires = Dialogic.VAR.get_variable("Transaction_ItemWants", "")
	var old_type = transaction.transaction_type
	var old_timeline = transaction.timeline
	var old_visit_story = transaction.is_visit_story
	
	transaction.desired_items.clear()
	_build_transaction_context(transaction, customer.customer_data, old_type == TransactionContext.Type.STORY)
	
	# Restore critical states so we don't abruptly change timeline midway
	transaction.transaction_type = old_type
	transaction.timeline = old_timeline
	transaction.is_visit_story = old_visit_story
	
	upgrade_desires()
	LogManager.info("StoryManager", "REFRESH: %s -> %s" % [old_desires, Dialogic.VAR.get_variable("Transaction_ItemWants", "")])
	LogManager.info("StoryManager", "Desires refreshed and upgraded via signal.")

## Force a specific named item as the customer's desire, then upgrade to best tier.
## Usage in Dialogic: [signal arg="set_desire:Kopimo"]
func set_desire(item_name: String) -> void:
	var customer = _get_current_customer()
	if not is_instance_valid(customer) or not customer.transaction_context:
		LogManager.warn("StoryManager", "SET_DESIRE FAILED: No active customer or context.")
		return
	
	# Find the item resource by name.
	# Priority: exact match → starts-with → contains (all case-insensitive)
	var search := item_name.to_lower()
	var target_item: ItemData = null
	var starts_match: ItemData = null
	var contains_match: ItemData = null
	for item in InventoryManager.get_all_items():
		var n := item.item_name.to_lower()
		if n == search:
			target_item = item
			break
		elif starts_match == null and n.begins_with(search):
			starts_match = item
		elif contains_match == null and n.contains(search):
			contains_match = item
	
	if not target_item:
		target_item = starts_match if starts_match else contains_match
	
	if not target_item:
		push_warning("[StoryManager] set_desire: No item matching '%s' found in inventory." % item_name)
		return
	
	LogManager.info("StoryManager", "SET_DESIRE: Matched '%s' -> '%s'" % [item_name, target_item.item_name])
	
	# Override the desired_items list with just this one item
	var transaction = customer.transaction_context
	var typed_list: Array[ItemData] = []
	typed_list.append(target_item)
	transaction.desired_items.assign(typed_list)
	
	# Now upgrade it to the best available tier in its category
	upgrade_desires()
	LogManager.info("StoryManager", "SET_DESIRE: Forced desire to '%s' -> upgraded to '%s'" % [item_name, Dialogic.VAR.get_variable("Transaction_ItemWants", "")])

## Manual command to upgrade current items to their best available tiers.
## Usage in Dialogic: [signal arg="upgrade_desires"] or [do StoryManager.upgrade_desires()]
func upgrade_desires() -> void:
	var customer = _get_current_customer()
	if not is_instance_valid(customer) or not customer.transaction_context:
		return
		
	var transaction = customer.transaction_context
	if transaction.desired_items.is_empty(): return
	
	var new_list: Array[ItemData] = []
	for old_item in transaction.desired_items:
		var best = get_best_item_for_category(old_item.category, old_item)
		if best: new_list.append(best)
		else: new_list.append(old_item)
	
	transaction.desired_items.assign(new_list)
	update_transaction_item_string(transaction)
	LogManager.info("StoryManager", "Manual Upgrade Executed: %s" % Dialogic.VAR.get_variable("Transaction_ItemWants", ""))

func update_transaction_item_string(transaction: TransactionContext) -> void:
	DialogicBridge.sync_item_string(transaction)
func _get_max_tier_for_category(cat: String) -> int:
	var mapped_cats = _get_mapped_categories(cat)
	var max_found = -1
	for item in InventoryManager.get_all_items():
		if item.category in mapped_cats and item.can_be_sold:
			if item.tier > max_found and item.tier <= current_tier:
				max_found = item.tier
	return max_found

func _join_names(names: Array[String]) -> String:
	if names.size() == 0: return ""
	if names.size() == 1: return names[0]
	if names.size() == 2: return names[0] + " and " + names[1]
	
	var result = ""
	for i in range(names.size()):
		if i == names.size() - 1:
			result += "and " + names[i]
		else:
			result += names[i] + ", "
	return result


## Helper to see if a label exists in a timeline file (.dtl) safely without crashing.
func is_label_in_timeline(path, label_name: String) -> bool:
	if typeof(path) != TYPE_STRING or path == "":
		return false
	
	# Normalize path and handle missing .dtl extension
	var full_path = path
	if not full_path.ends_with(".dtl"):
		full_path += ".dtl"
		
	var cache_key = full_path + "::" + label_name
	if _label_cache.has(cache_key):
		return _label_cache[cache_key]
		
	# Memory guard: Prevent unbounded growth in very long sessions
	if _label_cache.size() > 500:
		_label_cache.clear()
		
	if not FileAccess.file_exists(full_path):
		# Try one more fallback if Dialogic uses local paths
		if not full_path.begins_with("res://"):
			full_path = "res://" + full_path
		if not FileAccess.file_exists(full_path):
			_label_cache[cache_key] = false
			return false
	
	var file = FileAccess.open(full_path, FileAccess.READ)
	if not file: 
		_label_cache[cache_key] = false
		return false
	
	var content = file.get_as_text()
	# Strip UTF-8 BOM if present so the caret anchor (^) in regex works correctly
	content = content.replace("\uFEFF", "")
	
	# Robust label matching:
	# Clear cache if stale or requested
	if _label_cache.size() > 500:
		_label_cache.clear()

	var regex = RegEx.new()
	# (?m) enables multiline mode so ^ matches start of ANY line.
	# We look for "label", at least one space, then the target label name.
	regex.compile("(?m)^\\s*label\\s+" + label_name + "(\\s+|#|$)")
	
	if regex.search(content):
		_label_cache[cache_key] = true
		return true
			
	_label_cache[cache_key] = false
	return false


func reset_to_morning() -> void:
	_current_display_time = DAY_START_HOUR
	is_clock_running = true

func is_past_closing_time() -> bool:
	return _current_display_time >= CLOSING_HOUR

func has_pending_tier_advance() -> bool:
	return _pending_tier_advance_source != ""
