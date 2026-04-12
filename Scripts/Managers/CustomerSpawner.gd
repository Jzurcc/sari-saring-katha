extends Node
class_name CustomerSpawner

## Tracks which phase of dialogue is currently playing.
## Used by _on_dialogue_ended to decide what to do when a timeline ends.
## timeline_ended fires EXACTLY ONCE per timeline (confirmed from Dialogic source).
enum DialoguePhase {
	NONE,         ## No dialogue running / unknown context
	GREETING,     ## Customer arrived and played their greeting — waiting for player to give item
	TALK,         ## Player clicked customer to reconfirm request — waiting for player to give item
	SATISFIED,    ## Correct item given — satisfy() is running its own exit animation
	GENERIC_TALK, ## Drop-in visit with no purchase — dismiss when done
	WRONG_ITEM,   ## Wrong item dropped — customer reacts but stays so player can retry
}

@export var customer_scene: PackedScene = preload("res://Scenes/Customer.tscn")
@export var spawn_pos: NodePath
@export var target_pos: NodePath

## Fallback timeline played when a STORY/FILLER greeting DTL does not exist yet.
## After it plays the customer is dismissed (GENERIC_TALK phase) so the day advances.
const PLACEHOLDER_EMPTY_STORY := "res://Dialogue/placeholder_story_missing.dtl"

var current_customer: Customer = null
var _pending_dismiss: bool = false  # Set by refuse_service signal mid-dialogue; acted on at timeline_ended
var _is_spawning: bool = false      # Prevents double-spawn during async arrival timer
var _dialogue_phase: DialoguePhase = DialoguePhase.NONE

func _ready() -> void:
	add_to_group("customer_spawner")
	EventBus.day_started.connect(_on_day_started)
	EventBus.customer_satisfied.connect(_on_customer_finished)
	EventBus.customer_dismissed.connect(_on_customer_dismissed)
	Dialogic.timeline_ended.connect(_on_dialogue_ended)
	Dialogic.signal_event.connect(_on_dialogic_signal)

	await get_tree().process_frame

func _on_day_started(_day: int) -> void:
	_spawn_next_customer()

func _spawn_next_customer() -> void:
	if current_customer != null or _is_spawning:
		return

	_is_spawning = true

	var transaction = StoryManager.get_next_transaction()

	if StoryManager.current_event_index >= StoryManager.MAX_EVENTS_PER_DAY:
		_is_spawning = false
		var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
		EventBus.day_ended.emit(gm.day if gm else 1)
		return

	if transaction == null:
		# Quiet hour — kick off a fast time-sweep then wait.
		# _update_game_time() already moved to the next event hour; this overrides
		# that with a single smooth tween covering the full hour over the wait period.
		const QUIET_WAIT := 10.0
		print("[CustomerSpawner] Quiet hour. Waiting %.0f seconds..." % QUIET_WAIT)
		StoryManager.start_quiet_hour_transition(QUIET_WAIT)
		await get_tree().create_timer(QUIET_WAIT).timeout
		_is_spawning = false
		_spawn_next_customer()
		return

	var type_name: String = (["STORY", "FILLER", "GENERIC"] as Array[String])[transaction.transaction_type]
	var item_list: Array[String] = []
	for item in transaction.desired_items:
		item_list.append(item.item_name)
	print("\n[CUSTOMER] ── Incoming transaction ──────────────────")
	print("  Character : ", transaction.character_id)
	print("  Type      : ", type_name)
	print("  Event     : ", StoryManager.current_event_index, " / ", StoryManager.MAX_EVENTS_PER_DAY)
	print("  Wants     : ", ", ".join(item_list) if item_list.size() > 0 else "(nothing — generic/visit)")
	print("[CUSTOMER] ─────────────────────────────────────────")

	await get_tree().create_timer(2.0).timeout

	if not spawn_pos or not target_pos:
		push_error("[CustomerSpawner] spawn_pos or target_pos is not set!")
		_is_spawning = false
		return

	current_customer = customer_scene.instantiate()
	get_parent().add_child(current_customer)
	current_customer.global_position = get_node(spawn_pos).global_position
	current_customer.setup(transaction, get_node(target_pos).global_position)

	current_customer.arrived.connect(_on_customer_arrived)
	current_customer.clicked.connect(_on_customer_clicked)

	EventBus.customer_spawned.emit(current_customer)
	_is_spawning = false

func _on_customer_arrived(customer: Customer) -> void:
	EventBus.customer_arrived.emit(customer)

	# Set the global item name so Dialogic {expressions} can read it from .dtl files.
	var item_names: Array[String] = []
	for item in customer.transaction_context.desired_items:
		item_names.append(item.item_name)
	InventoryManager.current_item_name = ", ".join(item_names) if item_names.size() > 0 else "something"

	var context := customer.transaction_context
	var timeline_path: String

	if context.transaction_type == TransactionContext.Type.GENERIC:
		timeline_path = context.timeline_generic_talk
		_dialogue_phase = DialoguePhase.GENERIC_TALK
	else:
		timeline_path = context.timeline_greeting
		if timeline_path.is_empty():
			# Story chapter not written yet — play a placeholder and dismiss.
			push_warning("[CustomerSpawner] Empty greeting for '%s' (%s) — using placeholder." \
				% [context.character_id, TransactionContext.Type.keys()[context.transaction_type]])
			timeline_path = PLACEHOLDER_EMPTY_STORY
			_dialogue_phase = DialoguePhase.GENERIC_TALK  # Dismiss after placeholder
		else:
			_dialogue_phase = DialoguePhase.GREETING

	# ── Arrival debug ────────────────────────────────────
	print("\n[CUSTOMER] ── Arrived at counter ────────────────────")
	print("  Phase     : ", DialoguePhase.keys()[_dialogue_phase])
	print("  Greeting  : ", context.timeline_greeting  if context.timeline_greeting  != "" else "(empty)")
	print("  Talk      : ", context.timeline_talk       if context.timeline_talk       != "" else "(empty)")
	print("  Satisfied : ", context.timeline_satisfied  if context.timeline_satisfied  != "" else "(empty)")
	print("  WrongItem : ", context.timeline_wrong_item if context.timeline_wrong_item != "" else "(empty)")
	print("  Rejected  : ", context.timeline_rejected   if context.timeline_rejected   != "" else "(empty)")
	print("  Generic   : ", context.timeline_generic_talk if context.timeline_generic_talk != "" else "(empty)")
	print("  Starting  → ", timeline_path if timeline_path != "" else "(NO TIMELINE — nothing will play!)")
	print("[CUSTOMER] ─────────────────────────────────────────")
	# ─────────────────────────────────────────────────────

	_start_dialogue(timeline_path, customer)

