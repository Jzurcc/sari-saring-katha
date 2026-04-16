extends Control

@onready var label: Label = $Label

func _ready() -> void:
	modulate.a = 0.0
	SaveManager.save_started.connect(_on_save_started)
	SaveManager.save_finished.connect(_on_save_finished)

func _on_save_started() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC)
	
func _on_save_finished() -> void:
	# Add a small delay so the user can actually see it (minimum 1s)
	get_tree().create_timer(1.0).timeout.connect(func():
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_CUBIC)
	)
