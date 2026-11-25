class_name PlayerXPHUD
extends CanvasLayer

## Bottom-center auto-hiding Player Level & XP pill bar with thick sloped diagonal stripes.
## Only appears when XP changes: slides up with subtle overshoot, surges stripe speed & opacity
## while filling (with level-up wrap & pop), then after 3 seconds of idle plays a subtle
## anticipation lift before dropping cleanly off the bottom edge.

const BAR_WIDTH := 440.0
const BAR_HEIGHT := 26.0
const FRAME_PAD := 4.0
const REST_BOTTOM_MARGIN := 26.0
const IDLE_HIDE_DELAY := 1.5

const IDLE_STRIPE_SPEED := 0.58
const IDLE_STRIPE_ALPHA := 0.24
const SURGE_STRIPE_SPEED := 3.20
const SURGE_STRIPE_ALPHA := 0.58

const COL_TRACK_BG := Color(0.06, 0.052, 0.046, 0.90)
const COL_BORDER := Color(0.86, 0.66, 0.30, 0.85)
const COL_FILL_BASE := Color(0.84, 0.61, 0.22, 0.96)
const COL_FILL_SURGE := Color(1.0, 0.86, 0.44, 1.0)
const COL_TEXT := Color(1.0, 0.955, 0.86, 1.0)
const COL_TEXT_SUB := Color(1.0, 0.92, 0.76, 0.95)
const COL_OUTLINE := Color(0.06, 0.045, 0.03, 0.95)

var _holder: Control
var _frame_panel: Panel
var _frame_style: StyleBoxFlat
var _fill_rect: ColorRect
var _stripe_mat: ShaderMaterial
const GAIN_BASE_Y := -28.0
const GAIN_ROW_STEP := 22.0
const MAX_GAIN_POPUPS := 5

var _lvl_lbl: Label
var _xp_lbl: Label
var _active_gain_popups: Array[Label] = []
var _bold_font: FontVariation

var _frame_w: float = 0.0
var _frame_h: float = 0.0
var _rest_offset_top: float = 0.0
var _rest_offset_bottom: float = 0.0
var _hidden_offset_top: float = 0.0
var _hidden_offset_bottom: float = 0.0

var _is_shown: bool = false
var _display_ratio: float = 0.0
var _stripe_scroll: float = 0.0
var _stripe_speed: float = IDLE_STRIPE_SPEED
var _stripe_alpha: float = IDLE_STRIPE_ALPHA
var _anim_tween: Tween = null
var _vis_tween: Tween = null
var _hide_session_id: int = 0

func _ready() -> void:
	layer = 40
	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_INDER
	_bold_font.variation_embolden = 0.60
	_build_ui()
	EventBus.player_xp_changed.connect(_on_player_xp_changed)
	_sync_immediate()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_frame_w = BAR_WIDTH + FRAME_PAD * 2.0
	_frame_h = BAR_HEIGHT + FRAME_PAD * 2.0
	_rest_offset_bottom = -REST_BOTTOM_MARGIN
	_rest_offset_top = _rest_offset_bottom - _frame_h
	_hidden_offset_top = 18.0
	_hidden_offset_bottom = _hidden_offset_top + _frame_h

	_holder = Control.new()
	_holder.anchor_left = 0.5
	_holder.anchor_right = 0.5
	_holder.anchor_top = 1.0
	_holder.anchor_bottom = 1.0
	_holder.offset_left = -_frame_w * 0.5
	_holder.offset_right = _frame_w * 0.5
	_holder.offset_top = _hidden_offset_top
	_holder.offset_bottom = _hidden_offset_bottom
	_holder.modulate.a = 0.0
	_holder.visible = false
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_holder)

	# Outer dark pill bezel (exact concentric radius = _frame_h * 0.5)
	var outer_r := int(ceilf(_frame_h * 0.5))
	var inner_r := int(ceilf(BAR_HEIGHT * 0.5))
	_frame_panel = Panel.new()
	_frame_panel.size = Vector2(_frame_w, _frame_h)
	_frame_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_style = StyleBoxFlat.new()
	_frame_style.bg_color = COL_TRACK_BG
	_frame_style.border_color = COL_BORDER
	_frame_style.set_border_width_all(2)
	_frame_style.set_corner_radius_all(outer_r)
	_frame_style.corner_detail = 16
	_frame_style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	_frame_style.shadow_size = 14
	_frame_style.shadow_offset = Vector2(0, 5)
	_frame_panel.add_theme_stylebox_override("panel", _frame_style)
	_holder.add_child(_frame_panel)

	# Concentric rounded-pill mask so the fill ALWAYS matches the outer bar's curve even at low XP
	var fill_clip := Panel.new()
	fill_clip.position = Vector2(FRAME_PAD, FRAME_PAD)
	fill_clip.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	fill_clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var clip_style := StyleBoxFlat.new()
	clip_style.bg_color = Color.WHITE
	clip_style.set_corner_radius_all(inner_r)
	clip_style.corner_detail = 16
	fill_clip.add_theme_stylebox_override("panel", clip_style)
	_holder.add_child(fill_clip)

	# Single-pass fill + moving sloped stripes shader (no nested clip_children — Godot 4 doesn't support nested clip_children!)
	# Outer concentric rounding is masked by fill_clip; right-edge pill rounding + stripes are masked in the shader SDF.
	_fill_rect = ColorRect.new()
	_fill_rect.position = Vector2.ZERO
	_fill_rect.size = Vector2(0.0, BAR_HEIGHT)
	_fill_rect.color = Color.WHITE
	_fill_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec4 fill_color : source_color = vec4(0.84, 0.62, 0.25, 1.0);
