extends Node

var save_id: String = "story_manager"

## StoryManager — manages story progression and builds customer transactions.
## The clock runs freely from DAY_START_HOUR to CLOSING_HOUR with no event slots.

const DAY_START_HOUR := 5.0
const MENU_THEME_HOUR := 16.89 ## Golden hour aesthetic for Main Menu
const CLOSING_HOUR   := 20.0  ## 8 PM — no new customers after this
## 1 in-game hour = 30 real seconds.
const CLOCK_SPEED_HOURS_PER_SEC := 1.0 / 50.0

var day: int = 1

var todays_focus_character_path: String = ""
var _last_focus_character_path: String = ""
var todays_story_counts: Dictionary = {}

var character_story_states: Dictionary = {}
var customer_story_branches: Dictionary = {}
var encountered_characters: Dictionary = {}
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




# --- Story Progression ---
var global_story_cooldown: int = 0
var last_story_advancer_path: String = ""
var _first_customer_of_day: bool = true

var _char_lookup: Dictionary = {}   # resource_path -> CustomerData

## DEBUG: Set to true to cycle Sarimanok through STORY -> PURCHASE -> VISIT each spawn.
var DEBUG_SARIMANOK_ONLY: bool = false
var _debug_sarimanok_cycle: int = 0  # 0=STORY, 1=PURCHASE, 2=VISIT


# --- Tier Progression ---
var current_tier: int = 1
var max_unlocked_tier: int = 1
var _last_tier_unlocked_notification: int = 0
var _last_notified_tier: int = 0
var purchase_counter: int = 0:
	set(value):
		purchase_counter = value
		if purchase_counter >= 5:
			if max_unlocked_tier < 10:
				max_unlocked_tier += 1
				_pending_tier_advance_source = "Activity"
				_last_tier_unlocked_notification = max_unlocked_tier
			purchase_counter = 0

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

# --- Transaction Mirroring (for Dialogic access via {StoryManager.Transaction_...}) ---
var Transaction_CustomerName: String = ""
var Transaction_ItemWants: String = ""
var Transaction_ItemWantsID: String = ""
var Transaction_ItemWantsBest: String = ""
var Transaction_HighestItemWants: String = ""
var Transaction_ItemAnyWants: String = ""
var Transaction_ItemHint: String = ""
var Transaction_WantsDebt: bool = false
var Transaction_IsRepaying: bool = false
var Transaction_IsNextTier: bool = false
var Transaction_RepaymentAmount: float = 0.0
var Transaction_IsRiddle: bool = false
var Transaction_CurrentArc: int = 0
var Transaction_Chapter: int = 0
var Transaction_Branch: float = 0.0
var Transaction_DeliveredCount: int = 0
var Transaction_RemainingCount: int = 0
var Transaction_GreetingVar: float = 0.0
var Transaction_TalkVar: float = 0.0
var Transaction_SatisfyVar: float = 0.0
var Transaction_WrongItemVar: float = 0.0
var Transaction_VisitVar: float = 0.0

# --- Safe Dialogic Synchronization ---

## Safely sets a Dialogic variable only if it exists in the Dialogic system.
## Also automatically mirrors the value to the local Autoload properties (e.g. "Transaction_ItemWants")
func _set_dvar(path: String, value) -> void:
	# 1. Update the local mirrored property
	var underscore_path = path.replace(".", "_")
	var dot_path = path.replace("_", ".")
	
	if underscore_path in self:
		self.set(underscore_path, value)
	
	# We check existence for each to avoid console spam "Tried setting non-existant variable".
	if Dialogic.VAR.has(path):
		Dialogic.VAR.set_variable(path, value)
	
	if underscore_path != path and Dialogic.VAR.has(underscore_path):
		Dialogic.VAR.set_variable(underscore_path, value)
		
	if dot_path != path and Dialogic.VAR.has(dot_path):
		Dialogic.VAR.set_variable(dot_path, value)
	
	# Special legacy mapping
	var story_mgr_path = "StoryManager." + underscore_path
	if Dialogic.VAR.has(story_mgr_path):
		Dialogic.VAR.set_variable(story_mgr_path, value)
	# No else: we silent the error if it doesn't exist

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
	print("[DEBUG] StoryManager._ready() START")
	add_to_group("persist")
	EventBus.day_started.connect(_on_day_started)
	EventBus.customer_satisfied.connect(_on_customer_satisfied)
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
	print("[DEBUG] StoryManager._ready() END")
	
func _on_tod_time_changed(t: float) -> void:
	_current_display_time = t
	
	# End of day check: strictly cap at CLOSING_HOUR
	if _current_display_time >= CLOSING_HOUR:
		if is_clock_running:
			print("[StoryManager] Closing Time Reached (8 PM). Pausing clock.")
			is_clock_running = false
			_current_display_time = CLOSING_HOUR
			_apply_display_time(CLOSING_HOUR)
			EventBus.closing_time_reached.emit()
		elif _current_display_time > CLOSING_HOUR:
			# Safety clamp to prevent time creep while paused with a customer
			_current_display_time = CLOSING_HOUR
			_apply_display_time(CLOSING_HOUR)

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
	return 60.0 + float(target_tier - 2) * 20.0

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
			print("[StoryManager] Skip redundant notification for Tier ", max_unlocked_tier)
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
	SaveManager.force_save()

# ── Persistence ──────────────────────────────────────────────────────────

func get_save_id() -> String:
	return "progression"

