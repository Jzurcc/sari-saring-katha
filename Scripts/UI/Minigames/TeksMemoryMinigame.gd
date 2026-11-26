class_name TeksMemoryMinigame
extends CanvasLayer

## Classic Filipino Teks Memory Match Minigame (Fullscreen Vignette UI).
## Vintage Teks cards featuring customer portraits, pastel backgrounds,
## rectangular double borders, and crisp power numbers.

signal minigame_finished(won: bool, result: Dictionary)

const Juice := preload("res://Scripts/UI/Minigames/MinigameJuice.gd")

const PORTRAIT_PATHS: Array[String] = [
	"res://Assets/characters/portraits/Brahim Face.png",
	"res://Assets/characters/portraits/Buboy Face.png",
	"res://Assets/characters/portraits/Danilo Face.png",
	"res://Assets/characters/portraits/Kuya_Kap Face.png",
	"res://Assets/characters/portraits/LoloPilo Face.png",
	"res://Assets/characters/portraits/ManangAna Face.png",
	"res://Assets/characters/portraits/ReynaMayari Face.png",
	"res://Assets/characters/portraits/Rodel Face.png",
	"res://Assets/characters/portraits/Rosalyn Face.png",
	"res://Assets/characters/portraits/Sarimanok Face.png",
	"res://Assets/characters/portraits/TK Face.png",
	"res://Assets/characters/portraits/UncleMario Face.png",
]

const PASTEL_BACKGROUNDS: Array[Color] = [
	Color(0.99, 0.87, 0.82, 1.0), # Soft peach
	Color(0.84, 0.96, 0.88, 1.0), # Pastel mint
	Color(0.83, 0.92, 0.99, 1.0), # Baby sky blue
	Color(0.92, 0.86, 0.98, 1.0), # Soft lavender
	Color(0.99, 0.95, 0.78, 1.0), # Butter cream
	Color(0.99, 0.84, 0.90, 1.0), # Rose pink
	Color(0.84, 0.96, 0.96, 1.0), # Soft aqua
	Color(0.96, 0.92, 0.84, 1.0), # Warm apricot
]

