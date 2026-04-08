class_name Customer
extends Area3D

signal satisfied
@warning_ignore("unused_signal")
signal left
signal arrived(customer: Customer)
signal clicked(customer: Customer)

@export var movement_speed: float = 2.0
var target_position: Vector3
var is_waiting: bool = false
var desire: ItemData

@export var vertical_follow_factor: float = 1.0
@export var min_sprite_y: float = 1.3
@export var max_sprite_y: float = 2.4
var _base_sprite_y: float = 0.0

@onready var bubble: Sprite3D = $Bubble
@onready var item_icon: Sprite3D = $Bubble/ItemIcon
@onready var request_label: Label3D = $Bubble/RequestLabel
@onready var body_sprite: Sprite3D = $Body

func _ready() -> void:
	bubble.visible = false
	input_event.connect(_on_input_event)
	
	# Store the initial position of the body sprite for the vertical follow logic
	if body_sprite:
		_base_sprite_y = body_sprite.position.y

func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(self)

func setup(data: ItemData, target: Vector3) -> void:
	desire = data
	target_position = target
	if desire:
		if desire.texture:
			item_icon.texture = desire.texture
		request_label.text = desire.item_name

func _process(delta: float) -> void:
	# Vertically follow the camera pitch so the sprite doesn't skew downwards/upwards too much
	var camera := get_viewport().get_camera_3d()
	if camera and body_sprite:
		var pitch := camera.global_rotation.x
		# Applying the user requested logic: move normally as before, but clamped
		var target_y := _base_sprite_y - (pitch * vertical_follow_factor)
		body_sprite.position.y = clamp(target_y, min_sprite_y, max_sprite_y)

	# Early return optimization: skip processing when waiting at counter
	if is_waiting:
		return
	
	global_position = global_position.move_toward(target_position, movement_speed * delta)
	if global_position.distance_to(target_position) < 0.1:
		arrived_at_counter()

func arrived_at_counter() -> void:
	is_waiting = true
	bubble.visible = true
	arrived.emit(self)

func check_item(item: ItemData) -> bool:
	if item != null and desire != null and item.id == desire.id:
		satisfy()
		return true
	else:
		reject()
		return false

func satisfy() -> void:
	bubble.modulate = Color.GREEN
	request_label.text = "Thanks!"
	
	var tween = create_tween()
	var original_scale = body_sprite.scale
	var base_y = body_sprite.position.y
	
	# Jump up and stretch
	tween.tween_property(body_sprite, "scale", original_scale * Vector3(0.8, 1.2, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(body_sprite, "position:y", base_y + 0.3, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Trigger Particles precisely at the peak of the jump
	tween.tween_callback(func():
		var particles = get_node_or_null("HappyParticles")
		if particles and particles.has_method("play"):
			particles.play()
	)
	
	# Squish back down
	tween.tween_property(body_sprite, "scale", original_scale * Vector3(1.1, 0.9, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(body_sprite, "position:y", base_y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Recover to normal scale
	tween.tween_property(body_sprite, "scale", original_scale, 0.15).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	
	await get_tree().create_timer(2.0).timeout
	
	# Smooth fade out before freeing
	var fade_tween = create_tween()
	fade_tween.tween_property(body_sprite, "modulate:a", 0.0, 0.4)
	fade_tween.parallel().tween_property(bubble, "modulate:a", 0.0, 0.4)
	await fade_tween.finished
	
	satisfied.emit()
	queue_free()

func reject() -> void:
	bubble.modulate = Color.RED
	var original_text = request_label.text
	request_label.text = "No!"
	await get_tree().create_timer(1.0).timeout
	bubble.modulate = Color.WHITE
	request_label.text = original_text
