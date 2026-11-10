extends Node

## StoryManager — manages story progression and builds customer transactions.
## The clock runs freely from DAY_START_HOUR to CLOSING_HOUR with no event slots.

const DAY_START_HOUR := 5.0
const MENU_THEME_HOUR := 16.89 ## Golden hour aesthetic for Main Menu
const CLOSING_HOUR   := 20.0  ## 8 PM — no new customers after this
const HARD_STOP_HOUR := 24.0  ## Midnight — absolute time limit
## 1 in-game hour = 50 real seconds.
const CLOCK_SPEED_HOURS_PER_SEC := 1.0 / 50.0

var clock: DayClock = DayClock.new()

var day: int = 1
var is_clock_running: bool:
	get: return clock.is_clock_running
	set(value): clock.set_clock_running(value)

var is_customer_present: bool:
	get: return clock.is_customer_present
	set(value): clock.is_customer_present = value

var wait_limit_time: float:
	get: return clock.wait_limit_time
	set(value): clock.wait_limit_time = value

var was_paused_by_limit: bool:
	get: return clock.was_paused_by_limit
	set(value): clock.was_paused_by_limit = value

var _current_display_time: float:
	get: return clock.current_display_time
	set(value): clock.current_display_time = value

var _last_character_path: String = ""
var _pending_tier_advance_source: String = ""
var has_mayari_visited: bool = false
var is_mayari_debt_active: bool = true
var is_mayari_met: bool = false
var last_mayari_collection_successful: bool = true
var customer_debts: Dictionary = {}
var _save_requested: bool = false

# --- Story Progression ---
var _char_lookup: Dictionary = {}   # resource_path -> CustomerData
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
	if current_tier >= 7:
		base += (current_tier - 6) * 2
	return clampi(base, 5, 15)

var pending_upgrade_tier: int = 0
var pending_upgrade_cost: float = 0.0
var _upgrade_item_cache: Dictionary = {}

@export_group("Transaction Probabilities")
## Chance (0.0 to 1.0) that a customer will start with a rumor.
@export_range(0, 1) var rumor_chance: float = 0.45
## Chance (0.0 to 1.0) that a customer will just visit without buying.
@export_range(0, 1) var visit_chance: float = 0.35
## Chance (0.0 to 1.0) that a customer's request will be a riddle.
@export_range(0, 1) var riddle_chance: float = 0.35

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
	clock.setup(self)
	EventBus.day_started.connect(_on_day_started)
	EventBus.customer_satisfied.connect(_on_customer_satisfied)
	EventBus.customer_arrived.connect(_on_customer_arrived)
	EventBus.customer_dismissed.connect(_on_customer_dismissed)
	Dialogic.VAR.variable_changed.connect(_on_dialogic_variable_changed)
	Dialogic.signal_event.connect(_on_dialogic_signal)
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

func _on_day_started(new_day: int) -> void:
	LogManager.info("StoryManager", "StoryManager._on_day_started(%d) CALLED" % new_day)
	_cache_node_refs()
	day = new_day
	has_mayari_visited = false
	LogManager.info("StoryManager", "Day %d starts." % day)
	clock.on_day_started()


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
	if is_instance_valid(clock._time_of_day_node) and clock._time_of_day_node.has_method("get"):
		var tod_time = clock._time_of_day_node.get("current_time")
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

	CharacterProgressionManager.migrate_from_story_manager_save(data)
	DialogicBridge.sync_global(day, current_tier, max_unlocked_tier, 1)

	_ensure_tod_node()
	if is_instance_valid(clock._time_of_day_node):
		_apply_display_time(_current_display_time)
		clock._time_of_day_node.game_time_enabled = is_clock_running
	else:
		get_tree().process_frame.connect(func():
			_ensure_tod_node()
			if is_instance_valid(clock._time_of_day_node):
				_apply_display_time(_current_display_time)
				clock._time_of_day_node.game_time_enabled = is_clock_running
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
	_last_tier_unlocked_notification = 0
	_pending_tier_advance_source = ""
	_last_notified_tier = 0
	clock.reset_state()
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

func _apply_display_time(t: float) -> void:
	clock.apply_display_time(t)

func _ensure_tod_node() -> void:
	clock._ensure_tod_node()

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
						item = best_in_cat if best_in_cat else OrderItemPicker.random_orderable(current_tier)
					if item: transaction.desired_items.append(item)
		else:
			# Dynamic category requests via CustomerData.chapter_categories
			var dynamic_cat = data.get_chapter_category(chapter)
			if dynamic_cat != "":
				transaction.requested_category = dynamic_cat

			if transaction.transaction_type == TransactionContext.Type.PURCHASE and transaction.requested_category != "":
				if randf() > 0.5: transaction.requested_category = ""
				
			var target_item_count = OrderItemPicker.item_count_for_tier(current_tier) if transaction.transaction_type == TransactionContext.Type.PURCHASE else 1
			
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
					
			var remaining_items = target_item_count - transaction.desired_items.size()
			var current_max_tiers = OrderItemPicker.max_tier_per_category(current_tier)
			for i in range(remaining_items):
				if not pool.is_empty():
					var item = OrderItemPicker.pick_weighted(pool, current_tier, current_max_tiers)
					if transaction.upgrade_to_best_tier:
						var best = get_best_item_for_category(item.category, item)
						if best: item = best
					transaction.desired_items.append(item)
				else:
					var fallback = OrderItemPicker.random_orderable(current_tier)
					if fallback: transaction.desired_items.append(fallback)
					
			if transaction.desired_items.is_empty() and transaction.transaction_type != TransactionContext.Type.VISIT:
				var fallback = OrderItemPicker.random_orderable(current_tier)
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

## Helper to check if an item is available based on the current tier.
func is_item_unlocked(item: ItemData) -> bool:
	return OrderItemPicker.is_unlocked(item, current_tier)


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
	clock.on_customer_arrived()

func _on_customer_dismissed(_customer: Customer) -> void:
	clock.on_customer_dismissed()
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

func get_best_item_for_category(cat: String, current_item: ItemData = null) -> ItemData:
	return OrderItemPicker.best_for_category(cat, current_tier, current_item)

func get_any_item_for_category(cat: String, prefer_hint: bool = false) -> ItemData:
	return OrderItemPicker.any_for_category(cat, current_tier, prefer_hint)

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
	
	var target_item := OrderItemPicker.find_by_name(item_name)
	if not target_item:
		push_warning("[StoryManager] set_desire: No item matching '%s' found in inventory." % item_name)
		return
	
	LogManager.info("StoryManager", "SET_DESIRE: Matched '%s' -> '%s'" % [item_name, target_item.item_name])
	
	var transaction = customer.transaction_context
	var typed_list: Array[ItemData] = [target_item]
	transaction.desired_items.assign(typed_list)
	
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


## Helper to see if a label exists in a timeline file (.dtl) safely without crashing.
func is_label_in_timeline(path, label_name: String) -> bool:
	return TimelineLabels.has_label(path, label_name)


func is_past_closing_time() -> bool:
	return clock.is_past_closing_time()

func reset_to_morning() -> void:
	clock.reset_to_morning()

func has_pending_tier_advance() -> bool:
	return _pending_tier_advance_source != ""
