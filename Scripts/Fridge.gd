extends Area3D

@onready var door: Node3D = $DoorPivot
var is_open: bool = false

func _input_event(_camera: Camera3D, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        toggle_open()

func toggle_open() -> void:
    is_open = !is_open
    var target_rot = Vector3(0, deg_to_rad(-90), 0) if is_open else Vector3.ZERO
    
    var tween = create_tween()
    tween.tween_property(door, "rotation", target_rot, 0.5).set_trans(Tween.TRANS_CUBIC)
