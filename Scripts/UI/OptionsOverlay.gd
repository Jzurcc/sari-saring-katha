extends ColorRect

signal closed

# Settings UI node references
@onready var slider_master  : HSlider       = $OptionsPanel/Margin/VBox/AudioVBox/Master/Slider
@onready var slider_bgm     : HSlider       = $OptionsPanel/Margin/VBox/AudioVBox/BGM/Slider
@onready var slider_sfx     : HSlider       = $OptionsPanel/Margin/VBox/AudioVBox/SFX/Slider
@onready var slider_voices  : HSlider       = $OptionsPanel/Margin/VBox/AudioVBox/Voices/Slider
@onready var mute_toggle    : TextureButton = $OptionsPanel/Margin/VBox/MuteBackground/Toggle
@onready var display_label  : Label         = $OptionsPanel/Margin/VBox/DisplayOptions/WindowModePanel/HBox/Label
@onready var left_arrow     : TextureRect   = $OptionsPanel/Margin/VBox/DisplayOptions/WindowModePanel/HBox/LeftArrow
@onready var right_arrow    : TextureRect   = $OptionsPanel/Margin/VBox/DisplayOptions/WindowModePanel/HBox/RightArrow

@export var default_master_volume : float = 0.8
@export var default_bgm_volume    : float = 0.6
@export var default_sfx_volume    : float = 0.9
@export var default_voices_volume : float = 0.9

var _is_fullscreen: bool = false
const SETTINGS_PATH = "user://settings.cfg"

# Keybinding variables
const REMAPPABLE_ACTIONS = {
	"look_front": "Move Front",
	"look_back": "Move Back",
	"look_left": "Move Left",
	"look_right": "Move Right",
	"crouch": "Crouch",
	"sprint": "Sprint",
	"pricing_lens": "Pricing Lens",
	"price_up": "Increase Price",
	"price_down": "Decrease Price",
	"dialogic_default_action": "Advance Dialogue"
}

var _is_remapping: bool = false
var _remapping_action: String = ""
var _remapping_button: Button = null
var _custom_bindings: Dictionary = {}

# UI Sound
var _sfx_click   : AudioStream = preload("res://Audio/SFX/ui_sfx_4.mp3")
var _sfx_confirm : AudioStream = preload("res://Audio/SFX/ui_sfx_9.mp3")
var _ui_player   : AudioStreamPlayer

func _ready() -> void:
	# UI sound player
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = "SFX"
	add_child(_ui_player)

	# Set slider defaults
	slider_master.set_value_no_signal(default_master_volume)
	slider_bgm.set_value_no_signal(default_bgm_volume)
	slider_sfx.set_value_no_signal(default_sfx_volume)
	slider_voices.set_value_no_signal(default_voices_volume)

	# Connect slider signals
	slider_master.value_changed.connect(_on_master_changed)
	slider_bgm.value_changed.connect(_on_bgm_changed)
	slider_sfx.value_changed.connect(_on_sfx_changed)
	slider_voices.value_changed.connect(_on_voices_changed)
	slider_master.drag_ended.connect(func(_vc: bool): _play_confirm())
	slider_bgm.drag_ended.connect(func(_vc: bool): _play_confirm())
	slider_sfx.drag_ended.connect(func(_vc: bool): _play_confirm())
	slider_voices.drag_ended.connect(func(_vc: bool): _play_confirm())

	mute_toggle.toggled.connect(func(pressed: bool):
		_play_click()
		if has_node("/root/AudioManager"):
			AudioManager.update_mute_in_background(pressed)
	)

	_ensure_actions_initialized()
	_load_settings()
	var content_vbox = _setup_scroll_container()
	_setup_controls_ui(content_vbox)
	_sync_display_label()
	_update_all_binding_buttons()

