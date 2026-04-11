extends Node

var bgm_player: AudioStreamPlayer
var theme_player: AudioStreamPlayer
var ambience_base: AudioStreamPlayer
var ambience_night: AudioStreamPlayer

var audio_boring_day = preload("res://Audio/A Boring Day.mp3")
var audio_fantastic_idea = preload("res://Audio/Fantastic Idea.mp3")
var audio_not_me = preload("res://Audio/Not ME.mp3")
var audio_sleepy = preload("res://Audio/Sleepy.mp3")
var audio_laughing_horse = preload("res://Audio/Laughing Horse.mp3")

var character_themes: Dictionary = {
	"KuyaKap": audio_laughing_horse
}

var audio_calming_morning = preload("res://Audio/Calming Morning Sounds.mp3")
var audio_night_crickets = preload("res://Audio/Sounds of Night Crickets.mp3")

enum BGMPhase { NONE, MORNING, AFTERNOON, DUSK }
var current_bgm_phase: BGMPhase = BGMPhase.NONE

var time_of_day_node: Node = null

var afternoon_playlist_index: int = 0
var afternoon_playlist: Array = []

func _ready() -> void:
	name = "AudioManager"
	
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Music"
	add_child(bgm_player)
	
	theme_player = AudioStreamPlayer.new()
	theme_player.bus = "Music"
	theme_player.volume_db = -80.0
	add_child(theme_player)
	
	ambience_base = AudioStreamPlayer.new()
	ambience_base.bus = "Master"
	add_child(ambience_base)
	
	ambience_night = AudioStreamPlayer.new()
	ambience_night.bus = "Master"
	add_child(ambience_night)
	
	afternoon_playlist = [audio_fantastic_idea, audio_not_me]
	
	bgm_player.finished.connect(_on_bgm_finished)
	theme_player.finished.connect(_on_theme_finished)
	ambience_base.finished.connect(func(): ambience_base.play())
	ambience_night.finished.connect(_on_ambience_night_finished)
	
	EventBus.customer_spawned.connect(_on_customer_spawned)
	EventBus.customer_satisfied.connect(_on_customer_left)
	EventBus.customer_dismissed.connect(_on_customer_left)
	
	# Start base ambience immediately
	ambience_base.stream = audio_calming_morning
	ambience_base.play()

func _process(_delta: float) -> void:
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

func _update_audio_for_time(time: float) -> void:
	var new_phase = BGMPhase.NONE
	var is_night = false
	
	if time >= 5.0 and time < 12.0:
		new_phase = BGMPhase.MORNING
	elif time >= 12.0 and time < 18.0:
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

func _change_bgm_phase(phase: BGMPhase) -> void:
	current_bgm_phase = phase
	bgm_player.stop()
	
	if phase == BGMPhase.MORNING:
		bgm_player.stream = audio_boring_day
	elif phase == BGMPhase.AFTERNOON:
		afternoon_playlist_index = 0
		bgm_player.stream = afternoon_playlist[afternoon_playlist_index]
	elif phase == BGMPhase.DUSK:
		bgm_player.stream = audio_sleepy
		
	bgm_player.play()

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
	crossfade_tween.parallel().tween_property(theme_player, "volume_db", 0.0, 1.5).set_ease(Tween.EASE_IN)

func stop_character_theme() -> void:
	if crossfade_tween and crossfade_tween.is_valid():
		crossfade_tween.kill()
		
	crossfade_tween = create_tween()
	crossfade_tween.tween_property(bgm_player, "volume_db", 0.0, 2.0).set_ease(Tween.EASE_IN)
	crossfade_tween.parallel().tween_property(theme_player, "volume_db", -80.0, 2.0).set_ease(Tween.EASE_OUT)
	crossfade_tween.tween_callback(func(): theme_player.stop())

func _on_ambience_night_finished() -> void:
	if current_bgm_phase == BGMPhase.DUSK:
		ambience_night.play()
