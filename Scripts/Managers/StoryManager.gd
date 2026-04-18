extends Node

var save_id: String = "story_manager"

## StoryManager — manages story progression and builds customer transactions.
## The clock runs freely from DAY_START_HOUR to CLOSING_HOUR with no event slots.

const DAY_START_HOUR := 5.0
const CLOSING_HOUR   := 20.0  ## 8 PM — no new customers after this
## 1 in-game hour = 25 real seconds.
const CLOCK_SPEED_HOURS_PER_SEC := 1.0 / 25.0

var day: int = 1

var todays_focus_character_path: String = ""
var _last_focus_character_path: String = ""
var todays_story_counts: Dictionary = {}

var character_story_states: Dictionary = {}
var encountered_characters: Dictionary = {}
var is_clock_running: bool = false:
	set(value):
		is_clock_running = value
		_ensure_tod_node()
		if _time_of_day_node:
			_time_of_day_node.game_time_enabled = is_clock_running

var _last_character_path: String = ""
var _pending_tier_advance_source: String = ""
var has_mayari_visited: bool = false
var customer_debts: Dictionary = {}




# --- Story Progression ---
var global_story_cooldown: int = 0
var last_story_advancer_path: String = ""
var _first_customer_of_day: bool = true

var _char_lookup: Dictionary = {}   # resource_path -> CustomerData

## DEBUG: Set to true to cycle Sarimanok through STORY -> PURCHASE -> VISIT each spawn.
var DEBUG_SARIMANOK_ONLY: bool = true
var _debug_sarimanok_cycle: int = 0  # 0=STORY, 1=PURCHASE, 2=VISIT

# --- Tier Progression ---
var current_tier: int = 1
var max_unlocked_tier: int = 1
var purchase_counter: int = 0:
	set(value):
		purchase_counter = value
		if purchase_counter >= 8:
			if max_unlocked_tier < 10:
				max_unlocked_tier += 1
				_pending_tier_advance_source = "Activity"
			purchase_counter = 0

var pending_upgrade_tier: int = 0
var pending_upgrade_cost: float = 0.0
var _upgrade_item_cache: Dictionary = {}


@export_group("Transaction Probabilities")
## Chance (0.0 to 1.0) that a customer will start with a rumor.
@export_range(0, 1) var rumor_chance: float = 0.20
## Chance (0.0 to 1.0) that a customer will ask for debt (utang).
@export_range(0, 1) var debt_chance: float = 0.15
## Chance (0.0 to 1.0) that a customer will just visit without buying.
@export_range(0, 1) var visit_chance: float = 0.20
## Chance (0.0 to 1.0) that a customer's request will be a riddle.
@export_range(0, 1) var riddle_chance: float = 0.20

## Float representation of the currently displayed in-game hour (0–24).
var _current_display_time: float = 16.0
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
	print("[DEBUG] StoryManager._ready() START")
	add_to_group("persist")
	EventBus.day_started.connect(_on_day_started)
	EventBus.customer_satisfied.connect(_on_customer_satisfied)
	EventBus.customer_dismissed.connect(_on_customer_dismissed)
	
	_ensure_tod_node()
	if _time_of_day_node and not _time_of_day_node.time_changed.is_connected(_on_tod_time_changed):
		_time_of_day_node.time_changed.connect(_on_tod_time_changed)
	
	# Initial child character data into a lookup map for faster retrieval
	for c in available_characters:
		if c:
			_char_lookup[c.resource_path] = c
	
	randomize()
	print("[DEBUG] StoryManager._ready() END")
	
func _on_tod_time_changed(t: float) -> void:
	_current_display_time = t
	
	# End of day check
	if _current_display_time >= CLOSING_HOUR and is_clock_running:
		is_clock_running = false
		_current_display_time = CLOSING_HOUR
		_apply_display_time(CLOSING_HOUR)
		EventBus.closing_time_reached.emit()

func _on_day_started(new_day: int) -> void:
	print("[DEBUG] StoryManager._on_day_started(%d) CALLED" % new_day)
	day = new_day
	has_mayari_visited = false
	_first_customer_of_day = true
	todays_story_counts.clear()
	_setup_daily_focus()
	print("[StoryManager] Day ", day, " starts.")

func _setup_daily_focus() -> void:
	var unlocked = _get_unlocked_characters()
	if unlocked.is_empty():
		todays_focus_character_path = ""
		return
	
	match day:
		1:
			todays_focus_character_path = "res://Resources/customers/KuyaKap.tres"
		2:
			todays_focus_character_path = "res://Resources/customers/Buboy.tres"
		3:
			todays_focus_character_path = "res://Resources/customers/ManangAna.tres"
		_:
			# Filter to avoid repeating the same focus character as yesterday
			var possible_focus = unlocked.filter(func(c): return c.resource_path != _last_focus_character_path)
			if possible_focus.is_empty(): 
				possible_focus = unlocked
				
			var focus_char = possible_focus.pick_random()
			todays_focus_character_path = focus_char.resource_path

	_last_focus_character_path = todays_focus_character_path
	
	var focus_display = todays_focus_character_path.get_file().get_basename()
	print("[StoryManager] Day ", day, " focus character is: ", focus_display)

