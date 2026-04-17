extends Control

@onready var buttons = $Buttons
@onready var options_overlay    : Control = $OptionsOverlay
@onready var collection_overlay : Control = $CollectionOverlay

var _sfx_click   : AudioStream = preload("res://Audio/SFX/ui_sfx_4.mp3")
var _sfx_confirm : AudioStream = preload("res://Audio/SFX/ui_sfx_9.mp3")
var _ui_player   : AudioStreamPlayer

var _original_music_db: float = 0.0
const DUCK_AMOUNT: float = -12.0
const FADE_DURATION: float = 0.3

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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if has_node("/root/StoryManager"):
		StoryManager.is_clock_running = false
	
	if has_node("/root/Dialogic"):
		Dialogic.paused = true
	
	_duck_audio(true)
	
	# Focus first button
	buttons.get_node("Resume").grab_focus()

func resume() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
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
	if has_node("/root/SceneTransition"):
		SceneTransition.change_scene("res://Scenes/MainMenu.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

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
	
	# Find Amplify effect (we added it as index 0 in default_bus_layout.tres)
	var effect = AudioServer.get_bus_effect(music_idx, 0)
	if not effect is AudioEffectAmplify: return
	
	var target_db = DUCK_AMOUNT if enable else 0.0
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # Run even while paused
	tween.tween_property(effect, "volume_db", target_db, FADE_DURATION)

func _play_click() -> void:
	_ui_player.stream = _sfx_click
	_ui_player.play()

func _play_confirm() -> void:
	_ui_player.stream = _sfx_confirm
	_ui_player.play()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed):
		if visible:
			if options_overlay.visible:
				options_overlay.close()
			elif collection_overlay.visible:
				collection_overlay.close()
			else:
				resume()
		# We don't handle opening here, because the PauseMenu might not be in the tree or active.
		# Opening will be handled by MainGame.
