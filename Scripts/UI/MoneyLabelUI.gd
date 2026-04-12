extends Label
class_name MoneyLabelUI

var is_shaking: bool = false
var original_color: Color

func _ready() -> void:
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.insufficient_funds.connect(_on_insufficient_funds)
	original_color = get_theme_color("font_color")

func _on_money_changed(amount: float) -> void:
	text = "%.2f" % amount

func _on_insufficient_funds() -> void:
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