func get_save_data() -> Dictionary:
	# Robustness: Explicitly sync time from the sky system before returning save data
	# if we are in the game. This avoids stale time if we haven't received a signal lately.
	_ensure_tod_node()
	if is_instance_valid(_time_of_day_node) and _time_of_day_node.has_method("get"):
		var tod_time = _time_of_day_node.get("current_time")
		if tod_time != null:
			_current_display_time = tod_time
	
	return {
		"day": day,
		"current_tier": current_tier,
		"max_unlocked_tier": max_unlocked_tier,
		"purchase_counter": purchase_counter,
		"character_story_states": character_story_states.duplicate(),
		"customer_story_branches": customer_story_branches.duplicate(),
		"encountered_characters": encountered_characters.duplicate(),
		"customer_debts": customer_debts.duplicate(),
		"global_story_cooldown": global_story_cooldown,
		"last_story_advancer_path": last_story_advancer_path,
		"todays_focus_character_path": todays_focus_character_path,
		"pending_upgrade_tier": pending_upgrade_tier,
		"pending_upgrade_cost": pending_upgrade_cost,
		"has_mayari_visited": has_mayari_visited,
		"is_mayari_debt_active": is_mayari_debt_active,
		"is_mayari_met": is_mayari_met,
		"last_mayari_collection_successful": last_mayari_collection_successful,
		"current_display_time": _current_display_time,
		"is_clock_running": is_clock_running,
		"_last_notified_tier": _last_notified_tier,
	}

func load_save_data(data: Dictionary) -> void:
	day = data.get("day", 1)
	current_tier = data.get("current_tier", 1)
	max_unlocked_tier = data.get("max_unlocked_tier", 1)
	purchase_counter = data.get("purchase_counter", 0)
	character_story_states = data.get("character_story_states", {})
	customer_story_branches = data.get("customer_story_branches", {})
	
	encountered_characters = data.get("encountered_characters", {})
	
	# Migration/Reliability: Ensure anyone with story progress is also marked as encountered.
	# This recovers characters who might have been missed during a save ID migration.
	for path in character_story_states.keys():
		if path.begins_with("res://"):
			encountered_characters[path] = true
		
	customer_debts = data.get("customer_debts", {})
	global_story_cooldown = data.get("global_story_cooldown", 0)
	last_story_advancer_path = data.get("last_story_advancer_path", "")
	todays_focus_character_path = data.get("todays_focus_character_path", "")
	pending_upgrade_tier = data.get("pending_upgrade_tier", 0)
	pending_upgrade_cost = data.get("pending_upgrade_cost", 0.0)
	has_mayari_visited = data.get("has_mayari_visited", false)
	is_mayari_debt_active = data.get("is_mayari_debt_active", true)
	is_mayari_met = data.get("is_mayari_met", false)
	last_mayari_collection_successful = data.get("last_mayari_collection_successful", true)
	_current_display_time = data.get("current_display_time", DAY_START_HOUR)
	is_clock_running = data.get("is_clock_running", false)
	_last_notified_tier = data.get("_last_notified_tier", 0)
	
	# Apply loaded state to the sky system
	_ensure_tod_node()
	if is_instance_valid(_time_of_day_node):
		_apply_display_time(_current_display_time)
		_time_of_day_node.game_time_enabled = is_clock_running
	else:
		# If MainGame is still loading, wait a frame and retry once
		get_tree().process_frame.connect(func():
			_ensure_tod_node()
			if is_instance_valid(_time_of_day_node):
				_apply_display_time(_current_display_time)
				_time_of_day_node.game_time_enabled = is_clock_running
		, CONNECT_ONE_SHOT)
	
	print("[StoryManager] State loaded. Tier %d, Day %d, Time %.2f" % [current_tier, day, _current_display_time])


