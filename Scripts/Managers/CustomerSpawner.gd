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
	REPAYMENT,    ## Customer is paying back their debt before the main transaction
}

@export var customer_scene: PackedScene = preload("res://Scenes/Customer.tscn")
@export var spawn_pos: NodePath
@export var target_pos: NodePath
@export var exit_pos: NodePath

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
var _watchdog_frames: int = 0
var _greeting_interrupted: bool = false
 # Remembers if Uncle Mario forcibly shut down the greeting.
var _is_partial_success: bool = false # Tracks if a dismissal should be treated as a success
var _is_nokia_open: bool = false



var is_paused: bool = false:
	set(value):
		is_paused = value
		if not is_paused and current_customer == null and not _is_spawning:
			_spawn_next_customer()
var _dialogue_phase: DialoguePhase = DialoguePhase.NONE
var _current_timeline_path: String = "" # Track the timeline started by this spawner
var _last_dialogue_frame: int = -1 # Frame-based protection against double-starting dialogue
var _pending_restore_transaction: TransactionContext = null

func _ready() -> void:
	LogManager.debug("CustomerSpawner", "_ready() START")
	add_to_group("customer_spawner")
	add_to_group("persist")
	SaveManager.is_quitting = false # Reset quitting flag when entering the game
	EventBus.day_started.connect(_on_day_started)
	EventBus.customer_satisfied.connect(_on_customer_dismissed) # Completion of satisfy()
	EventBus.customer_partial_satisfaction.connect(_on_customer_partial_satisfaction)
	# Rejection no longer triggers dismissal (handles wrong item reaction staying at counter)
	EventBus.customer_dismissed.connect(_on_customer_dismissed)
	Dialogic.timeline_ended.connect(_on_dialogue_ended)
	Dialogic.signal_event.connect(_on_dialogic_signal)
	MarioManager.delivery_finished.connect(_on_mario_delivery_finished)
	MarioManager.call_ended.connect(_on_mario_call_ended)
	EventBus.nokia_opened.connect(_on_nokia_opened)
	EventBus.nokia_closed.connect(_on_nokia_closed)
	EventBus.closing_time_reached.connect(_on_closing_time_reached)
	EventBus.debt_quota_met.connect(_on_debt_quota_met)
	
	EventBus.dialogue_character_speaking.connect(_on_character_speaking)
	LogManager.debug("CustomerSpawner", "_ready() END")

func _on_day_started(_day: int) -> void:
	LogManager.debug("CustomerSpawner", "_on_day_started() Day starts — customers will spawn until 8 PM.")
	_spawn_next_customer()

