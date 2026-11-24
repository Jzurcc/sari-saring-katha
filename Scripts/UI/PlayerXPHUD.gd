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
var _fill_panel: Panel
var _fill_style: StyleBoxFlat
var _stripe_mat: ShaderMaterial
var _lvl_lbl: Label
var _xp_lbl: Label
var _gain_lbl: Label
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
var _gain_tween: Tween = null
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

	# Outer dark pill bezel
	_frame_panel = Panel.new()
	_frame_panel.size = Vector2(_frame_w, _frame_h)
	_frame_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_style = StyleBoxFlat.new()
	_frame_style.bg_color = COL_TRACK_BG
	_frame_style.border_color = COL_BORDER
	_frame_style.set_border_width_all(2)
	_frame_style.set_corner_radius_all(999)
	_frame_style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	_frame_style.shadow_size = 14
	_frame_style.shadow_offset = Vector2(0, 5)
	_frame_panel.add_theme_stylebox_override("panel", _frame_style)
	_holder.add_child(_frame_panel)

	# Inner clipped track
	var fill_clip := Control.new()
	fill_clip.position = Vector2(FRAME_PAD, FRAME_PAD)
	fill_clip.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	fill_clip.clip_contents = true
	fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(fill_clip)

	# Clipped rounded pill fill with thicker moving sloped stripes
	_fill_panel = Panel.new()
	_fill_panel.position = Vector2.ZERO
	_fill_panel.size = Vector2(0.0, BAR_HEIGHT)
	_fill_panel.clip_contents = true
	_fill_panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_fill_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_style = StyleBoxFlat.new()
	_fill_style.bg_color = COL_FILL_BASE
	_fill_style.set_corner_radius_all(999)
	_fill_panel.add_theme_stylebox_override("panel", _fill_style)
	fill_clip.add_child(_fill_panel)

	var stripe_rect := ColorRect.new()
	stripe_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	stripe_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe_rect.color = Color.WHITE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float scroll_offset = 0.0;
uniform float stripe_density = 26.0;
uniform float stripe_alpha = 0.24;
void fragment() {
	float diag = (FRAGCOORD.x + FRAGCOORD.y) / stripe_density - scroll_offset;
	float band = smoothstep(0.38, 0.46, fract(diag)) * (1.0 - smoothstep(0.86, 0.94, fract(diag)));
	COLOR = vec4(1.0, 0.98, 0.90, band * stripe_alpha);
}
"""
	_stripe_mat = ShaderMaterial.new()
	_stripe_mat.shader = sh
	stripe_rect.material = _stripe_mat
	_fill_panel.add_child(stripe_rect)

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

	# Floating "+XP" micro-pop above the right side of the pill
	_gain_lbl = Label.new()
	_gain_lbl.position = Vector2(_frame_w - 92.0, -24.0)
	_gain_lbl.custom_minimum_size = Vector2(92.0, 0.0)
	_gain_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gain_lbl.text = ""
	_gain_lbl.modulate.a = 0.0
	_gain_lbl.add_theme_font_override("font", _bold_font)
	_gain_lbl.add_theme_font_size_override("font_size", 17)
	_gain_lbl.add_theme_color_override("font_color", Color(0.66, 0.96, 0.56, 1.0))
	_gain_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_gain_lbl.add_theme_constant_override("outline_size", 4)
	_gain_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_gain_lbl)

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
	_fill_panel.size = Vector2(fill_w, BAR_HEIGHT)
	_fill_panel.visible = fill_w > 2.0

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

func _on_player_xp_changed(level: int, current_xp: int, xp_to_next: int, gained_xp: int, leveled_up: bool) -> void:
	var target_ratio := 1.0 if xp_to_next <= 0 else clampf(float(current_xp) / float(xp_to_next), 0.0, 1.0)

	# Silent sync on save load / new game reset — keep bar hidden!
	if gained_xp <= 0:
		if _anim_tween and _anim_tween.is_valid():
			_anim_tween.kill()
		_stripe_speed = IDLE_STRIPE_SPEED
		_stripe_alpha = IDLE_STRIPE_ALPHA
		_fill_style.bg_color = COL_FILL_BASE
		_frame_style.border_color = COL_BORDER
		_lvl_lbl.text = "Lv. %d" % level
		_xp_lbl.text = "MAX" if xp_to_next <= 0 else "%d / %d" % [current_xp, xp_to_next]
		_set_fill_ratio(target_ratio)
		return

	_hide_session_id += 1
	var my_session := _hide_session_id
	_animate_show()

	# Floating "+XP" pop above the bar
	_gain_lbl.text = "+%d XP" % gained_xp
	if _gain_tween and _gain_tween.is_valid():
		_gain_tween.kill()
	_gain_lbl.modulate.a = 0.0
	_gain_lbl.position.y = -14.0
	_gain_tween = create_tween()
	_gain_tween.tween_property(_gain_lbl, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE)
	_gain_tween.parallel().tween_property(_gain_lbl, "position:y", -28.0, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_gain_tween.tween_interval(1.1)
	_gain_tween.tween_property(_gain_lbl, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	_gain_tween.parallel().tween_property(_gain_lbl, "position:y", -36.0, 0.35).set_trans(Tween.TRANS_SINE)

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_holder.pivot_offset = Vector2(_frame_w * 0.5, _frame_h * 0.5)
	_anim_tween = create_tween()

	# Surge stripe speed, opacity & glow
	_anim_tween.tween_property(self, "_stripe_speed", SURGE_STRIPE_SPEED, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tween.parallel().tween_property(self, "_stripe_alpha", SURGE_STRIPE_ALPHA, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tween.parallel().tween_property(_fill_style, "bg_color", COL_FILL_SURGE, 0.14)
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
	_anim_tween.parallel().tween_property(_fill_style, "bg_color", COL_FILL_BASE, 0.48).set_trans(Tween.TRANS_SINE)
	_anim_tween.parallel().tween_property(_frame_style, "border_color", COL_BORDER, 0.48).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_callback(_schedule_hide.bind(my_session))
