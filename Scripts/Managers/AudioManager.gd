extends Node

var mute_in_background: bool = false
var master_muted_by_user: bool = false
const SETTINGS_PATH = "user://settings.cfg"

var bgm_player: AudioStreamPlayer
var theme_player: AudioStreamPlayer
var ambience_base: AudioStreamPlayer
var ambience_night: AudioStreamPlayer

var base_volume_db: float = -6.0 # Roughly 50% linear volume

var audio_boring_day = preload("res://Audio/Soundtracks/A Boring Day.mp3")
var audio_fantastic_idea = preload("res://Audio/Soundtracks/Fantastic Idea.mp3")
var audio_not_me = preload("res://Audio/Soundtracks/Not ME.mp3")
var audio_sleepy = preload("res://Audio/Soundtracks/Sleepy.mp3")
var audio_laughing_horse = preload("res://Audio/Soundtracks/Laughing Horse.mp3")

var character_themes: Dictionary = {
	# "KuyaKap": audio_laughing_horse
}

var dialogue_blip_player: AudioStreamPlayer

var audio_calming_morning = preload("res://Audio/SFX/Calming Morning Sounds.mp3")
var audio_night_crickets = preload("res://Audio/SFX/Sounds of Night Crickets.mp3")

enum BGMPhase { NONE, MORNING, AFTERNOON, DUSK }
var current_bgm_phase: BGMPhase = BGMPhase.NONE

var time_of_day_node: Node = null

var afternoon_playlist_index: int = 0
var afternoon_playlist: Array = []

func _ready() -> void:
	name = "AudioManager"
	
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Music"
	bgm_player.volume_db = base_volume_db
	add_child(bgm_player)
	
	theme_player = AudioStreamPlayer.new()
	theme_player.bus = "Music"
	theme_player.volume_db = -80.0
	add_child(theme_player)
	
	ambience_base = AudioStreamPlayer.new()
	ambience_base.bus = "Master"
	ambience_base.volume_db = 2.0
	add_child(ambience_base)
	
	ambience_night = AudioStreamPlayer.new()
	ambience_night.bus = "Master"
	ambience_night.volume_db = -4.0
	add_child(ambience_night)
	
	dialogue_blip_player = AudioStreamPlayer.new()
	dialogue_blip_player.bus = "SFX"
	add_child(dialogue_blip_player)
	
	afternoon_playlist = [audio_fantastic_idea, audio_not_me]
	
	bgm_player.finished.connect(_on_bgm_finished)
	theme_player.finished.connect(_on_theme_finished)
	ambience_base.finished.connect(func(): ambience_base.play())
	ambience_night.finished.connect(_on_ambience_night_finished)
	
	EventBus.customer_spawned.connect(_on_customer_spawned)
	EventBus.customer_satisfied.connect(_on_customer_left)
	EventBus.customer_dismissed.connect(_on_customer_left)
	
	var audio_autumn_wind = preload("res://Audio/Soundtracks/an Autumn Wind.mp3")
	
	# Start base ambience immediately
	ambience_base.stream = audio_calming_morning
	ambience_base.play()
	
	# Start Title Screen music
	bgm_player.stream = audio_autumn_wind
	bgm_player.volume_db = base_volume_db
	bgm_player.play()
	
	_load_audio_settings()
	
	call_deferred("_connect_dialogic")

func _process(_delta: float) -> void:
	# Prevent the dummy TimeOfDay inside the TitleScreen3D from hijacking the music!
	if get_tree().current_scene and get_tree().current_scene.name in ["MainMenu", "IntroCutscene"]:
		return
		
	if not is_instance_valid(time_of_day_node):
		time_of_day_node = _find_time_of_day(get_tree().root)
		
	if is_instance_valid(time_of_day_node):
		var time = time_of_day_node.get("current_time")
		if time != null:
			_update_audio_for_time(time)