func _on_customer_finished(_customer: Customer) -> void:
	# satisfy() ran its own exit animation. Advance the day.
	current_customer = null
	if StoryManager.current_event_index < StoryManager.MAX_EVENTS_PER_DAY:
		_spawn_next_customer()
	else:
		var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
		EventBus.day_ended.emit(gm.day if gm else 1)

func _on_customer_dismissed(_customer: Customer) -> void:
	current_customer = null
	_spawn_next_customer()

func _on_customer_clicked(customer: Customer) -> void:
	# Guard order matters — check from cheapest to most specific:
	# 1. Dialogic is actively running a timeline right now.
	if Dialogic.current_timeline != null or customer.transaction_context == null:
		return
	# 2. Customer is being dismissed (satisfy/dismiss already called).
	if not customer.is_waiting:
		return
	# 3. _dialogue_phase != NONE means a timeline just finished its async clear
	#    but timeline_ended hasn't fired yet (the gap between current_timeline=null
	#    and _on_dialogue_ended running). Also catches the deferred-layout window
	#    on first arrival. Either way: a dialogue is still in progress — block.
	if _dialogue_phase != DialoguePhase.NONE:
		return

	var timeline_path: String

	if customer.transaction_context.transaction_type == TransactionContext.Type.GENERIC:
		timeline_path = customer.transaction_context.timeline_generic_talk
		_dialogue_phase = DialoguePhase.GENERIC_TALK
	else:
		timeline_path = customer.transaction_context.timeline_talk
		_dialogue_phase = DialoguePhase.TALK

	_start_dialogue(timeline_path, customer)

func _on_dialogic_signal(argument: String) -> void:
	# [signal arg="refuse_service"] fires mid-execution. Set the flag here,
	# act on it ONLY after timeline_ended fires (never during signal_event).
	if argument == "refuse_service":
		_pending_dismiss = true

## Called from MainGame when the correct item is placed into the tray.
func notify_satisfied_dialogue() -> void:
	_dialogue_phase = DialoguePhase.SATISFIED

## Called from MainGame when the wrong item is placed into the tray.
func notify_wrong_item_dialogue() -> void:
	_dialogue_phase = DialoguePhase.WRONG_ITEM

## Shared helper — sets style, starts the timeline, and registers the bubble anchor.
func _start_dialogue(timeline_path: String, customer: Customer) -> void:
	# Never start a dialogue if one is playing, if the path is empty,
	# or if the customer is being dismissed.
	if timeline_path.is_empty() or Dialogic.current_timeline != null:
		return
	if not is_instance_valid(customer) or not customer.is_waiting:
		return

	Dialogic.Styles.load_style("FollowBubble")
	var layout = Dialogic.start(timeline_path)

	# Anchor the follow-bubble to the customer's SpeechMarker node.
	var char_data = StoryManager._get_character_data(customer.character_id)
	var char_res = char_data.dialogic_character if char_data else null
	var marker = customer.get_node_or_null("SpeechMarker")
	if marker == null:
		push_warning("[CustomerSpawner] Customer '%s' has no SpeechMarker node — bubble will not follow." % customer.character_id)
	if layout and layout.has_method("register_character") and char_res and is_instance_valid(marker):
		layout.register_character(char_res, marker)

func _on_dialogue_ended() -> void:
	# timeline_ended fires exactly once per timeline (confirmed from Dialogic source).
	# Read and clear the phase atomically.
	var phase := _dialogue_phase
	_dialogue_phase = DialoguePhase.NONE

	# refuse_service signal fired mid-dialogue (from a choice in TALK or WRONG_ITEM).
	# Always takes priority — dismiss the customer regardless of which phase just ended.
	if _pending_dismiss:
		_pending_dismiss = false
		if is_instance_valid(current_customer) and current_customer.is_waiting:
			current_customer.dismiss()
		return

	match phase:
		DialoguePhase.GENERIC_TALK:
			# Drop-in visit. Dismiss customer — _on_customer_dismissed spawns next.
			if is_instance_valid(current_customer) and current_customer.is_waiting:
				current_customer.dismiss()

		DialoguePhase.SATISFIED:
			# satisfy() already set is_waiting=false and owns its own exit animation.
			# _on_customer_finished handles spawning the next customer.
			pass

		DialoguePhase.WRONG_ITEM:
			# Customer reacted to the wrong item but stays at the counter.
			# Player can either give the correct item or refuse service next time.
			pass

		DialoguePhase.GREETING, DialoguePhase.TALK, DialoguePhase.NONE:
			# Customer is at the counter waiting for their item. Player must act.
			pass