uniform vec2 rect_size = vec2(100.0, 22.0);
uniform float right_radius = 11.0;
uniform float scroll_offset = 0.0;
uniform float stripe_density = 26.0;
uniform float stripe_alpha = 0.24;

void fragment() {
	vec2 p = UV * rect_size;
	// Signed distance to a rect with flat left edge (clipped by fill_clip) and rounded right cap
	float r = min(right_radius, min(rect_size.x, rect_size.y * 0.5));
	float mask = 1.0;
	if (p.x > rect_size.x - r) {
		float cy = clamp(p.y, r, rect_size.y - r);
		float d = length(p - vec2(rect_size.x - r, cy)) - r;
		mask = 1.0 - smoothstep(-0.75, 0.75, d);
	}
	float diag = (FRAGCOORD.x + FRAGCOORD.y) / stripe_density - scroll_offset;
	float band = smoothstep(0.38, 0.46, fract(diag)) * (1.0 - smoothstep(0.86, 0.94, fract(diag)));
	vec3 col = mix(fill_color.rgb, vec3(1.0, 0.98, 0.90), band * stripe_alpha);
	COLOR = vec4(col, fill_color.a * mask);
}
"""
	_stripe_mat = ShaderMaterial.new()
	_stripe_mat.shader = sh
	_stripe_mat.set_shader_parameter("fill_color", COL_FILL_BASE)
	_stripe_mat.set_shader_parameter("rect_size", Vector2(0.0, BAR_HEIGHT))
	_stripe_mat.set_shader_parameter("right_radius", float(inner_r))
	_fill_rect.material = _stripe_mat
	fill_clip.add_child(_fill_rect)

	# Top gloss sheen inside the pill
	var gloss := Panel.new()
	gloss.position = Vector2(FRAME_PAD + 10.0, FRAME_PAD + 2.5)
	gloss.size = Vector2(BAR_WIDTH - 20.0, 5.0)
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gloss_s := StyleBoxFlat.new()
	gloss_s.bg_color = Color(1.0, 0.98, 0.92, 0.16)
	gloss_s.set_corner_radius_all(999)
	gloss.add_theme_stylebox_override("panel", gloss_s)
	_holder.add_child(gloss)

	# Overlay text INSIDE the bar: Left = "Lv. X", Right = "cur / next"
	var text_margin := MarginContainer.new()
	text_margin.position = Vector2(FRAME_PAD, FRAME_PAD)
	text_margin.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	text_margin.add_theme_constant_override("margin_left", 14)
	text_margin.add_theme_constant_override("margin_right", 14)
	text_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(text_margin)

	var text_row := HBoxContainer.new()
	text_row.alignment = BoxContainer.ALIGNMENT_CENTER
	text_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_margin.add_child(text_row)

	_lvl_lbl = Label.new()
	_lvl_lbl.text = "Lv. 1"
	_lvl_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lvl_lbl.add_theme_font_override("font", _bold_font)
	_lvl_lbl.add_theme_font_size_override("font_size", 16)
	_lvl_lbl.add_theme_color_override("font_color", COL_TEXT)
	_lvl_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_lvl_lbl.add_theme_constant_override("outline_size", 4)
	_lvl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_row.add_child(_lvl_lbl)

	_xp_lbl = Label.new()
	_xp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_xp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_xp_lbl.text = "0 / 100"
	_xp_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_xp_lbl.add_theme_font_size_override("font_size", 14)
	_xp_lbl.add_theme_color_override("font_color", COL_TEXT_SUB)
	_xp_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_xp_lbl.add_theme_constant_override("outline_size", 4)
	_xp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_row.add_child(_xp_lbl)

func _process(delta: float) -> void:
	if not _holder.visible:
		return
	_stripe_scroll += delta * _stripe_speed
	if _stripe_mat:
		_stripe_mat.set_shader_parameter("scroll_offset", _stripe_scroll)
		_stripe_mat.set_shader_parameter("stripe_alpha", _stripe_alpha)

func _set_fill_ratio(ratio: float) -> void:
	_display_ratio = clampf(ratio, 0.0, 1.0)
	var fill_w := BAR_WIDTH * _display_ratio
	_fill_rect.size = Vector2(fill_w, BAR_HEIGHT)
	_fill_rect.visible = fill_w > 2.0
	if _stripe_mat:
		_stripe_mat.set_shader_parameter("rect_size", Vector2(maxf(1.0, fill_w), BAR_HEIGHT))

func _set_fill_color(col: Color) -> void:
	if _stripe_mat:
		_stripe_mat.set_shader_parameter("fill_color", col)

func _sync_immediate() -> void:
	var lvl := StoryManager.player_level
	var cur := StoryManager.player_xp
	var need := StoryManager.get_xp_for_next_level(lvl)
	_lvl_lbl.text = "Lv. %d" % lvl
	if need <= 0:
		_xp_lbl.text = "MAX"
		_set_fill_ratio(1.0)
	else:
		_xp_lbl.text = "%d / %d" % [cur, need]
		_set_fill_ratio(float(cur) / float(need))

func _animate_show() -> void:
	if _vis_tween and _vis_tween.is_valid():
		_vis_tween.kill()
	_holder.visible = true
	if not _is_shown:
		_holder.offset_top = _hidden_offset_top
		_holder.offset_bottom = _hidden_offset_bottom
		_holder.modulate.a = 0.0
	_is_shown = true

	# Subtle overshoot sliding up into resting bottom-center position
	_vis_tween = create_tween().set_parallel(true)
	_vis_tween.tween_property(_holder, "offset_top", _rest_offset_top, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_vis_tween.tween_property(_holder, "offset_bottom", _rest_offset_bottom, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_vis_tween.tween_property(_holder, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_SINE)

func _schedule_hide(my_session: int) -> void:
	await get_tree().create_timer(IDLE_HIDE_DELAY).timeout
	if not is_inside_tree() or my_session != _hide_session_id or not _is_shown:
		return

	if _vis_tween and _vis_tween.is_valid():
		_vis_tween.kill()

	# Subtle anticipation lift (+10px up), then slower, silky-smooth drop off the bottom edge
	_vis_tween = create_tween()
	_vis_tween.tween_property(_holder, "offset_top", _rest_offset_top - 10.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_vis_tween.parallel().tween_property(_holder, "offset_bottom", _rest_offset_bottom - 10.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_vis_tween.tween_property(_holder, "offset_top", _hidden_offset_top, 0.56).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_vis_tween.parallel().tween_property(_holder, "offset_bottom", _hidden_offset_bottom, 0.56).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_vis_tween.parallel().tween_property(_holder, "modulate:a", 0.0, 0.46).set_delay(0.08).set_trans(Tween.TRANS_SINE)
	_vis_tween.tween_callback(func():
		if my_session == _hide_session_id:
			_is_shown = false
			_holder.visible = false
	)

func _spawn_gain_popup(gained_xp: int) -> void:
	# Clean out any freed references
	_active_gain_popups = _active_gain_popups.filter(func(l: Label) -> bool: return is_instance_valid(l))

	# Cap simultaneous popups by gracefully retiring the oldest if full
	while _active_gain_popups.size() >= MAX_GAIN_POPUPS:
		var oldest: Label = _active_gain_popups.pop_front()
		if is_instance_valid(oldest):
			_fade_and_free_popup(oldest)
		_reflow_gain_popups()

	var lbl := Label.new()
	var slot_idx := _active_gain_popups.size()
	var target_y := GAIN_BASE_Y - float(slot_idx) * GAIN_ROW_STEP
	lbl.position = Vector2(_frame_w - 96.0, target_y + 10.0)
	lbl.custom_minimum_size = Vector2(96.0, 0.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.text = "+%d XP" % gained_xp
	lbl.modulate.a = 0.0
	lbl.add_theme_font_override("font", _bold_font)
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color(0.66, 0.96, 0.56, 1.0))
	lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(lbl)
	_active_gain_popups.append(lbl)

	# Pop-in entrance to its stacked slot
	var pos_tw := lbl.create_tween()
	lbl.set_meta("pos_tween", pos_tw)
	pos_tw.tween_property(lbl, "position:y", target_y, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Timely fade-out lifecycle; when this popup retires, remaining popups slide down into its space
	var life_tw := lbl.create_tween()
	lbl.set_meta("life_tween", life_tw)
	life_tw.tween_property(lbl, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE)
	life_tw.tween_interval(1.25)
	life_tw.tween_callback(func():
		if not is_instance_valid(lbl):
			return
		var idx := _active_gain_popups.find(lbl)
		if idx != -1:
			_active_gain_popups.remove_at(idx)
			_reflow_gain_popups()
		_fade_and_free_popup(lbl)
	)


func _fade_and_free_popup(lbl: Label) -> void:
	if not is_instance_valid(lbl) or lbl.get_meta("fading", false):
		return
	lbl.set_meta("fading", true)
	var old_pos = lbl.get_meta("pos_tween", null)
	if old_pos is Tween and old_pos.is_valid():
		old_pos.kill()
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 0.0, 0.30).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(lbl, "position:y", lbl.position.y + 6.0, 0.30).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(lbl.queue_free)


func _reflow_gain_popups() -> void:
	_active_gain_popups = _active_gain_popups.filter(func(l: Label) -> bool: return is_instance_valid(l))
	for i in range(_active_gain_popups.size()):
		var lbl: Label = _active_gain_popups[i]
		var target_y := GAIN_BASE_Y - float(i) * GAIN_ROW_STEP
		var old_pos = lbl.get_meta("pos_tween", null)
		if old_pos is Tween and old_pos.is_valid():
			old_pos.kill()
		var tw := lbl.create_tween()
		lbl.set_meta("pos_tween", tw)
		tw.tween_property(lbl, "position:y", target_y, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_player_xp_changed(level: int, current_xp: int, xp_to_next: int, gained_xp: int, leveled_up: bool) -> void:
	var target_ratio := 1.0 if xp_to_next <= 0 else clampf(float(current_xp) / float(xp_to_next), 0.0, 1.0)

	# Silent sync on save load / new game reset — keep bar hidden!
	if gained_xp <= 0:
		if _anim_tween and _anim_tween.is_valid():
			_anim_tween.kill()
		_stripe_speed = IDLE_STRIPE_SPEED
		_stripe_alpha = IDLE_STRIPE_ALPHA
		_set_fill_color(COL_FILL_BASE)
		_frame_style.border_color = COL_BORDER
		_lvl_lbl.text = "Lv. %d" % level
		_xp_lbl.text = "MAX" if xp_to_next <= 0 else "%d / %d" % [current_xp, xp_to_next]
		_set_fill_ratio(target_ratio)
		return

	_hide_session_id += 1
	var my_session := _hide_session_id
	_animate_show()

	# Stacked "+XP" popups above the right side of the pill
	_spawn_gain_popup(gained_xp)

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_holder.pivot_offset = Vector2(_frame_w * 0.5, _frame_h * 0.5)
	_anim_tween = create_tween()

	# Surge stripe speed, opacity & glow
	_anim_tween.tween_property(self, "_stripe_speed", SURGE_STRIPE_SPEED, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tween.parallel().tween_property(self, "_stripe_alpha", SURGE_STRIPE_ALPHA, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tween.parallel().tween_method(_set_fill_color, COL_FILL_BASE, COL_FILL_SURGE, 0.14)
	_anim_tween.parallel().tween_property(_frame_style, "border_color", Color(1.0, 0.92, 0.64, 1.0), 0.14)

	if leveled_up:
		_anim_tween.tween_method(_set_fill_ratio, _display_ratio, 1.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_anim_tween.tween_callback(func():
			_lvl_lbl.text = "Lv. %d" % level
			_xp_lbl.text = "MAX" if xp_to_next <= 0 else "%d / %d" % [current_xp, xp_to_next]
		)
		_anim_tween.tween_property(_holder, "scale", Vector2(1.08, 1.08), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_anim_tween.tween_property(_holder, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_SINE)
		if xp_to_next > 0:
			_anim_tween.tween_callback(func(): _set_fill_ratio(0.0))
			_anim_tween.tween_method(_set_fill_ratio, 0.0, target_ratio, 0.44).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_lvl_lbl.text = "Lv. %d" % level
		_xp_lbl.text = "MAX" if xp_to_next <= 0 else "%d / %d" % [current_xp, xp_to_next]
		_anim_tween.tween_method(_set_fill_ratio, _display_ratio, target_ratio, 0.56).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Return stripes & glow back to calm idle, then start the 3s auto-hide countdown
	_anim_tween.tween_property(self, "_stripe_speed", IDLE_STRIPE_SPEED, 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_anim_tween.parallel().tween_property(self, "_stripe_alpha", IDLE_STRIPE_ALPHA, 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_anim_tween.parallel().tween_method(_set_fill_color, COL_FILL_SURGE, COL_FILL_BASE, 0.48).set_trans(Tween.TRANS_SINE)
	_anim_tween.parallel().tween_property(_frame_style, "border_color", COL_BORDER, 0.48).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_callback(_schedule_hide.bind(my_session))
