extends Control


@onready var label: Label = $Label

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	modulate.a = 0.0
	SaveManager.save_started.connect(_on_save_started)
	SaveManager.save_finished.connect(_on_save_finished)

func _on_save_started() -> void:
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC)
	
func _on_save_finished() -> void:
	# Add a delay so the user can actually see it (approx 2s)
	# create_timer(time, process_always, process_in_physics, ignore_time_scale)
	get_tree().create_timer(2.0, true).timeout.connect(func():
		var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(self, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_CUBIC)
	)

