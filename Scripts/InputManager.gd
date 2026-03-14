extends Node

## Emitted when the player requests a camera view change.
signal view_requested(action: String)

func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		if event.is_action("look_front"):
			view_requested.emit("look_front")
		elif event.is_action("look_back"):
			view_requested.emit("look_back")
		elif event.is_action("look_left"):
			view_requested.emit("look_left")
		elif event.is_action("look_right"):
			view_requested.emit("look_right")