func advance_tier(source: String = "Manual") -> void:
	if current_tier >= 10:
		return
		
	current_tier += 1
	purchase_counter = 0
	pending_upgrade_tier = 0
	pending_upgrade_cost = 0.0
	print("[StoryManager] TIER ADVANCED to ", current_tier, " via ", source)
	
	# Save state
	_save_progression()
	
	# Trigger rewards
	EventBus.tier_advanced.emit(current_tier, source)

func get_upgrade_cost(target_tier: int) -> float:
	return 100.0 + float(target_tier - 2) * 25.0

## Returns a virtual ItemData representating a store upgrade for a specific tier.
func get_tier_upgrade_item(target_tier: int) -> ItemData:
	if _upgrade_item_cache.has(target_tier):
		return _upgrade_item_cache[target_tier]
		
	var item = ItemData.new()
	item.item_name = "Tier %d Upgrade" % target_tier
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
		# Queue the upgrade for purchase instead of auto-unlocking
		pending_upgrade_tier = current_tier + 1
		pending_upgrade_cost = get_upgrade_cost(pending_upgrade_tier)
		
		# Collect items being unlocked in this tier
		var new_items: Array[ItemData] = []
		for item in InventoryManager.get_all_items():
			if item.tier == pending_upgrade_tier:
				new_items.append(item)
		
		_pending_tier_advance_source = ""
		
		# Notify the player to call Uncle Mario
		EventBus.upgrade_available.emit(pending_upgrade_tier, pending_upgrade_cost, new_items)
		_save_progression()

func _save_progression() -> void:
	SaveManager.force_save()

# ── Persistence ──────────────────────────────────────────────────────────

func get_save_id() -> String:
	return "progression"

func get_save_data() -> Dictionary:
	return {
		"day": day,
		"current_tier": current_tier,
		"max_unlocked_tier": max_unlocked_tier,
		"purchase_counter": purchase_counter,
		"character_story_states": character_story_states.duplicate(),
		"encountered_characters": encountered_characters.duplicate(),
		"customer_debts": customer_debts.duplicate(),
		"global_story_cooldown": global_story_cooldown,
		"last_story_advancer_path": last_story_advancer_path,
		"todays_focus_character_path": todays_focus_character_path,
		"pending_upgrade_tier": pending_upgrade_tier,
		"pending_upgrade_cost": pending_upgrade_cost,
		"has_mayari_visited": has_mayari_visited,
		"current_display_time": _current_display_time,
	}

func load_save_data(data: Dictionary) -> void:
	day = data.get("day", 1)
	current_tier = data.get("current_tier", 1)
	max_unlocked_tier = data.get("max_unlocked_tier", 1)
	purchase_counter = data.get("purchase_counter", 0)
	character_story_states = data.get("character_story_states", {})
	
	encountered_characters = data.get("encountered_characters", {})
	for path in character_story_states.keys():
		encountered_characters[path] = true
		
	customer_debts = data.get("customer_debts", {})
	global_story_cooldown = data.get("global_story_cooldown", 0)
	last_story_advancer_path = data.get("last_story_advancer_path", "")
	todays_focus_character_path = data.get("todays_focus_character_path", "")
	pending_upgrade_tier = data.get("pending_upgrade_tier", 0)
	pending_upgrade_cost = data.get("pending_upgrade_cost", 0.0)
	has_mayari_visited = data.get("has_mayari_visited", false)
	_current_display_time = data.get("current_display_time", DAY_START_HOUR)
	
	_ensure_tod_node()
	_apply_display_time(_current_display_time)
	
	print("[StoryManager] State loaded. Tier %d, Day %d, Time %.2f, Characters tracked: %d" % [current_tier, day, _current_display_time, character_story_states.size()])


func reset_state() -> void:
	day = 1
	current_tier = 1
	purchase_counter = 0
	pending_upgrade_tier = 0
	pending_upgrade_cost = 0.0
	global_story_cooldown = 0
	last_story_advancer_path = ""
	character_story_states = {}
	encountered_characters = {}
	todays_focus_character_path = ""
	_last_focus_character_path = ""
	todays_story_counts = {}
	customer_debts = {}
	_current_display_time = DAY_START_HOUR

	SaveManager.delete_save()
	print("[StoryManager] Progression reset for New Game. Save file deleted.")


