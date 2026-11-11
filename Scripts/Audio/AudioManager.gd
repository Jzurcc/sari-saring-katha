extends Node

## Music & Ambience Director.
## Coordinates soundtrack playlists, day/afternoon/dusk phase transitions,
## character theme crossfades, ambient environment audio, and delegates SFX/settings.

enum BGMPhase { NONE, MORNING, AFTERNOON, DUSK }

const FADE_DURATION: float = 0.5

var settings: AudioSettings = AudioSettings.new()
var sfx_pool: SFXPool

var bgm_player: AudioStreamPlayer
var theme_player: AudioStreamPlayer
var ambience_base: AudioStreamPlayer
var ambience_night: AudioStreamPlayer
var fridge_hum_player: AudioStreamPlayer

var base_volume_db: float = -6.0
var current_bgm_phase: BGMPhase = BGMPhase.NONE

# --- Soundtracks ---
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

var audio_calming_morning = preload("res://Audio/SFX/Calming Morning Sounds.mp3")
var audio_night_crickets = preload("res://Audio/SFX/Sounds of Night Crickets.mp3")
var sfx_fridge_hum = preload("res://Audio/SFX/refrigerator.mp3")

var character_themes: Dictionary = {}

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

var _time_of_day_node: Node = null
var _active_playlist: Array = []
var _playlist_index: int = 0
var _last_emitted_title: String = ""
var bgm_transition_tween: Tween
var crossfade_tween: Tween

func _ready() -> void:
	randomize()
	name = "AudioManager"
	process_mode = PROCESS_MODE_ALWAYS

	# 1. Initialize audio players
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

	fridge_hum_player = AudioStreamPlayer.new()
	fridge_hum_player.bus = "SFX"
	fridge_hum_player.stream = sfx_fridge_hum
	fridge_hum_player.volume_db = -9.0
	add_child(fridge_hum_player)

	fridge_hum_player.finished.connect(func(): if fridge_hum_player.stream: fridge_hum_player.play())
	bgm_player.finished.connect(_on_bgm_finished)
	theme_player.finished.connect(_on_theme_finished)
	ambience_base.finished.connect(func(): ambience_base.play())
	ambience_night.finished.connect(_on_ambience_night_finished)

	# 2. Attach SFX pool child
	sfx_pool = SFXPool.new()
	sfx_pool.name = "SFXPool"
	add_child(sfx_pool)

	# 3. Connect event bus signals
	EventBus.customer_spawned.connect(_on_customer_spawned)
	EventBus.customer_satisfied.connect(_on_customer_left)
	EventBus.customer_dismissed.connect(_on_customer_left)
	EventBus.day_started.connect(func(_d): _update_audio_for_time(5.0))

	# 4. Start base morning ambience
	ambience_base.stream = audio_calming_morning
	ambience_base.play(randf_range(0.0, ambience_base.stream.get_length()))

	# 5. Load settings
	settings.load_settings()

	# 6. Initial BGM phase
	_change_bgm_phase(BGMPhase.NONE)

	# 7. Listen to scene additions for reactive binding (replaces frame-polling)
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_bind_initial_scene")

func _bind_initial_scene() -> void:
	var current = get_tree().current_scene
	if current:
		if current.name in ["MainMenu", "IntroCutscene"]:
			_change_bgm_phase(BGMPhase.NONE)
		else:
			var tod = get_tree().root.find_child("TimeOfDay", true, false)
			if tod:
				_bind_time_of_day(tod)

func _on_node_added(node: Node) -> void:
	if node is TimeOfDay or node.name == "TimeOfDay":
		_bind_time_of_day(node)
	elif node.name in ["MainMenu", "IntroCutscene"]:
		_unbind_time_of_day()
		_change_bgm_phase(BGMPhase.NONE)

func _bind_time_of_day(tod: Node) -> void:
	if _time_of_day_node == tod:
		return
	_unbind_time_of_day()
	_time_of_day_node = tod
	if tod.has_signal("time_changed") and not tod.time_changed.is_connected(_on_tod_time_changed):
		tod.time_changed.connect(_on_tod_time_changed)
	var cur_time = tod.get("current_time")
	if cur_time != null:
		_update_audio_for_time(float(cur_time))

