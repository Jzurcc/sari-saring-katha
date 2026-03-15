class_name MainGame
extends Node3D

# --- Enums ---
enum CameraView { FRONT, BACK, LEFT, RIGHT }

# --- Constants ---
const CUSTOMER_SCENE: PackedScene = preload("res://Scenes/Customer.tscn")
const TRAY_SCENE: PackedScene = preload("res://Scenes/TransactionTray.tscn")
const DIALOGUE_BALLOON: PackedScene = preload("res://Scenes/UI/dialogue_balloon.tscn")

# Game state passed to dialogue so it can read {{item_name}}
var item_name: String = ""

# --- Public state ---
var money: int = 0
var current_customer: Customer = null

# --- Private state ---
var _current_view: CameraView = CameraView.FRONT
var _left_transform: Transform3D
var _right_transform: Transform3D
var _waiting_for_next_customer: bool = false
var _encounter_count: int = 0  # 0 = first meeting, 1+ = returning

# --- Day/Night cycle ---
var _day_night: DayNightCycle

# --- @onready node references ---
@onready var camera: Camera3D = $Camera3D
@onready var front_cam_pos: Marker3D = $FrontCamPos
@onready var back_cam_pos: Marker3D = $BackCamPos
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

	# --- Set up lighting for day/night cycle ---
	_setup_lighting()

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
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

	# Pre-compute the left/right side camera transforms from the front/back markers
	var center := (front_cam_pos.global_position + back_cam_pos.global_position) / 2.0
	var basis_left := front_cam_pos.global_transform.basis.rotated(Vector3.UP, PI / 2.0)
	var pos_left := center + (front_cam_pos.global_position - center).rotated(Vector3.UP, PI / 2.0)
	_left_transform = Transform3D(basis_left, pos_left)

	var basis_right := front_cam_pos.global_transform.basis.rotated(Vector3.UP, -PI / 2.0)
	var pos_right := center + (front_cam_pos.global_position - center).rotated(Vector3.UP, -PI / 2.0)
	_right_transform = Transform3D(basis_right, pos_right)

	held_item_label.visible = false
	spawn_customer()

# --- Lighting setup ---

func _setup_lighting() -> void:
	# Create DirectionalLight3D (sun)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.shadow_enabled = true
	sun.light_energy = 1.0
	sun.rotation_degrees = Vector3(-45, -30, 0)
	add_child(sun)

	# Create WorldEnvironment with procedural sky
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.3, 0.45, 0.75)
	sky_material.sky_horizon_color = Color(0.65, 0.75, 0.85)

	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	# Create and initialize DayNightCycle
	_day_night = DayNightCycle.new()
	_day_night.name = "DayNightCycle"
	add_child(_day_night)
	_day_night.setup(sun, world_env)
	_day_night.day_ended.connect(_on_day_ended)
	print("[MainGame] Lighting and DayNightCycle initialized")

# --- Camera ---

func switch_view(action: String) -> void:
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
		CameraView.LEFT:  target_transform = _left_transform
		CameraView.RIGHT: target_transform = _right_transform

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

	# Pick the desired item — Cigarettes for now, random among available in the future
	var desired_item: ItemData
	if _encounter_count == 0:
		# First encounter: Kuya Kap wants Cigarettes
		desired_item = load("res://Resources/items/food/Cigarettes.tres")
	else:
		# Returning encounters: random item from inventory (for debugging)
		var all_items := InventoryManager.get_all_items()
		if all_items.is_empty():
			desired_item = load("res://Resources/items/food/Cigarettes.tres")
		else:
			desired_item = all_items.pick_random()

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
	var dialogue_res = load("res://Dialogue/customer.dialogue")
	if dialogue_res == null:
		push_error("[DEBUG] FAILED to load customer.dialogue!")
		return

	# First encounter gets the full greeting, returning gets the short version
	var dialogue_title: String
	if _encounter_count == 0:
		dialogue_title = "customer_greeting"
	else:
		dialogue_title = "customer_returning"

	DialogueManager.show_dialogue_balloon_scene(DIALOGUE_BALLOON, dialogue_res, dialogue_title, [self])
	print("[DEBUG] _on_customer_arrived: showing '%s', item_name='%s'" % [dialogue_title, item_name])

func _on_customer_satisfied() -> void:
	var dialogue_res = load("res://Dialogue/customer.dialogue")
	DialogueManager.show_dialogue_balloon_scene(DIALOGUE_BALLOON, dialogue_res, "customer_satisfied", [self])
	_waiting_for_next_customer = true

func _on_dialogue_ended(_resource) -> void:
	if _waiting_for_next_customer:
		_waiting_for_next_customer = false
		_encounter_count += 1
		current_customer = null
		spawn_customer()

func _on_day_ended(day_number: int) -> void:
	print("[MainGame] Day %d ended!" % day_number)
	var dialogue_res = load("res://Dialogue/customer.dialogue")
	DialogueManager.show_dialogue_balloon_scene(DIALOGUE_BALLOON, dialogue_res, "day_ended", [self])

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

	# Advance day/night cycle regardless of correct or wrong
	if _day_night:
		_day_night.advance_time()

	if is_correct:
		# Correct item — earn money, customer satisfied dialogue will trigger via signal
		add_money(item.item_data.price)
		held_item_label.text = item.item_data.item_name
		held_item_label.visible = true

		if current_customer.item_icon and item.item_data.texture:
			current_customer.item_icon.texture = item.item_data.texture
			current_customer.item_icon.visible = true

		# For testing: infinite items. Return to inventory and shelf instead of destroying.
		if item.item_data:
			InventoryManager.return_item(item.item_data)
		item.return_to_start()
		# customer.check_item → satisfy() → satisfied signal → _on_customer_satisfied
	else:
		# Wrong item — return to inventory, show rejected dialogue
		print("[MainGame] Customer rejected '%s'" % gave)
		if item.item_data:
			InventoryManager.return_item(item.item_data)
		item.return_to_start()

		var dialogue_res = load("res://Dialogue/customer.dialogue")
		DialogueManager.show_dialogue_balloon_scene(DIALOGUE_BALLOON, dialogue_res, "customer_rejected", [self])

		# After rejection, move to next customer too
		_waiting_for_next_customer = true

	held_item_label.visible = false