## Ask the StoryManager for the next customer's context.
## Returns null only if no characters are configured.
func get_next_transaction() -> TransactionContext:
	# --- TUTORIAL INJECTION ---
	var tutorial_path := "res://Resources/customers/UncleMario.tres"
	var tutorial_chapter = character_story_states.get(tutorial_path, 0)
	if day == 1 and tutorial_chapter == 0:
		var tutorial_char_data = preload("res://Resources/customers/UncleMario.tres")
		var tutorial_t = TransactionContext.new()
		tutorial_t.customer_data = tutorial_char_data
		
		# Build context explicitly for the tutorial — use VISIT so it plays from
		# the top of the file, not from a "Greeting" label (which doesn't exist).
		tutorial_t.transaction_type = TransactionContext.Type.VISIT
		tutorial_t.timeline = tutorial_char_data.story_timelines[0]
		
		# Specifically require Anoba for the tutorial task
		var anoba = preload("res://Resources/items/snack/Anoba.tres")
		tutorial_t.desired_items.append(anoba)
		
		# We don't advance the tutorial_chapter here anymore. 
		# It will be advanced in _on_customer_satisfied to ensure it actually happened.
		
		print("[STORY] Spawning Uncle Mario Tutorial")
		return tutorial_t
	# --------------------------

	# --- BRAHIM INJECTION ---
	var brahim_tut_path := "brahim_day1_spawned"
	var brahim_spawned = character_story_states.get(brahim_tut_path, 0)
	if day == 1 and tutorial_chapter >= 1 and brahim_spawned == 0:
		var brahim_data = preload("res://Resources/customers/Brahim.tres")
		var brahim_t = TransactionContext.new()
		brahim_t.customer_data = brahim_data
		
		# Build regular transaction context (Purchase/Visit)
		_build_transaction_context(brahim_t, brahim_data)
		
		# Flag so it doesn't repeat
		character_story_states[brahim_tut_path] = 1
		encountered_characters[brahim_data.resource_path] = true
		
		# Sync Dialogic variables so the Greeting dialogue can display properly
		# (normally done at the end of get_next_transaction, but we return early here)
		Dialogic.VAR.set_variable("Global.RumorActive", 0.0)
		Dialogic.VAR.set_variable("Global.RumorType", 0.0)
		Dialogic.VAR.set_variable("Global.AwarenessActive", 0.0)
		Dialogic.VAR.set_variable("Global.HighPriceActive", 0.0)
		Dialogic.VAR.set_variable("Global.StockStatus", "Normal")
		Dialogic.VAR.set_variable("Transaction.WantsDebt", 0.0)
		Dialogic.VAR.set_variable("Transaction.IsRepaying", 0.0)
		Dialogic.VAR.set_variable("Transaction.RepaymentAmount", 0.0)
		Dialogic.VAR.set_variable("Transaction.IsRiddle", 0.0)
		Dialogic.VAR.set_variable("Transaction.CustomerName", brahim_data.character_name)
		# Build item name string for the dialogue
		var item_names: Array[String] = []
		for item in brahim_t.desired_items:
			item_names.append(item.item_name)
		var formatted_names = ""
		if item_names.size() == 1:
			formatted_names = item_names[0]
		elif item_names.size() == 2:
			formatted_names = item_names[0] + " and " + item_names[1]
		elif item_names.size() > 2:
			var last = item_names.pop_back()
			formatted_names = ", ".join(item_names) + ", and " + last
		Dialogic.VAR.set_variable("Transaction.ItemWants", formatted_names)
		var b_chapter = character_story_states.get(brahim_data.resource_path, 0)
		Dialogic.VAR.set_variable("Transaction.CurrentArc", brahim_data.get_arc_index(b_chapter) + 1)
		_first_customer_of_day = false
		
		print("[STORY] Spawning Brahim after Dual Customer injection (ItemWants: %s)" % formatted_names)
		return brahim_t
	# --------------------------


	if available_characters.is_empty():
		return null

	var char_data: CustomerData = null
	var force_story = false
	
	# Priority 1: Check if a story chapter is ready to be forced
	var unlocked = _get_unlocked_characters()
	if global_story_cooldown <= 0:
		var story_candidates: Array[CustomerData] = []
		for c in unlocked:
			# Skip the character who just progressed
			if c.resource_path == last_story_advancer_path: continue
			# Skip if it was the last character to avoid back-to-back spawns
			if c.resource_path == _last_character_path: continue
			
			var c_chapter = character_story_states.get(c.resource_path, 0)
			var _daily_count = todays_story_counts.get(c.resource_path, 0)
			
			# Needs to have a story timeline available and pass prerequisites
			if c_chapter < c.story_timelines.size() and _is_story_chapter_available(c, c_chapter):
				story_candidates.append(c)
		
		# Deadlock Check: If we have chapters available but NO candidates passed prerequisites
		if story_candidates.is_empty():
			var blocked_story_exists = false
			for c in available_characters:
				var c_chapter = character_story_states.get(c.resource_path, 0)
				if c_chapter < c.story_timelines.size():
					blocked_story_exists = true
					break
			if blocked_story_exists:
				print("[StoryManager] WARNING: Potential Story Deadlock. Chapters are available but prerequisites are not met.")
		
		# If we have candidates, we force their story transaction
		if not story_candidates.is_empty():
			# Multi-story enhancement: 60% chance to pick focus if they are among candidates
			var prioritize_focus = randf() < 0.6
			var focus_candidate = null
			if prioritize_focus:
				for c in story_candidates:
					if c.resource_path == todays_focus_character_path:
						focus_candidate = c
						break
			
			if focus_candidate:
				print("[StoryManager] Forcing story for FOCUS character: ", focus_candidate.get_clean_id())
				char_data = focus_candidate
			else:
				char_data = story_candidates.pick_random()
				print("[StoryManager] Cooldown 0: Forcing story for: ", char_data.get_clean_id())
			
			force_story = true
		else:
			# Fix #1: Soft Lock check. 
			# If everything was skipped because of last_story_advancer_path, but that character 
			# still has story, allow them to proceed if no one else can.
			var fallback_story_candidates: Array[CustomerData] = []
			for c in unlocked:
				if c.resource_path == _last_character_path: continue
				var c_chapter = character_story_states.get(c.resource_path, 0)
				if c_chapter < c.story_timelines.size() and _is_story_chapter_available(c, c_chapter):
					fallback_story_candidates.append(c)
			
			if not fallback_story_candidates.is_empty():
				char_data = fallback_story_candidates.pick_random()
				force_story = true
				print("[StoryManager] Cooldown 0: Soft-lock override. Forcing story for: ", char_data.get_clean_id())

	# Priority 2: Generic flow if no story is forced, or cooldown is active
	if not char_data:
		# 1. Selection with Sequential Guard (Prevent same character twice in a row)
		var possible_chars = unlocked.filter(func(c): return c.resource_path != _last_character_path)
		if possible_chars.is_empty(): possible_chars = unlocked # Fallback
		char_data = possible_chars.pick_random()

	# DEBUG: Cycle Sarimanok through STORY -> PURCHASE -> VISIT when flag is set.
	if DEBUG_SARIMANOK_ONLY:
		const SARIMANOK_PATH := "res://Resources/customers/Sarimanok.tres"
		var smk: CustomerData = _char_lookup.get(SARIMANOK_PATH)
		if smk:
			char_data = smk
			force_story = false  # we'll set type manually below
			var cycle_names := ["STORY", "PURCHASE", "VISIT"]
			print("[DEBUG] Sarimanok cycle %d (%s)" % [_debug_sarimanok_cycle, cycle_names[_debug_sarimanok_cycle]])
			
			_last_character_path = char_data.resource_path
			var t_dbg = TransactionContext.new()
			t_dbg.customer_data = char_data
			var smk_chapter = character_story_states.get(SARIMANOK_PATH, 0)
			
			match _debug_sarimanok_cycle:
				0: # STORY
					t_dbg.transaction_type = TransactionContext.Type.STORY
					t_dbg.timeline = smk.story_timelines[smk_chapter] if smk_chapter < smk.story_timelines.size() else smk.story_timelines[0]
				1: # PURCHASE
					t_dbg.transaction_type = TransactionContext.Type.PURCHASE
					var pool = smk.get_purchase_timelines(smk_chapter)
					t_dbg.timeline = pool.pick_random() if not pool.is_empty() else "res://Dialogue/Timelines/Generic/Purchase.dtl"
					_build_transaction_context(t_dbg, smk, false)  # populates desired_items
				2: # VISIT
					t_dbg.transaction_type = TransactionContext.Type.VISIT
					var pool = smk.get_visit_timelines(smk_chapter)
					t_dbg.timeline = pool.pick_random() if not pool.is_empty() else "res://Dialogue/Timelines/Generic/Visit.dtl"
			
			_debug_sarimanok_cycle = (_debug_sarimanok_cycle + 1) % 3
			
			# Sync Dialogic vars the same way the normal path does
			Dialogic.VAR.set_variable("Transaction.CustomerName", smk.character_name)
			Dialogic.VAR.set_variable("Transaction.Chapter", float(smk_chapter))
			Dialogic.VAR.set_variable("Transaction.CurrentArc", smk.get_arc_index(smk_chapter) + 1)
			return t_dbg

	_last_character_path = char_data.resource_path
	
	var t = TransactionContext.new()
	t.customer_data = char_data
	
	_build_transaction_context(t, char_data, force_story)
	
	if not force_story:
		_first_customer_of_day = false
	
	# 2. Independent Feature Rolls
	
	# A. Environmental Awareness
	var awareness_roll = randf()
	var awareness_active = awareness_roll < 0.4 # 40% chance for awareness preamble
	
	# B. Price Sensitivity
	var high_price_roll = randf()
	var high_price_ratio = _get_high_pricing_ratio()
	var high_price_active = high_price_ratio >= 0.5 and high_price_roll < 0.4
	
	var total_stock = 0
	total_stock += InventoryManager.get_total_owned_count(ItemData.ItemType.SHELF)
	total_stock += InventoryManager.get_total_owned_count(ItemData.ItemType.FRIDGE)
	total_stock += InventoryManager.get_total_owned_count(ItemData.ItemType.CANDY_CONTAINER)
	total_stock += InventoryManager.get_total_owned_count(ItemData.ItemType.SACHET_CONTAINER)

	var stock_status = "Normal"
	if total_stock == 0:
		stock_status = "Empty"
	elif total_stock < 10:
		stock_status = "Low"
		
	Dialogic.VAR.set_variable("Global.AwarenessActive", 1.0 if awareness_active else 0.0)
	Dialogic.VAR.set_variable("Global.HighPriceActive", 1.0 if high_price_active else 0.0)
	Dialogic.VAR.set_variable("Global.StockStatus", stock_status)
	
	# B. Dual Customer (Story Events only)
	# Handled explicitly by story logic, no random chance.
	
	# C. Rumor Mill
	var last_cust = Dialogic.VAR.get_variable("Global.LastCustomer")
	var rumor_roll = randf()
	var current_cust_id = t.customer_data.get_clean_id()
	if last_cust != "" and last_cust != current_cust_id and rumor_roll < rumor_chance:
		t.rumor_active = true
		t.rumor_type = 1.0 if randf() < 0.5 else 0.0
	else:
		t.rumor_active = false
	
	# B. Utang (Debt)
	var debt_roll = randf()
	if t.transaction_type == TransactionContext.Type.PURCHASE and debt_roll < debt_chance:
		t.wants_debt = true
	else:
		t.wants_debt = false
		
	# B-2. Repayment
	var repay_roll = randf()
	var current_debt = customer_debts.get(t.customer_data.resource_path, 0.0)
	if current_debt > 0 and repay_roll < 0.30:
		t.is_repaying = true
		t.repayment_amount = current_debt
		print("[StoryManager] REPAYMENT ROLLED: ", current_debt)
	
	# C. Riddle (Tingting)

	# Only possible if there are items and the main item has a hint
	var riddle_roll = randf()
	if not t.desired_items.is_empty() and t.transaction_type != TransactionContext.Type.VISIT:
		var main_item = t.desired_items[0]
		if main_item.item_hint != "" and riddle_roll < riddle_chance:
			t.is_riddle = true
			t.riddle_item = main_item
			Dialogic.VAR.set_variable("Transaction.ItemHint", main_item.item_hint)
			
			# Special rule: Riddles can only be for a single item.
			if t.desired_items.size() > 1:
				print("[StoryManager] Riddle rolled for multi-item request. Trimming to 1 item.")
				t.desired_items = [main_item]
	
	# 3. Sync to Dialogic Variables
	Dialogic.VAR.set_variable("Global.RumorActive", 1.0 if t.rumor_active else 0.0)
	Dialogic.VAR.set_variable("Global.RumorType", t.rumor_type)
	Dialogic.VAR.set_variable("Transaction.WantsDebt", 1.0 if t.wants_debt else 0.0)
	Dialogic.VAR.set_variable("Transaction.IsRepaying", 1.0 if t.is_repaying else 0.0)
	Dialogic.VAR.set_variable("Transaction.RepaymentAmount", t.repayment_amount)
	Dialogic.VAR.set_variable("Transaction.IsRiddle", 1.0 if t.is_riddle else 0.0)
	Dialogic.VAR.set_variable("Transaction.ItemWantsBest", t.best_item_name)

	
	var chapter = character_story_states.get(t.customer_data.resource_path, 0)
	Dialogic.VAR.set_variable("Transaction.CurrentArc", t.customer_data.get_arc_index(chapter) + 1)
	Dialogic.VAR.set_variable("Transaction.Chapter", float(chapter))

	print("\n[STORY] --- Transaction Attributes ---")
	print("  Rumor : ", t.rumor_active, " (Roll: ", rumor_roll, " < ", rumor_chance, ")")
	print("  Riddle: ", t.is_riddle, " (Roll: ", riddle_roll, " < ", riddle_chance, ")")
	print("  Debt  : ", t.wants_debt, " (Roll: ", debt_roll, " < ", debt_chance, ")")
	print("  Repay : ", t.is_repaying, " (Roll: ", repay_roll, " < 0.30, Owed: ", current_debt, ")")


	print("[STORY] Debt Roll:  ", debt_roll, " (Target < 0.15) -> ", t.wants_debt)
	print("[STORY] Riddle State: ", t.is_riddle) # Riddle chance check remains in _build since it needs items

	# Track the initial count for progress UI
	t.original_count = t.desired_items.size()
	
	if t.customer_data and not encountered_characters.has(t.customer_data.resource_path):
		encountered_characters[t.customer_data.resource_path] = true
		_save_progression()
	
	return t