func reset_state() -> void:
	day = 1
	current_tier = 1
	max_unlocked_tier = 1
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
	has_mayari_visited = false
	is_mayari_debt_active = true
	is_mayari_met = false
	last_mayari_collection_successful = true
	_current_display_time = DAY_START_HOUR
	_last_tier_unlocked_notification = 0
	_pending_tier_advance_source = ""
	_last_notified_tier = 0

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
		tutorial_t.timeline = tutorial_char_data.story_timeline
		
		# Specifically require Anoba for the tutorial task
		var anoba = preload("res://Resources/items/snack/Anoba.tres")
		tutorial_t.desired_items.append(anoba)
		
		# We don't advance the tutorial_chapter here anymore. 
		# It will be advanced in _on_customer_satisfied to ensure it actually happened.
		
		print("[STORY] Spawning Uncle Mario Tutorial")
		return tutorial_t
	# --------------------------

	# --- KUYA KAP INJECTION ---
	var kuyakap_tut_path := "kuyakap_day1_spawned"
	var kuyakap_spawned = character_story_states.get(kuyakap_tut_path, 0)
	if day == 1 and tutorial_chapter >= 1 and kuyakap_spawned == 0:
		var kuyakap_data = preload("res://Resources/customers/KuyaKap.tres")
		var kuyakap_t = TransactionContext.new()
		kuyakap_t.customer_data = kuyakap_data
		
		# Build story transaction context
		_build_transaction_context(kuyakap_t, kuyakap_data, true)
		
		# Flag so it doesn't repeat
		character_story_states[kuyakap_tut_path] = 1
		encountered_characters[kuyakap_data.resource_path] = true
		
		_first_customer_of_day = false
		
		print("[STORY] Spawning Kuya Kap after Tutorial (Story Chapter 0)")
		return kuyakap_t
	# --------------------------


	if available_characters.is_empty():
		return null

	var char_data: CustomerData = null
	var force_story = false
	
	# Priority 0: Forced First-Time Encounters (Ignores Cooldown)
	var unlocked = _get_unlocked_characters()
	var new_characters = unlocked.filter(func(c): 
		var c_ch = character_story_states.get(c.resource_path, 0)
		# NEW: Check c_ch == 0 in addition to encountered_characters as a safeguard against resets.
		# EXCEPTION: Reyna Mayari never triggers story during the day, even for first encounter.
		return (not encountered_characters.has(c.resource_path) or c_ch == 0) \
			and c_ch < c.max_story_chapters and c.story_timeline != null \
			and _is_story_chapter_available(c, c_ch) \
			and c.get_clean_id() != "reynamayari"
	)
	
	if not new_characters.is_empty():
		char_data = new_characters.pick_random()
		force_story = true
		print("[StoryManager] FIRST ENCOUNTER: Forcing story for new character: ", char_data.get_clean_id())
	
	# Priority 1: Check if a story chapter is ready to be forced
	elif global_story_cooldown <= 0:
		var story_candidates: Array[CustomerData] = []
		for c in unlocked:
			# Skip the character who just progressed
			if c.resource_path == last_story_advancer_path: continue
			# Skip if it was the last character to avoid back-to-back spawns
			if c.resource_path == _last_character_path: continue
			# EXCEPTION: Reyna Mayari story only happens at night via special collection.
			if c.get_clean_id() == "reynamayari": continue
			
			var c_chapter = character_story_states.get(c.resource_path, 0)
			var _daily_count = todays_story_counts.get(c.resource_path, 0)
			
			# Needs to have a story timeline available and pass prerequisites
			if c_chapter < c.max_story_chapters and c.story_timeline != null and _is_story_chapter_available(c, c_chapter):
				story_candidates.append(c)
		
		# Deadlock Check: If we have chapters available but NO candidates passed prerequisites
		if story_candidates.is_empty():
			var blocked_story_exists = false
			for c in available_characters:
				var c_chapter = character_story_states.get(c.resource_path, 0)
				if c_chapter < c.max_story_chapters and c.story_timeline != null:
					blocked_story_exists = true
					break
			if blocked_story_exists:
				print("[StoryManager] WARNING: Potential Story Deadlock. Chapters are available but prerequisites are not met.")
		
		# If we have candidates, we force their story transaction
		if not story_candidates.is_empty():
			char_data = _pick_character_weighted(story_candidates)
			if char_data and char_data.resource_path == todays_focus_character_path:
				print("[StoryManager] Forcing story for FOCUS character: ", char_data.get_clean_id())
			else:
				print("[StoryManager] Cooldown 0: Forcing story for: ", char_data.get_clean_id() if char_data else "null")
			
			force_story = true
		else:
			# Fix #1: Soft Lock check. 
			# If everything was skipped because of last_story_advancer_path, but that character 
			# still has story, allow them to proceed if no one else can.
			var fallback_story_candidates: Array[CustomerData] = []
			for c in unlocked:
				if c.resource_path == _last_character_path: continue
				var c_chapter = character_story_states.get(c.resource_path, 0)
				if c_chapter < c.max_story_chapters and c.story_timeline != null and _is_story_chapter_available(c, c_chapter):
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
		
		char_data = _pick_character_weighted(possible_chars)

	_last_character_path = char_data.resource_path

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
					if smk.story_timeline == null:
						print("[DEBUG] Sarimanok has no story timeline. Falling back to PURCHASE.")
						t_dbg.transaction_type = TransactionContext.Type.PURCHASE
						var purchase_pool = smk.get_purchase_timelines(smk_chapter)
						t_dbg.timeline = purchase_pool.pick_random() if not purchase_pool.is_empty() else "res://Dialogue/Timelines/Generic/Purchase.dtl"
						_build_transaction_context(t_dbg, smk, false)
					else:
						t_dbg.transaction_type = TransactionContext.Type.STORY
						t_dbg.timeline = smk.story_timeline
						# Populate desired_items — _build will re-confirm STORY type/timeline via force_story=true
						_build_transaction_context(t_dbg, smk, true)
						print("[DEBUG] Sarimanok STORY selected. Timeline: ", t_dbg.timeline.resource_path if t_dbg.timeline is Resource else t_dbg.timeline)
				1: # PURCHASE
					t_dbg.transaction_type = TransactionContext.Type.PURCHASE
					var pool = smk.get_purchase_timelines(smk_chapter)
					t_dbg.timeline = pool.pick_random() if not pool.is_empty() else "res://Dialogue/Timelines/Generic/Purchase.dtl"
					_build_transaction_context(t_dbg, smk, false)  # populates desired_items
					print("[DEBUG] Sarimanok PURCHASE selected. Timeline: ", t_dbg.timeline.resource_path if t_dbg.timeline is Resource else t_dbg.timeline)
				2: # VISIT
					t_dbg.transaction_type = TransactionContext.Type.VISIT
					var pool = smk.get_visit_timelines(smk_chapter)
					t_dbg.timeline = pool.pick_random() if not pool.is_empty() else "res://Dialogue/Timelines/Generic/Visit.dtl"
					
					# Special: Force is_visit_story for early Sarimanok chapters even if type is STORY
					# (This matches the logic in _build_transaction_context)
					if smk.get_clean_id() == "sarimanok" and smk_chapter <= 3.0:
						t_dbg.is_visit_story = true
					
					print("[DEBUG] Sarimanok VISIT selected. Timeline: ", t_dbg.timeline.resource_path if t_dbg.timeline is Resource else t_dbg.timeline)
			
			_debug_sarimanok_cycle = (_debug_sarimanok_cycle + 1) % 3
			
			# Sync ALL critical Dialogic vars — same as the normal get_next_transaction() path
			_set_dvar("Transaction_CustomerName", smk.character_name)
			_set_dvar("Transaction_Chapter", float(smk_chapter))
			_set_dvar("Transaction_CurrentArc", smk.get_arc_index(smk_chapter) + 1)
			_set_dvar("Transaction_WantsDebt", 1.0 if t_dbg.wants_debt else 0.0)
			_set_dvar("Transaction_IsRepaying", 1.0 if t_dbg.is_repaying else 0.0)
			_set_dvar("Transaction_RepaymentAmount", t_dbg.repayment_amount)
			_set_dvar("Transaction_IsRiddle", 1.0 if t_dbg.is_riddle else 0.0)
			_set_dvar("Transaction_ItemWantsBest", t_dbg.best_item_name)
			_set_dvar("Transaction_GreetingVar", float(randi() % 100))
			_set_dvar("Transaction_TalkVar", float(randi() % 100))
			_set_dvar("Transaction_SatisfyVar", float(randi() % 100))
			_set_dvar("Transaction_WrongItemVar", float(randi() % 100))
			_set_dvar("Transaction_VisitVar", float(randi() % 100))
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
	# Customers complain if any of their requested items are at max price (50% chance)
	var any_item_at_max = false
	for item in t.desired_items:
		if item.get_final_price() >= item.get_max_selling_price():
			any_item_at_max = true
			break
			
	var high_price_roll = randf()
	var high_price_active = any_item_at_max and high_price_roll < 0.5
	
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
		
	_set_dvar("Global_AwarenessActive", 1.0 if awareness_active else 0.0)
	_set_dvar("Global_HighPriceActive", 1.0 if high_price_active else 0.0)
	_set_dvar("Global_StockStatus", stock_status)
	
	# B. Dual Customer (Story Events only)
	# Handled explicitly by story logic, no random chance.
	
	# C. Rumor Mill (Danilo Only)
	var last_cust = Dialogic.VAR.get_variable("Global_LastCustomer")
	var current_cust_id = t.customer_data.get_clean_id()
	if current_cust_id == "danilo" and last_cust != "" and last_cust != "Danilo" and randf() < rumor_chance:
		t.rumor_active = true
		t.rumor_type = 1.0 if randf() < 0.5 else 0.0
	else:
		t.rumor_active = false
	
	# B. Utang (Debt)
	# Random utang is disabled for the initial version.
	# Utang only comes from Manang Ana on PURCHASE transactions.
	const MANANG_ANA_PATH := "res://Resources/customers/ManangAna.tres"
	var debt_roll = randf()  # kept for logging parity
	if t.transaction_type == TransactionContext.Type.PURCHASE \
			and t.customer_data and t.customer_data.resource_path == MANANG_ANA_PATH:
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
		var id = t.customer_data.get_clean_id() if t.customer_data else ""
		var final_riddle_chance = 1.0 if id == "buboy" else riddle_chance
		
		if main_item.item_hint != "" and riddle_roll < final_riddle_chance:
			t.is_riddle = true
			t.riddle_item = main_item
			_set_dvar("Transaction_ItemHint", main_item.item_hint)
			
			# Special rule: Riddles can only be for a single item.
			if t.desired_items.size() > 1:
				print("[StoryManager] Riddle rolled for multi-item request. Trimming to 1 item.")
				var _trim: Array[ItemData] = [main_item]
				t.desired_items.assign(_trim)
	
	# 3. Sync Mirror Properties
	Transaction_WantsDebt = t.wants_debt
	Transaction_IsRepaying = t.is_repaying
	Transaction_RepaymentAmount = t.repayment_amount
	Transaction_IsRiddle = t.is_riddle
	Transaction_ItemWantsBest = t.best_item_name
	Transaction_ItemHint = t.riddle_item.item_hint if t.is_riddle and t.riddle_item else ""
	Transaction_CustomerName = t.customer_data.character_name if t.customer_data else ""
	
	Transaction_GreetingVar = float(randi() % 100)
	Transaction_TalkVar = float(randi() % 100)
	Transaction_SatisfyVar = float(randi() % 100)
	Transaction_WrongItemVar = float(randi() % 100)
	Transaction_VisitVar = float(randi() % 100)
	
	var chapter = character_story_states.get(t.customer_data.resource_path, 0)
	var branch_value = customer_story_branches.get(t.customer_data.resource_path, 0.0)
	Transaction_Chapter = float(chapter)
	Transaction_Branch = float(branch_value)
	Transaction_CurrentArc = t.customer_data.get_arc_index(chapter) + 1
	Transaction_DeliveredCount = t.delivered_items.size()
	Transaction_RemainingCount = t.desired_items.size()

	# 4. Sync to Dialogic Variables
	_set_dvar("Global_RumorActive", 1.0 if t.rumor_active else 0.0)
	_set_dvar("Global_RumorType", t.rumor_type)
	_set_dvar("Transaction_WantsDebt", 1.0 if t.wants_debt else 0.0)
	_set_dvar("Transaction_IsRepaying", 1.0 if t.is_repaying else 0.0)
	_set_dvar("Transaction_RepaymentAmount", t.repayment_amount)
	_set_dvar("Transaction_IsRiddle", 1.0 if t.is_riddle else 0.0)
	_set_dvar("Transaction_ItemWantsBest", t.best_item_name)
	
	# Update Dialogic ItemWants string
	_update_transaction_item_string(t)
	
	# Phase-specific random rolls
	_set_dvar("Transaction_GreetingVar", Transaction_GreetingVar)
	_set_dvar("Transaction_TalkVar", Transaction_TalkVar)
	_set_dvar("Transaction_SatisfyVar", Transaction_SatisfyVar)
	_set_dvar("Transaction_WrongItemVar", Transaction_WrongItemVar)
	_set_dvar("Transaction_VisitVar", Transaction_VisitVar)

	_set_dvar("Transaction_CurrentArc", float(Transaction_CurrentArc))
	_set_dvar("Transaction_Chapter", Transaction_Chapter)
	_set_dvar("Transaction_Branch", Transaction_Branch)

	print("\n[STORY] --- Transaction Attributes ---")
	print("  Rumor : ", t.rumor_active, " (Target < ", rumor_chance, ")")
	print("  Riddle: ", t.is_riddle, " (Target < ", riddle_chance, ")")
	print("  Debt  : ", t.wants_debt, " (ManangAna-only)")
	print("  Repay : ", t.is_repaying, " (Owed: ", current_debt, ")")


	print("[STORY] Debt State: ", t.wants_debt)
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
	if not data: data = _get_character_data("reynamayari")
	if not data:
		push_error("[StoryManager] Could not find Reyna Mayari data for collection!")
		return null
		
	var t = TransactionContext.new()
	t.customer_data = data
	
	var path = data.resource_path
	var chapter = character_story_states.get(path, 0)
	
	# Logic: First Meeting OR Story Progression if available
	var should_play_story = false
	if not is_mayari_met:
		should_play_story = true
		is_mayari_met = true
		print("[StoryManager] Mayari DEBUT nightly visit.")
	elif last_mayari_collection_successful and chapter < data.max_story_chapters:
		should_play_story = true
		print("[StoryManager] Mayari STORY nightly visit (Chapter %d)." % chapter)
	
	if should_play_story:
		t.transaction_type = TransactionContext.Type.STORY
		t.timeline = data.story_timeline
		# Synchronize necessary variables
		Transaction_Chapter = float(chapter)
		_set_dvar("Transaction_Chapter", Transaction_Chapter)
	else:
		t.transaction_type = TransactionContext.Type.VISIT
		t.timeline = "res://Dialogue/Timelines/mayari_collect.dtl"
		if not last_mayari_collection_successful:
			print("[StoryManager] Mayari RECOVERY nightly visit (Generic).")
	
	# Common nightly variety rolls
	Transaction_GreetingVar = float(randi() % 100)
	Transaction_TalkVar = float(randi() % 100)
	Transaction_SatisfyVar = float(randi() % 100)
	Transaction_WrongItemVar = float(randi() % 100)
	Transaction_VisitVar = float(randi() % 100)
	
	_set_dvar("Transaction_GreetingVar", Transaction_GreetingVar)
	_set_dvar("Transaction_TalkVar", Transaction_TalkVar)
	_set_dvar("Transaction_SatisfyVar", Transaction_SatisfyVar)
	_set_dvar("Transaction_WrongItemVar", Transaction_WrongItemVar)
	_set_dvar("Transaction_VisitVar", Transaction_VisitVar)
	
	has_mayari_visited = true
	encountered_characters[data.resource_path] = true
	return t

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
	# NEW: Always force story if a chapter is pending (unless it's Reyna Mayari during the day)
	# This prevents characters from getting "stuck" in generic visit loops.
	var story_pending = chapter < data.max_story_chapters and data.story_timeline != null
	var is_mayari = data.get_clean_id() == "reynamayari"
	
	if (chapter == 0 or force_story or story_pending) and story_pending and not is_mayari:
		t.transaction_type = TransactionContext.Type.STORY
		t.timeline = data.story_timeline
	else:
		# Generic flow selection: use the exported visit_chance (default 20%)
		# Force a purchase if it is the first regular customer of the day.
		# NOTE: Reyna Mayari falls here during the day even if she has pending story.
		var is_purchase = true
		if _first_customer_of_day:
			print("[StoryManager] First regular customer of the day. Forcing PURCHASE.")
		else:
			is_purchase = randf() < (1.0 - visit_chance)

		# Danilo Overdrive: Should only have VISIT timelines if story isn't finished.
		# FIX: Danilo's Chapter 8 (index 8) is a PURCHASE finale, allow it to remain PURCHASE.
		if is_purchase and data.get_clean_id() == "danilo" and chapter < data.max_story_chapters - 1:
			print("[StoryManager] Danilo story incomplete (%d/%d). Overriding PURCHASE to VISIT." % [chapter, data.max_story_chapters])
			is_purchase = false
			

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

	# 2.5 Identify "Visit-only" Story Chapters
	if t.transaction_type == TransactionContext.Type.STORY:
		var id = data.get_clean_id()
		var i_chapter = int(chapter)
		if id == "sarimanok" and i_chapter <= 3:
			t.is_visit_story = true
		elif id == "danilo" and i_chapter <= 8: # Chapter 9 is the first purchase
			t.is_visit_story = true
		elif id == "manangana" and i_chapter == 7: # Chapter 8 "Cleared" is a visit
			t.is_visit_story = true
		elif id == "buboy" and i_chapter == 0: # Chapter 1 "Pinoy Henyo" is a visit
			t.is_visit_story = true
		elif id == "rosalyn" and i_chapter in [0, 1, 4, 5, 7, 8]:
			t.is_visit_story = true
		elif id == "rodel" and i_chapter == 8:
			t.is_visit_story = true
		
		if t.is_visit_story:
			print("[StoryManager] Marked STORY as VISIT-ONLY for %s (Chapter %d)" % [id, i_chapter])
	
	# 2.6 Dynamic Requested Category Overrides
	var id = data.get_clean_id()
	if id == "kuyakap":
		if chapter == 7.0: # Chapter 8 "Not Today"
			t.requested_category = "bottle"
		elif chapter >= 8.0: # Chapter 9 "Candy" and beyond
			t.requested_category = "candy"
		else:
			t.requested_category = "cigarette"
	elif id == "manangana":
		match int(chapter):
			0: t.requested_category = "pack"
			1, 6: t.requested_category = "can"
			2: t.requested_category = "bottle"
			3: t.requested_category = "pack"
			4, 5: t.requested_category = "sachet"
			8: t.requested_category = "pack"
			_: t.requested_category = "pack"
	elif id == "danilo":
		t.requested_category = "snack"
	elif id == "buboy":
		# Shifted categories for Buboy's 10-chapter arc
		match int(chapter):
			1: t.requested_category = "can"       # Sardines
			2: t.requested_category = "snack"     # Red bag duck
			3: t.requested_category = "sachet"    # Soap/Detergents mapped to sachet
			4: t.requested_category = "snack"     # Green packet nuts
			5: t.requested_category = "pack"      # Meals mapped to pack
			6: t.requested_category = "bottle"    # Dark drink burp
			7: t.requested_category = "candy"     # Honey sweet
			8: t.requested_category = "snack"     # Pig skin crunchy
			9: t.requested_category = "pack"      # Masterpiece mapped to pack
	elif id == "tk":
		# T.K.'s 9-chapter travel vlogger arc
		match int(chapter):
			0, 3, 7: t.requested_category = "bottle"
			1, 4, 6: t.requested_category = "snack"
			2, 5, 8: t.requested_category = "pack"
	elif id == "rosalyn":
		# Rosalyn's 9-chapter wandering spirit arc
		match int(chapter):
			2, 3: t.requested_category = "bottle" # Ch 3 & 4
			6: t.requested_category = "candy" # Ch 7
			_: 
				t.requested_category = "bottle" # Default to bottle for generic visits
	elif id == "rodel":
		# Rodel's 9-chapter aquatic foreigner arc
		match int(chapter):
			0, 2, 3, 5, 7: t.requested_category = "bottle"
			1, 4: t.requested_category = "snack"
			6: t.requested_category = "frozen"
			8: 
				pass
	elif id == "brahim":
		match int(chapter):
			0, 3, 6: t.requested_category = "frozen"
			1, 4: t.requested_category = "can"
			2, 5, 8: t.requested_category = "pack"
			7: t.requested_category = "candy"
	elif id == "sarimanok":
		# Only chapters 4+ are purchases
		match int(chapter):
			4, 6: t.requested_category = "snack"
			5: t.requested_category = "pack"
			7, 8: t.requested_category = "can"
	elif id == "reynamayari":
		match int(chapter):
			0, 2, 4: t.requested_category = "cigarette"
			1, 5, 7: t.requested_category = "bottle"
			3, 6: t.requested_category = "candy"
			8: t.requested_category = "sachet"
	# Note: dual-customer (guest) injection is now configured via CustomerData.secondary_customer_data
	# rather than being hardcoded per character here.

	# 2. Assign Desired Items (unless it's a social visit or visit-story)
	if t.transaction_type != TransactionContext.Type.VISIT and not t.is_visit_story:
		# --- Priority 1: Pinned chapter items from CustomerData.get_chapter_request ---
		var pinned_request := data.get_chapter_request(chapter)
		if pinned_request != null:
			# Use pinned items, applying upgrades if requested at the chapter or item level.
			# Supports both the new ChapterItemEntry wrapper and legacy ItemData entries.
			for entry in pinned_request.items:
				var item: ItemData = null
				var item_auto_upgrade := false
				
				if entry is ChapterItemEntry:
					item = entry.item
					item_auto_upgrade = entry.auto_upgrade
				elif entry is ItemData:
					item = entry
					item_auto_upgrade = false
				
				if item:
					var needs_tier_downgrade = item.tier > current_tier
					if item_auto_upgrade or pinned_request.upgrade_all or needs_tier_downgrade:
						var best_in_cat = get_best_item_for_category(item.category, item)
						if best_in_cat:
							item = best_in_cat
						else:
							item = _pick_random_orderable_item()
							
					if item:
						t.desired_items.append(item)
				
			_update_transaction_item_string(t)
			print("[StoryManager] Chapter %d items used for %s: %s" % [chapter, data.character_name, Transaction_ItemWants])
		else:
			# --- 50% Unpredictability for Regular Purchases ---
			if t.transaction_type == TransactionContext.Type.PURCHASE and t.requested_category != "":
				if randf() > 0.5:
					print("[StoryManager] 50% Unpredictability Triggered for %s: Ignoring %s." % [data.character_name, t.requested_category])
					t.requested_category = ""

			# --- Determine How Many Items to Fetch ---
			var target_item_count = 1
			if t.transaction_type == TransactionContext.Type.PURCHASE:
				target_item_count = _get_item_count_for_tier(current_tier)

			# --- Priority 2: Requested category override (per-character hardcoded or runtime) ---
			if t.requested_category != "":
				var prefer_hint = (id == "buboy")
				var item = get_any_item_for_category(t.requested_category, prefer_hint)
				if item:
					t.desired_items.append(item)
					t.best_item_name = item.item_name
					print("[StoryManager] Category request: %s -> Item: %s" % [t.requested_category, t.best_item_name])
				else:
					push_warning("[StoryManager] Requested category '%s' found no valid items! Reshuffling to generic items." % t.requested_category)
					t.requested_category = ""

			# --- Build the 60/40 Generic Pool ---
			var pool: Array[ItemData] = []
			var selection_roll = randf()
			
			if selection_roll < 0.6:
				# 60% Chance: Pick from available items currently on display or in stock
				print("[StoryManager] Selection Mode: DISPLAY STOCK (60% roll)")
				var display_pool = InventoryManager.get_items_available_on_display()
				for item in display_pool:
					if is_item_unlocked(item) and item.can_be_sold:
						pool.append(item)
						
			if selection_roll >= 0.6 or pool.is_empty():
				# 40% Chance (or fallback): Pick from the default cumulative tier rank pool
				if selection_roll < 0.6:
					print("[StoryManager] Fallback: Display stock empty. Reverting to CUMULATIVE TIER pool.")
				else:
					print("[StoryManager] Selection Mode: CUMULATIVE TIER (40% roll)")
					
				for item in InventoryManager.get_all_items():
					# Selection Pool now includes current_tier + 1 to encourage upgrades
					if item.tier <= current_tier + 1 and item.can_be_sold:
						pool.append(item)
						
				# Build the desired items list using selection pool
				if id == "buboy":
					var hint_pool = pool.filter(func(i): return i.item_hint != "")
					if not hint_pool.is_empty():
						pool = hint_pool # Buboy ONLY picks items with hints if possible
				
				var max_tiers_by_cat = _get_max_tier_per_category()
				for i in range(target_item_count):
					var picked = _pick_weighted_item(pool, max_tiers_by_cat)
					if picked:
						t.desired_items.append(picked)

			# --- Fill Remaining Target Item Slots ---
			var remaining_items = target_item_count - t.desired_items.size()
			var max_tiers_by_cat = _get_max_tier_per_category()
			for i in range(remaining_items):
				if not pool.is_empty():
					var item = _pick_weighted_item(pool, max_tiers_by_cat)
					if t.upgrade_to_best_tier:
						var best = get_best_item_for_category(item.category, item)
						if best: item = best
					t.desired_items.append(item)
				else:
					var fallback = _pick_random_orderable_item()
					if fallback:
						if t.upgrade_to_best_tier:
							var best = get_best_item_for_category(fallback.category, fallback)
							if best: fallback = best
						t.desired_items.append(fallback)
			
			# Safety Fallback: If no items were found (due to category Tier mismatch or invalid pinned data)
			if t.desired_items.is_empty() and t.transaction_type != TransactionContext.Type.VISIT:
				print("[StoryManager] WARNING: No items found for transaction %s. Attempting global fallback." % data.character_name)
				var fallback = _pick_random_orderable_item()
				if fallback:
					t.desired_items.append(fallback)
					print("[StoryManager] Global fallback assigned: ", fallback.item_name)

			# Final type safety check
			if t.desired_items.is_empty():
				if t.transaction_type == TransactionContext.Type.PURCHASE:
					print("[StoryManager] Critical: No items found for purchase. Converting to VISIT for: ", data.character_name)
					t.transaction_type = TransactionContext.Type.VISIT
					t.timeline = "res://Dialogue/Timelines/Generic/Visit.dtl"
				elif t.transaction_type == TransactionContext.Type.STORY:
					# Some story chapters are purely talk, but if they use {Transaction_ItemWants} we need a fallback
					push_warning("[StoryManager] STORY transaction for %s has NO items. This might be intentional or a tier-lock issue." % data.character_name)
			
			# Tag as Next-Tier if any item is above player's current tier
			for item in t.desired_items:
				if item.tier > current_tier:
					t.is_next_tier_request = true
					break

			# SYNC: Ensure the built item list (overrides/fallbacks) is pushed to Dialogic DVars
			_update_transaction_item_string(t)
			print("[StoryManager] Final selection for %s: Type=%s, Items=[%s]" % [data.character_name, Transaction_Chapter, Transaction_ItemWants])




