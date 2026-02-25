extends Node

signal view_requested(view_name: String)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W:
				view_requested.emit("look_front")
			KEY_S:
				view_requested.emit("look_back")
			KEY_A:
				view_requested.emit("look_left")
			KEY_D:
				view_requested.emit("look_right")
