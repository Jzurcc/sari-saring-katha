extends Node

## StoryManager — manages story progression and builds customer transactions.
## The clock runs freely from DAY_START_HOUR to CLOSING_HOUR with no event slots.

const DAY_START_HOUR := 5.0
const CLOSING_HOUR   := 20.0  ## 8 PM — no new customers after this
## 1 in-game hour = 25 real seconds.
const CLOCK_SPEED_HOURS_PER_SEC := 1.0 / 25.0

var day: int = 1


var todays_focus_character: String = ""

var character_story_states: Dictionary = {}
var is_clock_running: bool = false:
	set(value):
		is_clock_running = value
		_ensure_tod_node()
		if _time_of_day_node:
			_time_of_day_node.game_time_enabled = is_clock_running

var _last_character_id: String = ""

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
	
	_ensure_tod_node()
	if _time_of_day_node:
		_time_of_day_node.time_changed.connect(_on_tod_time_changed)
	
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
		todays_focus_character = ""
		return
	var focus_char = available_characters.pick_random()
	todays_focus_character = focus_char.character_id
	print("[StoryManager] Day ", day, " focus character is: ", todays_focus_character)

func get_next_transaction() -> TransactionContext:
	# --- TUTORIAL INJECTION ---
	var tutorial_stage = character_story_states.get("UncleMarioTutorial", 0)
	if day == 1 and tutorial_stage == 0:
		var tutorial_char_data = preload("res://Resources/customers/UncleMarioTutorial.tres")
		var tutorial_t = TransactionContext.new()
		tutorial_t.character_id = tutorial_char_data.character_id
		
		# Build context explicitly for the tutorial so it's treated like a STORY
		tutorial_t.transaction_type = TransactionContext.Type.STORY
		tutorial_t.timeline = tutorial_char_data.story_timelines[0]
		
		# Flag it so it doesn't repeat
		character_story_states["UncleMarioTutorial"] = 1
		
		print("[STORY] Spawning Uncle Mario Tutorial")
		return tutorial_t
	# --------------------------

	if available_characters.is_empty():
		return null

	# 1. Selection with Sequential Guard (Prevent same character twice in a row)
	var possible_chars = available_characters.filter(func(c): return c.character_id != _last_character_id)
	if possible_chars.is_empty(): possible_chars = available_characters # Fallback

	var char_data = possible_chars.pick_random()
	_last_character_id = char_data.character_id
	
	var t = TransactionContext.new()
	t.character_id = char_data.character_id
	
	_build_transaction_context(t, char_data)
	
	# 2. Chance-based feature triggers (Consolidated for clarity & sync)
	
	# 20% Rumor Mill chance
	var last_cust = Dialogic.VAR.get_variable("Global.LastCustomer")
	var rumor_roll = randf()
	if last_cust != "" and last_cust != t.character_id and rumor_roll < 0.20:
		t.rumor_active = true
	else:
		t.rumor_active = false
	Dialogic.VAR.set_variable("Global.RumorActive", 1.0 if t.rumor_active else 0.0)
	t.rumor_type = 1.0 if randf() < 0.5 else 0.0
	Dialogic.VAR.set_variable("Global.RumorType", t.rumor_type)

	# 15% Utang (Debt) chance
	var debt_roll = randf()
	if t.transaction_type == TransactionContext.Type.PURCHASE and debt_roll < 0.15:
		t.wants_debt = true
	else:
		t.wants_debt = false
	Dialogic.VAR.set_variable("Transaction.WantsDebt", 1.0 if t.wants_debt else 0.0)
	
	# Riddle Sync (IsRiddle was rolled in _build_transaction_context)
	Dialogic.VAR.set_variable("Transaction.IsRiddle", 1.0 if t.is_riddle else 0.0)

	print("\n[STORY] --- Transaction Setup ---")
	print("[STORY] Spawning: ", t.character_id, " (Type: ", TransactionContext.Type.keys()[t.transaction_type], ")")
	print("[STORY] Rumor Roll: ", rumor_roll, " (Target < 0.20) -> ", t.rumor_active)
	print("[STORY] Riddle State: ", t.is_riddle) # Riddle chance check remains in _build since it needs items
	print("[STORY] Debt Roll:  ", debt_roll, " (Target < 0.15) -> ", t.wants_debt)

	return t

## Tick the clock every frame — runs continuously from DAY_START_HOUR to CLOSING_HOUR.
## No caps, no tweens, no toggling. The sky just moves.
func _process(_delta: float) -> void:
	# Continuous sync check — primarily uses signals now, but ensures
	# StoryManager logic stays informed if external factors change TOD time.
	_ensure_tod_node()

## Write the float hour value to the TimeOfDay node (drives sky/shadow).
func _apply_display_time(t: float) -> void:
	if not _time_of_day_node:
		return
	var h := int(t)
	var m := int((t - h) * 60.0)
	_time_of_day_node.set_time(h, m, 0)

func _ensure_tod_node() -> void:
	if not is_instance_valid(_time_of_day_node):
		_time_of_day_node = get_tree().root.find_child("TimeOfDay", true, false)

func _get_character_data(id: String) -> CustomerData:
	if id.to_lower() == "unclemariotutorial":
		return preload("res://Resources/customers/UncleMarioTutorial.tres")

	for c in available_characters:
		if c.character_id.to_lower() == id.to_lower():
			return c
	return null

