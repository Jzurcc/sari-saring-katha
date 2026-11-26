extends Node

## Music & Ambience Director.
## Coordinates soundtrack playlists, day/afternoon/dusk phase transitions,
## character theme crossfades, ambient environment audio, and delegates SFX/settings.

enum BGMPhase { NONE, MORNING, AFTERNOON, DUSK }

const FADE_DURATION: float = 0.5

var settings: AudioSettings = AudioSettings.new()
var sfx_pool: SFXPool

var bgm_player: AudioStreamPlayer
var override_player: AudioStreamPlayer
var ambience_base: AudioStreamPlayer
var ambience_night: AudioStreamPlayer
var fridge_hum_player: AudioStreamPlayer

var base_volume_db: float = -6.0
var current_bgm_phase: BGMPhase = BGMPhase.NONE

# --- Soundtracks (all by BGM President) ---
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

# New pool additions
var audio_weekend_plans = preload("res://Audio/Soundtracks/Weekend Plans.mp3")
var audio_nope = preload("res://Audio/Soundtracks/NOPE.mp3")
var audio_its_spring = preload("res://Audio/Soundtracks/It's Spring!!.mp3")
var audio_silly_day = preload("res://Audio/Soundtracks/A Silly Day.mp3")
var audio_ready_to_eat = preload("res://Audio/Soundtracks/Ready to Eat.mp3")
var audio_happy_hop = preload("res://Audio/Soundtracks/Happy Hop.mp3")
var audio_little_steps = preload("res://Audio/Soundtracks/Little Steps.mp3")
var audio_dark_humor = preload("res://Audio/Soundtracks/Dark Humor.mp3")
var audio_halo_price_sole = preload("res://Audio/Soundtracks/What is Halo-price Sole.mp3")

# Special context override tracks
var audio_modern_times = preload("res://Audio/Soundtracks/Moddern Times.mp3")
var audio_so_what = preload("res://Audio/Soundtracks/So What.mp3")
var audio_eat_or_not: AudioStream = null

var audio_calming_morning = preload("res://Audio/SFX/Calming Morning Sounds.mp3")
var audio_night_crickets = preload("res://Audio/SFX/Sounds of Night Crickets.mp3")
var sfx_fridge_hum = preload("res://Audio/SFX/refrigerator.mp3")

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
	audio_naptime: "Naptime",
	audio_weekend_plans: "Weekend Plans",
	audio_nope: "NOPE",
	audio_its_spring: "It's Spring!!",
	audio_silly_day: "A Silly Day",
	audio_ready_to_eat: "Ready to Eat",
	audio_happy_hop: "Happy Hop",
	audio_little_steps: "Little Steps",
	audio_dark_humor: "Dark Humor",
	audio_halo_price_sole: "What is \"Halo-price Sole\"?",
	audio_modern_times: "Modern Times",
	audio_so_what: "So What",
}

var _time_of_day_node: Node = null
var _active_playlist: Array = []
var _playlist_index: int = 0
var _phase_bags: Dictionary = {} # BGMPhase -> Array of remaining unplayed AudioStreams
var _last_bgm_stream: AudioStream = null
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

	override_player = AudioStreamPlayer.new()
	override_player.bus = "Music"
	override_player.volume_db = -80.0
	add_child(override_player)

	# Load optional Eat or Not track if present in Audio/Soundtracks
	for ext in ["mp3", "ogg", "wav"]:
		var candidate := "res://Audio/Soundtracks/Eat or Not.%s" % ext
		if ResourceLoader.exists(candidate):
			audio_eat_or_not = load(candidate)
			if audio_eat_or_not:
				_song_titles[audio_eat_or_not] = "Eat or Not"
			break

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
	override_player.finished.connect(_on_override_finished)
	ambience_base.finished.connect(func(): ambience_base.play())
	ambience_night.finished.connect(_on_ambience_night_finished)

	# 2. Attach SFX pool child
	sfx_pool = SFXPool.new()
	sfx_pool.name = "SFXPool"
	add_child(sfx_pool)

	# 3. Connect event bus signals
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
	elif not bgm_player.playing and (not bgm_transition_tween or not bgm_transition_tween.is_valid()):
		# Recover if BGM stopped (e.g. after fade_out_everything or interrupted transition)
		_change_bgm_phase(new_phase)
	elif bgm_player.playing and not override_player.playing \
		and (not bgm_transition_tween or not bgm_transition_tween.is_valid()) \
		and (not crossfade_tween or not crossfade_tween.is_valid()) \
		and bgm_player.volume_db < base_volume_db - 1.0:
		# Self-heal if BGM volume ever got stranded at -80 dB after an interrupted fade
		bgm_player.volume_db = base_volume_db

	if is_night and not ambience_night.playing:
		ambience_night.stream = audio_night_crickets
		ambience_night.play(randf_range(0.0, ambience_night.stream.get_length()))
	elif not is_night and ambience_night.playing:
		ambience_night.stop()

func _get_phase_pool(phase: BGMPhase) -> Array:
	match phase:
		BGMPhase.NONE:
			var scene = get_tree().current_scene
			if scene and scene.name == "MainMenu":
				return [audio_brunch, audio_autumn_wind]
			return [audio_autumn_wind]
		BGMPhase.MORNING:
			return [audio_boring_day, audio_brunch_ii, audio_kids_room, audio_weekend_plans, audio_nope, audio_its_spring]
		BGMPhase.AFTERNOON:
			return [audio_fantastic_idea, audio_not_me, audio_hermit_crab, audio_silly_day, audio_ready_to_eat, audio_happy_hop]
		BGMPhase.DUSK:
			return [audio_sleepy, audio_naptime, audio_little_steps, audio_dark_humor, audio_halo_price_sole]
	return []

