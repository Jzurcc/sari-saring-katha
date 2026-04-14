extends Control

@onready var buttons = $Buttons

# Settings UI node references
@onready var slider_master  : HSlider       = $OptionsOverlay/OptionsPanel/Margin/VBox/AudioVBox/Master/Slider
@onready var slider_bgm     : HSlider       = $OptionsOverlay/OptionsPanel/Margin/VBox/AudioVBox/BGM/Slider
@onready var slider_sfx     : HSlider       = $OptionsOverlay/OptionsPanel/Margin/VBox/AudioVBox/SFX/Slider
@onready var mute_toggle    : TextureButton = $OptionsOverlay/OptionsPanel/Margin/VBox/MuteBackground/Toggle
@onready var display_label  : Label         = $OptionsOverlay/OptionsPanel/Margin/VBox/DisplayOptions/WindowModePanel/HBox/Label
@onready var left_arrow     : TextureRect   = $OptionsOverlay/OptionsPanel/Margin/VBox/DisplayOptions/WindowModePanel/HBox/LeftArrow
@onready var right_arrow    : TextureRect   = $OptionsOverlay/OptionsPanel/Margin/VBox/DisplayOptions/WindowModePanel/HBox/RightArrow

var target_scene = "res://Scenes/MainGame.tscn"
var original_styles = {}

@export var default_master_volume : float = 0.8
@export var default_bgm_volume    : float = 0.6
@export var default_sfx_volume    : float = 0.9

var cam: Camera3D = null
var cam_origin_rot: Vector3
var cam_origin_pos: Vector3
var is_starting_game: bool = false
var settings_open: bool = false
var _is_fullscreen: bool = false
var pan_sensitivity: float = 0.5
var current_offset_x: float = 0.0
var current_offset_y: float = 0.0

const SETTINGS_PATH = "user://settings.cfg"

# ── UI Sound ─────────────────────────────────────────────────────────────────
var _sfx_click   : AudioStream = preload("res://Audio/SFX/ui_sfx_4.mp3")
var _sfx_confirm : AudioStream = preload("res://Audio/SFX/ui_sfx_9.mp3")
var _ui_player   : AudioStreamPlayer


# ─── Ready ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# UI sound player (uses SFX bus)
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = "SFX"
	add_child(_ui_player)

	if has_node("TitleScreen3D/Camera3D"):
		cam = $TitleScreen3D/Camera3D
		cam_origin_rot = cam.rotation
		cam_origin_pos = cam.position

	# Hook up button hover effects + click sound (ui_sfx_4) for all main buttons
	for btn in buttons.get_children():
		if btn is Button:
			original_styles[btn] = {
				"font_color":    btn.get_theme_color("font_color"),
				"shadow_color":  btn.get_theme_color("font_shadow_color"),
				"outline_color": btn.get_theme_color("font_outline_color"),
				"outline_size":  btn.get_theme_constant("outline_size"),
				"shadow_x":      btn.get_theme_constant("shadow_offset_x"),
				"shadow_y":      btn.get_theme_constant("shadow_offset_y")
			}
			btn.mouse_entered.connect(_on_btn_hover.bind(btn))
			btn.mouse_exited.connect(_on_btn_unhover.bind(btn))
			btn.focus_entered.connect(_on_btn_hover.bind(btn))
			btn.focus_exited.connect(_on_btn_unhover.bind(btn))
			if not btn.disabled:
				btn.pressed.connect(_play_click)
	buttons.get_node("NewGame").grab_focus()

	# Set slider defaults from @export values
	slider_master.set_value_no_signal(default_master_volume)
	slider_bgm.set_value_no_signal(default_bgm_volume)
	slider_sfx.set_value_no_signal(default_sfx_volume)

	# Connect slider signals — value_changed for audio, drag_ended for confirm sound
	slider_master.value_changed.connect(_on_master_changed)
	slider_bgm.value_changed.connect(_on_bgm_changed)
	slider_sfx.value_changed.connect(_on_sfx_changed)
	slider_master.drag_ended.connect(func(_vc: bool): _play_confirm())
	slider_bgm.drag_ended.connect(func(_vc: bool): _play_confirm())
	slider_sfx.drag_ended.connect(func(_vc: bool): _play_confirm())

	# Mute toggle sound (ui_sfx_4)
	mute_toggle.toggled.connect(func(_pressed: bool): _play_click())

	# Ensure Music and SFX buses exist (creates them routed to Master if missing)
	_ensure_audio_buses()

	# Load saved settings and apply them
	_load_settings()

	# Sync display label to current actual window mode
	_sync_display_label()