func _ensure_actions_initialized() -> void:
	for action in REMAPPABLE_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			_set_default_for_action(action)
	
	# Special case: ensure Advance Dialogue displays Space as primary if possible
	if InputMap.has_action("dialogic_default_action"):
		var events = InputMap.action_get_events("dialogic_default_action")
		var space_idx = -1
		for i in range(events.size()):
			if events[i] is InputEventKey and (events[i].physical_keycode == KEY_SPACE or events[i].keycode == KEY_SPACE):
				space_idx = i
				break
		
		if space_idx > 0:
			var space_event = events[space_idx]
			events.remove_at(space_idx)
			events.insert(0, space_event)
			InputMap.action_erase_events("dialogic_default_action")
			for e in events:
				InputMap.action_add_event("dialogic_default_action", e)

func _set_default_for_action(action: String) -> void:
	var events: Array[InputEvent] = []
	match action:
		"crouch":
			var e = InputEventKey.new()
			e.physical_keycode = KEY_CTRL
			events.append(e)
		"sprint":
			var e = InputEventKey.new()
			e.physical_keycode = KEY_SHIFT
			events.append(e)
		"pricing_lens":
			var e = InputEventKey.new()
			e.physical_keycode = KEY_ALT
			events.append(e)
		"price_up":
			var e1 = InputEventKey.new()
			e1.physical_keycode = KEY_PERIOD
			events.append(e1)
			var e2 = InputEventMouseButton.new()
			e2.button_index = MOUSE_BUTTON_WHEEL_UP
			events.append(e2)
		"price_down":
			var e1 = InputEventKey.new()
			e1.physical_keycode = KEY_COMMA
			events.append(e1)
			var e2 = InputEventMouseButton.new()
			e2.button_index = MOUSE_BUTTON_WHEEL_DOWN
			events.append(e2)
		"dialogic_default_action":
			var e1 = InputEventKey.new()
			e1.physical_keycode = KEY_SPACE
			events.append(e1)
			var e2 = InputEventKey.new()
			e2.physical_keycode = KEY_ENTER
			events.append(e2)
			var e3 = InputEventMouseButton.new()
			e3.button_index = MOUSE_BUTTON_LEFT
			events.append(e3)
	
	for e in events:
		InputMap.action_add_event(action, e)

func close() -> void:
	_play_confirm()
	_save_settings()
	hide()
	closed.emit()

func open() -> void:
	show()
	_ensure_actions_initialized() # Ensure actions and order are correct every time we open
	_load_settings()

func _play_click() -> void:
	_ui_player.stream = _sfx_click
	_ui_player.play()

func _play_confirm() -> void:
	_ui_player.stream = _sfx_confirm
	_ui_player.play()

func _on_master_changed(value: float) -> void:
	var idx: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(idx, linear_to_db(value) if value > 0.0 else -80.0)
	AudioServer.set_bus_mute(idx, value <= 0.0)
	if has_node("/root/AudioManager"):
		AudioManager.update_master_muted_by_user(value <= 0.0)

func _on_bgm_changed(value: float) -> void:
	var idx: int = AudioServer.get_bus_index("Music")
	if idx < 0: return
	AudioServer.set_bus_volume_db(idx, linear_to_db(value) if value > 0.0 else -80.0)
	AudioServer.set_bus_mute(idx, value <= 0.0)

func _on_sfx_changed(value: float) -> void:
	var idx: int = AudioServer.get_bus_index("SFX")
	if idx < 0: return
	AudioServer.set_bus_volume_db(idx, linear_to_db(value) if value > 0.0 else -80.0)
	AudioServer.set_bus_mute(idx, value <= 0.0)

func _on_voices_changed(value: float) -> void:
	var idx: int = AudioServer.get_bus_index("Voices")
	if idx < 0: return
	AudioServer.set_bus_volume_db(idx, linear_to_db(value) if value > 0.0 else -80.0)
	AudioServer.set_bus_mute(idx, value <= 0.0)

func _on_window_mode_panel_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	_play_click()
	_is_fullscreen = not _is_fullscreen
	if _is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_sync_display_label()

