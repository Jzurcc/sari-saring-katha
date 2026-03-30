class_name MainGame
extends Node3D

# --- Enums ---
enum CameraView { FRONT, BACK, LEFT, RIGHT }

# --- Constants ---
const CUSTOMER_SCENE: PackedScene = preload("res://Scenes/Customer.tscn")
const TRAY_SCENE: PackedScene = preload("res://Scenes/TransactionTray.tscn")

# Game state passed to dialogue so it can read {{item_name}}
var item_name: String = ""

# --- Public state ---
var money: int = 0
var current_customer: Customer = null

# --- Free Camera ---
@export var use_free_camera: bool = true
var walk_speed: float = 5.0
var sprint_speed: float = 8.0
var movement_acceleration: float = 40.0
var movement_friction: float = 30.0
var mouse_sensitivity: float = 0.002

# Head Bobbing (Sine/Cosine Waves)
var bob_frequency: float = 2.0
var bob_amplitude: float = 0.08
var t_bob: float = 0.0

# Dynamic Field of View
var base_fov: float = 75.0
var fov_change: float = 1.5

var _pitch: float = 0.0
var _yaw: float = 0.0

# --- Debug ---
var _debug_show_collisions: bool = false

# --- Private state ---
var _current_view: CameraView = CameraView.FRONT
var _waiting_for_next_customer: bool = false
var _encounter_count: int = 0  # 0 = first meeting, 1+ = returning
var _last_hovered: Node = null

# --- Progression ---
const CUSTOMERS_PER_DAY: int = 5
var day: int = 1
var customers_served_today: int = 0

# --- @onready node references ---
@onready var player: CharacterBody3D = $Player
@onready var head: Node3D = $Player/Head
@onready var camera: Camera3D = $Player/Head/Camera3D
@onready var front_cam_pos: Marker3D = $FrontCamPos
@onready var back_cam_pos: Marker3D = $BackCamPos
@onready var left_cam_pos: Marker3D = $LeftCamPos
@onready var right_cam_pos: Marker3D = $RightCamPos
@onready var money_label: Label = $CanvasLayer/MoneyLabel
@onready var held_item_label: Label = $CanvasLayer/HeldItemLabel
@onready var customer_spawn_pos: Marker3D = $CustomerSpawnPos
@onready var customer_target_pos: Marker3D = $CustomerTargetPos
@onready var tray: TransactionTray

# Legacy UI — disabled but kept for future use
@onready var item_selection_ui: ItemSelectionUI = $"ItemSelectionUI"
@onready var confirmation_popup: ConfirmationPopup = $"ConfirmationPopup"

# --- Lifecycle ---

func _ready() -> void:
	# Disable legacy UI (kept for future use)
	if item_selection_ui:
		item_selection_ui.visible = false
		item_selection_ui.process_mode = Node.PROCESS_MODE_DISABLED
	if confirmation_popup:
		confirmation_popup.visible = false
		confirmation_popup.process_mode = Node.PROCESS_MODE_DISABLED

	# Fix camera FOV once scene is fully loaded
	await get_tree().process_frame
	if camera and camera.fov != 75:
		camera.fov = 75.0

	# Auto-collision script has been removed as per user request.
	# Please set up collisions manually in the Godot Editor.

	# Setup Free Camera Mode defaults
	if use_free_camera:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		$CanvasLayer/CrosshairContainer.show()
		_pitch = 0.0
		_yaw = 0.0
		if head:
			head.rotation.y = _yaw
		if camera:
			camera.rotation.x = _pitch
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		$CanvasLayer/CrosshairContainer.hide()

	# Find the TransactionTray anywhere in the scene tree
	var tray_nodes := get_tree().get_nodes_in_group("transaction_tray")
	if tray_nodes.size() > 0:
		tray = tray_nodes[0] as TransactionTray
		print("[MainGame] Found TransactionTray in scene: ", tray.get_path())
	else:
		# Fallback: instantiate one
		tray = TRAY_SCENE.instantiate()
		add_child(tray)
		tray.global_position = front_cam_pos.global_position + Vector3(0, -1, -2)
		print("[MainGame] No TransactionTray found, created one at ", tray.global_position)

	# Connect signals
	InputManager.view_requested.connect(switch_view)
	tray.item_placed.connect(_on_item_placed)
	Dialogic.timeline_ended.connect(_on_dialogue_ended)


	held_item_label.visible = false
	spawn_customer()

func _process(_delta: float) -> void:
	if not _debug_show_collisions:
		return
	_draw_all_collision_shapes(get_tree().root)

