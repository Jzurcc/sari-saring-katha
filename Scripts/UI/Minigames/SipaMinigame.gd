class_name SipaMinigame
extends CanvasLayer

## Sipa Keepy-Uppy Minigame (Fullscreen Vignette UI).
## Starts with a 3-2-1 countdown, then drops the sipa across the full viewport
## inside a bounded store perimeter. Press SPACE (or Click) when the sipa enters
## the bottom kick zone to bounce it up and immediately refresh your kick!

signal minigame_finished(won: bool, result: Dictionary)

const TEX_SIPA := "res://Assets/ui/minigames/sipa.png"
const Juice := preload("res://Scripts/UI/Minigames/MinigameJuice.gd")
const SIPA_SIZE := Vector2(82.0, 82.0)
const EARLY_COOLDOWN := 0.45
const XP_CAP_KICKS := 32

const NEIGHBOR_SCORES: Array[Dictionary] = [
	{"name": "Lolo Pilo", "score": 32, "portrait": "res://Assets/characters/portraits/LoloPilo Face.png"},
	{"name": "Buboy", "score": 21, "portrait": "res://Assets/characters/portraits/Buboy Face.png"},
	{"name": "T.K.", "score": 15, "portrait": "res://Assets/characters/portraits/TK Face.png"},
	{"name": "Kuya Kap", "score": 10, "portrait": "res://Assets/characters/portraits/Kuya_Kap Face.png"},
	{"name": "Danilo", "score": 6, "portrait": "res://Assets/characters/portraits/Danilo Face.png"},
	{"name": "Manang Ana", "score": 0, "portrait": "res://Assets/characters/portraits/ManangAna Face.png"},
	{"name": "Rosalyn", "score": 0, "portrait": "res://Assets/characters/portraits/Rosalyn Face.png"},
]

