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
	SMALLTALK,
	WRONG_ITEM,
	REPAYMENT,
	MOSQUITO_PREAMBLE
}

var phase: Phase = Phase.NONE
var current_customer: Customer = null
var guest_customer: Customer = null

var _pending_dismiss: bool = false
var _is_partial_success: bool = false
var _greeting_interrupted: bool = false
var _mosquito_choice: String = ""
var _switching_customer_dialogue: bool = false
var _switch_session_id: int = 0
var _current_timeline_path: String = ""
var _last_dialogue_frame: int = -1
var _watchdog_elapsed: float = 0.0
const WATCHDOG_TIMEOUT_SEC: float = 0.5
const PRICE_REFUSED_TIMELINE_PATH := "res://Dialogue/Timelines/price_refused.dtl"

const PRICE_REFUSAL_LINES: Array[String] = [
	"₱%d for %s?! Ang mahal naman! Sa kabila na lang ako.",
	"Wait, ₱%d for %s? That's way past my budget. Never mind!",
	"Grabe naman ang patong sa %s... I'll just pass today.",
	"₱%d?! My wallet can't take that right now. Maybe next time.",
	"Whoa, %s is ₱%d now? Too steep for me — I'll head out.",
]

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
	_switching_customer_dialogue = false
	_switch_session_id += 1
	_current_timeline_path = ""
	_watchdog_elapsed = 0.0

func unbind_encounter() -> void:
	current_customer = null
	guest_customer = null
	phase = Phase.NONE
	_pending_dismiss = false
	_is_partial_success = false
	_greeting_interrupted = false
	_switching_customer_dialogue = false
	_switch_session_id += 1
	_current_timeline_path = ""

func on_customer_arrived(customer: Customer) -> void:
	update_item_names(customer)
	if generic_char_res:
		generic_char_res.display_name = InventoryManager.current_character_name


static func compute_overpriced_refusal_chance(item_data: ItemData, customer_data: CustomerData = null) -> float:
	if item_data == null:
		return 0.0
	var tolerance: int = 0
	if is_instance_valid(StoreEventManager):
		tolerance = StoreEventManager.get_item_tolerance_offset(item_data)
	tolerance += StoryManager.get_mayari_tolerance_offset()
	if customer_data != null and is_instance_valid(CharacterProgressionManager):
		tolerance += CharacterProgressionManager.get_reputation_tolerance_bonus(customer_data, item_data)
	var effective_step: int = item_data.current_step - tolerance
	if effective_step < 2:
		return 0.0
	var base_chance: float = 0.0
	match effective_step:
		2: base_chance = 0.20
		3: base_chance = 0.45
		4: base_chance = 0.72
		_: base_chance = 0.92
	var relief: float = StoryManager.get_storefront_price_relief()
	var card_mod: float = 0.0
	if StoryManager.has_mayari_card(MayariCardRegistry.CARD_RESTLESS_CROWD):
		card_mod += 0.20
	if StoryManager.has_mayari_card(MayariCardRegistry.CARD_UNRUSHED_HOUR):
		card_mod -= 0.20
	var final_chance: float = base_chance - relief + card_mod
	return maxf(0.05, final_chance) if effective_step >= 3 else maxf(0.0, final_chance)


func _matches_desired_preview(context: TransactionContext, offered: ItemData) -> bool:
	if context == null or offered == null:
		return false
	for d in context.desired_items:
		if d == null:
			continue
		if d == offered or d.get_clean_id() == offered.get_clean_id() or d.item_name == offered.item_name:
			return true
	return false


func _should_refuse_for_high_price(customer: Customer, context: TransactionContext, offered: ItemData) -> bool:
	if not is_instance_valid(customer) or context == null or offered == null:
		return false
	if context.transaction_type != TransactionContext.Type.PURCHASE:
		return false
	if context.wants_debt or context.is_guided_tutorial:
		return false
	if is_instance_valid(_tree_owner) and _tree_owner.is_inside_tree():
		var gm := _tree_owner.get_tree().get_first_node_in_group("game_manager") as GameManager
		if gm and gm.tutorial and gm.tutorial.is_guided_timeline_active():
			return false
	if not _matches_desired_preview(context, offered):
		return false
	var chance: float = compute_overpriced_refusal_chance(offered, customer.customer_data)
	return chance > 0.0 and randf() < chance


