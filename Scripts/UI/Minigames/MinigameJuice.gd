class_name MinigameJuice
extends RefCounted

## Shared audio, visual game-feel juice, and modernized UI design-system helpers
## for all 4 minigames (Dusk Lamp Swat, Sipa, Teks Memory, Anting-Anting Trace).

# --- Unified Warm Espresso + Antique Gold + Cream Design Tokens ---
const COL_PANEL_BG := Color(0.10, 0.08, 0.06, 0.96)
const COL_HUD_BG := Color(0.10, 0.08, 0.06, 0.88)
const COL_GOLD := Color(0.90, 0.72, 0.34, 1.0)
const COL_GOLD_SOFT := Color(0.88, 0.70, 0.34, 0.42)
const COL_GOLD_BRIGHT := Color(1.0, 0.91, 0.62, 1.0)
const COL_CREAM := Color(0.97, 0.93, 0.86, 1.0)
const COL_MUTED := Color(0.76, 0.70, 0.62, 1.0)
const COL_SUCCESS := Color(0.46, 0.88, 0.54, 1.0)
const COL_DANGER := Color(0.94, 0.42, 0.36, 1.0)

const ICON_CLOCK := "res://Assets/ui/icons/clock.png"
const ICON_TROPHY := "res://Assets/ui/icons/trophy.png"
const ICON_SPARKLES := "res://Assets/ui/icons/sparkles.png"
const ICON_LAYERS := "res://Assets/ui/icons/layers-2.png"
const ICON_ZAP := "res://Assets/ui/icons/zap.png"
const ICON_FLAME := "res://Assets/ui/icons/flame.png"
const ICON_AWARD := "res://Assets/ui/icons/award.png"


static func are_minigame_tutorials_enabled() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		return bool(cfg.get_value("gameplay", "minigame_tutorials", true))
	return true


static func load_icon(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Texture2D:
			return res
	return null


static func make_icon_rect(path: String, sz: Vector2 = Vector2(20, 20), tint: Color = COL_GOLD_BRIGHT) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load_icon(path)
	tr.custom_minimum_size = sz
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.modulate = tint
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func play_sfx(sfx_name: String, pitch: float = 1.0, vol_delta_db: float = 0.0) -> void:
	if is_instance_valid(AudioManager) and is_instance_valid(AudioManager.sfx_pool):
		AudioManager.sfx_pool.play_sfx_pitched(sfx_name, pitch, vol_delta_db)
	else:
		EventBus.request_sfx.emit(sfx_name)


static func play_win_fanfare(owner: Node) -> void:
	if not is_instance_valid(owner) or not owner.is_inside_tree():
		return
	play_sfx("pickup", 1.05, 1.0)
	var tw := owner.create_tween()
	tw.tween_interval(0.11)
	tw.tween_callback(func(): play_sfx("pickup", 1.26, 1.5))
	tw.tween_interval(0.11)
	tw.tween_callback(func():
		play_sfx("pickup", 1.50, 2.0)
		play_sfx("money_gain", 1.08, -1.0)
	)


static func play_lose_sting(owner: Node) -> void:
	if not is_instance_valid(owner) or not owner.is_inside_tree():
		return
	play_sfx("drop", 0.80, 1.0)
	var tw := owner.create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(func(): play_sfx("money_decrease", 0.88, -2.0))


static func shake_control(ctrl: Control, intensity: float = 8.0, duration: float = 0.22) -> void:
	if not is_instance_valid(ctrl) or not ctrl.is_inside_tree():
		return
	var orig_pos: Vector2 = ctrl.get_meta("_juice_orig_pos", ctrl.position)
	ctrl.set_meta("_juice_orig_pos", orig_pos)
	var old_tw = ctrl.get_meta("_juice_shake_tw", null)
	if old_tw is Tween and old_tw.is_valid():
		old_tw.kill()
		ctrl.position = orig_pos
	var steps := maxi(3, int(roundf(duration / 0.032)))
	var step_dt := duration / float(steps)
	var tw := ctrl.create_tween()
	ctrl.set_meta("_juice_shake_tw", tw)
	for i in range(steps):
		var decay := 1.0 - float(i) / float(steps)
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * intensity * decay
		tw.tween_property(ctrl, "position", orig_pos + off, step_dt)
	tw.tween_property(ctrl, "position", orig_pos, step_dt)


static func pop_control(ctrl: Control, peak_scale: float = 1.18, duration: float = 0.22) -> void:
	if not is_instance_valid(ctrl) or not ctrl.is_inside_tree():
		return
	ctrl.pivot_offset = ctrl.size * 0.5
	var old_tw = ctrl.get_meta("_juice_pop_tw", null)
	if old_tw is Tween and old_tw.is_valid():
		old_tw.kill()
	var tw := ctrl.create_tween()
	ctrl.set_meta("_juice_pop_tw", tw)
	tw.tween_property(ctrl, "scale", Vector2(peak_scale, peak_scale), duration * 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "scale", Vector2.ONE, duration * 0.62).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# =============================================================================
# MODERNIZED UI COMPONENT FACTORIES (True Fredoka + Safe Zones + High Contrast)
# =============================================================================

static func make_pill_style(
	bg: Color = COL_HUD_BG,
	border: Color = COL_GOLD_SOFT,
	radius: int = 14,
	pad_x: int = 18,
	pad_y: int = 10,
	border_w: int = 2
) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(border_w)
	st.set_corner_radius_all(radius)
	st.content_margin_left = pad_x
	st.content_margin_right = pad_x
	st.content_margin_top = pad_y
	st.content_margin_bottom = pad_y
	st.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	st.shadow_size = 12
	st.shadow_offset = Vector2(0, 3)
	return st


static func make_modal_style(border_col: Color = COL_GOLD) -> StyleBoxFlat:
	var st := make_pill_style(COL_PANEL_BG, border_col, 18, 32, 26, 2)
	st.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	st.shadow_size = 24
	st.shadow_offset = Vector2(0, 8)
	return st


static func make_modal_shell(parent: Control, min_size: Vector2 = Vector2(540, 0)) -> Dictionary:
	## Creates a full-rect dimmed overlay + CenterContainer + styled PanelContainer
	## so modals are always centered cleanly across 720p/1080p/4K/ultrawide displays.
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.03, 0.02, 0.015, 0.62)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	parent.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", make_modal_style())
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	return {"overlay": overlay, "panel": panel, "vbox": vbox}