func _spawn_next_customer(delay: float = -1.0) -> void:
	if _is_spawning:
		LogManager.debug("CustomerSpawner", "_spawn_next_customer() IGNORED: Spawn already in progress.")
		return
		
	if current_customer:
		LogManager.debug("CustomerSpawner", "_spawn_next_customer() ABORTED: customer already present!")
		return

	LogManager.debug("CustomerSpawner", "_spawn_next_customer() CALLED. is_paused=%s, current_customer=%s, _is_spawning=%s" % [is_paused, current_customer != null, _is_spawning])
	if is_paused or current_customer != null or _is_spawning:
		LogManager.debug("CustomerSpawner", "Aborting spawn due to state.")
		return

	# Closing time check
	if StoryManager._current_display_time >= StoryManager.CLOSING_HOUR:
		LogManager.info("CustomerSpawner", "Store is closing. Spawning Mayari for collection.")
		spawn_mayari_for_collection()
		return

	_is_spawning = true
	
	var transaction: TransactionContext = null
	if _pending_restore_transaction:
		transaction = _pending_restore_transaction
		_pending_restore_transaction = null
		LogManager.info("CustomerSpawner", "Using restored transaction for next spawn: %s" % transaction.customer_data.character_name)
		
		# RE-SYNC: Ensure StoryManager (and Dialogic) has the correct string data
		# for this restored transaction before the greeting starts.
		StoryManager.update_transaction_item_string(transaction)
	else:
		transaction = StoryManager.get_next_transaction()

	if transaction == null:
		# No characters configured — nothing to spawn
		_is_spawning = false
		_end_day()
		return

	var type_name: String = ([" STORY", "PURCHASE", "VISIT "])[transaction.transaction_type]
	var item_list: Array[String] = []
	for item in transaction.desired_items:
		item_list.append(item.item_name)
	LogManager.info("Customer", "Incoming transaction: Character=%s, Type=%s, Wants=%s" % [
		transaction.customer_data.get_clean_id(),
		type_name,
		", ".join(item_list) if item_list.size() > 0 else "(nothing — visit)"
	])

	await get_tree().create_timer(2.0).timeout

	var pos_data = _calculate_positions(transaction.secondary_customer_data != null)
	var spawn_global = pos_data.spawn_pos
	var target_global = pos_data.target_pos
	var exit_global = pos_data.exit_pos
	var final_target = pos_data.primary_target
	
	# If the customer is Kuya Kap, offset him back so he doesn't hit his head on the roof.
	if transaction.customer_data.get_clean_id() == "kuyakap":
		var dir_back = (spawn_global - target_global).normalized()
		final_target += (dir_back * 0.7)

	current_customer = customer_scene.instantiate()
	get_parent().add_child(current_customer)
	current_customer.global_position = spawn_global
	current_customer.setup(transaction, final_target, exit_global)

	current_customer.arrived.connect(_on_customer_arrived)
	current_customer.clicked.connect(_on_customer_clicked)
	current_customer.satisfied.connect(_on_customer_finished) # Triggers Satisfy dialogue

	# Spawn Guest Customer if present
	if transaction.secondary_customer_data:
		var guest_context = TransactionContext.new()
		guest_context.customer_data = transaction.secondary_customer_data
		guest_context.transaction_type = TransactionContext.Type.VISIT # Guests don't buy (for now)
		
		var guest_target = pos_data.guest_target
		
		guest_customer = customer_scene.instantiate()
		get_parent().add_child(guest_customer)
		guest_customer.global_position = spawn_global
		guest_customer.setup(guest_context, guest_target, exit_global, transaction.guest_spawns_later)
		
		# Allow clicking the guest to also start the main dialogue
		guest_customer.clicked.connect(_on_guest_clicked)
		
		# Guest doesn't trigger logic, they are just there for dialogue
		LogManager.info("Customer", "Guest spawned: %s" % transaction.secondary_customer_data.get_clean_id())

	EventBus.customer_spawned.emit(current_customer)
	_is_spawning = false

func _calculate_positions(has_guest: bool) -> Dictionary:
	if not spawn_pos or not target_pos:
		return {}

	var spawn_global = get_node(spawn_pos).global_position
	# Note: We don't randomize Z here to keep it deterministic during load
	var target_global = get_node(target_pos).global_position
	var exit_global = get_node(exit_pos).global_position if exit_pos else spawn_global
	
	var approach_dir = (target_global - spawn_global).normalized()
	var side_offset = Vector3(-approach_dir.z, 0, approach_dir.x) # Left perpendicular
	
	var primary_target = target_global
	var guest_target = target_global
	
	if has_guest:
		primary_target = target_global + (side_offset * -0.9) # Shift Primary to Right
		guest_target = target_global + (side_offset * 0.9) # Shift Guest to Left
		
	return {
		"spawn_pos": spawn_global,
		"target_pos": target_global,
		"exit_pos": exit_global,
		"primary_target": primary_target,
		"guest_target": guest_target
	}

func _on_customer_arrived(customer: Customer) -> void:
	_handle_customer_logic(customer, true)

