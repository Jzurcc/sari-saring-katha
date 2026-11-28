class_name SipaMinigame
extends CanvasLayer

## Sipa Keepy-Uppy Minigame (Fullscreen Vignette UI).
## Starts with a 3-2-1 countdown, then drops the sipa across the full viewport
## inside a bounded store perimeter. Press SPACE (or Click) when the sipa enters
## the bottom kick zone to bounce it up and immediately refresh your kick!

signal minigame_finished(won: bool, result: Dictionary)

const Juice := preload("res://Scripts/UI/Minigames/MinigameJuice.gd")
const TEX_SIPA := "res://Assets/ui/minigames/sipa.png"
const SIPA_SIZE := Vector2(82.0, 82.0)
const EARLY_COOLDOWN := 0.45
const XP_CAP_KICKS := 32

const NEIGHBOR_SCORES: Array[Dictionary] = [
	{"name": "Lolo Pilo", "score": 480, "portrait": "res://Assets/characters/portraits/LoloPilo Face.png"},
	{"name": "Buboy", "score": 300, "portrait": "res://Assets/characters/portraits/Buboy Face.png"},
	{"name": "T.K.", "score": 210, "portrait": "res://Assets/characters/portraits/TK Face.png"},
	{"name": "Kuya Kap", "score": 140, "portrait": "res://Assets/characters/portraits/Kuya_Kap Face.png"},
	{"name": "Danilo", "score": 80, "portrait": "res://Assets/characters/portraits/Danilo Face.png"},
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
var _phase: String = "idle" # intro, countdown, playing, finished
var _countdown_t: float = 3.0
var _kicks: int = 0
var _score: int = 0
var _perfects: int = 0
var _start_diff: float = 0.0
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
var _perfect_streak: int = 0
var _wind_ax: float = 0.0
var _arc_style: String = "standard" # standard, high_lob, low_hop, curve
var _trail_pts: Array[Vector2] = []
var _trail_color: Color = Color(1.0, 0.86, 0.42, 1.0)
var _kick_rings: Array[Dictionary] = [] # {pos, r, max_r, alpha, col}

var _root: Control
var _field_draw: Control
var _sipa_sprite: TextureRect
var _countdown_lbl: Label
var _score_val_lbl: Label
var _kicks_val_lbl: Label
var _status_lbl: Label
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


func _get_vp_size() -> Vector2:
	var vp := get_viewport()
	if vp:
		var sz := vp.get_visible_rect().size
		if sz.x > 100.0 and sz.y > 100.0:
			return sz
	return Vector2(1280.0, 720.0)


func _get_diff_t() -> float:
	var kick_t := clampf(float(_score) / 480.0, 0.0, 1.0)
	return clampf(_start_diff + kick_t * (1.0 - _start_diff * 0.5), 0.0, 1.0)


func _get_bounds() -> Dictionary:
	var vp := _get_vp_size()
	var left := vp.x * 0.14
	var right := minf(vp.x * 0.76, vp.x - 320.0)
	var top := 132.0
	var floor_y := vp.y - 68.0
	var zone_bottom := floor_y - 14.0
	# Starts generous/tall on Day 1, gradually narrows with score and later days
	var diff_t := _get_diff_t()
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
	if not Juice.are_minigame_tutorials_enabled():
		_on_intro_start()


func _show_intro() -> void:
	var b := _get_bounds()
	var cx := (float(b["left"]) + float(b["right"])) * 0.5
	var vp := _get_vp_size()
	_phase = "intro"
	_prev_space_down = Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER)
	_kicks = 0
	_score = 0
	_perfects = 0
	var day_idx := maxi(0, StoryManager.day - 1) if is_instance_valid(StoryManager) else 0
	_start_diff = clampf(float(day_idx) * 0.055, 0.0, 0.40)
	_cooldown = 0.0
	_elapsed = 0.0
	_sipa_pos = Vector2(cx, vp.y * 0.30)
	_sipa_vel = Vector2.ZERO
	_sipa_rot = 0.0
	_sync_sipa_visual()
	_countdown_lbl.visible = false
	_result_overlay.visible = false
	_intro_overlay.visible = true
	call_deferred("_pop_intro_deferred")
	_refresh_hud_counters()
	_set_status("Ready to rally", Juice.COL_MUTED)
	_refresh_leaderboard()