func _find_time_of_day(node: Node) -> Node:
	if node is TimeOfDay:
		return node
	# Fallback if TimeOfDay class isn't loaded everywhere properly, fallback to name check:
	if node.name == "TimeOfDay" and node.has_method("get_current_time_utc0"):
		return node
	
	for i in range(node.get_child_count()):
		var child = node.get_child(i)
		var result = _find_time_of_day(child)
		if result:
			return result
	return null

func _load_audio_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		var master_val : float = cfg.get_value("audio", "master", 0.8)
		var bgm_val    : float = cfg.get_value("audio", "bgm",    0.6)
		var sfx_val    : float = cfg.get_value("audio", "sfx",    0.9)
		
		# Only update default base_volume_db if master is different? 
		# No, the volume buses will handle real volumes.
		
		var m_idx = AudioServer.get_bus_index("Master")
		if m_idx >= 0:
			AudioServer.set_bus_volume_db(m_idx, linear_to_db(master_val) if master_val > 0.0 else -80.0)
			AudioServer.set_bus_mute(m_idx, master_val <= 0.0)
			master_muted_by_user = master_val <= 0.0
			
		var b_idx = AudioServer.get_bus_index("Music")
		if b_idx >= 0:
			AudioServer.set_bus_volume_db(b_idx, linear_to_db(bgm_val) if bgm_val > 0.0 else -80.0)
			AudioServer.set_bus_mute(b_idx, bgm_val <= 0.0)
			
		var s_idx = AudioServer.get_bus_index("SFX")
		if s_idx >= 0:
			AudioServer.set_bus_volume_db(s_idx, linear_to_db(sfx_val) if sfx_val > 0.0 else -80.0)
			AudioServer.set_bus_mute(s_idx, sfx_val <= 0.0)
		
		mute_in_background = cfg.get_value("accessibility", "mute_in_background", false)

func update_mute_in_background(value: bool) -> void:
	mute_in_background = value

func update_master_muted_by_user(value: bool) -> void:
	master_muted_by_user = value

func _notification(what: int) -> void:
	if not mute_in_background:
		return
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx < 0:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			AudioServer.set_bus_mute(master_idx, true)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			AudioServer.set_bus_mute(master_idx, master_muted_by_user)


func _update_audio_for_time(time: float) -> void:
	var new_phase = BGMPhase.NONE
	var is_night = false
	
	if time >= 4.0 and time < 11.0:
		new_phase = BGMPhase.MORNING
	elif time >= 11.0 and time < 18.0:
		new_phase = BGMPhase.AFTERNOON
	else:
		new_phase = BGMPhase.DUSK
		is_night = true
		
	if new_phase != current_bgm_phase:
		_change_bgm_phase(new_phase)
		
	if is_night and not ambience_night.playing:
		ambience_night.stream = audio_night_crickets
		ambience_night.play()
	elif not is_night and ambience_night.playing:
		ambience_night.stop()

var bgm_transition_tween: Tween

func _change_bgm_phase(phase: BGMPhase) -> void:
	current_bgm_phase = phase
	
	if bgm_transition_tween and bgm_transition_tween.is_valid():
		bgm_transition_tween.kill()
		
	bgm_transition_tween = create_tween()
	var is_first_play = not bgm_player.playing
	
	if not is_first_play:
		bgm_transition_tween.tween_property(bgm_player, "volume_db", -80.0, 2.0).set_ease(Tween.EASE_OUT)
		bgm_transition_tween.tween_interval(2.0)
		bgm_transition_tween.tween_callback(func(): bgm_player.stop())
		
	bgm_transition_tween.tween_callback(func():
		if phase == BGMPhase.MORNING:
			bgm_player.stream = audio_boring_day
		elif phase == BGMPhase.AFTERNOON:
			afternoon_playlist_index = 0
			bgm_player.stream = afternoon_playlist[afternoon_playlist_index]
		elif phase == BGMPhase.DUSK:
			bgm_player.stream = audio_sleepy
			
		var target_vol = -80.0 if theme_player.playing else base_volume_db
		
		if is_first_play:
			bgm_player.volume_db = target_vol
			bgm_player.play()
		else:
			bgm_player.volume_db = -80.0
			bgm_player.play()
			bgm_transition_tween = create_tween()
			bgm_transition_tween.tween_property(bgm_player, "volume_db", target_vol, 2.0).set_ease(Tween.EASE_IN)
	)