## Process arrival signals. We no longer auto-play dialogue upon arrival.
func _handle_customer_logic(customer: Customer, is_initial_arrival: bool) -> void:
	if is_initial_arrival:
		EventBus.customer_arrived.emit(customer)
		
		_update_item_names(customer)
		

		
		# Patch the generic character resource so "Customer:" lines show the right name and play sounds.
		if GENERIC_CHAR_RES:
			GENERIC_CHAR_RES.display_name = InventoryManager.current_character_name


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
		var active_path = Dialogic.current_timeline.resource_path
		var target_path = customer.transaction_context.timeline.resource_path if customer.transaction_context.timeline is Resource else customer.transaction_context.timeline
		
		if active_path == target_path:
			var label := "Satisfy"
			if StoryManager.is_label_in_timeline(target_path, label):
				LogManager.debug("CustomerSpawner", "Jumping to Satisfy label mid-timeline.")
				Dialogic.Jump.jump_to_label(label)
				_dialogue_phase = DialoguePhase.SATISFIED
				return
		return
		
	_update_item_names(customer)
	
	var timeline = customer.transaction_context.timeline
	_dialogue_phase = DialoguePhase.SATISFIED
	start_dialogue(timeline, customer, _dialogue_phase, "Satisfy")

func _on_customer_dismissed(customer: Customer) -> void:
	# Only process signals from customers we currently track.
	# This prevents "ghost" signals from previous transactions (that are still fading out)
	# from accidentally wiping out the next customer who just started spawning.
	if customer == null:
		return

	if customer != current_customer and customer != guest_customer:
		return

	# RACE GUARD: Both customer_satisfied AND customer_dismissed route here.
	# Lock _is_spawning NOW — before the await — so the second signal fire
	# is rejected by _spawn_next_customer()'s guard instead of racing it.
	if _is_spawning:
		LogManager.debug("CustomerSpawner", "_on_customer_dismissed: already spawning — ignoring duplicate signal.")
		return
	_is_spawning = true

	if is_instance_valid(guest_customer):
		guest_customer.dismiss()
		guest_customer = null
	current_customer = null

	EventBus.customer_order_cleared.emit()

	# Check if we have a pending tier unlock now that the counter is clear
	StoryManager.process_pending_unlock()

	var delay = randf_range(0.3, 5.0)
	if StoryManager._current_display_time >= StoryManager.CLOSING_HOUR:
		delay = 1.0 # Short delay for Mayari arrival

	await get_tree().create_timer(delay).timeout
	# _is_spawning will be managed by _spawn_next_customer from here
	_is_spawning = false
	_spawn_next_customer()

func _process(_delta: float) -> void:
	# Watchdog: If we are in a dialogue phase but Dialogic is no longer running,
	# something likely crashed or ended without firing the timeline_ended signal.
	# We exclude SATISFIED and NONE as those are stable/resolving states.
	if _dialogue_phase != DialoguePhase.NONE and _dialogue_phase != DialoguePhase.SATISFIED:
		if Dialogic.current_timeline == null:
			# Give it a few frames to make sure it's not just a transition
			_watchdog_frames += 1
			if _watchdog_frames > 30: # ~0.5s at 60fps
				LogManager.warn("CustomerSpawner", "WATCHDOG: Dialogue phase stuck in '%s' while Dialogic is inactive. Resetting." % DialoguePhase.keys()[_dialogue_phase])
				_dialogue_phase = DialoguePhase.NONE
				_watchdog_frames = 0
		else:
			_watchdog_frames = 0
	else:
		_watchdog_frames = 0