## Returns the number of items a customer should request.
## Distribution: 1 item (40%), 2 items (30%), 3 items (30%)
func _get_item_count_for_tier(_tier: int) -> int:
	var roll = randf() * 100.0
	if roll < 40: return 1
	elif roll < 70: return 2
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
	_set_dvar("Global_LastSatisfaction", "Happy")
	
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
	_set_dvar("Global_LastSatisfaction", "Unhappy")
	
	_process_story_cooldown(customer)

func _set_last_customer_info(customer: Customer) -> void:
	if customer.transaction_context:
		var data = customer.transaction_context.customer_data
		var display_name = data.character_name if data.character_name != "" else data.get_clean_id()
			
		_set_dvar("Global_LastCustomer", display_name)
		
		# Mark as encountered so they leave the Priority 0 "Forced First Encounter" list
		var path = data.resource_path
		if not encountered_characters.has(path):
			encountered_characters[path] = true
			print("[StoryManager] Character marked as ENCOUNTERED: ", data.get_clean_id())
		
		# Save specific item for rumors if applicable
		if not customer.transaction_context.desired_items.is_empty():
			_set_dvar("Global_LastItem", customer.transaction_context.desired_items[0].item_name)
		else:
			_set_dvar("Global_LastItem", "")

func _process_story_cooldown(customer) -> void:
	if not customer.transaction_context:
		return
	
	var t = customer.transaction_context
	if t.story_advanced:
		return # Already advanced this visit
		
	if t.transaction_type == TransactionContext.Type.STORY or t.is_visit_story:
		var path = t.customer_data.resource_path
		
		# EXCEPTION: Reyna Mayari only advances if the collection was successful.
		if path.contains("ReynaMayari"):
			if not last_mayari_collection_successful:
				print("[StoryManager] Mayari collection FAILED. Chapter %d remains unchanged." % character_story_states.get(path, 0))
				return
		
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
		t.story_advanced = true
		last_story_advancer_path = path
		global_story_cooldown = randi_range(1, 3)
	
		# Mayari Debt Clear Check: Chapter 8 (Index 7) settlement
		if path.contains("ReynaMayari") and character_story_states[path] >= 8:
			if is_mayari_debt_active:
				is_mayari_debt_active = false
				print("[StoryManager] Reyna Mayari chapter 8 reached. Debt marked as INACTIVE.")

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

