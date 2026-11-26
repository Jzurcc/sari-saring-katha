class_name TeksMemoryMinigame
extends CanvasLayer

## Classic Filipino Teks Memory Match Minigame (Fullscreen Vignette UI).
## 4x3 grid (6 pairs) of rectangular vintage Teks cards featuring customer portraits,
## random pastel light backgrounds, rectangular double borders, and text-free visual
## power-level pips along the bottom.

signal minigame_finished(won: bool, result: Dictionary)

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
const Juice := preload("res://Scripts/UI/Minigames/MinigameJuice.gd")

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
var _pairs_found: int = 0
var _tries_left: int = MAX_TRIES
var _streak: int = 0
var _cards: Array[Dictionary] = []
var _flipped: Array[Dictionary] = []

var _root: Control
var _grid: GridContainer
var _stats_lbl: Label
var _intro_panel: PanelContainer
var _result_panel: PanelContainer
var _result_title: Label
var _result_sub: Label
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
	_locked = true
	Juice.pop_panel_in(_intro_panel)


func _on_intro_start() -> void:
	Juice.play_sfx("tab_switch", 1.15)
	_intro_panel.visible = false
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
			"total_pairs": TOTAL_PAIRS,
			"tries_left": _tries_left,
		})


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close_minigame(false, true)
		elif _intro_panel.visible and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
			get_viewport().set_input_as_handled()
			_on_intro_start()


func _start_round() -> void:
	_locked = false
	_pairs_found = 0
	_tries_left = MAX_TRIES
	_streak = 0
	_flipped.clear()
	_cards.clear()
	_result_panel.visible = false
	for ch in _grid.get_children():
		ch.queue_free()

	var pool := PORTRAIT_PATHS.duplicate()
	pool.shuffle()
	var pastels := PASTEL_BACKGROUNDS.duplicate()
	pastels.shuffle()

	var deck: Array[Dictionary] = []
	for i in range(TOTAL_PAIRS):
		var path: String = pool[i % pool.size()]
		var bg: Color = pastels[i % pastels.size()]
		var power: int = randi_range(2, 5)
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
	var card_size := Vector2(126, 166)
	var holder := Control.new()
	holder.custom_minimum_size = card_size
	holder.pivot_offset = card_size * 0.5
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Back face (vintage crimson/gold geometric Teks card back — zero text)
	var back := PanelContainer.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := UIStyle.create_flat_stylebox(Color(0.36, 0.12, 0.14, 1.0), 6, 8, 8)
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

	# Front face (rectangular Teks border + pastel background + portrait + visual power-level pips, NO text!)
	var front := PanelContainer.new()
	front.set_anchors_preset(Control.PRESET_FULL_RECT)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.visible = false
	var f_outer := UIStyle.create_flat_stylebox(Color(0.98, 0.95, 0.88, 1.0), 5, 7, 7)
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
	var f_inner := UIStyle.create_flat_stylebox(entry["pastel"], 2, 6, 6)
	f_inner.border_color = Color(0.24, 0.18, 0.14, 0.88)
	f_inner.set_border_width_all(2)
	inner.add_theme_stylebox_override("panel", f_inner)
	front.add_child(inner)

	var inner_v := VBoxContainer.new()
	inner_v.add_theme_constant_override("separation", 5)
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

	var power_bar := Control.new()
	power_bar.custom_minimum_size = Vector2(0, 14)
	power_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var power_val: int = int(entry["power"])
	power_bar.draw.connect(func():
		var bw := power_bar.size.x
		var bh := power_bar.size.y
		var pips := 5
		var gap := 4.0
		var pip_w := (bw - gap * float(pips - 1)) / float(pips)
		for p in range(pips):
			var px := float(p) * (pip_w + gap)
			var prect := Rect2(px, 2.0, pip_w, bh - 4.0)
			var filled := p < power_val
			var fill_col := Color(0.92, 0.62, 0.14, 1.0) if filled else Color(0.20, 0.16, 0.14, 0.18)
			power_bar.draw_rect(prect, fill_col, true)
			power_bar.draw_rect(prect, Color(0.22, 0.16, 0.12, 0.75), false, 1.2)
	)
	inner_v.add_child(power_bar)

	var card_dict := {
		"root": holder,
		"back": back,
		"front": front,
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
			Juice.pop_control(_stats_lbl, 1.22, 0.20)
			# Escalating match fanfare + spark bursts on both cards!
			var match_pitch := minf(1.65, 1.0 + float(_streak) * 0.13)
			Juice.play_sfx("pickup", match_pitch, 1.5)
			Juice.play_sfx("interact", match_pitch + 0.18, 0.0)
			for m in [a, b]:
				var r: Control = m["root"]
				var center_pos := r.global_position + r.size * 0.5
				Juice.spawn_burst(_root, center_pos, Color(1.0, 0.88, 0.36), 10, 100.0)
				var tw := r.create_tween()
				tw.tween_property(r, "scale", Vector2(1.13, 1.13), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(r, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE)
			_spawn_match_label(
				((a["root"] as Control).global_position + (b["root"] as Control).global_position) * 0.5 + Vector2(63, 40),
				"MATCH!" if _streak <= 1 else "STREAK x%d!" % _streak,
				Color(0.68, 0.96, 0.58) if _streak <= 1 else Color(1.0, 0.90, 0.38)
			)
			_locked = false
			if _pairs_found >= TOTAL_PAIRS:
				_finish_round(true, "Teks Master!", "Matched all %d pairs with %d tries to spare!" % [TOTAL_PAIRS, _tries_left])
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
				if _tries_left <= 0 and _pairs_found < TOTAL_PAIRS:
					_finish_round(false, "Out of Tries!", "Matched %d / %d Teks pairs." % [_pairs_found, TOTAL_PAIRS])
			)


func _spawn_match_label(pos: Vector2, txt: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.position = pos - Vector2(54, 16)
	lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.90))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 44.0, 0.60).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.60)
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
	_stats_lbl.text = "Pairs: %d / %d   •   Tries Left: %d" % [_pairs_found, TOTAL_PAIRS, _tries_left]
	var col := Color(0.98, 0.48, 0.44) if _tries_left <= 3 else Color(0.96, 0.91, 0.78)
	_stats_lbl.add_theme_color_override("font_color", col)
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
			nlbl.add_theme_color_override("font_color", Color(0.68, 0.96, 0.62))
			slbl.add_theme_color_override("font_color", Color(0.68, 0.96, 0.62))
			slbl.text = "%s ✓" % base_lbl
		else:
			var is_zero := req_pairs == 0
			nlbl.add_theme_color_override("font_color", Color(0.76, 0.72, 0.66) if is_zero else Color(0.94, 0.90, 0.82))
			slbl.add_theme_color_override("font_color", Color(0.68, 0.64, 0.58) if is_zero else Color(0.98, 0.84, 0.46))
			slbl.text = base_lbl


