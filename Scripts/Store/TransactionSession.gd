class_name TransactionSession
extends RefCounted

## Deep module orchestrating active customer encounter dialogue, item evaluation,
## Dialogic variable synchronization, and state transitions.

enum Phase {
	NONE,
	GREETING,
	TALK,
	SATISFIED,
	SOCIAL_VISIT,
	WRONG_ITEM,
	REPAYMENT
}

var phase: Phase = Phase.NONE
var current_customer: Customer = null
var guest_customer: Customer = null

var _pending_dismiss: bool = false
var _is_partial_success: bool = false
var _greeting_interrupted: bool = false
var _current_timeline_path: String = ""
var _last_dialogue_frame: int = -1
var _watchdog_elapsed: float = 0.0
const WATCHDOG_TIMEOUT_SEC: float = 0.5

var generic_char_res: Resource = preload("res://Dialogue/Timelines/Customer.dch")
var _tree_owner: Node = null

func setup(owner_node: Node) -> void:
	_tree_owner = owner_node

func bind_encounter(primary: Customer, guest: Customer = null) -> void:
	current_customer = primary
	guest_customer = guest
	phase = Phase.NONE
	_pending_dismiss = false
	_is_partial_success = false
	_greeting_interrupted = false
	_current_timeline_path = ""
	_watchdog_elapsed = 0.0

func unbind_encounter() -> void:
	current_customer = null
	guest_customer = null
	phase = Phase.NONE
	_pending_dismiss = false
	_is_partial_success = false
	_greeting_interrupted = false
	_current_timeline_path = ""

func on_customer_arrived(customer: Customer) -> void:
	update_item_names(customer)
	if generic_char_res:
		generic_char_res.display_name = InventoryManager.current_character_name

func on_customer_clicked(customer: Customer, is_nokia_open: bool) -> void:
	if Dialogic.current_timeline != null or customer.transaction_context == null:
		return
	if not customer.is_waiting:
		return

	# Repayment preamble check
	if customer.transaction_context.is_repaying:
		customer.transaction_context.is_repaying = false
		phase = Phase.REPAYMENT
		var repay_timeline = customer.transaction_context.timeline
		var timeline_path = repay_timeline.resource_path if repay_timeline is Resource else repay_timeline
		if StoryManager.is_label_in_timeline(timeline_path, "Repayment"):
			start_dialogue(repay_timeline, customer, Phase.REPAYMENT, "Repayment")
		else:
			start_dialogue("res://Dialogue/Timelines/Generic/Repayment.dtl", customer, Phase.REPAYMENT)
		return

	if phase != Phase.NONE and phase != Phase.SATISFIED:
		return

	if customer.has_method("_is_resolving") and customer._is_resolving:
		return

	if MarioManager.is_restocking_active or is_nokia_open:
		return

	var timeline = customer.transaction_context.timeline
	var label: String = ""

	# Danilo visit override fallback
	if customer.customer_data.get_clean_id() == "danilo":
		var path = customer.customer_data.resource_path
		var chapter = CharacterProgressionManager.get_chapter(path)
		if chapter < customer.customer_data.max_story_chapters - 1:
			if customer.transaction_context.transaction_type == TransactionContext.Type.PURCHASE:
				customer.transaction_context.transaction_type = TransactionContext.Type.VISIT

	if customer.transaction_context.transaction_type == TransactionContext.Type.VISIT:
		phase = Phase.SOCIAL_VISIT
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
			phase = Phase.GREETING
			_greeting_interrupted = false
		else:
			label = "Talk"
			phase = Phase.TALK

	start_dialogue(timeline, customer, phase, label)

