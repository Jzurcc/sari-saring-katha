extends Node

var mute_in_background: bool = false
var master_muted_by_user: bool = false
const SETTINGS_PATH = "user://settings.cfg"

var bgm_player: AudioStreamPlayer
var theme_player: AudioStreamPlayer
var ambience_base: AudioStreamPlayer
var ambience_night: AudioStreamPlayer

var base_volume_db: float = -6.0 # Roughly 50% linear volume
const FADE_DURATION: float = 1.5

func fade_out_everything(duration: float = FADE_DURATION) -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(bgm_player, "volume_db", -80.0, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(theme_player, "volume_db", -80.0, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(ambience_base, "volume_db", -80.0, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(ambience_night, "volume_db", -80.0, duration).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	bgm_player.stop()
	theme_player.stop()
	ambience_base.stop()
	ambience_night.stop()
	
	# Reset volumes for future play calls (they usually set their own volume anyway)
	bgm_player.volume_db = base_volume_db
	theme_player.volume_db = -80.0
	ambience_base.volume_db = 2.0
	ambience_night.volume_db = -13.1


var audio_boring_day = preload("res://Audio/Soundtracks/A Boring Day.mp3")
var audio_fantastic_idea = preload("res://Audio/Soundtracks/Fantastic Idea.mp3")
var audio_not_me = preload("res://Audio/Soundtracks/Not ME.mp3")
var audio_sleepy = preload("res://Audio/Soundtracks/Sleepy.mp3")
var audio_laughing_horse = preload("res://Audio/Soundtracks/Laughing Horse.mp3")
var audio_autumn_wind = preload("res://Audio/Soundtracks/an Autumn Wind.mp3")
var audio_brunch = preload("res://Audio/Soundtracks/Brunch.wav")
var audio_brunch_ii = preload("res://Audio/Soundtracks/Brunch II.wav")
var audio_kids_room = preload("res://Audio/Soundtracks/Kid's Room.wav")
var audio_hermit_crab = preload("res://Audio/Soundtracks/Adventure of a Hermit Crab.wav")
var audio_naptime = preload("res://Audio/Soundtracks/Naptime.wav")

var character_themes: Dictionary = {
	# "KuyaKap": audio_laughing_horse
}

@onready var _song_titles: Dictionary = {
	audio_boring_day: "A Boring Day",
	audio_fantastic_idea: "Fantastic Idea",
	audio_not_me: "Not ME",
	audio_sleepy: "Sleepy",
	audio_laughing_horse: "Laughing Horse",
	audio_autumn_wind: "An Autumn Wind",
	audio_brunch: "Brunch",
	audio_brunch_ii: "Brunch II",
	audio_kids_room: "Kid's Room",
	audio_hermit_crab: "Adventure of a Hermit Crab",
	audio_naptime: "Naptime"
}


var dialogue_blip_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player_idx: int = 0
const SFX_POOL_SIZE: int = 8

var audio_calming_morning = preload("res://Audio/SFX/Calming Morning Sounds.mp3")
var audio_night_crickets = preload("res://Audio/SFX/Sounds of Night Crickets.mp3")

# --- SFX Preloads for Juice ---
var sfx_kaching = preload("res://Audio/SFX/money kaching.mp3")
var sfx_pop_1 = preload("res://Audio/SFX/ui_sfx_12.mp3")
var sfx_pop_2 = preload("res://Audio/SFX/ui_sfx_15.mp3")
var sfx_clink = preload("res://Audio/SFX/ui_sfx_3.mp3")
var sfx_error = preload("res://Audio/SFX/ui_sfx_9.mp3")
var sfx_tab = preload("res://Audio/SFX/ui_sfx_4.mp3")
var sfx_hover = preload("res://Audio/SFX/ui_sfx_7.mp3")
var sfx_plastic = preload("res://Audio/SFX/plastic.mp3")
var sfx_trash = preload("res://Audio/SFX/trash.mp3")
var sfx_money_decrease = preload("res://Audio/SFX/money_decrease.wav")
var sfx_fridge_open = preload("res://Audio/SFX/refrigerator_open.mp3")
var sfx_fridge_close = preload("res://Audio/SFX/refrigerator_close.mp3")
var sfx_fridge_hum = preload("res://Audio/SFX/refrigerator.mp3")

var sfx_library = {
	"money_gain": sfx_kaching,
	"purchase": sfx_kaching,
	"pickup": sfx_pop_1,
	"drop": sfx_pop_2,
	"interact": sfx_clink,
	"error": sfx_error,
	"tab_switch": sfx_tab,
	"ui_hover": sfx_hover,
	"plastic": sfx_plastic,
	"trash": sfx_trash,
	"money_decrease": sfx_money_decrease,
	"refrigerator_open": sfx_fridge_open,
	"refrigerator_close": sfx_fridge_close,
	"price_change": sfx_error
}

var sfx_volume_offsets = {
	"money_gain": -6.0,
	"purchase": -6.0,
	"tab_switch": -6.0,
	"interact": -6.0,
	"pickup": -6.0,
	"drop": -6.0,
	"error": -6.0,
	"ui_hover": -6.0,
	"refrigerator_open": -3.0,
	"refrigerator_close": -3.0,
	"price_change": -6.0
}
enum BGMPhase { NONE, MORNING, AFTERNOON, DUSK }
var fridge_hum_player: AudioStreamPlayer
var current_bgm_phase: BGMPhase = BGMPhase.NONE

var time_of_day_node: Node = null
var _scene_check_timer: float = 0.0
var _is_in_intro_or_menu: bool = true
var _last_scene_name: String = ""

var _active_playlist: Array = []
var _playlist_index: int = 0
var _last_emitted_title: String = ""


func _ready() -> void:
	randomize()

	name = "AudioManager"

	process_mode = PROCESS_MODE_ALWAYS
	
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
	ambience_night.volume_db = -13.1
	add_child(ambience_night)

	
	dialogue_blip_player = AudioStreamPlayer.new()
	dialogue_blip_player.bus = "Voices"
	add_child(dialogue_blip_player)
	
	for i in range(SFX_POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)
	
	fridge_hum_player = AudioStreamPlayer.new()
	fridge_hum_player.bus = "SFX"
	fridge_hum_player.stream = sfx_fridge_hum
	fridge_hum_player.volume_db = -9.0
	add_child(fridge_hum_player)
	
	# Connect loop for hum
	fridge_hum_player.finished.connect(func(): if fridge_hum_player.stream: fridge_hum_player.play())
	
	bgm_player.finished.connect(_on_bgm_finished)
	theme_player.finished.connect(_on_theme_finished)
	ambience_base.finished.connect(func(): ambience_base.play())
	ambience_night.finished.connect(_on_ambience_night_finished)
	
	EventBus.customer_spawned.connect(_on_customer_spawned)
	EventBus.customer_satisfied.connect(_on_customer_left)
	EventBus.customer_dismissed.connect(_on_customer_left)
	EventBus.request_sfx.connect(play_sfx)
	
	# Start base ambience immediately at a random position
	ambience_base.stream = audio_calming_morning
	ambience_base.play(randf_range(0.0, ambience_base.stream.get_length()))
	
	_load_audio_settings()
	
	# Initial entry into Menu phase
	_change_bgm_phase(BGMPhase.NONE)
	
	# Cache TimeOfDay once scene is settled
	await get_tree().process_frame
	
	call_deferred("_connect_dialogic")

func play_sfx(sfx_name: String) -> void:
	if sfx_library.has(sfx_name):
		var p = sfx_players[_next_sfx_player_idx]
		_next_sfx_player_idx = (_next_sfx_player_idx + 1) % SFX_POOL_SIZE
		
		p.stream = sfx_library[sfx_name]
		p.pitch_scale = randf_range(0.9, 1.1)
		
		# Apply volume offset if defined, otherwise reset to 0
		if sfx_volume_offsets.has(sfx_name):
			p.volume_db = sfx_volume_offsets[sfx_name]
		else:
			p.volume_db = 0.0
			
		p.play()

func _process(delta: float) -> void:
	_scene_check_timer += delta
	if _scene_check_timer > 1.0:
		_scene_check_timer = 0.0
		var scene = get_tree().current_scene
		if scene:
			_is_in_intro_or_menu = scene.name in ["MainMenu", "IntroCutscene"] or scene.has_method("play_all_sequences")
			
			# Force phase update if scene name changed while in intro/menu
			if _last_scene_name != scene.name:
				_last_scene_name = scene.name
				if _is_in_intro_or_menu:
					_change_bgm_phase(BGMPhase.NONE)

			if not _is_in_intro_or_menu and not is_instance_valid(time_of_day_node):
				time_of_day_node = scene.get_node_or_null("World/TimeOfDay")
				if not time_of_day_node:
					time_of_day_node = scene.find_child("TimeOfDay", true, false)

	if _is_in_intro_or_menu:
		if current_bgm_phase != BGMPhase.NONE:
			_change_bgm_phase(BGMPhase.NONE)
		return
		
	if is_instance_valid(time_of_day_node):
		var time = time_of_day_node.get("current_time")
		if time != null:
			_update_audio_for_time(time)


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
		
		var v_val : float = cfg.get_value("audio", "voices", 0.9)
		var v_idx = AudioServer.get_bus_index("Voices")
		if v_idx >= 0:
			AudioServer.set_bus_volume_db(v_idx, linear_to_db(v_val) if v_val > 0.0 else -80.0)
			AudioServer.set_bus_mute(v_idx, v_val <= 0.0)
		
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
		ambience_night.play(randf_range(0.0, ambience_night.stream.get_length()))
	elif not is_night and ambience_night.playing:
		ambience_night.stop()

var bgm_transition_tween: Tween

func _change_bgm_phase(phase: BGMPhase) -> void:
	current_bgm_phase = phase
	
	# Populate Playlist Pools
	var pool = []
	match phase:
		BGMPhase.NONE: # Main Menu / Intro
			var scene = get_tree().current_scene
			if scene and scene.name == "MainMenu":
				pool = [audio_brunch, audio_autumn_wind]
			else:
				pool = [audio_autumn_wind]
		BGMPhase.MORNING:
			pool = [audio_boring_day, audio_brunch_ii, audio_kids_room]
		BGMPhase.AFTERNOON:
			pool = [audio_fantastic_idea, audio_not_me, audio_hermit_crab]
		BGMPhase.DUSK:
			pool = [audio_sleepy, audio_naptime]
	
	if pool.is_empty(): return
	
	# Apply Shuffling Rules
	if phase == BGMPhase.NONE:
		# Just alternate starting with Brunch from the top
		_active_playlist = pool
	else:
		# True shuffle for everything else
		var original_first = pool[0]
		_active_playlist = pool.duplicate()
		_active_playlist.shuffle()
		
		# Force the first starting song to NOT be the first one declared in the pool to guarantee it feels random
		if _active_playlist[0] == original_first and _active_playlist.size() > 1:
			var swap_idx = (randi() % (_active_playlist.size() - 1)) + 1
			var tmp = _active_playlist[0]
			_active_playlist[0] = _active_playlist[swap_idx]
			_active_playlist[swap_idx] = tmp
			
	_playlist_index = 0

	_update_fridge_hum(phase)
	
	if bgm_transition_tween and bgm_transition_tween.is_valid():
		bgm_transition_tween.kill()
		
	bgm_transition_tween = create_tween()
	var is_first_play = not bgm_player.playing
	
	if not is_first_play:
		bgm_transition_tween.tween_property(bgm_player, "volume_db", -80.0, FADE_DURATION).set_ease(Tween.EASE_OUT)
		bgm_transition_tween.tween_callback(func(): bgm_player.stop())
		
	bgm_transition_tween.tween_callback(func():
		bgm_player.stream = _active_playlist[_playlist_index]
			
		var target_vol = -80.0 if theme_player.playing else base_volume_db
		
		if is_first_play:
			bgm_player.volume_db = target_vol
			bgm_player.play()
		else:
			bgm_player.volume_db = -80.0
			bgm_player.play()
			bgm_transition_tween = create_tween()
			bgm_transition_tween.tween_property(bgm_player, "volume_db", target_vol, FADE_DURATION).set_ease(Tween.EASE_IN)
		
		_emit_music_change(bgm_player.stream)
	)

func _update_fridge_hum(phase: BGMPhase) -> void:
	if not fridge_hum_player: return
	
	# Play always except in the menu/intro
	var should_play = (phase != BGMPhase.NONE)
	
	if should_play and not fridge_hum_player.playing:
		fridge_hum_player.play()
	elif not should_play and fridge_hum_player.playing:
		fridge_hum_player.stop()



func _on_bgm_finished() -> void:
	var last_song = _active_playlist[_playlist_index]
	_playlist_index += 1
	
	if _playlist_index >= _active_playlist.size():
		# Reshuffle on loop (maintaining phase rules)
		if current_bgm_phase == BGMPhase.NONE:
			# Main menu just alternates (already set up as [Brunch, Autumn Wind])
			_playlist_index = 0
		else:
			# Non-menu phases get a fresh shuffle that avoids immediate repeats
			_shuffle_playlist(_active_playlist)
			# If the first song of the new shuffle is the same as the last one played...
			if _active_playlist.size() > 1 and _active_playlist[0] == last_song:
				# Swap it with another random element skip the first one
				var swap_idx = (randi() % (_active_playlist.size() - 1)) + 1
				var tmp = _active_playlist[0]

				_active_playlist[0] = _active_playlist[swap_idx]
				_active_playlist[swap_idx] = tmp
			
			_playlist_index = 0
	
	bgm_player.stream = _active_playlist[_playlist_index]
	bgm_player.play()
	_emit_music_change(bgm_player.stream)

func _shuffle_playlist(playlist: Array) -> void:
	playlist.shuffle()



func _on_theme_finished() -> void:
	theme_player.play()
	
func _on_customer_spawned(customer: Customer) -> void:
	if customer.customer_data and character_themes.has(customer.customer_data.resource_path):
		play_character_theme(character_themes[customer.customer_data.resource_path])

func _on_customer_left(_customer: Customer) -> void:
	stop_character_theme()

var crossfade_tween: Tween

func play_character_theme(theme_stream: AudioStream) -> void:
	if crossfade_tween and crossfade_tween.is_valid():
		crossfade_tween.kill()
		
	theme_player.stream = theme_stream
	theme_player.play()
	
	crossfade_tween = create_tween()
	crossfade_tween.tween_property(bgm_player, "volume_db", -80.0, FADE_DURATION).set_ease(Tween.EASE_OUT)
	crossfade_tween.parallel().tween_property(theme_player, "volume_db", base_volume_db, FADE_DURATION).set_ease(Tween.EASE_IN)
	
	_emit_music_change(theme_player.stream)


func stop_character_theme() -> void:
	if not theme_player.playing:
		return
		
	if crossfade_tween and crossfade_tween.is_valid():
		crossfade_tween.kill()
		
	crossfade_tween = create_tween()
	crossfade_tween.tween_property(bgm_player, "volume_db", base_volume_db, FADE_DURATION).set_ease(Tween.EASE_IN)
	crossfade_tween.parallel().tween_property(theme_player, "volume_db", -80.0, FADE_DURATION).set_ease(Tween.EASE_OUT)
	crossfade_tween.tween_callback(func(): theme_player.stop())
	
	_emit_music_change(bgm_player.stream)


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
		var char_path: String = info.character.resource_path
		
		# --- STRATEGY 1: Priority check for the active customer from CustomerSpawner ---
		# This is the most reliable way as CustomerSpawner knows exactly who is at the counter.
		var spawner_nodes = get_tree().get_nodes_in_group("customer_spawner")
		if not spawner_nodes.is_empty():
			var spawner = spawner_nodes[0]
			if spawner.current_customer and spawner.current_customer.customer_data:
				# If the display name matches the active customer, use their data regardless of paths.
				# Also match if the name is "???" (undiscovered character).
				if spawner.current_customer.customer_data.character_name == info.character.display_name or info.character.display_name == "???":
					char_to_play = spawner.current_customer.customer_data
		
		# --- STRATEGY 2: Match by specific .dch resource path (Story/Filler characters) ---
		if char_to_play == null:
			for c in story_mgr.available_characters:
				if c.dialogic_character and c.dialogic_character.resource_path == char_path:
					char_to_play = c
					break
		
		# --- STRATEGY 3: Match generic "Customer" by display_name fallback ---
		if char_to_play == null and (char_path.ends_with("Customer.dch") or char_path == ""):
			for c in story_mgr.available_characters:
				if c.character_name == info.character.display_name:
					char_to_play = c
					break
		
		# --- STRATEGY 4: Match Uncle Mario (outside available_characters) ---
		if char_to_play == null:
			var mario_manager = get_node_or_null("/root/MarioManager")
			if mario_manager and mario_manager.get("_mario_data"):
				var m_data = mario_manager.get("_mario_data")
				if m_data and m_data.dialogic_character and m_data.dialogic_character.resource_path == char_path:
					char_to_play = m_data

		# --- PLAY AUDIO ---
		if char_to_play:
			play_dialogue_blip(char_to_play)

## Plays a character blip sound and emits the speaking signal for animations.
## Can be called externally (e.g. by CustomerSpawner on arrival).
func play_dialogue_blip(char_data: CustomerData) -> void:
	if char_data:
		if char_data.dialogue_blip_sound:
			dialogue_blip_player.pitch_scale = randf_range(0.95, 1.105)
			dialogue_blip_player.stream = char_data.dialogue_blip_sound
			# Apply the character's unique volume offset
			dialogue_blip_player.volume_db = char_data.dialogue_blip_volume
			dialogue_blip_player.play()
		
		# Notify system that character is "speaking" (triggers pulse animation)
		EventBus.dialogue_character_speaking.emit(char_data)

func _emit_music_change(stream: AudioStream) -> void:
	if not stream: return
	
	var title = "Unknown Track"
	if _song_titles.has(stream):
		title = _song_titles[stream]
	else:
		# Fallback: try to get title from filename if not in dict
		var path = stream.resource_path
		title = path.get_file().get_basename().capitalize()
	
	if title == _last_emitted_title:
		return
		
	_last_emitted_title = title
	EventBus.music_title_changed.emit(title)