const VIGNETTE_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.025, 0.02, 0.016, 0.92);
void fragment() {
	vec2 d = UV - vec2(0.5);
	float dist = length(d * vec2(1.12, 1.0));
	float vig = smoothstep(0.14, 0.74, dist);
	COLOR = vec4(tint.rgb, mix(0.46, tint.a, vig));
}
"""

const TOTAL_PAIRS := 6
const MAX_TRIES := 14

const NEIGHBOR_RECORDS: Array[Dictionary] = [
	{"name": "Lolo Pilo", "pairs": 6, "left": 8, "label": "6/6 (+8)", "portrait": "res://Assets/characters/portraits/LoloPilo Face.png"},
	{"name": "Buboy", "pairs": 6, "left": 5, "label": "6/6 (+5)", "portrait": "res://Assets/characters/portraits/Buboy Face.png"},
	{"name": "T.K.", "pairs": 6, "left": 2, "label": "6/6 (+2)", "portrait": "res://Assets/characters/portraits/TK Face.png"},
	{"name": "Kuya Kap", "pairs": 5, "left": 0, "label": "5/6", "portrait": "res://Assets/characters/portraits/Kuya_Kap Face.png"},
	{"name": "Danilo", "pairs": 3, "left": 0, "label": "3/6", "portrait": "res://Assets/characters/portraits/Danilo Face.png"},
	{"name": "Manang Ana", "pairs": 0, "left": 0, "label": "0", "portrait": "res://Assets/characters/portraits/ManangAna Face.png"},
	{"name": "Rosalyn", "pairs": 0, "left": 0, "label": "0", "portrait": "res://Assets/characters/portraits/Rosalyn Face.png"},
]

var is_open: bool = false
var _locked: bool = false
var _total_pairs: int = TOTAL_PAIRS
var _max_tries: int = MAX_TRIES
var _pairs_found: int = 0
var _tries_left: int = MAX_TRIES
var _streak: int = 0
var _cards: Array[Dictionary] = []
var _flipped: Array[Dictionary] = []

var _root: Control
var _grid: GridContainer
var _pairs_val_lbl: Label
var _tries_val_lbl: Label
var _streak_pill: PanelContainer
var _streak_lbl: Label
var _intro_overlay: ColorRect
var _intro_panel: PanelContainer
var _result_overlay: ColorRect
var _result_panel: PanelContainer
var _result_title: Label
var _result_sub: Label
var _result_stats_row: HBoxContainer
var _board_rows: Array[Dictionary] = []
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED


static func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Texture2D:
			return res
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


func _ready() -> void:
	layer = 42
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func open_minigame(_config: Dictionary = {}) -> void:
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_open = true
	visible = true
	add_to_group("minigame_overlay_active")
	_start_round()
	if Juice.are_minigame_tutorials_enabled():
		_locked = true
		_intro_overlay.visible = true
		call_deferred("_pop_intro_deferred")
	else:
		_intro_overlay.visible = false
		_locked = false


func _pop_intro_deferred() -> void:
	if is_instance_valid(_intro_panel):
		Juice.pop_panel_in(_intro_panel)


func _on_intro_start() -> void:
	Juice.play_sfx("tab_switch", 1.15)
	_intro_overlay.visible = false
	_locked = false


func close_minigame(won: bool = false, emit_result: bool = true) -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if is_in_group("minigame_overlay_active"):
		remove_from_group("minigame_overlay_active")
	Input.mouse_mode = _prev_mouse_mode
	if emit_result:
		minigame_finished.emit(won, {
			"id": "teks",
			"pairs": _pairs_found,
			"total_pairs": _total_pairs,
			"tries_left": _tries_left,
		})


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _result_overlay.visible:
				close_minigame(bool(_result_panel.get_meta("won", false)), true)
			else:
				close_minigame(false, true)
		elif _intro_overlay.visible and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
			get_viewport().set_input_as_handled()
			_on_intro_start()
		elif _result_overlay.visible and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
			get_viewport().set_input_as_handled()
			close_minigame(bool(_result_panel.get_meta("won", false)), true)


func _start_round() -> void:
	_locked = false
	var day_idx := maxi(0, StoryManager.day - 1) if is_instance_valid(StoryManager) else 0
	if day_idx >= 6:
		_total_pairs = 10
		_max_tries = 22
		_grid.columns = 5
	elif day_idx >= 3:
		_total_pairs = 8
		_max_tries = 18
		_grid.columns = 4
	else:
		_total_pairs = TOTAL_PAIRS
		_max_tries = MAX_TRIES
		_grid.columns = 4
	_pairs_found = 0
	_tries_left = _max_tries
	_streak = 0
	_flipped.clear()
	_cards.clear()
	_result_overlay.visible = false
	for ch in _grid.get_children():
		_grid.remove_child(ch)
		ch.queue_free()

	var pool := PORTRAIT_PATHS.duplicate()
	pool.shuffle()
	var pastels := PASTEL_BACKGROUNDS.duplicate()
	pastels.shuffle()

	var deck: Array[Dictionary] = []
	for i in range(_total_pairs):
		var path: String = pool[i % pool.size()]
		var bg: Color = pastels[i % pastels.size()]
		var power: int = randi_range(12000, 999999)
		var tex := _load_tex(path)
		for _copy in range(2):
			deck.append({
				"pair_id": i,
				"tex": tex,
				"pastel": bg,
				"power": power,
			})
	deck.shuffle()

	for idx in range(deck.size()):
		var entry: Dictionary = deck[idx]
		var card_info := _create_teks_card(entry)
		_cards.append(card_info)
		_grid.add_child(card_info["root"])

	_refresh_hud()


func _create_teks_card(entry: Dictionary) -> Dictionary:
	var card_size := Vector2(126, 168) if _total_pairs <= 6 else (Vector2(110, 144) if _total_pairs <= 8 else Vector2(102, 134))
	var holder := Control.new()
	holder.custom_minimum_size = card_size
	holder.pivot_offset = card_size * 0.5
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Back face (vintage crimson/gold geometric Teks card back)
	var back := PanelContainer.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := UIStyle.create_flat_stylebox(Color(0.36, 0.12, 0.14, 1.0), 8, 8, 8)
	bs.border_color = Color(0.95, 0.86, 0.68, 0.95)
	bs.set_border_width_all(4)
	bs.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	bs.shadow_size = 10
	bs.shadow_offset = Vector2(0, 4)
	back.add_theme_stylebox_override("panel", bs)
	holder.add_child(back)

	var back_pattern := Control.new()
	back_pattern.set_anchors_preset(Control.PRESET_FULL_RECT)
	back_pattern.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_pattern.draw.connect(func():
		var sz := back_pattern.size
		var rect := Rect2(4, 4, sz.x - 8, sz.y - 8)
		back_pattern.draw_rect(rect, Color(0.92, 0.74, 0.36, 0.85), false, 2.0)
		var c := sz * 0.5
		var pts := PackedVector2Array([
			c + Vector2(0, -30), c + Vector2(22, 0),
			c + Vector2(0, 30), c + Vector2(-22, 0)
		])
		back_pattern.draw_colored_polygon(pts, Color(0.92, 0.74, 0.36, 0.25))
		back_pattern.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.95, 0.80, 0.42, 0.90), 2.0)
	)
	back.add_child(back_pattern)

	# Front face (rectangular Teks border + pastel background + portrait + crisp Fredoka power)
	var front := PanelContainer.new()
	front.set_anchors_preset(Control.PRESET_FULL_RECT)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.visible = false
	var f_outer := UIStyle.create_flat_stylebox(Color(0.98, 0.95, 0.88, 1.0), 6, 7, 7)
	f_outer.border_color = Color(0.22, 0.16, 0.12, 0.95)
	f_outer.set_border_width_all(3)
	f_outer.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	f_outer.shadow_size = 10
	f_outer.shadow_offset = Vector2(0, 4)
	front.add_theme_stylebox_override("panel", f_outer)
	holder.add_child(front)

	var inner := PanelContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f_inner := UIStyle.create_flat_stylebox(entry["pastel"], 3, 5, 5)
	f_inner.border_color = Color(0.24, 0.18, 0.14, 0.88)
	f_inner.set_border_width_all(2)
	inner.add_theme_stylebox_override("panel", f_inner)
	front.add_child(inner)

	var inner_v := VBoxContainer.new()
	inner_v.add_theme_constant_override("separation", 3)
	inner_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(inner_v)

	var portrait := TextureRect.new()
	portrait.texture = entry["tex"]
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_v.add_child(portrait)

	var power_val: int = int(entry["power"])
	var power_lbl := Label.new()
	@warning_ignore("integer_division")
	power_lbl.text = "%d,%03d" % [power_val / 1000, power_val % 1000]
	power_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	power_lbl.add_theme_font_size_override("font_size", 15 if _total_pairs <= 6 else 14)
	power_lbl.add_theme_color_override("font_color", Color(0.20, 0.11, 0.06, 0.98))
	power_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_v.add_child(power_lbl)

	var card_dict := {
		"root": holder,
		"back": back,
		"front": front,
		"front_style": f_outer,
		"pair_id": int(entry["pair_id"]),
		"face_up": false,
		"matched": false,
	}

	holder.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_card_clicked(card_dict)
	)
	holder.mouse_entered.connect(func():
		if not _locked and not bool(card_dict["face_up"]) and not bool(card_dict["matched"]):
			Juice.play_sfx("ui_hover", 1.12, -10.0)
			var htw := holder.create_tween()
			htw.tween_property(holder, "scale", Vector2(1.06, 1.06), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	holder.mouse_exited.connect(func():
		if not bool(card_dict["face_up"]) and not bool(card_dict["matched"]):
			var htw := holder.create_tween()
			htw.tween_property(holder, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	return card_dict


func _on_card_clicked(card: Dictionary) -> void:
	if _locked or bool(card["face_up"]) or bool(card["matched"]):
		return
	_flip_card(card, true)
	_flipped.append(card)
	Juice.play_sfx("tab_switch", 1.08, 0.0)

	if _flipped.size() == 2:
		_locked = true
		var a: Dictionary = _flipped[0]
		var b: Dictionary = _flipped[1]
		if int(a["pair_id"]) == int(b["pair_id"]):
			a["matched"] = true
			b["matched"] = true
			_pairs_found += 1
			_streak += 1
			_flipped.clear()
			_refresh_hud()
			Juice.pop_control(_pairs_val_lbl, 1.24, 0.18)
			# Escalating match fanfare + spark bursts + gilded matched border!
			var match_pitch := minf(1.65, 1.0 + float(_streak) * 0.13)
			Juice.play_sfx("pickup", match_pitch, 1.5)
			Juice.play_sfx("interact", match_pitch + 0.18, 0.0)
			for m in [a, b]:
				var st: StyleBoxFlat = m["front_style"]
				st.border_color = Juice.COL_GOLD
				var r: Control = m["root"]
				var center_pos := r.global_position + r.size * 0.5
				Juice.spawn_burst(_root, center_pos, Color(1.0, 0.88, 0.36), 10, 100.0)
				var tw := r.create_tween()
				tw.tween_property(r, "scale", Vector2(1.12, 1.12), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(r, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_SINE)
			_spawn_match_label(
				((a["root"] as Control).global_position + (b["root"] as Control).global_position) * 0.5 + Vector2(63, 40),
				"MATCH!" if _streak <= 1 else "STREAK x%d!" % _streak,
				Juice.COL_SUCCESS if _streak <= 1 else Juice.COL_GOLD_BRIGHT
			)
			_locked = false
			if _pairs_found >= _total_pairs:
				_finish_round(true, "Teks Master!", "Matched all %d pairs with %d tries to spare!" % [_total_pairs, _tries_left])
		else:
			_streak = 0
			_tries_left = maxi(0, _tries_left - 1)
			_refresh_hud()
			Juice.play_sfx("drop", 0.78, 0.0)
			for m in [a, b]:
				var r: Control = m["root"]
				var wtw := r.create_tween()
				wtw.tween_property(r, "rotation", 0.06, 0.06)
				wtw.tween_property(r, "rotation", -0.06, 0.08)
				wtw.tween_property(r, "rotation", 0.0, 0.06)
			var timer := get_tree().create_timer(0.65)
			timer.timeout.connect(func():
				if not is_open:
					return
				Juice.play_sfx("tab_switch", 0.84, -4.0)
				_flip_card(a, false)
				_flip_card(b, false)
				_flipped.clear()
				_locked = false
				if _tries_left <= 0 and _pairs_found < _total_pairs:
					_finish_round(false, "Out of Tries!", "Matched %d / %d Teks pairs." % [_pairs_found, _total_pairs])
			)


func _spawn_match_label(pos: Vector2, txt: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.position = pos - Vector2(54, 16)
	Juice.style_hud_label(lbl, UIStyle.FONT_FREDOKA_BOLD, 24, col, 5)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 44.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.55)
	tw.tween_callback(lbl.queue_free)


func _flip_card(card: Dictionary, show_front: bool) -> void:
	card["face_up"] = show_front
	var holder: Control = card["root"]
	var front: Control = card["front"]
	var back: Control = card["back"]
	var tw := holder.create_tween()
	tw.tween_property(holder, "scale:x", 0.02, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		front.visible = show_front
		back.visible = not show_front
	)
	tw.tween_property(holder, "scale:x", 1.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _refresh_hud() -> void:
	_pairs_val_lbl.text = "%d / %d" % [_pairs_found, _total_pairs]
	var low_tries := _tries_left <= 3
	_tries_val_lbl.text = "%d (!)" % _tries_left if low_tries else str(_tries_left)
	_tries_val_lbl.add_theme_color_override("font_color", Juice.COL_DANGER if low_tries else Juice.COL_GOLD_BRIGHT)
	if is_instance_valid(_streak_pill):
		if _streak >= 2:
			_streak_pill.visible = true
			_streak_lbl.text = "x%d Streak" % _streak
			Juice.pop_control(_streak_pill, 1.15, 0.16)
		else:
			_streak_pill.visible = false
	_refresh_leaderboard()


func _refresh_leaderboard() -> void:
	for item in _board_rows:
		var req_pairs: int = int(item["pairs"])
		var req_left: int = int(item["left"])
		var base_lbl: String = str(item["label"])
		var beaten := false
		if req_pairs == 0:
			beaten = _pairs_found >= 1
		elif req_pairs < TOTAL_PAIRS:
			beaten = _pairs_found > req_pairs
		else:
			beaten = _pairs_found >= TOTAL_PAIRS and _tries_left > req_left
		var nlbl: Label = item["name_lbl"]
		var slbl: Label = item["score_lbl"]
		if beaten:
			nlbl.add_theme_color_override("font_color", Juice.COL_SUCCESS)
			slbl.add_theme_color_override("font_color", Juice.COL_SUCCESS)
			slbl.text = "%s ✓" % base_lbl
		else:
			var is_zero := req_pairs == 0
			nlbl.add_theme_color_override("font_color", Juice.COL_MUTED if is_zero else Juice.COL_CREAM)
			slbl.add_theme_color_override("font_color", Juice.COL_MUTED if is_zero else Juice.COL_GOLD_BRIGHT)
			slbl.text = base_lbl


func _finish_round(won: bool, title: String, sub: String) -> void:
	_locked = true
	_result_title.text = title
	_result_title.add_theme_color_override("font_color", Juice.COL_SUCCESS if won else Juice.COL_DANGER)
	_result_sub.text = sub
	_result_panel.set_meta("won", won)

	for ch in _result_stats_row.get_children():
		_result_stats_row.remove_child(ch)
		ch.queue_free()
	_result_stats_row.add_child(Juice.make_stat_chip("Pairs", "%d / %d" % [_pairs_found, _total_pairs], Juice.COL_SUCCESS if won else Juice.COL_CREAM))
	_result_stats_row.add_child(Juice.make_stat_chip("Tries Left", str(_tries_left), Juice.COL_GOLD_BRIGHT if _tries_left > 0 else Juice.COL_DANGER))

	_result_overlay.visible = true
	call_deferred("_pop_result_deferred")
	if won:
		Juice.play_win_fanfare(self)
		var vp := get_viewport().get_visible_rect().size
		Juice.spawn_burst(_root, vp * Vector2(0.35, 0.45), Color(1.0, 0.88, 0.36), 14, 180.0)
		Juice.spawn_burst(_root, vp * Vector2(0.65, 0.45), Color(0.60, 0.96, 0.58), 14, 180.0)
	else:
		Juice.play_lose_sting(self)


func _pop_result_deferred() -> void:
	if is_instance_valid(_result_panel):
		Juice.pop_panel_in(_result_panel)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Fullscreen Vignette Backdrop
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	vig.material = mat
	_root.add_child(vig)

	# --- TOP SAFE-ZONE HEADER + CONTRASTING HUD BAR ---
	var header := VBoxContainer.new()
	header.anchor_left = 0.5
	header.anchor_right = 0.5
	header.anchor_top = 0.0
	header.offset_left = -320
	header.offset_right = 320
	header.offset_top = 22
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 6)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(header)

	var title := Label.new()
	title.text = "Teks Memory"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Juice.style_hud_label(title, UIStyle.FONT_FREDOKA_BOLD, 30, Juice.COL_GOLD_BRIGHT, 5)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title)

	var hud_center := HBoxContainer.new()
	hud_center.alignment = BoxContainer.ALIGNMENT_CENTER
	hud_center.add_theme_constant_override("separation", 10)
	hud_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(hud_center)

	var hud_pill := PanelContainer.new()
	hud_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_pill.add_theme_stylebox_override("panel", Juice.make_pill_style(Juice.COL_HUD_BG, Juice.COL_GOLD_SOFT, 14, 18, 8, 2))
	hud_center.add_child(hud_pill)

	var hud_row := HBoxContainer.new()
	hud_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hud_row.add_theme_constant_override("separation", 14)
	hud_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_pill.add_child(hud_row)

	# Pairs counter
	var p_box := HBoxContainer.new()
	p_box.alignment = BoxContainer.ALIGNMENT_CENTER
	p_box.add_theme_constant_override("separation", 7)
	p_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_row.add_child(p_box)

	p_box.add_child(Juice.make_icon_rect(Juice.ICON_LAYERS, Vector2(18, 18), Juice.COL_SUCCESS))
	var pk := Label.new()
	pk.text = "Pairs"
	pk.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	pk.add_theme_font_size_override("font_size", 15)
	pk.add_theme_color_override("font_color", Juice.COL_MUTED)
	pk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p_box.add_child(pk)

	_pairs_val_lbl = Label.new()
	_pairs_val_lbl.text = "0 / 6"
	_pairs_val_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	_pairs_val_lbl.add_theme_font_size_override("font_size", 20)
	_pairs_val_lbl.add_theme_color_override("font_color", Juice.COL_SUCCESS)
	_pairs_val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p_box.add_child(_pairs_val_lbl)

	hud_row.add_child(Juice.make_vsep(22.0))

	# Tries Left counter
	var t_box := HBoxContainer.new()
	t_box.alignment = BoxContainer.ALIGNMENT_CENTER
	t_box.add_theme_constant_override("separation", 7)
	t_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_row.add_child(t_box)

	var tk := Label.new()
	tk.text = "Tries Left"
	tk.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	tk.add_theme_font_size_override("font_size", 15)
	tk.add_theme_color_override("font_color", Juice.COL_MUTED)
	tk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t_box.add_child(tk)

	_tries_val_lbl = Label.new()
	_tries_val_lbl.text = "14"
	_tries_val_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	_tries_val_lbl.add_theme_font_size_override("font_size", 20)
	_tries_val_lbl.add_theme_color_override("font_color", Juice.COL_GOLD_BRIGHT)
	_tries_val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t_box.add_child(_tries_val_lbl)

	# Contextual Streak Pill
	_streak_pill = PanelContainer.new()
	_streak_pill.visible = false
	_streak_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_streak_pill.add_theme_stylebox_override("panel", Juice.make_pill_style(Color(0.22, 0.14, 0.06, 0.94), Juice.COL_GOLD, 12, 12, 6, 2))
	hud_center.add_child(_streak_pill)

	_streak_lbl = Label.new()
	_streak_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	_streak_lbl.add_theme_font_size_override("font_size", 16)
	_streak_lbl.add_theme_color_override("font_color", Juice.COL_GOLD_BRIGHT)
	_streak_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_streak_pill.add_child(_streak_lbl)

	# Standardized 48x48 close button in top-right safe zone
	var close_btn := Button.new()
	Juice.style_close_button(close_btn)
	close_btn.anchor_left = 1.0
	close_btn.anchor_right = 1.0
	close_btn.offset_left = -84
	close_btn.offset_right = -36
	close_btn.offset_top = 24
	close_btn.offset_bottom = 72
	close_btn.pressed.connect(func(): close_minigame(false, true))
	_root.add_child(close_btn)

	# --- TOP-RIGHT BARANGAY RECORDS CARD (Safe Zone) ---
	var board_card := PanelContainer.new()
	board_card.anchor_left = 1.0
	board_card.anchor_right = 1.0
	board_card.anchor_top = 0.0
	board_card.offset_left = -318
	board_card.offset_right = -36
	board_card.offset_top = 86
	board_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_card.add_theme_stylebox_override("panel", Juice.make_pill_style(Color(0.09, 0.07, 0.055, 0.84), Juice.COL_GOLD_SOFT, 14, 14, 12, 1))
	_root.add_child(board_card)

	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 8)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_card.add_child(bv)

	var bhdr := HBoxContainer.new()
	bhdr.alignment = BoxContainer.ALIGNMENT_CENTER
	bhdr.add_theme_constant_override("separation", 8)
	bhdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(bhdr)

	bhdr.add_child(Juice.make_icon_rect(Juice.ICON_TROPHY, Vector2(18, 18), Juice.COL_GOLD_BRIGHT))
	var btitle := Label.new()
	btitle.text = "Barangay Records"
	btitle.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	btitle.add_theme_font_size_override("font_size", 17)
	btitle.add_theme_color_override("font_color", Juice.COL_GOLD_BRIGHT)
	btitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bhdr.add_child(btitle)

	_board_rows.clear()
	for entry in NEIGHBOR_RECORDS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(row)

		var pframe := PanelContainer.new()
		pframe.custom_minimum_size = Vector2(36, 36)
		pframe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pst := StyleBoxFlat.new()
		pst.bg_color = Color(0.16, 0.12, 0.09, 0.96)
		pst.border_color = Juice.COL_GOLD_SOFT
		pst.set_border_width_all(1)
		pst.set_corner_radius_all(18)
		pst.set_content_margin_all(2)
		pframe.add_theme_stylebox_override("panel", pst)
		row.add_child(pframe)

		var portrait := TextureRect.new()
		portrait.texture = _load_tex(str(entry["portrait"]))
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pframe.add_child(portrait)

		var nlbl := Label.new()
		nlbl.text = str(entry["name"])
		nlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nlbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
		nlbl.add_theme_font_size_override("font_size", 16)
		nlbl.add_theme_color_override("font_color", Juice.COL_CREAM)
		nlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(nlbl)

		var slbl := Label.new()
		slbl.text = str(entry["label"])
		slbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slbl.custom_minimum_size = Vector2(78, 0)
		slbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
		slbl.add_theme_font_size_override("font_size", 15)
		slbl.add_theme_color_override("font_color", Juice.COL_GOLD_BRIGHT)
		slbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(slbl)

		_board_rows.append({
			"pairs": int(entry["pairs"]),
			"left": int(entry["left"]),
			"label": str(entry["label"]),
			"name_lbl": nlbl,
			"score_lbl": slbl,
		})

	# Centered Teks Grid floating over vignette (offset right-margin clear of leaderboard)
	var board_center := CenterContainer.new()
	board_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_center.offset_top = 112
	board_center.offset_bottom = -24
	board_center.offset_right = -120
	board_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(board_center)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 20)
	_grid.add_theme_constant_override("v_separation", 16)
	board_center.add_child(_grid)

	# --- INTRO MODAL ---
	var intro_shell := Juice.make_modal_shell(_root, Vector2(540, 0))
	_intro_overlay = intro_shell["overlay"]
	_intro_panel = intro_shell["panel"]
	var iv: VBoxContainer = intro_shell["vbox"]

	var ititle := Label.new()
	ititle.text = "Teks Memory"
	ititle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ititle.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	ititle.add_theme_font_size_override("font_size", 32)
	ititle.add_theme_color_override("font_color", Juice.COL_GOLD_BRIGHT)
	iv.add_child(ititle)

	var idesc := Label.new()
	idesc.text = "Flip vintage Teks cards two at a time to match every pair before your tries run out. Chain consecutive matches for a streak!"
	idesc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	idesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	idesc.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	idesc.add_theme_font_size_override("font_size", 18)
	idesc.add_theme_color_override("font_color", Juice.COL_CREAM)
	iv.add_child(idesc)

	var start_btn := Button.new()
	start_btn.text = "Flip Cards"
	Juice.style_primary_button(start_btn, Vector2(220, 50))
	start_btn.pressed.connect(_on_intro_start)
	iv.add_child(start_btn)

	# --- RESULT MODAL ---
	var res_shell := Juice.make_modal_shell(_root, Vector2(500, 0))
	_result_overlay = res_shell["overlay"]
	_result_panel = res_shell["panel"]
	var rv: VBoxContainer = res_shell["vbox"]

	_result_title = Label.new()
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	_result_title.add_theme_font_size_override("font_size", 32)
	rv.add_child(_result_title)

	_result_sub = Label.new()
	_result_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_sub.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	_result_sub.add_theme_font_size_override("font_size", 18)
	_result_sub.add_theme_color_override("font_color", Juice.COL_CREAM)
	rv.add_child(_result_sub)

	_result_stats_row = HBoxContainer.new()
	_result_stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_stats_row.add_theme_constant_override("separation", 12)
	rv.add_child(_result_stats_row)

	var cont_btn := Button.new()
	cont_btn.text = "Continue"
	Juice.style_primary_button(cont_btn, Vector2(210, 50))
	cont_btn.pressed.connect(func(): close_minigame(bool(_result_panel.get_meta("won", false)), true))
	rv.add_child(cont_btn)