func _on_customer_clicked(customer: Customer) -> void:

	# Guard order matters — check from cheapest to most specific:
	# 1. Dialogic is actively running a timeline right now.
	if Dialogic.current_timeline != null or customer.transaction_context == null:
		return
	# 2. Customer is being dismissed (satisfy/dismiss already called).
	if not customer.is_waiting:
		return
		
	# 4. Check for Repayment Preamble (30% chance rolled in StoryManager)
	if customer.transaction_context.is_repaying:
		customer.transaction_context.is_repaying = false # Consume flag so it doesn't loop
		_dialogue_phase = DialoguePhase.REPAYMENT
		
		# Dynamic Repayment: Check if the character has a custom "Repayment" label in their timeline
		var repay_timeline = customer.transaction_context.timeline
		var timeline_path = repay_timeline.resource_path if repay_timeline is Resource else repay_timeline
		if StoryManager.is_label_in_timeline(timeline_path, "Repayment"):
			LogManager.debug("CustomerSpawner", "Found custom Repayment label. Using: %s" % timeline_path)
			start_dialogue(repay_timeline, customer, _dialogue_phase, "Repayment")
		else:
			LogManager.debug("CustomerSpawner", "No custom Repayment label. Falling back to Generic/Repayment.dtl")
			start_dialogue("res://Dialogue/Timelines/Generic/Repayment.dtl", customer, _dialogue_phase)
		return

	# 5. _dialogue_phase != NONE means a timeline just finished its async clear
	#    but timeline_ended hasn't fired yet.
	if _dialogue_phase != DialoguePhase.NONE and _dialogue_phase != DialoguePhase.SATISFIED:
		return

	# 4. If they are already in the middle of a satisfy/dismiss process, block.
	if customer.has_method("_is_resolving") and customer._is_resolving:
		return

	if MarioManager.is_restocking_active or _is_nokia_open:
		# Don't allow manual dialogue triggering while phone is open
		return

	var timeline = customer.transaction_context.timeline
	var label: String = ""

	if customer.transaction_context.transaction_type == TransactionContext.Type.VISIT:
		_dialogue_phase = DialoguePhase.SOCIAL_VISIT
		var timeline_path = timeline.resource_path if timeline is Resource else timeline
		if StoryManager.is_label_in_timeline(timeline_path, "Greeting"):
			label = "Greeting"
	else:
		if not customer.has_been_greeted or _greeting_interrupted:
			var timeline_path = timeline.resource_path if timeline is Resource else timeline
			if Dialogic.VAR.get_variable("Global_RumorActive") and StoryManager.is_label_in_timeline(timeline_path, "Rumor"):
				label = "Rumor"
			else:
				label = "Greeting"
			_dialogue_phase = DialoguePhase.GREETING
			_greeting_interrupted = false  # Consume the flag
		else:
			label = "Talk"
			_dialogue_phase = DialoguePhase.TALK

	# ── Manual Trigger debug ─────────────────────────────
	LogManager.info("Dialogue", "Manual Trigger: Character=%s, Phase=%s, Label=%s" % [
		InventoryManager.current_character_name,
		DialoguePhase.keys()[_dialogue_phase],
		label if label != "" else "(Start)"
	])

	start_dialogue(timeline, customer, _dialogue_phase, label)

func _on_guest_clicked(_guest: Customer) -> void:
	# If guest is clicked, we redirect the interaction to the primary customer
	if is_instance_valid(current_customer):
		_on_customer_clicked(current_customer)

func _on_dialogic_signal(argument: String) -> void:
	if argument == "refuse_service":
		# [signal arg="refuse_service"] should ALWAYS dismiss the customer.
		_pending_dismiss = true
		
		# If items were already delivered, treat as a partial completion.
		var delivered = Dialogic.VAR.get_variable("Transaction_DeliveredCount")
		if delivered > 0:
			_is_partial_success = true
			# Try to jump to a specific partial success label, fallback to Satisfy
			if StoryManager.is_label_in_timeline(_current_timeline_path, "PartialDismiss"):
				Dialogic.Jump.jump_to_label("PartialDismiss")
			elif StoryManager.is_label_in_timeline(_current_timeline_path, "Satisfy"):
				Dialogic.Jump.jump_to_label("Satisfy")
			else:
				# If neither exists, just mark for dismissal but with success flag
				_pending_dismiss = true
		else:
			_pending_dismiss = true
	elif argument == "partial_dismiss" or argument == "story_success":
		_is_partial_success = true
		_pending_dismiss = true
	elif argument == "utang_accepted":
		EventBus.utang_accepted.emit(current_customer)
	elif argument == "utang_rejected":
		EventBus.utang_rejected.emit(current_customer)
		_pending_dismiss = true
	elif argument == "pulse_red":
		if is_instance_valid(current_customer):
			current_customer.pulse_color(Color.RED)
	elif argument == "pulse_green":
		if is_instance_valid(current_customer):
			current_customer.pulse_color(Color("#0f6e2f")) # Vibrant Green
	elif argument == "setup_debt":
		if is_instance_valid(current_customer) and current_customer.transaction_context:
			current_customer.transaction_context.wants_debt = true
			StoryManager._set_dvar("Transaction_WantsDebt", 1.0)
			LogManager.debug("CustomerSpawner", "Forcing DEBT state via signal.")
	elif argument == "setup_repay_full":
		if is_instance_valid(current_customer) and current_customer.transaction_context:
			var path = current_customer.customer_data.resource_path
			var debt = StoryManager.customer_debts.get(path, 0.0)
			current_customer.transaction_context.is_repaying = true
			current_customer.transaction_context.repayment_amount = debt
			StoryManager._set_dvar("Transaction_IsRepaying", 1.0)
			StoryManager._set_dvar("Transaction_RepaymentAmount", debt)
			LogManager.debug("CustomerSpawner", "Forcing FULL REPAYMENT state via signal: %f" % debt)
	elif argument == "setup_repay_half":
		if is_instance_valid(current_customer) and current_customer.transaction_context:
			var path = current_customer.customer_data.resource_path
			var debt = StoryManager.customer_debts.get(path, 0.0)
			var half = floor(debt / 2.0)
			current_customer.transaction_context.is_repaying = true
			current_customer.transaction_context.repayment_amount = half
			StoryManager._set_dvar("Transaction_IsRepaying", 1.0)
			StoryManager._set_dvar("Transaction_RepaymentAmount", half)
			LogManager.debug("CustomerSpawner", "Forcing HALF REPAYMENT state via signal: %f" % half)
	elif argument == "spawn_guest":
		if is_instance_valid(guest_customer) and guest_customer.has_method("trigger_arrival"):
			guest_customer.trigger_arrival()

