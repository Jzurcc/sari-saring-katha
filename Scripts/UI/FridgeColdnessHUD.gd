extends CanvasLayer
class_name FridgeColdnessHUD

## Center-right animated refrigerator coldness meter with moving diagonal stripes.
## Visible while the refrigerator is open OR while coldness is regenerating (< 100%).

const BAR_WIDTH := 28.0
const BAR_HEIGHT := 340.0
const FRAME_PAD := 6.0

const COLOR_ICE := Color("#6CE5FF")
const COLOR_MID := Color("#FFD166")
const COLOR_WARM := Color("#FF5E2B")

var _root: Control
var _holder: Control
var _frame_panel: Panel
var _fill_clip: Control
var _fill_panel: Panel
var _stripe_rect: ColorRect
var _stripe_mat: ShaderMaterial
var _warm_badge: PanelContainer
var _warm_label: Label
var _pct_label: Label

var _coldness: float = 100.0
var _is_open: bool = false
var _is_warm: bool = false
var _is_shown: bool = false
var _stripe_scroll: float = 0.0
var _shimmer_time: float = 0.0
var _vis_tween: Tween = null
var _base_holder_x: float = 0.0

func _ready() -> void:
	layer = -1
	_build_ui()
	EventBus.fridge_coldness_changed.connect(_on_fridge_coldness_changed)
	_on_fridge_coldness_changed(StoryManager.fridge_coldness, false, StoryManager.is_fridge_warm)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var frame_w := BAR_WIDTH + FRAME_PAD * 2.0
	var frame_h := BAR_HEIGHT + FRAME_PAD * 2.0

	_holder = Control.new()
	_holder.anchor_left = 1.0
	_holder.anchor_right = 1.0
	_holder.anchor_top = 0.5
	_holder.anchor_bottom = 0.5
	_holder.offset_left = -(frame_w + 26.0)
	_holder.offset_right = -26.0
	_holder.offset_top = -(frame_h * 0.5)
	_holder.offset_bottom = (frame_h * 0.5)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.modulate.a = 0.0
	_root.add_child(_holder)
	_base_holder_x = _holder.offset_left

	# Outer dark pill bezel
	_frame_panel = Panel.new()
	_frame_panel.size = Vector2(frame_w, frame_h)
	_frame_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.06, 0.07, 0.09, 0.86)
	frame_style.border_color = Color(0.55, 0.85, 0.98, 0.55)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(999)
	frame_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	frame_style.shadow_size = 10
	frame_style.shadow_offset = Vector2(0, 4)
	_frame_panel.add_theme_stylebox_override("panel", frame_style)
	_holder.add_child(_frame_panel)

	# Clipped fill track inside the bezel
	_fill_clip = Control.new()
	_fill_clip.position = Vector2(FRAME_PAD, FRAME_PAD)
	_fill_clip.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_fill_clip.clip_contents = true
	_fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_fill_clip)

	# Inner fill bar (grows from bottom up; CLIP_CHILDREN_AND_DRAW masks stripes cleanly inside rounded corners)
	_fill_panel = Panel.new()
	_fill_panel.position = Vector2.ZERO
	_fill_panel.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_fill_panel.clip_contents = true
	_fill_panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_fill_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = COLOR_ICE
	fill_style.set_corner_radius_all(999)
	_fill_panel.add_theme_stylebox_override("panel", fill_style)
	_fill_clip.add_child(_fill_panel)

	# Animated diagonal sloped semitransparent white stripes shader
	_stripe_rect = ColorRect.new()
	_stripe_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stripe_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stripe_rect.color = Color.WHITE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float scroll_offset = 0.0;
