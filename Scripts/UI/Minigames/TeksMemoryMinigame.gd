class_name TeksMemoryMinigame
extends CanvasLayer

## Classic Filipino Teks Memory Match Minigame.
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

const TOTAL_PAIRS := 6
const MAX_TRIES := 14

var is_open: bool = false
var _locked: bool = false
var _pairs_found: int = 0
var _tries_left: int = MAX_TRIES
var _cards: Array[Dictionary] = []
var _flipped: Array[Dictionary] = []

var _root: Control
var _grid: GridContainer
var _pairs_lbl: Label
var _tries_lbl: Label
var _result_panel: PanelContainer
var _result_title: Label
var _result_sub: Label
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
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_minigame(false, true)


func _start_round() -> void:
	_locked = false
	_pairs_found = 0
	_tries_left = MAX_TRIES
	_flipped.clear()
	_cards.clear()
	_result_panel.visible = false
	for ch in _grid.get_children():
		ch.queue_free()

	# Pick 6 random portraits & pastel backgrounds
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
	var card_size := Vector2(124, 162)
	var holder := Control.new()
	holder.custom_minimum_size = card_size
	holder.pivot_offset = card_size * 0.5
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Back face (vintage dark crimson/gold geometric Teks card back — zero text)
	var back := PanelContainer.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := UIStyle.create_flat_stylebox(Color(0.36, 0.12, 0.14, 1.0), 6, 8, 8)
	bs.border_color = Color(0.95, 0.86, 0.68, 0.95)
	bs.set_border_width_all(4)
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

	# Visual-only Teks power level bar (5 rectangular pips, zero text!)
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
	return card_dict


func _on_card_clicked(card: Dictionary) -> void:
	if _locked or bool(card["face_up"]) or bool(card["matched"]):
		return
	_flip_card(card, true)
	_flipped.append(card)
	EventBus.request_sfx.emit("interact")

	if _flipped.size() == 2:
		_locked = true
		var a: Dictionary = _flipped[0]
		var b: Dictionary = _flipped[1]
		if int(a["pair_id"]) == int(b["pair_id"]):
			a["matched"] = true
			b["matched"] = true
			_pairs_found += 1
			_flipped.clear()
			_refresh_hud()
			# Celebratory pop on matched pair
			for m in [a, b]:
				var r: Control = m["root"]
				var tw := r.create_tween()
				tw.tween_property(r, "scale", Vector2(1.08, 1.08), 0.10)
				tw.tween_property(r, "scale", Vector2.ONE, 0.12)
			_locked = false
			if _pairs_found >= TOTAL_PAIRS:
				_finish_round(true, "Teks Master!", "Matched all %d pairs with %d tries to spare!" % [TOTAL_PAIRS, _tries_left])
		else:
			_tries_left = maxi(0, _tries_left - 1)
			_refresh_hud()
			var timer := get_tree().create_timer(0.65)
			timer.timeout.connect(func():
				if not is_open:
					return
				_flip_card(a, false)
				_flip_card(b, false)
				_flipped.clear()
				_locked = false
				if _tries_left <= 0 and _pairs_found < TOTAL_PAIRS:
					_finish_round(false, "Out of Tries!", "Matched %d / %d Teks pairs." % [_pairs_found, TOTAL_PAIRS])
			)


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
	_pairs_lbl.text = "PAIRS: %d / %d" % [_pairs_found, TOTAL_PAIRS]
	_tries_lbl.text = "TRIES LEFT: %d" % _tries_left
	var col := Color(0.98, 0.45, 0.40) if _tries_left <= 3 else Color(1.0, 0.92, 0.72)
	_tries_lbl.add_theme_color_override("font_color", col)


func _finish_round(won: bool, title: String, sub: String) -> void:
	_locked = true
	_result_title.text = title
	_result_title.add_theme_color_override("font_color", Color(0.62, 0.96, 0.56) if won else Color(0.98, 0.48, 0.45))
	_result_sub.text = sub
	_result_panel.set_meta("won", won)
	_result_panel.visible = true


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.03, 0.025, 0.02, 0.72)
	_root.add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(640, 645)
	var fs := UIStyle.create_flat_stylebox(Color(0.09, 0.08, 0.068, 0.97), 12, 24, 18)
	fs.border_color = Color(0.86, 0.66, 0.30, 0.92)
	fs.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", fs)
	center.add_child(frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	frame.add_child(vbox)

	# Header
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 16)
	vbox.add_child(hdr)

	var title := Label.new()
	title.text = "TEKS MEMORY"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", UIStyle.FONT_INDER)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62))
	hdr.add_child(title)

	_pairs_lbl = Label.new()
	_pairs_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_pairs_lbl.add_theme_font_size_override("font_size", 18)
	_pairs_lbl.add_theme_color_override("font_color", Color(0.70, 0.96, 0.62))
	hdr.add_child(_pairs_lbl)

	_tries_lbl = Label.new()
	_tries_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_tries_lbl.add_theme_font_size_override("font_size", 18)
	hdr.add_child(_tries_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(func(): close_minigame(false, true))
	hdr.add_child(close_btn)

	# Board container
	var board_wrap := Control.new()
	board_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_wrap.custom_minimum_size = Vector2(560, 520)
	vbox.add_child(board_wrap)

	var board_center := CenterContainer.new()
	board_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_wrap.add_child(board_center)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 14)
	board_center.add_child(_grid)

	# Result panel
	_result_panel = PanelContainer.new()
	_result_panel.set_anchors_preset(Control.PRESET_CENTER)
	_result_panel.custom_minimum_size = Vector2(380, 185)
	_result_panel.offset_left = -190
	_result_panel.offset_right = 190
	_result_panel.offset_top = -92
	_result_panel.offset_bottom = 92
	var rs := UIStyle.create_flat_stylebox(Color(0.08, 0.07, 0.06, 0.96), 12, 22, 18)
	rs.border_color = Color(0.92, 0.72, 0.32, 0.95)
	rs.set_border_width_all(2)
	_result_panel.add_theme_stylebox_override("panel", rs)
	_result_panel.visible = false
	board_wrap.add_child(_result_panel)

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
