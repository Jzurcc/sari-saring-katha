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
var _haggle_reaction_pending: bool = false
var _switch_session_id: int = 0
var _current_timeline_path: String = ""
var _last_dialogue_frame: int = -1
var _watchdog_elapsed: float = 0.0
const WATCHDOG_TIMEOUT_SEC: float = 0.5
const PRICE_REFUSED_TIMELINE_PATH := "res://Dialogue/Timelines/price_refused.dtl"
const PRICE_HAGGLE_PROMPT_TIMELINE_PATH := "res://Dialogue/Timelines/price_haggle_prompt.dtl"
const HaggleOverlayScript := preload("res://Scripts/UI/HaggleOverlay.gd")
const FAVORITE_DISCOVERED_TIMELINE_PATH := "res://Dialogue/Timelines/favorite_discovered.dtl"

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
	_haggle_reaction_pending = false
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
	_haggle_reaction_pending = false
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
	if effective_step < 3:
		return 0.0
	var base_chance: float = 0.0
	match effective_step:
		3: base_chance = 0.15
		4: base_chance = 0.40
		_: base_chance = 0.70
	var relief: float = StoryManager.get_storefront_price_relief()
	var card_mod: float = 0.0
	if StoryManager.has_mayari_card(MayariCardRegistry.CARD_RESTLESS_CROWD):
		card_mod += 0.20
	if StoryManager.has_mayari_card(MayariCardRegistry.CARD_UNRUSHED_HOUR):
		card_mod -= 0.20
	var final_chance: float = base_chance - relief + card_mod
	return maxf(0.05, final_chance) if effective_step >= 4 else maxf(0.0, final_chance)


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

	# Clear any partial bulk-order tip tracker (rejected/refused customer = guaranteed no tip)
	if is_instance_valid(_tree_owner) and _tree_owner.is_inside_tree() and customer.customer_data:
		var gm_ref := _tree_owner.get_tree().get_first_node_in_group("game_manager") as GameManager
		if gm_ref:
			gm_ref.resolve_bulk_order_tip(customer.customer_data.resource_path, false)

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
	if (Dialogic.current_timeline != null and "UncleMario.dtl" in Dialogic.current_timeline.resource_path) or _switching_customer_dialogue or _haggle_reaction_pending:
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

	# Check overpriced refusal BEFORE fulfilling the item (regular cash purchases only; never blocks Story/Tutorial/Utang)
	if _should_refuse_for_high_price(customer, context, item.item_data):
		_start_haggle_or_refusal(customer, item, fallback_pos, needs_switch, prev_customer, prev_phase, prev_pending_dismiss, prev_partial_success)
		return true

	return _complete_item_delivery(customer, item, fallback_pos, needs_switch, prev_customer, prev_phase, prev_pending_dismiss, prev_partial_success)


func _format_price_refusal_line(item_data: ItemData) -> String:
	var price_int: int = int(roundf(item_data.get_final_price()))
	var tmpl: String = PRICE_REFUSAL_LINES[randi() % PRICE_REFUSAL_LINES.size()]
	if tmpl.find("₱%d") != -1 and tmpl.find("%s") != -1:
		if tmpl.find("₱%d") < tmpl.find("%s"):
			return tmpl % [price_int, item_data.item_name]
		return tmpl % [item_data.item_name, price_int]
	elif tmpl.find("%s") != -1:
		return tmpl % item_data.item_name
	return tmpl % price_int


