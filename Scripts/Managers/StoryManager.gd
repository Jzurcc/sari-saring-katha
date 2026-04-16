extends Node

## StoryManager — manages story progression and builds customer transactions.
## The clock runs freely from DAY_START_HOUR to CLOSING_HOUR with no event slots.

const DAY_START_HOUR := 5.0
const CLOSING_HOUR   := 21.0  ## 9 PM — no new customers after this
## 1 in-game hour = 25 real seconds.
const CLOCK_SPEED_HOURS_PER_SEC := 1.0 / 25.0

var day: int = 1


var todays_focus_character_path: String = ""

var character_story_states: Dictionary = {}
var is_clock_running: bool = false:
	set(value):
		is_clock_running = value
		_ensure_tod_node()
		if _time_of_day_node:
			_time_of_day_node.game_time_enabled = is_clock_running

var _last_character_path: String = ""
var _last_focus_character_path: String = ""
var _pending_tier_advance_source: String = ""

# --- Story Progression ---
var global_story_cooldown: int = 0
var last_story_advancer_path: String = ""

var _char_lookup: Dictionary = {}   # resource_path -> CustomerData

# --- Tier Progression ---
var current_tier: int = 1
var purchase_counter: int = 0:
	set(value):
		purchase_counter = value
		if purchase_counter >= 8 and current_tier < 10:
			_pending_tier_advance_source = "Activity"

var pending_upgrade_tier: int = 0
var pending_upgrade_cost: float = 0.0

@export_group("Transaction Probabilities")
## Chance (0.0 to 1.0) that a customer will start with a rumor.
@export_range(0, 1) var rumor_chance: float = 0.20
## Chance (0.0 to 1.0) that a customer will ask for debt (utang).
@export_range(0, 1) var debt_chance: float = 0.15
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
	preload("res://Resources/customers/Dionisio.tres"),
	preload("res://Resources/customers/Rodel.tres")
]

func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.customer_satisfied.connect(_on_customer_satisfied)
	EventBus.customer_dismissed.connect(_on_customer_dismissed)
	
	# Load progression state
	var save_data = SaveManager.load_game()
	if save_data.has("progression"):
		var p = save_data["progression"]
		current_tier = p.get("current_tier", 1)
		purchase_counter = p.get("purchase_counter", 0)
		pending_upgrade_tier = p.get("pending_upgrade_tier", 0)
		pending_upgrade_cost = p.get("pending_upgrade_cost", 0.0)
		global_story_cooldown = p.get("global_story_cooldown", 0)
		last_story_advancer_path = p.get("last_story_advancer_path", "")
		_current_display_time = p.get("current_display_time", 16.0) # Default to 4 PM if missing
		if p.has("character_story_states"):
			character_story_states = p["character_story_states"]
	
	_ensure_tod_node()
	if _time_of_day_node and not _time_of_day_node.time_changed.is_connected(_on_tod_time_changed):
		_time_of_day_node.time_changed.connect(_on_tod_time_changed)
	
	# Initial child character data into a lookup map for faster retrieval
	for c in available_characters:
		if c:
			_char_lookup[c.resource_path] = c
	
	randomize()

func _on_tod_time_changed(t: float) -> void:
	_current_display_time = t
	# End of day check
	if _current_display_time >= CLOSING_HOUR and is_clock_running:
		is_clock_running = false

func _on_day_started(new_day: int) -> void:
	day = new_day
	_setup_daily_focus()
	print("[StoryManager] Day ", day, " starts.")

func _setup_daily_focus() -> void:
	if available_characters.is_empty():
		todays_focus_character_path = ""
		return
	
	# Filter to avoid repeating the same focus character as yesterday
	var possible_focus = available_characters.filter(func(c): return c.resource_path != _last_focus_character_path)
	if possible_focus.is_empty(): 
		possible_focus = available_characters
		
	var focus_char = possible_focus.pick_random()
	todays_focus_character_path = focus_char.resource_path
	_last_focus_character_path = todays_focus_character_path
	
	print("[StoryManager] Day ", day, " focus character is: ", focus_char.get_clean_id())