func _pick_character_weighted(candidates: Array[CustomerData]) -> CustomerData:
	if candidates.is_empty():
		return null
		
	# Find the focus character in the candidates list
	var focus_char: CustomerData = null
	for c in candidates:
		if c.resource_path == todays_focus_character_path:
			focus_char = c
			break
			
	# If focus character is available and there are others to choose from
	if focus_char and candidates.size() > 1:
		# 30% chance to pick the focus character
		if randf() < 0.3:
			return focus_char
		else:
			# 70% chance to pick evenly among others
			var others = candidates.filter(func(c): return c != focus_char)
			return others.pick_random()
			
	# Fallback for single candidate or if focus isn't a candidate
	return candidates.pick_random()

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
		print("[StoryManager] Category Search FAILURE: '%s'. Attempting global fallback." % cat)
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
			weight = 0.3
		else:
			# Priority 2: Gradual category-based decay
			var max_tier_in_cat = max_tiers_by_cat.get(item.category, item.tier)
			var gap = max_tier_in_cat - item.tier
			
			if gap <= 0:
				weight = 1.0 # Best currently unlocked in this category
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
			customer_story_branches[customer.customer_data.resource_path] = new_val
			print("[StoryManager] Captured Transaction_Branch change for ", customer.customer_data.character_name, " -> ", new_val)
			_save_progression()
			
	elif var_path == "Transaction_ItemWants":
		# Manual morphing implemented via upgrade_desires() instead of automatic listeners
		pass

