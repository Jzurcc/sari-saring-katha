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
const PLACEHOLDER_EMPTY_STORY := "res://Dialogue/Timelines/Generic/Neutral.dtl"

## Proxy character used in generic dialogues (e.g. "Customer: Hello!").
## We patch this at runtime to show the correct name and anchor to the sprite.
var GENERIC_CHAR_RES := preload("res://Dialogue/Timelines/Customer.dch")

var current_customer: Customer = null
var guest_customer: Customer = null
var _pending_dismiss: bool = false
var _is_spawning: bool = false
var _greeting_interrupted: bool = false # Remembers if Uncle Mario forcibly shut down the greeting.
var _is_partial_success: bool = false # Tracks if a dismissal should be treated as a success
var _greeting_deferred: bool = false # Remembers if a greeting was stalled because Mario was busy.
var _is_nokia_open: bool = false



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
	EventBus.customer_satisfied.connect(_on_customer_dismissed) # Completion of satisfy()
	EventBus.customer_partial_satisfaction.connect(_on_customer_partial_satisfaction)
	EventBus.customer_rejected.connect(_on_customer_dismissed)
	EventBus.customer_dismissed.connect(_on_customer_dismissed)
	Dialogic.timeline_ended.connect(_on_dialogue_ended)
	Dialogic.signal_event.connect(_on_dialogic_signal)
	MarioManager.delivery_finished.connect(_on_mario_delivery_finished)
	MarioManager.call_ended.connect(_on_mario_call_ended)
	EventBus.nokia_opened.connect(_on_nokia_opened)
	EventBus.nokia_closed.connect(_on_nokia_closed)

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
	print("  Character : ", transaction.customer_data.get_clean_id())
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
	
	# Calculate side offsets for dual customers
	var approach_dir = (target_global - spawn_global).normalized()
	var side_offset = Vector3(-approach_dir.z, 0, approach_dir.x) # Left perpendicular
	
	if transaction.secondary_customer_data:
		final_target = target_global + (side_offset * -0.4) # Shift Primary to Right
	
	# If the customer is Kuya Kap, offset him back so he doesn't hit his head on the roof.
	if transaction.customer_data.get_clean_id() == "kuyakap":
		var dir_back = (spawn_global - target_global).normalized()
		final_target += (dir_back * 0.7)

	current_customer = customer_scene.instantiate()
	get_parent().add_child(current_customer)
	current_customer.global_position = spawn_global
	current_customer.setup(transaction, final_target)

	current_customer.arrived.connect(_on_customer_arrived)
	current_customer.clicked.connect(_on_customer_clicked)
	current_customer.satisfied.connect(_on_customer_finished) # Triggers Satisfy dialogue

	# Spawn Guest Customer if present
	if transaction.secondary_customer_data:
		var guest_context = TransactionContext.new()
		guest_context.customer_data = transaction.secondary_customer_data
		guest_context.transaction_type = TransactionContext.Type.VISIT # Guests don't buy (for now)
		
		var guest_target = target_global + (side_offset * 0.4) # Shift Guest to Left
		
		guest_customer = customer_scene.instantiate()
		get_parent().add_child(guest_customer)
		guest_customer.global_position = spawn_global
		guest_customer.setup(guest_context, guest_target)
		
		# Guest doesn't trigger logic, they are just there for dialogue
		print("[CUSTOMER] Guest spawned: ", transaction.secondary_customer_data.get_clean_id())

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
			await player.face_node(customer)

		_update_item_names(customer)
		
		# Patch the generic character resource so "Customer:" lines show the right name and play sounds.
		if GENERIC_CHAR_RES:
			GENERIC_CHAR_RES.display_name = InventoryManager.current_character_name

	# ── DIALOGUE LOGIC ──
	var timeline = customer.transaction_context.timeline
	var start_label := "Greeting"
	var next_phase := DialoguePhase.GREETING
	
	if customer.transaction_context.transaction_type == TransactionContext.Type.VISIT:
		start_label = "" # Play from start for social visits
		next_phase = DialoguePhase.SOCIAL_VISIT
	elif Dialogic.VAR.get_variable("Global.RumorActive"):
		# If a rumor is active and the character has a dedicated label, start there
		if _is_label_in_timeline(timeline, "Rumor") and not customer.has_been_greeted:
			start_label = "Rumor"
			print("[CustomerSpawner] Specific Rumor label found and prioritized.")

	if MarioManager.is_restocking_active or _is_nokia_open:
		print("[CustomerSpawner] Phone is active — deferring greeting for %s." % customer.customer_data.get_clean_id())
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