func _on_customer_partial_satisfaction(customer: Customer) -> void:
	if Dialogic.current_timeline != null:
		return
		
	# Update the strings for the remaining items
	_update_item_names(customer)
	
	# Trigger a "Partial" thanks. We check for a "Partial" label in their timeline.
	# If omitted, it will just start the timeline at "Talk" or repeat the request.
	var timeline = customer.transaction_context.timeline
	_dialogue_phase = DialoguePhase.TALK 
	
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
		var data = customer.customer_data
		var cname = data.character_name if data.character_name != "" else data.get_clean_id()
		LogManager.debug("CustomerSpawner", "NOTE: Transaction has zero items for '%s' (visit or visit-story). Skipping ItemWants update." % cname)
		
		# Still update character name and counts, but leave Transaction_ItemWants alone.
		InventoryManager.current_character_name = cname
		InventoryManager.current_item_name = ""
		StoryManager._set_dvar("Transaction_CustomerName", InventoryManager.current_character_name)
		if customer.transaction_context:
			var total_cnt = customer.transaction_context.original_count
			var remain_cnt = customer.transaction_context.desired_items.size()
			StoryManager._set_dvar("Transaction_DeliveredCount", total_cnt - remain_cnt)
			StoryManager._set_dvar("Transaction_RemainingCount", remain_cnt)
		if GENERIC_CHAR_RES:
			GENERIC_CHAR_RES.display_name = InventoryManager.current_character_name
		return
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

	# 3. Update Dialogic Variables — Sync safely via StoryManager helper
	StoryManager._set_dvar("Transaction_CustomerName", InventoryManager.current_character_name)
	StoryManager._set_dvar("Transaction_ItemWants", InventoryManager.current_item_name)
	
	# 4. Sync Delivered/Remaining Counts
	if customer.transaction_context:
		var total_cnt = customer.transaction_context.original_count
		var remain_cnt = customer.transaction_context.desired_items.size()
		StoryManager._set_dvar("Transaction_DeliveredCount", total_cnt - remain_cnt)
		StoryManager._set_dvar("Transaction_RemainingCount", remain_cnt)
	
	# 5. Patch Generic Character Resource
	if GENERIC_CHAR_RES:
		GENERIC_CHAR_RES.display_name = InventoryManager.current_character_name