func _trigger_price_refusal(
	customer: Customer,
	item: DraggableItem,
	needs_switch: bool,
	prev_customer: Customer,
	prev_phase: Phase,
	prev_pending_dismiss: bool,
	prev_partial_success: bool
) -> void:
	var item_data: ItemData = item.item_data
	var price: float = item_data.get_final_price()
	var price_int: int = int(roundf(price))
	var char_name: String = customer.customer_data.character_name if (customer.customer_data and customer.customer_data.character_name != "") else "Neighbor"

	# Return rejected item cleanly to shelf (no stock lost, no money earned)
	item.show_visuals()
	item.return_to_start()

	# World & UI Juice (let the refusal dialogue & -Rep popup carry the message cleanly)
	EventBus.request_camera_shake.emit(0.18, 0.22)
	AudioManager.play_sfx("error")
	customer.pulse_color(Color(1.0, 0.26, 0.22, 1.0))
	StoryManager.record_missed_item(item_data)
	if customer.customer_data and is_instance_valid(CharacterProgressionManager):
		CharacterProgressionManager.add_reputation(customer.customer_data.resource_path, -12, "price_refusal")

	# Pick a natural refusal line and play walkout dialogue on the customer
	var tmpl: String = PRICE_REFUSAL_LINES[randi() % PRICE_REFUSAL_LINES.size()]
	var line: String = ""
	if tmpl.find("₱%d") != -1 and tmpl.find("%s") != -1:
		if tmpl.find("₱%d") < tmpl.find("%s"):
			line = tmpl % [price_int, item_data.item_name]
		else:
			line = tmpl % [item_data.item_name, price_int]
	elif tmpl.find("%s") != -1:
		line = tmpl % item_data.item_name
	else:
		line = tmpl % price_int

	if generic_char_res:
		generic_char_res.display_name = char_name
	Dialogic.VAR.set_variable("Global_PriceRefusalLine", line)

	if needs_switch and is_instance_valid(prev_customer):
		_finish_dialogue_for_customer(prev_customer, prev_phase, prev_pending_dismiss, prev_partial_success)
		_switching_customer_dialogue = false

	current_customer = customer
	_pending_dismiss = true
	_is_partial_success = false
	customer.dialogue_phase = Phase.WRONG_ITEM
	if ResourceLoader.exists(PRICE_REFUSED_TIMELINE_PATH):
		start_dialogue(PRICE_REFUSED_TIMELINE_PATH, customer, Phase.WRONG_ITEM, "")
	else:
		_finish_dialogue_for_customer(customer, Phase.WRONG_ITEM, true, false)

func on_customer_clicked(customer: Customer, is_nokia_open: bool) -> void:
	if _switching_customer_dialogue or Dialogic.current_timeline != null or customer == null or customer.transaction_context == null:
		return
	if not customer.is_waiting or customer._is_resolving or customer.is_lingering_visitor:
		return

	if phase != Phase.NONE and phase != Phase.SATISFIED:
		return

	if MarioManager.is_restocking_active or is_nokia_open:
		return

	# Switch active dialogue focus to the clicked customer and sync their Dialogic vars
	current_customer = customer
	_sync_customer_dialogic_vars(customer)

	# Returning lingering visitor smalltalk
	if customer.is_returning_for_smalltalk:
		Dialogic.VAR.set_variable("Transaction_VisitVar", randf() * 100.0)
		var st_timeline = customer.transaction_context.timeline
		var st_path = st_timeline.resource_path if st_timeline is Resource else st_timeline
		phase = Phase.SMALLTALK
		customer.dialogue_phase = Phase.SMALLTALK
		if StoryManager.is_label_in_timeline(st_path, "Smalltalk"):
			start_dialogue(st_timeline, customer, Phase.SMALLTALK, "Smalltalk")
		else:
			start_dialogue("res://Dialogue/Timelines/Generic/Smalltalk.dtl", customer, Phase.SMALLTALK, "Smalltalk")
		return

	# 4PM+ Mosquito Swarm pre-greeting remark (once per day)
	if is_instance_valid(StoryManager) and StoryManager.mosquito_swarm_pending \
			and not customer.has_been_greeted \
			and not customer.is_returning_for_smalltalk \
			and customer.customer_data and not customer.customer_data.is_collector() \
			and not customer.transaction_context.is_nightly_collection \
			and not customer.transaction_context.is_guided_tutorial:
		StoryManager.mosquito_swarm_pending = false
		_mosquito_choice = ""
		phase = Phase.MOSQUITO_PREAMBLE
		customer.dialogue_phase = Phase.MOSQUITO_PREAMBLE
		start_dialogue("res://Dialogue/Timelines/Generic/MosquitoSwarm.dtl", customer, Phase.MOSQUITO_PREAMBLE)
		return

	# Repayment preamble check
	if customer.transaction_context.is_repaying and customer.transaction_context.repayment_amount > 0.0:
		customer.transaction_context.is_repaying = false
		phase = Phase.REPAYMENT
		customer.dialogue_phase = Phase.REPAYMENT
		var repay_timeline = customer.transaction_context.timeline
		var timeline_path = repay_timeline.resource_path if repay_timeline is Resource else repay_timeline
		if StoryManager.is_label_in_timeline(timeline_path, "Repayment"):
			start_dialogue(repay_timeline, customer, Phase.REPAYMENT, "Repayment")
		else:
			start_dialogue("res://Dialogue/Timelines/Generic/Repayment.dtl", customer, Phase.REPAYMENT)
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
		if not customer.has_been_greeted or customer.greeting_interrupted or _greeting_interrupted:
			var timeline_path = timeline.resource_path if timeline is Resource else timeline
			if Dialogic.VAR.get_variable("Global_RumorActive") and StoryManager.is_label_in_timeline(timeline_path, "Rumor"):
				label = "Rumor"
			else:
				label = "Greeting"
			phase = Phase.GREETING
			customer.greeting_interrupted = false
			_greeting_interrupted = false
		else:
			label = "Talk"
			phase = Phase.TALK

	customer.dialogue_phase = phase
	start_dialogue(timeline, customer, phase, label)