func advance_tier(source: String = "Manual") -> void:
	if current_tier >= 10:
		return
		
	current_tier += 1
	purchase_counter = 0
	print("[StoryManager] TIER ADVANCED to ", current_tier, " via ", source)
	
	# Save state
	_save_progression()
	
	# Trigger rewards
	EventBus.tier_advanced.emit(current_tier, source)

func get_upgrade_cost(target_tier: int) -> float:
	return 100.0 + float(target_tier - 2) * 25.0

func process_pending_unlock() -> void:
	if _pending_tier_advance_source != "":
		# Queue the upgrade for purchase instead of auto-unlocking
		pending_upgrade_tier = current_tier + 1
		pending_upgrade_cost = get_upgrade_cost(pending_upgrade_tier)
		
		_pending_tier_advance_source = ""
		
		# Notify the player to call Uncle Mario
		EventBus.upgrade_available.emit(pending_upgrade_tier, pending_upgrade_cost)
		_save_progression()

func _save_progression() -> void:
	var current_save = SaveManager.load_game()
	current_save["progression"] = {
		"current_tier": current_tier,
		"purchase_counter": purchase_counter,
		"pending_upgrade_tier": pending_upgrade_tier,
		"pending_upgrade_cost": pending_upgrade_cost,
		"global_story_cooldown": global_story_cooldown,
		"last_story_advancer_path": last_story_advancer_path,
		"character_story_states": character_story_states,
		"current_display_time": _current_display_time
	}
	SaveManager.save_game(current_save)

