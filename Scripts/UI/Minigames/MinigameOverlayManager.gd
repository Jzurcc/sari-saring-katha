class_name MinigameOverlayManager
extends Node

## Manages interactive non-purchase minigame overlays (Mosquito Swat, Sipa, Teks Memory).
## Can be triggered via EventBus.start_minigame, Dialogic signal_event ("minigame:sipa", etc.),
## or quick playtest hotkeys (F6 = Mosquito, F7 = Sipa, F8 = Teks).

const MosquitoSwatScript := preload("res://Scripts/UI/Minigames/MosquitoSwatMinigame.gd")
const SipaScript := preload("res://Scripts/UI/Minigames/SipaMinigame.gd")
const TeksMemoryScript := preload("res://Scripts/UI/Minigames/TeksMemoryMinigame.gd")

var mosquito_minigame: CanvasLayer
var sipa_minigame: CanvasLayer
var teks_minigame: CanvasLayer
var _active_id: String = ""


func _ready() -> void:
	mosquito_minigame = MosquitoSwatScript.new()
	mosquito_minigame.name = "MosquitoSwatMinigame"
	mosquito_minigame.minigame_finished.connect(_on_minigame_finished.bind("mosquito"))
	add_child(mosquito_minigame)

	sipa_minigame = SipaScript.new()
	sipa_minigame.name = "SipaMinigame"
	sipa_minigame.minigame_finished.connect(_on_minigame_finished.bind("sipa"))
	add_child(sipa_minigame)

	teks_minigame = TeksMemoryScript.new()
	teks_minigame.name = "TeksMemoryMinigame"
	teks_minigame.minigame_finished.connect(_on_minigame_finished.bind("teks"))
	add_child(teks_minigame)

	EventBus.start_minigame.connect(launch_minigame)
	if is_instance_valid(Dialogic) and not Dialogic.signal_event.is_connected(_on_dialogic_signal):
		Dialogic.signal_event.connect(_on_dialogic_signal)


func is_any_open() -> bool:
	return (is_instance_valid(mosquito_minigame) and mosquito_minigame.is_open) \
		or (is_instance_valid(sipa_minigame) and sipa_minigame.is_open) \
		or (is_instance_valid(teks_minigame) and teks_minigame.is_open)


const LOLO_PILO_MINIGAMES: Array[String] = ["sipa", "teks"]

func launch_minigame(minigame_id: String, config: Dictionary = {}) -> void:
	if is_any_open():
		return
	var id := minigame_id.strip_edges().to_lower()
	if id == "lolo_pilo_random" or id == "random":
		id = LOLO_PILO_MINIGAMES[randi() % LOLO_PILO_MINIGAMES.size()]
	match id:
		"mosquito", "mosquito_swat", "lamok":
			_active_id = "mosquito"
			if is_instance_valid(Dialogic) and Dialogic.current_timeline != null:
				Dialogic.paused = true
			mosquito_minigame.open_minigame(config)
		"sipa":
			_active_id = "sipa"
			if is_instance_valid(Dialogic) and Dialogic.current_timeline != null:
				Dialogic.paused = true
			sipa_minigame.open_minigame(config)
		"teks", "teks_memory":
			_active_id = "teks"
			if is_instance_valid(Dialogic) and Dialogic.current_timeline != null:
				Dialogic.paused = true
			teks_minigame.open_minigame(config)
		_:
			LogManager.warning("MinigameOverlayManager", "Unknown minigame id: %s" % minigame_id)


func _on_dialogic_signal(arg: String) -> void:
	var raw := str(arg).strip_edges().to_lower()
	if raw.begins_with("minigame:"):
		launch_minigame(raw.substr("minigame:".length()))
	elif raw.begins_with("start_minigame:"):
		launch_minigame(raw.substr("start_minigame:".length()))


func _unhandled_input(event: InputEvent) -> void:
	if is_any_open():
		return
	if not get_tree().get_nodes_in_group("storefront_canvas_active").is_empty():
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		match event.keycode:
			KEY_1:
				get_viewport().set_input_as_handled()
				if is_instance_valid(StoryManager):
					StoryManager.debug_force_next_customer_id = "lolopilo"
					EventBus.show_notification.emit("Debug Hotkey [1]", "Lolo Pilo queued as the next customer!", "interact")
			KEY_2:
				get_viewport().set_input_as_handled()
				launch_minigame("mosquito")
			KEY_F6:
				get_viewport().set_input_as_handled()
				launch_minigame("mosquito")
			KEY_F7:
				get_viewport().set_input_as_handled()
				launch_minigame("sipa")
			KEY_F8:
				get_viewport().set_input_as_handled()
				launch_minigame("teks")


func _on_minigame_finished(won: bool, result: Dictionary, minigame_id: String) -> void:
	_active_id = ""
	if is_instance_valid(Dialogic):
		Dialogic.paused = false
	if won:
		if is_instance_valid(StoryManager):
			StoryManager.add_player_xp(15, "minigame_" + minigame_id)
		var gm := get_tree().get_first_node_in_group("game_manager")
		if gm and "money" in gm:
			gm.money += 15.0
			EventBus.money_changed.emit(gm.money)
		EventBus.show_notification.emit("Minigame Victory!", "+₱15.00 & +15 Player XP earned!", "purchase")
	EventBus.minigame_completed.emit(minigame_id, won, result)