## Draws the next track from a persistent per-phase shuffle bag so every track in a phase
## is heard before any track repeats (even across consecutive days).
func _draw_next_track_for_phase(phase: BGMPhase) -> AudioStream:
	var pool := _get_phase_pool(phase)
	if pool.is_empty():
		return null
	if phase == BGMPhase.NONE:
		if _active_playlist != pool:
			_active_playlist = pool
			_playlist_index = 0
		var s: AudioStream = _active_playlist[_playlist_index % _active_playlist.size()]
		_playlist_index = (_playlist_index + 1) % _active_playlist.size()
		return s

	var bag: Array = _phase_bags.get(phase, [])
	if bag.is_empty():
		bag = pool.duplicate()
		bag.shuffle()
		# Avoid repeating the exact last played song right across a bag refill
		if bag.size() > 1 and bag[bag.size() - 1] == _last_bgm_stream:
			var swap_idx := randi() % (bag.size() - 1)
			var tmp = bag[bag.size() - 1]
			bag[bag.size() - 1] = bag[swap_idx]
			bag[swap_idx] = tmp
	var next_stream: AudioStream = bag.pop_back()
	_phase_bags[phase] = bag
	_last_bgm_stream = next_stream
	return next_stream

func _change_bgm_phase(phase: BGMPhase) -> void:
	current_bgm_phase = phase

	var next_stream := _draw_next_track_for_phase(phase)
	if next_stream == null:
		return

	_update_fridge_hum(phase)

	if bgm_transition_tween and bgm_transition_tween.is_valid():
		bgm_transition_tween.kill()

	bgm_transition_tween = create_tween()
	var is_first_play = not bgm_player.playing or bgm_player.volume_db <= -79.0

	if not is_first_play:
		bgm_transition_tween.tween_property(bgm_player, "volume_db", -80.0, FADE_DURATION).set_ease(Tween.EASE_OUT)
		bgm_transition_tween.tween_callback(func(): bgm_player.stop())

	bgm_transition_tween.tween_callback(func():
		bgm_player.stream = next_stream
		bgm_player.volume_db = -80.0
		bgm_player.play()
		if not override_player.playing:
			_emit_music_change(bgm_player.stream)
	)
	var target_vol = -80.0 if override_player.playing else base_volume_db
	bgm_transition_tween.tween_property(bgm_player, "volume_db", target_vol, FADE_DURATION).set_ease(Tween.EASE_IN)

func _update_fridge_hum(phase: BGMPhase) -> void:
	if not fridge_hum_player:
		return
	var should_play = (phase != BGMPhase.NONE)
	if should_play and not fridge_hum_player.playing:
		fridge_hum_player.play()
	elif not should_play and fridge_hum_player.playing:
		fridge_hum_player.stop()

func _on_bgm_finished() -> void:
	var next_stream := _draw_next_track_for_phase(current_bgm_phase)
	if next_stream == null:
		return

	bgm_player.stream = next_stream
	bgm_player.volume_db = -80.0 if override_player.playing else base_volume_db
	bgm_player.play()
	if not override_player.playing:
		_emit_music_change(bgm_player.stream)

func _on_override_finished() -> void:
	if override_player.stream:
		override_player.play()

## Crossfades the current BGM silently into the background (continuing to play at -80 dB)
## while an override track takes over.
func play_bgm_override(stream: AudioStream) -> void:
	if not stream:
		return
	if crossfade_tween and crossfade_tween.is_valid():
		crossfade_tween.kill()

	if override_player.stream != stream or not override_player.playing:
		override_player.stream = stream
		override_player.volume_db = -80.0
		override_player.play()

	crossfade_tween = create_tween()
	crossfade_tween.tween_property(bgm_player, "volume_db", -80.0, FADE_DURATION).set_ease(Tween.EASE_OUT)
	crossfade_tween.parallel().tween_property(override_player, "volume_db", base_volume_db, FADE_DURATION).set_ease(Tween.EASE_IN)

	_emit_music_change(override_player.stream)

func play_restock_bgm() -> void:
	play_bgm_override(audio_modern_times)

func play_minigame_bgm(minigame_id: String) -> void:
	if minigame_id == "talisman":
		play_bgm_override(audio_eat_or_not if audio_eat_or_not != null else audio_so_what)
	else:
		play_bgm_override(audio_so_what)

## Fades out the override track and brings the silently-playing background BGM back up.
func stop_bgm_override() -> void:
	if not override_player.playing:
		return

	if crossfade_tween and crossfade_tween.is_valid():
		crossfade_tween.kill()

	crossfade_tween = create_tween()
	crossfade_tween.tween_property(bgm_player, "volume_db", base_volume_db, FADE_DURATION).set_ease(Tween.EASE_IN)
	crossfade_tween.parallel().tween_property(override_player, "volume_db", -80.0, FADE_DURATION).set_ease(Tween.EASE_OUT)
	crossfade_tween.tween_callback(func(): override_player.stop())

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
	if bgm_transition_tween and bgm_transition_tween.is_valid():
		bgm_transition_tween.kill()
	if crossfade_tween and crossfade_tween.is_valid():
		crossfade_tween.kill()

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(bgm_player, "volume_db", -80.0, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(override_player, "volume_db", -80.0, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(ambience_base, "volume_db", -80.0, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(ambience_night, "volume_db", -80.0, duration).set_ease(Tween.EASE_OUT)

	await tween.finished
	bgm_player.stop()
	override_player.stop()
	ambience_base.stop()
	ambience_night.stop()
	current_bgm_phase = BGMPhase.NONE

	bgm_player.volume_db = base_volume_db
	override_player.volume_db = -80.0
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
