class_name DraggableItem
extends Area3D

signal drag_started
signal drag_ended

@export var item_data: ItemData

var _original_position: Vector3

@onready var sprite: Sprite3D = $Sprite3D
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var label: Label3D = $Label3D

func _ready() -> void:
	_original_position = global_position
	if item_data:
		setup(item_data)

func setup(data: ItemData) -> void:
	item_data = data
	if item_data:
		if item_data.texture:
			sprite.texture = item_data.texture
		if label:
			label.text = "%s\nP%d" % [item_data.item_name, item_data.price]

func _input_event(_camera: Camera3D, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var drag_manager = get_node_or_null("/root/DragManager")
				if drag_manager:
					drag_manager.start_drag(self, sprite.texture)

func _on_drag_started_by_manager() -> void:
	sprite.hide()
	label.hide()
	drag_started.emit()

func _on_drag_cancelled_by_manager() -> void:
	show_visuals()
	drag_ended.emit()

func show_visuals() -> void:
	sprite.show()
	if label: label.show()

func return_to_start() -> void:
	show_visuals()
	var tween = create_tween()
	tween.tween_property(self , "global_position", _original_position, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