var _processed_finished_customers: Array[Customer] = []

func _on_customer_finished(customer: Customer) -> void:
	# Double-processing guard
	if customer in _processed_finished_customers:
		return
	_processed_finished_customers.append(customer)
	if _processed_finished_customers.size() > 5:
		_processed_finished_customers.pop_front()

	# This is called when CUSTOMER_SATISFIED is emitted (all items delivered).
	# Instead of clearing them immediately, we trigger the "Satisfy" dialogue.
	if Dialogic.current_timeline != null:
		# If a timeline is already running, we might be in the middle of a partial satisfaction
		# or a riddle resolution that just completed the transaction. 
		# If the current timeline IS the customer's timeline, we should jump to Satisfy.
		if Dialogic.current_timeline.resource_path == customer.transaction_context.timeline.resource_path:
			var label := "Satisfy"
			if _is_label_in_timeline(_current_timeline_path, label):
				print("[CustomerSpawner] Jumping to Satisfy label mid-timeline.")
				Dialogic.Jump.jump_to_label(label)
				_dialogue_phase = DialoguePhase.SATISFIED
				return
		return
		
	_update_item_names(customer)
	
	var timeline = customer.transaction_context.timeline
	_dialogue_phase = DialoguePhase.SATISFIED
	start_dialogue(timeline, customer, _dialogue_phase, "Satisfy")

func _on_customer_dismissed(_customer: Customer) -> void:
	if is_instance_valid(guest_customer):
		guest_customer.dismiss()
		guest_customer = null
		
	current_customer = null
	
	# Check if we have a pending tier unlock now that the counter is clear
	StoryManager.process_pending_unlock()
	
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
	#    but timeline_ended hasn't fired yet.
	if _dialogue_phase != DialoguePhase.NONE and _dialogue_phase != DialoguePhase.SATISFIED:
		return

	# 4. If they are already in the middle of a satisfy/dismiss process, block.
	if customer.has_method("_is_resolving") and customer._is_resolving:
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
		# Partial success check: if items were delivered, redirect to a partial completion path.
		# We attempt to jump to PartialDismiss or Satisfy labels.
		var delivered = Dialogic.VAR.get_variable("Transaction.DeliveredCount")
		if delivered > 0:
			_is_partial_success = true
			# Try to jump to a specific partial success label, fallback to Satisfy
			if _is_label_in_timeline(_current_timeline_path, "PartialDismiss"):
				Dialogic.Jump.jump_to_label("PartialDismiss")
			elif _is_label_in_timeline(_current_timeline_path, "Satisfy"):
				Dialogic.Jump.jump_to_label("Satisfy")
			else:
				# If neither exists, just mark for dismissal but with success flag
				_pending_dismiss = true
		else:
			_pending_dismiss = true
	elif argument == "partial_dismiss":
		_is_partial_success = true
		_pending_dismiss = true
	elif argument == "utang_accepted":
		EventBus.utang_accepted.emit(current_customer)
	elif argument == "utang_rejected":
		EventBus.utang_rejected.emit(current_customer)
		_pending_dismiss = true

