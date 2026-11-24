class_name DialogicNode_ChoiceButton
extends Button
## This button allows the player to make a choice in the Dialogic system.
##
## When a choice is reached Dialogic will automatically show ChoiceButtons 
## and call their [code]_load_info()[/code] method which will display the choices.
## You will need to ensure that enough choice buttons are available in the tree 
## to display all choices.[br]
## 
## [br]  
## You can extend this node and implement some custom logic by overwriting
## the [code]_load_info(info:Dictionary)[/code] method. [br]
## [br]
## If you need RichText support, consider adding a RichTextLabel child and setting it as the [member text_node].[br]
## 
## [br]
## DialogicChoiceButtons will grab the focus when hovered to avoid a confusing 
## focus style being present for players who use the mouse.[br]
## To avoid the opposite situation, when the focus is changed by the player 
## and a different button is still hovered the mouse pointer will be moved
## to the now focused button as well.


## Emitted when the choice is selected. Unless overridden, this is when the button or its shortcut is pressed.
signal choice_selected


## Used to identify what choices to put on. If you leave it at -1, choices will be distributed automatically.
@export var choice_index: int = -1

## Can be set to play this sound when pressed. Requires a sibling DialogicNode_ButtonSound node.
@export var sound_pressed: AudioStream
## Can be set to play this sound when hovered. Requires a sibling DialogicNode_ButtonSound node.
@export var sound_hover: AudioStream
## Can be set to play this sound when focused. Requires a sibling DialogicNode_ButtonSound node.
@export var sound_focus: AudioStream

## If set, the text will be set on this node's `text` property instead. 
## This can be used to have a custom text rendering child, like a RichTextLabel.
@export var text_node: Node

var _confirm_keycap: PanelContainer = null
var _confirm_keycap_lbl: Label = null


func _ready() -> void:
	add_to_group('dialogic_choice_button')
	shortcut_in_tooltip = false
	clip_contents = false
	hide()
	
	# For players who use a mouse to make choices, mouse hover should grab focus.
	# Otherwise the auto-focused button will always show a highlighted color when
	# the mouse cursor is hovering on another button.
	if not mouse_entered.is_connected(grab_focus):
		mouse_entered.connect(grab_focus)
	if not focus_entered.is_connected(_on_choice_button_focus_entred):
		focus_entered.connect(_on_choice_button_focus_entred.bind(self))
	if not focus_entered.is_connected(_on_keycap_focus_entered):
		focus_entered.connect(_on_keycap_focus_entered)
	if not focus_exited.is_connected(_on_keycap_focus_exited):
		focus_exited.connect(_on_keycap_focus_exited)
	if not hidden.is_connected(_on_keycap_focus_exited):
		hidden.connect(_on_keycap_focus_exited)

	_build_confirm_keycap()
	if Engine.has_singleton("EventBus") or get_node_or_null("/root/EventBus"):
		var eb := get_node_or_null("/root/EventBus")
		if eb and eb.has_signal("keybinds_changed") and not eb.keybinds_changed.is_connected(_refresh_keycap_text):
			eb.keybinds_changed.connect(_refresh_keycap_text)


func _build_confirm_keycap() -> void:
	_confirm_keycap = PanelContainer.new()
	_confirm_keycap.name = "ConfirmKeycap"
	_confirm_keycap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_keycap.anchor_left = 0.0
	_confirm_keycap.anchor_right = 0.0
	_confirm_keycap.anchor_top = 0.5
	_confirm_keycap.anchor_bottom = 0.5
	_confirm_keycap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_confirm_keycap.grow_vertical = Control.GROW_DIRECTION_BOTH
	_confirm_keycap.offset_left = -10.0
	_confirm_keycap.offset_right = -10.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.10, 0.09, 0.94)
	style.border_color = Color(1.0, 0.90, 0.54, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 5
	_confirm_keycap.add_theme_stylebox_override("panel", style)

	_confirm_keycap_lbl = Label.new()
	_confirm_keycap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_keycap_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_confirm_keycap_lbl.add_theme_font_size_override("font_size", 14)
	_confirm_keycap_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.56, 1.0))
	_confirm_keycap_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_keycap.add_child(_confirm_keycap_lbl)

	_refresh_keycap_text()
	_confirm_keycap.visible = false
	add_child(_confirm_keycap)


