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

@export_group("Debug Tools (Temporary)")
## Adjust this value in the Remote Inspector while the game is running to resize the active customer.
@export var debug_customer_scale: float = 1.0:
	set(val):
		debug_customer_scale = val
		if not is_inside_tree():
			return
		var spawner = get_tree().get_first_node_in_group("customer_spawner")
		if spawner and is_instance_valid(spawner.current_customer):
			var customer = spawner.current_customer
			var body = customer.get_node_or_null("Body")
			var marker = customer.get_node_or_null("SpeechMarker")
			
			if body:
				body.scale = Vector3.ONE * val
				if marker and body.texture:
					var base_middle_y = (body.texture.get_height() / 2.0) * body.pixel_size
					marker.position.y = base_middle_y * val
					
			print("[DEBUG-SCALE] Character: ", customer.character_id, " | New Visual Scale: ", val)

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
		
	if is_instance_valid(target_node):
		await face_node(target_node, 0.4)
		_open_nokia()

## Makes the player camera smoothly rotate to look at a specific world position.
func face_pos(target_world_pos: Vector3, duration: float = 0.35) -> Signal:
	# Convert world target to local space relative to the player body.
	var target_local_pos = to_local(target_world_pos)
	
	# Calculate target angles
	var target_yaw = atan2(-target_local_pos.x, -target_local_pos.z)
	var horizontal_dist = Vector2(target_local_pos.x, target_local_pos.z).length()
	var target_pitch = clamp(atan2(target_local_pos.y - head.position.y, horizontal_dist), -PI/2, PI/2)
	
	# Shortest path wrapping: calculate the minimal difference and add it to current _yaw
	var yaw_diff = fposmod(target_yaw - _yaw + PI, TAU) - PI
	target_yaw = _yaw + yaw_diff

	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_yaw", target_yaw, duration)
	tween.tween_property(self, "_pitch", target_pitch, duration)
	
	return tween.finished

## Makes the player camera smoothly rotate to look at a node.
## If the node has a SpeechMarker child, it will aim for that instead.
func face_node(target: Node3D, duration: float = 0.35) -> Signal:
	if not is_instance_valid(target):
		return get_tree().process_frame # Return a dummy signal-like object
		
	var target_pos_vec = target.global_position
	var marker = target.get_node_or_null("SpeechMarker")
	if marker:
		target_pos_vec = marker.global_position
		
	return face_pos(target_pos_vec, duration)

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
