extends Node

## StoryManager — manages story progression and builds customer transactions.
## The clock runs freely from DAY_START_HOUR to CLOSING_HOUR with no event slots.

const DAY_START_HOUR := 5.0
const CLOSING_HOUR   := 20.0  ## 8 PM — no new customers after this
## 1 in-game hour = 20 real seconds.
const CLOCK_SPEED_HOURS_PER_SEC := 1.0 / 20.0

var day: int = 1


var todays_focus_character: String = ""
## Tracks which story stage each character is on, e.g. {"KuyaKap": 1}
var character_story_states: Dictionary = {}

## Float representation of the currently displayed in-game hour (0–24).
var _current_display_time: float = DAY_START_HOUR
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
]

func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.customer_satisfied.connect(_on_customer_satisfied)
	randomize()

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

## Ask the StoryManager for the next customer's context.
## Returns null only if no characters are configured.
func get_next_transaction() -> TransactionContext:
	if available_characters.is_empty():
		return null

	var t = TransactionContext.new()

	var type_pool: Array = []
	if todays_focus_character != "":
		type_pool.append(TransactionContext.Type.STORY)

	# Add purchase and visit probability weights
	type_pool.append(TransactionContext.Type.PURCHASE)
	type_pool.append(TransactionContext.Type.PURCHASE)
	type_pool.append(TransactionContext.Type.VISIT)

	var chosen_type = type_pool.pick_random()

	if chosen_type == TransactionContext.Type.STORY and todays_focus_character != "":
		t.transaction_type = TransactionContext.Type.STORY
		t.character_id = todays_focus_character
		var char_data = _get_character_data(todays_focus_character)
		if char_data:
			_build_story_context(t, char_data)
		else:
			_build_fallback_context(t)
	elif chosen_type == TransactionContext.Type.PURCHASE:
		var char_data = available_characters.pick_random()
		t.transaction_type = TransactionContext.Type.PURCHASE
		t.character_id = char_data.character_id
		_build_purchase_context(t, char_data)
	else:
		var char_data = available_characters.pick_random()
		t.transaction_type = TransactionContext.Type.VISIT
		t.character_id = char_data.character_id
		_build_visit_context(t, char_data)

	return t

## Tick the clock every frame — runs continuously from DAY_START_HOUR to CLOSING_HOUR.
## No caps, no tweens, no toggling. The sky just moves.
func _process(delta: float) -> void:
	if _current_display_time >= CLOSING_HOUR:
		return
	_ensure_tod_node()
	if not _time_of_day_node:
		return
	_current_display_time = minf(
		_current_display_time + CLOCK_SPEED_HOURS_PER_SEC * delta,
		CLOSING_HOUR
	)
	_apply_display_time(_current_display_time)

## Write the float hour value to the TimeOfDay node (drives sky/shadow).
func _apply_display_time(t: float) -> void:
	if not _time_of_day_node:
		return
	var h := int(t)
	var m := int((t - h) * 60.0)
	_time_of_day_node.set_time(h, m, 0)

## Lazy-initialise _time_of_day_node so we don't search the tree every tick.
func _ensure_tod_node() -> void:
	if not is_instance_valid(_time_of_day_node):
		_time_of_day_node = get_tree().root.find_child("TimeOfDay", true, false)

func _get_character_data(id: String) -> CustomerData:
	for c in available_characters:
		if c.character_id == id:
			return c
	return null

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

func _build_story_context(t: TransactionContext, data: CustomerData) -> void:
	var stage: int = character_story_states.get(t.character_id, 0)
	var base := (data.timelines_dir if data.timelines_dir != "" else "res://Dialogue/" + data.character_id + "/") + "Story/stage_" + str(stage)
	var greeting_path := base + "_greeting.dtl"

	# If the greeting for this story stage doesn't exist, downgrade to a regular purchase.
	if not ResourceLoader.exists(greeting_path):
		push_warning("[StoryManager] Story stage %d for '%s' is missing. Downgrading to PURCHASE." % [stage, t.character_id])
		t.transaction_type = TransactionContext.Type.PURCHASE
		_build_purchase_context(t, data)
		return

	_assign_timeline(t, "timeline_greeting",  greeting_path)
	_assign_timeline(t, "timeline_talk",       base + "_talk.dtl")
	_assign_timeline(t, "timeline_satisfied",  base + "_satisfied.dtl")
	_assign_timeline(t, "timeline_wrong_item", base + "_wrong_item.dtl")
	_assign_timeline(t, "timeline_rejected",   base + "_rejected.dtl")

	var pool: Array[ItemData] = []
	for item in data.filler_items:
		if _is_item_unlocked(item):
			pool.append(item)

	if pool.size() > 0:
		t.desired_items.append(pool.pick_random())
	else:
		var fallback := _pick_random_orderable_item()
		if fallback:
			t.desired_items.append(fallback)

