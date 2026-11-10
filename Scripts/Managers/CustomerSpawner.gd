extends Node
class_name CustomerSpawner

## Tracks which phase of dialogue is currently playing.
## Used by _on_dialogue_ended to decide what to do when a timeline ends.
## timeline_ended fires EXACTLY ONCE per timeline (confirmed from Dialogic source)
const DialoguePhase = TransactionSession.Phase

@export var customer_scene: PackedScene = preload("res://Scenes/Customer.tscn")
@export var spawn_pos: NodePath
@export var target_pos: NodePath
@export var exit_pos: NodePath

const PLACEHOLDER_EMPTY_STORY := "res://Dialogue/Timelines/Generic/Neutral.dtl"

var session: TransactionSession = TransactionSession.new()

var current_customer: Customer:
	get: return session.current_customer
	set(val): session.current_customer = val

var guest_customer: Customer:
	get: return session.guest_customer
	set(val): session.guest_customer = val

var _dialogue_phase: TransactionSession.Phase:
	get: return session.phase
	set(val): session.phase = val

var _is_spawning: bool = false
var _is_nokia_open: bool = false

var is_paused: bool = false:
	set(value):
		is_paused = value
		if not is_paused and current_customer == null and not _is_spawning:
			_spawn_next_customer()

var _pending_restore_transaction: TransactionContext = null

func _ready() -> void:
	LogManager.debug("CustomerSpawner", "_ready() START")
	add_to_group("customer_spawner")
	add_to_group("persist")
	session.setup(self)
	SaveManager.is_quitting = false # Reset quitting flag when entering the game
	EventBus.day_started.connect(_on_day_started)
	EventBus.customer_satisfied.connect(_on_customer_dismissed)
	EventBus.customer_partial_satisfaction.connect(_on_customer_partial_satisfaction)
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

func _spawn_next_customer(_delay: float = -1.0) -> void:
	if _is_spawning:
		LogManager.debug("CustomerSpawner", "_spawn_next_customer() IGNORED: Spawn already in progress.")
		return
		
	if current_customer:
		LogManager.debug("CustomerSpawner", "_spawn_next_customer() ABORTED: customer already present!")
		return

	LogManager.debug("CustomerSpawner", "_spawn_next_customer() CALLED. is_paused=%s, current_customer=%s, _is_spawning=%s" % [is_paused, current_customer != null, _is_spawning])
	if is_paused:
		LogManager.debug("CustomerSpawner", "Aborting spawn: store is paused.")
		return

	# Closing time check
	if StoryManager.is_past_closing_time():
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

func _on_customer_dismissed(customer: Customer) -> void:
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
	if StoryManager.is_past_closing_time():
		delay = 1.0 # Short delay for Mayari arrival

	await get_tree().create_timer(delay).timeout
	_is_spawning = false
	_spawn_next_customer()

func _process(delta: float) -> void:
	session.update_watchdog(delta)

func _on_customer_arrived(customer: Customer) -> void:
	EventBus.customer_arrived.emit(customer)
	session.on_customer_arrived(customer)

func _on_customer_finished(customer: Customer) -> void:
	session.on_item_delivered(customer, true)

func _on_customer_clicked(customer: Customer) -> void:
	session.on_customer_clicked(customer, _is_nokia_open)

func _on_guest_clicked(_guest: Customer) -> void:
	if is_instance_valid(current_customer):
		session.on_customer_clicked(current_customer, _is_nokia_open)

func _on_dialogic_signal(argument: String) -> void:
	session.on_dialogic_signal(argument)

func _on_customer_partial_satisfaction(customer: Customer) -> void:
	session.on_item_delivered(customer, false)

func _update_item_names(customer: Customer) -> void:
	session.update_item_names(customer)

func start_dialogue(timeline, customer: Customer, phase: TransactionSession.Phase = TransactionSession.Phase.NONE, label: String = "") -> void:
	session.start_dialogue(timeline, customer, phase, label)

func _on_dialogue_ended() -> void:
	session.on_dialogue_ended()




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
	EventBus.day_ended.emit(StoryManager.day)

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
	session._greeting_interrupted = false # Also reset: interruption state is irrelevant after a reload
	
	if data.has("current_customer"):
		var ctx_data = data["current_customer"]
		var ctx = TransactionContext.from_dict(ctx_data)
		if ctx and ctx.customer_data:
			_pending_restore_transaction = ctx
			LogManager.info("CustomerSpawner", "Queuing restored customer for fresh walk-in: %s" % ctx.customer_data.character_name)
			
			# Delay slightly to ensure self is ready, then trigger spawn
			get_tree().create_timer(1.0).timeout.connect(_spawn_next_customer)
			return

func reset_state() -> void:
	_pending_restore_transaction = null
	current_customer = null
	guest_customer = null
	_is_spawning = false
	_dialogue_phase = DialoguePhase.NONE
	session._greeting_interrupted = false
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
