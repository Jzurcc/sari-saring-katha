class_name PlayerXPHUD
extends CanvasLayer

## Sleek, fat rounded pill XP bar under the top-left wallet, matching FridgeColdnessHUD's
## bezel & moving diagonal stripe shader. Displays "Lv. X" on the left and "cur / next"
## on the right directly inside the bar, with juicy stripe-speed & opacity surges on XP gain.

const BAR_WIDTH := 310.0
const BAR_HEIGHT := 26.0
const FRAME_PAD := 4.0

const IDLE_STRIPE_SPEED := 0.26
const IDLE_STRIPE_ALPHA := 0.20
const SURGE_STRIPE_SPEED := 2.85
const SURGE_STRIPE_ALPHA := 0.56

const COL_TRACK_BG := Color(0.06, 0.052, 0.046, 0.88)
const COL_BORDER := Color(0.86, 0.66, 0.30, 0.82)
const COL_FILL_BASE := Color(0.82, 0.59, 0.22, 0.96)
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

var _display_ratio: float = 0.0
var _stripe_scroll: float = 0.0
var _stripe_speed: float = IDLE_STRIPE_SPEED
var _stripe_alpha: float = IDLE_STRIPE_ALPHA
var _anim_tween: Tween = null
var _gain_tween: Tween = null

