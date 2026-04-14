extends Node
class_name CustomerSpawner

## Tracks which phase of dialogue is currently playing.
## Used by _on_dialogue_ended to decide what to do when a timeline ends.
## timeline_ended fires EXACTLY ONCE per timeline (confirmed from Dialogic source)
enum DialoguePhase {
	NONE,         ## No dialogue running / unknown context
	GREETING,     ## Customer arrived and played their greeting — waiting for player to give item
	TALK,         ## Player clicked customer to reconfirm request — waiting for player to give item
	SATISFIED,    ## Correct item given — satisfy() is running its own exit animation
	SOCIAL_VISIT, ## Drop-in visit with no purchase — dismiss when done
	WRONG_ITEM,   ## Wrong item dropped — customer reacts but stays so player can retry
}

@export var customer_scene: PackedScene = preload("res://Scenes/Customer.tscn")
@export var spawn_pos: NodePath
@export var target_pos: NodePath

## Fallback timeline played when a STORY/FILLER greeting DTL does not exist yet.
## After it plays the customer is dismissed (SOCIAL_VISIT phase) so the day advances.
const PLACEHOLDER_EMPTY_STORY := "res://Dialogue/placeholder_story_missing.dtl"

## Proxy character used in generic dialogues (e.g. "Customer: Hello!").
## We patch this at runtime to show the correct name and anchor to the sprite.
var GENERIC_CHAR_RES := preload("res://Dialogue/Timelines/Customer.dch")

var current_customer: Customer = null
var _pending_dismiss: bool = false
var _is_spawning: bool = false
var _greeting_interrupted: bool = false # Remembers if Uncle Mario forcibly shut down the greeting.
var _greeting_deferred: bool = false # Remembers if a greeting was stalled because Mario was busy.



var is_paused: bool = false:
	set(value):
		is_paused = value
		if not is_paused and current_customer == null and not _is_spawning:
			_spawn_next_customer()
var _dialogue_phase: DialoguePhase = DialoguePhase.NONE
var _current_timeline_path: String = "" # Track the timeline started by this spawner

func _ready() -> void:
	add_to_group("customer_spawner")
	EventBus.day_started.connect(_on_day_started)
	EventBus.customer_satisfied.connect(_on_customer_finished)
	EventBus.customer_dismissed.connect(_on_customer_dismissed)
	Dialogic.timeline_ended.connect(_on_dialogue_ended)
	Dialogic.signal_event.connect(_on_dialogic_signal)
	MarioManager.delivery_finished.connect(_on_mario_delivery_finished)
	MarioManager.call_ended.connect(_on_mario_call_ended)

	await get_tree().process_frame

func _on_day_started(_day: int) -> void:
	print("[CustomerSpawner] Day starts — customers will spawn until 8 PM.")
	_spawn_next_customer()

func _spawn_next_customer() -> void:
	if is_paused or current_customer != null or _is_spawning:
		return

	# Closing time — no new customers at or after 8 PM
	if StoryManager._current_display_time >= StoryManager.CLOSING_HOUR:
		print("[CustomerSpawner] Store is closing. Ending day.")
		_end_day()
		return

	_is_spawning = true

	var transaction = StoryManager.get_next_transaction()

	if transaction == null:
		# No characters configured — nothing to spawn
		_is_spawning = false
		_end_day()
		return

	var type_name: String = ([" STORY", "PURCHASE", "VISIT "])[transaction.transaction_type]
	var item_list: Array[String] = []
	for item in transaction.desired_items:
		item_list.append(item.item_name)
	print("\n[CUSTOMER] ── Incoming transaction ──────────────────")
	print("  Character : ", transaction.character_id)
	print("  Type      : ", type_name)
	print("  Status    : Spawning...")
	print("  Wants     : ", ", ".join(item_list) if item_list.size() > 0 else "(nothing — visit)")
	print("[CUSTOMER] ─────────────────────────────────────────")

	await get_tree().create_timer(2.0).timeout

	if not spawn_pos or not target_pos:
		push_error("[CustomerSpawner] spawn_pos or target_pos is not set!")
		_is_spawning = false
		return

	var spawn_global = get_node(spawn_pos).global_position
	var target_global = get_node(target_pos).global_position
	var final_target = target_global
	
	# If the customer is Kuya Kap, offset him back so he doesn't hit his head on the roof.
	if transaction.character_id.to_lower() == "kuyakap":
		var dir_back = (spawn_global - target_global).normalized()
		final_target = target_global + (dir_back * 0.7)

	current_customer = customer_scene.instantiate()
	get_parent().add_child(current_customer)
	current_customer.global_position = spawn_global
	current_customer.setup(transaction, final_target)

	current_customer.arrived.connect(_on_customer_arrived)
	current_customer.clicked.connect(_on_customer_clicked)

	EventBus.customer_spawned.emit(current_customer)
	_is_spawning = false