## Resolves an item placed on the transaction tray.
## Validates the customer state, checks the item against requirements,
## triggers audio/visual feedback, updates inventory/progression,
## and transitions dialogue state accordingly.
func process_item_placed(item: DraggableItem, fallback_pos: Vector3 = Vector3.ZERO) -> bool:
	if item == null or item.item_data == null:
		return false

	EventBus.transaction_started.emit(item.item_data)

	if not is_instance_valid(current_customer) or not current_customer.is_waiting:
		LogManager.debug("TransactionSession", "No customer waiting, dropping item")
		item.show_visuals()
		item.return_to_start()
		return false

	var customer: Customer = current_customer
	var context: TransactionContext = customer.transaction_context
	var is_correct: bool = customer.check_item(item.item_data)
	var c_path: String = customer.customer_data.resource_path if customer.customer_data else ""

	if is_correct:
		EventBus.request_camera_shake.emit(0.1, 0.15) # Small physical bump for selling

		# Spawn glimmer at the customer's visual center (SpeechMarker) or fallback position
		var glimmer_pos: Vector3 = fallback_pos + Vector3(0, 0.2, 0)
		var marker: Node3D = customer.get_node_or_null("SpeechMarker") as Node3D
		if marker:
			glimmer_pos = marker.global_position

		VisualEffectManager.spawn_transaction_glimmer(glimmer_pos)
		var wants_debt: bool = context.wants_debt if context else false
		EventBus.transaction_completed.emit(item.item_data, true, wants_debt, c_path)

		if not item.is_transient:
			InventoryManager.take_item(item.item_data)
		item.notify_placed()
		item.play_give_animation()

		var is_whole_order_done: bool = context.desired_items.is_empty() if context else true
		on_item_delivered(customer, is_whole_order_done)
		return true
	else:
		# If given an item before greeting, trigger greeting instead of WrongItem.
		if not customer.has_been_greeted:
			LogManager.debug("TransactionSession", "Item given before greeting. Triggering greeting instead of WrongItem.")
			on_wrong_item_given(customer)
		else:
			var gm: GameManager = null
			if is_instance_valid(_tree_owner) and _tree_owner.is_inside_tree():
				gm = _tree_owner.get_tree().get_first_node_in_group("game_manager") as GameManager

			if gm and gm.tutorial and gm.tutorial.should_suppress_wrong_item_feedback(context):
				LogManager.debug("TransactionSession", "Suppressing WrongItem feedback during guided tutorial task.")
			else:
				var wants_debt: bool = context.wants_debt if context else false
				EventBus.transaction_completed.emit(item.item_data, false, wants_debt, c_path)
				on_wrong_item_given(customer)

				# Keep item in hand so it doesn't just vanish or jump
				if DragManager and item.item_data and item.item_data.texture:
					DragManager.call_deferred("start_drag", item, item.item_data.texture)
					return false

		# Return item to its shelf slot if not consumed or kept in hand
		if item:
			item.show_visuals()
			item.return_to_start()
		return false

func on_item_delivered(customer: Customer, is_whole_order_done: bool) -> void:
	if Dialogic.current_timeline != null:
		var active_path = Dialogic.current_timeline.resource_path
		var target_path = customer.transaction_context.timeline.resource_path if customer.transaction_context.timeline is Resource else customer.transaction_context.timeline
		if active_path == target_path:
			var jump_label := "Satisfy" if is_whole_order_done else "Partial"
			if StoryManager.is_label_in_timeline(target_path, jump_label):
				Dialogic.Jump.jump_to_label(jump_label)
				phase = Phase.SATISFIED if is_whole_order_done else Phase.TALK
				return

	update_item_names(customer)
	var next_phase = Phase.SATISFIED if is_whole_order_done else Phase.TALK
	var target_label = "Satisfy" if is_whole_order_done else "Partial"
	start_dialogue(customer.transaction_context.timeline, customer, next_phase, target_label)

func on_wrong_item_given(customer: Customer) -> void:
	if not customer.has_been_greeted:
		on_customer_clicked(customer, false)
	else:
		start_dialogue(customer.transaction_context.timeline, customer, Phase.WRONG_ITEM, "WrongItem")

func start_dialogue(timeline, customer: Customer, in_phase: Phase = Phase.NONE, label: String = "") -> void:
	if timeline == null or (timeline is String and timeline.is_empty()):
		return
	if not is_instance_valid(customer) or not customer.is_waiting:
		return

	if Engine.get_frames_drawn() == _last_dialogue_frame:
		return
	_last_dialogue_frame = Engine.get_frames_drawn()

	phase = in_phase
	_current_timeline_path = timeline.resource_path if timeline is Resource else timeline

	if in_phase in [Phase.TALK, Phase.SATISFIED]:
		if is_instance_valid(customer) and customer.transaction_context:
			EventBus.customer_order_updated.emit(customer.customer_data.character_name, customer.transaction_context.desired_items, customer.transaction_context.is_riddle)

	var final_label = label
	if final_label != "":
		var exists = StoryManager.is_label_in_timeline(_current_timeline_path, final_label)
		if not exists:
			if final_label == "Partial":
				final_label = "Satisfy"
			elif final_label == "Satisfy":
				final_label = ""

	if Dialogic.current_timeline != null:
		if Dialogic.current_timeline.resource_path != _current_timeline_path:
			Dialogic.end_timeline()
		elif final_label != "":
			Dialogic.Jump.jump_to_label(final_label)
			return

	Dialogic.Styles.load_style("FollowBubble")
	var layout = Dialogic.start(timeline, final_label)
	if layout == null:
		phase = Phase.NONE
		_current_timeline_path = ""
		return

	_register_characters_to_layout(layout, customer)

