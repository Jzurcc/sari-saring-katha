extends Control

@onready var label: Label = $Label

var current_tween: Tween

func _ready() -> void:
	modulate.a = 0.0
	EventBus.music_title_changed.connect(_on_music_title_changed)

func _on_music_title_changed(title: String) -> void:
	if label:
		label.text = "Now Playing - %s by BGM President" % title
	
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	
	current_tween = create_tween()
	# Fade in
	current_tween.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC)
	# Wait
	current_tween.tween_interval(3.0)
	# Fade out
	current_tween.tween_property(self, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_CUBIC)