func _input(event: InputEvent) -> void:
	if not visible: return
	
	if not _is_remapping:
		if event.is_action_pressed("ui_cancel"):
			close()
			get_viewport().set_input_as_handled()
		return
	
	# Only capture actual presses to avoid binding on key release
	if not event.is_pressed():
		return
		
	if event is InputEventKey or event is InputEventMouseButton:
		# Stop remapping if Escape is pressed (cancel)
		if event is InputEventKey and event.keycode == KEY_ESCAPE:
			_stop_remapping()
			get_viewport().set_input_as_handled()
			return
		
		# Set the new binding
		_update_binding(_remapping_action, event)
		_stop_remapping()
		get_viewport().set_input_as_handled()

func _start_remapping(action: String, button: Button) -> void:
	if _is_remapping:
		return
	
	_is_remapping = true
	_remapping_action = action
	_remapping_button = button
	_remapping_button.text = "..."
	_play_click()

func _stop_remapping() -> void:
	_is_remapping = false
	if _remapping_button:
		_update_button_text(_remapping_button, _remapping_action)
		_remapping_button = null
	_remapping_action = ""

func _update_binding(action: String, event: InputEvent) -> void:
	# Only keep key or mouse button events for now
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
		
	_custom_bindings[action] = event
	_update_input_map(action, event)
	_save_settings()
	_update_all_binding_buttons()

func _update_input_map(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		# Initialize if missing
		InputMap.add_action(action)
		_set_default_for_action(action)
	
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event.duplicate())
	
	# Preserve mouse wheel for pricing regardless of keyboard rebind
	if action == "price_up":
		var wheel = InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		InputMap.action_add_event(action, wheel)
	elif action == "price_down":
		var wheel = InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		InputMap.action_add_event(action, wheel)

func _update_button_text(button: Button, action: String) -> void:
	if action == "": # Default recovery if aborted
		action = _remapping_action
		
	var events = InputMap.action_get_events(action)
	if events.size() > 0:
		var raw_text = events[0].as_text()
		# Aggressively clean up Godot's text representation
		var labels = [" (Physical)", " (physical)", " - Physical", " - physical", " (Physical Key)"]
		for label in labels:
			raw_text = raw_text.replace(label, "")
		button.text = raw_text
	else:
		button.text = "None"

func _setup_scroll_container() -> VBoxContainer:
	var vbox = $OptionsPanel/Margin/VBox
	var _header = vbox.get_node("Header")
	
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	var content_vbox = VBoxContainer.new()
	content_vbox.name = "ContentVBox"
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 24)
	scroll.add_child(content_vbox)
	
	var nodes_to_move = []
	for i in range(1, vbox.get_child_count()):
		nodes_to_move.append(vbox.get_child(i))
	
	for node in nodes_to_move:
		vbox.remove_child(node)
		content_vbox.add_child(node)
	
	vbox.add_child(scroll)
	return content_vbox

func _setup_controls_ui(vbox: VBoxContainer) -> void:
	# Add Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	# Add Label
	var label = Label.new()
	label.text = "Controls"
	label.add_theme_font_override("font", preload("res://Assets/Fonts/Inder/Inder-Regular.ttf"))
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1, 0.922, 0.792, 1))
	vbox.add_child(label)
	
	# Add Controls Container
	var controls_vbox = VBoxContainer.new()
	controls_vbox.name = "ControlsVBox"
	controls_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(controls_vbox)
	
	for action in REMAPPABLE_ACTIONS:
		var hbox = HBoxContainer.new()
		hbox.name = action
		controls_vbox.add_child(hbox)
		
		var sub_spacer = Control.new()
		sub_spacer.custom_minimum_size = Vector2(24, 0)
		hbox.add_child(sub_spacer)
		
		var action_label = Label.new()
		action_label.text = REMAPPABLE_ACTIONS[action]
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_label.add_theme_font_override("font", preload("res://Assets/Fonts/Inder/Inder-Regular.ttf"))
		action_label.add_theme_font_size_override("font_size", 20)
		action_label.add_theme_color_override("font_color", Color(1, 0.922, 0.792, 1))
		hbox.add_child(action_label)
		
		var btn = Button.new()
		btn.name = "Button"
		btn.custom_minimum_size = Vector2(200, 40)
		btn.focus_mode = Control.FOCUS_NONE # Prevent buttons from consuming Space/Enter
		btn.add_theme_font_override("font", preload("res://Assets/Fonts/Inder/Inder-Regular.ttf"))
		btn.pressed.connect(_start_remapping.bind(action, btn))
		hbox.add_child(btn)