## Build the transaction context by choosing the appropriate timeline.
func _build_transaction_context(t: TransactionContext, data: CustomerData) -> void:
	# 1. Reset Social flags in context object (GDScript base)
	t.is_riddle = false
	t.wants_debt = false
	# We will sync these to Dialogic at the end of get_next_transaction().

	# 2. Choose Transaction Type
	# If this is their first visit (stage 0), always trigger STORY type.
	var stage = character_story_states.get(data.character_id, 0)
	
	if stage < data.story_timelines.size():
		# Play next story stage
		t.transaction_type = TransactionContext.Type.STORY
		t.timeline = data.story_timelines[stage]
	elif not data.generic_purchase_timelines.is_empty():
		# Fallback to generic purchase
		t.transaction_type = TransactionContext.Type.PURCHASE
		t.timeline = data.generic_purchase_timelines.pick_random()
	elif not data.generic_visit_timelines.is_empty():
		# Fallback to social visit
		t.transaction_type = TransactionContext.Type.VISIT
		t.timeline = data.generic_visit_timelines.pick_random()
	else:
		# Ultimate fallback
		t.transaction_type = TransactionContext.Type.VISIT
		t.timeline = "res://Dialogue/customer_talk.dtl"
		t.is_placeholder = true

	# 2. Assign Desired Items (unless it's a social visit)
	if t.transaction_type != TransactionContext.Type.VISIT:
		var pool: Array[ItemData] = []
		for item in data.filler_items:
			if _is_item_unlocked(item):
				pool.append(item)

		if not pool.is_empty():
			t.desired_items.append(pool.pick_random())
		else:
			var fallback := _pick_random_orderable_item()
			if fallback:
				t.desired_items.append(fallback)
		
		# 20% Tingting (Riddle) chance
		var riddle_roll = randf()
		if not t.desired_items.is_empty() and riddle_roll < 0.20:
			var main_item = t.desired_items[0]
			if main_item.item_hint != "":
				t.is_riddle = true
				Dialogic.VAR.set_variable("Transaction.ItemHint", main_item.item_hint)
				print("[STORY] Riddle Roll: ", riddle_roll, " (Target < 0.20) -> SUCCESS (Hint: ", main_item.item_hint, ")")
			else:
				print("[STORY] Riddle Roll: ", riddle_roll, " (Target < 0.20) -> FAIL (No hint found for ", main_item.item_name, ")")
		else:
			t.is_riddle = false

## Returns a random item that is unlocked for the current day.
## Prioritizes items that are currently in stock. 
## Fallback: picks an unlocked item even if out of stock (prevents "something" dialogue gap).
func _pick_random_orderable_item() -> ItemData:
	var stocked_unlocked: Array[ItemData] = []
	var all_unlocked: Array[ItemData] = []
	
	for item in InventoryManager.get_all_items():
		if _is_item_unlocked(item):
			all_unlocked.append(item)
			if InventoryManager.is_in_stock(item):
				stocked_unlocked.append(item)

	# Pass 1: Try items that the player actually has on the shelf
	if not stocked_unlocked.is_empty():
		return stocked_unlocked.pick_random()
	
	# Pass 2: Fallback to any unlocked item (so customers still ask for things)
	if not all_unlocked.is_empty():
		return all_unlocked.pick_random()
		
	push_warning("[StoryManager] No unlocked items available at all for fallback filler.")
	return null

## Helper to check if an item is available based on the current day's progression.
func _is_item_unlocked(item: ItemData) -> bool:
	var unlock_map: Dictionary = {
		# DAY 1
		"Anoba": 1, "Patos": 1,
		"Argentita": 1, "Cenchuree": 1,
		"Champyon": 1,
		# DAY 2
		"Mentor": 2, "Pocha": 2,
		"Water": 2,
		"Chicken": 2, "Pantit": 2,
		"Mix": 2,
		# DAY 3
		"Hotdog": 3, "Borgir": 3,
		"NgaragYa": 3, "Dantes": 3,
		"Mayti": 3,
		# DAY 4
		"Coke": 4,
		"Marites": 4, "Utang": 4,
		# DAY 5
		"Lucky9": 5, "Mema": 5,
		"Nagets": 5,
		# DAY 6
		"Marboro": 6,
		"Gin": 6,
		# DAY 7
		"Tocino": 7,
		"Scam": 7,
		"Chubs": 7,
	}
	
	var unlock_day = unlock_map.get(item.id, 1)
	return day >= unlock_day


func _on_customer_satisfied(customer) -> void:
	# Update Rumor Mill State
	if customer.transaction_context:
		var id = customer.transaction_context.character_id
		# Use the Character resource's name if available, otherwise fallback to ID
		var display_name = id # Default
		var data = _get_character_data(id)
		if data and data.character_name != "":
			display_name = data.character_name
			
		Dialogic.VAR.set_variable("Global.LastCustomer", display_name)
		Dialogic.VAR.set_variable("Global.LastSatisfaction", "Happy")
		
		# Save specific item for rumors if applicable
		if not customer.transaction_context.desired_items.is_empty():
			Dialogic.VAR.set_variable("Global.LastItem", customer.transaction_context.desired_items[0].item_name)

	if customer.transaction_context and customer.transaction_context.transaction_type == TransactionContext.Type.STORY:
		var id = customer.transaction_context.character_id
		var stage = character_story_states.get(id, 0)
		character_story_states[id] = stage + 1
		print("[StoryManager] Advanced story for ", id, " to stage ", stage + 1)