# ─── UI Sound helpers ─────────────────────────────────────────────────────────

func _play_click() -> void:
	_ui_player.stream = _sfx_click
	_ui_player.play()

func _play_confirm() -> void:
	_ui_player.stream = _sfx_confirm
	_ui_player.play()


# ─── Button hover effects ──────────────────────────────────────────────────────

func _on_btn_hover(btn: Button) -> void:
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_constant_override("outline_size", 0)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))

func _on_btn_unhover(btn: Button) -> void:
	var orig = original_styles[btn]
	btn.add_theme_color_override("font_color",         orig["font_color"])
	btn.add_theme_color_override("font_shadow_color",  orig["shadow_color"])
	btn.add_theme_color_override("font_outline_color", orig["outline_color"])
	btn.add_theme_constant_override("outline_size",    orig["outline_size"])


# ─── Camera parallax pan ───────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if is_starting_game or cam == null or settings_open:
		return

	var mouse_pos   = get_viewport().get_mouse_position()
	var window_size = get_viewport().get_visible_rect().size
	
	# Mapped from -1.0 to 1.0 based on screen center
	current_offset_x = (mouse_pos.x / window_size.x) * 2.0 - 1.0
	current_offset_y = (mouse_pos.y / window_size.y) * 2.0 - 1.0
	
	var target_rot_x = cam_origin_rot.x - (current_offset_y * pan_sensitivity)
	var target_rot_y = cam_origin_rot.y - (current_offset_x * pan_sensitivity)
	
	var target_pos_x = cam_origin_pos.x + (current_offset_x * 0.02)
	var target_pos_y = cam_origin_pos.y - (current_offset_y * 0.02)
	
	# Smoothly interpolate the camera's transform
	cam.rotation.x = lerp(cam.rotation.x, target_rot_x, delta * 3.0)
	cam.rotation.y = lerp(cam.rotation.y, target_rot_y, delta * 3.0)
	cam.position.x = lerp(cam.position.x, target_pos_x, delta * 3.0)
	cam.position.y = lerp(cam.position.y, target_pos_y, delta * 3.0)


# ─── New Game ─────────────────────────────────────────────────────────────────

func _on_new_game_pressed() -> void:
	is_starting_game = true
	buttons.hide()
	$LeftVignette.hide()

	if cam == null:
		SceneTransition.change_scene(target_scene)
		return

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	var target_pos = Vector3(-1.638, 4.1, -0.05)
	var target_rot = Vector3(0, deg_to_rad(90.0), 0)

	tween.set_parallel(true)
	tween.tween_property(cam, "position", target_pos, 1.8)
	tween.tween_property(cam, "rotation", target_rot, 1.8)
	tween.tween_property(cam, "fov",  75.0,   1.8)
	tween.tween_property(cam, "near", 0.05,   1.8)
	tween.tween_property(cam, "far",  4000.0, 1.8)
	tween.set_parallel(false)
	tween.chain().tween_callback(_on_pan_finished)

func _on_pan_finished() -> void:
	SceneTransition.change_scene(target_scene)

func _on_exit_pressed() -> void:
	get_tree().quit()


# ─── Settings overlay ─────────────────────────────────────────────────────────