func _register_characters_to_layout(layout: Node, customer: Customer) -> void:
	if not (layout and layout.has_method("register_character")):
		return

	var marker: Node3D = customer.get_node_or_null("SpeechMarker") as Node3D
	if marker:
		if customer.customer_data:
			_register_marker_character(layout, customer.customer_data.dialogic_character, marker)
		_register_marker_character(layout, generic_char_res, marker)

	if is_instance_valid(guest_customer):
		var guest_marker: Node3D = guest_customer.get_node_or_null("SpeechMarker") as Node3D
		if guest_marker and guest_customer.customer_data:
			_register_marker_character(layout, guest_customer.customer_data.dialogic_character, guest_marker)

func _register_marker_character(layout: Node, char_res: Resource, marker: Node3D) -> void:
	if not char_res or not marker:
		return
	var dch_name: String = char_res.resource_path.get_file().get_basename()
	var canonical = DialogicResourceUtil.get_character_resource(dch_name)
	if canonical:
		layout.register_character(canonical, marker)

func on_dialogic_signal(argument: String) -> void:
	if argument == "refuse_service":
		_pending_dismiss = true
		var delivered = Dialogic.VAR.get_variable("Transaction_DeliveredCount")
		if delivered != null and delivered > 0:
			_is_partial_success = true
			if StoryManager.is_label_in_timeline(_current_timeline_path, "PartialDismiss"):
				Dialogic.Jump.jump_to_label("PartialDismiss")
			elif StoryManager.is_label_in_timeline(_current_timeline_path, "Satisfy"):
				Dialogic.Jump.jump_to_label("Satisfy")
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
			current_customer.pulse_color(Color("#0f6e2f"))
	elif argument == "setup_debt":
		if is_instance_valid(current_customer) and current_customer.transaction_context:
			current_customer.transaction_context.wants_debt = true
			Dialogic.VAR.set_variable("Transaction_WantsDebt", 1.0)
	elif argument == "setup_repay_full":
		if is_instance_valid(current_customer) and current_customer.transaction_context:
			var path = current_customer.customer_data.resource_path
			var debt = StoryManager.customer_debts.get(path, 0.0)
			current_customer.transaction_context.is_repaying = true
			current_customer.transaction_context.repayment_amount = debt
			Dialogic.VAR.set_variable("Transaction_IsRepaying", 1.0)
			Dialogic.VAR.set_variable("Transaction_RepaymentAmount", debt)
	elif argument == "setup_repay_half":
		if is_instance_valid(current_customer) and current_customer.transaction_context:
			var path = current_customer.customer_data.resource_path
			var debt = StoryManager.customer_debts.get(path, 0.0)
			var half = floor(debt / 2.0)
			current_customer.transaction_context.is_repaying = true
			current_customer.transaction_context.repayment_amount = half
			Dialogic.VAR.set_variable("Transaction_IsRepaying", 1.0)
			Dialogic.VAR.set_variable("Transaction_RepaymentAmount", half)
	elif argument == "spawn_guest":
		if is_instance_valid(guest_customer) and guest_customer.has_method("trigger_arrival"):
			guest_customer.trigger_arrival()