## Shared helper — sets style, starts the timeline, and registers the bubble anchor.
func start_dialogue(timeline, customer: Customer, phase: DialoguePhase = DialoguePhase.NONE, label: String = "") -> void:
	# Never start a dialogue if the timeline is empty or if the customer is gone.
	if (timeline == null or (timeline is String and timeline.is_empty())):
		return
	if not is_instance_valid(customer) or not customer.is_waiting:
		return
		
	# PROTECTION: Prevent "Double-Start" race conditions within the target frame.
	# This happens if both Customer.gd and MainGame.gd trigger start_dialogue simultaneously.
	if Engine.get_frames_drawn() == _last_dialogue_frame:
		LogManager.warn("CustomerSpawner", "REJECTED: start_dialogue already called in this frame. Latching to previous call.")
		return
	_last_dialogue_frame = Engine.get_frames_drawn()

	_dialogue_phase = phase
	_current_timeline_path = timeline.resource_path if timeline is Resource else timeline
	
	# HUD: Update orders immediately for transaction phases (Partial/Satisfied)
	# For GREETING, we wait until the dialogue ENDS (in _on_dialogue_ended)
	if phase in [DialoguePhase.TALK, DialoguePhase.SATISFIED]:
		if is_instance_valid(customer) and customer.transaction_context:
			EventBus.customer_order_updated.emit(customer.customer_data.character_name, customer.transaction_context.desired_items, customer.transaction_context.is_riddle)

	# LABEL SAFETY: If a specific label (like 'Partial') is requested but missing from the timeline,
	# fallback to 'Satisfy' or start at the beginning to avoid silent Dialogic crashes.
	var final_label = label
	if final_label != "":
		var exists = StoryManager.is_label_in_timeline(_current_timeline_path, final_label)
		if not exists:
			print("[CustomerSpawner] WARNING: Label '%s' missing in %s." % [final_label, _current_timeline_path])
			if final_label == "Partial":
				final_label = "Satisfy" # Best fallback for multi-item orders
				print("[CustomerSpawner] Falling back to: Satisfy")
			elif final_label == "Satisfy":
				final_label = "" # Final fallback: start from beginning
				print("[CustomerSpawner] Falling back to start of timeline.")

	LogManager.info("Dialogue", "Starting: %s (Phase: %s, Label: %s)" % [_current_timeline_path, DialoguePhase.keys()[phase], final_label])

	# If a different timeline is running, end it first to prioritize this one.
	# We REMOVED the early return for Dialogic.current_timeline != null to allow 
	# item-giving to interrupt greetings or idle talk.
	if Dialogic.current_timeline != null:
		if Dialogic.current_timeline.resource_path != _current_timeline_path:
			LogManager.info("CustomerSpawner", "Ending current timeline to play priority: %s" % _current_timeline_path)
			Dialogic.end_timeline()
		elif final_label != "":
			LogManager.debug("CustomerSpawner", "Jumping directly to label: %s" % final_label)
			Dialogic.Jump.jump_to_label(final_label)
			return

	Dialogic.Styles.load_style("FollowBubble")
	var layout = Dialogic.start(timeline, final_label)
	if layout == null:
		LogManager.error("CustomerSpawner", "Dialogic FAILED to start timeline: %s (Phase reset to NONE)" % _current_timeline_path)
		_dialogue_phase = DialoguePhase.NONE
		_current_timeline_path = ""
		return

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
	LogManager.debug("CustomerSpawner", "Dialogue Ended signal received. Current Phase: %s" % DialoguePhase.keys()[_dialogue_phase])

	if SaveManager.is_quitting:
		LogManager.debug("CustomerSpawner", "Dialogue ended due to quitting. Suppressing dismissal.")
		_dialogue_phase = DialoguePhase.NONE
		_current_timeline_path = ""
		_pending_dismiss = false
		return

	# 1. Detect if Mario just cut in
	if Dialogic.current_timeline != null and "UncleMario.dtl" in Dialogic.current_timeline.resource_path:
		LogManager.debug("CustomerSpawner", "Mario interrupted current flow. Interruption flag set.")
		if _dialogue_phase == DialoguePhase.GREETING:
			_greeting_interrupted = true
		_dialogue_phase = DialoguePhase.NONE
		_current_timeline_path = ""
		return
		
	# 2. Detect if Mario just FINISHED (leaving Dialogic empty)
	# We check if restocking is active to verify it was likely Mario's timeline that just ended.
	if MarioManager.is_restocking_active and Dialogic.current_timeline == null:
		LogManager.debug("CustomerSpawner", "Mario timeline ended. (Phase '%s' preserved)" % DialoguePhase.keys()[_dialogue_phase])
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
		
	# 3. Handle continuation after REPAYMENT preamble
	if _dialogue_phase == DialoguePhase.REPAYMENT:
		_dialogue_phase = DialoguePhase.NONE
		if is_instance_valid(current_customer) and current_customer.is_waiting:
			# Resimulate clicking the customer to start their actual transaction
			_on_customer_clicked(current_customer)
		return
		
	# Read and clear the phase atomically.
	var phase := _dialogue_phase
	_dialogue_phase = DialoguePhase.NONE
	_current_timeline_path = ""

	# refuse_service signal fired mid-dialogue (from a choice in TALK or WRONG_ITEM).
	# Always takes priority — dismiss the customer regardless of which phase just ended.
	if _pending_dismiss:
		_pending_dismiss = false
		if is_instance_valid(current_customer):
			# Dismiss guest alongside primary if present, with a slight delay
			if is_instance_valid(guest_customer):
				var g = guest_customer
				guest_customer = null
				get_tree().create_timer(0.5).timeout.connect(func(): if is_instance_valid(g): g.dismiss())

			# Final decision: Satisfy (happy/partial) vs Dismiss (canceled/failure)
			# We use satisfy() if items were traded OR if we explicitly marked it as a partial success.
			var delivered = Dialogic.VAR.get_variable("Transaction_DeliveredCount")
			if _is_partial_success or (delivered != null and delivered > 0):
				current_customer.satisfy()
			else:
				current_customer.dismiss()
				
			_is_partial_success = false
		return

	match phase:
		DialoguePhase.SOCIAL_VISIT:
			# Drop-in visit. Dismiss customer — _on_customer_dismissed spawns next.
			if is_instance_valid(guest_customer):
				var g = guest_customer
				guest_customer = null
				get_tree().create_timer(0.5).timeout.connect(func(): if is_instance_valid(g): g.dismiss())

			if is_instance_valid(current_customer) and current_customer.is_waiting:
				current_customer.has_been_greeted = true
				current_customer.dismiss()

		DialoguePhase.SATISFIED:
			# satisfy() sets is_waiting=false and owns its own exit animation.
			if is_instance_valid(guest_customer):
				var g = guest_customer
				guest_customer = null
				get_tree().create_timer(0.5).timeout.connect(func(): if is_instance_valid(g): g.dismiss())

			if is_instance_valid(current_customer):
				current_customer.satisfy()
			
			# _handle_transaction_cleanup() REMOVED. 
			# We now rely solely on _on_customer_dismissed (connected to EventBus) 
			# to trigger the next spawn after the exit animation finishes.
			# This prevents the race condition where two spawns were triggered for one customer.

		DialoguePhase.WRONG_ITEM:
			# Customer reacted to the wrong item but stays at the counter.
			# Player can either give the correct item or refuse service next time.
			pass

		DialoguePhase.GREETING:
			# If a story encounter was just an intro/greeting and it ends, 
			# we might need to satisfy it if it's a visit-only chapter.
			if is_instance_valid(current_customer) and current_customer.transaction_context:
				var t = current_customer.transaction_context
				if t.transaction_type == TransactionContext.Type.STORY and t.is_visit_story:
					LogManager.debug("CustomerSpawner", "Fallback Satisfaction for VISIT-STORY.")
					current_customer.satisfy()
					return
			if phase == DialoguePhase.GREETING and is_instance_valid(current_customer):
				current_customer.has_been_greeted = true
				if current_customer.transaction_context:
					EventBus.customer_order_updated.emit(InventoryManager.current_character_name, current_customer.transaction_context.desired_items, current_customer.transaction_context.is_riddle)
			pass