func _refresh_keycap_text() -> void:
	if not is_instance_valid(_confirm_keycap_lbl):
		return
	var nav := get_node_or_null("/root/DialogueChoiceNavigator")
	if nav and nav.has_method("get_action_key_label"):
		_confirm_keycap_lbl.text = nav.get_action_key_label("dialogue_confirm_choice", "F")
	else:
		_confirm_keycap_lbl.text = "F"


func _on_keycap_focus_entered() -> void:
	if not is_instance_valid(_confirm_keycap) or not visible or disabled:
		return
	_refresh_keycap_text()
	_confirm_keycap.visible = true
	_confirm_keycap.pivot_offset = _confirm_keycap.size * 0.5
	_confirm_keycap.scale = Vector2(0.84, 0.84)
	var tw := create_tween()
	tw.tween_property(_confirm_keycap, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_keycap_focus_exited() -> void:
	if is_instance_valid(_confirm_keycap):
		_confirm_keycap.visible = false


## Custom choice buttons can override this for specialized behavior when the choice button is pressed.
func _pressed():
	choice_selected.emit()


## Custom choice buttons can override this if their behavior should change
## based on event data. If the custom choice button does not override
## visibility, disabled-ness, nor the choice text, consider
## calling super(choice_info) at the start of the override.
##
## The choice_info Dictionary has the following keys:
## - event_index:    The index of the choice event in the timeline.
## - button_index:   The relative index of the choice (starts from 1).
## - visible:        If the choice should be visible.
## - disabled:       If the choice should be selectable.
## - text:           The text of the choice.
## - visited_before: If the choice has been selected before. Only available is the History submodule is enabled.
## - *:              Information from the event's additional info.
func _load_info(choice_info: Dictionary) -> void:
	set_choice_text(choice_info.text)
	visible = choice_info.visible
	disabled = choice_info.disabled


## Called when the text changes.
func set_choice_text(new_text: String) -> void:
	if text_node:
		text_node.text = new_text
	else:
		text = new_text


## This method moves the mouse to the focused choice when the focus changes 
## while a choice button was hovered. [br]
## For players who use many devices (mouse/keyboard/gamepad, etc) at the same time to make choices,
## a grabing-focus triggered by keyboard/gamepad should also change the mouse cursor's
## position otherwise two buttons will have highlighted color(one highlighted button
## triggered by mouse hover and another highlighted button triggered by other devices' choice).
func _on_choice_button_focus_entred(focused_button: Button):
	var global_mouse_pos = get_global_mouse_position()
	var focused_button_rect = focused_button.get_global_rect()
	if focused_button_rect.has_point(global_mouse_pos):
		return
	# Only change mouse curor position when an unfocused button' rect has the cursor.
	for node in get_tree().get_nodes_in_group('dialogic_choice_button'):
		if node is Button:
			if node != focused_button and node.get_global_rect().has_point(global_mouse_pos):
				# We prefer to change only mouse_position.y or mouse_position.x to warp the
				# mouse to the focused button's rect to achieve the best visual effect.
				var modify_y_pos = Vector2(global_mouse_pos.x, focused_button.get_global_rect().get_center().y)
				if focused_button_rect.has_point(modify_y_pos):
					get_viewport().warp_mouse(modify_y_pos)
					return
					
				var modify_x_pos = Vector2(focused_button.get_global_rect().get_center().x, global_mouse_pos.y)
				if focused_button_rect.has_point(modify_x_pos):
					get_viewport().warp_mouse(modify_x_pos)
					return
					
				# Maybe the buttons are not aligned as vertically or horizontlly.
				# Or perhaps the length difference between the two buttons is quite large.
				# So we just make the cursor hover on the center of the focused button.
				get_viewport().warp_mouse(focused_button.get_global_rect().get_center())
				return