func _pop_intro_deferred() -> void:
	if is_instance_valid(_intro_panel):
		Juice.pop_panel_in(_intro_panel)


func _on_intro_start() -> void:
	Juice.play_sfx("tab_switch", 1.15)
	_intro_overlay.visible = false
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
			"score": _score,
			"xp_cap": XP_CAP_KICKS,
			"elapsed": _elapsed,
		})


func _start_countdown() -> void:
	var b := _get_bounds()
	var cx := (float(b["left"]) + float(b["right"])) * 0.5
	var vp := _get_vp_size()
	_phase = "countdown"
	_countdown_t = 3.0
	_kicks = 0
	_score = 0
	_perfects = 0
	_cooldown = 0.0
	_elapsed = 0.0
	_hit_flash = 0.0
	_miss_flash = 0.0
	_result_overlay.visible = false
	_sipa_pos = Vector2(cx, vp.y * 0.30)
	_sipa_vel = Vector2.ZERO
	_sipa_rot = 0.0
	_sipa_ang_vel = 0.0
	_perfect_streak = 0
	_wind_ax = 0.0
	_arc_style = "standard"
	_trail_pts.clear()
	_trail_color = Color(1.0, 0.86, 0.42, 1.0)
	_kick_rings.clear()
	_sync_sipa_visual()
	_countdown_lbl.visible = true
	_countdown_lbl.text = "3"
	Juice.pop_control(_countdown_lbl, 1.35, 0.28)
	Juice.play_sfx("ui_hover", 0.85, 1.0)
	_set_status("Get ready...", Juice.COL_GOLD_BRIGHT)
	_refresh_hud_counters()
	_refresh_leaderboard()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _result_overlay.visible:
				close_minigame(bool(_result_panel.get_meta("won", false)), true)
			else:
				close_minigame(false, true)
			return
		if _phase == "intro" and event.keycode == KEY_ENTER:
			get_viewport().set_input_as_handled()
			_on_intro_start()
			return
		if _phase == "finished" and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			close_minigame(bool(_result_panel.get_meta("won", false)), true)
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
		if is_perfect:
			_perfects += 1
			_perfect_streak += 1
		else:
			_perfect_streak = 0

		var prev_score := _score
		var streak_bonus := 5 if _perfect_streak >= 3 else 0
		var pts := (20 if is_perfect else 10) + streak_bonus
		_score += pts

		var vp_scale := _get_vp_size().y / 720.0
		var diff_t := _get_diff_t()

		# Dynamic arc variability after Kick 2: Standard / High Lob / Quick Low Hop / Breeze Curve
		_arc_style = "standard"
		_wind_ax = 0.0
		if _kicks >= 3:
			var roll := randf()
			var special_chance := lerpf(0.32, 0.62, diff_t)
			if roll < special_chance:
				var pick := randf()
				if pick < 0.36:
					_arc_style = "high_lob"
				elif pick < 0.70:
					_arc_style = "low_hop"
				else:
					_arc_style = "curve"

		var height_mult := 1.0
		match _arc_style:
			"high_lob":
				height_mult = randf_range(1.16, 1.26)
			"low_hop":
				height_mult = randf_range(0.76, 0.85)
			"curve":
				height_mult = randf_range(0.95, 1.08)
				_wind_ax = (1.0 if randf() < 0.5 else -1.0) * randf_range(130.0, 240.0) * vp_scale

		var bounce_vy := -randf_range(575.0, 645.0) * height_mult * vp_scale * lerpf(0.92, 1.34, diff_t)
		var drift_range := lerpf(95.0, 310.0, diff_t) * vp_scale
		var bounce_vx := randf_range(-drift_range, drift_range)
		if absf(bounce_vx) < 48.0:
			bounce_vx = (48.0 if randf() < 0.5 else -48.0)
		_sipa_vel = Vector2(bounce_vx, bounce_vy)
		_sipa_ang_vel = randf_range(-10.0, 10.0)

		# Trail & shockwave ring color reflects Perfect / Arc Style
		if is_perfect:
			_trail_color = Color(1.0, 0.90, 0.36, 1.0)
		elif _arc_style == "high_lob":
			_trail_color = Color(0.54, 0.90, 1.0, 1.0)
		elif _arc_style == "low_hop":
			_trail_color = Color(1.0, 0.62, 0.32, 1.0)
		elif _arc_style == "curve":
			_trail_color = Color(0.68, 0.96, 0.66, 1.0)
		else:
			_trail_color = Color(0.96, 0.82, 0.48, 1.0)

		_kick_rings.append({
			"pos": _sipa_pos,
			"r": 18.0,
			"max_r": 92.0 if is_perfect else 68.0,
			"alpha": 0.92,
			"col": _trail_color,
		})

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
			sq.set_ignore_time_scale(true)
			sq.tween_property(_sipa_sprite, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		Juice.shake_control(_root, 7.5 if is_perfect else 4.5, 0.16)
		Juice.spawn_burst(_root, _sipa_pos, _trail_color, 15 if is_perfect else 9, 135.0)
		Juice.pop_control(_score_val_lbl, 1.24, 0.18)

		_refresh_hud_counters()
		var arc_tag := " · High Lob" if _arc_style == "high_lob" else (" · Quick Hop" if _arc_style == "low_hop" else (" · Breeze Curve" if _arc_style == "curve" else ""))
		var fb_txt := ("PERFECT x%d! +%d" % [_perfect_streak, pts]) if (is_perfect and _perfect_streak >= 3) else ("PERFECT! +%d" % pts if is_perfect else "Swak! +%d" % pts)
		_set_status(fb_txt + arc_tag, _trail_color if is_perfect else Juice.COL_SUCCESS)
		_spawn_feedback(fb_txt, _trail_color if is_perfect else Juice.COL_SUCCESS, 0.0)
		_refresh_leaderboard()

		for entry in NEIGHBOR_SCORES:
			var target_score: int = int(entry["score"])
			if target_score > 0 and prev_score <= target_score and _score > target_score:
				_set_status("Beat %s's record (%d)!" % [str(entry["name"]), target_score], Juice.COL_GOLD_BRIGHT)
				_spawn_feedback("Beat %s!" % str(entry["name"]), Color(1.0, 0.90, 0.42), -62.0)
				Juice.play_sfx("interact", 1.42, 1.0)
				break
	else:
		_cooldown = EARLY_COOLDOWN
		_miss_flash = 1.0
		_set_status("Too early — cooldown!", Juice.COL_DANGER)
		_spawn_feedback("Too early!", Juice.COL_DANGER)
		Juice.play_sfx("error", 0.88, 0.5)
		Juice.shake_control(_root, 8.5, 0.20)


func _refresh_hud_counters() -> void:
	if is_instance_valid(_score_val_lbl):
		_score_val_lbl.text = str(_score)
	if is_instance_valid(_kicks_val_lbl):
		_kicks_val_lbl.text = str(_kicks)


func _set_status(txt: String, col: Color) -> void:
	if is_instance_valid(_status_lbl):
		_status_lbl.text = txt
		_status_lbl.add_theme_color_override("font_color", col)


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
			_set_status("Kick in the golden zone!", Juice.COL_CREAM)
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
				_set_status("Ready!", Juice.COL_SUCCESS)

		var b := _get_bounds()
		var vp_scale := _get_vp_size().y / 720.0
		var diff_t := _get_diff_t()
		var endless_extra := minf(0.35, maxf(0.0, float(_kicks - XP_CAP_KICKS)) * 0.015)
		var grav_mult := 0.88 if _arc_style == "high_lob" else (1.08 if _arc_style == "low_hop" else 1.0)
		var gravity := lerpf(580.0, 1120.0, diff_t) * (1.0 + endless_extra) * grav_mult * vp_scale
		_sipa_vel.x += _wind_ax * delta
		_sipa_vel.y += gravity * delta
		_sipa_pos += _sipa_vel * delta
		_sipa_rot += _sipa_ang_vel * delta

		# Record smooth ribbon trail points
		if _trail_pts.is_empty() or _trail_pts[_trail_pts.size() - 1].distance_squared_to(_sipa_pos) > 9.0:
			_trail_pts.append(_sipa_pos)
			if _trail_pts.size() > 18:
				_trail_pts.pop_front()

		# Animate expanding kick shockwave rings
		for ri in range(_kick_rings.size() - 1, -1, -1):
			var ring: Dictionary = _kick_rings[ri]
			ring["r"] = lerpf(float(ring["r"]), float(ring["max_r"]), clampf(delta * 11.0, 0.0, 1.0))
			ring["alpha"] = float(ring["alpha"]) - delta * 3.4
			if float(ring["alpha"]) <= 0.02:
				_kick_rings.remove_at(ri)

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
				_finish_round(true, "Great Rally!", "You kept the sipa airborne for %d kicks! Try to beat Lolo Pilo's 480!" % _kicks)
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


func _spawn_feedback(txt: String, col: Color, y_extra_offset: float = 0.0) -> void:
	var b := _get_bounds()
	var lbl := Label.new()
	lbl.text = txt
	lbl.position = Vector2(_sipa_pos.x - 62.0, float(b["zone_top"]) - 36.0 + y_extra_offset)
	Juice.style_hud_label(lbl, UIStyle.FONT_FREDOKA_BOLD, 23, col, 5)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 46.0, 0.52).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.52)
	tw.tween_callback(lbl.queue_free)