func _on_dialogic_signal(argument: String) -> void:
	if argument == "refresh_desires":
		refresh_desires()
	elif argument == "upgrade_desires":
		# Signal form of upgrade_desires — use in .dtl as: [signal arg="upgrade_desires"]
		upgrade_desires()
	elif argument.begins_with("set_desire:"):
		# Force a specific item by name. Usage in .dtl: [signal arg="set_desire:Kopimo"]
		var item_name := argument.substr(len("set_desire:")).strip_edges()
		set_desire(item_name)
	elif argument == "story_success":
		# Manual story advancement signal
		var customer = _get_current_customer()
		
		# NEW: Robust lookup — if spawner customer is null or doesn't match current speaker, 
		# we try to find the character by Dialogic's active character if possible, 
		# but for now we'll just check if the current customer exists.
		if customer:
			print("[StoryManager] Direct Advance: 'story_success' signal received for ", customer.customer_data.character_name)
			_process_story_cooldown(customer)
			_save_progression()
		else:
			# Fallback for characters NOT in a spawner (e.g. static scene characters)
			# We'll use the most recently built transaction if it matches a story chapter.
			if last_story_advancer_path != "":
				var chapter = character_story_states.get(last_story_advancer_path, 0)
				character_story_states[last_story_advancer_path] = chapter + 1
				print("[StoryManager] Direct Advance (Fallback): No active customer node, using last_story_advancer_path: ", last_story_advancer_path)
				
				# Ensure Dialogic sees the new chapter immediately for the next timeline run
				Transaction_Chapter = float(chapter + 1)
				_set_dvar("Transaction_Chapter", Transaction_Chapter)
				
				_save_progression()