## Returns a special transaction for Reyna Mayari's end-of-day debt collection.
func get_collection_transaction() -> TransactionContext:
	if has_mayari_visited:
		return null
		
	var data = _get_character_data("res://Resources/customers/ReynaMayari.tres")
	if not data:
		# Fallback if the path is wrong
		data = _get_character_data("reynamayari")
	
	if not data:
		push_error("[StoryManager] Could not find Reyna Mayari data for collection!")
		return null
		
	var t = TransactionContext.new()
	t.customer_data = data
	t.transaction_type = TransactionContext.Type.VISIT
	t.timeline = "res://Dialogue/Timelines/mayari_collect.dtl"
	
	has_mayari_visited = true
	encountered_characters[data.resource_path] = true
	return t

func record_debt(customer_path: String, amount: float) -> void:
	var current = customer_debts.get(customer_path, 0.0)
	customer_debts[customer_path] = current + amount
	print("[StoryManager] Recorded Debt for %s: +%.2f (Total: %.2f)" % [customer_path.get_file(), amount, customer_debts[customer_path]])
	_save_progression()

func clear_debt(customer_path: String) -> void:
	if customer_debts.has(customer_path):
		customer_debts.erase(customer_path)
		print("[StoryManager] Debt CLEARED for %s" % customer_path.get_file())
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
	var h: int = int(t)
	var m: int = int((t - h) * 60.0)
	_time_of_day_node.set_time(h, m, 0)

