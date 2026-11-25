class_name MosquitoSwatMinigame
extends CanvasLayer

## Mosquito & Firefly Swat Minigame.
## Swat mosquitoes flying around the counter lamp to fill the score bar
## before time runs out, while sparing glowing fireflies (3 Firefly Lives).

signal minigame_finished(won: bool, result: Dictionary)

const TEX_MOSQUITO := "res://Assets/ui/minigames/mosquito/mosquito.png"
const TEX_MOSQUITO_DEAD := "res://Assets/ui/minigames/mosquito/mosquito_dead.png"
const TEX_FIREFLY := "res://Assets/ui/minigames/mosquito/firefly.png"
const TEX_FIREFLY_DEAD := "res://Assets/ui/minigames/mosquito/firefly_dead.png"

const ARENA_SIZE := Vector2(880.0, 500.0)
const TARGET_SCORE := 12
const MAX_LIVES := 3
const ROUND_TIME := 25.0

var is_open: bool = false
var _active: bool = false
var _score: int = 0
var _lives: int = MAX_LIVES
var _time_left: float = ROUND_TIME
var _spawn_timer: float = 0.0
var _bugs: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []

var _tex_mosq: Texture2D
var _tex_mosq_dead: Texture2D
var _tex_firefly: Texture2D
var _tex_firefly_dead: Texture2D

var _root: Control
var _arena: Control
var _arena_fx: Control
var _score_bar: ProgressBar
var _score_lbl: Label
var _timer_lbl: Label
var _lives_box: HBoxContainer
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
	_tex_mosq = _load_tex(TEX_MOSQUITO)
	_tex_mosq_dead = _load_tex(TEX_MOSQUITO_DEAD)
	_tex_firefly = _load_tex(TEX_FIREFLY)
	_tex_firefly_dead = _load_tex(TEX_FIREFLY_DEAD)
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
	_active = false
	is_open = false
	visible = false
	if is_in_group("minigame_overlay_active"):
		remove_from_group("minigame_overlay_active")
	_clear_bugs()
	Input.mouse_mode = _prev_mouse_mode
	if emit_result:
		minigame_finished.emit(won, {
			"id": "mosquito",
			"score": _score,
			"target": TARGET_SCORE,
			"lives_left": _lives,
			"time_left": _time_left,
		})


func _start_round() -> void:
	_clear_bugs()
	_ripples.clear()
	_score = 0
	_lives = MAX_LIVES
	_time_left = ROUND_TIME
	_spawn_timer = 0.15
	_active = true
	_result_panel.visible = false
	_refresh_hud()
	# Seed a few initial bugs right away
	for _i in range(4):
		_spawn_bug(false)
	for _j in range(2):
		_spawn_bug(true)


func _clear_bugs() -> void:
	for b in _bugs:
		var node: Control = b.get("node")
		if is_instance_valid(node):
			node.queue_free()
	_bugs.clear()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_minigame(false, true)


func _process(delta: float) -> void:
	if not is_open:
		return

	# Update ripples even after round ends
	for i in range(_ripples.size() - 1, -1, -1):
		_ripples[i]["t"] = float(_ripples[i]["t"]) + delta * 2.8
		if float(_ripples[i]["t"]) >= 1.0:
			_ripples.remove_at(i)
	if is_instance_valid(_arena_fx):
		_arena_fx.queue_redraw()

	if not _active:
		return

	_time_left = maxf(0.0, _time_left - delta)
	_refresh_timer_label()
	if _time_left <= 0.0:
		_finish_round(false, "Time's Up!", "The mosquitoes took over the counter lamp. Swatted %d / %d." % [_score, TARGET_SCORE])
		return

	# Spawn pacing
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		var live_mosq := 0
		var live_ff := 0
		for b in _bugs:
			if not bool(b["dead"]):
				if bool(b["is_firefly"]):
					live_ff += 1
				else:
					live_mosq += 1
		if live_mosq < 6:
			_spawn_bug(false)
		if live_ff < 4 and randf() < 0.45:
			_spawn_bug(true)
		_spawn_timer = randf_range(0.55, 0.95)

	# Move active bugs
	var bounds := _arena.size
	if bounds.x < 100.0:
		bounds = ARENA_SIZE
	for i in range(_bugs.size() - 1, -1, -1):
		var b: Dictionary = _bugs[i]
		var node: Control = b["node"]
		if not is_instance_valid(node):
			_bugs.remove_at(i)
			continue
		if bool(b["dead"]):
			continue

		b["age"] = float(b["age"]) + delta
		var pos: Vector2 = b["pos"]
		var vel: Vector2 = b["vel"]
		var wobble := sin(float(b["age"]) * float(b["freq"]) + float(b["phase"])) * float(b["amp"])
		var perp := Vector2(-vel.y, vel.x).normalized()
		pos += (vel + perp * wobble) * delta

		var pad := 34.0
		if pos.x < pad:
			pos.x = pad
			vel.x = absf(vel.x)
		elif pos.x > bounds.x - pad:
			pos.x = bounds.x - pad
			vel.x = -absf(vel.x)
		if pos.y < pad:
			pos.y = pad
			vel.y = absf(vel.y)
		elif pos.y > bounds.y - pad:
			pos.y = bounds.y - pad
			vel.y = -absf(vel.y)

		b["pos"] = pos
		b["vel"] = vel
		var sz := node.size
		node.position = pos - sz * 0.5
		if node is TextureRect:
			(node as TextureRect).flip_h = vel.x > 0.0
		if bool(b["is_firefly"]):
			var glow := 0.82 + 0.18 * sin(float(b["age"]) * 5.0 + float(b["phase"]))
			node.modulate = Color(1.0, 0.98, 0.80, glow)