## Ask the StoryManager for the next customer's context.
## Returns null only if no characters are configured.
func get_next_transaction() -> TransactionContext:
	# --- TUTORIAL INJECTION ---
	var tutorial_path := "res://Resources/customers/UncleMarioTutorial.tres"
	var tutorial_stage = character_story_states.get(tutorial_path, 0)
	if day == 1 and tutorial_stage == 0:
		var tutorial_char_data = preload("res://Resources/customers/UncleMarioTutorial.tres")
		var tutorial_t = TransactionContext.new()
		tutorial_t.customer_data = tutorial_char_data
		
		# Build context explicitly for the tutorial — use VISIT so it plays from
		# the top of the file, not from a "Greeting" label (which doesn't exist).
		tutorial_t.transaction_type = TransactionContext.Type.VISIT
		tutorial_t.timeline = tutorial_char_data.story_timelines[0]
		
		# Flag it so it doesn't repeat
		character_story_states[tutorial_path] = 1
		
		print("[STORY] Spawning Uncle Mario Tutorial")
		return tutorial_t
	# --------------------------

	if available_characters.is_empty():
		return null

	var char_data: CustomerData = null
	var force_story = false
	
	# Priority 1: Check if a story chapter is ready to be forced
	if global_story_cooldown <= 0:
		var story_candidates: Array[CustomerData] = []
		for c in available_characters:
			# Skip the character who just progressed
			if c.resource_path == last_story_advancer_path: continue
			# Skip if it was the last character to avoid back-to-back spawns
			if c.resource_path == _last_character_path: continue
			
			var c_stage = character_story_states.get(c.resource_path, 0)
			# Needs to have a story timeline available AND pass prerequisites
			if c_stage < c.story_timelines.size() and _is_story_chapter_available(c, c_stage):
				story_candidates.append(c)
		
		# Deadlock Check: If we have stages available but NO candidates passed prerequisites
		if story_candidates.is_empty():
			var blocked_story_exists = false
			for c in available_characters:
				var c_stage = character_story_states.get(c.resource_path, 0)
				if c_stage < c.story_timelines.size():
					blocked_story_exists = true
					break
			if blocked_story_exists:
				print("[StoryManager] WARNING: Potential Story Deadlock. Chapters are available but prerequisites are not met.")
		
		# If we have candidates, we force their story transaction
		if not story_candidates.is_empty():
			# Fix #3: Prioritize Today's Focus Character if they have a story chapter ready
			var focus_candidate = null
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
			for c in available_characters:
				if c.resource_path == _last_character_path: continue
				var c_stage = character_story_states.get(c.resource_path, 0)
				if c_stage < c.story_timelines.size() and _is_story_chapter_available(c, c_stage):
					fallback_story_candidates.append(c)
			
			if not fallback_story_candidates.is_empty():
				char_data = fallback_story_candidates.pick_random()
				force_story = true
				print("[StoryManager] Cooldown 0: Soft-lock override. Forcing story for: ", char_data.get_clean_id())

	# Priority 2: Generic flow if no story is forced, or cooldown is active
	if not char_data:
		# 1. Selection with Sequential Guard (Prevent same character twice in a row)
		var possible_chars = available_characters.filter(func(c): return c.resource_path != _last_character_path)
		if possible_chars.is_empty(): possible_chars = available_characters # Fallback
		char_data = possible_chars.pick_random()

	_last_character_path = char_data.resource_path
	
	var t = TransactionContext.new()
	t.customer_data = char_data
	
	_build_transaction_context(t, char_data, force_story)
	
	# 2. Independent Feature Rolls
	
	# A. Environmental Awareness
	var awareness_roll = randf()
	var awareness_active = awareness_roll < 0.4 # 40% chance for awareness preamble
	
	var current_hour = StoryManager._current_display_time
	var time_phase = "Morning"
	if current_hour >= 18.0:
		time_phase = "Evening"
	elif current_hour >= 12.0:
		time_phase = "Afternoon"
	
	var total_stock = InventoryManager.get_total_owned_count(ItemData.ItemType.SHELF) + InventoryManager.get_total_owned_count(ItemData.ItemType.FRIDGE)
	var stock_status = "Normal"
	if total_stock < 10:
		stock_status = "Low"
		
	Dialogic.VAR.set_variable("Global.AwarenessActive", 1.0 if awareness_active else 0.0)
	Dialogic.VAR.set_variable("Global.TimeOfDayPhase", time_phase)
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
		
	# C. Riddle (Tingting)
	# Only possible if there are items and the main item has a hint
	var riddle_roll = randf()
	if not t.desired_items.is_empty() and t.transaction_type != TransactionContext.Type.VISIT:
		var main_item = t.desired_items[0]
		if main_item.item_hint != "" and riddle_roll < riddle_chance:
			t.is_riddle = true
			Dialogic.VAR.set_variable("Transaction.ItemHint", main_item.item_hint)
	
	# 3. Sync to Dialogic Variables
	Dialogic.VAR.set_variable("Global.RumorActive", 1.0 if t.rumor_active else 0.0)
	Dialogic.VAR.set_variable("Global.RumorType", t.rumor_type)
	Dialogic.VAR.set_variable("Transaction.WantsDebt", 1.0 if t.wants_debt else 0.0)
	Dialogic.VAR.set_variable("Transaction.IsRiddle", 1.0 if t.is_riddle else 0.0)
	
	var stage = character_story_states.get(t.customer_data.resource_path, 0)
	Dialogic.VAR.set_variable("Transaction.CurrentArc", t.customer_data.get_arc_index(stage) + 1)

	print("\n[STORY] --- Transaction Attributes ---")
	print("  Rumor : ", t.rumor_active, " (Roll: ", rumor_roll, " < ", rumor_chance, ")")
	print("  Riddle: ", t.is_riddle, " (Roll: ", riddle_roll, " < ", riddle_chance, ")")
	print("  Debt  : ", t.wants_debt, " (Roll: ", debt_roll, " < ", debt_chance, ")")

	print("\n[STORY] --- Transaction Setup ---")
	print("[STORY] Spawning: ", t.customer_data.get_clean_id(), " (Type: ", TransactionContext.Type.keys()[t.transaction_type], ")")
	print("[STORY] Rumor Roll: ", rumor_roll, " (Target < 0.20) -> ", t.rumor_active)
	print("[STORY] Riddle State: ", t.is_riddle) # Riddle chance check remains in _build since it needs items
	print("[STORY] Debt Roll:  ", debt_roll, " (Target < 0.15) -> ", t.wants_debt)

	return t

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