func _on_bgm_finished() -> void:
	if current_bgm_phase == BGMPhase.AFTERNOON:
		afternoon_playlist_index = (afternoon_playlist_index + 1) % afternoon_playlist.size()
		bgm_player.stream = afternoon_playlist[afternoon_playlist_index]
		bgm_player.play()
	else:
		# For Morning string and Dusk tracks, simply replay when finished
		bgm_player.play()

func _on_theme_finished() -> void:
	theme_player.play()
	
func _on_customer_spawned(customer: Customer) -> void:
	if character_themes.has(customer.character_id):
		play_character_theme(character_themes[customer.character_id])

func _on_customer_left(_customer: Customer) -> void:
	stop_character_theme()

var crossfade_tween: Tween

func play_character_theme(theme_stream: AudioStream) -> void:
	if crossfade_tween and crossfade_tween.is_valid():
		crossfade_tween.kill()
		
	theme_player.stream = theme_stream
	theme_player.play()
	
	crossfade_tween = create_tween()
	crossfade_tween.tween_property(bgm_player, "volume_db", -80.0, 1.5).set_ease(Tween.EASE_OUT)
	crossfade_tween.parallel().tween_property(theme_player, "volume_db", base_volume_db, 1.5).set_ease(Tween.EASE_IN)

func stop_character_theme() -> void:
	if crossfade_tween and crossfade_tween.is_valid():
		crossfade_tween.kill()
		
	crossfade_tween = create_tween()
	crossfade_tween.tween_property(bgm_player, "volume_db", base_volume_db, 2.0).set_ease(Tween.EASE_IN)
	crossfade_tween.parallel().tween_property(theme_player, "volume_db", -80.0, 2.0).set_ease(Tween.EASE_OUT)
	crossfade_tween.tween_callback(func(): theme_player.stop())

func _on_ambience_night_finished() -> void:
	if current_bgm_phase == BGMPhase.DUSK:
		ambience_night.play()

func _connect_dialogic() -> void:
	if has_node("/root/Dialogic"):
		var dialogic = get_node("/root/Dialogic")
		dialogic.Text.about_to_show_text.connect(_on_dialogue_about_to_show)

func _on_dialogue_about_to_show(info: Dictionary) -> void:
	if info.has("character") and info.character != null:
		var story_mgr = get_node_or_null("/root/StoryManager")
		if not story_mgr:
			return

		var char_to_play: CustomerData = null
		var char_path = info.character.resource_path

		# Case A: Information matches a specific character's .dch (Story/Filler)
		for c in story_mgr.available_characters:
			if c.dialogic_character and c.dialogic_character.resource_path == char_path:
				char_to_play = c
				break
		
		# Case B: Information matches our generic Customer.dch (Generic/Social)
		# We match by display_name which was patched in CustomerSpawner.
		if char_to_play == null and char_path.ends_with("Customer.dch"):
			for c in story_mgr.available_characters:
				if c.character_name == info.character.display_name:
					char_to_play = c
					break
		
		
		# Case C: Information matches Uncle Mario's .dch (which is outside standard available_characters)
		if char_to_play == null:
			var mario_manager = get_node_or_null("/root/MarioManager")
			if mario_manager and mario_manager.get("_mario_data"):
				var m_data = mario_manager.get("_mario_data")
				if m_data and m_data.dialogic_character and m_data.dialogic_character.resource_path == char_path:
					char_to_play = m_data

		if char_to_play and char_to_play.dialogue_blip_sound:
			dialogue_blip_player.pitch_scale = randf_range(0.95, 1.05)
			dialogue_blip_player.stream = char_to_play.dialogue_blip_sound
			dialogue_blip_player.play()