func _sync_customer_dialogic_vars(customer: Customer) -> void:
	if not is_instance_valid(customer) or not customer.transaction_context or not customer.customer_data:
		return
	var char_data := customer.customer_data
	var chapter: int = CharacterProgressionManager.get_chapter(char_data.resource_path)
	var branch_value: float = CharacterProgressionManager.get_branch(char_data.resource_path)
	var current_arc: float = float(char_data.get_arc_index(chapter) + 1)
	DialogicBridge.sync_transaction(customer.transaction_context, chapter, branch_value, current_arc)
	update_item_names(customer)

## Resolves an item offered directly to a specific customer.
## Validates the customer state, checks the item against requirements,
## triggers audio/visual feedback, updates inventory/progression,
## and transitions dialogue state accordingly.
func process_item_placed(item: DraggableItem, fallback_pos: Vector3 = Vector3.ZERO, target_customer: Customer = null) -> bool:
	if item == null or item.item_data == null:
		return false

	EventBus.transaction_started.emit(item.item_data)

	var customer: Customer = target_customer if is_instance_valid(target_customer) else current_customer
	if not is_instance_valid(customer) or not customer.is_waiting or customer.is_lingering_visitor:
		LogManager.debug("TransactionSession", "No valid waiting customer for item drop, returning item")
		item.show_visuals()
		item.return_to_start()
		return false

	# Never interrupt Uncle Mario dialogue or an in-progress cross-customer dialogue switch
	if (Dialogic.current_timeline != null and "UncleMario.dtl" in Dialogic.current_timeline.resource_path) or _switching_customer_dialogue:
		item.show_visuals()
		item.return_to_start()
		return false

	# Guard against double-drops onto a customer whose order is already finishing Satisfy dialogue
	if customer.dialogue_phase == Phase.SATISFIED or (customer == current_customer and phase == Phase.SATISFIED):
		item.show_visuals()
		item.return_to_start()
		return false

	var needs_switch: bool = (Dialogic.current_timeline != null and is_instance_valid(current_customer) and current_customer != customer)
	var prev_customer: Customer = null
	var prev_phase: Phase = Phase.NONE
	var prev_pending_dismiss: bool = false
	var prev_partial_success: bool = false

	if needs_switch:
		prev_customer = current_customer
		prev_phase = phase
		prev_pending_dismiss = _pending_dismiss
		prev_partial_success = _is_partial_success
		_switching_customer_dialogue = true
		phase = Phase.NONE
		_current_timeline_path = ""
		_pending_dismiss = false
		_is_partial_success = false
	else:
		# Bind active focus to the customer receiving the item
		current_customer = customer
		_sync_customer_dialogic_vars(customer)

	var context: TransactionContext = customer.transaction_context
	var c_path: String = customer.customer_data.resource_path if customer.customer_data else ""

	# Check overpriced refusal BEFORE fulfilling the item (regular cash purchases only; never blocks Story/Tutorial/Utang)
	if _should_refuse_for_high_price(customer, context, item.item_data):
		_trigger_price_refusal(customer, item, needs_switch, prev_customer, prev_phase, prev_pending_dismiss, prev_partial_success)
		return false

	var is_correct: bool = customer.check_item(item.item_data)

	if is_correct:
		EventBus.request_camera_shake.emit(0.1, 0.15) # Small physical bump for selling

		# Spawn glimmer at the customer's visual center (SpeechMarker) or fallback position
		var glimmer_pos: Vector3 = fallback_pos + Vector3(0, 0.2, 0)
		var marker: Node3D = customer.get_node_or_null("SpeechMarker") as Node3D
		if marker:
			glimmer_pos = marker.global_position

		VisualEffectManager.spawn_transaction_glimmer(glimmer_pos)
		var wants_debt: bool = context.wants_debt if context else false
		if item.item_data.current_step < 0 and not wants_debt:
			if context:
				context.tip_active = true
			Dialogic.VAR.set_variable("Global_TipActive", true)
		EventBus.transaction_completed.emit(item.item_data, true, wants_debt, c_path)

		if not item.is_transient:
			InventoryManager.take_item(item.item_data)
		item.notify_placed()
		item.play_give_animation()

		var gm_guided: GameManager = null
		if is_instance_valid(_tree_owner) and _tree_owner.is_inside_tree():
			gm_guided = _tree_owner.get_tree().get_first_node_in_group("game_manager") as GameManager
		var is_guided: bool = (context != null and context.is_guided_tutorial) or (gm_guided != null and gm_guided.tutorial != null and gm_guided.tutorial.is_guided_timeline_active())
		var is_whole_order_done: bool = context.desired_items.is_empty() if context else true
		if is_whole_order_done:
			StoryManager.award_customer_completion_xp(customer)
		if needs_switch:
			if not is_guided and context:
				EventBus.customer_order_updated.emit(customer.get_order_hud_key(), context.desired_items, context.is_riddle)
			_finish_switch_and_start(prev_customer, prev_phase, prev_pending_dismiss, prev_partial_success, customer, true, is_whole_order_done, is_guided)
		elif not is_guided:
			on_item_delivered(customer, is_whole_order_done)
		return true
	else:
		var trigger_wrong_dialogue := false
		# If given an item before greeting, trigger greeting instead of WrongItem.
		if not customer.has_been_greeted:
			LogManager.debug("TransactionSession", "Item given before greeting. Triggering greeting instead of WrongItem.")
			trigger_wrong_dialogue = true
		else:
			var gm: GameManager = null
			if is_instance_valid(_tree_owner) and _tree_owner.is_inside_tree():
				gm = _tree_owner.get_tree().get_first_node_in_group("game_manager") as GameManager

			if gm and gm.tutorial and gm.tutorial.should_suppress_wrong_item_feedback(context):
				LogManager.debug("TransactionSession", "Suppressing WrongItem feedback during guided tutorial task.")
			else:
				var wants_debt: bool = context.wants_debt if context else false
				EventBus.transaction_completed.emit(item.item_data, false, wants_debt, c_path)
				trigger_wrong_dialogue = true

		# Return rejected item straight back to its shelf slot / container / bag instead of keeping it in hand
		if item:
			item.show_visuals()
			item.return_to_start()

		if needs_switch:
			_finish_switch_and_start(prev_customer, prev_phase, prev_pending_dismiss, prev_partial_success, customer, false, false, not trigger_wrong_dialogue)
		elif trigger_wrong_dialogue:
			on_wrong_item_given(customer)
		return false