func _ensure_tod_node() -> void:
	if not is_instance_valid(_time_of_day_node):
		_time_of_day_node = get_tree().root.find_child("TimeOfDay", true, false)
		if is_instance_valid(_time_of_day_node):
			if not _time_of_day_node.time_changed.is_connected(_on_tod_time_changed):
				_time_of_day_node.time_changed.connect(_on_tod_time_changed)

func complete_tutorial() -> void:
	var tutorial_path := "res://Resources/customers/UncleMario.tres"
	character_story_states[tutorial_path] = 1
	_save_progression()
	print("[StoryManager] Uncle Mario tutorial marked as complete (Manually).")

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
func _build_transaction_context(t: TransactionContext, data: CustomerData, force_story: bool = false) -> void:
	# 1. Reset Social flags in context object (GDScript base)
	t.is_riddle = false
	t.wants_debt = false
	# We will sync these to Dialogic at the end of get_next_transaction().

	# 2. Choose Transaction Type
	var path = data.resource_path
	var chapter = character_story_states.get(path, 0)
	
	# If this is their first visit (chapter 0) OR the system forced a story chapter
	if (chapter == 0 or force_story) and chapter < data.story_timelines.size():
		t.transaction_type = TransactionContext.Type.STORY
		t.timeline = data.story_timelines[chapter]
	else:
		# Generic flow selection: use the exported visit_chance (default 20%)
		# Force a purchase if it is the first regular customer of the day.
		var is_purchase = true
		if _first_customer_of_day:
			print("[StoryManager] First customer of the day. Forcing PURCHASE.")
		else:
			is_purchase = randf() < (1.0 - visit_chance)
			
		if data.get_clean_id() == "sarimanok" and chapter <= 3.0:
			is_purchase = false
			print("[StoryManager] Sarimanok is in Early Arc (Chapter <= 3.0). Forcing VISIT.")
			
		var purchase_pool = data.get_purchase_timelines(chapter)
		var visit_pool = data.get_visit_timelines(chapter)
		
		if is_purchase and not purchase_pool.is_empty():
			t.transaction_type = TransactionContext.Type.PURCHASE
			t.timeline = purchase_pool.pick_random()
		elif not visit_pool.is_empty():
			t.transaction_type = TransactionContext.Type.VISIT
			t.timeline = visit_pool.pick_random()
		else:
			# Fallback to last resort
			t.transaction_type = TransactionContext.Type.PURCHASE
			t.timeline = "res://Dialogue/Timelines/Generic/Purchase.dtl"
		
		# Log the selection
		var type_str = "VISIT" if t.transaction_type == TransactionContext.Type.VISIT else "PURCHASE"
		print("[StoryManager] Selection for %s: %s (Timeline: %s)" % [data.character_name, type_str, t.timeline])

	# 2. Assign Desired Items (unless it's a social visit)
	if t.transaction_type != TransactionContext.Type.VISIT:
		# If a category was requested, resolve to the best item in that category
		if t.requested_category != "":
			var best = get_best_item_for_category(t.requested_category)
			if best:
				t.desired_items.append(best)
				t.best_item_name = best.item_name
				print("[StoryManager] Category request: %s -> Best item: %s" % [t.requested_category, t.best_item_name])
			else:
				push_warning("[StoryManager] Requested category '%s' found no valid items!" % t.requested_category)

		var pool: Array[ItemData] = []
		
		# --- 60/40 Item Selection Logic ---
		var selection_roll = randf()
		
		if selection_roll < 0.4:
			# 40% Chance: Pick from available items currently on display or in stock
			print("[StoryManager] Selection Mode: DISPLAY STOCK (40% roll)")
			var display_pool = InventoryManager.get_items_available_on_display()
			for item in display_pool:
				if is_item_unlocked(item) and item.can_be_sold:
					pool.append(item)
					
		if selection_roll >= 0.4 or pool.is_empty():
			# 60% Chance (or fallback): Pick from the default cumulative tier rank pool
			if selection_roll < 0.4:
				print("[StoryManager] Fallback: Display stock empty. Reverting to CUMULATIVE TIER pool.")
			else:
				print("[StoryManager] Selection Mode: CUMULATIVE TIER (60% roll)")
				
				for item in InventoryManager.get_all_items():
					if is_item_unlocked(item) and item.can_be_sold:
						pool.append(item)

		# Multi-item request logic based on Tier
		# Skip if we already fulfilled via requested_category
		if t.requested_category == "":
			var item_count = _get_item_count_for_tier(current_tier)
			for i in range(item_count):
				if not pool.is_empty():
					t.desired_items.append(pool.pick_random())
				else:
					var fallback = _pick_random_orderable_item()
					if fallback:
						t.desired_items.append(fallback)
		
		# Safety: If we still have no items, convert to a visit
		if t.desired_items.is_empty():

			print("[StoryManager] Critical: No items found for purchase, converting to VISIT for: ", data.character_name)
			t.transaction_type = TransactionContext.Type.VISIT
			t.timeline = "res://Dialogue/Timelines/Generic/Visit.dtl"