func _on_closing_time_reached() -> void:
	# If time hit 8 PM and no one is at the counter, spawn Mayari immediately.
	if current_customer == null and not _is_spawning:
		spawn_mayari_for_collection()

func spawn_mayari_for_collection() -> void:
	if _is_spawning or current_customer != null:
		return
	
	_is_spawning = true
	
	# Request the special collection transaction from StoryManager
	var transaction = StoryManager.get_collection_transaction()
	if transaction == null:
		_is_spawning = false
		_end_day()
		return

	LogManager.info("Customer", "Incoming Debt Collection: Character=Reyna Mayari, Type=VISIT (Collection)")

	await get_tree().create_timer(1.5).timeout

	var spawn_global = get_node(spawn_pos).global_position
	var target_global = get_node(target_pos).global_position
	
	current_customer = customer_scene.instantiate()
	get_parent().add_child(current_customer)
	current_customer.global_position = spawn_global
	current_customer.setup(transaction, target_global)

	current_customer.arrived.connect(_on_customer_arrived)
	current_customer.clicked.connect(_on_customer_clicked)
	current_customer.satisfied.connect(_on_customer_finished)

	EventBus.customer_spawned.emit(current_customer)
	_is_spawning = false

func _on_debt_quota_met(_success: bool) -> void:
	# This is called after Mayari's dialogue finishes and she is dismissed.
	# We can now safely end the day.
	pass

