extends Control

## HelperPrompt.gd
## A simple, non-intrusive UI element that displays tutorial instructions.
## Listens for EventBus.helper_prompt_requested to show/hide and update text.

@onready var label: Label = $PanelContainer/MarginContainer/Label
@onready var panel: PanelContainer = $PanelContainer



func _ready() -> void:
	EventBus.helper_prompt_requested.connect(_on_helper_prompt_requested)
	panel.modulate.a = 0.0
	panel.hide()

func _on_helper_prompt_requested(text: String, is_active: bool) -> void:
	if is_active:
		_show_prompt(text)
	else:
		_hide_prompt()

func _show_prompt(text: String) -> void:
	label.text = text
	panel.show()
	
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC)
	
	# Small bounce effect
	panel.scale = Vector2(0.8, 0.8)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _hide_prompt() -> void:
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(panel.hide)