func _draw_all_collision_shapes(node: Node) -> void:
	if node is CollisionShape3D:
		var cs: CollisionShape3D = node
		if cs.shape == null or not cs.visible:
			return
		var xform: Transform3D = cs.global_transform
		var color := Color(0.0, 1.0, 0.3, 0.8)
		if cs.get_parent() is CharacterBody3D:
			color = Color(0.2, 0.6, 1.0, 0.9)  # Blue for player
		elif cs.get_parent() is Area3D:
			color = Color(1.0, 1.0, 0.0, 0.8)  # Yellow for areas/items

		if cs.shape is BoxShape3D:
			var box: BoxShape3D = cs.shape
			DebugDraw3D.draw_box(xform.origin, xform.basis.get_rotation_quaternion(), box.size, color)
		elif cs.shape is CapsuleShape3D:
			var cap: CapsuleShape3D = cs.shape
			DebugDraw3D.draw_capsule(xform.origin, xform.basis.get_rotation_quaternion(), cap.radius, cap.height, color)
		elif cs.shape is SphereShape3D:
			var sph: SphereShape3D = cs.shape
			DebugDraw3D.draw_sphere(xform.origin, sph.radius, color)
		elif cs.shape is ConcavePolygonShape3D:
			var faces = cs.shape.get_faces()
			var lines = PackedVector3Array()
			for i in range(0, faces.size(), 3):
				var a: Vector3 = xform * faces[i]
				var b: Vector3 = xform * faces[i+1]
				var c: Vector3 = xform * faces[i+2]
				lines.append(a)
				lines.append(b)
				lines.append(b)
				lines.append(c)
				lines.append(c)
				lines.append(a)
			if lines.size() > 0:
				DebugDraw3D.draw_lines(lines, color)
		elif cs.shape is WorldBoundaryShape3D:
			# Just mark the position with a cross for infinite planes
			DebugDraw3D.draw_position(xform, color)
		elif cs.shape is ConvexPolygonShape3D:
			DebugDraw3D.draw_position(xform, color)

	for child in node.get_children():
		_draw_all_collision_shapes(child)

# --- Camera / Input ---

func _input(event: InputEvent) -> void:
	# F1 toggles collision shape debug visualization
	if event is InputEventKey and event.keycode == KEY_F1 and event.pressed and not event.is_echo():
		_debug_show_collisions = !_debug_show_collisions
		DebugDraw2D.set_text("Collision Debug", "ON" if _debug_show_collisions else "OFF")
		return

	# O toggles the view modes
	if event is InputEventKey and event.keycode == KEY_O and event.pressed and not event.is_echo():
		use_free_camera = !use_free_camera
		if use_free_camera:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			$CanvasLayer/CrosshairContainer.show()
			camera.position = Vector3.ZERO
			head.rotation = Vector3(0, _yaw, 0)
			camera.rotation = Vector3(_pitch, 0, 0)
			camera.fov = base_fov
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			$CanvasLayer/CrosshairContainer.hide()
			switch_view("look_front")
		return

	# V toggles mouse freedom while retaining FPS mode
	if event is InputEventKey and event.keycode == KEY_V and event.pressed and not event.is_echo():
		if use_free_camera:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				$CanvasLayer/CrosshairContainer.hide()
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				$CanvasLayer/CrosshairContainer.show()
				camera.position = Vector3.ZERO
				head.rotation = Vector3(0, _yaw, 0)
				camera.rotation = Vector3(_pitch, 0, 0)
		return

	if use_free_camera and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			_yaw -= event.relative.x * mouse_sensitivity
			_pitch -= event.relative.y * mouse_sensitivity
			_pitch = clamp(_pitch, -PI/2, PI/2)
			
			head.rotation.y = _yaw
			camera.rotation.x = _pitch
		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				# If we aren't already dragging something, interact with it.
				if not DragManager._is_dragging:
					get_viewport().set_input_as_handled()
					if is_instance_valid(_last_hovered) and _last_hovered.has_method("on_interact"):
						_last_hovered.on_interact()
					else:
						DragManager.fps_try_interact()

