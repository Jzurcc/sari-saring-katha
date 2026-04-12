extends Node

## StoryManager handles progression and transaction creation based on day and hour.
const MAX_EVENTS_PER_DAY = 17 # 5 AM to 10 PM (17 chunks of time)

var current_event_index: int = 0
var day: int = 1

# Tracks current story stage index per character e.g., {"KuyaKap": 1}
var character_story_states: Dictionary = {}

var todays_focus_character: String = ""

## ─── Real-time clock ─────────────────────────────────────────────────────────
## In-game time advances in real-time during an event, then locks when it hits
## the per-event cap (eventStartHour + 1). On the next event, it smoothly
## tweens to the new hour before the real-time clock resumes.

## 1 in-game hour = 3 real minutes (1.0 / 180.0 hours/sec).
const CLOCK_SPEED_HOURS_PER_SEC := 1.0 / 180.0
## Duration of the animated time-jump between events (seconds).
## 6 s feels smooth: the sky is still moving as the customer walks in.
const TIME_TRANSITION_DURATION := 6.0

## Float representation of the currently displayed in-game hour (0–24).
var _current_display_time: float = 5.0
## Clock stops advancing once it reaches this value.
var _clock_cap_hour: float = 6.0
## Whether the real-time clock is actively ticking.
var _clock_running: bool = false
## Tween handle for the animated transition between event hours.
var _transition_tween: Tween = null
## Cached reference to the TimeOfDay node (searched once on first use).
var _time_of_day_node: Node = null
var todays_story_events_left: int = 0

## Pool of characters that can arrive
@export var available_characters: Array[CustomerData] = [
	preload("res://Resources/customers/KuyaKap.tres")
]

func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.customer_satisfied.connect(_on_customer_satisfied)
	randomize()

func _on_day_started(new_day: int) -> void:
	day = new_day
	current_event_index = 0
	_setup_daily_focus()
	# The CustomerSpawner will ask for the next transaction.

func _setup_daily_focus() -> void:
	if available_characters.is_empty(): 
		todays_focus_character = ""
		todays_story_events_left = 0
		return
		
	# Pick a focus character for the 3 daily story events
	var focus_char = available_characters.pick_random()
	todays_focus_character = focus_char.character_id
	todays_story_events_left = 3
	print("[StoryManager] Day ", day, " focus character is: ", todays_focus_character)

## Ask the StoryManager for what happens in the next hour block.
## Returns null if nobody comes, or a TransactionContext.
func get_next_transaction() -> TransactionContext:
	if current_event_index >= MAX_EVENTS_PER_DAY:
		return null
	
	_update_game_time()
	current_event_index += 1
	print("[StoryManager] Hour ", current_event_index, "/", MAX_EVENTS_PER_DAY)
	
	# 15% chance for no customer this hour block
	if randf() < 0.15:
		print("[StoryManager] No customer will arrive this hour.")
		return null
		
	if available_characters.is_empty():
		return null
		
	var t = TransactionContext.new()
	t.event_hour = current_event_index
	
	var type_pool = []
	if todays_story_events_left > 0:
		type_pool.append(TransactionContext.Type.STORY)
		
	# Add filler and generic probability weights
	type_pool.append(TransactionContext.Type.FILLER)
	type_pool.append(TransactionContext.Type.FILLER)
	type_pool.append(TransactionContext.Type.GENERIC)
	
	var chosen_type = type_pool.pick_random()

	
	if chosen_type == TransactionContext.Type.STORY and todays_focus_character != "":
		t.transaction_type = TransactionContext.Type.STORY
		t.character_id = todays_focus_character
		var char_data = _get_character_data(todays_focus_character)
		if char_data:
			_build_story_context(t, char_data)
			todays_story_events_left -= 1
		else:
			_build_fallback_context(t)
	elif chosen_type == TransactionContext.Type.FILLER:
		var char_data = available_characters.pick_random()
		t.transaction_type = TransactionContext.Type.FILLER
		t.character_id = char_data.character_id
		_build_filler_context(t, char_data)
	else:
		var char_data = available_characters.pick_random()
		t.transaction_type = TransactionContext.Type.GENERIC
		t.character_id = char_data.character_id
		_build_generic_context(t, char_data)
	
	return t

## Tick the real-time clock each frame while it is running.
func _process(delta: float) -> void:
	if not _clock_running:
		return
	_ensure_tod_node()
	if not _time_of_day_node:
		return
	_current_display_time = minf(_current_display_time + CLOCK_SPEED_HOURS_PER_SEC * delta, _clock_cap_hour)
	_apply_display_time(_current_display_time)
	if _current_display_time >= _clock_cap_hour:
		_clock_running = false