## Emit day_ended when no more customers will come today.
func _end_day() -> void:
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	EventBus.day_ended.emit(gm.day if gm else 1)

func _on_mario_delivery_finished() -> void:
	pass

func _on_mario_call_ended(_success: bool) -> void:
	pass

func _on_nokia_opened() -> void:
	_is_nokia_open = true

func _on_nokia_closed() -> void:
	_is_nokia_open = false


# ── Persistence ──────────────────────────────────────────────────────────────

func get_save_id() -> String:
	return "customer_spawner"

func get_save_data() -> Dictionary:
	var data := {}
	
	if is_instance_valid(current_customer) and current_customer.transaction_context:
		data["current_customer"] = current_customer.transaction_context.to_dict()
		data["current_greeted"] = current_customer.has_been_greeted
		
	if is_instance_valid(guest_customer) and guest_customer.transaction_context:
		data["guest_customer"] = guest_customer.transaction_context.to_dict()
		data["guest_greeted"] = guest_customer.has_been_greeted
		
	return data

func load_save_data(data: Dictionary) -> void:
	# IMPORTANT: Do NOT restore _dialogue_phase from save.
	# The customer will do a fresh walk-in, so the phase must start as NONE.
	# Restoring a stale phase (e.g. GREETING or SOCIAL_VISIT) would permanently
	# block the click guard at _on_customer_clicked() line 286, making the
	# re-spawned customer unclickable. This was the root cause of the tutorial bug.
	_dialogue_phase = DialoguePhase.NONE
	_greeting_interrupted = false # Also reset: interruption state is irrelevant after a reload
	
	if data.has("current_customer"):
		var ctx_data = data["current_customer"]
		var ctx = TransactionContext.from_dict(ctx_data)
		if ctx and ctx.customer_data:
			_pending_restore_transaction = ctx
			LogManager.info("CustomerSpawner", "Queuing restored customer for fresh walk-in: %s" % ctx.customer_data.character_name)
			
			# Delay slightly to ensure self is ready, then trigger spawn
			get_tree().create_timer(1.0).timeout.connect(func(): _spawn_next_customer())
			return

func reset_state() -> void:
	_pending_restore_transaction = null
	current_customer = null
	guest_customer = null
	_is_spawning = false
	_dialogue_phase = DialoguePhase.NONE
	_greeting_interrupted = false
	LogManager.info("CustomerSpawner", "State reset for New Game.")

	# If no customer to restore, handle guest restoration (optional, usually guest is with primary)


func _on_character_speaking(data: CustomerData) -> void:
	if not data:
		return
		
	# Match data to current_customer or guest_customer using stable ID
	var target_id = data.get_clean_id()
	
	if current_customer and current_customer.customer_data:
		if current_customer.customer_data.get_clean_id() == target_id:
			current_customer.play_speak_animation()
	
	if guest_customer and guest_customer.customer_data:
		if guest_customer.customer_data.get_clean_id() == target_id:
			guest_customer.play_speak_animation()