func _physics_process(delta: float) -> void:
	# Add the gravity
	if not player.is_on_floor():
		player.velocity += player.get_gravity() * delta

	if use_free_camera and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var center := get_viewport().get_visible_rect().size / 2.0
		var ray_origin := camera.project_ray_origin(center)
		var ray_dir := camera.project_ray_normal(center)

		var query := PhysicsRayQueryParameters3D.new()
		query.from = ray_origin
		query.to = ray_origin + ray_dir * 10.0
		query.collide_with_areas = true
		query.collide_with_bodies = false

		var result := get_world_3d().direct_space_state.intersect_ray(query)
		var current_hovered = null
		if result:
			current_hovered = result.get("collider")
		
		# Modular interaction hover
		if current_hovered != _last_hovered:
			if is_instance_valid(_last_hovered) and _last_hovered.has_method("on_hover"):
				_last_hovered.on_hover(false)
			if current_hovered and current_hovered.has_method("on_hover"):
				current_hovered.on_hover(true)
			_last_hovered = current_hovered
		
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
			player.velocity.x = move_toward(player.velocity.x, direction.x * current_speed, movement_acceleration * delta)
			player.velocity.z = move_toward(player.velocity.z, direction.z * current_speed, movement_acceleration * delta)
		else:
			player.velocity.x = move_toward(player.velocity.x, 0, movement_friction * delta)
			player.velocity.z = move_toward(player.velocity.z, 0, movement_friction * delta)
			
		# Head Bobbing (Procedural Animation)
		t_bob += delta * player.velocity.length() * float(player.is_on_floor())
		camera.position.y = sin(t_bob * bob_frequency) * bob_amplitude
		camera.position.x = cos(t_bob * bob_frequency / 2.0) * bob_amplitude
		
		# Dynamic FOV (Speed Sense)
		var clamped_velocity = clamp(player.velocity.length(), 0.5, sprint_speed * 2.0)
		var target_fov = base_fov + (fov_change * clamped_velocity)
		camera.fov = lerp(camera.fov, target_fov, 8.0 * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, movement_friction * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, movement_friction * delta)
		
		# We don't need to try and manually lerp it down here; switch_view handles the position
		pass
	player.move_and_slide()
	
	# --- Automatic Step Up for Stairs / Small Ledges ---
	if use_free_camera and player.is_on_floor() and player.get_slide_collision_count() > 0:
		var input_dir = Input.get_vector("look_left", "look_right", "look_front", "look_back")
		if input_dir.length_squared() > 0.01:
			var is_wall = false
			for i in range(player.get_slide_collision_count()):
				var collision = player.get_slide_collision(i)
				if collision.get_angle() > player.floor_max_angle:
					is_wall = true
					break
			
			if is_wall:
				var forward = -head.global_transform.basis.z
				var right = head.global_transform.basis.x
				forward.y = 0
				right.y = 0
				forward = forward.normalized()
				right = right.normalized()
				var direction = (right * input_dir.x + forward * (-input_dir.y)).normalized()
				
				var step_height := 0.35
				var test_transform = player.global_transform
				# 1. Test if we can move straight up without hitting the ceiling
				if not player.test_move(test_transform, Vector3.UP * step_height):
					test_transform.origin.y += step_height
					# 2. Test if we can move forward over the ledge
					if not player.test_move(test_transform, direction * 0.2):
						player.global_position.y += step_height