## Returns the number of items a customer should request based on the current tier.
func _get_item_count_for_tier(tier: int) -> int:
	var roll = randf() * 100.0
	
	match tier:
		1:
			if roll < 80: return 1
			else: return 2
		2:
			if roll < 70: return 1
			else: return 2
		3:
			if roll < 50: return 1
			elif roll < 90: return 2
			else: return 3
		4:
			if roll < 30: return 1
			elif roll < 70: return 2
			else: return 3
		_: # Tier 5 and onwards
			if roll < 20: return 1
			elif roll < 60: return 2
			else: return 3

## Returns a random item that is unlocked for the current day.
## Prioritizes items that are currently in stock. 
## Fallback: picks an unlocked item even if out of stock (prevents "something" dialogue gap).
func _pick_random_orderable_item() -> ItemData:
	var all_unlocked: Array[ItemData] = []
	
	for item in InventoryManager.get_all_items():
		if is_item_unlocked(item) and item.can_be_sold:
			all_unlocked.append(item)

	if not all_unlocked.is_empty():
		return all_unlocked.pick_random()
		
	push_warning("[StoryManager] No unlocked items available at all for fallback filler.")
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
	Dialogic.VAR.set_variable("Global.LastSatisfaction", "Happy")
	
	_process_story_cooldown(customer)
	
	# Increment purchase counter for activity-based progression
	if customer.transaction_context and customer.transaction_context.transaction_type != TransactionContext.Type.VISIT:
		purchase_counter += 1
		
	# Tutorial Persistence: If this was Uncle Mario, mark the tutorial as complete now.
	if customer.customer_data and customer.customer_data.get_clean_id() == "unclemario":
		var tutorial_path := "res://Resources/customers/UncleMario.tres"
		character_story_states[tutorial_path] = 1
		encountered_characters[tutorial_path] = true
		_save_progression()
		print("[StoryManager] Uncle Mario tutorial successfully completed and saved.")