func _start_haggle_or_refusal(
	customer: Customer,
	item: DraggableItem,
	fallback_pos: Vector3,
	needs_switch: bool,
	prev_customer: Customer,
	prev_phase: Phase,
	prev_pending_dismiss: bool,
	prev_partial_success: bool
) -> void:
	if not is_instance_valid(_tree_owner) or not _tree_owner.is_inside_tree():
		_trigger_price_refusal(customer, item, needs_switch, prev_customer, prev_phase, prev_pending_dismiss, prev_partial_success)
		return

	# Haggle triggers by chance (60% base, modified by Mayari Favor/Omen cards)
	var haggle_chance: float = 0.60
	var modifier_label: String = ""
	if is_instance_valid(StoryManager):
		var has_unrushed := StoryManager.has_mayari_card(MayariCardRegistry.CARD_UNRUSHED_HOUR)
		var has_restless := StoryManager.has_mayari_card(MayariCardRegistry.CARD_RESTLESS_CROWD)
		if has_unrushed:
			haggle_chance += 0.25
		if has_restless:
			haggle_chance -= 0.25
		if has_unrushed and not has_restless:
			modifier_label = "Unrushed Hour"
		elif has_restless and not has_unrushed:
			modifier_label = "Restless Crowd"
	haggle_chance = clampf(haggle_chance, 0.15, 0.95)
	var can_haggle: bool = randf() < haggle_chance

	_haggle_reaction_pending = true
	_show_haggle_reaction_badge(customer, can_haggle, haggle_chance, modifier_label)

	var proceed := func():
		_haggle_reaction_pending = false
		if not is_instance_valid(customer) or not is_instance_valid(item) or item.item_data == null:
			return
		if not can_haggle:
			_trigger_price_refusal(customer, item, needs_switch, prev_customer, prev_phase, prev_pending_dismiss, prev_partial_success)
			return

		var launch_haggle := func():
			if not is_instance_valid(customer) or not is_instance_valid(item) or item.item_data == null:
				return
			var overlay := HaggleOverlayScript.new()
			overlay.setup(item.item_data, customer.customer_data, customer)
			_tree_owner.get_tree().root.add_child(overlay)
			overlay.haggle_finished.connect(func(accepted: bool, offered_step: int):
				if not is_instance_valid(customer) or not is_instance_valid(item) or item.item_data == null:
					return
				if accepted:
					var saved_step := item.item_data.current_step
					var saved_selling_price := item.item_data.selling_price
					item.item_data.current_step = offered_step
					item.item_data.selling_price = item.item_data.get_price_for_step(offered_step)
					_complete_item_delivery(customer, item, fallback_pos, needs_switch, prev_customer, prev_phase, prev_pending_dismiss, prev_partial_success)
					item.item_data.current_step = saved_step
					item.item_data.selling_price = saved_selling_price
				else:
					_trigger_price_refusal(customer, item, needs_switch, prev_customer, prev_phase, prev_pending_dismiss, prev_partial_success)
			)

		if not ResourceLoader.exists(PRICE_HAGGLE_PROMPT_TIMELINE_PATH):
			launch_haggle.call()
			return

		var char_name: String = customer.customer_data.character_name if (customer.customer_data and customer.customer_data.character_name != "") else "Neighbor"
		if generic_char_res:
			generic_char_res.display_name = char_name
		Dialogic.VAR.set_variable("Global_PriceRefusalLine", _format_price_refusal_line(item.item_data))

		var choice_holder := {"choice": "decline"}
		var sig_cb := func(arg: String):
			if arg == "haggle_accept":
				choice_holder["choice"] = "haggle"
			elif arg == "haggle_decline":
				choice_holder["choice"] = "decline"
		Dialogic.signal_event.connect(sig_cb)

		start_dialogue(PRICE_HAGGLE_PROMPT_TIMELINE_PATH, customer, Phase.TALK, "")
		Dialogic.timeline_ended.connect(func():
			if Dialogic.signal_event.is_connected(sig_cb):
				Dialogic.signal_event.disconnect(sig_cb)
			if choice_holder["choice"] == "haggle":
				launch_haggle.call()
			else:
				_trigger_price_refusal(customer, item, needs_switch, prev_customer, prev_phase, prev_pending_dismiss, prev_partial_success)
		, CONNECT_ONE_SHOT)

	var beat_timer := _tree_owner.get_tree().create_timer(0.75)
	beat_timer.timeout.connect(proceed, CONNECT_ONE_SHOT)