func _finish_switch_and_start(
	prev_customer: Customer,
	prev_phase: Phase,
	prev_pending_dismiss: bool,
	prev_partial_success: bool,
	next_customer: Customer,
	was_correct: bool,
	is_whole_order_done: bool,
	skip_next_dialogue: bool
) -> void:
	_switch_session_id += 1
	var my_switch_id := _switch_session_id
	if Dialogic.current_timeline != null:
		await Dialogic.end_timeline(true)
	if my_switch_id != _switch_session_id:
		return

	_switching_customer_dialogue = false
	_last_dialogue_frame = -1
	_finish_dialogue_for_customer(prev_customer, prev_phase, prev_pending_dismiss, prev_partial_success)

	if skip_next_dialogue or not is_instance_valid(next_customer) or not next_customer.is_waiting or next_customer._is_resolving:
		return

	current_customer = next_customer
	_sync_customer_dialogic_vars(next_customer)
	if was_correct:
		on_item_delivered(next_customer, is_whole_order_done)
	else:
		on_wrong_item_given(next_customer)

func on_item_delivered(customer: Customer, is_whole_order_done: bool) -> void:
	if _switching_customer_dialogue:
		return
	update_item_names(customer)
	if Dialogic.current_timeline != null:
		var active_path = Dialogic.current_timeline.resource_path
		var target_path = customer.transaction_context.timeline.resource_path if customer.transaction_context.timeline is Resource else customer.transaction_context.timeline
		if active_path == target_path:
			var jump_label := "Satisfy" if is_whole_order_done else "Partial"
			if StoryManager.is_label_in_timeline(target_path, jump_label):
				if is_instance_valid(customer) and customer.transaction_context:
					EventBus.customer_order_updated.emit(customer.get_order_hud_key(), customer.transaction_context.desired_items, customer.transaction_context.is_riddle)
				Dialogic.Jump.jump_to_label(jump_label)
				phase = Phase.SATISFIED if is_whole_order_done else Phase.TALK
				if is_instance_valid(customer):
					customer.dialogue_phase = phase
				return

	var next_phase = Phase.SATISFIED if is_whole_order_done else Phase.TALK
	var target_label = "Satisfy" if is_whole_order_done else "Partial"
	start_dialogue(customer.transaction_context.timeline, customer, next_phase, target_label)