func _get_character_data(path_or_id: String) -> CustomerData:
	if path_or_id.to_lower() == "unclemariotutorial":
		return preload("res://Resources/customers/UncleMarioTutorial.tres")

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
	var stage = character_story_states.get(path, 0)
	
	# If this is their first visit (stage 0) OR the system forced a story chapter
	if stage == 0 or force_story:
		if stage < data.story_timelines.size():
			t.transaction_type = TransactionContext.Type.STORY
			t.timeline = data.story_timelines[stage]
		else:
			# Edgecase: forced story but no timelines available -> fallback to visit
			var visit_pool = data.get_visit_timelines(stage)
			t.transaction_type = TransactionContext.Type.VISIT
			t.timeline = visit_pool.pick_random() if not visit_pool.is_empty() else "res://Dialogue/Timelines/Generic/Neutral.dtl"
	else:
		# Generic flow
		var purchase_pool = data.get_purchase_timelines(stage)
		var visit_pool = data.get_visit_timelines(stage)
		
		if not purchase_pool.is_empty() and randf() < 0.7:
			# 70% chance to purchase if available
			t.transaction_type = TransactionContext.Type.PURCHASE
			t.timeline = purchase_pool.pick_random()
		elif not visit_pool.is_empty():
			t.transaction_type = TransactionContext.Type.VISIT
			t.timeline = visit_pool.pick_random()
		elif not purchase_pool.is_empty():
			t.transaction_type = TransactionContext.Type.PURCHASE
			t.timeline = purchase_pool.pick_random()
		else:
			t.transaction_type = TransactionContext.Type.VISIT
			t.timeline = "res://Dialogue/Timelines/Generic/Neutral.dtl"
			t.is_placeholder = true

	# 2. Assign Desired Items (unless it's a social visit)
	if t.transaction_type != TransactionContext.Type.VISIT:
		var pool: Array[ItemData] = []
		var filler_pool = data.get_filler_items(stage)
		for item in filler_pool:
			if is_item_unlocked(item) and item.can_be_sold:
				pool.append(item)

		# Multi-item request logic (1-3 items)
		var item_count = randi_range(1, 3)
		for i in range(item_count):
			if not pool.is_empty():
				t.desired_items.append(pool.pick_random())
			else:
				var fallback: ItemData = _pick_random_orderable_item()
				if fallback:
					t.desired_items.append(fallback)
		
		t.original_count = t.desired_items.size()

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
		_save_progression() # Save intermediate progress

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
		var stage = character_story_states.get(path, 0)
		character_story_states[path] = stage + 1
		print("[StoryManager] Advanced story for ", path.get_file(), " to stage ", stage + 1)
		
		# Story advanced — set cooldown and mark them
		last_story_advancer_path = path
		global_story_cooldown = randi_range(3, 5)
		
		# Narrative Tier Progression Check (Chapters 3 and 6 mark arc boundaries)
		if character_story_states[path] in [3, 6]:
			_pending_tier_advance_source = "Story (%s)" % path.get_file().get_basename()
	
		_save_progression()
	else:
		# Any successful generic transaction (or visit finish) decreases the cooldown
		if global_story_cooldown > 0:
			global_story_cooldown -= 1
			print("[StoryManager] Generic transaction (", TransactionContext.Type.keys()[customer.transaction_context.transaction_type], ") completed. Cooldown remains: ", global_story_cooldown)
			_save_progression()

func _is_story_chapter_available(customer: CustomerData, stage: int) -> bool:
	# If no prerequisites defined or array index doesn't exist, assume available
	if stage >= customer.story_prerequisites.size() or customer.story_prerequisites[stage] == null:
		return true
		
	return customer.story_prerequisites[stage].is_met(self)
	return customer.story_prerequisites[stage].is_met(self)
