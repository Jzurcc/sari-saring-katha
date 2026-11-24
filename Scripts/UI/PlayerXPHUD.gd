class_name PlayerXPHUD
extends CanvasLayer

## Top-left compact Player Level & XP HUD with a slow sloped diagonal-striped fill bar
## matching FridgeColdnessHUD's shader language. When XP is gained, the bar smoothly
## animates to the new value while the stripes speed up and brighten, then settle back.

const TRACK_WIDTH := 196.0
const TRACK_HEIGHT := 11.0
const IDLE_STRIPE_SPEED := 0.28
const IDLE_STRIPE_ALPHA := 0.18
const SURGE_STRIPE_SPEED := 2.65
const SURGE_STRIPE_ALPHA := 0.54

const COL_ESPRESSO := Color(0.082, 0.074, 0.066, 0.90)
const COL_GOLD := Color(0.835, 0.624, 0.278, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.875, 0.56, 1.0)
const COL_CREAM := Color(1.0, 0.922, 0.792, 1.0)
const COL_CREAM_MUTED := Color(0.82, 0.75, 0.64, 0.85)

var _panel: PanelContainer
var _lvl_lbl: Label
var _xp_lbl: Label
var _gain_lbl: Label
var _fill_panel: Panel
var _fill_style: StyleBoxFlat
var _stripe_mat: ShaderMaterial

var _display_ratio: float = 0.0
var _stripe_scroll: float = 0.0
var _stripe_speed: float = IDLE_STRIPE_SPEED
var _stripe_alpha: float = IDLE_STRIPE_ALPHA
var _anim_tween: Tween = null
var _gain_tween: Tween = null

func _ready() -> void:
	layer = 40
	_build_ui()
	EventBus.player_xp_changed.connect(_on_player_xp_changed)
	_sync_immediate()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.offset_left = 20.0
	_panel.offset_top = 86.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p_style := UIStyle.create_flat_stylebox(COL_ESPRESSO, 10, 12, 8)
	p_style.border_color = Color(0.835, 0.624, 0.278, 0.72)
	p_style.border_width_left = 2
	p_style.border_width_top = 1
	p_style.border_width_right = 1
	p_style.border_width_bottom = 1
	p_style.shadow_color = Color(0.0, 0.0, 0.0, 0.40)
	p_style.shadow_size = 8
	_panel.add_theme_stylebox_override("panel", p_style)
	root.add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top_row)

	_lvl_lbl = Label.new()
	_lvl_lbl.text = "Lv. 1"
	_lvl_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_lvl_lbl.add_theme_font_size_override("font_size", 15)
	_lvl_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_lvl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(_lvl_lbl)

	_gain_lbl = Label.new()
	_gain_lbl.text = ""
	_gain_lbl.modulate.a = 0.0
	_gain_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_gain_lbl.add_theme_font_size_override("font_size", 12)
	_gain_lbl.add_theme_color_override("font_color", Color(0.62, 0.96, 0.58, 1.0))
	_gain_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(_gain_lbl)

	_xp_lbl = Label.new()
	_xp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_xp_lbl.text = "0 / 100 XP"
	_xp_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_xp_lbl.add_theme_font_size_override("font_size", 12)
	_xp_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	_xp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(_xp_lbl)

	# Track container
	var track_bg := Panel.new()
	track_bg.custom_minimum_size = Vector2(TRACK_WIDTH, TRACK_HEIGHT)
	track_bg.clip_contents = true
	track_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t_style := StyleBoxFlat.new()
	t_style.bg_color = Color(0.045, 0.04, 0.036, 0.95)
	t_style.border_color = Color(0.48, 0.34, 0.16, 0.65)
	t_style.set_border_width_all(1)
	t_style.set_corner_radius_all(999)
	track_bg.add_theme_stylebox_override("panel", t_style)
	v.add_child(track_bg)

	# Clipped inner fill bar with moving diagonal stripes
	_fill_panel = Panel.new()
	_fill_panel.position = Vector2(1.0, 1.0)
	_fill_panel.size = Vector2(0.0, TRACK_HEIGHT - 2.0)
	_fill_panel.clip_contents = true
	_fill_panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_fill_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_style = StyleBoxFlat.new()
	_fill_style.bg_color = COL_GOLD
	_fill_style.set_corner_radius_all(999)
	_fill_panel.add_theme_stylebox_override("panel", _fill_style)
	track_bg.add_child(_fill_panel)

	var stripe_rect := ColorRect.new()
	stripe_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	stripe_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe_rect.color = Color.WHITE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float scroll_offset = 0.0;
