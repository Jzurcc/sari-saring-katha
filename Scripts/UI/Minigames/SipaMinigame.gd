class_name SipaMinigame
extends CanvasLayer

## Sipa Keepy-Uppy Minigame.
## Starts with a 3-2-1 countdown, then drops the sipa inside a bounded store perimeter.
## Press SPACE (or Click) when the sipa enters the bottom kick zone to bounce it up
## and immediately refresh your kick! Pressing early triggers a brief cooldown lockout.

signal minigame_finished(won: bool, result: Dictionary)

const TEX_SIPA := "res://Assets/ui/minigames/sipa.png"
const FIELD_SIZE := Vector2(560.0, 520.0)
const KICK_ZONE_TOP := 360.0
const KICK_ZONE_BOTTOM := 476.0
const FLOOR_Y := 492.0
const EARLY_COOLDOWN := 0.50
const TARGET_KICKS := 12

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
var _field: Control
var _field_draw: Control
var _sipa_sprite: TextureRect
var _countdown_lbl: Label
var _kick_lbl: Label
var _status_lbl: Label
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
	_sipa_tex = _load_tex(TEX_SIPA)
	_build_ui()
	visible = false


func open_minigame(_config: Dictionary = {}) -> void:
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_open = true
	visible = true
	add_to_group("minigame_overlay_active")
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
	_phase = "countdown"
	_countdown_t = 3.0
	_kicks = 0
	_cooldown = 0.0
	_elapsed = 0.0
	_hit_flash = 0.0
	_miss_flash = 0.0
	_result_panel.visible = false
	_sipa_pos = Vector2(FIELD_SIZE.x * 0.5, 115.0)
	_sipa_vel = Vector2.ZERO
	_sipa_rot = 0.0
	_sipa_ang_vel = 0.0
	_sync_sipa_visual()
	_countdown_lbl.visible = true
	_countdown_lbl.text = "3"
	_status_lbl.text = "GET READY..."
	_kick_lbl.text = "KICKS: 0 / %d" % TARGET_KICKS


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close_minigame(false, true)
			return
		if event.keycode == KEY_SPACE and _phase == "playing":
			get_viewport().set_input_as_handled()
			_attempt_kick()