func on_wrong_item_given(customer: Customer) -> void:
	if _switching_customer_dialogue:
		return
	if not customer.has_been_greeted:
		on_customer_clicked(customer, false)
	else:
		start_dialogue(customer.transaction_context.timeline, customer, Phase.WRONG_ITEM, "WrongItem")

func start_dialogue(timeline, customer: Customer, in_phase: Phase = Phase.NONE, label: String = "") -> void:
	if _switching_customer_dialogue:
		return
	if timeline == null or (timeline is String and timeline.is_empty()):
		return
	if not is_instance_valid(customer) or not customer.is_waiting:
		return

	if Engine.get_frames_drawn() == _last_dialogue_frame:
		return
	_last_dialogue_frame = Engine.get_frames_drawn()

	phase = in_phase
	customer.dialogue_phase = in_phase
	_current_timeline_path = timeline.resource_path if timeline is Resource else timeline

	if in_phase in [Phase.TALK, Phase.SATISFIED]:
		if is_instance_valid(customer) and customer.transaction_context:
			EventBus.customer_order_updated.emit(customer.get_order_hud_key(), customer.transaction_context.desired_items, customer.transaction_context.is_riddle)

	var final_label = label
	if final_label != "":
		var exists = StoryManager.is_label_in_timeline(_current_timeline_path, final_label)
		if not exists:
			if final_label == "Partial":
				# Never fall back Partial -> Satisfy, or multi-item customers will dismiss early!
				phase = Phase.NONE
				_current_timeline_path = ""
				return
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
	elif argument == "event_announced":
		if is_instance_valid(StoreEventManager):
			StoreEventManager.mark_event_announced()
	elif argument == "mosquito_choice_swat":
		_mosquito_choice = "swat"
	elif argument == "mosquito_choice_sorry":
		_mosquito_choice = "sorry"
	elif argument.begins_with("rep:"):
		# Dialogic choice reputation modifier: "rep:+15", "rep:-10", or "rep:LoloPilo:+15"
		var payload := argument.substr(4).strip_edges()
		var target_path := ""
		var delta_str := payload
		if payload.find(":") != -1:
			var parts := payload.split(":", false, 1)
			var c_data := StoryManager._get_character_data(parts[0].strip_edges())
			if c_data:
				target_path = c_data.resource_path
			delta_str = parts[1].strip_edges()
		elif is_instance_valid(current_customer) and current_customer.customer_data:
			target_path = current_customer.customer_data.resource_path
		if target_path != "" and delta_str.is_valid_int():
			CharacterProgressionManager.add_reputation(target_path, int(delta_str), "dialogue_choice")
	elif argument.begins_with("flag:"):
		# Persistent cross-character world flag: "flag:helped_ana" or "flag:key=value"
		var fpayload := argument.substr(5).strip_edges()
		if fpayload.find("=") != -1:
			var fparts := fpayload.split("=", false, 1)
			var fval_str := fparts[1].strip_edges().to_lower()
			var fval: Variant = (false if fval_str == "false" else (true if fval_str == "true" else fparts[1].strip_edges()))
			CharacterProgressionManager.set_world_flag(fparts[0].strip_edges(), fval)
		else:
			CharacterProgressionManager.set_world_flag(fpayload, true)
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
			var debt: float = float(StoryManager.customer_debts.get(path, 0.0))
			if debt > 0.0:
				current_customer.transaction_context.is_repaying = true
				current_customer.transaction_context.repayment_amount = debt
				Dialogic.VAR.set_variable("Transaction_IsRepaying", 1.0)
				Dialogic.VAR.set_variable("Transaction_RepaymentAmount", debt)
			else:
				current_customer.transaction_context.is_repaying = false
				current_customer.transaction_context.repayment_amount = 0.0
				Dialogic.VAR.set_variable("Transaction_IsRepaying", 0.0)
				Dialogic.VAR.set_variable("Transaction_RepaymentAmount", 0.0)
	elif argument == "setup_repay_half":
		if is_instance_valid(current_customer) and current_customer.transaction_context:
			var path = current_customer.customer_data.resource_path
			var debt: float = float(StoryManager.customer_debts.get(path, 0.0))
			var half: float = floor(debt / 2.0) if debt >= 2.0 else debt
			if half > 0.0:
				current_customer.transaction_context.is_repaying = true
				current_customer.transaction_context.repayment_amount = half
				Dialogic.VAR.set_variable("Transaction_IsRepaying", 1.0)
				Dialogic.VAR.set_variable("Transaction_RepaymentAmount", half)
			else:
				current_customer.transaction_context.is_repaying = false
				current_customer.transaction_context.repayment_amount = 0.0
				Dialogic.VAR.set_variable("Transaction_IsRepaying", 0.0)
				Dialogic.VAR.set_variable("Transaction_RepaymentAmount", 0.0)
	elif argument == "spawn_guest":
		if is_instance_valid(guest_customer) and guest_customer.has_method("trigger_arrival"):
			guest_customer.trigger_arrival()

