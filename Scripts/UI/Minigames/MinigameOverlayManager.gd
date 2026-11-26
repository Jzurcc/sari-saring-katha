class_name MinigameOverlayManager
extends Node

## Manages interactive non-purchase minigame overlays (Mosquito Swat, Sipa, Teks Memory, Talisman Tracing).
## Can be triggered via EventBus.start_minigame, Dialogic signal_event ("minigame:sipa", "minigame:talisman", etc.),
## or quick playtest hotkeys (F6 = Mosquito, F7 = Sipa, F8 = Teks, F9 / 4 = Talisman).

const MosquitoSwatScript := preload("res://Scripts/UI/Minigames/MosquitoSwatMinigame.gd")
const SipaScript := preload("res://Scripts/UI/Minigames/SipaMinigame.gd")
const TeksMemoryScript := preload("res://Scripts/UI/Minigames/TeksMemoryMinigame.gd")
const TalismanTraceScript := preload("res://Scripts/UI/Minigames/TalismanTraceMinigame.gd")
const Juice := preload("res://Scripts/UI/Minigames/MinigameJuice.gd")

var mosquito_minigame: CanvasLayer
var sipa_minigame: CanvasLayer
var teks_minigame: CanvasLayer
var talisman_minigame: CanvasLayer
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _is_transitioning: bool = false
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

	talisman_minigame = TalismanTraceScript.new()
	talisman_minigame.name = "TalismanTraceMinigame"
	talisman_minigame.minigame_finished.connect(_on_minigame_finished.bind("talisman"))
	add_child(talisman_minigame)

	# Fullscreen black fade curtain for entering/exiting minigames
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "MinigameFadeLayer"
	_fade_layer.layer = 96
	_fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_layer.visible = false
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0.015, 0.012, 0.010, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_layer.add_child(_fade_rect)

	EventBus.start_minigame.connect(launch_minigame)
	if is_instance_valid(Dialogic) and not Dialogic.signal_event.is_connected(_on_dialogic_signal):
		Dialogic.signal_event.connect(_on_dialogic_signal)


func is_any_open() -> bool:
	return _is_transitioning \
		or (is_instance_valid(mosquito_minigame) and mosquito_minigame.is_open) \
		or (is_instance_valid(sipa_minigame) and sipa_minigame.is_open) \
		or (is_instance_valid(teks_minigame) and teks_minigame.is_open) \
		or (is_instance_valid(talisman_minigame) and talisman_minigame.is_open)


const LOLO_PILO_MINIGAMES: Array[String] = ["sipa", "teks"]

var _hidden_dialogic_nodes: Array[Node] = []


func _hide_dialogic_for_minigame() -> void:
	_hidden_dialogic_nodes.clear()
	if not is_instance_valid(Dialogic) or Dialogic.current_timeline == null:
		return
	Dialogic.paused = true
	if Dialogic.Text and Dialogic.Text.has_method("hide_textbox"):
		Dialogic.Text.hide_textbox(true)
	for text_node in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		if "textbox_root" in text_node and is_instance_valid(text_node.textbox_root) and text_node.textbox_root.visible:
			text_node.textbox_root.visible = false
			_hidden_dialogic_nodes.append(text_node.textbox_root)
	var layout = Dialogic.Styles.get_layout_node()
	if is_instance_valid(layout):
		if "visible" in layout and layout.visible:
			layout.visible = false
			_hidden_dialogic_nodes.append(layout)
		for ch in layout.get_children():
			if (ch is CanvasLayer or ch is CanvasItem) and ch.visible:
				ch.visible = false
				_hidden_dialogic_nodes.append(ch)


func _restore_dialogic_after_minigame() -> void:
	for n in _hidden_dialogic_nodes:
		if is_instance_valid(n) and "visible" in n:
			n.visible = true
	_hidden_dialogic_nodes.clear()
	if is_instance_valid(Dialogic):
		Dialogic.paused = false
		if Dialogic.current_timeline != null and Dialogic.Text and Dialogic.Text.has_method("show_textbox"):
			Dialogic.Text.show_textbox(true)


func launch_minigame(minigame_id: String, config: Dictionary = {}) -> void:
	if is_any_open():
		return
	var id := minigame_id.strip_edges().to_lower()
	if id == "lolo_pilo_random" or id == "random":
		id = LOLO_PILO_MINIGAMES[randi() % LOLO_PILO_MINIGAMES.size()]
	var target: CanvasLayer = null
	var resolved_id := ""
	match id:
		"mosquito", "mosquito_swat", "lamok":
			resolved_id = "mosquito"
			target = mosquito_minigame
		"sipa":
			resolved_id = "sipa"
			target = sipa_minigame
		"teks", "teks_memory":
			resolved_id = "teks"
			target = teks_minigame
		"talisman", "anting", "anting_anting", "brahim":
			resolved_id = "talisman"
			target = talisman_minigame
		_:
			LogManager.warning("MinigameOverlayManager", "Unknown minigame id: %s" % minigame_id)
			return

	_transition_into_minigame(resolved_id, target, config)