func _finish_round(won: bool, title: String, sub: String) -> void:
	_phase = "finished"
	_result_title.text = title
	_result_title.add_theme_color_override("font_color", Juice.COL_SUCCESS if won else Juice.COL_DANGER)
	_result_sub.text = sub
	_result_panel.set_meta("won", won)

	for ch in _result_stats_row.get_children():
		_result_stats_row.remove_child(ch)
		ch.queue_free()
	_result_stats_row.add_child(Juice.make_stat_chip("Score", str(_score), Juice.COL_GOLD_BRIGHT))
	_result_stats_row.add_child(Juice.make_stat_chip("Kicks", str(_kicks), Juice.COL_SUCCESS if won else Juice.COL_CREAM))
	_result_stats_row.add_child(Juice.make_stat_chip("Perfects", str(_perfects), Color(1.0, 0.84, 0.42)))

	_result_overlay.visible = true
	call_deferred("_pop_result_deferred")
	if won:
		Juice.play_win_fanfare(self)
		var vp := _get_vp_size()
		Juice.spawn_burst(_root, vp * Vector2(0.35, 0.45), Color(1.0, 0.88, 0.36), 14, 180.0)
		Juice.spawn_burst(_root, vp * Vector2(0.65, 0.45), Color(0.60, 0.96, 0.58), 14, 180.0)
	else:
		Juice.play_lose_sting(self)