func on_dialogue_ended() -> void:
	if SaveManager.is_quitting:
		phase = Phase.NONE
		_current_timeline_path = ""
		_pending_dismiss = false
		return

	if Dialogic.current_timeline != null and "UncleMario.dtl" in Dialogic.current_timeline.resource_path:
		if phase == Phase.GREETING:
			_greeting_interrupted = true
		phase = Phase.NONE
		_current_timeline_path = ""
		return

	if MarioManager.is_restocking_active and Dialogic.current_timeline == null:
		return

	if Dialogic.current_timeline == null and _greeting_interrupted:
		_greeting_interrupted = false
		if is_instance_valid(current_customer) and current_customer.is_waiting and is_instance_valid(_tree_owner):
			_tree_owner.get_tree().process_frame.connect(func():
				if is_instance_valid(current_customer) and current_customer.is_waiting:
					var timeline = current_customer.transaction_context.timeline
					start_dialogue(timeline, current_customer, Phase.GREETING, "Greeting")
			, Node.CONNECT_ONE_SHOT)
		return

	if phase == Phase.REPAYMENT:
		phase = Phase.NONE
		if is_instance_valid(current_customer) and current_customer.is_waiting:
			on_customer_clicked(current_customer, false)
		return

	var ending_phase := phase
	phase = Phase.NONE
	_current_timeline_path = ""

	if _pending_dismiss:
		_pending_dismiss = false
		if is_instance_valid(current_customer):
			_dismiss_guest_if_present()
			var delivered = Dialogic.VAR.get_variable("Transaction_DeliveredCount")
			if _is_partial_success or (delivered != null and delivered > 0):
				current_customer.satisfy()
			else:
				current_customer.dismiss()
			_is_partial_success = false
		return

	_resolve_phase_transition(ending_phase)

func _resolve_phase_transition(ending_phase: Phase) -> void:
	match ending_phase:
		Phase.SOCIAL_VISIT:
			_dismiss_guest_if_present()
			if is_instance_valid(current_customer) and current_customer.is_waiting:
				current_customer.has_been_greeted = true
				current_customer.dismiss()

		Phase.SATISFIED:
			_dismiss_guest_if_present()
			if is_instance_valid(current_customer):
				current_customer.satisfy()

		Phase.GREETING:
			if is_instance_valid(current_customer) and current_customer.transaction_context:
				var t = current_customer.transaction_context
				if t.transaction_type == TransactionContext.Type.STORY and t.is_visit_story:
					current_customer.satisfy()
					return
			if is_instance_valid(current_customer):
				current_customer.has_been_greeted = true
				if current_customer.transaction_context:
					EventBus.customer_order_updated.emit(InventoryManager.current_character_name, current_customer.transaction_context.desired_items, current_customer.transaction_context.is_riddle)

		Phase.WRONG_ITEM:
			pass

func update_watchdog(delta: float) -> void:
	if phase != Phase.NONE and phase != Phase.SATISFIED:
		if Dialogic.current_timeline == null:
			_watchdog_elapsed += delta
			if _watchdog_elapsed >= WATCHDOG_TIMEOUT_SEC:
				phase = Phase.NONE
				_watchdog_elapsed = 0.0
		else:
			_watchdog_elapsed = 0.0
	else:
		_watchdog_elapsed = 0.0

func update_item_names(customer: Customer) -> void:
	if not customer or not customer.transaction_context:
		return
	var item_names: Array[String] = []
	var ctx = customer.transaction_context
	for item in ctx.desired_items:
		if ctx.is_riddle and item == ctx.riddle_item:
			continue
		item_names.append(item.item_name)
	
	var data = customer.customer_data
	InventoryManager.current_character_name = data.character_name if data.character_name != "" else data.get_clean_id()
	InventoryManager.current_item_name = DialogicBridge.join_names(item_names)
	
	Dialogic.VAR.set_variable("Transaction_CustomerName", InventoryManager.current_character_name)
	if not item_names.is_empty():
		Dialogic.VAR.set_variable("Transaction_ItemWants", InventoryManager.current_item_name)
	
	var total_cnt = ctx.original_count
	var remain_cnt = ctx.desired_items.size()
	Dialogic.VAR.set_variable("Transaction_DeliveredCount", total_cnt - remain_cnt)
	Dialogic.VAR.set_variable("Transaction_RemainingCount", remain_cnt)

	if generic_char_res:
		generic_char_res.display_name = InventoryManager.current_character_name

func _dismiss_guest_if_present() -> void:
	if is_instance_valid(guest_customer):
		var g = guest_customer
		guest_customer = null
		g.create_tween().tween_callback(g.dismiss).set_delay(0.5)