func _spawn_bug(is_firefly: bool) -> void:
	var bounds := _arena.size
	if bounds.x < 100.0:
		bounds = ARENA_SIZE

	var tr := TextureRect.new()
	tr.texture = _tex_firefly if is_firefly else _tex_mosq
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var sz := Vector2(60, 60) if is_firefly else Vector2(64, 64)
	tr.custom_minimum_size = sz
	tr.size = sz
	tr.pivot_offset = sz * 0.5
	tr.mouse_filter = Control.MOUSE_FILTER_STOP
	tr.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Spawn near random edge or interior
	var pos := Vector2(randf_range(50.0, bounds.x - 50.0), randf_range(50.0, bounds.y - 50.0))
	var speed := randf_range(75.0, 125.0) if is_firefly else randf_range(130.0, 210.0)
	var ang := randf() * TAU
	var vel := Vector2(cos(ang), sin(ang)) * speed

	tr.position = pos - sz * 0.5
	_arena.add_child(tr)

	var bug_dict := {
		"node": tr,
		"is_firefly": is_firefly,
		"dead": false,
		"pos": pos,
		"vel": vel,
		"age": 0.0,
		"freq": randf_range(2.2, 4.2) if is_firefly else randf_range(5.0, 9.5),
		"amp": randf_range(22.0, 48.0) if is_firefly else randf_range(40.0, 85.0),
		"phase": randf() * TAU,
	}
	_bugs.append(bug_dict)

	tr.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_bug_swatted(bug_dict)
	)


