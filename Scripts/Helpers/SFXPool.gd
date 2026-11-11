class_name SFXPool
extends Node

## Manages pooled sound effect players, the SFX library, volume offsets,
## and character voice blip audio.

const SFX_POOL_SIZE: int = 8

var dialogue_blip_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player_idx: int = 0

# --- SFX Preloads ---
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

var sfx_library: Dictionary = {}
var sfx_volume_offsets: Dictionary = {}

func _ready() -> void:
	_init_library()

	dialogue_blip_player = AudioStreamPlayer.new()
	dialogue_blip_player.bus = "Voices"
	add_child(dialogue_blip_player)

	for i in range(SFX_POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)

	EventBus.request_sfx.connect(play_sfx)
	call_deferred("_connect_dialogic")

func _init_library() -> void:
	sfx_library = {
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

	sfx_volume_offsets = {
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

func play_sfx(sfx_name: String) -> void:
	if sfx_library.has(sfx_name):
		var p = sfx_players[_next_sfx_player_idx]
		_next_sfx_player_idx = (_next_sfx_player_idx + 1) % SFX_POOL_SIZE

		p.stream = sfx_library[sfx_name]
		p.pitch_scale = randf_range(0.9, 1.1)

		if sfx_volume_offsets.has(sfx_name):
			p.volume_db = sfx_volume_offsets[sfx_name]
		else:
			p.volume_db = 0.0

		p.play()

func play_dialogue_blip(char_data: CustomerData) -> void:
	if char_data:
		if char_data.dialogue_blip_sound:
			dialogue_blip_player.pitch_scale = randf_range(0.95, 1.105)
			dialogue_blip_player.stream = char_data.dialogue_blip_sound
			dialogue_blip_player.volume_db = char_data.dialogue_blip_volume
			dialogue_blip_player.play()

		EventBus.dialogue_character_speaking.emit(char_data)

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

		# Strategy 1: Active customer from CustomerSpawner
		var spawner_nodes = get_tree().get_nodes_in_group("customer_spawner")
		if not spawner_nodes.is_empty():
			var spawner = spawner_nodes[0]
			if spawner.current_customer and spawner.current_customer.customer_data:
				if spawner.current_customer.customer_data.character_name == info.character.display_name or info.character.display_name == "???":
					char_to_play = spawner.current_customer.customer_data

		# Strategy 2: Match by specific .dch resource path
		if char_to_play == null:
			for c in story_mgr.available_characters:
				if c.dialogic_character and c.dialogic_character.resource_path == char_path:
					char_to_play = c
					break

		# Strategy 3: Match generic "Customer" by display_name fallback
		if char_to_play == null and (char_path.ends_with("Customer.dch") or char_path == ""):
			for c in story_mgr.available_characters:
				if c.character_name == info.character.display_name:
					char_to_play = c
					break

		# Strategy 4: Match Uncle Mario
		if char_to_play == null:
			var mario_manager = get_node_or_null("/root/MarioManager")
			if mario_manager and mario_manager.get("_mario_data"):
				var m_data = mario_manager.get("_mario_data")
				if m_data and m_data.dialogic_character and m_data.dialogic_character.resource_path == char_path:
					char_to_play = m_data

		if char_to_play:
			play_dialogue_blip(char_to_play)
