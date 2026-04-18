extends CanvasLayer

signal completed

@onready var content: Control = $Content
@onready var subtitle_label: Label = $Content/SubtitleLabel
@onready var indicator_label: Label = $Content/IndicatorLabel

var _can_advance: bool = false
var _typing_tween: Tween

func _ready() -> void:
	content.modulate.a = 0.0
	subtitle_label.text = ""
	indicator_label.modulate.a = 0.0
	indicator_label.hide()

func display_text(text_content: String) -> void:
	_can_advance = false
	indicator_label.hide()
	
	if _typing_tween:
		_typing_tween.kill()
	
	subtitle_label.text = text_content
	subtitle_label.visible_ratio = 0.0
	
	# Fade in the whole overlay if it was hidden
	if content.modulate.a < 1.0:
		var fade_tween = create_tween()
		fade_tween.tween_property(content, "modulate:a", 1.0, 0.5)
	
	_typing_tween = create_tween()
	var typing_duration = max(1.0, text_content.length() / 25.0)
	_typing_tween.tween_property(subtitle_label, "visible_ratio", 1.0, typing_duration)
	await _typing_tween.finished
	
	_can_advance = true
	_show_indicator()

func _show_indicator() -> void:
	indicator_label.show()
	var blink = create_tween().set_loops()
	blink.tween_property(indicator_label, "modulate:a", 1.0, 0.5)
	blink.tween_property(indicator_label, "modulate:a", 0.0, 0.5)

func fade_out() -> void:
	var fade = create_tween()
	fade.tween_property(content, "modulate:a", 0.0, 0.8)
	await fade.finished
	hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dialogic_default_action") or event.is_action_pressed("ui_accept"):
		if _can_advance:
			_can_advance = false
			completed.emit()
			get_viewport().set_input_as_handled()
