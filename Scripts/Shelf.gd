class_name Shelf
extends StaticBody3D

signal pressed

@onready var area_3d: Area3D = $Area3D

func _ready() -> void:
	area_3d.input_event.connect(_on_input_event)

func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