func _pop_result_deferred() -> void:
	if is_instance_valid(_result_panel):
		Juice.pop_panel_in(_result_panel)


func _build_ui() -> void:
	# Fullscreen Vignette Backdrop directly on CanvasLayer with overscan so screen shake never exposes unfaded edges
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.offset_left = -36
	vig.offset_top = -36
	vig.offset_right = 36
	vig.offset_bottom = 36
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	vig.material = mat
	add_child(vig)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _phase == "playing":
			_attempt_kick()
	)
	add_child(_root)

	# Fullscreen custom draw layer (perimeter guides + kick zone + sweet spot + shadow)
	_field_draw = Control.new()
	_field_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_field_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_draw.draw.connect(_draw_field)
	_root.add_child(_field_draw)

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
	title.text = "Sipa Challenge"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Juice.style_hud_label(title, UIStyle.FONT_FREDOKA_BOLD, 30, Juice.COL_GOLD_BRIGHT, 5)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title)

	var hud_center := HBoxContainer.new()
	hud_center.alignment = BoxContainer.ALIGNMENT_CENTER
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

	# Score pair
	var sc_box := HBoxContainer.new()
	sc_box.alignment = BoxContainer.ALIGNMENT_CENTER
	sc_box.add_theme_constant_override("separation", 6)
	sc_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_row.add_child(sc_box)

	var sc_k := Label.new()
	sc_k.text = "Score"
	sc_k.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	sc_k.add_theme_font_size_override("font_size", 15)
	sc_k.add_theme_color_override("font_color", Juice.COL_MUTED)
	sc_k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc_box.add_child(sc_k)

	_score_val_lbl = Label.new()
	_score_val_lbl.text = "0"
	_score_val_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	_score_val_lbl.add_theme_font_size_override("font_size", 22)
	_score_val_lbl.add_theme_color_override("font_color", Juice.COL_GOLD_BRIGHT)
	_score_val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc_box.add_child(_score_val_lbl)

	hud_row.add_child(Juice.make_vsep(22.0))

	# Kicks pair
	var kk_box := HBoxContainer.new()
	kk_box.alignment = BoxContainer.ALIGNMENT_CENTER
	kk_box.add_theme_constant_override("separation", 6)
	kk_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_row.add_child(kk_box)

	var kk_k := Label.new()
	kk_k.text = "Kicks"
	kk_k.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	kk_k.add_theme_font_size_override("font_size", 15)
	kk_k.add_theme_color_override("font_color", Juice.COL_MUTED)
	kk_k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kk_box.add_child(kk_k)

	_kicks_val_lbl = Label.new()
	_kicks_val_lbl.text = "0"
	_kicks_val_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	_kicks_val_lbl.add_theme_font_size_override("font_size", 22)
	_kicks_val_lbl.add_theme_color_override("font_color", Juice.COL_SUCCESS)
	_kicks_val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kk_box.add_child(_kicks_val_lbl)

	hud_row.add_child(Juice.make_vsep(22.0))

	_status_lbl = Label.new()
	_status_lbl.custom_minimum_size = Vector2(165, 0)
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	_status_lbl.add_theme_font_size_override("font_size", 16)
	_status_lbl.add_theme_color_override("font_color", Juice.COL_CREAM)
	_status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_row.add_child(_status_lbl)

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
	board_card.offset_left = -304
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
	for entry in NEIGHBOR_SCORES:
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
		slbl.text = str(int(entry["score"]))
		slbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slbl.custom_minimum_size = Vector2(56, 0)
		slbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
		slbl.add_theme_font_size_override("font_size", 16)
		slbl.add_theme_color_override("font_color", Juice.COL_GOLD_BRIGHT)
		slbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(slbl)

		_board_rows.append({
			"score": int(entry["score"]),
			"name_lbl": nlbl,
			"score_lbl": slbl,
			"row": row,
		})

	# Bottom safe-zone keycap prompt pill
	var hint_wrap := HBoxContainer.new()
	hint_wrap.anchor_left = 0.5
	hint_wrap.anchor_right = 0.5
	hint_wrap.anchor_top = 1.0
	hint_wrap.anchor_bottom = 1.0
	hint_wrap.offset_left = -280
	hint_wrap.offset_right = 280
	hint_wrap.offset_top = -52
	hint_wrap.offset_bottom = -18
	hint_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	hint_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hint_wrap)

	var hint_pill := PanelContainer.new()
	hint_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_pill.add_theme_stylebox_override("panel", Juice.make_pill_style(Color(0.08, 0.06, 0.05, 0.78), Color(0.88, 0.70, 0.34, 0.26), 12, 16, 6, 1))
	hint_wrap.add_child(hint_pill)

	var hint_row := HBoxContainer.new()
	hint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hint_row.add_theme_constant_override("separation", 8)
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_pill.add_child(hint_row)

	hint_row.add_child(Juice.make_keycap_pill("Space"))
	var or_lbl := Label.new()
	or_lbl.text = "or"
	or_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	or_lbl.add_theme_font_size_override("font_size", 14)
	or_lbl.add_theme_color_override("font_color", Juice.COL_MUTED)
	or_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_row.add_child(or_lbl)
	hint_row.add_child(Juice.make_keycap_pill("Click"))
	var htxt := Label.new()
	htxt.text = "Kick in the golden zone • Hit center for Perfect (+20)"
	htxt.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	htxt.add_theme_font_size_override("font_size", 15)
	htxt.add_theme_color_override("font_color", Juice.COL_CREAM)
	htxt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_row.add_child(htxt)

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
	Juice.style_hud_label(_countdown_lbl, UIStyle.FONT_FREDOKA_BOLD, 96, Juice.COL_GOLD_BRIGHT, 10)
	_countdown_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_countdown_lbl)

	# --- INTRO MODAL (Responsive CenterContainer) ---
	var intro_shell := Juice.make_modal_shell(_root, Vector2(560, 0))
	_intro_overlay = intro_shell["overlay"]
	_intro_panel = intro_shell["panel"]
	var iv: VBoxContainer = intro_shell["vbox"]

	var ititle := Label.new()
	ititle.text = "Sipa Challenge"
	ititle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ititle.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	ititle.add_theme_font_size_override("font_size", 32)
	ititle.add_theme_color_override("font_color", Juice.COL_GOLD_BRIGHT)
	iv.add_child(ititle)

	var keys_row := HBoxContainer.new()
	keys_row.alignment = BoxContainer.ALIGNMENT_CENTER
	keys_row.add_theme_constant_override("separation", 10)
	iv.add_child(keys_row)
	keys_row.add_child(Juice.make_keycap_pill("Space"))
	var slash := Label.new()
	slash.text = "or"
	slash.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	slash.add_theme_font_size_override("font_size", 15)
	slash.add_theme_color_override("font_color", Juice.COL_MUTED)
	keys_row.add_child(slash)
	keys_row.add_child(Juice.make_keycap_pill("Left Click"))
	var act := Label.new()
	act.text = "to Kick"
	act.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	act.add_theme_font_size_override("font_size", 16)
	act.add_theme_color_override("font_color", Juice.COL_CREAM)
	keys_row.add_child(act)

	var idesc := Label.new()
	idesc.text = "Kick when the sipa enters the golden zone to keep it airborne. Aim for the center line for Perfect (+20) points — the zone narrows and gravity builds as you climb!"
	idesc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	idesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	idesc.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	idesc.add_theme_font_size_override("font_size", 18)
	idesc.add_theme_color_override("font_color", Juice.COL_CREAM)
	iv.add_child(idesc)

	var start_btn := Button.new()
	start_btn.text = "Start Rally"
	Juice.style_primary_button(start_btn, Vector2(220, 50))
	start_btn.pressed.connect(_on_intro_start)
	iv.add_child(start_btn)

	# --- RESULT MODAL ---
	var res_shell := Juice.make_modal_shell(_root, Vector2(520, 0))
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