func _on_customer_partial_satisfaction(customer: Customer) -> void:
	if Dialogic.current_timeline != null:
		return
		
	# Update the strings for the remaining items
	_update_item_names(customer)
	
	# Trigger a "Partial" thanks. We check for a "Partial" label in their timeline.
	# If omitted, it will just start the timeline at "Talk" or repeat the request.
	var timeline = customer.transaction_context.timeline
	_dialogue_phase = DialoguePhase.TALK 
	
	# For now, we will just use the "Talk" label which we've already updated 
	# to show the remaining items in Neutral.dtl.
	start_dialogue(timeline, customer, _dialogue_phase, "Partial")

func _update_item_names(customer: Customer) -> void:
	# 1. Build the grammar-aware item list
	var item_names: Array[String] = []
	var ctx = customer.transaction_context
	
	for item in ctx.desired_items:
		# If this is currently a riddle, skip the specific riddle item so it doesn't spoil the hint.
		if ctx.is_riddle and item == ctx.riddle_item:
			continue
		item_names.append(item.item_name)
	
	var formatted_names = ""
	if item_names.size() == 0:
		formatted_names = "something"
	elif item_names.size() == 1:
		formatted_names = item_names[0]
	elif item_names.size() == 2:
		formatted_names = item_names[0] + " and " + item_names[1]
	else:
		var last = item_names.pop_back()
		formatted_names = ", ".join(item_names) + ", and " + last
		
	InventoryManager.current_item_name = formatted_names

	# 2. Set the character display name
	var data = customer.customer_data
	InventoryManager.current_character_name = data.character_name if data.character_name != "" else data.get_clean_id()

	# 3. Update Dialogic Variables
	Dialogic.VAR.set_variable("Transaction.CustomerName", InventoryManager.current_character_name)
	Dialogic.VAR.set_variable("Transaction.ItemWants", InventoryManager.current_item_name)
	
	# 4. Sync Delivered/Remaining Counts
	if customer.transaction_context:
		var total = customer.transaction_context.original_count
		var remaining = customer.transaction_context.desired_items.size()
		Dialogic.VAR.set_variable("Transaction.DeliveredCount", total - remaining)
		Dialogic.VAR.set_variable("Transaction.RemainingCount", remaining)
	
	# 5. Patch Generic Character Resource
	if GENERIC_CHAR_RES:
		GENERIC_CHAR_RES.display_name = InventoryManager.current_character_name

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
			if label != "" and _is_label_in_timeline(_current_timeline_path, label):
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

	# Freeze the game clock while dialogue is active
	StoryManager.is_clock_running = false

	# Anchor characters to the speech markers.
	if layout and layout.has_method("register_character"):
		# 1. Primary Customer
		var marker = customer.get_node_or_null("SpeechMarker")
		if marker:
			var char_data = customer.customer_data
			if char_data and char_data.dialogic_character:
				var dch_name: String = char_data.dialogic_character.resource_path.get_file().get_basename()
				var canonical_char = DialogicResourceUtil.get_character_resource(dch_name)
				if canonical_char:
					layout.register_character(canonical_char, marker)
			
			if GENERIC_CHAR_RES:
				var generic_name: String = GENERIC_CHAR_RES.resource_path.get_file().get_basename()
				var canonical_generic = DialogicResourceUtil.get_character_resource(generic_name)
				if canonical_generic:
					layout.register_character(canonical_generic, marker)
		
		# 2. Guest Customer
		if is_instance_valid(guest_customer):
			var guest_marker = guest_customer.get_node_or_null("SpeechMarker")
			if guest_marker:
				var guest_data = guest_customer.customer_data
				if guest_data and guest_data.dialogic_character:
					var guest_dch_name: String = guest_data.dialogic_character.resource_path.get_file().get_basename()
					var canonical_guest = DialogicResourceUtil.get_character_resource(guest_dch_name)
					if canonical_guest:
						layout.register_character(canonical_guest, guest_marker)