uniform float stripe_density = 18.0;
uniform float stripe_alpha = 0.28;
void fragment() {
	float diag = (FRAGCOORD.x + FRAGCOORD.y) / stripe_density + scroll_offset;
	float band = smoothstep(0.45, 0.52, fract(diag)) * (1.0 - smoothstep(0.88, 0.95, fract(diag)));
	COLOR = vec4(1.0, 1.0, 1.0, band * stripe_alpha);
}
"""
	_stripe_mat = ShaderMaterial.new()
	_stripe_mat.shader = sh
	_stripe_rect.material = _stripe_mat
	_fill_panel.add_child(_stripe_rect)

	# Percentage micro-label above the bar
	_pct_label = Label.new()
	_pct_label.text = "100%"
	_pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pct_label.position = Vector2(-14.0, -26.0)
	_pct_label.size = Vector2(frame_w + 28.0, 22.0)
	_pct_label.add_theme_font_override("font", UIStyle.FONT_INDER)
	_pct_label.add_theme_font_size_override("font_size", 16)
	_pct_label.add_theme_color_override("font_color", COLOR_ICE)
	_pct_label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.08, 0.92))
	_pct_label.add_theme_constant_override("outline_size", 4)
	_pct_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_pct_label)

	# Compact "WARM" warning pill below the bar (only visible when depleted -> warm penalty active)
	_warm_badge = PanelContainer.new()
	_warm_badge.position = Vector2(-22.0, frame_h + 8.0)
	_warm_badge.custom_minimum_size = Vector2(frame_w + 44.0, 24.0)
	_warm_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wb_style := StyleBoxFlat.new()
	wb_style.bg_color = Color(0.24, 0.08, 0.04, 0.92)
	wb_style.border_color = COLOR_WARM
	wb_style.set_border_width_all(1)
	wb_style.set_corner_radius_all(999)
	wb_style.content_margin_left = 8.0
	wb_style.content_margin_right = 8.0
	wb_style.content_margin_top = 2.0
	wb_style.content_margin_bottom = 2.0
	_warm_badge.add_theme_stylebox_override("panel", wb_style)
	_warm_badge.hide()
	_holder.add_child(_warm_badge)

	_warm_label = Label.new()
	_warm_label.text = "WARM -25%"
	_warm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warm_label.add_theme_font_override("font", UIStyle.FONT_INDER)
	_warm_label.add_theme_font_size_override("font_size", 11)
	_warm_label.add_theme_color_override("font_color", Color("#FFB085"))
	_warm_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warm_badge.add_child(_warm_label)

func _process(delta: float) -> void:
	if not _is_shown and _holder.modulate.a <= 0.01:
		return

	# Scroll sloped stripes downward when draining, upward when regenerating
	var scroll_speed := 1.45 if _is_open else (-1.85 if _coldness < 100.0 else 0.35)
	_stripe_scroll += delta * scroll_speed
	if _stripe_mat:
		_stripe_mat.set_shader_parameter("scroll_offset", _stripe_scroll)

	# Multi-frequency trauma-scaled shiver when coldness is critically low while open
	if _is_open and _coldness < 25.0:
		var trauma := clampf((25.0 - _coldness) / 25.0, 0.15, 1.0)
		var amp := 2.6 * trauma * trauma
		_shimmer_time += delta
		_frame_panel.position.x = (sin(_shimmer_time * 31.0) * 0.65 + sin(_shimmer_time * 53.0) * 0.35) * amp
	else:
		_frame_panel.position.x = move_toward(_frame_panel.position.x, 0.0, delta * 24.0)

	if _warm_badge.visible:
		var pulse := 0.82 + 0.18 * sin(Time.get_ticks_msec() * 0.006)
		_warm_badge.modulate.a = pulse

func _on_fridge_coldness_changed(coldness: float, is_open: bool, is_warm: bool) -> void:
	var was_open := _is_open
	var was_warm := _is_warm
	var was_below_full := _coldness < 100.0
	_coldness = clampf(coldness, 0.0, 100.0)
	_is_open = is_open
	_is_warm = is_warm

	_update_bar_visuals()
	if _is_warm and not was_warm:
		_warm_badge.pivot_offset = _warm_badge.size * 0.5
		_warm_badge.scale = Vector2(1.18, 0.85)
		var pop := create_tween()
		pop.set_ignore_time_scale(true)
		pop.tween_property(_warm_badge, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var should_show := _is_open or _coldness < 100.0
	if should_show and not _is_shown:
		_animate_in()
	elif not should_show and _is_shown:
		var just_finished_regen := (not was_open) and was_below_full and _coldness >= 100.0
		_animate_out(just_finished_regen)

func _update_bar_visuals() -> void:
	var ratio := _coldness / 100.0
	var fill_h := maxf(0.0, BAR_HEIGHT * ratio)
	_fill_panel.size = Vector2(BAR_WIDTH, fill_h)
	_fill_panel.position = Vector2(0.0, BAR_HEIGHT - fill_h)
	_fill_panel.visible = fill_h > 1.0

	# Smooth icy-blue -> warm-amber -> fiery-orange color ramp
	var col: Color
	if ratio >= 0.45:
		col = COLOR_MID.lerp(COLOR_ICE, (ratio - 0.45) / 0.55)
	else:
		col = COLOR_WARM.lerp(COLOR_MID, ratio / 0.45)

	var fill_style := _fill_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if fill_style:
		fill_style.bg_color = col

	var frame_style := _frame_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if frame_style:
		frame_style.border_color = Color(col.r, col.g, col.b, 0.65)

	_pct_label.text = "%d%%" % int(roundf(_coldness))
	_pct_label.add_theme_color_override("font_color", col)
	_warm_badge.visible = _is_warm

func _animate_in() -> void:
	_is_shown = true
	if _vis_tween and _vis_tween.is_valid():
		_vis_tween.kill()
	_holder.offset_left = _base_holder_x + 44.0
	_vis_tween = create_tween().set_parallel(true)
	_vis_tween.set_ignore_time_scale(true)
	_vis_tween.tween_property(_holder, "offset_left", _base_holder_x, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_vis_tween.tween_property(_holder, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)

func _animate_out(flash_chilled: bool) -> void:
	_is_shown = false
	if _vis_tween and _vis_tween.is_valid():
		_vis_tween.kill()
	_vis_tween = create_tween()
	_vis_tween.set_ignore_time_scale(true)
	if flash_chilled:
		_vis_tween.tween_property(_frame_panel, "modulate", Color(1.35, 1.45, 1.55, 1.0), 0.12).set_trans(Tween.TRANS_SINE)
		_vis_tween.tween_property(_frame_panel, "modulate", Color.WHITE, 0.16).set_trans(Tween.TRANS_SINE)
	_vis_tween.tween_property(_holder, "offset_left", _base_holder_x + 44.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_vis_tween.parallel().tween_property(_holder, "modulate:a", 0.0, 0.26).set_trans(Tween.TRANS_SINE)