func _on_customer_dismissed(customer) -> void:
	# Update LastCustomer even if they left dissatisfied so rumors stay current
	_set_last_customer_info(customer)
	Dialogic.VAR.set_variable("Global.LastSatisfaction", "Unhappy")
	
	_process_story_cooldown(customer)

func _set_last_customer_info(customer: Customer) -> void:
	if customer.transaction_context:
		var data = customer.transaction_context.customer_data
		var display_name = data.character_name if data.character_name != "" else data.get_clean_id()
			
		Dialogic.VAR.set_variable("Global.LastCustomer", display_name)
		
		# Save specific item for rumors if applicable
		if not customer.transaction_context.desired_items.is_empty():
			Dialogic.VAR.set_variable("Global.LastItem", customer.transaction_context.desired_items[0].item_name)
		else:
			Dialogic.VAR.set_variable("Global.LastItem", "")

func _process_story_cooldown(customer) -> void:
	if not customer.transaction_context:
		return
		
	if customer.transaction_context.transaction_type == TransactionContext.Type.STORY:
		var path = customer.transaction_context.customer_data.resource_path
		var chapter = character_story_states.get(path, 0)
		character_story_states[path] = chapter + 1
		print("[StoryManager] Advanced story for ", path.get_file(), " to chapter ", chapter + 1)
		
		# Track daily story count
		var current_count = todays_story_counts.get(path, 0)
		todays_story_counts[path] = current_count + 1
		print("[StoryManager] Character ", path.get_file().get_basename(), " now at ", todays_story_counts[path], " story interactions today.")
		
		# If the focus character reaches 3 story interactions in a day, randomize to a new focus character
		if todays_story_counts[path] >= 3 and path == todays_focus_character_path:
			print("[StoryManager] Focus character ", path.get_file().get_basename(), " has reached 3 story interactions. Randomizing new focus character.")
			var unlocked = _get_unlocked_characters()
			var possible_focus = unlocked.filter(func(c): return c.resource_path != todays_focus_character_path)
			if possible_focus.is_empty():
				possible_focus = unlocked
			
			if not possible_focus.is_empty():
				var focus_char = possible_focus.pick_random()
				todays_focus_character_path = focus_char.resource_path
				print("[StoryManager] New focus character is: ", todays_focus_character_path.get_file().get_basename())

		# Story advanced — set cooldown and mark them
		last_story_advancer_path = path
		global_story_cooldown = randi_range(2, 4)
		
		# Narrative Tier Progression Check (Chapters 3 and 6 mark arc boundaries)
		if character_story_states[path] in [3, 6]:
			_pending_tier_advance_source = "Story (%s)" % path.get_file().get_basename()
	
		_save_progression()
	else:
		# Any successful generic transaction (or visit finish) decreases the cooldown
		if global_story_cooldown > 0:
			global_story_cooldown -= 1
			print("[StoryManager] Generic transaction (", TransactionContext.Type.keys()[customer.transaction_context.transaction_type], ") completed. Cooldown remains: ", global_story_cooldown)

