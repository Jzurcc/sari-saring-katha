extends CanvasLayer

## The action to use for advancing the dialogue.
@export var next_action: StringName = &"ui_accept"

## The action to use to skip typing.
@export var skip_action: StringName = &"ui_cancel"

## Block all other input while balloon is visible.
@export var will_block_other_input: bool = true

# --- Node references ---
@onready var balloon: Control = %Balloon
@onready var portrait: TextureRect = %Portrait
@onready var character_label: RichTextLabel = %CharacterLabel
@onready var dialogue_label: DialogueLabel = %DialogueLabel
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu
@onready var continue_indicator: Control = %ContinueIndicator

# --- State ---
var _dialogue_resource = null       
var temporary_game_states: Array = []
var is_waiting_for_input: bool = false
var will_hide_balloon: bool = false

var mutation_cooldown: Timer = Timer.new()


var dialogue_line = null:
	set(value):
		if value:
			dialogue_line = value
			_apply_dialogue_line()
		else:
			queue_free()
	get:
		return dialogue_line


func _ready() -> void:
	balloon.hide()
	DialogueManager.mutated.connect(_on_mutated)

	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)


func _process(_delta: float) -> void:
	if is_instance_valid(dialogue_line):
		continue_indicator.visible = not dialogue_label.is_typing and dialogue_line.responses.size() == 0


func _unhandled_input(_event: InputEvent) -> void:
	if will_block_other_input:
		get_viewport().set_input_as_handled()


## Called by DialogueManager.show_dialogue_balloon_scene() to start the conversation.
func start(with_dialogue_resource = null, title: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false

	if with_dialogue_resource != null:
		_dialogue_resource = with_dialogue_resource

	if _dialogue_resource == null:
		push_error("DialogueBalloon.start(): no dialogue resource provided!")
		queue_free()
		return

	show()
	dialogue_line = await _dialogue_resource.get_next_dialogue_line(title, temporary_game_states)


## Apply the current dialogue line to all visuals.
func _apply_dialogue_line() -> void:
	mutation_cooldown.stop()
	continue_indicator.hide()
	is_waiting_for_input = false
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	# --- Character name ---
	character_label.visible = not dialogue_line.character.is_empty()
	character_label.text = tr(dialogue_line.character, "dialogue")

	# --- Portrait ---
	# TK_Portrait.png is baked into the scene — always visible.
	# Override the texture if a game state provides a custom one.
	_get_portrait_from_states()
	portrait.show()

	# --- Dialogue text ---
	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	# --- Responses ---
	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses

	# Show the balloon with a fade-in
	balloon.show()
	will_hide_balloon = false
	balloon.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(balloon, "modulate:a", 1.0, 0.15)

	# Type out text
	dialogue_label.show()
	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	# What happens next?
	if dialogue_line.responses.size() > 0:
		balloon.focus_mode = Control.FOCUS_NONE
		responses_menu.show()
	elif dialogue_line.time != "":
		var time: float = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(time).timeout
		_next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()


## Advance to the next dialogue line.
func _next(next_id: String) -> void:
	dialogue_line = await _dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


## Try to read portrait_texture from extra game states.
func _get_portrait_from_states() -> bool:
	for state in temporary_game_states:
		if state is Node and "portrait_texture" in state and state.portrait_texture != null:
			portrait.texture = state.portrait_texture
			return true
	return false


#region Signals


func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		balloon.hide()


func _on_mutated(mutation: Dictionary) -> void:
	if not mutation.is_inline:
		is_waiting_for_input = false
		will_hide_balloon = true
		mutation_cooldown.start(0.1)


func _on_balloon_gui_input(event: InputEvent) -> void:
	if dialogue_label.is_typing:
		var mouse_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		var skip_pressed: bool = event.is_action_pressed(skip_action)
		if mouse_clicked or skip_pressed:
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
			return

	if not is_waiting_for_input:
		return
	if dialogue_line.responses.size() > 0:
		return

	get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		_next(dialogue_line.next_id)
	elif event.is_action_pressed(next_action) and get_viewport().gui_get_focus_owner() == balloon:
		_next(dialogue_line.next_id)


func _on_responses_menu_response_selected(response) -> void:
	_next(response.next_id)


#endregion