func _on_customer_arrived(customer: Customer) -> void:
	_handle_customer_logic(customer, true)

## Helper to process arrival signals and dialogues.
## is_initial_arrival: if true, emits signals and sets naming globals.
func _handle_customer_logic(customer: Customer, is_initial_arrival: bool) -> void:
	if is_initial_arrival:
		EventBus.customer_arrived.emit(customer)
		
		# Automatically face the customer upon arrival (even if the phone isn't open).
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("face_node"):
			player.face_node(customer)

		# Set global variables so Dialogic {expressions} can read them from .dtl files.
		var item_names: Array[String] = []
		for item in customer.transaction_context.desired_items:
			item_names.append(item.item_name)
		InventoryManager.current_item_name = ", ".join(item_names) if item_names.size() > 0 else "something"

		# Set the character display name so generic dialogues can use {InventoryManager.current_character_name}
		var char_data_for_name = StoryManager._get_character_data(customer.character_id)
		InventoryManager.current_character_name = char_data_for_name.character_name if char_data_for_name else customer.character_id

		# Set context in Dialogic Variables instead of globals
		Dialogic.VAR.set_variable("Transaction.CustomerName", InventoryManager.current_character_name)
		Dialogic.VAR.set_variable("Transaction.ItemWants", InventoryManager.current_item_name)

	# ── DIALOGUE LOGIC ──
	var timeline = customer.transaction_context.timeline
	var start_label := "Greeting"
	var next_phase := DialoguePhase.GREETING
	
	if customer.transaction_context.transaction_type == TransactionContext.Type.VISIT:
		start_label = "" # Play from start for social visits
		next_phase = DialoguePhase.SOCIAL_VISIT

	if MarioManager.is_restocking_active:
		print("[CustomerSpawner] Mario is restocking — deferring greeting for %s." % customer.character_id)
		_greeting_deferred = true
		return

	# ── Arrival debug ────────────────────────────────────
	print("\n[CUSTOMER] ── Triggering Greeting ──────────────────")
	print("  Phase     : ", DialoguePhase.keys()[next_phase])
	print("  Timeline  : ", timeline)
	print("  Label     : ", start_label if start_label != "" else "(Start)")
	print("[CUSTOMER] ─────────────────────────────────────────")
	# ─────────────────────────────────────────────────────

	start_dialogue(timeline, customer, next_phase, start_label)

func _on_customer_finished(_customer: Customer) -> void:
	# satisfy() ran its own exit animation. Wait a natural gap then spawn next.
	current_customer = null
	await get_tree().create_timer(randf_range(5.0, 15.0)).timeout
	_spawn_next_customer()

func _on_customer_dismissed(_customer: Customer) -> void:
	current_customer = null
	await get_tree().create_timer(randf_range(5.0, 15.0)).timeout
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

	var timeline = customer.transaction_context.timeline
	var label: String = ""

	if customer.transaction_context.transaction_type == TransactionContext.Type.VISIT:
		_dialogue_phase = DialoguePhase.SOCIAL_VISIT
	else:
		if _greeting_interrupted:
			label = "Greeting"
			_dialogue_phase = DialoguePhase.GREETING
			_greeting_interrupted = false  # Consume the flag
		else:
			label = "Talk"
			_dialogue_phase = DialoguePhase.TALK

	start_dialogue(timeline, customer, _dialogue_phase, label)

func _on_dialogic_signal(argument: String) -> void:
	# [signal arg="refuse_service"] fires mid-execution. Set the flag here,
	# act on it ONLY after timeline_ended fires (never during signal_event).
	if argument == "refuse_service":
		_pending_dismiss = true
	elif argument == "utang_accepted":
		EventBus.utang_accepted.emit(current_customer)
	elif argument == "utang_rejected":
		EventBus.utang_rejected.emit(current_customer)
		_pending_dismiss = true