func switch_view(action: String) -> void:
	if use_free_camera:
		return

	var target_view: CameraView = _current_view

	match action:
		"look_front":
			target_view = CameraView.FRONT
		"look_left":
			match _current_view:
				CameraView.FRONT: target_view = CameraView.LEFT
				CameraView.LEFT:  target_view = CameraView.BACK
				CameraView.BACK:  target_view = CameraView.RIGHT
				CameraView.RIGHT: target_view = CameraView.FRONT
		"look_right":
			match _current_view:
				CameraView.FRONT: target_view = CameraView.RIGHT
				CameraView.RIGHT: target_view = CameraView.BACK
				CameraView.BACK:  target_view = CameraView.LEFT
				CameraView.LEFT:  target_view = CameraView.FRONT
		"look_back":
			match _current_view:
				CameraView.FRONT: target_view = CameraView.BACK
				CameraView.BACK:  target_view = CameraView.FRONT
				CameraView.LEFT:  target_view = CameraView.RIGHT
				CameraView.RIGHT: target_view = CameraView.LEFT

	if _current_view == target_view:
		return
	_current_view = target_view

	var target_transform: Transform3D
	match target_view:
		CameraView.FRONT: target_transform = front_cam_pos.global_transform
		CameraView.BACK:  target_transform = back_cam_pos.global_transform
		CameraView.LEFT:  target_transform = left_cam_pos.global_transform
		CameraView.RIGHT: target_transform = right_cam_pos.global_transform

	# Tween via quaternion to avoid euler angle wrap-around
	var local_target: Transform3D = (camera.get_parent() as Node3D).global_transform.affine_inverse() * target_transform
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(camera, "position", local_target.origin, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "quaternion", local_target.basis.get_rotation_quaternion(), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

# --- Customer lifecycle ---

func spawn_customer() -> void:
	if current_customer:
		print("[DEBUG] spawn_customer: already have a customer, skipping")
		return

	print("[DEBUG] spawn_customer: waiting 2s then spawning...")
	await get_tree().create_timer(2.0).timeout

	# Always request Cigarettes for all encounters (for testing)
	var desired_item: ItemData = load("res://Resources/items/food/Cigarettes.tres")

	if not desired_item:
		push_error("[MainGame] Failed to load item for customer!")
		return

	var customer: Customer = CUSTOMER_SCENE.instantiate()
	add_child(customer)
	customer.global_position = customer_spawn_pos.global_position
	customer.setup(desired_item, customer_target_pos.global_position)

	current_customer = customer
	current_customer.satisfied.connect(_on_customer_satisfied)
	if not customer.is_connected("arrived", _on_customer_arrived):
		customer.arrived.connect(_on_customer_arrived)
	print("[DEBUG] spawn_customer: encounter #%d, wants '%s'" % [_encounter_count, desired_item.item_name])

func _on_customer_arrived(customer: Customer) -> void:
	item_name = customer.desire.item_name if customer.desire else "something"
	InventoryManager.current_item_name = item_name

	# First encounter gets the full greeting, returning gets the short version
	var timeline_path: String
	if _encounter_count == 0:
		timeline_path = "res://Dialogue/customer_greeting.dtl"
	else:
		timeline_path = "res://Dialogue/customer_returning.dtl"

	if Dialogic.current_timeline == null:
		Dialogic.start(timeline_path)
	print("[DEBUG] _on_customer_arrived: starting '%s', item_name='%s'" % [timeline_path, item_name])

func _on_customer_satisfied() -> void:
	_waiting_for_next_customer = true
	if Dialogic.current_timeline == null:
		Dialogic.start("res://Dialogue/customer_satisfied.dtl")

func _on_dialogue_ended() -> void:
	if _waiting_for_next_customer:
		_waiting_for_next_customer = false
		_encounter_count += 1
		current_customer = null
		spawn_customer()

func _on_day_ended(day_number: int) -> void:
	print("[MainGame] Day %d ended!" % day_number)
	if Dialogic.current_timeline == null:
		Dialogic.start("res://Dialogue/day_ended.dtl")

# --- Money ---

func add_money(amount: int) -> void:
	money += amount
	money_label.text = "Peso: " + str(money)

# --- Item → Tray → Customer delivery (unified flow) ---

func _on_item_placed(item: DraggableItem) -> void:
	print("[MainGame] _on_item_placed called! item_data=", item.item_data)

	if current_customer == null or not current_customer.is_waiting:
		print("[MainGame] No customer waiting, returning item")
		if item.item_data:
			InventoryManager.return_item(item.item_data)
		item.return_to_start()
		return

	var customer_want := current_customer.desire.item_name if current_customer.desire else "?"
	var gave := item.item_data.item_name if item.item_data else "?"
	print("[MainGame] Customer wants '%s', got '%s'" % [customer_want, gave])

	var is_correct := current_customer.check_item(item.item_data)
	print("[MainGame] check_item result: ", is_correct)

	# Advance progression
	customers_served_today += 1
	if customers_served_today >= CUSTOMERS_PER_DAY:
		customers_served_today = 0
		_on_day_ended(day)
		day += 1

	if is_correct:
		# Correct item — earn money, customer satisfied dialogue will trigger via signal
		add_money(item.item_data.price)
		held_item_label.text = item.item_data.item_name
		held_item_label.visible = true

		if current_customer.item_icon and item.item_data.texture:
			current_customer.item_icon.texture = item.item_data.texture
			current_customer.item_icon.visible = true

		# Infinite items for testing: restock and return to shelf
		if item.item_data:
			InventoryManager.return_item(item.item_data)
		item.show_visuals()  # Re-show the 3D sprite before moving back
		item.return_to_start()
		# customer.check_item → satisfy() → satisfied signal → _on_customer_satisfied
	else:
		# Wrong item — return to inventory, show rejected dialogue
		print("[MainGame] Customer rejected '%s'" % gave)
		if item.item_data:
			InventoryManager.return_item(item.item_data)
		item.return_to_start()

		if Dialogic.current_timeline == null:
			Dialogic.start("res://Dialogue/customer_rejected.dtl")

		# After rejection, move to next customer too
		_waiting_for_next_customer = true

	held_item_label.visible = false