func _unbind_time_of_day() -> void:
	if is_instance_valid(_time_of_day_node):
		if _time_of_day_node.has_signal("time_changed") and _time_of_day_node.time_changed.is_connected(_on_tod_time_changed):
			_time_of_day_node.time_changed.disconnect(_on_tod_time_changed)
	_time_of_day_node = null

func _on_tod_time_changed(time: Variant) -> void:
	_update_audio_for_time(float(time))

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

func _change_bgm_phase(phase: BGMPhase) -> void:
	current_bgm_phase = phase

	var pool: Array = []
	match phase:
		BGMPhase.NONE:
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

	if pool.is_empty():
		return

	if phase == BGMPhase.NONE:
		_active_playlist = pool
	else:
		var original_first = pool[0]
		_active_playlist = pool.duplicate()
		_active_playlist.shuffle()
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
		bgm_player.volume_db = -80.0
		bgm_player.play()
		bgm_transition_tween = create_tween()
		bgm_transition_tween.tween_property(bgm_player, "volume_db", target_vol, FADE_DURATION).set_ease(Tween.EASE_IN)
		_emit_music_change(bgm_player.stream)
	)

func _update_fridge_hum(phase: BGMPhase) -> void:
	if not fridge_hum_player:
		return
	var should_play = (phase != BGMPhase.NONE)
	if should_play and not fridge_hum_player.playing:
		fridge_hum_player.play()
	elif not should_play and fridge_hum_player.playing:
		fridge_hum_player.stop()

func _on_bgm_finished() -> void:
	var last_song = _active_playlist[_playlist_index]
	_playlist_index += 1

	if _playlist_index >= _active_playlist.size():
		if current_bgm_phase == BGMPhase.NONE:
			_playlist_index = 0
		else:
			_active_playlist.shuffle()
			if _active_playlist.size() > 1 and _active_playlist[0] == last_song:
				var swap_idx = (randi() % (_active_playlist.size() - 1)) + 1
				var tmp = _active_playlist[0]
				_active_playlist[0] = _active_playlist[swap_idx]
				_active_playlist[swap_idx] = tmp
			_playlist_index = 0

	bgm_player.stream = _active_playlist[_playlist_index]
	bgm_player.play()
	_emit_music_change(bgm_player.stream)

func _on_theme_finished() -> void:
	theme_player.play()

func _on_customer_spawned(customer: Customer) -> void:
	if customer.customer_data and character_themes.has(customer.customer_data.resource_path):
		play_character_theme(character_themes[customer.customer_data.resource_path])

func _on_customer_left(_customer: Customer) -> void:
	stop_character_theme()

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

func _emit_music_change(stream: AudioStream) -> void:
	if not stream:
		return

	var title = "Unknown Track"
	if _song_titles.has(stream):
		title = _song_titles[stream]
	else:
		var path = stream.resource_path
		title = path.get_file().get_basename().capitalize()

	if title == _last_emitted_title:
		return

	_last_emitted_title = title
	EventBus.music_title_changed.emit(title)

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

	bgm_player.volume_db = base_volume_db
	theme_player.volume_db = -80.0
	ambience_base.volume_db = 2.0
	ambience_night.volume_db = -13.1


# ── Public Delegation API (Backwards Compatibility) ──────────────────────

func play_sfx(sfx_name: String) -> void:
	if sfx_pool:
		sfx_pool.play_sfx(sfx_name)

func play_dialogue_blip(char_data: CustomerData) -> void:
	if sfx_pool:
		sfx_pool.play_dialogue_blip(char_data)

func update_mute_in_background(value: bool) -> void:
	settings.update_mute_in_background(value)

func update_master_muted_by_user(value: bool) -> void:
	settings.update_master_muted_by_user(value)

func _notification(what: int) -> void:
	if settings:
		settings.handle_application_focus(what)
