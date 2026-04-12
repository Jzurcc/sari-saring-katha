extends CharacterBody3D

@export var use_free_camera: bool = true
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var movement_acceleration: float = 40.0
@export var movement_friction: float = 30.0
@export var mouse_sensitivity: float = 0.002

@export_group("Head Bobbing")
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.08

@export_group("Dynamic FOV")
@export var base_fov: float = 75.0
@export var fov_change: float = 1.5

var _t_bob: float = 0.0
var _pitch: float = 0.0
var _yaw: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

func _ready() -> void:
	if use_free_camera:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_pitch = camera.rotation.x
		_yaw = head.rotation.y
		camera.fov = base_fov

func _input(event: InputEvent) -> void:
	if use_free_camera and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			_yaw -= event.relative.x * mouse_sensitivity
			_pitch -= event.relative.y * mouse_sensitivity
			_pitch = clamp(_pitch, -PI/2, PI/2)
			
			head.rotation.y = _yaw
			camera.rotation.x = _pitch
		
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_R:
				_rotate_to_nokia_and_open()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if use_free_camera and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var input_dir = Input.get_vector("look_left", "look_right", "look_front", "look_back")
		var forward = -head.global_transform.basis.z
		var right = head.global_transform.basis.x
		
		# Flatten the movement vertically
		forward.y = 0
		right.y = 0
		forward = forward.normalized()
		right = right.normalized()
		
		var direction = (right * input_dir.x + forward * (-input_dir.y)).normalized()
		var current_speed = sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
		
		if direction:
			velocity.x = move_toward(velocity.x, direction.x * current_speed, movement_acceleration * delta)
			velocity.z = move_toward(velocity.z, direction.z * current_speed, movement_acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, movement_friction * delta)
			velocity.z = move_toward(velocity.z, 0, movement_friction * delta)
			
		# Head Bobbing (Procedural Animation)
		_t_bob += delta * velocity.length() * float(is_on_floor())
		camera.position.y = sin(_t_bob * bob_frequency) * bob_amplitude
		camera.position.x = cos(_t_bob * bob_frequency / 2.0) * bob_amplitude
		
		# Dynamic FOV (Speed Sense)
		var clamped_velocity = clamp(velocity.length(), 0.5, sprint_speed * 2.0)
		var target_fov = base_fov + (fov_change * clamped_velocity)
		camera.fov = lerp(camera.fov, target_fov, 8.0 * delta)
		
		# Automatic Step Up for Stairs / Small Ledges
		if is_on_floor() and get_slide_collision_count() > 0 and input_dir.length_squared() > 0.01:
			var is_wall = false
			for i in range(get_slide_collision_count()):
				var collision = get_slide_collision(i)
				if collision.get_angle() > floor_max_angle:
					is_wall = true
					break
			
			if is_wall:
				var step_height := 0.35
				var test_transform = global_transform
				# 1. Test if we can move straight up without hitting the ceiling
				if not test_move(test_transform, Vector3.UP * step_height):
					test_transform.origin.y += step_height
					# 2. Test if we can move forward over the ledge
					if not test_move(test_transform, direction * 0.2):
						global_position.y += step_height
	else:
		velocity.x = move_toward(velocity.x, 0, movement_friction * delta)
		velocity.z = move_toward(velocity.z, 0, movement_friction * delta)
		
	move_and_slide()

## Smoothly rotate view to Nokia phone and then open it.
func _rotate_to_nokia_and_open() -> void:
	# Try to find the specific marker first, then fallback to the interaction region
	var target_node = get_tree().root.find_child("PhoneMarker3D", true, false)
	if not is_instance_valid(target_node):
		target_node = get_node_or_null("/root/MainGame/NokiaInteractable")
		
	if not is_instance_valid(target_node):
		return
		
	var target_world_pos = target_node.global_position
	# Convert world target to local space relative to the player body.
	# This ensures we 'look at' the point correctly even if the body is rotated.
	var target_local_pos = to_local(target_world_pos)
	
	# Calculate target yaw (local head rotation) and pitch (camera rotation)
	var target_yaw = atan2(-target_local_pos.x, -target_local_pos.z)
	var horizontal_dist = Vector2(target_local_pos.x, target_local_pos.z).length()
	# Account for head height in the pitch calculation
	var target_pitch = clamp(atan2(target_local_pos.y - head.position.y, horizontal_dist), -PI/2, PI/2)
	
	# Handle angle wrapping to take the shortest path around the circle
	_yaw = fposmod(_yaw + PI, TAU) - PI
	target_yaw = fposmod(target_yaw + PI, TAU) - PI
	if abs(target_yaw - _yaw) > PI:
		if target_yaw > _yaw: target_yaw -= TAU
		else: target_yaw += TAU

	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# Tween the internal state variables so mouse look stays synchronized
	tween.tween_property(self, "_yaw", target_yaw, 0.4)
	tween.tween_property(self, "_pitch", target_pitch, 0.4)
	
	# Update the actual nodes every frame during the tween
	tween.chain().tween_callback(_open_nokia)

func _process(_delta: float) -> void:
	# Ensure the nodes match our state variables (important for smooth tweening)
	head.rotation.y = _yaw
	camera.rotation.x = _pitch

## Triggers the Nokia UI interaction.
func _open_nokia() -> void:
	var nokia_region = get_node_or_null("/root/MainGame/NokiaInteractable")
	if not is_instance_valid(nokia_region) or not nokia_region.has_method("on_interact"):
		return
	
	nokia_region.on_interact()
