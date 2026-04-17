extends Control

@onready var buttons = $Buttons

# Standalone UI components
@onready var options_overlay    : Control = $OptionsOverlay
@onready var collection_overlay : Control = $CollectionOverlay
@onready var story_overlay      : Control = $StoryProgressOverlay

var target_scene = "res://Scenes/IntroCutscene.tscn"
var original_styles = {}

@export var default_master_volume : float = 0.8
@export var default_bgm_volume    : float = 0.6
@export var default_sfx_volume    : float = 0.9

var cam: Camera3D = null
var cam_origin_rot: Vector3
var cam_origin_pos: Vector3
var is_starting_game: bool = false
var settings_open: bool = false
var pan_sensitivity: float = 0.15
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
	options_overlay.hide()
	collection_overlay.hide()
	if has_node("StoryProgressOverlay"):
		story_overlay.hide()
	
	options_overlay.closed.connect(_on_options_closed)
	collection_overlay.closed.connect(_on_collection_closed)
	if has_node("StoryProgressOverlay"):
		story_overlay.closed.connect(_on_story_progress_closed)

	if has_node("TitleScreen3D/Camera3D"):
		cam = $TitleScreen3D/Camera3D
		cam_origin_rot = cam.rotation
		cam_origin_pos = cam.position

	# Hook up button hover effects + click sound (ui_sfx_4) for all main buttons
	for btn in buttons.get_children():
		if btn is Button:
			_register_button(btn)
	_check_save_status()
	buttons.get_node("NewGame").grab_focus()



# ─── UI Sound helpers ─────────────────────────────────────────────────────────

func _play_click() -> void:
	_ui_player.stream = _sfx_click
	_ui_player.play()

func _play_confirm() -> void:
	_ui_player.stream = _sfx_confirm
	_ui_player.play()

func _register_button(btn: Button) -> void:
	# Cache original theme properties for unhover restoration
	original_styles[btn] = {
		"font_color":    btn.get_theme_color("font_color"),
		"shadow_color":  btn.get_theme_color("font_shadow_color"),
		"outline_color": btn.get_theme_color("font_outline_color"),
		"outline_size":  btn.get_theme_constant("outline_size"),
		"shadow_x":      btn.get_theme_constant("shadow_offset_x"),
		"shadow_y":      btn.get_theme_constant("shadow_offset_y")
	}
	
	# Connect signals for hover/focus effects
	btn.mouse_entered.connect(_on_btn_hover.bind(btn))
	btn.mouse_exited.connect(_on_btn_unhover.bind(btn))
	btn.focus_entered.connect(_on_btn_hover.bind(btn))
	btn.focus_exited.connect(_on_btn_unhover.bind(btn))
	
	if not btn.disabled:
		btn.pressed.connect(_play_click)


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
	if is_starting_game or cam == null:
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
	# Clear existing save for a fresh start
	SaveManager.clear_save()
	
	# Reset in-memory singletons to avoid carrying over old data
	StoryManager.reset_state()
	InventoryManager.reset_state()
	
	# Reset Dialogic state (variables, history, etc.)
	if Engine.has_singleton("Dialogic"):
		Dialogic.VAR.reset_all()

	
	is_starting_game = true
	buttons.hide()
	$LeftVignette.hide()

	# Immediately fade to black and transition to intro cutscene
	SceneTransition.change_scene(target_scene)


func _check_save_status() -> void:
	# Check if we have an actual non-empty save state, rather than just checking
	# for file existence (which could be an empty {} file).
	var save_data = SaveManager.load_game()
	if not save_data.is_empty():
		_create_continue_button()

func _create_continue_button() -> void:
	var new_game_btn = buttons.get_node("NewGame")
	var continue_btn = new_game_btn.duplicate()
	continue_btn.name = "ContinueGame"
	continue_btn.text = "CONTINUE"
	buttons.add_child(continue_btn)
	buttons.move_child(continue_btn, 0)
	
	# Connect signals and register for hover effects
	_register_button(continue_btn)
	continue_btn.pressed.connect(_on_continue_pressed)
	
	# Grab focus if save exists
	continue_btn.grab_focus()

func _on_continue_pressed() -> void:
	# Just start the game; managers will load from the existing save automatically
	is_starting_game = true
	buttons.hide()
	$LeftVignette.hide()
	
	# Skip intro and go straight to the game
	SceneTransition.change_scene("res://Scenes/MainGame.tscn")

func _on_exit_pressed() -> void:
	SaveManager.force_save()
	get_tree().quit()


# ─── Settings overlay ─────────────────────────────────────────────────────────

func _on_options_pressed() -> void:
	settings_open = true
	options_overlay.open()
	_update_menu_interaction(false)

func _on_options_closed() -> void:
	settings_open = false
	_update_menu_interaction(true)


# ─── Collection overlay ───────────────────────────────────────────────────────

func _on_collection_pressed() -> void:
	_play_click()
	collection_overlay.open()
	_update_menu_interaction(false)

func _on_collection_closed() -> void:
	_update_menu_interaction(true)

func _on_story_progress_pressed() -> void:
	_play_click()
	if story_overlay:
		story_overlay.open()
		_update_menu_interaction(false)

func _on_story_progress_closed() -> void:
	_update_menu_interaction(true)

func _update_menu_interaction(enabled: bool) -> void:
	var mode = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	buttons.mouse_filter = mode
	for child in buttons.get_children():
		if child is Control:
			child.mouse_filter = mode