const VIGNETTE_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.025, 0.02, 0.016, 0.90);
void fragment() {
	vec2 d = UV - vec2(0.5);
	float dist = length(d * vec2(1.15, 1.0));
	float vig = smoothstep(0.14, 0.74, dist);
	COLOR = vec4(tint.rgb, mix(0.42, tint.a, vig));
}
"""

var is_open: bool = false
var _phase: String = "idle" # countdown, playing, finished
var _countdown_t: float = 3.0
var _kicks: int = 0
var _cooldown: float = 0.0
var _elapsed: float = 0.0
var _hit_flash: float = 0.0
var _miss_flash: float = 0.0
var _hitstop: float = 0.0
var _prev_space_down: bool = false

var _sipa_pos: Vector2 = Vector2.ZERO
var _sipa_vel: Vector2 = Vector2.ZERO
var _sipa_rot: float = 0.0
var _sipa_ang_vel: float = 0.0
var _sipa_tex: Texture2D

var _root: Control
var _field_draw: Control
var _sipa_sprite: TextureRect
var _countdown_lbl: Label
var _kick_lbl: Label
var _status_lbl: Label
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


func _get_vp_size() -> Vector2:
	var vp := get_viewport()
	if vp:
		var sz := vp.get_visible_rect().size
		if sz.x > 100.0 and sz.y > 100.0:
			return sz
	return Vector2(1280.0, 720.0)


func _get_bounds() -> Dictionary:
	var vp := _get_vp_size()
	var left := vp.x * 0.16
	var right := vp.x * 0.80
	var top := 118.0
	var floor_y := vp.y - 46.0
	var zone_bottom := floor_y - 14.0
	# Starts generous/tall so early kicks are forgiving, then gradually narrows up to kick 32+
	var diff_t := clampf(float(_kicks) / float(XP_CAP_KICKS), 0.0, 1.0)
	var base_zone_h := lerpf(168.0, 96.0, diff_t) * (vp.y / 720.0)
	var zone_top := zone_bottom - clampf(base_zone_h, 88.0, 210.0)
	return {
		"left": left,
		"right": right,
		"top": top,
		"floor_y": floor_y,
		"zone_top": zone_top,
		"zone_bottom": zone_bottom,
	}


func _ready() -> void:
	layer = 42
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sipa_tex = _load_tex(TEX_SIPA)
	_build_ui()
	visible = false


func open_minigame(_config: Dictionary = {}) -> void:
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_open = true
	visible = true
	add_to_group("minigame_overlay_active")
	_show_intro()


func _show_intro() -> void:
	var vp := _get_vp_size()
	_phase = "intro"
	_prev_space_down = Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER)
	_kicks = 0
	_cooldown = 0.0
	_elapsed = 0.0
	_sipa_pos = Vector2(vp.x * 0.5, vp.y * 0.28)
	_sipa_vel = Vector2.ZERO
	_sipa_rot = 0.0
	_sync_sipa_visual()
	_countdown_lbl.visible = false
	_result_panel.visible = false
	Juice.pop_panel_in(_intro_panel)
	_kick_lbl.text = "Kicks: 0"
	_status_lbl.text = ""
	_refresh_leaderboard()


func _on_intro_start() -> void:
	Juice.play_sfx("tab_switch", 1.15)
	_intro_panel.visible = false
	_start_countdown()


func close_minigame(won: bool = false, emit_result: bool = true) -> void:
	if not is_open:
		return
	_phase = "idle"
	is_open = false
	visible = false
	if is_in_group("minigame_overlay_active"):
		remove_from_group("minigame_overlay_active")
	Input.mouse_mode = _prev_mouse_mode
	if emit_result:
		minigame_finished.emit(won, {
			"id": "sipa",
			"kicks": _kicks,
			"xp_cap": XP_CAP_KICKS,
			"elapsed": _elapsed,
		})


func _start_countdown() -> void:
	var vp := _get_vp_size()
	_phase = "countdown"
	_countdown_t = 3.0
	_kicks = 0
	_cooldown = 0.0
	_elapsed = 0.0
	_hit_flash = 0.0
	_miss_flash = 0.0
	_result_panel.visible = false
	_sipa_pos = Vector2(vp.x * 0.5, vp.y * 0.28)
	_sipa_vel = Vector2.ZERO
	_sipa_rot = 0.0
	_sipa_ang_vel = 0.0
	_sync_sipa_visual()
	_countdown_lbl.visible = true
	_countdown_lbl.text = "3"
	Juice.pop_control(_countdown_lbl, 1.35, 0.28)
	Juice.play_sfx("ui_hover", 0.85, 1.0)
	_status_lbl.text = "Get ready..."
	_kick_lbl.text = "Kicks: 0"
	_refresh_leaderboard()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close_minigame(false, true)
			return
		if _phase == "intro" and event.keycode == KEY_ENTER:
			get_viewport().set_input_as_handled()
			_on_intro_start()
			return
		if event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()


func _attempt_kick() -> void:
	if _phase != "playing" or _cooldown > 0.0:
		return
	var b := _get_bounds()
	var half_h := SIPA_SIZE.y * 0.45
	var in_zone := (_sipa_pos.y + half_h) >= float(b["zone_top"]) and (_sipa_pos.y - half_h) <= float(b["zone_bottom"])
	if in_zone:
		_kicks += 1
		_cooldown = 0.0
		_hit_flash = 1.0
		_hitstop = 0.032
		var zone_center := (float(b["zone_top"]) + float(b["zone_bottom"])) * 0.5
		var zone_half := (float(b["zone_bottom"]) - float(b["zone_top"])) * 0.5
		var is_perfect := absf(_sipa_pos.y - zone_center) <= zone_half * 0.45

		var vp_scale := _get_vp_size().y / 720.0
		var diff_t := clampf(float(_kicks) / float(XP_CAP_KICKS), 0.0, 1.0)
		var bounce_vy := -randf_range(580.0, 650.0) * vp_scale * lerpf(0.92, 1.36, diff_t)
		var drift_range := lerpf(85.0, 290.0, diff_t) * vp_scale
		var bounce_vx := randf_range(-drift_range, drift_range)
		if absf(bounce_vx) < 42.0:
			bounce_vx = (42.0 if randf() < 0.5 else -42.0)
		_sipa_vel = Vector2(bounce_vx, bounce_vy)
		_sipa_ang_vel = randf_range(-8.0, 8.0)

		# Escalating combo pitch + tactile plastic kick thwack
		var combo_pitch := minf(1.85, 0.92 + float(_kicks) * 0.032)
		Juice.play_sfx("pickup", combo_pitch, 1.0)
		Juice.play_sfx("plastic", minf(1.75, 1.06 + float(_kicks) * 0.022), -5.0)
		if is_perfect:
			Juice.play_sfx("interact", combo_pitch + 0.16, 0.5)

		# Squash & stretch on the sipa + screen punch + spark burst
		if is_instance_valid(_sipa_sprite):
			_sipa_sprite.scale = Vector2(1.42, 0.62)
			var sq := _sipa_sprite.create_tween()
			sq.tween_property(_sipa_sprite, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		Juice.shake_control(_root, 7.5 if is_perfect else 4.5, 0.16)
		Juice.spawn_burst(_root, _sipa_pos, Color(1.0, 0.88, 0.36) if is_perfect else Color(0.62, 0.96, 0.56), 14 if is_perfect else 9, 130.0)
		Juice.pop_control(_kick_lbl, 1.24, 0.20)

		_kick_lbl.text = "Kicks: %d" % _kicks
		_status_lbl.text = "Perfect kick!" if is_perfect else "Swak! Keep it up!"
		_spawn_feedback("PERFECT!" if is_perfect else "Swak!", Color(1.0, 0.90, 0.38) if is_perfect else Color(0.62, 0.96, 0.56))
		_refresh_leaderboard()

		for entry in NEIGHBOR_SCORES:
			var target_score: int = int(entry["score"])
			if target_score > 0 and _kicks == target_score + 1:
				_status_lbl.text = "You beat %s's record (%d)!" % [str(entry["name"]), target_score]
				_spawn_feedback("Beat %s!" % str(entry["name"]), Color(1.0, 0.90, 0.42))
				Juice.play_sfx("interact", 1.42, 1.0)
				break
	else:
		_cooldown = EARLY_COOLDOWN
		_miss_flash = 1.0
		_status_lbl.text = "Too early — cooldown!"
		_spawn_feedback("Too early!", Color(0.98, 0.45, 0.42))
		Juice.play_sfx("error", 0.88, 0.5)
		Juice.shake_control(_root, 8.5, 0.20)


func _process(delta: float) -> void:
	if not is_open:
		return

	# Edge-triggered hardware Space check so Dialogic/UI focus can never swallow Spacebar
	var space_down := Input.is_key_pressed(KEY_SPACE)
	var space_just_pressed := space_down and not _prev_space_down
	_prev_space_down = space_down
	if space_just_pressed:
		if _phase == "intro":
			_on_intro_start()
		elif _phase == "playing":
			_attempt_kick()

	_hit_flash = maxf(0.0, _hit_flash - delta * 3.5)
	_miss_flash = maxf(0.0, _miss_flash - delta * 3.0)

	if _phase == "countdown":
		var prev_int := ceili(_countdown_t)
		_countdown_t -= delta
		var cur_int := ceili(_countdown_t)
		if cur_int != prev_int and cur_int > 0:
			_countdown_lbl.text = str(cur_int)
			Juice.pop_control(_countdown_lbl, 1.35, 0.28)
			Juice.play_sfx("ui_hover", 0.85 + float(3 - cur_int) * 0.15, 1.0)
		if _countdown_t <= 0.0:
			_phase = "playing"
			_countdown_lbl.visible = false
			_status_lbl.text = "Press Space or Click when the sipa enters the golden zone"
			_sipa_vel = Vector2(randf_range(-75.0, 75.0), 40.0)
			_sipa_ang_vel = 2.5
			Juice.play_sfx("pickup", 1.38, 1.5)
			_spawn_feedback("GO!", Color(1.0, 0.92, 0.54))
	elif _phase == "playing":
		if _hitstop > 0.0:
			_hitstop = maxf(0.0, _hitstop - delta)
			if is_instance_valid(_field_draw):
				_field_draw.queue_redraw()
			return
		_elapsed += delta
		if _cooldown > 0.0:
			_cooldown = maxf(0.0, _cooldown - delta)
			if _cooldown <= 0.0:
				_status_lbl.text = "Ready — press Space in the golden zone"

		var b := _get_bounds()
		var vp_scale := _get_vp_size().y / 720.0
		var diff_t := clampf(float(_kicks) / float(XP_CAP_KICKS), 0.0, 1.0)
		var endless_extra := minf(0.35, maxf(0.0, float(_kicks - XP_CAP_KICKS)) * 0.015)
		var gravity := lerpf(580.0, 1120.0, diff_t) * (1.0 + endless_extra) * vp_scale
		_sipa_vel.y += gravity * delta
		_sipa_pos += _sipa_vel * delta
		_sipa_rot += _sipa_ang_vel * delta

		var pad_x := SIPA_SIZE.x * 0.5 + 8.0
		if _sipa_pos.x < float(b["left"]) + pad_x:
			_sipa_pos.x = float(b["left"]) + pad_x
			_sipa_vel.x = absf(_sipa_vel.x) * 0.92
			Juice.play_sfx("ui_hover", 1.25, -6.0)
			Juice.spawn_burst(_root, Vector2(float(b["left"]), _sipa_pos.y), Color(1.0, 0.88, 0.56), 5, 55.0)
		elif _sipa_pos.x > float(b["right"]) - pad_x:
			_sipa_pos.x = float(b["right"]) - pad_x
			_sipa_vel.x = -absf(_sipa_vel.x) * 0.92
			Juice.play_sfx("ui_hover", 1.25, -6.0)
			Juice.spawn_burst(_root, Vector2(float(b["right"]), _sipa_pos.y), Color(1.0, 0.88, 0.56), 5, 55.0)
		if _sipa_pos.y < float(b["top"]):
			_sipa_pos.y = float(b["top"])
			_sipa_vel.y = absf(_sipa_vel.y) * 0.45
			Juice.play_sfx("ui_hover", 1.35, -7.0)

		_sync_sipa_visual()

		if _sipa_pos.y >= float(b["floor_y"]):
			Juice.shake_control(_root, 14.0, 0.30)
			var won := _kicks >= 6
			if _kicks > XP_CAP_KICKS:
				_finish_round(true, "New Barangay Champion!", "You beat Lolo Pilo's record with %d kicks! (Bonus XP capped at %d)" % [_kicks, XP_CAP_KICKS])
			elif won:
				_finish_round(true, "Great Rally!", "You kept the sipa airborne for %d kicks! Try to beat Lolo Pilo's 32!" % _kicks)
			else:
				_finish_round(false, "Dropped the Sipa!", "You reached %d kicks. Keep practicing your timing!" % _kicks)

	if is_instance_valid(_field_draw):
		_field_draw.queue_redraw()


func _sync_sipa_visual() -> void:
	if is_instance_valid(_sipa_sprite):
		_sipa_sprite.size = SIPA_SIZE
		_sipa_sprite.pivot_offset = SIPA_SIZE * 0.5
		_sipa_sprite.position = _sipa_pos - SIPA_SIZE * 0.5
		_sipa_sprite.rotation = _sipa_rot


func _spawn_feedback(txt: String, col: Color) -> void:
	var b := _get_bounds()
	var lbl := Label.new()
	lbl.text = txt
	lbl.position = Vector2(_sipa_pos.x - 48.0, float(b["zone_top"]) - 34.0)
	lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 46.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.55)
	tw.tween_callback(lbl.queue_free)


func _finish_round(won: bool, title: String, sub: String) -> void:
	_phase = "finished"
	_result_title.text = title
	_result_title.add_theme_color_override("font_color", Color(0.62, 0.96, 0.56) if won else Color(0.98, 0.48, 0.45))
	_result_sub.text = sub
	_result_panel.set_meta("won", won)
	Juice.pop_panel_in(_result_panel)
	if won:
		Juice.play_win_fanfare(self)
		var vp := _get_vp_size()
		Juice.spawn_burst(_root, vp * Vector2(0.35, 0.45), Color(1.0, 0.88, 0.36), 14, 180.0)
		Juice.spawn_burst(_root, vp * Vector2(0.65, 0.45), Color(0.60, 0.96, 0.58), 14, 180.0)
	else:
		Juice.play_lose_sting(self)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _phase == "playing":
			_attempt_kick()
	)
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

	# Fullscreen custom draw layer (perimeter guides + kick zone + shadow)
	_field_draw = Control.new()
	_field_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_field_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_draw.draw.connect(_draw_field)
	_root.add_child(_field_draw)

	# Floating Top-Center Title & Kicks (no box, Title Case)
	var header := VBoxContainer.new()
	header.anchor_left = 0.5
	header.anchor_right = 0.5
	header.anchor_top = 0.0
	header.offset_left = -260
	header.offset_right = 260
	header.offset_top = 22
	header.add_theme_constant_override("separation", 4)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(header)

	var title := Label.new()
	title.text = "Sipa Challenge"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UIStyle.FONT_INDER)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.93, 0.72))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.92))
	title.add_theme_constant_override("outline_size", 6)
	header.add_child(title)

	_kick_lbl = Label.new()
	_kick_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kick_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_kick_lbl.add_theme_font_size_override("font_size", 21)
	_kick_lbl.add_theme_color_override("font_color", Color(0.70, 0.96, 0.62))
	_kick_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.9))
	_kick_lbl.add_theme_constant_override("outline_size", 5)
	header.add_child(_kick_lbl)

	_status_lbl = Label.new()
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_status_lbl.add_theme_font_size_override("font_size", 15)
	_status_lbl.add_theme_color_override("font_color", Color(0.96, 0.90, 0.78, 0.88))
	_status_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.85))
	_status_lbl.add_theme_constant_override("outline_size", 4)
	header.add_child(_status_lbl)

	# Minimal floating close button top-right
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.anchor_left = 1.0
	close_btn.anchor_right = 1.0
	close_btn.offset_left = -58
	close_btn.offset_right = -18
	close_btn.offset_top = 18
	close_btn.offset_bottom = 58
	close_btn.pressed.connect(func(): close_minigame(false, true))
	_root.add_child(close_btn)

	# Top-Right Neighbor Leaderboard (Barangay Records)
	var board_panel := PanelContainer.new()
	board_panel.anchor_left = 1.0
	board_panel.anchor_right = 1.0
	board_panel.anchor_top = 0.0
	board_panel.offset_left = -228
	board_panel.offset_right = -18
	board_panel.offset_top = 68
	board_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bstyle := UIStyle.create_flat_stylebox(Color(0.08, 0.07, 0.06, 0.84), 10, 12, 10)
	bstyle.border_color = Color(0.86, 0.70, 0.36, 0.55)
	bstyle.set_border_width_all(1)
	board_panel.add_theme_stylebox_override("panel", bstyle)
	_root.add_child(board_panel)

	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 5)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_panel.add_child(bv)

	var btitle := Label.new()
	btitle.text = "Barangay Records"
	btitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btitle.add_theme_font_override("font", UIStyle.FONT_INDER)
	btitle.add_theme_font_size_override("font_size", 14)
	btitle.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62))
	btitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(btitle)

	_board_rows.clear()
	for entry in NEIGHBOR_SCORES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(row)

		var portrait := TextureRect.new()
		portrait.texture = _load_tex(str(entry["portrait"]))
		portrait.custom_minimum_size = Vector2(26, 26)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(portrait)

		var nlbl := Label.new()
		nlbl.text = str(entry["name"])
		nlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nlbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		nlbl.add_theme_font_size_override("font_size", 13)
		nlbl.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82))
		nlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(nlbl)

		var slbl := Label.new()
		slbl.text = str(int(entry["score"]))
		slbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slbl.custom_minimum_size = Vector2(34, 0)
		slbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		slbl.add_theme_font_size_override("font_size", 13)
		slbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.46))
		slbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(slbl)

		_board_rows.append({
			"score": int(entry["score"]),
			"name_lbl": nlbl,
			"score_lbl": slbl,
			"row": row,
		})

	# Sipa Sprite
	_sipa_sprite = TextureRect.new()
	_sipa_sprite.texture = _sipa_tex
	_sipa_sprite.custom_minimum_size = SIPA_SIZE
	_sipa_sprite.size = SIPA_SIZE
	_sipa_sprite.pivot_offset = SIPA_SIZE * 0.5
	_sipa_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sipa_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sipa_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_sipa_sprite)

	# 3-2-1 Countdown
	_countdown_lbl = Label.new()
	_countdown_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_countdown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_countdown_lbl.add_theme_font_size_override("font_size", 96)
	_countdown_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62))
	_countdown_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	_countdown_lbl.add_theme_constant_override("outline_size", 10)
	_countdown_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_countdown_lbl)

	# Intro instructions pop-up
	_intro_panel = PanelContainer.new()
	_intro_panel.set_anchors_preset(Control.PRESET_CENTER)
	_intro_panel.custom_minimum_size = Vector2(540, 265)
	_intro_panel.offset_left = -270
	_intro_panel.offset_right = 270
	_intro_panel.offset_top = -132
	_intro_panel.offset_bottom = 132
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
	ititle.text = "How to Play: Sipa"
	ititle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ititle.add_theme_font_override("font", UIStyle.FONT_INDER)
	ititle.add_theme_font_size_override("font_size", 30)
	ititle.add_theme_color_override("font_color", Color(1.0, 0.91, 0.64))
	iv.add_child(ititle)

	var idesc := Label.new()
	idesc.text = "Press Space or Click when the sipa enters the golden zone at the bottom to keep it airborne as long as you can. The zone narrows and gravity builds as your kicks climb — try to beat Lolo Pilo's record of 32!"
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


func _refresh_leaderboard() -> void:
	for item in _board_rows:
		var target_score: int = int(item["score"])
		var beaten := (_kicks > target_score) if target_score > 0 else (_kicks >= 1)
		var nlbl: Label = item["name_lbl"]
		var slbl: Label = item["score_lbl"]
		if beaten:
			nlbl.add_theme_color_override("font_color", Color(0.68, 0.96, 0.62))
			slbl.add_theme_color_override("font_color", Color(0.68, 0.96, 0.62))
			slbl.text = "%d ✓" % target_score
		else:
			var is_zero := target_score == 0
			nlbl.add_theme_color_override("font_color", Color(0.76, 0.72, 0.66) if is_zero else Color(0.94, 0.90, 0.82))
			slbl.add_theme_color_override("font_color", Color(0.68, 0.64, 0.58) if is_zero else Color(0.98, 0.84, 0.46))
			slbl.text = str(target_score)


func _draw_field() -> void:
	var b := _get_bounds()
	var left: float = float(b["left"])
	var right: float = float(b["right"])
	var zone_top: float = float(b["zone_top"])
	var zone_bottom: float = float(b["zone_bottom"])
	var floor_y: float = float(b["floor_y"])

	# Subtle glowing side perimeter rails
	_field_draw.draw_line(Vector2(left, 110.0), Vector2(left, floor_y), Color(0.95, 0.82, 0.48, 0.16), 2.0)
	_field_draw.draw_line(Vector2(right, 110.0), Vector2(right, floor_y), Color(0.95, 0.82, 0.48, 0.16), 2.0)

	# Bottom kick zone (translucent glowing band across the play perimeter)
	var half_h := SIPA_SIZE.y * 0.45
	var in_zone := _phase == "playing" and (_sipa_pos.y + half_h) >= zone_top and (_sipa_pos.y - half_h) <= zone_bottom
	var zone_col := Color(0.94, 0.76, 0.32, 0.16)
	var border_col := Color(0.96, 0.80, 0.38, 0.65)
	if _cooldown > 0.0:
		zone_col = Color(0.88, 0.28, 0.24, 0.20)
		border_col = Color(0.96, 0.38, 0.34, 0.82)
	elif in_zone:
		zone_col = Color(0.46, 0.90, 0.44, 0.26)
		border_col = Color(0.66, 0.98, 0.58, 0.95)
	if _hit_flash > 0.0:
		zone_col = zone_col.lerp(Color(0.65, 1.0, 0.58, 0.48), _hit_flash)

	var zone_rect := Rect2(left, zone_top, right - left, zone_bottom - zone_top)
	_field_draw.draw_rect(zone_rect, zone_col, true)
	_field_draw.draw_line(Vector2(left, zone_top), Vector2(right, zone_top), border_col, 2.5)
	_field_draw.draw_line(Vector2(left, zone_bottom), Vector2(right, zone_bottom), border_col, 2.5)

	# Cooldown bar when early-press locked
	if _cooldown > 0.0:
		var frac := clampf(_cooldown / EARLY_COOLDOWN, 0.0, 1.0)
		var cd_rect := Rect2(left + 6.0, zone_bottom - 9.0, (right - left - 12.0) * frac, 5.0)
		_field_draw.draw_rect(cd_rect, Color(0.98, 0.42, 0.38, 0.92), true)

	# Floor line + subtle sipa shadow
	_field_draw.draw_line(Vector2(left, floor_y), Vector2(right, floor_y), Color(0.92, 0.38, 0.34, 0.55), 2.5)
	var height_ratio := clampf(1.0 - (floor_y - _sipa_pos.y) / floor_y, 0.15, 1.0)
	_field_draw.draw_circle(Vector2(_sipa_pos.x, floor_y + 4.0), 22.0 * height_ratio, Color(0.0, 0.0, 0.0, 0.36 * height_ratio))