func _ready() -> void:
	layer = 40
	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_INDER
	_bold_font.variation_embolden = 0.55
	_build_ui()
	EventBus.player_xp_changed.connect(_on_player_xp_changed)
	_sync_immediate()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var frame_w := BAR_WIDTH + FRAME_PAD * 2.0
	var frame_h := BAR_HEIGHT + FRAME_PAD * 2.0

	_holder = Control.new()
	_holder.anchor_left = 0.0
	_holder.anchor_top = 0.0
	_holder.offset_left = 24.0
	_holder.offset_top = 18.0
	_holder.size = Vector2(frame_w, frame_h)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_holder)

	# Outer dark pill bezel (matches FridgeColdnessHUD pill aesthetic)
	_frame_panel = Panel.new()
	_frame_panel.size = Vector2(frame_w, frame_h)
	_frame_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_style = StyleBoxFlat.new()
	_frame_style.bg_color = COL_TRACK_BG
	_frame_style.border_color = COL_BORDER
	_frame_style.set_border_width_all(2)
	_frame_style.set_corner_radius_all(999)
	_frame_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	_frame_style.shadow_size = 10
	_frame_style.shadow_offset = Vector2(0, 4)
	_frame_panel.add_theme_stylebox_override("panel", _frame_style)
	_holder.add_child(_frame_panel)

	# Inner clipped track
	var fill_clip := Control.new()
	fill_clip.position = Vector2(FRAME_PAD, FRAME_PAD)
	fill_clip.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	fill_clip.clip_contents = true
	fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(fill_clip)

	# Clipped rounded pill fill with moving sloped stripes
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
uniform float stripe_density = 18.0;
uniform float stripe_alpha = 0.20;
void fragment() {
	float diag = (FRAGCOORD.x + FRAGCOORD.y) / stripe_density - scroll_offset;
	float band = smoothstep(0.45, 0.52, fract(diag)) * (1.0 - smoothstep(0.88, 0.95, fract(diag)));
	COLOR = vec4(1.0, 0.98, 0.90, band * stripe_alpha);
}
"""
	_stripe_mat = ShaderMaterial.new()
	_stripe_mat.shader = sh
	stripe_rect.material = _stripe_mat
	_fill_panel.add_child(stripe_rect)

	# Subtle top gloss sheen inside the pill
	var gloss := Panel.new()
	gloss.position = Vector2(FRAME_PAD + 6.0, FRAME_PAD + 2.0)
	gloss.size = Vector2(BAR_WIDTH - 12.0, 5.0)
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gloss_s := StyleBoxFlat.new()
	gloss_s.bg_color = Color(1.0, 0.98, 0.92, 0.14)
	gloss_s.set_corner_radius_all(999)
	gloss.add_theme_stylebox_override("panel", gloss_s)
	_holder.add_child(gloss)

	# Overlay text INSIDE the fat bar: Left = "Lv. X", Right = "cur / next"
	var text_margin := MarginContainer.new()
	text_margin.position = Vector2(FRAME_PAD, FRAME_PAD)
	text_margin.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	text_margin.add_theme_constant_override("margin_left", 12)
	text_margin.add_theme_constant_override("margin_right", 12)
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
	_lvl_lbl.add_theme_font_size_override("font_size", 15)
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
	_xp_lbl.add_theme_font_size_override("font_size", 13)
	_xp_lbl.add_theme_color_override("font_color", COL_TEXT_SUB)
	_xp_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_xp_lbl.add_theme_constant_override("outline_size", 4)
	_xp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_row.add_child(_xp_lbl)

	# Floating "+XP" micro-pop to the right of the pill
	_gain_lbl = Label.new()
	_gain_lbl.position = Vector2(frame_w + 10.0, 5.0)
	_gain_lbl.text = ""
	_gain_lbl.modulate.a = 0.0
	_gain_lbl.add_theme_font_override("font", _bold_font)
	_gain_lbl.add_theme_font_size_override("font_size", 15)
	_gain_lbl.add_theme_color_override("font_color", Color(0.66, 0.96, 0.56, 1.0))
	_gain_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_gain_lbl.add_theme_constant_override("outline_size", 4)
	_gain_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_gain_lbl)

func _process(delta: float) -> void:
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

func _on_player_xp_changed(level: int, current_xp: int, xp_to_next: int, gained_xp: int, leveled_up: bool) -> void:
	var target_ratio := 1.0 if xp_to_next <= 0 else clampf(float(current_xp) / float(xp_to_next), 0.0, 1.0)

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

	# Juicy floating "+XP" pop off the right end of the bar
	_gain_lbl.text = "+%d XP" % gained_xp
	if _gain_tween and _gain_tween.is_valid():
		_gain_tween.kill()
	_gain_lbl.modulate.a = 0.0
	_gain_lbl.position.y = 10.0
	_gain_tween = create_tween()
	_gain_tween.tween_property(_gain_lbl, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE)
	_gain_tween.parallel().tween_property(_gain_lbl, "position:y", 4.0, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_gain_tween.tween_interval(1.0)
	_gain_tween.tween_property(_gain_lbl, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	_gain_tween.parallel().tween_property(_gain_lbl, "position:y", -4.0, 0.35).set_trans(Tween.TRANS_SINE)

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_holder.pivot_offset = _holder.size * 0.5
	_anim_tween = create_tween()

	# Surge stripe speed, opacity, glow, and micro-pop
	_anim_tween.tween_property(self, "_stripe_speed", SURGE_STRIPE_SPEED, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tween.parallel().tween_property(self, "_stripe_alpha", SURGE_STRIPE_ALPHA, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tween.parallel().tween_property(_fill_style, "bg_color", COL_FILL_SURGE, 0.14)
	_anim_tween.parallel().tween_property(_frame_style, "border_color", Color(1.0, 0.92, 0.64, 1.0), 0.14)
	_anim_tween.parallel().tween_property(_holder, "scale", Vector2(1.045, 1.045), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(_holder, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE)

	if leveled_up:
		_anim_tween.tween_method(_set_fill_ratio, _display_ratio, 1.0, 0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_anim_tween.tween_callback(func():
			_lvl_lbl.text = "Lv. %d" % level
			_xp_lbl.text = "MAX" if xp_to_next <= 0 else "%d / %d" % [current_xp, xp_to_next]
		)
		_anim_tween.tween_property(_holder, "scale", Vector2(1.10, 1.10), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_anim_tween.tween_property(_holder, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_SINE)
		if xp_to_next > 0:
			_anim_tween.tween_callback(func(): _set_fill_ratio(0.0))
			_anim_tween.tween_method(_set_fill_ratio, 0.0, target_ratio, 0.44).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_lvl_lbl.text = "Lv. %d" % level
		_xp_lbl.text = "MAX" if xp_to_next <= 0 else "%d / %d" % [current_xp, xp_to_next]
		_anim_tween.tween_method(_set_fill_ratio, _display_ratio, target_ratio, 0.56).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Smoothly return stripes & glow back to calm slow idle
	_anim_tween.tween_property(self, "_stripe_speed", IDLE_STRIPE_SPEED, 0.50).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_anim_tween.parallel().tween_property(self, "_stripe_alpha", IDLE_STRIPE_ALPHA, 0.50).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_anim_tween.parallel().tween_property(_fill_style, "bg_color", COL_FILL_BASE, 0.50).set_trans(Tween.TRANS_SINE)
	_anim_tween.parallel().tween_property(_frame_style, "border_color", COL_BORDER, 0.50).set_trans(Tween.TRANS_SINE)
