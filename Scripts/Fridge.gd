class_name Fridge
extends Area3D

@onready var door: Node3D = $DoorPivot
@onready var interior_light: OmniLight3D = get_node_or_null("InteriorLight")
@onready var mist: Node3D = get_node_or_null("ColdMist")

var is_open: bool = false

func _ready() -> void:
	if mist and mist is CPUParticles3D:
		# Override any scene-locked properties to ensure it drifts up and stays around longer
		mist.direction = Vector3.BACK
		mist.spread = 90.0
		mist.gravity = Vector3(0, 0.15, 0)
		mist.lifetime = 4.0
		mist.one_shot = false
		mist.initial_velocity_min = 0.1
		mist.initial_velocity_max = 0.4
		mist.damping_min = 0.2
		mist.damping_max = 0.5
		
		# Give it the smooth pulse/fade curve
		var curves = Curve.new()
		curves.add_point(Vector2(0, 0.2))
		curves.add_point(Vector2(0.3, 1.2))
		curves.add_point(Vector2(0.7, 1.2))
		curves.add_point(Vector2(1, 0))
		mist.scale_amount_curve = curves

func on_interact() -> void:
	toggle_open()

func on_hover(_is_hovered: bool) -> void:
	pass

func _input_event(_camera: Camera3D, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		on_interact()

func toggle_open() -> void:
	is_open = !is_open
	var target_rot := Vector3(0, deg_to_rad(-90), 0) if is_open else Vector3.ZERO

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(door, "rotation", target_rot, 0.5).set_trans(Tween.TRANS_CUBIC)
	
	if interior_light:
		var target_energy = 1.0 if is_open else 0.0
		tween.tween_property(interior_light, "light_energy", target_energy, 0.5)
		
	if mist:
		if is_open:
			mist.rate_over_time = 50.0
			if mist.has_method("play"):
				mist.play()
		else:
			if mist.has_method("stop"):
				mist.stop()