func _build_purchase_context(t: TransactionContext, data: CustomerData) -> void:
	var base := data.timelines_dir if data.timelines_dir != "" else "res://Dialogue/" + data.character_id + "/"

	_search_and_assign_purchase_tl(t, "timeline_greeting",  base, "filler_greeting_1.dtl")
	_search_and_assign_purchase_tl(t, "timeline_talk",       base, "filler_talk_1.dtl")
	_search_and_assign_purchase_tl(t, "timeline_satisfied",  base, "filler_satisfied_1.dtl")
	_search_and_assign_purchase_tl(t, "timeline_wrong_item", base, "filler_wrong_item_1.dtl")
	_search_and_assign_purchase_tl(t, "timeline_rejected",   base, "filler_rejected_1.dtl")

	var pool: Array[ItemData] = []
	for item in data.filler_items:
		if _is_item_unlocked(item):
			pool.append(item)

	if pool.size() > 0:
		t.desired_items.append(pool.pick_random())
	else:
		var fallback := _pick_random_orderable_item()
		if fallback:
			t.desired_items.append(fallback)

func _build_visit_context(t: TransactionContext, data: CustomerData) -> void:
	var base := data.timelines_dir if data.timelines_dir != "" else "res://Dialogue/" + data.character_id + "/"
	# 1. Try character's own Social/ subfolder
	var p1 := base + "Social/social_talk_1.dtl"
	if ResourceLoader.exists(p1):
		t.timeline_visit = p1
		return
	# 2. Pick randomly from shared generic/filler/ pool (per user request)
	var random_talk := _pick_random_from_folder("res://Dialogue/generic/filler/")
	if random_talk != "":
		t.timeline_visit = random_talk
		return
	# 3. Final catch-all fallback
	var p3 := "res://Dialogue/customer_talk.dtl"
	if ResourceLoader.exists(p3):
		t.timeline_visit = p3
		return
	push_warning("[StoryManager] No visit timeline for '%s'" % data.character_id)

func _build_fallback_context(t: TransactionContext) -> void:
	_assign_timeline(t, "timeline_greeting",  "res://Dialogue/customer_greeting.dtl")
	_assign_timeline(t, "timeline_talk",       "res://Dialogue/customer_talk.dtl")
	_assign_timeline(t, "timeline_satisfied",  "res://Dialogue/customer_satisfied.dtl")
	_assign_timeline(t, "timeline_wrong_item", "res://Dialogue/customer_wrong_item.dtl")
	_assign_timeline(t, "timeline_rejected",   "res://Dialogue/customer_rejected.dtl")

## Assigns a timeline path only if the file exists; warns otherwise.
func _assign_timeline(t: TransactionContext, property: String, path: String) -> void:
	if ResourceLoader.exists(path):
		t.set(property, path)
	else:
		push_warning("[StoryManager] Missing timeline file for '%s': %s" % [property, path])

func _search_and_assign_purchase_tl(t: TransactionContext, property: String, base: String, filename: String) -> void:
	# 1. Try character's own Filler/ subfolder
	var p1 = base + "Filler/" + filename
	if ResourceLoader.exists(p1):
		t.set(property, p1)
		return
	# 2. Try character's base folder
	var p2 = base + filename
	if ResourceLoader.exists(p2):
		t.set(property, p2)
		return
	# 3. Pick a random file from the shared generic pool subfolder
	#    e.g. timeline_wrong_item → res://Dialogue/generic/wrong_item/
	var type_name := property.replace("timeline_", "")
	var generic_folder := "res://Dialogue/generic/" + type_name + "/"
	var random_generic := _pick_random_from_folder(generic_folder)
	if random_generic != "":
		t.set(property, random_generic)
		return
	# 4. Old customer_* catch-all
	var p4 = "res://Dialogue/customer_" + type_name + ".dtl"
	if ResourceLoader.exists(p4):
		t.set(property, p4)
		return
	# 5. Warn if everything is missing
	push_warning("[StoryManager] No generic dialogue for '%s': tried %s, %s, %s, %s" % [property, p1, p2, generic_folder, p4])

## Picks a random .dtl file from a folder. Returns "" if folder is missing or empty.
func _pick_random_from_folder(folder_path: String) -> String:
	var dir := DirAccess.open(folder_path)
	if not dir:
		return ""
	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".dtl"):
			files.append(folder_path + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	if files.is_empty():
		return ""
	return files.pick_random()

func _on_customer_satisfied(customer) -> void:
	if customer.transaction_context and customer.transaction_context.transaction_type == TransactionContext.Type.STORY:
		var id = customer.transaction_context.character_id
		var stage = character_story_states.get(id, 0)
		character_story_states[id] = stage + 1
		print("[StoryManager] Advanced story for ", id, " to stage ", stage + 1)