func refresh_desires() -> void:
	var customer = _get_current_customer()
	if not is_instance_valid(customer) or not customer.transaction_context:
		print("[StoryManager] REFRESH FAILED: No active customer or context.")
		return
		
	var t = customer.transaction_context
	var old_desires = Transaction_ItemWants
	var old_type = t.transaction_type
	var old_timeline = t.timeline
	var old_visit_story = t.is_visit_story
	
	t.desired_items.clear()
	_build_transaction_context(t, customer.customer_data, old_type == TransactionContext.Type.STORY)
	
	# Restore critical states so we don't abruptly change timeline midway
	t.transaction_type = old_type
	t.timeline = old_timeline
	t.is_visit_story = old_visit_story
	
	upgrade_desires()
	print("[StoryManager] REFRESH: %s -> %s" % [old_desires, Transaction_ItemWants])
	print("[StoryManager] Desires refreshed and upgraded via signal.")

## Force a specific named item as the customer's desire, then upgrade to best tier.
## Usage in Dialogic: [signal arg="set_desire:Kopimo"]
func set_desire(item_name: String) -> void:
	var customer = _get_current_customer()
	if not is_instance_valid(customer) or not customer.transaction_context:
		print("[StoryManager] SET_DESIRE FAILED: No active customer or context.")
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
	
	print("[StoryManager] SET_DESIRE: Matched '%s' -> '%s'" % [item_name, target_item.item_name])
	
	# Override the desired_items list with just this one item
	var t = customer.transaction_context
	var typed_list: Array[ItemData] = []
	typed_list.append(target_item)
	t.desired_items.assign(typed_list)
	
	# Now upgrade it to the best available tier in its category
	upgrade_desires()
	print("[StoryManager] SET_DESIRE: Forced desire to '%s' -> upgraded to '%s'" % [item_name, Transaction_ItemWants])

