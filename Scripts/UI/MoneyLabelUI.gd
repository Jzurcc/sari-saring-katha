extends Label
class_name MoneyLabelUI

var is_shaking: bool = false
var original_color: Color
var _last_amount: float = 0.0

func _ready() -> void:
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.insufficient_funds.connect(_on_insufficient_funds)
	original_color = get_theme_color("font_color")
	_last_amount = text.to_float()

func _on_money_changed(amount: float) -> void:
	text = "%.2f" % amount
	var container = get_parent()
	
	if amount > _last_amount:
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
	elif amount < _last_amount:
		# Spent money fade
		add_theme_color_override("font_color", Color("#E5A1A1")) # Soft red
		var tween = create_tween()
		tween.tween_interval(0.3)
		tween.tween_callback(func():
			add_theme_color_override("font_color", original_color)
		)
		
	_last_amount = amount

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
