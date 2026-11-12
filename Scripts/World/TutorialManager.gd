class_name TutorialManager
extends RefCounted

## Standalone Guided Interaction & Tutorial Controller.
## Orchestrates mid-dialogue interactive tasks (pausing Dialogic, showing helper prompts,
## gating world interaction / item pickup / item delivery, and resuming dialogue on signal completion).
## Decoupled from Customer, MainGame, and PlayerInteraction so any timeline can trigger guided tasks.

var gm: Node
var _is_waiting_for_tutorial_space: bool = false
var is_tutorial_task_active: bool = false
var is_blocking_pickup: bool = false
var current_tutorial_task_id: String = ""
var _current_task_signal: Signal

func _init(manager: Node) -> void:
	gm = manager


# ── Policy Queries (Used by PlayerInteraction, DraggableItem, Customer, MainGame) ──

## Returns true if the player is allowed to interact with 3D world objects right now.
func can_interact_with_world() -> bool:
	var is_in_timeline: bool = Dialogic.current_timeline != null
	if not is_in_timeline:
		return true

	var layout: Node = Dialogic.Styles.get_layout_node()
	var is_dialogue_ui_visible: bool = is_instance_valid(layout) and layout.visible
	if not is_dialogue_ui_visible:
		return true

	return is_tutorial_task_active or is_guided_timeline_active()

## Returns true if picking up DraggableItems is currently permitted.
func can_pickup_item() -> bool:
	return not is_blocking_pickup

## Returns true if a guided sale task is currently waiting for an item handover.
func can_accept_guided_item() -> bool:
	return is_tutorial_task_active and current_tutorial_task_id in ["allow_sale_early", "wait_for_sale"]

## Returns true if wrong-item feedback should be suppressed because a non-sale guided task is active.
func should_suppress_wrong_item_feedback(ctx: TransactionContext) -> bool:
	if ctx == null or not ctx.is_guided_tutorial:
		return false
	return is_tutorial_task_active and current_tutorial_task_id != "wait_for_sale"

## Returns true if the active Dialogic timeline is the guided tutorial timeline.
func is_guided_timeline_active() -> bool:
	var tl = Dialogic.current_timeline
	if tl == null:
		return false
	if typeof(tl) == TYPE_STRING:
		return tl.to_lower().contains("unclemario")
	elif "resource_path" in tl:
		return tl.resource_path.to_lower().contains("unclemario")
	return false


# ── Input & Signal Handling ───────────────────────────────────────────────

## Handles input gating during guided tasks. Returns true if the event was consumed.
func handle_input(event: InputEvent, viewport: Viewport) -> bool:
	# 1. Tutorial Space Handling: Resumes Dialogic after camera pan
	if _is_waiting_for_tutorial_space:
		if event.is_action_pressed("dialogic_default_action") or event.is_action_pressed("ui_accept"):
			_is_waiting_for_tutorial_space = false
			Dialogic.paused = false
			viewport.set_input_as_handled()
			return true

	# 2. Block Dialogue Advancement during Tutorial Tasks or Pause
	if is_tutorial_task_active or Dialogic.paused:
		if event.is_action_pressed("ui_accept"):
			viewport.set_input_as_handled()
			return true

	return false

## Processes Dialogic signal events for guided tasks. Returns true if handled.
func handle_dialogic_signal(argument: String) -> bool:
	if argument == "refuse_service":
		if StoryManager.day == 1 and is_guided_timeline_active():
			StoryManager.complete_tutorial()
		cancel_tutorial_tasks()
		return true
	elif argument == "tutorial_skipped" or argument == "tutorial_completed":
		StoryManager.complete_tutorial()
		cancel_tutorial_tasks()
		if StoryManager.has_method("is_past_closing_time") and StoryManager.is_past_closing_time():
			LogManager.info("TutorialManager", "Tutorial ended at closing time. Skipping Mayari and ending day.")
			StoryManager.has_mayari_visited = true
			EventBus.day_ended.emit(StoryManager.day)
		return true
	elif argument == "allow_sale_early":
		is_tutorial_task_active = true
		current_tutorial_task_id = "allow_sale_early"
		return true
	elif argument == "wait_for_fridge":
		_start_tutorial_task("wait_for_fridge", "Click the handle to open the Refrigerator.", EventBus.refrigerator_opened)
		return true
	elif argument == "wait_for_pricing":
		is_blocking_pickup = false
		_start_tutorial_task("wait_for_pricing", "Press ALT or L to check prices.", EventBus.pricing_mode_changed)
		if not EventBus.price_ledger_toggled.is_connected(_on_tutorial_task_completed):
			EventBus.price_ledger_toggled.connect(_on_tutorial_task_completed, CONNECT_ONE_SHOT)
		return true
	elif argument == "wait_for_pricing_tutorial":
		_start_tutorial_task_timed(3.0, "Adjust prices with Scroll Wheel, or press L for the Price Ledger.")
		return true
	elif argument == "wait_for_price_increase" or argument == "wait_for_profit_increase":
		_start_tutorial_task("wait_for_price_increase", "Adjust an item's price step.", EventBus.price_increased)
		return true
	elif argument == "wait_for_pickup":
		is_blocking_pickup = false
		_start_tutorial_task("wait_for_pickup", "Left-Click an Anoba to pick it up.", EventBus.drag_started)
		return true
	elif argument == "wait_for_sale":
		_start_tutorial_task("wait_for_sale", "Drag the item onto Uncle Mario to sell it.", EventBus.transaction_completed)
		return true
	elif argument == "wait_look_at_fridge":
		_start_tutorial_task_timed(3.0, "Look at the Refrigerator.")
		return true
	elif argument == "wait_look_at_shelf":
		_start_tutorial_task_timed(3.0, "Look at the shelves on your left.")
		return true
	elif argument == "wait_look_at_phone":
		_start_tutorial_task_timed(3.0, "Look at the Phone.")
		return true
	elif argument == "wait_look_at_notebook":
		_start_tutorial_task_timed(3.0, "Look at the Notebook.")
		return true

	return false