func _show_haggle_reaction_badge(customer: Customer, can_haggle: bool, haggle_chance: float, modifier_label: String) -> void:
	if not is_instance_valid(_tree_owner) or not _tree_owner.is_inside_tree():
		return
	var tree := _tree_owner.get_tree()
	var vp := tree.root.get_viewport()
	var vp_size := vp.get_visible_rect().size if vp else Vector2(1280.0, 720.0)

	# Project customer's head/speech marker to 2D screen coordinates
	var screen_pos := Vector2(vp_size.x * 0.5, vp_size.y * 0.34)
	if is_instance_valid(customer) and vp:
		var cam := vp.get_camera_3d()
		if cam:
			var marker := customer.get_node_or_null("SpeechMarker") as Node3D
			var world_pos := (marker.global_position + Vector3(0.0, 0.34, 0.0)) if marker else (customer.global_position + Vector3(0.0, 1.78, 0.0))
			if not cam.is_position_behind(world_pos):
				screen_pos = cam.unproject_position(world_pos)

	var accent := Color(0.96, 0.80, 0.38, 1.0) if can_haggle else Color(0.94, 0.44, 0.38, 1.0)
	var icon_path := "res://Assets/ui/icons/heart-handshake.png" if can_haggle else "res://Assets/ui/icons/clock.png"
	var headline := "Open to Haggle!" if can_haggle else "Too Rushed to Haggle!"
	var pct := int(roundf(haggle_chance * 100.0))
	var subline := "%d%% Tawaran chance" % pct
	if modifier_label != "":
		subline += " • %s" % modifier_label

	var cl := CanvasLayer.new()
	cl.layer = 45
	tree.root.add_child(cl)

	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.modulate.a = 0.0
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.10, 0.08, 0.06, 0.95)
	st.border_color = accent
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	st.content_margin_left = 18
	st.content_margin_right = 20
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	st.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	st.shadow_size = 14
	st.shadow_offset = Vector2(0, 4)
	pill.add_theme_stylebox_override("panel", st)
	cl.add_child(pill)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)

	if ResourceLoader.exists(icon_path):
		var ic := TextureRect.new()
		ic.texture = load(icon_path)
		ic.custom_minimum_size = Vector2(28, 28)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.modulate = accent
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	var title_lbl := Label.new()
	title_lbl.text = headline
	title_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", accent)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = subline
	sub_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", Color(0.92, 0.87, 0.78, 0.90))
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sub_lbl)

	# Audio cue matching outcome
	if is_instance_valid(AudioManager) and is_instance_valid(AudioManager.sfx_pool):
		if can_haggle:
			AudioManager.sfx_pool.play_sfx_pitched("pickup", 1.12, -2.0)
		else:
			AudioManager.sfx_pool.play_sfx_pitched("drop", 0.86, -2.0)

	# Defer placement one frame so pill.size is measured, then clamp cleanly into safe zone
	var animate := func():
		if not is_instance_valid(pill):
			return
		var sz := pill.size
		var clamped_x := clampf(screen_pos.x - sz.x * 0.5, 48.0, vp_size.x - sz.x - 48.0)
		var clamped_y := clampf(screen_pos.y - sz.y - 12.0, 56.0, vp_size.y * 0.52)
		pill.position = Vector2(clamped_x, clamped_y + 14.0)
		pill.pivot_offset = sz * 0.5
		pill.scale = Vector2(0.80, 0.80)
		pill.modulate.a = 0.0

		var tw := pill.create_tween()
		tw.set_parallel(true)
		tw.tween_property(pill, "position:y", clamped_y, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(pill, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(pill, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
		tw.chain().tween_interval(3.2)
		tw.chain().set_parallel(true)
		tw.tween_property(pill, "position:y", clamped_y - 16.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(pill, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
		tw.chain().tween_callback(func():
			if is_instance_valid(cl):
				cl.queue_free()
		)
	pill.call_deferred("set_visible", true)
	tree.process_frame.connect(animate, CONNECT_ONE_SHOT)


func _complete_item_delivery(
	customer: Customer,
	item: DraggableItem,
	fallback_pos: Vector3,
	needs_switch: bool,
	prev_customer: Customer,
	prev_phase: Phase,
	prev_pending_dismiss: bool,
	prev_partial_success: bool
) -> bool:
	var context: TransactionContext = customer.transaction_context
	var c_path: String = customer.customer_data.resource_path if customer.customer_data else ""
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
			if gm_guided and not wants_debt and c_path != "":
				var bulk_tip := gm_guided.resolve_bulk_order_tip(c_path, true)
				if bulk_tip > 0.0 and context:
					context.tip_active = true
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

func _build_favorite_discovery_line(c_data: CustomerData, cat_label: String) -> String:
	var cid := c_data.get_clean_id() if c_data else ""
	match cid:
		"kuyakap":
			return "Heh... %s. You've got a good eye, apo — that's always my favorite." % cat_label
		"manangana":
			return "Aba, %s! You really know what I always come here for, anak." % cat_label
		"buboy":
			return "YES! %s is my favorite, Kuya! Keep stocking these, ha?" % cat_label
		"rosalyn":
			return "%s... I always end up reaching for these. Thank you for keeping them." % cat_label
		"tk":
			return "Ooh, %s! Instant favorite — I'm definitely coming back for more." % cat_label
		"danilo":
			return "Hehe, %s! Between us, that's the main reason I stop by your counter." % cat_label
		"brahim":
			return "Salamat. %s — I always keep a bit of this on hand." % cat_label
		"rodel":
			return "Ah, %s. Honestly, that's my favorite thing you carry here." % cat_label
		"sarimanok":
			return "Splendid! %s — truly a favorite worth crossing the street for." % cat_label
		"lolopilo":
			return "Ho-ho! %s! That's my favorite, apo — your lola knew it too." % cat_label
		"reynamayari":
			return "%s... How fitting. You have a knack for what I favor." % cat_label
		_:
			return "Salamat! I really love %s — I'll be back for more!" % cat_label


func on_item_delivered(customer: Customer, is_whole_order_done: bool) -> void:
	if _switching_customer_dialogue:
		return
	update_item_names(customer)

	# First-time favorite category discovery plays an in-character dialogue line instead of a star toast
	var discovered_cat := StoryManager.pending_favorite_discovered_cat if is_instance_valid(StoryManager) else ""
	if discovered_cat != "":
		StoryManager.pending_favorite_discovered_cat = ""
		var ctx := customer.transaction_context
		if ctx != null and not ctx.wants_debt and ResourceLoader.exists(FAVORITE_DISCOVERED_TIMELINE_PATH):
			var cname := customer.customer_data.character_name if (customer.customer_data and customer.customer_data.character_name != "") else "Neighbor"
			if generic_char_res:
				generic_char_res.display_name = cname
			Dialogic.VAR.set_variable("Global_FavoriteDiscoveredLine", _build_favorite_discovery_line(customer.customer_data, discovered_cat))
			if is_instance_valid(customer) and ctx:
				EventBus.customer_order_updated.emit(customer.get_order_hud_key(), ctx.desired_items, ctx.is_riddle)
			if ctx.transaction_type == TransactionContext.Type.STORY:
				# Play favorite discovery remark first, then seamlessly continue into the story chapter's closing dialogue
				start_dialogue(FAVORITE_DISCOVERED_TIMELINE_PATH, customer, Phase.TALK, "Partial")
				Dialogic.timeline_ended.connect(func():
					if is_instance_valid(customer) and is_instance_valid(_tree_owner) and _tree_owner.is_inside_tree():
						on_item_delivered(customer, is_whole_order_done)
				, CONNECT_ONE_SHOT)
				return
			var fav_phase = Phase.SATISFIED if is_whole_order_done else Phase.TALK
			var fav_label = "Satisfy" if is_whole_order_done else "Partial"
			start_dialogue(FAVORITE_DISCOVERED_TIMELINE_PATH, customer, fav_phase, fav_label)
			return

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
				# Award Full 2+ Multi-Item Basket REP right as they start leaving the counter
				if target.transaction_context and not target.get_meta("full_basket_rep_awarded", false):
					var ctx_done: TransactionContext = target.transaction_context
					if ctx_done.delivered_items.size() >= 2 and ctx_done.delivered_items.size() >= ctx_done.desired_items.size():
						target.set_meta("full_basket_rep_awarded", true)
						if target.customer_data and is_instance_valid(CharacterProgressionManager):
							CharacterProgressionManager.add_reputation(target.customer_data.resource_path, 4, "full_basket")
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
