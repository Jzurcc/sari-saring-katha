extends Label
class_name MoneyLabelUI

const COLOR_GAIN := Color("#7EE081")
const COLOR_SPEND := Color("#F07167")
const PESO_ICON: Texture2D = preload("res://Assets/ui/peso_icon.png")
const POPUP_HOLD_SEC := 2.1
const POPUP_STACK_STEP := 40.0

var is_shaking: bool = false
var original_color: Color
var _last_amount: float = 0.0
var _initialized: bool = false
var _active_popups: Array[WeakRef] = []

func _ready() -> void:
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.insufficient_funds.connect(_on_insufficient_funds)
	original_color = get_theme_color("font_color")
	_last_amount = text.to_float()

func _on_money_changed(amount: float) -> void:
	text = "%.2f" % amount

	# Skip delta popup and SFX on the initial startup / save-load balance sync
	if not _initialized:
		_initialized = true
		_last_amount = amount
		return

	var diff: float = amount - _last_amount
	var container = get_parent()
	
	if diff > 0.005:
		# Gain juice
		EventBus.request_sfx.emit("money_gain")
		add_theme_color_override("font_color", Color("#A8E5A1")) # Soft green
		var tween = create_tween()
		
		# Scale punch
		container.pivot_offset = container.size / 2.0
		tween.tween_property(container, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		
		var reset_tween = create_tween()
		reset_tween.tween_interval(0.3)
		reset_tween.tween_callback(func():
			add_theme_color_override("font_color", original_color)
		)
		_spawn_delta_popup(diff)
	elif diff < -0.005:
		# Spent money fade
		add_theme_color_override("font_color", Color("#E5A1A1")) # Soft red
		var tween = create_tween()
		tween.tween_interval(0.3)
		tween.tween_callback(func():
			add_theme_color_override("font_color", original_color)
		)
		_spawn_delta_popup(diff)
		
	_last_amount = amount

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

	# Gently nudge any existing active popups downward so rapid changes stack cleanly
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
	var outline_color := Color(0.05, 0.08, 0.05, 0.92) if is_gain else Color(0.14, 0.04, 0.04, 0.92)
	var font_res := get_theme_font("font")
	if not font_res:
		font_res = UIStyle.FONT_INDER

	var base_size := get_theme_font_size("font_size")
	var popup_size := clampi(int(roundf(base_size * 0.95)), 24, 34) if base_size > 0 else 28

	var popup := HBoxContainer.new()
	popup.add_theme_constant_override("separation", -2)
	popup.alignment = BoxContainer.ALIGNMENT_BEGIN
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 20

	var sign_lbl := Label.new()
	sign_lbl.text = "+" if is_gain else "-"
	sign_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign_lbl.add_theme_font_override("font", font_res)
	sign_lbl.add_theme_font_size_override("font_size", popup_size)
	sign_lbl.add_theme_color_override("font_color", fg_color)
	sign_lbl.add_theme_color_override("font_outline_color", outline_color)
	sign_lbl.add_theme_constant_override("outline_size", 5)
	popup.add_child(sign_lbl)

	var icon_rect := TextureRect.new()
	icon_rect.texture = PESO_ICON
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_px := float(popup_size) * 1.25
	icon_rect.custom_minimum_size = Vector2(icon_px, icon_px)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(icon_rect)

	var num_lbl := Label.new()
	num_lbl.text = _format_amount_number(diff)
	num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	num_lbl.add_theme_font_override("font", font_res)
	num_lbl.add_theme_font_size_override("font_size", popup_size)
	num_lbl.add_theme_color_override("font_color", fg_color)
	num_lbl.add_theme_color_override("font_outline_color", outline_color)
	num_lbl.add_theme_constant_override("outline_size", 5)
	popup.add_child(num_lbl)

	host.add_child(popup)
	var popup_ref: WeakRef = weakref(popup)
	_active_popups.append(popup_ref)

	var target_pos := Vector2(
		container.position.x + 8.0,
		container.position.y + container.size.y + 4.0
	)
	popup.position = target_pos + Vector2(0.0, -8.0)
	popup.modulate.a = 0.0
	popup.scale = Vector2(0.75, 0.75)

	var tw := popup.create_tween()
	# Pop-in (0.22s)
	tw.tween_property(popup, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(popup, "position:y", target_pos.y, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(popup, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Hold fully opaque for POPUP_HOLD_SEC (2.1s)
	tw.tween_interval(POPUP_HOLD_SEC)
	# Smooth fade and float away (0.45s)
	tw.tween_property(popup, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(popup, "position:y", -14.0, 0.45).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_active_popups.erase(popup_ref)
		var node: Control = popup_ref.get_ref() as Control
		if node != null and is_instance_valid(node):
			node.queue_free()
	)

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
