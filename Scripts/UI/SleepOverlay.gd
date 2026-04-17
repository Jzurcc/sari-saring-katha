extends Control

signal completed

@onready var subtitle_label: Label = $SubtitleLabel
@onready var indicator_label: Label = $IndicatorLabel

var _can_advance: bool = false
var _typing_tween: Tween

func _ready() -> void:
	modulate.a = 0.0
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
	if modulate.a < 1.0:
		var fade_tween = create_tween()
		fade_tween.tween_property(self, "modulate:a", 1.0, 0.5)
	
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

func _input(event: InputEvent) -> void:
	if not visible: return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _can_advance:
			completed.emit()
		elif _typing_tween and _typing_tween.is_running():
			# Fast forward typing
			_typing_tween.kill()
			subtitle_label.visible_ratio = 1.0
			_can_advance = true
			_show_indicator()

func fade_out() -> void:
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.8)
	await fade.finished
	hide()