func _refresh_leaderboard() -> void:
	for item in _board_rows:
		var target_score: int = int(item["score"])
		var beaten := (_score > target_score) if target_score > 0 else (_score >= 1)
		var nlbl: Label = item["name_lbl"]
		var slbl: Label = item["score_lbl"]
		if beaten:
			nlbl.add_theme_color_override("font_color", Juice.COL_SUCCESS)
			slbl.add_theme_color_override("font_color", Juice.COL_SUCCESS)
			slbl.text = "%d ✓" % target_score
		else:
			var is_zero := target_score == 0
			nlbl.add_theme_color_override("font_color", Juice.COL_MUTED if is_zero else Juice.COL_CREAM)
			slbl.add_theme_color_override("font_color", Juice.COL_MUTED if is_zero else Juice.COL_GOLD_BRIGHT)
			slbl.text = str(target_score)


func _draw_field() -> void:
	var b := _get_bounds()
	var left: float = float(b["left"])
	var right: float = float(b["right"])
	var zone_top: float = float(b["zone_top"])
	var zone_bottom: float = float(b["zone_bottom"])
	var floor_y: float = float(b["floor_y"])
	var zone_mid := (zone_top + zone_bottom) * 0.5

	# Subtle glowing side perimeter rails
	_field_draw.draw_line(Vector2(left, 126.0), Vector2(left, floor_y), Color(0.95, 0.82, 0.48, 0.18), 2.0)
	_field_draw.draw_line(Vector2(right, 126.0), Vector2(right, floor_y), Color(0.95, 0.82, 0.48, 0.18), 2.0)

	# Bottom kick zone (translucent glowing band across the play perimeter)
	var half_h := SIPA_SIZE.y * 0.45
	var in_zone := _phase == "playing" and (_sipa_pos.y + half_h) >= zone_top and (_sipa_pos.y - half_h) <= zone_bottom
	var zone_col := Color(0.94, 0.76, 0.32, 0.16)
	var border_col := Color(0.96, 0.80, 0.38, 0.68)
	if _cooldown > 0.0:
		zone_col = Color(0.88, 0.28, 0.24, 0.22)
		border_col = Color(0.96, 0.38, 0.34, 0.86)
	elif in_zone:
		zone_col = Color(0.46, 0.90, 0.44, 0.26)
		border_col = Color(0.66, 0.98, 0.58, 0.96)
	if _hit_flash > 0.0:
		zone_col = zone_col.lerp(Color(0.65, 1.0, 0.58, 0.48), _hit_flash)

	var zone_rect := Rect2(left, zone_top, right - left, zone_bottom - zone_top)
	_field_draw.draw_rect(zone_rect, zone_col, true)
	_field_draw.draw_line(Vector2(left, zone_top), Vector2(right, zone_top), border_col, 2.5, true)
	_field_draw.draw_line(Vector2(left, zone_bottom), Vector2(right, zone_bottom), border_col, 2.5, true)

	# Diegetic Perfect (+20) Sweet-Spot center guide line
	var sweet_col := Color(1.0, 0.92, 0.54, 0.55 if in_zone else 0.30)
	_field_draw.draw_dashed_line(Vector2(left + 12.0, zone_mid), Vector2(right - 12.0, zone_mid), sweet_col, 2.0, 10.0)

	# Cooldown bar when early-press locked
	if _cooldown > 0.0:
		var frac := clampf(_cooldown / EARLY_COOLDOWN, 0.0, 1.0)
		var cd_rect := Rect2(left + 8.0, zone_bottom - 9.0, (right - left - 16.0) * frac, 5.0)
		_field_draw.draw_rect(cd_rect, Color(0.98, 0.42, 0.38, 0.94), true)

	# Floor line + subtle sipa shadow
	_field_draw.draw_line(Vector2(left, floor_y), Vector2(right, floor_y), Color(0.92, 0.38, 0.34, 0.58), 2.5, true)
	var height_ratio := clampf(1.0 - (floor_y - _sipa_pos.y) / floor_y, 0.15, 1.0)
	_field_draw.draw_circle(Vector2(_sipa_pos.x, floor_y + 4.0), 22.0 * height_ratio, Color(0.0, 0.0, 0.0, 0.38 * height_ratio))

	# Subtle drifting wind streaks during Breeze Curve arcs
	if _phase == "playing" and absf(_wind_ax) > 10.0:
		var dir_sign := 1.0 if _wind_ax > 0.0 else -1.0
		var w_col := Color(0.74, 0.96, 0.72, 0.22)
		for wi in range(4):
			var wy := lerpf(190.0, zone_top - 40.0, float(wi) / 3.0)
			var wx := left + fposmod(_elapsed * 220.0 * dir_sign + float(wi) * 145.0, maxf(60.0, right - left - 60.0))
			_field_draw.draw_line(Vector2(wx, wy), Vector2(wx + 46.0 * dir_sign, wy), w_col, 2.0, true)

	# Glowing tapered ribbon trail behind the sipa
	if _phase == "playing" and _trail_pts.size() >= 2:
		var n := _trail_pts.size()
		for i in range(n - 1):
			var t := float(i + 1) / float(n)
			var w := lerpf(2.5, 19.0, t * t)
			var a := t * t * 0.52
			var seg_col := Color(_trail_color.r, _trail_color.g, _trail_color.b, a)
			_field_draw.draw_line(_trail_pts[i], _trail_pts[i + 1], seg_col, w, true)
			# Crisp bright inner core on the newest half of the trail
			if t > 0.45:
				var core_col := Color(1.0, 0.98, 0.90, (t - 0.45) * 0.65)
				_field_draw.draw_line(_trail_pts[i], _trail_pts[i + 1], core_col, w * 0.36, true)

	# Expanding kick shockwave rings
	for ring in _kick_rings:
		var rc: Color = ring["col"]
		_field_draw.draw_arc(ring["pos"], float(ring["r"]), 0.0, TAU, 36, Color(rc.r, rc.g, rc.b, float(ring["alpha"])), 3.0, true)