## Manual command to upgrade current items to their best available tiers.
## Usage in Dialogic: [signal arg="upgrade_desires"] or [do StoryManager.upgrade_desires()]
func upgrade_desires() -> void:
	var customer = _get_current_customer()
	if not is_instance_valid(customer) or not customer.transaction_context:
		return
		
	var t = customer.transaction_context
	if t.desired_items.is_empty(): return
	
	var new_list: Array[ItemData] = []
	for old_item in t.desired_items:
		var best = get_best_item_for_category(old_item.category, old_item)
		if best: new_list.append(best)
		else: new_list.append(old_item)
	
	t.desired_items.assign(new_list)
	_update_transaction_item_string(t)
	print("[StoryManager] Manual Upgrade Executed: ", Transaction_ItemWants)

func _update_transaction_item_string(t: TransactionContext) -> void:
	var item_names: Array[String] = []
	var highest_tier := -1
	var highest_item_name := ""
	
	for item in t.desired_items:
		item_names.append(item.item_name)
		if item.tier > highest_tier:
			highest_tier = item.tier
			highest_item_name = item.item_name
		
	var formatted_names = _join_names(item_names)
	
	# ABSOLUTE FALLBACK: Prevent Dialogic's default "something" from leaking through.
	# If desired_items is empty for a non-visit transaction, pick a real random item
	# and inject it — same pattern used for the "item" fallback.
	if formatted_names == "" and t.transaction_type != TransactionContext.Type.VISIT:
		var fallback_item = _pick_random_orderable_item()
		if fallback_item:
			var typed_list: Array[ItemData] = [fallback_item]
			t.desired_items.assign(typed_list)
			item_names = [fallback_item.item_name]
			formatted_names = fallback_item.item_name
			highest_item_name = fallback_item.item_name
			print("[StoryManager] FALLBACK: desired_items was empty — overriding with random item: ", fallback_item.item_name)
		else:
			formatted_names = "any items"
		
	# Clean ID for easy matching in DTL (e.g. "lucky9" vs "Lucky 9 Carne Norte")
	var wants_id := ""
	if not t.desired_items.is_empty():
		wants_id = t.desired_items[0].get_clean_id()
	
	Transaction_ItemWantsID = wants_id
	_set_dvar("Transaction_ItemWantsID", wants_id)
	
	Transaction_ItemWants = formatted_names
	_set_dvar("Transaction_ItemWants", formatted_names)
	_set_dvar("Transaction_IsNextTier", t.is_next_tier_request)
	
	Transaction_HighestItemWants = highest_item_name
	_set_dvar("Transaction_HighestItemWants", highest_item_name)
	
	if not item_names.is_empty():
		Transaction_ItemAnyWants = item_names.pick_random()
		_set_dvar("Transaction_ItemAnyWants", Transaction_ItemAnyWants)

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
	
	# Robust label matching:
	var regex = RegEx.new()
	regex.compile("^\\s*label\\s+" + label_name + "(\\s+|#|$)")
	
	for line in content.split("\n"):
		if regex.search(line):
			_label_cache[cache_key] = true
			return true
			
	_label_cache[cache_key] = false
	return false