static func style_primary_button(btn: Button, min_size: Vector2 = Vector2(210, 50)) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = min_size
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	btn.add_theme_font_size_override("font_size", 20)
	var st := make_pill_style(Color(0.38, 0.27, 0.11, 0.98), Color(0.96, 0.82, 0.44, 0.96), 12, 24, 10, 2)
	var hov := st.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.49, 0.36, 0.15, 0.98)
	hov.border_color = Color(1.0, 0.94, 0.72, 1.0)
	var prs := st.duplicate() as StyleBoxFlat
	prs.bg_color = Color(0.28, 0.20, 0.08, 0.98)
	var dis := st.duplicate() as StyleBoxFlat
	dis.bg_color = Color(0.16, 0.13, 0.10, 0.65)
	dis.border_color = Color(0.86, 0.67, 0.32, 0.22)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", prs)
	btn.add_theme_stylebox_override("disabled", dis)
	btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.76, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.60, 0.54, 0.46, 0.55))


static func style_close_button(btn: Button) -> void:
	## Standardized 48x48 coral-bordered espresso close button (exceeds 44px touch target).
	btn.text = "✕"
	btn.tooltip_text = "Close (Esc)"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(48, 48)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	btn.add_theme_font_size_override("font_size", 20)
	var norm := make_pill_style(Color(0.18, 0.10, 0.09, 0.94), Color(0.88, 0.40, 0.36, 0.76), 12, 6, 4, 2)
	var hov := make_pill_style(Color(0.30, 0.13, 0.12, 0.98), Color(1.0, 0.56, 0.52, 0.98), 12, 6, 4, 2)
	var prs := make_pill_style(Color(0.14, 0.08, 0.07, 0.98), Color(0.88, 0.40, 0.36, 0.90), 12, 6, 4, 2)
	btn.add_theme_stylebox_override("normal", norm)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", prs)
	btn.add_theme_color_override("font_color", Color(1.0, 0.84, 0.82, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.78, 0.74, 1.0))


static func make_keycap_pill(key_text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.20, 0.15, 0.10, 0.96)
	st.border_color = Color(0.92, 0.76, 0.42, 0.75)
	st.set_border_width_all(1)
	st.border_width_bottom = 3
	st.set_corner_radius_all(6)
	st.content_margin_left = 9
	st.content_margin_right = 9
	st.content_margin_top = 2
	st.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", st)
	var lbl := Label.new()
	lbl.text = key_text
	lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(lbl)
	return p


static func make_vsep(height: float = 22.0) -> VSeparator:
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(2, height)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.88, 0.70, 0.34, 0.28)
	sep.add_theme_stylebox_override("separator", st)
	return sep


static func make_stat_chip(label_text: String, value_text: String, val_color: Color = COL_GOLD_BRIGHT) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", make_pill_style(Color(0.15, 0.11, 0.08, 0.94), COL_GOLD_SOFT, 10, 14, 8, 1))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)

	var k := Label.new()
	k.text = label_text
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	k.add_theme_font_size_override("font_size", 14)
	k.add_theme_color_override("font_color", COL_MUTED)
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(k)

	var val := Label.new()
	val.text = value_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	val.add_theme_font_size_override("font_size", 22)
	val.add_theme_color_override("font_color", val_color)
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(val)
	p.set_meta("value_label", val)
	return p


static func style_hud_label(lbl: Label, font: Font, font_size: int, col: Color, outline_px: int = 4) -> void:
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.92))
	lbl.add_theme_constant_override("outline_size", outline_px)


static func pop_panel_in(panel: Control) -> void:
	if not is_instance_valid(panel) or not panel.is_inside_tree():
		return
	panel.visible = true
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.86, 0.86)
	panel.modulate.a = 0.0
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)


static func spawn_burst(parent: Control, origin: Vector2, color: Color, count: int = 10, spread: float = 130.0) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	for i in range(count):
		var p := ColorRect.new()
		var sz := randf_range(5.0, 10.0)
		p.size = Vector2(sz, sz)
		p.pivot_offset = p.size * 0.5
		p.position = origin - p.size * 0.5
		p.rotation = randf() * TAU
		p.color = color.lerp(Color.WHITE, randf_range(0.0, 0.35))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(p)

		var ang := (TAU * float(i) / float(count)) + randf_range(-0.35, 0.35)
		var dist := randf_range(spread * 0.45, spread)
		var dest := p.position + Vector2(cos(ang), sin(ang)) * dist + Vector2(0.0, randf_range(12.0, 38.0))
		var dur := randf_range(0.28, 0.46)
		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p, "position", dest, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "rotation", p.rotation + randf_range(-4.0, 4.0), dur)
		tw.tween_property(p, "scale", Vector2(0.15, 0.15), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(p, "modulate:a", 0.0, dur).set_delay(dur * 0.30)
		tw.chain().tween_callback(p.queue_free)
