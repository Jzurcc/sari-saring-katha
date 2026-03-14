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

	# Load Cigarettes specifically for Kuya Kap
	var cigarettes: ItemData = load("res://Resources/items/food/Cigarettes.tres")
	if not cigarettes:
		push_error("[MainGame] Failed to load Cigarettes.tres!")
		return

	var customer: Customer = CUSTOMER_SCENE.instantiate()
	add_child(customer)
	customer.global_position = customer_spawn_pos.global_position
	customer.setup(cigarettes, customer_target_pos.global_position)

	current_customer = customer
	current_customer.satisfied.connect(_on_customer_satisfied)
	if not customer.is_connected("arrived", _on_customer_arrived):
		customer.arrived.connect(_on_customer_arrived)
	print("[DEBUG] spawn_customer: customer wants '", customer.desire.item_name, "'")

func _on_customer_arrived(customer: Customer) -> void:
	print("[DEBUG] _on_customer_arrived: customer arrived! desire=", customer.desire)
	item_name = customer.desire.item_name if customer.desire else "something"
	var dialogue_res = load("res://Dialogue/customer.dialogue")
	if dialogue_res == null:
		push_error("[DEBUG] FAILED to load customer.dialogue!")
		return
	DialogueManager.show_dialogue_balloon_scene(DIALOGUE_BALLOON, dialogue_res, "customer_greeting", [self])

func _on_customer_satisfied() -> void:
	var dialogue_res = load("res://Dialogue/customer.dialogue")
	DialogueManager.show_dialogue_balloon_scene(DIALOGUE_BALLOON, dialogue_res, "customer_satisfied", [self])
	_waiting_for_next_customer = true

func _on_dialogue_ended(_resource) -> void:
	if _waiting_for_next_customer:
		_waiting_for_next_customer = false
		current_customer = null
		spawn_customer()

# --- Money ---

func add_money(amount: int) -> void:
	money += amount
	money_label.text = "Peso: " + str(money)

# --- Item → Tray → Customer delivery (unified flow) ---

func _on_item_placed(item: DraggableItem) -> void:
	print("[MainGame] _on_item_placed called! item=", item, " item_data=", item.item_data)
	print("[MainGame] current_customer=", current_customer, " is_waiting=", current_customer.is_waiting if current_customer else "N/A")

	if current_customer == null or not current_customer.is_waiting:
		print("[MainGame] No customer waiting, returning item")
		if item.item_data:
			InventoryManager.return_item(item.item_data)
		item.return_to_start()
		return

	print("[MainGame] Customer wants: '", current_customer.desire.item_name, "', got: '", item.item_data.item_name if item.item_data else "null", "'")
	var is_correct := current_customer.check_item(item.item_data)
	print("[MainGame] check_item result: ", is_correct)
	if is_correct:
		# Correct item — earn money, show satisfied dialogue
		add_money(item.item_data.price)
		held_item_label.text = item.item_data.item_name
		held_item_label.visible = true

		if current_customer.item_icon and item.item_data.texture:
			current_customer.item_icon.texture = item.item_data.texture
			current_customer.item_icon.visible = true

		item.queue_free()
		# Note: customer.check_item → satisfy() → satisfied signal → _on_customer_satisfied
		# which shows the satisfied dialogue and sets _waiting_for_next_customer
	else:
		# Wrong item — show rejected dialogue, return item to inventory & shelf
		print("[MainGame] Customer rejected '", item.item_data.item_name, "'")
		if item.item_data:
			InventoryManager.return_item(item.item_data)
		item.return_to_start()

		var dialogue_res = load("res://Dialogue/customer.dialogue")
		DialogueManager.show_dialogue_balloon_scene(DIALOGUE_BALLOON, dialogue_res, "customer_rejected", [self])

	held_item_label.visible = false
