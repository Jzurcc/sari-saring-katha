class_name Customer
extends Area3D

signal satisfied
signal left
signal arrived(customer: Customer)

@export var movement_speed: float = 2.0
var target_position: Vector3
var is_waiting: bool = false
var desire: ItemData

@onready var bubble: Sprite3D = $Bubble
@onready var item_icon: Sprite3D = $Bubble/ItemIcon
@onready var request_label: Label3D = $Bubble/RequestLabel
@onready var body_sprite: Sprite3D = $Body

func _ready() -> void:
	bubble.visible = false

func setup(data: ItemData, target: Vector3) -> void:
	desire = data
	target_position = target
	if desire:
		if desire.texture:
			item_icon.texture = desire.texture
		request_label.text = desire.item_name

func _process(delta: float) -> void:
	if not is_waiting:
		global_position = global_position.move_toward(target_position, movement_speed * delta)
		if global_position.distance_to(target_position) < 0.1:
			 arrived_at_counter()

func arrived_at_counter() -> void:
	is_waiting = true
	bubble.visible = true
	arrived.emit(self)

func check_item(item: ItemData) -> bool:
	if item == desire:
		satisfy()
		return true
	else:
		reject()
		return false

func satisfy() -> void:
	bubble.modulate = Color.GREEN
	request_label.text = "Thanks!"
	await get_tree().create_timer(1.0).timeout
	satisfied.emit()
	queue_free()

func reject() -> void:
	bubble.modulate = Color.RED
	var original_text = request_label.text
	request_label.text = "No!"
	await get_tree().create_timer(1.0).timeout
	bubble.modulate = Color.WHITE
	request_label.text = original_text