func _attempt_kick() -> void:
	if _phase != "playing":
		return
	if _cooldown > 0.0:
		return

	var in_zone := _sipa_pos.y >= KICK_ZONE_TOP and _sipa_pos.y <= KICK_ZONE_BOTTOM
	if in_zone:
		# Successful kick! Bounce upward & immediately refresh Space!
		_kicks += 1
		_cooldown = 0.0
		_hit_flash = 1.0
		var speed_scale := 1.0 + float(_kicks) * 0.065
		var bounce_vy := -randf_range(540.0, 620.0) * minf(1.42, speed_scale)
		var drift_range := 95.0 + float(_kicks) * 18.0
		var bounce_vx := randf_range(-drift_range, drift_range)
		# Keep drift lively without hugging walls
		if absf(bounce_vx) < 35.0:
			bounce_vx = (35.0 if randf() < 0.5 else -35.0)
		_sipa_vel = Vector2(bounce_vx, bounce_vy)
		_sipa_ang_vel = randf_range(-8.0, 8.0)

		EventBus.request_sfx.emit("interact")
		_kick_lbl.text = "KICKS: %d / %d" % [_kicks, TARGET_KICKS]
		_status_lbl.text = "SWAK! (%d)" % _kicks
		_spawn_feedback("SWAK!", Color(0.62, 0.96, 0.56))

		if _kicks >= TARGET_KICKS:
			_finish_round(true, "Sipa Champion!", "You kept the sipa airborne for %d kicks!" % _kicks)
	else:
		# Pressed early -> cooldown penalty!
		_cooldown = EARLY_COOLDOWN
		_miss_flash = 1.0
		_status_lbl.text = "TOO EARLY! (COOLDOWN)"
		_spawn_feedback("TOO EARLY!", Color(0.98, 0.45, 0.42))
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
			_status_lbl.text = "PRESS [SPACE] IN THE GOLD ZONE!"
			_sipa_vel = Vector2(randf_range(-55.0, 55.0), 40.0)
			_sipa_ang_vel = 2.5
			EventBus.request_sfx.emit("interact")
	elif _phase == "playing":
		_elapsed += delta
		if _cooldown > 0.0:
			_cooldown = maxf(0.0, _cooldown - delta)
			if _cooldown <= 0.0:
				_status_lbl.text = "READY! PRESS [SPACE]"

		# Gravity scales gently over time & kicks for exciting ramp-up
		var diff_mult := 1.0 + minf(0.85, float(_kicks) * 0.07 + _elapsed * 0.012)
		var gravity := 760.0 * diff_mult
		_sipa_vel.y += gravity * delta
		_sipa_pos += _sipa_vel * delta
		_sipa_rot += _sipa_ang_vel * delta

		# Keep sipa strictly inside the dedicated store perimeter (bounce off left/right/top)
		var margin_x := 46.0
		if _sipa_pos.x < margin_x:
			_sipa_pos.x = margin_x
			_sipa_vel.x = absf(_sipa_vel.x) * 0.92
		elif _sipa_pos.x > FIELD_SIZE.x - margin_x:
			_sipa_pos.x = FIELD_SIZE.x - margin_x
			_sipa_vel.x = -absf(_sipa_vel.x) * 0.92
		if _sipa_pos.y < 42.0:
			_sipa_pos.y = 42.0
			_sipa_vel.y = absf(_sipa_vel.y) * 0.45

		_sync_sipa_visual()

		if _sipa_pos.y >= FLOOR_Y:
			EventBus.request_sfx.emit("error")
			_finish_round(false, "Dropped the Sipa!", "You reached %d / %d kicks. Better timing next round!" % [_kicks, TARGET_KICKS])

	if is_instance_valid(_field_draw):
		_field_draw.queue_redraw()


func _sync_sipa_visual() -> void:
	if is_instance_valid(_sipa_sprite):
		_sipa_sprite.position = _sipa_pos - _sipa_sprite.size * 0.5
		_sipa_sprite.rotation = _sipa_rot


