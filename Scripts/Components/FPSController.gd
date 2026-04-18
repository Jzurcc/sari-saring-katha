extends CharacterBody3D

@export var use_free_camera: bool = true
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var crouch_speed: float = 2.5
@export var movement_acceleration: float = 40.0
@export var movement_friction: float = 30.0
@export var mouse_sensitivity: float = 0.002

@export_group("Crouch")
@export var stand_head_y: float = 0.7       ## Head Y position when standing (matches scene default)
@export var crouch_head_y: float = 0.2      ## Head Y position when crouching (0.5 drop from stand)
@export var crouch_transition_speed: float = 10.0  ## Lerp speed for the crouch motion
@export var crouch_capsule_height: float = 1.6   ## CapsuleShape3D height while crouching (standing height is read from the shape at startup)

@export_group("Head Bobbing")
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.08

@export_group("Dynamic FOV")
@export var base_fov: float = 75.0
@export var fov_change: float = 1.5

@export_group("Camera Juiciness")
@export var idle_sway_amplitude: float = 0.015
@export var idle_sway_frequency: float = 1.0


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
					var full_height_y = body.texture.get_height() * body.pixel_size
					var ratio = customer.customer_data.speech_marker_height_ratio if customer.customer_data else 0.75
					marker.position.y = (full_height_y * ratio) * val
					
			if customer.customer_data:
				customer.customer_data.sprite_scale = val
				if not _is_syncing_debug:
					ResourceSaver.save(customer.customer_data, customer.customer_data.resource_path)
					print("[DEBUG-SCALE] Character: ", customer.customer_data.get_clean_id(), " | Saved Resource Scale: ", val)

## Adjust this value in the Remote Inspector to change and save the active customer's dialogue volume.
@export var debug_customer_volume: float = 0.0:
	set(val):
		debug_customer_volume = val
		if not is_inside_tree():
			return
		var spawner = get_tree().get_first_node_in_group("customer_spawner")
		if spawner and is_instance_valid(spawner.current_customer):
			var customer = spawner.current_customer
			if customer.customer_data:
				customer.customer_data.dialogue_blip_volume = val
				if not _is_syncing_debug:
					ResourceSaver.save(customer.customer_data, customer.customer_data.resource_path)
					print("[DEBUG-VOLUME] Character: ", customer.customer_data.get_clean_id(), " | Saved Dialogue Blip Volume: ", val)
				if AudioManager:
					AudioManager.play_dialogue_blip(customer.customer_data)

## Adjust this value in the Remote Inspector to change and save the active customer's speech marker position.
@export var debug_customer_marker_ratio: float = 0.75:
	set(val):
		debug_customer_marker_ratio = val
		if not is_inside_tree():
			return
		var spawner = get_tree().get_first_node_in_group("customer_spawner")
		if spawner and is_instance_valid(spawner.current_customer):
			var customer = spawner.current_customer
			var marker = customer.get_node_or_null("SpeechMarker")
			var body = customer.get_node_or_null("Body")
			
			if customer.customer_data:
				customer.customer_data.speech_marker_height_ratio = val
				if not _is_syncing_debug:
					ResourceSaver.save(customer.customer_data, customer.customer_data.resource_path)
					print("[DEBUG-RATIO] Character: ", customer.customer_data.get_clean_id(), " | Saved Speech Marker Ratio: ", val)
				
				if body and body.texture and marker:
					var full_height_y = body.texture.get_height() * body.pixel_size
					marker.position.y = (full_height_y * val) * customer.customer_data.sprite_scale

var _t_bob: float = 0.0
var _pitch: float = 0.0
var _yaw: float = 0.0

var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0

var _is_crouching: bool = false
var _stand_capsule_height: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _is_syncing_debug: bool = false

func _ready() -> void:
	if use_free_camera:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_pitch = camera.rotation.x
		_yaw = head.rotation.y
		camera.fov = base_fov
	# Cache the standing capsule height from the scene so we can lerp back to it
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		_stand_capsule_height = collision_shape.shape.height
	EventBus.request_camera_shake.connect(_on_camera_shake)
	EventBus.customer_spawned.connect(_on_customer_spawned_for_debug)