func _on_options_pressed() -> void:
	settings_open = true
	$OptionsOverlay.show()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in buttons.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_options_close_pressed() -> void:
	_play_confirm()   # ui_sfx_9 on X close
	settings_open = false
	$OptionsOverlay.hide()
	buttons.mouse_filter = Control.MOUSE_FILTER_STOP
	for child in buttons.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_STOP
	_save_settings()


# ─── Audio bus setup ─────────────────────────────────────────────────────────

func _ensure_audio_buses() -> void:
	# Godot always has Master at index 0.
	# Create Music and SFX buses routed to Master if they don't already exist.
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")


# ─── Volume sliders ───────────────────────────────────────────────────────────

func _on_master_changed(value: float) -> void:
	# Master affects ALL audio — including Music and SFX routed through it
	var idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(idx, linear_to_db(value) if value > 0.0 else -80.0)
	AudioServer.set_bus_mute(idx, value <= 0.0)

func _on_bgm_changed(value: float) -> void:
	# Music bus — only soundtracks, not SFX
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(value) if value > 0.0 else -80.0)
	AudioServer.set_bus_mute(idx, value <= 0.0)

func _on_sfx_changed(value: float) -> void:
	# SFX bus — only sound effects, not music
	var idx := AudioServer.get_bus_index("SFX")
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(value) if value > 0.0 else -80.0)
	AudioServer.set_bus_mute(idx, value <= 0.0)


# ─── Mute in Background ───────────────────────────────────────────────────────

func _notification(what: int) -> void:
	if not is_instance_valid(mute_toggle) or not mute_toggle.button_pressed:
		return
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx < 0:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			AudioServer.set_bus_mute(master_idx, true)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			AudioServer.set_bus_mute(master_idx, slider_master.value <= 0.0)


# ─── Display mode toggle ─────────────────────────────────────────────────────────

func _on_window_mode_panel_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed):
		return

	_play_click()   # ui_sfx_4

	_is_fullscreen = not _is_fullscreen
	if _is_fullscreen:
		# Exclusive Fullscreen: takes 100% GPU control, max performance, no desktop overhead
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		# Windowed: floating window with title bar, best for multitasking
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	_sync_display_label()

func _sync_display_label() -> void:
	display_label.text  = "Full Screen" if _is_fullscreen else "Windowed Mode"
	left_arrow.visible  = not _is_fullscreen   # left arrow = can go back to windowed
	right_arrow.visible = _is_fullscreen        # right arrow = can go to fullscreen


# ─── Settings persistence ─────────────────────────────────────────────────────

func _save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "master", slider_master.value)
	cfg.set_value("audio", "bgm",    slider_bgm.value)
	cfg.set_value("audio", "sfx",    slider_sfx.value)
	cfg.set_value("accessibility", "mute_in_background", mute_toggle.button_pressed)
	var mode = DisplayServer.window_get_mode()
	cfg.set_value("display", "fullscreen", _is_fullscreen)
	cfg.save(SETTINGS_PATH)

func _load_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		# First launch — push slider defaults to AudioServer
		_on_master_changed(slider_master.value)
		_on_bgm_changed(slider_bgm.value)
		_on_sfx_changed(slider_sfx.value)
		return

	# Audio volumes — fall back to @export defaults if no saved value
	var master_val : float = cfg.get_value("audio", "master", default_master_volume)
	var bgm_val    : float = cfg.get_value("audio", "bgm",    default_bgm_volume)
	var sfx_val    : float = cfg.get_value("audio", "sfx",    default_sfx_volume)
	slider_master.set_value_no_signal(master_val)
	slider_bgm.set_value_no_signal(bgm_val)
	slider_sfx.set_value_no_signal(sfx_val)
	_on_master_changed(master_val)
	_on_bgm_changed(bgm_val)
	_on_sfx_changed(sfx_val)

	# Accessibility
	mute_toggle.button_pressed = cfg.get_value("accessibility", "mute_in_background", false)

	# Display mode — restore internal state flag and apply
	var want_fs : bool = cfg.get_value("display", "fullscreen", false)
	_is_fullscreen = want_fs
	if want_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
