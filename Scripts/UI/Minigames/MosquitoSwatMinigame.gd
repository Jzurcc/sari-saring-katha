class_name MosquitoSwatMinigame
extends CanvasLayer

## Mosquito & Firefly Swat Minigame (Fullscreen Vignette UI).
## Mosquitoes and glowing fireflies fly in from the edges of the entire screen.
## Swat mosquitoes to fill the score bar before time runs out while sparing fireflies!

signal minigame_finished(won: bool, result: Dictionary)

const Juice := preload("res://Scripts/UI/Minigames/MinigameJuice.gd")
const TEX_MOSQUITO := "res://Assets/ui/minigames/mosquito/mosquito.png"
const TEX_MOSQUITO_DEAD := "res://Assets/ui/minigames/mosquito/mosquito_dead.png"
const TEX_FIREFLY := "res://Assets/ui/minigames/mosquito/firefly.png"
const TEX_FIREFLY_DEAD := "res://Assets/ui/minigames/mosquito/firefly_dead.png"
const SFX_SWAT_PATH := "res://Audio/SFX/swat.wav"

const MOSQUITO_SIZE := Vector2(256.0, 256.0)
const FIREFLY_SIZE := Vector2(244.0, 244.0)
const MOSQUITO_HIT_RADIUS := 145.0
const FIREFLY_HIT_RADIUS := 82.0
const TARGET_SCORE := 12
const MAX_LIVES := 3
const ROUND_TIME := 25.0