func _on_dialogue_ended() -> void:
	# Resume the game clock when dialogue ends
	StoryManager.is_clock_running = true
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
			# If it was a partial success, treat as satisfied (fade in place, count towards quota)
			if _is_partial_success:
				current_customer.satisfy()
				_is_partial_success = false
				# We don't return here because we need current_customer = null and spawning logic below 
				# but satisfy() owns its current_customer lifecycle. Actually, better to match SATISFIED behavior.
				_handle_transaction_cleanup()
				return
			else:
				current_customer.dismiss()
		return

	match phase:
		DialoguePhase.SOCIAL_VISIT:
			# Drop-in visit. Dismiss customer — _on_customer_dismissed spawns next.
			if is_instance_valid(current_customer) and current_customer.is_waiting:
				current_customer.has_been_greeted = true
				current_customer.dismiss()

		DialoguePhase.SATISFIED:
			# satisfy() sets is_waiting=false and owns its own exit animation.
			if is_instance_valid(guest_customer):
				guest_customer.dismiss()
				guest_customer = null

			if is_instance_valid(current_customer):
				current_customer.satisfy()
			
			_handle_transaction_cleanup()

		DialoguePhase.WRONG_ITEM:
			# Customer reacted to the wrong item but stays at the counter.
			# Player can either give the correct item or refuse service next time.
			pass

		DialoguePhase.GREETING, DialoguePhase.TALK, DialoguePhase.NONE:
			# Customer is at the counter waiting for their item. Player must act.
			if phase == DialoguePhase.GREETING and is_instance_valid(current_customer):
				current_customer.has_been_greeted = true
			pass

func _handle_transaction_cleanup() -> void:
	current_customer = null
	_is_partial_success = false
	
	# Check if we have a pending tier unlock now that the counter is clear
	StoryManager.process_pending_unlock()
	
	# Small delay before next customer
	await get_tree().create_timer(randf_range(5.0, 15.0)).timeout
	_spawn_next_customer()



## Helper to see if a label exists in a timeline file (.dtl)
func _is_label_in_timeline(path: String, label_name: String) -> bool:
	if path == "":
		return false
	
	# Normalize path and handle missing .dtl extension
	var full_path = path
	if not full_path.ends_with(".dtl"):
		full_path += ".dtl"
		
	if not FileAccess.file_exists(full_path):
		# Try one more fallback if Dialogic uses local paths
		if not full_path.begins_with("res://"):
			full_path = "res://" + full_path
		if not FileAccess.file_exists(full_path):
			return false
	
	var file = FileAccess.open(full_path, FileAccess.READ)
	if not file: return false
	
	var content = file.get_as_text()
	
	# Robust label matching:
	# - Matches "label" at start of line (after optional whitespace)
	# - Followed by at least one whitespace
	# - Then the exact label name
	# - Ignores anything after (comments, etc)
	var regex = RegEx.new()
	regex.compile("^\\s*label\\s+" + label_name + "(\\s+|#|$)")
	
	for line in content.split("\n"):
		if regex.search(line):
			return true
	return false

## Emit day_ended when no more customers will come today.
func _end_day() -> void:
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	EventBus.day_ended.emit(gm.day if gm else 1)

func _on_mario_delivery_finished() -> void:
	_trigger_deferred_greeting()

func _on_mario_call_ended(success: bool) -> void:
	if not success:
		_trigger_deferred_greeting()

func _on_nokia_opened() -> void:
	_is_nokia_open = true

func _on_nokia_closed() -> void:
	_is_nokia_open = false
	# Small delay to ensure UI closing animations don't overlap with bubble appearances
	await get_tree().create_timer(0.5).timeout
	_trigger_deferred_greeting()

func _trigger_deferred_greeting() -> void:
	if _greeting_deferred and is_instance_valid(current_customer):
		print("[CustomerSpawner] Restock complete — triggering deferred greeting for %s." % current_customer.customer_data.get_clean_id())
		_greeting_deferred = false
		_handle_customer_logic(current_customer, false)