func _on_bug_swatted(bug: Dictionary) -> void:
	if not _active or bool(bug["dead"]):
		return
	bug["dead"] = true
	var tr: TextureRect = bug["node"]
	var pos: Vector2 = bug["pos"]
	var is_firefly: bool = bool(bug["is_firefly"])

	if is_firefly:
		tr.texture = _tex_firefly_dead
		_lives = maxi(0, _lives - 1)
		_ripples.append({"pos": pos, "t": 0.0, "color": Color(0.98, 0.35, 0.32, 0.9)})
		_spawn_floating_text(pos, "-1 FIREFLY!", Color(1.0, 0.45, 0.40))
		EventBus.request_sfx.emit("error")
	else:
		tr.texture = _tex_mosq_dead
		_score += 1
		_ripples.append({"pos": pos, "t": 0.0, "color": Color(0.98, 0.84, 0.42, 0.9)})
		_spawn_floating_text(pos, "SWAT! +1", Color(0.68, 0.96, 0.58))
		EventBus.request_sfx.emit("interact")

	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := tr.create_tween()
	tw.tween_property(tr, "scale", Vector2(1.22, 0.82), 0.07)
	tw.tween_property(tr, "position:y", tr.position.y + 42.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(tr, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		if is_instance_valid(tr):
			tr.queue_free()
	)

	_refresh_hud()
	if _lives <= 0:
		_finish_round(false, "Fireflies Lost!", "Oh no — too many fireflies got swatted!")
	elif _score >= TARGET_SCORE:
		_finish_round(true, "Counter Clear!", "Swatted %d mosquitoes with %d fireflies safe!" % [_score, _lives])


func _spawn_floating_text(pos: Vector2, txt: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.position = pos - Vector2(45, 16)
	lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 38.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.55)
	tw.tween_callback(lbl.queue_free)


func _finish_round(won: bool, title: String, subtitle: String) -> void:
	_active = false
	_result_title.text = title
	_result_title.add_theme_color_override("font_color", Color(0.62, 0.96, 0.56) if won else Color(0.98, 0.48, 0.45))
	_result_sub.text = subtitle
	_result_panel.set_meta("won", won)
	_result_panel.visible = true


func _refresh_hud() -> void:
	_score_bar.max_value = TARGET_SCORE
	_score_bar.value = _score
	_score_lbl.text = "MOSQUITOES: %d / %d" % [_score, TARGET_SCORE]
	_refresh_timer_label()

	for ch in _lives_box.get_children():
		ch.queue_free()
	for i in range(MAX_LIVES):
		var icon := TextureRect.new()
		icon.texture = _tex_firefly if i < _lives else _tex_firefly_dead
		icon.custom_minimum_size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color(1.0, 0.98, 0.82, 1.0) if i < _lives else Color(0.55, 0.45, 0.45, 0.45)
		_lives_box.add_child(icon)


func _refresh_timer_label() -> void:
	_timer_lbl.text = "%.1fs" % _time_left
	var col := Color(0.98, 0.45, 0.40) if _time_left <= 6.0 else Color(1.0, 0.92, 0.72)
	_timer_lbl.add_theme_color_override("font_color", col)


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
	frame.custom_minimum_size = Vector2(930, 620)
	var fs := UIStyle.create_flat_stylebox(Color(0.09, 0.08, 0.068, 0.97), 12, 22, 18)
	fs.border_color = Color(0.86, 0.66, 0.30, 0.92)
	fs.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", fs)
	center.add_child(frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	frame.add_child(vbox)

	# Header
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 16)
	vbox.add_child(hdr)

	var title := Label.new()
	title.text = "DUSK LAMP SWAT"
	title.add_theme_font_override("font", UIStyle.FONT_INDER)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62))
	hdr.add_child(title)

	var score_col := VBoxContainer.new()
	score_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_col.add_theme_constant_override("separation", 3)
	hdr.add_child(score_col)

	_score_lbl = Label.new()
	_score_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_score_lbl.add_theme_font_size_override("font_size", 14)
	_score_lbl.add_theme_color_override("font_color", Color(0.94, 0.88, 0.76))
	score_col.add_child(_score_lbl)

	_score_bar = ProgressBar.new()
	_score_bar.custom_minimum_size = Vector2(220, 14)
	_score_bar.show_percentage = false
	var sb_bg := UIStyle.create_flat_stylebox(Color(0.16, 0.14, 0.11, 1.0), 6, 0, 0)
	var sb_fill := UIStyle.create_flat_stylebox(Color(0.42, 0.82, 0.44, 1.0), 6, 0, 0)
	_score_bar.add_theme_stylebox_override("background", sb_bg)
	_score_bar.add_theme_stylebox_override("fill", sb_fill)
	score_col.add_child(_score_bar)

	var lives_wrap := HBoxContainer.new()
	lives_wrap.add_theme_constant_override("separation", 6)
	hdr.add_child(lives_wrap)
	var lives_lbl := Label.new()
	lives_lbl.text = "FIREFLIES:"
	lives_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	lives_lbl.add_theme_font_size_override("font_size", 14)
	lives_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.68))
	lives_wrap.add_child(lives_lbl)
	_lives_box = HBoxContainer.new()
	_lives_box.add_theme_constant_override("separation", 4)
	lives_wrap.add_child(_lives_box)

	_timer_lbl = Label.new()
	_timer_lbl.custom_minimum_size = Vector2(72, 0)
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_timer_lbl.add_theme_font_size_override("font_size", 22)
	hdr.add_child(_timer_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(func(): close_minigame(false, true))
	hdr.add_child(close_btn)

	# Arena
	var arena_panel := PanelContainer.new()
	arena_panel.custom_minimum_size = ARENA_SIZE
	arena_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var ap_style := UIStyle.create_flat_stylebox(Color(0.055, 0.06, 0.085, 1.0), 10, 0, 0)
	ap_style.border_color = Color(0.45, 0.38, 0.24, 0.8)
	ap_style.set_border_width_all(1)
	arena_panel.add_theme_stylebox_override("panel", ap_style)
	vbox.add_child(arena_panel)

	_arena = Control.new()
	_arena.clip_contents = true
	_arena.set_anchors_preset(Control.PRESET_FULL_RECT)
	arena_panel.add_child(_arena)

	_arena_fx = Control.new()
	_arena_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arena_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena_fx.draw.connect(_draw_arena_fx)
	_arena.add_child(_arena_fx)

	# Hint footer
	var hint := Label.new()
	hint.text = "Click mosquitoes to swat them! Avoid hitting the glowing fireflies. (Esc to quit)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", UIStyle.FONT_INDER)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.84, 0.78, 0.66, 0.85))
	vbox.add_child(hint)

	# Result overlay inside arena
	_result_panel = PanelContainer.new()
	_result_panel.set_anchors_preset(Control.PRESET_CENTER)
	_result_panel.custom_minimum_size = Vector2(400, 190)
	_result_panel.offset_left = -200
	_result_panel.offset_right = 200
	_result_panel.offset_top = -95
	_result_panel.offset_bottom = 95
	var rs := UIStyle.create_flat_stylebox(Color(0.08, 0.07, 0.06, 0.96), 12, 24, 20)
	rs.border_color = Color(0.92, 0.72, 0.32, 0.95)
	rs.set_border_width_all(2)
	_result_panel.add_theme_stylebox_override("panel", rs)
	_result_panel.visible = false
	_arena.add_child(_result_panel)

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


func _draw_arena_fx() -> void:
	var c := _arena_fx.size * 0.5
	# Soft warm counter-lamp glow in the center
	for r_idx in range(4):
		var rad := 70.0 + float(r_idx) * 65.0
		var alpha := 0.075 - float(r_idx) * 0.015
		_arena_fx.draw_circle(c, rad, Color(1.0, 0.82, 0.42, alpha))
	# Swat ripples
	for rip in _ripples:
		var t: float = float(rip["t"])
		var col: Color = rip["color"]
		col.a *= (1.0 - t)
		_arena_fx.draw_arc(rip["pos"], 14.0 + t * 46.0, 0.0, TAU, 28, col, 3.0, true)