# ── Task Lifecycle ────────────────────────────────────────────────────────

func complete_active_task() -> void:
	_on_tutorial_task_completed()

func _start_tutorial_task(task_id: String, prompt: String, completion_signal: Signal) -> void:
	is_tutorial_task_active = true
	current_tutorial_task_id = task_id
	Dialogic.paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var layout = Dialogic.Styles.get_layout_node()
	if layout:
		layout.hide()

	EventBus.helper_prompt_requested.emit(prompt, true)
	_current_task_signal = completion_signal

	if not _current_task_signal.is_connected(_on_tutorial_task_completed):
		_current_task_signal.connect(_on_tutorial_task_completed)

func _start_tutorial_task_timed(duration: float, prompt: String) -> void:
	is_tutorial_task_active = true
	Dialogic.paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var layout = Dialogic.Styles.get_layout_node()
	if layout:
		layout.hide()

	EventBus.helper_prompt_requested.emit(prompt, true)

	await gm.get_tree().create_timer(duration).timeout
	if not is_instance_valid(gm) or not gm.is_inside_tree() or not is_tutorial_task_active:
		return

	is_tutorial_task_active = false
	is_blocking_pickup = false
	Dialogic.paused = false
	if layout:
		layout.show()
	EventBus.helper_prompt_requested.emit("", false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_tutorial_task_completed(arg1 = null, _b = null, _c = null, _d = null) -> void:
	if not is_tutorial_task_active:
		return

	if current_tutorial_task_id.begins_with("wait_look_at"):
		var expected_id: String = current_tutorial_task_id.replace("wait_look_at_", "")
		if str(arg1) != expected_id:
			return

	if _current_task_signal and not _current_task_signal.is_null() and _current_task_signal.is_connected(_on_tutorial_task_completed):
		_current_task_signal.disconnect(_on_tutorial_task_completed)

	is_tutorial_task_active = false
	current_tutorial_task_id = ""
	is_blocking_pickup = false
	EventBus.helper_prompt_requested.emit("", false)

	await gm.get_tree().create_timer(0.7).timeout
	if not is_instance_valid(gm) or not gm.is_inside_tree():
		return

	var layout = Dialogic.Styles.get_layout_node()
	if layout:
		layout.show()
	Dialogic.paused = false

func cancel_tutorial_tasks() -> void:
	LogManager.info("TutorialManager", "Tutorial tasks cancelled/cleaned up.")

	is_blocking_pickup = false
	_is_waiting_for_tutorial_space = false

	if is_instance_valid(MarioManager):
		MarioManager.is_restocking_active = false
		MarioManager.is_mario_physically_present = false
		if MarioManager.has_method("cancel_restock"):
			MarioManager.cancel_restock()

	_cancel_tutorial_signal_connection()

	is_tutorial_task_active = false
	current_tutorial_task_id = ""

	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()

	EventBus.helper_prompt_requested.emit("", false)
	Dialogic.paused = false

	var layout = Dialogic.Styles.get_layout_node()
	if layout:
		layout.show()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _cancel_tutorial_signal_connection() -> void:
	if _current_task_signal and _current_task_signal.is_connected(_on_tutorial_task_completed):
		_current_task_signal.disconnect(_on_tutorial_task_completed)