uniform float stripe_density = 16.0;
uniform float stripe_alpha = 0.18;
void fragment() {
	float diag = (FRAGCOORD.x + FRAGCOORD.y) / stripe_density - scroll_offset;
	float band = smoothstep(0.45, 0.52, fract(diag)) * (1.0 - smoothstep(0.88, 0.95, fract(diag)));
	COLOR = vec4(1.0, 0.97, 0.88, band * stripe_alpha);
}
"""
	_stripe_mat = ShaderMaterial.new()
	_stripe_mat.shader = sh
	stripe_rect.material = _stripe_mat
	_fill_panel.add_child(stripe_rect)

func _process(delta: float) -> void:
	_stripe_scroll += delta * _stripe_speed
	if _stripe_mat:
		_stripe_mat.set_shader_parameter("scroll_offset", _stripe_scroll)
		_stripe_mat.set_shader_parameter("stripe_alpha", _stripe_alpha)

func _set_fill_ratio(ratio: float) -> void:
	_display_ratio = clampf(ratio, 0.0, 1.0)
	var inner_w := (TRACK_WIDTH - 2.0) * _display_ratio
	_fill_panel.size = Vector2(inner_w, TRACK_HEIGHT - 2.0)
	_fill_panel.visible = inner_w > 1.0

func _sync_immediate() -> void:
	var lvl := StoryManager.player_level
	var cur := StoryManager.player_xp
	var need := StoryManager.get_xp_for_next_level(lvl)
	_lvl_lbl.text = "Player Lv. %d" % lvl
	if need <= 0:
		_xp_lbl.text = "MAX"
		_set_fill_ratio(1.0)
	else:
		_xp_lbl.text = "%d / %d XP" % [cur, need]
		_set_fill_ratio(float(cur) / float(need))

func _on_player_xp_changed(level: int, current_xp: int, xp_to_next: int, gained_xp: int, leveled_up: bool) -> void:
	var target_ratio := 1.0 if xp_to_next <= 0 else clampf(float(current_xp) / float(xp_to_next), 0.0, 1.0)

	# Instant sync (save load / reset)
	if gained_xp <= 0:
		if _anim_tween and _anim_tween.is_valid():
			_anim_tween.kill()
		_stripe_speed = IDLE_STRIPE_SPEED
		_stripe_alpha = IDLE_STRIPE_ALPHA
		_fill_style.bg_color = COL_GOLD
		_lvl_lbl.text = "Player Lv. %d" % level
		_xp_lbl.text = "MAX" if xp_to_next <= 0 else "%d / %d XP" % [current_xp, xp_to_next]
		_set_fill_ratio(target_ratio)
		return

	# Show brief +XP gain pill
	_gain_lbl.text = "+%d XP" % gained_xp
	if _gain_tween and _gain_tween.is_valid():
		_gain_tween.kill()
	_gain_lbl.modulate.a = 0.0
	_gain_tween = create_tween()
	_gain_tween.tween_property(_gain_lbl, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE)
	_gain_tween.tween_interval(1.1)
	_gain_tween.tween_property(_gain_lbl, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween()

	# Surge the diagonal stripe speed & opacity + brighten fill while animating
	_anim_tween.tween_property(self, "_stripe_speed", SURGE_STRIPE_SPEED, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tween.parallel().tween_property(self, "_stripe_alpha", SURGE_STRIPE_ALPHA, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tween.parallel().tween_property(_fill_style, "bg_color", COL_GOLD_BRIGHT, 0.14)

	if leveled_up:
		# Fill to 100%, flash gold, switch level label, then fill to remainder
		_anim_tween.tween_method(_set_fill_ratio, _display_ratio, 1.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_anim_tween.tween_callback(func():
			_lvl_lbl.text = "Player Lv. %d" % level
			_xp_lbl.text = "MAX" if xp_to_next <= 0 else "%d / %d XP" % [current_xp, xp_to_next]
			_panel.pivot_offset = _panel.size * 0.5
		)
		_anim_tween.tween_property(_panel, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_anim_tween.tween_property(_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
		if xp_to_next > 0:
			_anim_tween.tween_callback(func(): _set_fill_ratio(0.0))
			_anim_tween.tween_method(_set_fill_ratio, 0.0, target_ratio, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_lvl_lbl.text = "Player Lv. %d" % level
		_xp_lbl.text = "MAX" if xp_to_next <= 0 else "%d / %d XP" % [current_xp, xp_to_next]
		_anim_tween.tween_method(_set_fill_ratio, _display_ratio, target_ratio, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Ease stripes & fill color smoothly back to calm idle state
	_anim_tween.tween_property(self, "_stripe_speed", IDLE_STRIPE_SPEED, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_anim_tween.parallel().tween_property(self, "_stripe_alpha", IDLE_STRIPE_ALPHA, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_anim_tween.parallel().tween_property(_fill_style, "bg_color", COL_GOLD, 0.45).set_trans(Tween.TRANS_SINE)