func _update_all_binding_buttons() -> void:
	for action in REMAPPABLE_ACTIONS:
		# Search in content_vbox/ControlsVBox
		var btn = get_node_or_null("OptionsPanel/Margin/VBox/ScrollContainer/ContentVBox/ControlsVBox/" + action + "/Button")
		if btn:
			_update_button_text(btn, action)

func _sync_display_label() -> void:
	display_label.text  = "Full Screen" if _is_fullscreen else "Windowed Mode"
	left_arrow.visible  = _is_fullscreen
	right_arrow.visible = not _is_fullscreen

func _save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "master", slider_master.value)
	cfg.set_value("audio", "bgm",    slider_bgm.value)
	cfg.set_value("audio", "sfx",    slider_sfx.value)
	cfg.set_value("audio", "voices", slider_voices.value)
	cfg.set_value("accessibility", "mute_in_background", mute_toggle.button_pressed)
	cfg.set_value("display", "fullscreen", _is_fullscreen)
	
	# Save Controls
	for action in _custom_bindings:
		var event = _custom_bindings[action]
		if event is InputEventKey:
			cfg.set_value("controls", action, {"type": "key", "keycode": event.keycode, "physical": event.physical_keycode})
		elif event is InputEventMouseButton:
			cfg.set_value("controls", action, {"type": "mouse", "button_index": event.button_index})

	cfg.save(SETTINGS_PATH)

func _load_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		_on_master_changed(slider_master.value)
		_on_bgm_changed(slider_bgm.value)
		_on_sfx_changed(slider_sfx.value)
		_on_voices_changed(slider_voices.value)
		return
	
	# Load Controls first so they are applied to InputMap
	if cfg.has_section("controls"):
		for action in cfg.get_section_keys("controls"):
			var data = cfg.get_value("controls", action)
			var event: InputEvent
			if data is Dictionary:
				if data.get("type") == "key":
					event = InputEventKey.new()
					event.keycode = data.get("keycode", 0)
					event.physical_keycode = data.get("physical", 0)
				elif data.get("type") == "mouse":
					event = InputEventMouseButton.new()
					event.button_index = data.get("button_index", 0)
			
			if event:
				_custom_bindings[action] = event
				_update_input_map(action, event)
	var master_val : float = cfg.get_value("audio", "master", default_master_volume)
	var bgm_val    : float = cfg.get_value("audio", "bgm",    default_bgm_volume)
	var sfx_val    : float = cfg.get_value("audio", "sfx",    default_sfx_volume)
	var voices_val : float = cfg.get_value("audio", "voices", default_voices_volume)
	slider_master.set_value_no_signal(master_val)
	slider_bgm.set_value_no_signal(bgm_val)
	slider_sfx.set_value_no_signal(sfx_val)
	slider_voices.set_value_no_signal(voices_val)
	_on_master_changed(master_val)
	_on_bgm_changed(bgm_val)
	_on_sfx_changed(sfx_val)
	_on_voices_changed(voices_val)
	mute_toggle.button_pressed = cfg.get_value("accessibility", "mute_in_background", false)
	var want_fs : bool = cfg.get_value("display", "fullscreen", true)
	_is_fullscreen = want_fs
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_fs else DisplayServer.WINDOW_MODE_WINDOWED)