const VIGNETTE_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.02, 0.018, 0.028, 0.94);
void fragment() {
	vec2 d = UV - vec2(0.5);
	float dist = length(d * vec2(1.12, 1.0));
	float vig = smoothstep(0.12, 0.72, dist);
	COLOR = vec4(tint.rgb, mix(0.48, tint.a, vig));
}
"""

var is_open: bool = false
var _active: bool = false
var _score: int = 0
var _lives: int = MAX_LIVES
var _time_left: float = ROUND_TIME
var _spawn_timer: float = 0.0
var _streak: int = 0
var _streak_timer: float = 0.0
var _last_tick_sec: int = -1
var _start_diff: float = 0.0
var _target_score: int = TARGET_SCORE
var _bugs: Array[Dictionary] = []
var _ripples: Array[Dictionary] = []

var _tex_mosq: Texture2D
var _tex_mosq_dead: Texture2D
var _tex_firefly: Texture2D
var _tex_firefly_dead: Texture2D
var _sfx_swat: AudioStream

var _root: Control
var _arena: Control
var _arena_fx: Control
var _score_bar: ProgressBar
var _score_lbl: Label
var _timer_lbl: Label
var _timer_icon: TextureRect
var _streak_pill: PanelContainer
var _streak_lbl: Label
var _lives_box: HBoxContainer
var _intro_overlay: ColorRect
var _intro_panel: PanelContainer
var _result_overlay: ColorRect
var _result_panel: PanelContainer
var _result_title: Label
var _result_sub: Label
var _result_stats_row: HBoxContainer
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


func _ready() -> void:
	layer = 42
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tex_mosq = _load_tex(TEX_MOSQUITO)
	_tex_mosq_dead = _load_tex(TEX_MOSQUITO_DEAD)
	_tex_firefly = _load_tex(TEX_FIREFLY)
	_tex_firefly_dead = _load_tex(TEX_FIREFLY_DEAD)
	_sfx_swat = _load_swat_sfx()
	_build_ui()
	visible = false


static func _load_swat_sfx() -> AudioStream:
	if ResourceLoader.exists(SFX_SWAT_PATH):
		var res := load(SFX_SWAT_PATH)
		if res is AudioStream:
			return res
	if FileAccess.file_exists(SFX_SWAT_PATH):
		var wav := AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(SFX_SWAT_PATH))
		if wav:
			return wav
	return null


func _play_swat_sfx(pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if _sfx_swat == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = _sfx_swat
	player.pitch_scale = pitch
	player.volume_db = vol_db
	player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


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
	_clear_bugs()
	_ripples.clear()
	_score = 0
	_lives = MAX_LIVES
	_time_left = ROUND_TIME
	_streak = 0
	_streak_timer = 0.0
	_last_tick_sec = -1
	_active = false
	_result_overlay.visible = false
	_intro_overlay.visible = true
	call_deferred("_pop_intro_deferred")
	_refresh_hud()


func _pop_intro_deferred() -> void:
	if is_instance_valid(_intro_panel):
		Juice.pop_panel_in(_intro_panel)


func _on_intro_start() -> void:
	Juice.play_sfx("tab_switch", 1.15)
	_intro_overlay.visible = false
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
			"target": _target_score,
			"lives_left": _lives,
			"time_left": _time_left,
		})


func _start_round() -> void:
	_clear_bugs()
	_ripples.clear()
	_score = 0
	_lives = MAX_LIVES
	_time_left = ROUND_TIME
	_spawn_timer = 0.25
	_streak = 0
	_streak_timer = 0.0
	_last_tick_sec = -1
	var day_idx := maxi(0, StoryManager.day - 1) if is_instance_valid(StoryManager) else 0
	_start_diff = clampf(float(day_idx) * 0.07, 0.0, 0.48)
	_target_score = TARGET_SCORE + (2 if day_idx >= 3 else 0) + (2 if day_idx >= 6 else 0)
	_active = true
	_result_overlay.visible = false
	Juice.play_sfx("pickup", 1.18, 0.5)
	_refresh_hud()
	# Spawn gentle initial wave (slightly more fireflies & bugs on later days)
	var init_mosq := 3 + (1 if day_idx >= 4 else 0)
	var init_ff := 1 + (1 if day_idx >= 2 else 0) + (1 if day_idx >= 5 else 0)
	for _i in range(init_mosq):
		_spawn_bug(false)
	for _j in range(init_ff):
		_spawn_bug(true)


func _get_diff_t() -> float:
	var prog := clampf(float(_score) / float(maxi(1, _target_score)), 0.0, 1.0)
	return clampf(_start_diff + prog * (1.0 - _start_diff * 0.45), 0.0, 1.0)


func _clear_bugs() -> void:
	for b in _bugs:
		var raw_node = b.get("node")
		if is_instance_valid(raw_node):
			(raw_node as Node).queue_free()
	_bugs.clear()


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


func _process(delta: float) -> void:
	if not is_open:
		return

	for i in range(_ripples.size() - 1, -1, -1):
		_ripples[i]["t"] = float(_ripples[i]["t"]) + delta * 2.8
		if float(_ripples[i]["t"]) >= 1.0:
			_ripples.remove_at(i)
	if is_instance_valid(_arena_fx):
		_arena_fx.queue_redraw()

	if not _active:
		return

	if _streak_timer > 0.0:
		_streak_timer = maxf(0.0, _streak_timer - delta)
		if _streak_timer <= 0.0:
			_streak = 0
			_refresh_streak_pill()

	_time_left = maxf(0.0, _time_left - delta)
	_refresh_timer_label()
	if _time_left > 0.0 and _time_left <= 5.0:
		var sec := ceili(_time_left)
		if sec != _last_tick_sec:
			_last_tick_sec = sec
			Juice.play_sfx("ui_hover", 1.38, -3.0)
			Juice.pop_control(_timer_lbl, 1.24, 0.18)
	if _time_left <= 0.0:
		_finish_round(false, "Time's Up!", "The mosquitoes took over the counter. Swatted %d / %d." % [_score, _target_score])
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		var diff_t := _get_diff_t()
		var max_mosq := int(roundf(lerpf(4.0, 7.0, diff_t)))
		var max_ff := int(roundf(lerpf(2.0, 4.0, diff_t)))
		var live_mosq := 0
		var live_ff := 0
		for b in _bugs:
			if not bool(b["dead"]):
				if bool(b["is_firefly"]):
					live_ff += 1
				else:
					live_mosq += 1
		if live_mosq < max_mosq:
			_spawn_bug(false)
		if live_ff < max_ff and randf() < lerpf(0.28, 0.48, diff_t):
			_spawn_bug(true)
		_spawn_timer = lerpf(1.05, 0.48, diff_t) + randf_range(-0.08, 0.12)

	var bounds := _get_vp_size()
	for i in range(_bugs.size() - 1, -1, -1):
		var b: Dictionary = _bugs[i]
		var raw_node = b.get("node")
		if not is_instance_valid(raw_node):
			_bugs.remove_at(i)
			continue
		if bool(b["dead"]):
			continue
		var node: Control = raw_node as Control

		b["age"] = float(b["age"]) + delta
		var pos: Vector2 = b["pos"]
		var vel: Vector2 = b["vel"]

		# Organic mid-flight course changes (veers into vertical climbs/dives or sharp zig-zags)
		var steer_t := float(b.get("steer_timer", 1.2)) - delta
		if steer_t <= 0.0:
			var max_turn := 0.78 if bool(b["is_firefly"]) else 0.62
			vel = vel.rotated(randf_range(-max_turn, max_turn))
			var spd_jitter := randf_range(0.90, 1.12)
			var base_spd := float(b.get("base_spd", vel.length()))
			vel = vel.normalized() * clampf(vel.length() * spd_jitter, base_spd * 0.80, base_spd * 1.22)
			steer_t = randf_range(0.55, 1.35) if bool(b["is_firefly"]) else randf_range(0.75, 1.85)
		b["steer_timer"] = steer_t

		var wobble := sin(float(b["age"]) * float(b["freq"]) + float(b["phase"])) * float(b["amp"])
		var perp := Vector2(-vel.y, vel.x).normalized()
		pos += (vel + perp * wobble) * delta

		# Bounce gently inside the visible screen once they have flown in from the edges
		var entered: bool = bool(b["entered"])
		var pad := 68.0
		var top_pad := 148.0
		if not entered:
			if pos.x >= pad and pos.x <= bounds.x - pad and pos.y >= top_pad and pos.y <= bounds.y - pad:
				b["entered"] = true
		else:
			if pos.x < pad:
				pos.x = pad
				vel.x = absf(vel.x)
			elif pos.x > bounds.x - pad:
				pos.x = bounds.x - pad
				vel.x = -absf(vel.x)
			if pos.y < top_pad:
				pos.y = top_pad
				vel.y = absf(vel.y)
			elif pos.y > bounds.y - pad:
				pos.y = bounds.y - pad
				vel.y = -absf(vel.y)

		b["pos"] = pos
		b["vel"] = vel
		var sz := node.size
		node.position = pos - sz * 0.5
		if node is TextureRect:
			if absf(vel.x) > 14.0:
				(node as TextureRect).flip_h = vel.x > 0.0
			var pitch_sign := 1.0 if (node as TextureRect).flip_h else -1.0
			var vert_ratio := clampf(vel.y / maxf(1.0, vel.length()), -1.0, 1.0)
			node.rotation = lerpf(node.rotation, vert_ratio * 0.42 * pitch_sign, clampf(delta * 8.0, 0.0, 1.0))
		if bool(b["is_firefly"]):
			var glow := 0.82 + 0.18 * sin(float(b["age"]) * 6.8 + float(b["phase"]))
			node.modulate = Color(1.0, 0.98, 0.80, glow)


func _spawn_bug(is_firefly: bool) -> void:
	var bounds := _get_vp_size()
	var tr := TextureRect.new()
	tr.texture = _tex_firefly if is_firefly else _tex_mosq
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var sz := FIREFLY_SIZE if is_firefly else MOSQUITO_SIZE
	tr.custom_minimum_size = sz
	tr.size = sz
	tr.pivot_offset = sz * 0.5
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Spawn from all 4 edges (~42% vertical top/bottom flyers, ~58% left/right & steep diagonal flyers)
	var edge_roll := randf()
	var pos: Vector2
	var target: Vector2
	if edge_roll < 0.21:
		# Top-down vertical / steep dive
		pos = Vector2(randf_range(110.0, bounds.x - 110.0), -72.0)
		target = Vector2(
			clampf(pos.x + randf_range(-220.0, 220.0), 110.0, bounds.x - 110.0),
			randf_range(bounds.y * 0.55, bounds.y - 100.0)
		)
	elif edge_roll < 0.42:
		# Bottom-up vertical climb
		pos = Vector2(randf_range(110.0, bounds.x - 110.0), bounds.y + 72.0)
		target = Vector2(
			clampf(pos.x + randf_range(-220.0, 220.0), 110.0, bounds.x - 110.0),
			randf_range(165.0, bounds.y * 0.48)
		)
	else:
		# Left or right edge (with much wider vertical target spread for diagonal climbs/dives)
		var from_left := edge_roll < 0.71
		pos = Vector2(
			-72.0 if from_left else bounds.x + 72.0,
			randf_range(155.0, bounds.y - 85.0)
		)
		target = Vector2(
			randf_range(bounds.x * 0.20, bounds.x * 0.80),
			randf_range(160.0, bounds.y - 95.0)
		)

	var diff_t := _get_diff_t()
	var base_speed: float
	if is_firefly:
		# Fireflies zip noticeably faster than mosquitoes across the lamp light
		base_speed = randf_range(680.0, 960.0)
	else:
		var roll := randf()
		if roll < 0.28:
			base_speed = randf_range(200.0, 300.0) # Slow drifter
		elif roll < 0.72:
			base_speed = randf_range(350.0, 485.0) # Normal buzz
		else:
			base_speed = randf_range(510.0, 650.0) # Fast mosquito dart
	var speed_scale := lerpf(0.74, 1.16, diff_t) if is_firefly else lerpf(0.58, 1.12, diff_t)
	var speed: float = base_speed * speed_scale
	var vel := (target - pos).normalized() * speed

	tr.position = pos - sz * 0.5
	tr.flip_h = vel.x > 0.0
	_arena.add_child(tr)

	var amp_mult := lerpf(0.65, 1.12, diff_t)
	var bug_dict := {
		"node": tr,
		"is_firefly": is_firefly,
		"dead": false,
		"entered": false,
		"pos": pos,
		"vel": vel,
		"base_spd": speed,
		"steer_timer": randf_range(0.55, 1.50),
		"age": 0.0,
		"freq": randf_range(4.8, 7.8) if is_firefly else randf_range(4.2, 8.8),
		"amp": randf_range(46.0, 88.0) if is_firefly else randf_range(38.0, 94.0) * amp_mult,
		"phase": randf() * TAU,
	}
	_bugs.append(bug_dict)


func _handle_swat_tap(tap_pos: Vector2) -> void:
	if not _active:
		return
	var best_mosq: Dictionary = {}
	var best_mosq_dist := MOSQUITO_HIT_RADIUS
	var best_ff: Dictionary = {}
	var best_ff_dist := FIREFLY_HIT_RADIUS

	for b in _bugs:
		if bool(b["dead"]):
			continue
		var d := tap_pos.distance_to(b["pos"] as Vector2)
		if bool(b["is_firefly"]):
			if d <= best_ff_dist:
				best_ff_dist = d
				best_ff = b
		else:
			if d <= best_mosq_dist:
				best_mosq_dist = d
				best_mosq = b

	# Prioritize mosquitoes over fireflies when both are near the tap
	if not best_mosq.is_empty():
		_play_swat_sfx(randf_range(0.95, 1.12), 0.5)
		_on_bug_swatted(best_mosq)
	elif not best_ff.is_empty():
		_play_swat_sfx(randf_range(0.82, 0.92), -1.0)
		_on_bug_swatted(best_ff)
	else:
		_play_swat_sfx(randf_range(1.06, 1.22), -5.0)
		_ripples.append({"pos": tap_pos, "t": 0.0, "color": Color(0.86, 0.84, 0.78, 0.38)})


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
		_streak = 0
		_streak_timer = 0.0
		_ripples.append({"pos": pos, "t": 0.0, "color": Color(0.98, 0.35, 0.32, 0.9)})
		_spawn_floating_text(pos, "-1 Firefly!", Juice.COL_DANGER)
		Juice.play_sfx("error", 0.78, 1.5)
		Juice.shake_control(_root, 13.0, 0.26)
		Juice.spawn_burst(_arena, pos, Color(1.0, 0.42, 0.36), 12, 120.0)
		Juice.pop_control(_lives_box, 1.22, 0.22)
	else:
		tr.texture = _tex_mosq_dead
		_score += 1
		_streak += 1
		_streak_timer = 1.65
		_ripples.append({"pos": pos, "t": 0.0, "color": Color(0.98, 0.84, 0.42, 0.9)})
		var popup_txt := "+1" if _streak <= 1 else ("x%d!" % _streak if _streak < 4 else "COMBO x%d!" % _streak)
		var popup_col := Juice.COL_SUCCESS if _streak <= 1 else (Color(1.0, 0.90, 0.42) if _streak < 4 else Color(1.0, 0.68, 0.28))
		_spawn_floating_text(pos, popup_txt, popup_col)
		# Tactile plastic slap + escalating pitch chime!
		Juice.play_sfx("plastic", minf(1.65, 1.0 + float(_streak) * 0.06), -2.5)
		Juice.play_sfx("pickup", minf(1.60, 0.94 + float(_score) * 0.045), 0.5)
		Juice.shake_control(_root, minf(8.0, 3.8 + float(_streak) * 0.8), 0.14)
		Juice.spawn_burst(_arena, pos, popup_col, mini(14, 7 + _streak * 2), 110.0)
		Juice.pop_control(_score_lbl, 1.24, 0.18)

	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := tr.create_tween()
	tw.tween_property(tr, "scale", Vector2(1.22, 0.80), 0.07)
	tw.tween_property(tr, "position:y", tr.position.y + 42.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(tr, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		bug["node"] = null
		if is_instance_valid(tr):
			tr.queue_free()
	)

	_refresh_hud()
	if _lives <= 0:
		_finish_round(false, "Fireflies Lost!", "Oh no — too many fireflies got swatted!")
	elif _score >= _target_score:
		_finish_round(true, "Counter Clear!", "Swatted %d mosquitoes with %d fireflies safe!" % [_score, _lives])


func _spawn_floating_text(pos: Vector2, txt: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.position = pos - Vector2(40, 18)
	Juice.style_hud_label(lbl, UIStyle.FONT_FREDOKA_BOLD, 21, col, 4)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 38.0, 0.50).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.50)
	tw.tween_callback(lbl.queue_free)


func _finish_round(won: bool, title: String, subtitle: String) -> void:
	_active = false
	_result_title.text = title
	_result_title.add_theme_color_override("font_color", Juice.COL_SUCCESS if won else Juice.COL_DANGER)
	_result_sub.text = subtitle
	_result_panel.set_meta("won", won)

	for ch in _result_stats_row.get_children():
		_result_stats_row.remove_child(ch)
		ch.queue_free()
	_result_stats_row.add_child(Juice.make_stat_chip("Swatted", "%d / %d" % [_score, _target_score], Juice.COL_SUCCESS if won else Juice.COL_CREAM))
	_result_stats_row.add_child(Juice.make_stat_chip("Fireflies Safe", "%d / %d" % [_lives, MAX_LIVES], Juice.COL_GOLD_BRIGHT if _lives > 0 else Juice.COL_DANGER))
	_result_stats_row.add_child(Juice.make_stat_chip("Time Left", "%.1fs" % _time_left, Juice.COL_CREAM))

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


func _refresh_hud() -> void:
	_score_bar.max_value = _target_score
	_score_bar.value = _score
	_score_lbl.text = "%d / %d" % [_score, _target_score]
	_refresh_timer_label()
	_refresh_streak_pill()

	for ch in _lives_box.get_children():
		_lives_box.remove_child(ch)
		ch.queue_free()
	for i in range(MAX_LIVES):
		var icon := TextureRect.new()
		icon.texture = _tex_firefly if i < _lives else _tex_firefly_dead
		icon.custom_minimum_size = Vector2(44, 44)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color(1.0, 0.98, 0.82, 1.0) if i < _lives else Color(0.55, 0.45, 0.45, 0.38)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lives_box.add_child(icon)


func _refresh_streak_pill() -> void:
	if not is_instance_valid(_streak_pill):
		return
	if _streak >= 2:
		_streak_pill.visible = true
		_streak_lbl.text = "x%d Streak" % _streak
		var col := Color(1.0, 0.72, 0.30) if _streak >= 4 else Juice.COL_GOLD_BRIGHT
		_streak_lbl.add_theme_color_override("font_color", col)
		Juice.pop_control(_streak_pill, 1.15, 0.16)
	else:
		_streak_pill.visible = false


func _refresh_timer_label() -> void:
	var low := _time_left <= 6.0
	_timer_lbl.text = "%.1fs" % _time_left
	var col := Juice.COL_DANGER if low else Juice.COL_GOLD_BRIGHT
	_timer_lbl.add_theme_color_override("font_color", col)
	if is_instance_valid(_timer_icon):
		_timer_icon.modulate = col


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
	add_child(_root)

	# Fullscreen bug arena (generous tap hitbox handles both bug swats & air misses)
	_arena = Control.new()
	_arena.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arena.clip_contents = true
	_arena.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_arena.gui_input.connect(func(ev: InputEvent):
		if _active and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_handle_swat_tap((ev as InputEventMouseButton).position)
	)
	_root.add_child(_arena)

	_arena_fx = Control.new()
	_arena_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arena_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena_fx.draw.connect(_draw_arena_fx)
	_arena.add_child(_arena_fx)

	# --- TOP SAFE-ZONE HEADER + CONTRASTING HUD BAR ---
	var header := VBoxContainer.new()
	header.anchor_left = 0.5
	header.anchor_right = 0.5
	header.anchor_top = 0.0
	header.offset_left = -340
	header.offset_right = 340
	header.offset_top = 24
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(header)

	var title := Label.new()
	title.text = "Dusk Lamp Swat"
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

	# Score progress bar + numeric readout
	var score_wrap := HBoxContainer.new()
	score_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	score_wrap.add_theme_constant_override("separation", 10)
	score_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_row.add_child(score_wrap)

	_score_bar = ProgressBar.new()
	_score_bar.custom_minimum_size = Vector2(168, 14)
	_score_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_score_bar.show_percentage = false
	_score_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb_bg := UIStyle.create_flat_stylebox(Color(0.06, 0.05, 0.04, 0.92), 7, 0, 0)
	sb_bg.border_color = Color(0.88, 0.70, 0.34, 0.28)
	sb_bg.set_border_width_all(1)
	var sb_fill := UIStyle.create_flat_stylebox(Juice.COL_SUCCESS, 7, 0, 0)
	_score_bar.add_theme_stylebox_override("background", sb_bg)
	_score_bar.add_theme_stylebox_override("fill", sb_fill)
	score_wrap.add_child(_score_bar)

	_score_lbl = Label.new()
	_score_lbl.custom_minimum_size = Vector2(58, 0)
	_score_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	_score_lbl.add_theme_font_size_override("font_size", 18)
	_score_lbl.add_theme_color_override("font_color", Juice.COL_CREAM)
	_score_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_wrap.add_child(_score_lbl)

	hud_row.add_child(Juice.make_vsep(24.0))

	# Firefly Lives
	_lives_box = HBoxContainer.new()
	_lives_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_lives_box.add_theme_constant_override("separation", 2)
	_lives_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_row.add_child(_lives_box)

	hud_row.add_child(Juice.make_vsep(24.0))

	# Timer with Lucide clock icon
	var timer_wrap := HBoxContainer.new()
	timer_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	timer_wrap.add_theme_constant_override("separation", 6)
	timer_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_row.add_child(timer_wrap)

	_timer_icon = Juice.make_icon_rect(Juice.ICON_CLOCK, Vector2(18, 18), Juice.COL_GOLD_BRIGHT)
	timer_wrap.add_child(_timer_icon)

	_timer_lbl = Label.new()
	_timer_lbl.custom_minimum_size = Vector2(58, 0)
	_timer_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	_timer_lbl.add_theme_font_size_override("font_size", 20)
	_timer_lbl.add_theme_color_override("font_color", Juice.COL_GOLD_BRIGHT)
	_timer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_wrap.add_child(_timer_lbl)

	# Contextual Streak Pill (appears only when streak >= 2)
	_streak_pill = PanelContainer.new()
	_streak_pill.visible = false
	_streak_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_streak_pill.add_theme_stylebox_override("panel", Juice.make_pill_style(Color(0.22, 0.14, 0.06, 0.94), Juice.COL_GOLD, 12, 12, 6, 2))
	hud_center.add_child(_streak_pill)

	_streak_lbl = Label.new()
	_streak_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	_streak_lbl.add_theme_font_size_override("font_size", 16)
	_streak_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_streak_pill.add_child(_streak_lbl)

	# Bottom safe-zone hint pill
	var hint_wrap := HBoxContainer.new()
	hint_wrap.anchor_left = 0.5
	hint_wrap.anchor_right = 0.5
	hint_wrap.anchor_top = 1.0
	hint_wrap.anchor_bottom = 1.0
	hint_wrap.offset_left = -280
	hint_wrap.offset_right = 280
	hint_wrap.offset_top = -54
	hint_wrap.offset_bottom = -20
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

	hint_row.add_child(Juice.make_keycap_pill("Click"))
	var hint := Label.new()
	hint.text = "Swat mosquitoes — spare the glowing fireflies"
	hint.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Juice.COL_CREAM)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_row.add_child(hint)

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

	# --- INTRO MODAL (Responsive CenterContainer + Visual Target Preview) ---
	var intro_shell := Juice.make_modal_shell(_root, Vector2(560, 0))
	_intro_overlay = intro_shell["overlay"]
	_intro_panel = intro_shell["panel"]
	var iv: VBoxContainer = intro_shell["vbox"]

	var ititle := Label.new()
	ititle.text = "Dusk Lamp Swat"
	ititle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ititle.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	ititle.add_theme_font_size_override("font_size", 32)
	ititle.add_theme_color_override("font_color", Juice.COL_GOLD_BRIGHT)
	iv.add_child(ititle)

	# Visual glance row: Swat Mosquito vs Spare Firefly
	var preview_row := HBoxContainer.new()
	preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_row.add_theme_constant_override("separation", 16)
	iv.add_child(preview_row)

	preview_row.add_child(_make_bug_badge(_tex_mosq, "SWAT", Juice.COL_SUCCESS))
	preview_row.add_child(_make_bug_badge(_tex_firefly, "SPARE", Juice.COL_DANGER))

	var idesc := Label.new()
	idesc.text = "Click mosquitoes before time runs out. Sparing the glowing fireflies keeps your %d lives safe!" % MAX_LIVES
	idesc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	idesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	idesc.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	idesc.add_theme_font_size_override("font_size", 18)
	idesc.add_theme_color_override("font_color", Juice.COL_CREAM)
	iv.add_child(idesc)

	var start_btn := Button.new()
	start_btn.text = "Start Swatting"
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


func _make_bug_badge(tex: Texture2D, badge_text: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Juice.make_pill_style(Color(0.15, 0.11, 0.08, 0.94), Color(col.r, col.g, col.b, 0.65), 12, 16, 10, 2))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)

	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = Vector2(52, 52)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(tr)

	var lbl := Label.new()
	lbl.text = badge_text
	lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", col)
	h.add_child(lbl)
	return p


func _draw_arena_fx() -> void:
	for rip in _ripples:
		var t: float = float(rip["t"])
		var col: Color = rip["color"]
		col.a *= (1.0 - t)
		_arena_fx.draw_arc(rip["pos"], 12.0 + t * 40.0, 0.0, TAU, 26, col, 2.8, true)