func _transition_into_minigame(resolved_id: String, target: CanvasLayer, config: Dictionary) -> void:
	_is_transitioning = true
	_active_id = resolved_id
	_hide_dialogic_for_minigame()
	Juice.play_sfx("tab_switch", 0.78, -3.0)

	# Fade to black curtain
	_fade_layer.visible = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_rect.color.a = 0.0
	var tw_in := create_tween()
	tw_in.tween_property(_fade_rect, "color:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw_in.finished
	if not is_inside_tree():
		_is_transitioning = false
		return

	# Open minigame under cover of black, brief beat, then fade back in
	target.open_minigame(config)
	await get_tree().create_timer(0.06).timeout
	if not is_inside_tree():
		_is_transitioning = false
		return

	var tw_out := create_tween()
	tw_out.tween_property(_fade_rect, "color:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw_out.finished
	if is_instance_valid(_fade_layer):
		_fade_layer.visible = false
	_is_transitioning = false


func _play_exit_fade() -> void:
	if not is_instance_valid(_fade_layer) or not is_instance_valid(_fade_rect):
		return
	_fade_layer.visible = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.color.a = 0.65
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if is_instance_valid(_fade_layer) and not _is_transitioning:
			_fade_layer.visible = false
	)


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
				launch_minigame("teks")
			KEY_2:
				get_viewport().set_input_as_handled()
				launch_minigame("mosquito")
			KEY_3:
				get_viewport().set_input_as_handled()
				launch_minigame("sipa")
			KEY_4:
				get_viewport().set_input_as_handled()
				launch_minigame("talisman")
			KEY_F6:
				get_viewport().set_input_as_handled()
				launch_minigame("mosquito")
			KEY_F7:
				get_viewport().set_input_as_handled()
				launch_minigame("sipa")
			KEY_F8:
				get_viewport().set_input_as_handled()
				launch_minigame("teks")
			KEY_F9:
				get_viewport().set_input_as_handled()
				launch_minigame("talisman")


func _on_minigame_finished(won: bool, result: Dictionary, minigame_id: String) -> void:
	_active_id = ""
	_play_exit_fade()
	_restore_dialogic_after_minigame()
	# Award Reputation to the active counter customer (e.g. Lolo Pilo or Mosquito complainant)
	var spawner := get_tree().get_first_node_in_group("customer_spawner")
	if spawner and spawner.get("current_customer") and is_instance_valid(spawner.current_customer):
		var cust = spawner.current_customer
		if cust.customer_data and is_instance_valid(CharacterProgressionManager):
			var rep_gain := 15 if won else 8
			if minigame_id == "sipa":
				var kicks := int(result.get("kicks", 0))
				rep_gain = 22 if kicks >= 32 else (15 if kicks >= 6 else 8)
			CharacterProgressionManager.add_reputation(cust.customer_data.resource_path, rep_gain, "minigame_" + minigame_id)
	if minigame_id == "sipa":
		var kicks := int(result.get("kicks", 0))
		var xp_cap := int(result.get("xp_cap", 32))
		var capped_kicks := mini(kicks, xp_cap)
		if capped_kicks > 0:
			var xp_gain := capped_kicks
			var cash_gain := float(capped_kicks)
			if is_instance_valid(StoryManager):
				StoryManager.add_player_xp(xp_gain, "minigame_sipa")
			var gm := get_tree().get_first_node_in_group("game_manager")
			if gm and "money" in gm:
				gm.money += cash_gain
				EventBus.money_changed.emit(gm.money)
			var title := "New Sipa Record!" if kicks > xp_cap else "Sipa Complete!"
			var cap_note := " (max cap)" if kicks >= xp_cap else ""
			EventBus.show_notification.emit(title, "+₱%d  •  +%d XP%s" % [int(cash_gain), xp_gain, cap_note], "purchase")
	elif minigame_id == "talisman" and won:
		var lvl := clampi(int(result.get("level", 1)), 1, 10)
		var acc := int(result.get("accuracy", 0))
		var xp_gain := 15 + lvl * 2
		var cash_gain := float(15 + lvl * 2)
		if is_instance_valid(StoryManager):
			StoryManager.add_player_xp(xp_gain, "minigame_talisman")
		var gm := get_tree().get_first_node_in_group("game_manager")
		if gm and "money" in gm:
			gm.money += cash_gain
			EventBus.money_changed.emit(gm.money)
		EventBus.show_notification.emit("Anting-Anting Empowered!", "%d%% Accuracy  •  +₱%d  •  +%d XP" % [acc, int(cash_gain), xp_gain], "purchase")
	elif won:
		if is_instance_valid(StoryManager):
			StoryManager.add_player_xp(15, "minigame_" + minigame_id)
		var gm := get_tree().get_first_node_in_group("game_manager")
		if gm and "money" in gm:
			gm.money += 15.0
			EventBus.money_changed.emit(gm.money)
		EventBus.show_notification.emit("Minigame Victory!", "+₱15  •  +15 XP", "purchase")
	EventBus.minigame_completed.emit(minigame_id, won, result)
