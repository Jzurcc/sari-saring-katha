class_name DraggableItem
extends Area3D

signal drag_started
signal drag_ended

@export var item_data: ItemData

var _is_dragging: bool = false
var _offset: Vector3
var _original_position: Vector3
var _drag_depth: float = 0.0

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
				start_drag(_camera, _event_position)

func _input(event: InputEvent) -> void:
	if _is_dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			end_drag()

func start_drag(camera: Camera3D, grab_position: Vector3) -> void:
	if _is_dragging: return
	_is_dragging = true
	_drag_depth = camera.global_position.distance_to(global_position)
	# Calculate offset to keep relative position to mouse
	_offset = global_position - grab_position
	
	drag_started.emit()

func end_drag() -> void:
	if not _is_dragging: return
	_is_dragging = false
	
	# Check for valid drop zone (Transaction Tray)
	var overlapped = get_overlapping_areas()
	var valid_drop = false
	
	for area in overlapped:
		if area.is_in_group("transaction_tray"):
			valid_drop = true
			if area.has_method("receive_item"):
				 area.receive_item(self)
			break
			
	if not valid_drop:
		return_to_start()
	
	drag_ended.emit()

func _process(_delta: float) -> void:
	if _is_dragging:
		var camera = get_viewport().get_camera_3d()
		if camera:
			var mouse_pos = get_viewport().get_mouse_position()
			var target_pos = camera.project_position(mouse_pos, _drag_depth)
			
			# We could add the offset here if we want exact grab point, 
			# but simple projection is often smooth enough for 2.5D
			global_position = target_pos

func return_to_start() -> void:
	var tween = create_tween()
	tween.tween_property(self, "global_position", _original_position, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