func on_dialogue_ended() -> void:
	if _switching_customer_dialogue:
		return

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
		_pending_dismiss = false
		_is_partial_success = false
		if is_instance_valid(current_customer) and current_customer.is_waiting:
			on_customer_clicked(current_customer, false)
		return

	var ending_phase := phase
	var was_pending_dismiss := _pending_dismiss
	var was_partial_success := _is_partial_success
	var target := current_customer

	phase = Phase.NONE
	_current_timeline_path = ""
	_pending_dismiss = false
	_is_partial_success = false

	_finish_dialogue_for_customer(target, ending_phase, was_pending_dismiss, was_partial_success)

func _should_intercept_mayari_summary(target: Customer) -> bool:
	return is_instance_valid(target) \
		and target.transaction_context != null \
		and target.transaction_context.is_nightly_collection \
		and not target.get_meta("mayari_summary_done", false)

func _run_mayari_day_summary_and_quip(target: Customer) -> void:
	if not is_instance_valid(target) or not is_instance_valid(_tree_owner):
		return
	target.set_meta("mayari_summary_done", true)
	target.dialogue_phase = Phase.NONE
	var gm := _tree_owner.get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm and gm.has_method("show_day_summary"):
		var res: Dictionary = await gm.show_day_summary(true)
		if not is_instance_valid(target) or not is_instance_valid(_tree_owner) or not _tree_owner.is_inside_tree():
			return
		var quip := str(res.get("quip", ""))
		if quip != "" and ResourceLoader.exists("res://Dialogue/Timelines/mayari_day_summary_quip.dtl"):
			Dialogic.VAR.set_variable("Global_DaySummaryQuip", quip)
			start_dialogue("res://Dialogue/Timelines/mayari_day_summary_quip.dtl", target, Phase.SATISFIED)
			return
	if is_instance_valid(target):
		target.satisfy()

