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

	_load_settings()
	_sync_display_label()

func open() -> void:
	show()
	_load_settings()

func close() -> void:
	_play_confirm()
	_save_settings()
	hide()
	closed.emit()

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
	cfg.save(SETTINGS_PATH)

func _load_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		_on_master_changed(slider_master.value)
		_on_bgm_changed(slider_bgm.value)
		_on_sfx_changed(slider_sfx.value)
		_on_voices_changed(slider_voices.value)
		return
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