## Shared helper — sets style, starts the timeline, and registers the bubble anchor.
func start_dialogue(timeline: Variant, customer: Customer, phase: DialoguePhase = DialoguePhase.NONE, label: String = "") -> void:
	# Never start a dialogue if one is playing, if the path is empty,
	# or if the customer is being dismissed.
	if (timeline == null or (timeline is String and timeline.is_empty())) or Dialogic.current_timeline != null:
		return
	if not is_instance_valid(customer) or not customer.is_waiting:
		return

	_dialogue_phase = phase
	_current_timeline_path = timeline.resource_path if timeline is Resource else timeline

	# If this exact timeline is ALREADY running (e.g., Greeting is playing),
	# jump to the requested label (e.g., Satisfy) instead of restarting it.
	if Dialogic.current_timeline != null:
		if Dialogic.current_timeline.resource_path == _current_timeline_path:
			if label != "":
				print("[CustomerSpawner] Jumping directly to label: ", label)
				Dialogic.Jump.jump_to_label(label)
				return
		else:
			# If a DIFFERENT timeline is running (e.g., Uncle Mario), end it first
			# to prioritize the customer's reaction to the delivery.
			print("[CustomerSpawner] Ending current timeline to play: ", _current_timeline_path)
			Dialogic.end_timeline()

	Dialogic.Styles.load_style("FollowBubble")
	var layout = Dialogic.start(timeline, label)

	# Anchor both characters to the speech marker.
	var marker = customer.get_node_or_null("SpeechMarker")
	if marker == null:
		push_warning("[CustomerSpawner] Customer '%s' has no SpeechMarker node — bubble will not follow." % customer.character_id)
	
	if layout and layout.has_method("register_character") and is_instance_valid(marker):
		var char_data = StoryManager._get_character_data(customer.character_id)
		# Register specific character (for story lines)
		if char_data and char_data.dialogic_character:
			layout.register_character(char_data.dialogic_character, marker)
		# Register generic proxy (for generic/filler lines using "Customer:")
		if GENERIC_CHAR_RES:
			layout.register_character(GENERIC_CHAR_RES, marker)

func _on_dialogue_ended() -> void:
	# 1. Detect if Mario just cut in
	if Dialogic.current_timeline != null and "UncleMario" in Dialogic.current_timeline.resource_path:
		print("[CustomerSpawner] Mario interrupted current flow. Interruption flag set.")
		if _dialogue_phase == DialoguePhase.GREETING:
			_greeting_interrupted = true
		_dialogue_phase = DialoguePhase.NONE
		_current_timeline_path = ""
		return
		
	# 2. Detect if Mario just FINISHED (leaving Dialogic empty)
	# We check if restocking is active to verify it was likely Mario's timeline that just ended.
	if MarioManager.is_restocking_active and Dialogic.current_timeline == null:
		print("[CustomerSpawner] Mario timeline ended. (Phase '%s' preserved)" % DialoguePhase.keys()[_dialogue_phase])
		# Do NOT clear _dialogue_phase here! MarioManager will emit delivery_finished 
		# which triggers the deferred/interrupted logic correctly.
		return
		
	# If Dialogic is now free and we have a queued greeting, automatically replay it!
	if Dialogic.current_timeline == null and _greeting_interrupted:
		_greeting_interrupted = false
		if is_instance_valid(current_customer) and current_customer.is_waiting:
			# Yield 1 frame to ensure Dialogic has completely cleaned up the old timeline
			await get_tree().process_frame
			var timeline = current_customer.transaction_context.timeline
			_dialogue_phase = DialoguePhase.GREETING
			start_dialogue(timeline, current_customer, DialoguePhase.GREETING, "Greeting")
		return
		
	# Read and clear the phase atomically.
	var phase := _dialogue_phase
	_dialogue_phase = DialoguePhase.NONE
	_current_timeline_path = ""

	# refuse_service signal fired mid-dialogue (from a choice in TALK or WRONG_ITEM).
	# Always takes priority — dismiss the customer regardless of which phase just ended.
	if _pending_dismiss:
		_pending_dismiss = false
		if is_instance_valid(current_customer) and current_customer.is_waiting:
			current_customer.dismiss()
		return

	match phase:
		DialoguePhase.SOCIAL_VISIT:
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

## Emit day_ended when no more customers will come today.
func _end_day() -> void:
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	EventBus.day_ended.emit(gm.day if gm else 1)

func _on_mario_delivery_finished() -> void:
	_trigger_deferred_greeting()

func _on_mario_call_ended(success: bool) -> void:
	if not success:
		_trigger_deferred_greeting()

func _trigger_deferred_greeting() -> void:
	if _greeting_deferred and is_instance_valid(current_customer):
		print("[CustomerSpawner] Restock complete — triggering deferred greeting for %s." % current_customer.character_id)
		_greeting_deferred = false
		_handle_customer_logic(current_customer, false)