## Write the float hour value to the TimeOfDay node.
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

func _update_game_time() -> void:
	# Called before current_event_index is incremented, so index=0 → 5 AM, index=1 → 6 AM, etc.
	var target_hour := float(5 + current_event_index)
	_ensure_tod_node()
	if not _time_of_day_node:
		return

	_time_of_day_node.game_time_enabled = false
	_time_of_day_node.system_sync = false

	# Stop any in-progress real-time ticking.
	_clock_running = false

	# Kill the previous transition if one was still animating.
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
		_transition_tween = null

	# Smoothly animate from the current displayed hour to the new event hour.
	var from_time := _current_display_time
	_transition_tween = create_tween()
	_transition_tween.set_trans(Tween.TRANS_CUBIC)
	_transition_tween.set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_method(_apply_display_time, from_time, target_hour, TIME_TRANSITION_DURATION)
	_transition_tween.tween_callback(func() -> void:
		_current_display_time = target_hour
		_clock_cap_hour = target_hour + 1.0
		_clock_running = true
	)

## Called by CustomerSpawner when the hour block has no customer.
## Overrides the previous transition with a single sweep from the current
## displayed time all the way to the next event hour (clock_cap_hour),
## timed to finish exactly when the quiet-hour wait expires.
func start_quiet_hour_transition(duration: float) -> void:
	_clock_running = false
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
		_transition_tween = null

	var from_time := _current_display_time
	var to_time   := _clock_cap_hour  # set by _update_game_time() to eventHour + 1

	_transition_tween = create_tween()
	_transition_tween.set_trans(Tween.TRANS_CUBIC)
	_transition_tween.set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_method(_apply_display_time, from_time, to_time, duration)
	_transition_tween.tween_callback(func() -> void:
		_current_display_time = to_time
		_clock_running = false  # No real-time drift after quiet fast-forward
	)

func _get_character_data(id: String) -> CustomerData:
	for c in available_characters:
		if c.character_id == id:
			return c
	return null

func _build_story_context(t: TransactionContext, data: CustomerData) -> void:
	var stage: int = character_story_states.get(t.character_id, 0)
	var base := (data.timelines_dir if data.timelines_dir != "" else "res://Dialogue/" + data.character_id + "/") + "Story/stage_" + str(stage)

	_assign_timeline(t, "timeline_greeting",  base + "_greeting.dtl")
	_assign_timeline(t, "timeline_talk",       base + "_talk.dtl")
	_assign_timeline(t, "timeline_satisfied",  base + "_satisfied.dtl")
	_assign_timeline(t, "timeline_wrong_item", base + "_wrong_item.dtl")
	_assign_timeline(t, "timeline_rejected",   base + "_rejected.dtl")

	if data.filler_items.size() > 0:
		t.desired_items.append(data.filler_items.pick_random())

func _build_filler_context(t: TransactionContext, data: CustomerData) -> void:
	var base := data.timelines_dir if data.timelines_dir != "" else "res://Dialogue/" + data.character_id + "/"

	_assign_timeline(t, "timeline_greeting",  base + "Filler/filler_greeting_1.dtl")
	_assign_timeline(t, "timeline_talk",       base + "Filler/filler_talk_1.dtl")
	_assign_timeline(t, "timeline_satisfied",  base + "Filler/filler_satisfied_1.dtl")
	_assign_timeline(t, "timeline_wrong_item", base + "Filler/filler_wrong_item_1.dtl")
	_assign_timeline(t, "timeline_rejected",   base + "Filler/filler_rejected_1.dtl")

	if data.filler_items.size() > 0:
		t.desired_items.append(data.filler_items.pick_random())

func _build_generic_context(t: TransactionContext, data: CustomerData) -> void:
	var base := data.timelines_dir if data.timelines_dir != "" else "res://Dialogue/" + data.character_id + "/"
	_assign_timeline(t, "timeline_generic_talk", base + "Generic/generic_talk_1.dtl")

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

func _on_customer_satisfied(customer) -> void:
	if customer.transaction_context and customer.transaction_context.transaction_type == TransactionContext.Type.STORY:
		var id = customer.transaction_context.character_id
		var stage = character_story_states.get(id, 0)
		character_story_states[id] = stage + 1
		print("[StoryManager] Advanced story for ", id, " to stage ", stage + 1)