func _is_story_chapter_available(customer: CustomerData, chapter: int) -> bool:
	# If no prerequisites defined or array index doesn't exist, assume available
	if chapter >= customer.story_prerequisites.size() or customer.story_prerequisites[chapter] == null:
		return true
		
	return customer.story_prerequisites[chapter].is_met(self)

func _get_high_pricing_ratio() -> float:
	var im = get_node_or_null("/root/InventoryManager")
	if not im: return 0.0
	
	var stocked_items = im.get_all_items().filter(func(i): return im.is_in_stock(i))
	if stocked_items.is_empty():
		return 0.0
		
	var high_priced_count = 0
	for item in stocked_items:
		if item.get_final_price() >= item.get_max_selling_price():
			high_priced_count += 1
			
	return float(high_priced_count) / float(stocked_items.size())

func _get_unlocked_characters() -> Array[CustomerData]:
	var unlocked: Array[CustomerData] = []
	var gm = get_tree().get_first_node_in_group("game_manager")
	var current_quota_day = gm.quota_day if gm else 1
	
	for c in available_characters:
		if not c:
			continue
			
		# Day 1 special rule: Mario is NOT a regular customer, he's a tutorial character.
		if day == 1 and c.get_clean_id() == "unclemario":
			continue
			
		if c.get_clean_id() == "reynamayari":
			if current_quota_day > 2:
				unlocked.append(c)
		elif c.unlock_tier <= current_tier:
			unlocked.append(c)
			
	return unlocked

func get_best_item_for_category(cat: String) -> ItemData:
	var best_item: ItemData = null
	var max_tier = -1
	for item in InventoryManager.get_all_items():
		if item.category == cat and item.tier <= current_tier and item.can_be_sold:
			if item.tier > max_tier:
				max_tier = item.tier
				best_item = item
	return best_item