func _spawn_feedback(txt: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.position = Vector2(_sipa_pos.x - 50.0, KICK_ZONE_TOP - 32.0)
	lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 42.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.5)
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
	add_child(_root)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.03, 0.025, 0.02, 0.72)
	_root.add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(610, 640)
	var fs := UIStyle.create_flat_stylebox(Color(0.09, 0.08, 0.068, 0.97), 12, 22, 18)
	fs.border_color = Color(0.86, 0.66, 0.30, 0.92)
	fs.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", fs)
	center.add_child(frame)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	frame.add_child(vbox)

	# Header
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	vbox.add_child(hdr)

	var title := Label.new()
	title.text = "SIPA CHALLENGE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", UIStyle.FONT_INDER)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62))
	hdr.add_child(title)

	_kick_lbl = Label.new()
	_kick_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_kick_lbl.add_theme_font_size_override("font_size", 20)
	_kick_lbl.add_theme_color_override("font_color", Color(0.70, 0.96, 0.62))
	hdr.add_child(_kick_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(func(): close_minigame(false, true))
	hdr.add_child(close_btn)

	# Dedicated Store Perimeter Playfield
	var field_panel := PanelContainer.new()
	field_panel.custom_minimum_size = FIELD_SIZE
	field_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var fp_style := UIStyle.create_flat_stylebox(Color(0.11, 0.095, 0.078, 1.0), 10, 0, 0)
	fp_style.border_color = Color(0.72, 0.56, 0.28, 0.85)
	fp_style.set_border_width_all(2)
	field_panel.add_theme_stylebox_override("panel", fp_style)
	vbox.add_child(field_panel)

	_field = Control.new()
	_field.custom_minimum_size = FIELD_SIZE
	_field.clip_contents = true
	_field.mouse_filter = Control.MOUSE_FILTER_STOP
	_field.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _phase == "playing":
			_attempt_kick()
	)
	field_panel.add_child(_field)

	_field_draw = Control.new()
	_field_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_field_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_draw.draw.connect(_draw_field)
	_field.add_child(_field_draw)

	_sipa_sprite = TextureRect.new()
	_sipa_sprite.texture = _sipa_tex
	_sipa_sprite.custom_minimum_size = Vector2(68, 68)
	_sipa_sprite.size = Vector2(68, 68)
	_sipa_sprite.pivot_offset = Vector2(34, 34)
	_sipa_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sipa_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sipa_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(_sipa_sprite)

	_countdown_lbl = Label.new()
	_countdown_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_countdown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_countdown_lbl.add_theme_font_size_override("font_size", 84)
	_countdown_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.56))
	_countdown_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_countdown_lbl.add_theme_constant_override("outline_size", 8)
	_countdown_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(_countdown_lbl)

	_status_lbl = Label.new()
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_status_lbl.add_theme_font_size_override("font_size", 16)
	_status_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
	vbox.add_child(_status_lbl)

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
	_field.add_child(_result_panel)

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
	var w := FIELD_SIZE.x
	var h := FIELD_SIZE.y
	# Dedicated store perimeter guide lines (left/right safe bounce walls)
	_field_draw.draw_line(Vector2(18, 12), Vector2(18, FLOOR_Y), Color(0.85, 0.68, 0.35, 0.22), 2.0)
	_field_draw.draw_line(Vector2(w - 18, 12), Vector2(w - 18, FLOOR_Y), Color(0.85, 0.68, 0.35, 0.22), 2.0)

	# Bottom kick zone
	var in_zone := _phase == "playing" and _sipa_pos.y >= KICK_ZONE_TOP and _sipa_pos.y <= KICK_ZONE_BOTTOM
	var zone_col := Color(0.92, 0.72, 0.28, 0.20)
	var border_col := Color(0.95, 0.78, 0.36, 0.75)
	if _cooldown > 0.0:
		zone_col = Color(0.85, 0.26, 0.24, 0.22)
		border_col = Color(0.95, 0.38, 0.34, 0.85)
	elif in_zone:
		zone_col = Color(0.46, 0.88, 0.44, 0.28)
		border_col = Color(0.62, 0.98, 0.56, 0.95)
	if _hit_flash > 0.0:
		zone_col = zone_col.lerp(Color(0.62, 1.0, 0.56, 0.50), _hit_flash)

	var zone_rect := Rect2(20.0, KICK_ZONE_TOP, w - 40.0, KICK_ZONE_BOTTOM - KICK_ZONE_TOP)
	_field_draw.draw_rect(zone_rect, zone_col, true)
	_field_draw.draw_rect(zone_rect, border_col, false, 2.5)

	# Cooldown bar inside kick zone when locked out
	if _cooldown > 0.0:
		var frac := clampf(_cooldown / EARLY_COOLDOWN, 0.0, 1.0)
		var cd_rect := Rect2(24.0, KICK_ZONE_BOTTOM - 10.0, (w - 48.0) * frac, 6.0)
		_field_draw.draw_rect(cd_rect, Color(0.98, 0.42, 0.38, 0.92), true)

	# Ground line
	_field_draw.draw_line(Vector2(14, FLOOR_Y), Vector2(w - 14, FLOOR_Y), Color(0.90, 0.36, 0.32, 0.65), 3.0)
	# Subtle floor shadow beneath sipa
	var height_ratio := clampf(1.0 - (FLOOR_Y - _sipa_pos.y) / FLOOR_Y, 0.15, 1.0)
	_field_draw.draw_circle(Vector2(_sipa_pos.x, FLOOR_Y + 4.0), 22.0 * height_ratio, Color(0.0, 0.0, 0.0, 0.32 * height_ratio))
	var _unused := h
