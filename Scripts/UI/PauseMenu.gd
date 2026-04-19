extends Control

@onready var buttons = $Buttons
@onready var options_overlay    : Control = $OptionsOverlay
@onready var collection_overlay : Control = $CollectionOverlay

var _sfx_click   : AudioStream = preload("res://Audio/SFX/ui_sfx_4.mp3")
var _sfx_confirm : AudioStream = preload("res://Audio/SFX/ui_sfx_9.mp3")
var _ui_player   : AudioStreamPlayer

var _original_music_db: float = 0.0
const DUCK_AMOUNT: float = -6.0 # Subtler ducking
const MUFFLE_CUTOFF: float = 1500.0 # Muffled frequency
const NORMAL_CUTOFF: float = 20500.0 # Full range frequency
const FADE_DURATION: float = 0.4

var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = "SFX"
	add_child(_ui_player)
	
	options_overlay.hide()
	collection_overlay.hide()
	
	options_overlay.closed.connect(_on_options_closed)
	collection_overlay.closed.connect(_on_collection_closed)
	
	# Initial state
	hide()

func pause() -> void:
	show()
	get_tree().paused = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if has_node("/root/StoryManager"):
		StoryManager.is_clock_running = false
	
	if has_node("/root/Dialogic"):
		Dialogic.paused = true
	
	_duck_audio(true)
	_play_confirm()
	
	# Focus first button
	buttons.get_node("Resume").grab_focus()

func resume() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = _previous_mouse_mode
	
	if has_node("/root/StoryManager"):
		StoryManager.is_clock_running = true

	if has_node("/root/Dialogic"):
		Dialogic.paused = false
		
	_duck_audio(false)

func _on_resume_pressed() -> void:
	_play_click()
	resume()

func _on_settings_pressed() -> void:
	_play_click()
	options_overlay.open()
	_update_menu_interaction(false)

func _on_options_closed() -> void:
	_update_menu_interaction(true)
	buttons.get_node("Settings").grab_focus()

func _on_collection_pressed() -> void:
	_play_click()
	collection_overlay.open()
	_update_menu_interaction(false)

func _on_collection_closed() -> void:
	_update_menu_interaction(true)
	buttons.get_node("Collection").grab_focus()

func _on_main_menu_pressed() -> void:
	_play_confirm()
	get_tree().paused = false
	
	_duck_audio(false)
	
	if has_node("/root/StoryManager"):
		StoryManager.is_clock_running = true
		
	if has_node("/root/Dialogic"):
		Dialogic.paused = false
		if Dialogic.current_timeline != null:
			Dialogic.end_timeline()
			
	if has_node("/root/SceneTransition"):
		SceneTransition.change_scene("res://Scenes/MainMenu.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_save_game_pressed() -> void:
	_play_confirm()
	SaveManager.force_save()

func _on_exit_pressed() -> void:
	_play_confirm()
	get_tree().quit()

func _update_menu_interaction(enabled: bool) -> void:
	var mode = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	buttons.mouse_filter = mode
	for child in buttons.get_children():
		if child is Control:
			child.mouse_filter = mode

func _duck_audio(enable: bool) -> void:
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx < 0: return
	
	# Effects: index 0 = Amplify, index 1 = LowPass
	var amp = AudioServer.get_bus_effect(music_idx, 0)
	var lpf = AudioServer.get_bus_effect(music_idx, 1)
	
	var target_amp = DUCK_AMOUNT if enable else 0.0
	var target_lpf = MUFFLE_CUTOFF if enable else NORMAL_CUTOFF
	
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	if amp is AudioEffectAmplify:
		tween.tween_property(amp, "volume_db", target_amp, FADE_DURATION)
	if lpf is AudioEffectLowPassFilter:
		tween.tween_property(lpf, "cutoff_hz", target_lpf, FADE_DURATION)

func _play_click() -> void:
	_ui_player.stream = _sfx_click
	_ui_player.play()

func _play_confirm() -> void:
	_ui_player.stream = _sfx_confirm
	_ui_player.play()

func _input(event: InputEvent) -> void:
	if (event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed)):
		if visible:
			get_viewport().set_input_as_handled()
			if options_overlay.visible:
				options_overlay.close()
			elif collection_overlay.visible:
				collection_overlay.close()
			else:
				_play_confirm() # Play sfx_9 when resuming via Escape
				resume()
		# Opening handled by MainGame.
