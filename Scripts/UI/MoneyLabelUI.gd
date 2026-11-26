extends Label
class_name MoneyLabelUI

const COLOR_GAIN := Color("#7EE081")
const COLOR_SPEND := Color("#F07167")
const COLOR_GAIN_FLASH := Color("#E8FFD0")
const COLOR_SPEND_FLASH := Color("#FFB4A8")
const PESO_ICON: Texture2D = preload("res://Assets/ui/peso_icon.png")
const POPUP_HOLD_SEC := 1.7
const POPUP_STACK_STEP := 40.0

var is_shaking: bool = false
var original_color: Color
var _last_amount: float = 0.0
var _initialized: bool = false
var _active_popups: Array[WeakRef] = []
var _displayed_amount: float = 0.0
var _count_tween: Tween = null
var _color_tween: Tween = null
var _punch_tween: Tween = null

func _ready() -> void:
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.insufficient_funds.connect(_on_insufficient_funds)
	original_color = get_theme_color("font_color")
	_last_amount = text.to_float()
	_displayed_amount = _last_amount

func _on_money_changed(amount: float) -> void:
	# Skip delta popup, SFX, and counting on the initial startup / save-load balance sync
	if not _initialized:
		_initialized = true
		_last_amount = amount
		_displayed_amount = amount
		text = "%.2f" % amount
		return

	var diff: float = amount - _last_amount
	_last_amount = amount
	var container := get_parent() as Control

	if absf(diff) <= 0.005:
		_displayed_amount = amount
		text = "%.2f" % amount
		return

	var is_gain := diff > 0.0
	_roll_counter_to(amount, is_gain, absf(diff))

	if is_gain:
		EventBus.request_sfx.emit("money_gain")
		_flash_label(COLOR_GAIN_FLASH, 0.9)
		if is_instance_valid(container):
			if _punch_tween and _punch_tween.is_valid():
				_punch_tween.kill()
			container.pivot_offset = container.size / 2.0
			var strength := clampf(1.10 + minf(diff, 200.0) / 200.0 * 0.12, 1.10, 1.22)
			_punch_tween = create_tween()
			_punch_tween.tween_property(container, "scale", Vector2(strength, strength), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_punch_tween.tween_property(container, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		_flash_label(COLOR_SPEND_FLASH, 0.6)
		if is_instance_valid(container):
			if _punch_tween and _punch_tween.is_valid():
				_punch_tween.kill()
			container.pivot_offset = container.size / 2.0
			container.rotation = 0.0
			_punch_tween = create_tween()
			_punch_tween.tween_property(container, "scale", Vector2(0.94, 0.94), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_punch_tween.tween_property(container, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_delta_popup(diff)


## Smooth "number go up" counter: ease-out roll with a per-step soft pulse so the digits feel alive.
func _roll_counter_to(target: float, is_gain: bool, magnitude: float) -> void:
	if _count_tween and _count_tween.is_valid():
		_count_tween.kill()
	var from_val := _displayed_amount
	var duration := clampf(0.50 + log(1.0 + magnitude) * 0.13, 0.50, 1.15)
	if not is_gain:
		duration *= 0.70
	_count_tween = create_tween()
	_count_tween.tween_method(func(v: float):
		_displayed_amount = v
		text = "%.2f" % v
	, from_val, target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_count_tween.tween_callback(func():
		_displayed_amount = target
		text = "%.2f" % target
	)


func _flash_label(flash_color: Color, hold: float) -> void:
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	add_theme_color_override("font_color", flash_color)
	_color_tween = create_tween()
	_color_tween.tween_interval(0.12)
	_color_tween.tween_method(func(c: Color):
		add_theme_color_override("font_color", c)
	, flash_color, original_color, hold).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_color_tween.tween_callback(func():
		add_theme_color_override("font_color", original_color)
	)


func _format_amount_number(diff: float) -> String:
	var abs_val := absf(diff)
	if is_equal_approx(abs_val, roundf(abs_val)):
		return "%d" % int(roundf(abs_val))
	return "%.2f" % abs_val


func _spawn_delta_popup(diff: float) -> void:
	var container := get_parent() as Control
	if not is_instance_valid(container):
		return
	var host := container.get_parent()
	if not is_instance_valid(host):
		return

	# Nudge existing popups downward so rapid changes stack cleanly
	var still_valid: Array[WeakRef] = []
	for ref in _active_popups:
		if not ref:
			continue
		var old_popup: Control = ref.get_ref() as Control
		if old_popup != null and is_instance_valid(old_popup) and old_popup.is_inside_tree():
			still_valid.append(ref)
			var nudge: Tween = old_popup.create_tween()
			nudge.tween_property(old_popup, "position:y", old_popup.position.y + POPUP_STACK_STEP, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_popups = still_valid

	var is_gain := diff > 0.0
	var fg_color := COLOR_GAIN if is_gain else COLOR_SPEND
	var outline_color := Color(0.04, 0.07, 0.04, 0.95) if is_gain else Color(0.14, 0.04, 0.04, 0.95)
	var font_res := get_theme_font("font")
	if not font_res:
		font_res = UIStyle.FONT_INDER

	var base_size := get_theme_font_size("font_size")
	var mag_boost := clampf(absf(diff) / 120.0, 0.0, 1.0) * 8.0
	var popup_size := clampi(int(roundf(base_size * 0.95 + mag_boost)), 26, 42) if base_size > 0 else 30

	# Dark rounded pill with a colored rim so the delta stays readable on any background
	var popup := PanelContainer.new()
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 20
	var pill := UIStyle.create_flat_stylebox(Color(0.07, 0.058, 0.05, 0.92), 18, 14, 4)
	pill.border_color = Color(fg_color.r, fg_color.g, fg_color.b, 0.85)
	pill.set_border_width_all(2)
	pill.shadow_color = Color(fg_color.r, fg_color.g, fg_color.b, 0.28)
	pill.shadow_size = 10
	popup.add_theme_stylebox_override("panel", pill)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(row)

	var sign_lbl := Label.new()
	sign_lbl.text = "+" if is_gain else "-"
	sign_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign_lbl.add_theme_font_override("font", font_res)
	sign_lbl.add_theme_font_size_override("font_size", popup_size)
	sign_lbl.add_theme_color_override("font_color", fg_color)
	sign_lbl.add_theme_color_override("font_outline_color", outline_color)
	sign_lbl.add_theme_constant_override("outline_size", 5)
	row.add_child(sign_lbl)

	var icon_rect := TextureRect.new()
	icon_rect.texture = PESO_ICON
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_px := float(popup_size) * 1.1
	icon_rect.custom_minimum_size = Vector2(icon_px, icon_px)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_rect)

	var num_lbl := Label.new()
	num_lbl.text = _format_amount_number(diff)
	num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	num_lbl.add_theme_font_override("font", font_res)
	num_lbl.add_theme_font_size_override("font_size", popup_size)
	num_lbl.add_theme_color_override("font_color", fg_color)
	num_lbl.add_theme_color_override("font_outline_color", outline_color)
	num_lbl.add_theme_constant_override("outline_size", 5)
	row.add_child(num_lbl)

	host.add_child(popup)
	var popup_ref: WeakRef = weakref(popup)
	_active_popups.append(popup_ref)

	var target_pos := Vector2(
		container.position.x + 6.0,
		container.position.y + container.size.y + 6.0
	)
	var enter_offset := Vector2(0.0, -14.0) if is_gain else Vector2(0.0, 14.0)
	popup.position = target_pos + enter_offset
	popup.modulate.a = 0.0
	popup.scale = Vector2(0.4, 0.4)

	# Wait one frame so the pill has its real size before scaling around its left-center
	await get_tree().process_frame
	if not is_instance_valid(popup):
		return
	popup.pivot_offset = Vector2(14.0, popup.size.y * 0.5)

	var tw := popup.create_tween()
	# Overshoot pop-in
	tw.tween_property(popup, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(popup, "position:y", target_pos.y, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(popup, "scale", Vector2(1.18, 1.18), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(popup, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Hold, then drift away in the direction of the change
	tw.tween_interval(POPUP_HOLD_SEC)
	tw.tween_property(popup, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(popup, "position:y", -16.0 if is_gain else 16.0, 0.55).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_active_popups.erase(popup_ref)
		var node: Control = popup_ref.get_ref() as Control
		if node != null and is_instance_valid(node):
			node.queue_free()
	)

	# Celebratory coin-gold sparkle burst for gains
	if is_gain:
		var Juice := load("res://Scripts/UI/Minigames/MinigameJuice.gd")
		if Juice and host is Control:
			var burst_n := clampi(6 + int(absf(diff) / 6.0), 6, 22)
			Juice.spawn_burst(host as Control, target_pos + Vector2(26.0, 18.0), Color(1.0, 0.88, 0.45), burst_n, 90.0)

func _on_insufficient_funds() -> void:
	EventBus.request_sfx.emit("error")
	if is_shaking:
		return
	is_shaking = true
	add_theme_color_override("font_color", Color("#CB6245"))
	var container = get_parent()
	var orig_x = container.position.x
	var tween = create_tween()
	
	tween.tween_property(container, "position:x", orig_x + 6, 0.05)
	tween.tween_property(container, "position:x", orig_x - 6, 0.05)
	tween.tween_property(container, "position:x", orig_x + 6, 0.05)
	tween.tween_property(container, "position:x", orig_x - 6, 0.05)
	tween.tween_property(container, "position:x", orig_x, 0.05)
	
	tween.tween_callback(func():
		add_theme_color_override("font_color", original_color)
		is_shaking = false
	)