func _finish_dialogue_for_customer(target: Customer, ending_phase: Phase, was_pending_dismiss: bool, was_partial_success: bool) -> void:
	if is_instance_valid(target) and target.transaction_context:
		if target.transaction_context.event_rumor_active and is_instance_valid(StoreEventManager):
			StoreEventManager.mark_event_announced(target.transaction_context.pending_event_id)

	if was_pending_dismiss:
		# Visit.dtl files emit [signal arg="story_success"] at the end of Greeting;
		# route SOCIAL_VISIT completions through _resolve_phase_transition_for so lingering triggers!
		if ending_phase == Phase.SOCIAL_VISIT and was_partial_success:
			_resolve_phase_transition_for(target, ending_phase)
			return
		if _should_intercept_mayari_summary(target):
			_run_mayari_day_summary_and_quip(target)
			return
		if is_instance_valid(target):
			_dismiss_guest_if_present()
			target.dialogue_phase = Phase.NONE
			var has_delivered: bool = target.transaction_context != null and not target.transaction_context.delivered_items.is_empty()
			if was_partial_success or has_delivered:
				target.satisfy()
			else:
				target.dismiss()
		return

	_resolve_phase_transition_for(target, ending_phase)

func _resolve_phase_transition_for(target: Customer, ending_phase: Phase) -> void:
	match ending_phase:
		Phase.SOCIAL_VISIT:
			_dismiss_guest_if_present()
			if _should_intercept_mayari_summary(target):
				_run_mayari_day_summary_and_quip(target)
				return
			if is_instance_valid(target) and target.is_waiting:
				target.has_been_greeted = true
				target.dialogue_phase = Phase.NONE
				if is_instance_valid(_tree_owner) and _tree_owner.has_method("handle_social_visit_finished"):
					_tree_owner.handle_social_visit_finished(target)
				else:
					target.dismiss()

		Phase.SMALLTALK:
			if is_instance_valid(target):
				StoryManager.record_daily_stat_int("smalltalks_done", 1)
				var st_xp := StoryManager.get_bench_smalltalk_xp()
				if st_xp > 0:
					StoryManager.add_player_xp(st_xp, "Tambayan Smalltalk")
				if target.customer_data and is_instance_valid(CharacterProgressionManager):
					CharacterProgressionManager.add_reputation(target.customer_data.resource_path, 7, "smalltalk")
				target.dialogue_phase = Phase.NONE
				target.leave_from_lingering()

		Phase.SATISFIED:
			_dismiss_guest_if_present()
			if _should_intercept_mayari_summary(target):
				_run_mayari_day_summary_and_quip(target)
				return
			if is_instance_valid(target):
				target.dialogue_phase = Phase.NONE
				target.satisfy()

		Phase.GREETING:
			if is_instance_valid(target) and target.transaction_context:
				var t = target.transaction_context
				if t.transaction_type == TransactionContext.Type.STORY and t.is_visit_story:
					if _should_intercept_mayari_summary(target):
						_run_mayari_day_summary_and_quip(target)
						return
					target.dialogue_phase = Phase.NONE
					target.satisfy()
					return
			if is_instance_valid(target):
				target.has_been_greeted = true
				target.dialogue_phase = Phase.NONE
				if target.transaction_context:
					EventBus.customer_order_updated.emit(target.get_order_hud_key(), target.transaction_context.desired_items, target.transaction_context.is_riddle)

		Phase.MOSQUITO_PREAMBLE:
			var choice := _mosquito_choice
			_mosquito_choice = ""
			if is_instance_valid(target):
				target.dialogue_phase = Phase.NONE
			if choice == "swat":
				var on_done: Callable
				on_done = func(mg_id: String, won: bool, _res: Dictionary):
					if mg_id != "mosquito":
						return
					if EventBus.minigame_completed.is_connected(on_done):
						EventBus.minigame_completed.disconnect(on_done)
					if not won and is_instance_valid(StoreEventManager):
						StoreEventManager.trigger_special_event("mosquito_swarm")
					if is_instance_valid(target) and target.is_waiting:
						on_customer_clicked(target, false)
				EventBus.minigame_completed.connect(on_done)
				EventBus.start_minigame.emit("mosquito", {})
			else:
				if is_instance_valid(StoreEventManager):
					StoreEventManager.trigger_special_event("mosquito_swarm")
				if is_instance_valid(target) and target.is_waiting:
					on_customer_clicked(target, false)

		Phase.WRONG_ITEM, Phase.TALK:
			if is_instance_valid(target):
				target.dialogue_phase = Phase.NONE

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
