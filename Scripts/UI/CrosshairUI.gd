extends Control
class_name CrosshairUI

func _ready() -> void:
	EventBus.drag_started.connect(_on_drag_started)
	EventBus.drag_ended.connect(_on_drag_ended)

func _on_drag_started(_item) -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		hide()
	elif Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _on_drag_ended(_item, _success) -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		show()
	elif Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