func _on_customer_spawned_for_debug(customer: Customer) -> void:
	if customer and customer.customer_data:
		_is_syncing_debug = true
		# Setting these triggered physical updates (visually) but the flag prevents redundant saves to disk
		debug_customer_scale = customer.customer_data.sprite_scale
		debug_customer_volume = customer.customer_data.dialogue_blip_volume
		debug_customer_marker_ratio = customer.customer_data.speech_marker_height_ratio
		_is_syncing_debug = false
		
		# Force the Godot property inspector to refresh its display
		notify_property_list_changed()

func _on_camera_shake(intensity: float, duration: float) -> void:
	if intensity > _shake_intensity * (_shake_timer / max(_shake_duration, 0.01)):
		_shake_intensity = intensity
	_shake_duration = duration
	_shake_timer = duration

func _input(event: InputEvent) -> void:
	if use_free_camera and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			_yaw -= event.relative.x * mouse_sensitivity
			_pitch -= event.relative.y * mouse_sensitivity
			_pitch = clamp(_pitch, -PI/2, PI/2)
			
			head.rotation.y = _yaw
			camera.rotation.x = _pitch
		

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
		# --- Crouch ---
		var was_crouching = _is_crouching
		_is_crouching = Input.is_key_pressed(KEY_CTRL)
		
		# Snap the capsule size immediately on state change — physics doesn't need to animate.
		# Only the head/camera lerps for smooth visual feel. This keeps both directions symmetric.
		if collision_shape and collision_shape.shape is CapsuleShape3D and _stand_capsule_height > 0.0:
			if _is_crouching != was_crouching:
				collision_shape.shape.height = crouch_capsule_height if _is_crouching else _stand_capsule_height
		
		var target_head_y = crouch_head_y if _is_crouching else stand_head_y
		head.position.y = lerp(head.position.y, target_head_y, crouch_transition_speed * delta)
		
		var current_speed = crouch_speed if _is_crouching else (sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed)
		
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
		
		# FOV is now fixed to base_fov (75)
		camera.fov = base_fov
		
		# Automatic Step Up for Stairs / Small Ledges
		if StoryManager.current_tier >= 10 and is_on_floor() and get_slide_collision_count() > 0 and input_dir.length_squared() > 0.01:
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


## Makes the player camera smoothly rotate to look at a specific world position.
func face_pos(target_world_pos: Vector3, duration: float = 0.4) -> Signal:
	# Convert world target to local space relative to the player body.
	var target_local_pos = to_local(target_world_pos)
	
	# Calculate target angles
	var target_yaw = atan2(-target_local_pos.x, -target_local_pos.z)
	var horizontal_dist = Vector2(target_local_pos.x, target_local_pos.z).length()
	var target_pitch = clamp(atan2(target_local_pos.y - head.position.y, horizontal_dist), -PI/2, PI/2)
	
	# Shortest path wrapping: calculate the minimal difference and add it to current _yaw
	var yaw_diff = fposmod(target_yaw - _yaw + PI, TAU) - PI
	target_yaw = _yaw + yaw_diff

	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_yaw", target_yaw, duration)
	tween.tween_property(self, "_pitch", target_pitch, duration)
	
	return tween.finished

## Makes the player camera smoothly rotate to look at a node.
## If the node has a SpeechMarker child, it will aim for that instead.
func face_node(target: Node3D, duration: float = 0.4) -> Signal:
	if not is_instance_valid(target):
		return get_tree().process_frame # Return a dummy signal-like object
		
	var target_pos_vec = target.global_position
	var marker = target.get_node_or_null("SpeechMarker")
	if marker:
		target_pos_vec = marker.global_position
		
	return face_pos(target_pos_vec, duration)

func _process(delta: float) -> void:
	# Ensure the nodes match our state variables (important for smooth tweening)
	head.rotation.y = _yaw
	camera.rotation.x = _pitch
	
	# --- Idle Sway (disabled) ---
	camera.rotation.z = lerp(camera.rotation.z, 0.0, delta * 5.0)

	# --- Camera Shake ---
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var decay = clamp(_shake_timer / _shake_duration, 0.0, 1.0)
		# Add a bit of randomness to h_offset and v_offset of the camera
		camera.h_offset = randf_range(-1.0, 1.0) * _shake_intensity * decay * 0.1
		camera.v_offset = randf_range(-1.0, 1.0) * _shake_intensity * decay * 0.1
	else:
		# Return to center
		camera.h_offset = lerp(camera.h_offset, 0.0, delta * 15.0)
		camera.v_offset = lerp(camera.v_offset, 0.0, delta * 15.0)