func _finish_round(won: bool, title: String, sub: String) -> void:
	_locked = true
	_result_title.text = title
	_result_title.add_theme_color_override("font_color", Color(0.62, 0.96, 0.56) if won else Color(0.98, 0.48, 0.45))
	_result_sub.text = sub
	_result_panel.set_meta("won", won)
	Juice.pop_panel_in(_result_panel)
	if won:
		Juice.play_win_fanfare(self)
		var vp := get_viewport().get_visible_rect().size
		Juice.spawn_burst(_root, vp * Vector2(0.35, 0.45), Color(1.0, 0.88, 0.36), 14, 180.0)
		Juice.spawn_burst(_root, vp * Vector2(0.65, 0.45), Color(0.60, 0.96, 0.58), 14, 180.0)
	else:
		Juice.play_lose_sting(self)


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

	# Floating Top-Center Title & Stats (no outer box, Title Case)
	var header := VBoxContainer.new()
	header.anchor_left = 0.5
	header.anchor_right = 0.5
	header.anchor_top = 0.0
	header.offset_left = -260
	header.offset_right = 260
	header.offset_top = 20
	header.add_theme_constant_override("separation", 4)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(header)

	var title := Label.new()
	title.text = "Teks Memory"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UIStyle.FONT_INDER)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.93, 0.72))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.92))
	title.add_theme_constant_override("outline_size", 6)
	header.add_child(title)

	_stats_lbl = Label.new()
	_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_stats_lbl.add_theme_font_size_override("font_size", 19)
	_stats_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.9))
	_stats_lbl.add_theme_constant_override("outline_size", 5)
	header.add_child(_stats_lbl)

	# Minimal floating close button top-right
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.anchor_left = 1.0
	close_btn.anchor_right = 1.0
	close_btn.offset_left = -58
	close_btn.offset_right = -18
	close_btn.offset_top = 18
	close_btn.offset_bottom = 58
	close_btn.pressed.connect(func(): close_minigame(false, true))
	_root.add_child(close_btn)

	# Top-Right Neighbor Leaderboard (Barangay Records — frameless floating over vignette)
	var bv := VBoxContainer.new()
	bv.anchor_left = 1.0
	bv.anchor_right = 1.0
	bv.anchor_top = 0.0
	bv.offset_left = -310
	bv.offset_right = -24
	bv.offset_top = 74
	bv.add_theme_constant_override("separation", 8)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bv)

	var btitle := Label.new()
	btitle.text = "Barangay Records"
	btitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	btitle.add_theme_font_override("font", UIStyle.FONT_INDER)
	btitle.add_theme_font_size_override("font_size", 20)
	btitle.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62))
	btitle.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.92))
	btitle.add_theme_constant_override("outline_size", 5)
	btitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(btitle)

	_board_rows.clear()
	for entry in NEIGHBOR_RECORDS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(row)

		var portrait := TextureRect.new()
		portrait.texture = _load_tex(str(entry["portrait"]))
		portrait.custom_minimum_size = Vector2(38, 38)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(portrait)

		var nlbl := Label.new()
		nlbl.text = str(entry["name"])
		nlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nlbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		nlbl.add_theme_font_size_override("font_size", 18)
		nlbl.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82))
		nlbl.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.90))
		nlbl.add_theme_constant_override("outline_size", 4)
		nlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(nlbl)

		var slbl := Label.new()
		slbl.text = str(entry["label"])
		slbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slbl.custom_minimum_size = Vector2(82, 0)
		slbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		slbl.add_theme_font_size_override("font_size", 17)
		slbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.46))
		slbl.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.90))
		slbl.add_theme_constant_override("outline_size", 4)
		slbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(slbl)

		_board_rows.append({
			"pairs": int(entry["pairs"]),
			"left": int(entry["left"]),
			"label": str(entry["label"]),
			"name_lbl": nlbl,
			"score_lbl": slbl,
		})

	# Centered 4x3 Teks Grid floating over vignette
	var board_center := CenterContainer.new()
	board_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_center.offset_top = 86
	board_center.offset_bottom = -16
	board_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(board_center)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 20)
	_grid.add_theme_constant_override("v_separation", 16)
	board_center.add_child(_grid)

	# Intro instructions pop-up
	_intro_panel = PanelContainer.new()
	_intro_panel.set_anchors_preset(Control.PRESET_CENTER)
	_intro_panel.custom_minimum_size = Vector2(540, 255)
	_intro_panel.offset_left = -270
	_intro_panel.offset_right = 270
	_intro_panel.offset_top = -128
	_intro_panel.offset_bottom = 128
	var istyle := UIStyle.create_flat_stylebox(Color(0.08, 0.07, 0.06, 0.95), 14, 28, 22)
	istyle.border_color = Color(0.92, 0.72, 0.32, 0.92)
	istyle.set_border_width_all(2)
	_intro_panel.add_theme_stylebox_override("panel", istyle)
	_intro_panel.visible = false
	_root.add_child(_intro_panel)

	var iv := VBoxContainer.new()
	iv.alignment = BoxContainer.ALIGNMENT_CENTER
	iv.add_theme_constant_override("separation", 14)
	_intro_panel.add_child(iv)

	var ititle := Label.new()
	ititle.text = "How to Play: Teks Memory"
	ititle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ititle.add_theme_font_override("font", UIStyle.FONT_INDER)
	ititle.add_theme_font_size_override("font_size", 30)
	ititle.add_theme_color_override("font_color", Color(1.0, 0.91, 0.64))
	iv.add_child(ititle)

	var idesc := Label.new()
	idesc.text = "Click cards to flip them and match all %d pairs of Teks cards before you run out of %d tries!" % [TOTAL_PAIRS, MAX_TRIES]
	idesc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	idesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	idesc.add_theme_font_override("font", UIStyle.FONT_INDER)
	idesc.add_theme_font_size_override("font_size", 20)
	idesc.add_theme_color_override("font_color", Color(0.94, 0.89, 0.78))
	iv.add_child(idesc)

	var start_btn := Button.new()
	start_btn.text = "Start"
	start_btn.focus_mode = Control.FOCUS_NONE
	start_btn.custom_minimum_size = Vector2(170, 46)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.add_theme_font_override("font", UIStyle.FONT_INDER)
	start_btn.add_theme_font_size_override("font_size", 20)
	start_btn.pressed.connect(_on_intro_start)
	iv.add_child(start_btn)

	# Result panel
	_result_panel = PanelContainer.new()
	_result_panel.set_anchors_preset(Control.PRESET_CENTER)
	_result_panel.custom_minimum_size = Vector2(390, 185)
	_result_panel.offset_left = -195
	_result_panel.offset_right = 195
	_result_panel.offset_top = -92
	_result_panel.offset_bottom = 92
	var rs := UIStyle.create_flat_stylebox(Color(0.08, 0.07, 0.06, 0.94), 14, 24, 20)
	rs.border_color = Color(0.92, 0.72, 0.32, 0.92)
	rs.set_border_width_all(2)
	_result_panel.add_theme_stylebox_override("panel", rs)
	_result_panel.visible = false
	_root.add_child(_result_panel)

	var rv := VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_theme_constant_override("separation", 12)
	_result_panel.add_child(rv)

	_result_title = Label.new()
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_font_override("font", UIStyle.FONT_INDER)
	_result_title.add_theme_font_size_override("font_size", 28)
	rv.add_child(_result_title)

	_result_sub = Label.new()
	_result_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_sub.add_theme_font_override("font", UIStyle.FONT_INDER)
	_result_sub.add_theme_font_size_override("font_size", 16)
	_result_sub.add_theme_color_override("font_color", Color(0.94, 0.89, 0.78))
	rv.add_child(_result_sub)

	var cont_btn := Button.new()
	cont_btn.text = "Continue"
	cont_btn.custom_minimum_size = Vector2(160, 40)
	cont_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cont_btn.pressed.connect(func(): close_minigame(bool(_result_panel.get_meta("won", false)), true))
	rv.add_child(cont_btn)
