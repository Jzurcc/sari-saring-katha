class_name SipaMinigame
extends CanvasLayer

## Sipa Keepy-Uppy Minigame (Fullscreen Vignette UI).
## Starts with a 3-2-1 countdown, then drops the sipa across the full viewport
## inside a bounded store perimeter. Press SPACE (or Click) when the sipa enters
## the bottom kick zone to bounce it up and immediately refresh your kick!

signal minigame_finished(won: bool, result: Dictionary)

const TEX_SIPA := "res://Assets/ui/minigames/sipa.png"
const SIPA_SIZE := Vector2(82.0, 82.0)
const EARLY_COOLDOWN := 0.50
const TARGET_KICKS := 12

const VIGNETTE_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.03, 0.024, 0.02, 0.78);
void fragment() {
	vec2 d = UV - vec2(0.5);
	float dist = length(d * vec2(1.15, 1.0));
	float vig = smoothstep(0.18, 0.78, dist);
	COLOR = vec4(tint.rgb, mix(0.24, tint.a, vig));
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
	var right := vp.x * 0.84
	var top := 118.0
	var floor_y := vp.y - 46.0
	var zone_bottom := floor_y - 16.0
	var zone_top := zone_bottom - clampf(vp.y * 0.17, 105.0, 145.0)
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
	_kicks = 0
	_cooldown = 0.0
	_elapsed = 0.0
	_sipa_pos = Vector2(vp.x * 0.5, vp.y * 0.28)
	_sipa_vel = Vector2.ZERO
	_sipa_rot = 0.0
	_sync_sipa_visual()
	_countdown_lbl.visible = false
	_result_panel.visible = false
	_intro_panel.visible = true
	_kick_lbl.text = "Kicks: 0 / %d" % TARGET_KICKS
	_status_lbl.text = ""


func _on_intro_start() -> void:
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
			"target": TARGET_KICKS,
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
	_status_lbl.text = "Get ready..."
	_kick_lbl.text = "Kicks: 0 / %d" % TARGET_KICKS


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close_minigame(false, true)
			return
		if _phase == "intro" and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
			get_viewport().set_input_as_handled()
			_on_intro_start()
			return
		if event.keycode == KEY_SPACE and _phase == "playing":
			get_viewport().set_input_as_handled()
			_attempt_kick()


func _attempt_kick() -> void:
	if _phase != "playing" or _cooldown > 0.0:
		return
	var b := _get_bounds()
	var in_zone := _sipa_pos.y >= float(b["zone_top"]) and _sipa_pos.y <= float(b["zone_bottom"])
	if in_zone:
		_kicks += 1
		_cooldown = 0.0
		_hit_flash = 1.0
		var vp_scale := _get_vp_size().y / 720.0
		var speed_scale := 1.0 + float(_kicks) * 0.06
		var bounce_vy := -randf_range(640.0, 740.0) * vp_scale * minf(1.42, speed_scale)
		var drift_range := (140.0 + float(_kicks) * 26.0) * vp_scale
		var bounce_vx := randf_range(-drift_range, drift_range)
		if absf(bounce_vx) < 48.0:
			bounce_vx = (48.0 if randf() < 0.5 else -48.0)
		_sipa_vel = Vector2(bounce_vx, bounce_vy)
		_sipa_ang_vel = randf_range(-8.0, 8.0)

		EventBus.request_sfx.emit("interact")
		_kick_lbl.text = "Kicks: %d / %d" % [_kicks, TARGET_KICKS]
		_status_lbl.text = "Swak! Keep it up!"
		_spawn_feedback("Swak!", Color(0.62, 0.96, 0.56))

		if _kicks >= TARGET_KICKS:
			_finish_round(true, "Sipa Champion!", "You kept the sipa airborne for %d kicks!" % _kicks)
	else:
		_cooldown = EARLY_COOLDOWN
		_miss_flash = 1.0
		_status_lbl.text = "Too early — cooldown!"
		_spawn_feedback("Too early!", Color(0.98, 0.45, 0.42))
		EventBus.request_sfx.emit("error")


func _process(delta: float) -> void:
	if not is_open:
		return

	_hit_flash = maxf(0.0, _hit_flash - delta * 3.5)
	_miss_flash = maxf(0.0, _miss_flash - delta * 3.0)

	if _phase == "countdown":
		var prev_int := ceili(_countdown_t)
		_countdown_t -= delta
		var cur_int := ceili(_countdown_t)
		if cur_int != prev_int and cur_int > 0:
			_countdown_lbl.text = str(cur_int)
			EventBus.request_sfx.emit("interact")
		if _countdown_t <= 0.0:
			_phase = "playing"
			_countdown_lbl.visible = false
			_status_lbl.text = "Press Space or Click when the sipa enters the golden zone"
			_sipa_vel = Vector2(randf_range(-75.0, 75.0), 40.0)
			_sipa_ang_vel = 2.5
			EventBus.request_sfx.emit("interact")
	elif _phase == "playing":
		_elapsed += delta
		if _cooldown > 0.0:
			_cooldown = maxf(0.0, _cooldown - delta)
			if _cooldown <= 0.0:
				_status_lbl.text = "Ready — press Space in the golden zone"

		var b := _get_bounds()
		var vp_scale := _get_vp_size().y / 720.0
		var diff_mult := 1.0 + minf(0.85, float(_kicks) * 0.068 + _elapsed * 0.012)
		var gravity := 820.0 * vp_scale * diff_mult
		_sipa_vel.y += gravity * delta
		_sipa_pos += _sipa_vel * delta
		_sipa_rot += _sipa_ang_vel * delta

		var pad_x := SIPA_SIZE.x * 0.5 + 8.0
		if _sipa_pos.x < float(b["left"]) + pad_x:
			_sipa_pos.x = float(b["left"]) + pad_x
			_sipa_vel.x = absf(_sipa_vel.x) * 0.92
		elif _sipa_pos.x > float(b["right"]) - pad_x:
			_sipa_pos.x = float(b["right"]) - pad_x
			_sipa_vel.x = -absf(_sipa_vel.x) * 0.92
		if _sipa_pos.y < float(b["top"]):
			_sipa_pos.y = float(b["top"])
			_sipa_vel.y = absf(_sipa_vel.y) * 0.45

		_sync_sipa_visual()

		if _sipa_pos.y >= float(b["floor_y"]):
			EventBus.request_sfx.emit("error")
			_finish_round(false, "Dropped the Sipa!", "You reached %d / %d kicks. Better timing next round!" % [_kicks, TARGET_KICKS])

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
	_result_panel.visible = true


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
	idesc.text = "Press Space or Click when the sipa enters the golden zone at the bottom to bounce it back up. Pressing too early triggers a short cooldown. Reach %d kicks to win!" % TARGET_KICKS
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
	var in_zone := _phase == "playing" and _sipa_pos.y >= zone_top and _sipa_pos.y <= zone_bottom
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
