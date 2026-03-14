class_name MainGame
extends Node3D

# --- Signals ---
# (none — MainGame is the top-level orchestrator and communicates downward)

# --- Enums ---
enum CameraView { FRONT, BACK, LEFT, RIGHT }

# --- Constants ---
const CUSTOMER_SCENE: PackedScene = preload("res://Scenes/Customer.tscn")
const TRAY_SCENE: PackedScene = preload("res://Scenes/TransactionTray.tscn")
const DIALOGUE_BALLOON: PackedScene = preload("res://Scenes/UI/dialogue_balloon.tscn")

# Game state passed to dialogue so it can read {{item_name}}
var item_name: String = ""

# --- Exported / configurable ---
# (none in this scene — all children are scene-defined)

# --- Public state ---
var money: int = 0
var held_item: ItemData = null
var current_customer: Customer = null

# --- Private state ---
var _current_view: CameraView = CameraView.FRONT
var _left_transform: Transform3D
var _right_transform: Transform3D
var _waiting_for_next_customer: bool = false
var _items: Array[ItemData] = []

# --- @onready node references ---
@onready var camera: Camera3D = $Camera3D
@onready var front_cam_pos: Marker3D = $FrontCamPos
@onready var back_cam_pos: Marker3D = $BackCamPos
@onready var money_label: Label = $CanvasLayer/MoneyLabel
@onready var held_item_label: Label = $CanvasLayer/HeldItemLabel
@onready var customer_spawn_pos: Marker3D = $CustomerSpawnPos
@onready var customer_target_pos: Marker3D = $CustomerTargetPos
# dialogue_ui removed — now using DialogueManager balloon system
@onready var item_selection_ui: ItemSelectionUI = $"ItemSelectionUI"
@onready var confirmation_popup: ConfirmationPopup = $"ConfirmationPopup"
@onready var tray: TransactionTray

# --- Item loading ---

func _get_items_from_folder(folder_path: String) -> Array[ItemData]:
	var items: Array[ItemData] = []
	var dir := DirAccess.open(folder_path)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var item: Resource = load(folder_path + "/" + file_name)
				if item is ItemData:
					items.append(item)
			file_name = dir.get_next()
		dir.list_dir_end()
	return items

func _load_all_items() -> void:
	var base_path := "res://Resources/items"
	var base_dir := DirAccess.open(base_path)
	if base_dir:
		base_dir.list_dir_begin()
		var subdir := base_dir.get_next()
		while subdir != "":
			if base_dir.current_is_dir() and subdir != "." and subdir != "..":
				_items.append_array(_get_items_from_folder(base_path + "/" + subdir))
			subdir = base_dir.get_next()
		base_dir.list_dir_end()

	# Fallback: load the legacy item if folder scan yielded nothing
	if _items.is_empty():
		var sardines: Resource = load("res://Resources/items/food/Sardines.tres")
		if sardines is ItemData:
			_items.append(sardines)

# --- Lifecycle ---

func _ready() -> void:
	_load_all_items()
	print("Loaded ", _items.size(), " items dynamically")

	if item_selection_ui:
		item_selection_ui.set_item_count(33)

	# Fix camera FOV once scene is fully loaded
	await get_tree().process_frame
	if camera and camera.fov != 75:
		camera.fov = 75.0

	# Find or instantiate the TransactionTray
	var tray_node := get_node_or_null("FrontStore/TransactionTray")
	if tray_node:
		tray = tray_node
	else:
		tray = TRAY_SCENE.instantiate()
		var front_store := get_node_or_null("FrontStore")
		if front_store:
			front_store.add_child(tray)
		else:
			add_child(tray)
			tray.global_position = front_cam_pos.global_position + Vector3(0, -1, -2)

	# Connect signals — "call down, signal up" pattern
	InputManager.view_requested.connect(switch_view)
	tray.item_placed.connect(_on_item_placed)

	# Connect to Dialogue Manager's dialogue_ended to drive customer flow
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

	var shelf_node := get_node_or_null("Shelf")
	if shelf_node and shelf_node.has_signal("pressed"):
		shelf_node.pressed.connect(_on_shelf_pressed)

	if item_selection_ui:
		item_selection_ui.item_selected.connect(_on_item_selected)
		print("ItemSelectionUI signal connected")
	else:
		print("ERROR: ItemSelectionUI is null!")
		push_error("MainGame: ItemSelectionUI node not found!")

	print("ConfirmationPopup node:", confirmation_popup)
	if confirmation_popup:
		confirmation_popup.confirmed.connect(_on_confirmation_confirmed)
		print("ConfirmationPopup signal connected!")
	else:
		print("ERROR: ConfirmationPopup is null!")
		push_error("MainGame: ConfirmationPopup node not found!")

	# Pre-compute the left/right side camera transforms from the front/back markers
	var center := (front_cam_pos.global_position + back_cam_pos.global_position) / 2.0
	var basis_left := front_cam_pos.global_transform.basis.rotated(Vector3.UP, PI / 2.0)
	var pos_left := center + (front_cam_pos.global_position - center).rotated(Vector3.UP, PI / 2.0)
	_left_transform = Transform3D(basis_left, pos_left)

	var basis_right := front_cam_pos.global_transform.basis.rotated(Vector3.UP, -PI / 2.0)
	var pos_right := center + (front_cam_pos.global_position - center).rotated(Vector3.UP, -PI / 2.0)
	_right_transform = Transform3D(basis_right, pos_right)

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

	var customer: Customer = CUSTOMER_SCENE.instantiate()
	add_child(customer)
	customer.global_position = customer_spawn_pos.global_position
	customer.setup(_items.pick_random(), customer_target_pos.global_position)

	current_customer = customer
	current_customer.satisfied.connect(_on_customer_satisfied)
	if not customer.is_connected("arrived", _on_customer_arrived):
		customer.arrived.connect(_on_customer_arrived)
	print("[DEBUG] spawn_customer: customer spawned, 'arrived' signal connected? ", customer.is_connected("arrived", _on_customer_arrived))

func _on_customer_arrived(customer: Customer) -> void:
	print("[DEBUG] _on_customer_arrived: customer arrived! desire=", customer.desire)
	# Set game state so the .dialogue file can read {{item_name}}
	item_name = customer.desire.item_name if customer.desire else "something"
	# Load the dialogue resource and show the balloon with the greeting title
	var dialogue_res = load("res://Dialogue/customer.dialogue")
	print("[DEBUG] _on_customer_arrived: dialogue_res=", dialogue_res, " item_name=", item_name)
	if dialogue_res == null:
		push_error("[DEBUG] FAILED to load customer.dialogue!")
		return
	DialogueManager.show_dialogue_balloon_scene(DIALOGUE_BALLOON, dialogue_res, "customer_greeting", [self])
	print("[DEBUG] _on_customer_arrived: show_dialogue_balloon_scene called")

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

# --- Shelf / Item selection flow ---

func _on_shelf_pressed() -> void:
	item_selection_ui.show_selection()

func _on_item_selected(index: int) -> void:
	if not confirmation_popup:
		print("ERROR: confirmation_popup is null in _on_item_selected!")
		push_error("MainGame: confirmation_popup is null in _on_item_selected!")
		return
	var texture: Texture2D = load("res://Assets/items/%d.png" % (index + 1))
	confirmation_popup.show_confirmation(index, texture)
	print("Showing confirmation for item:", index)

func _on_confirmation_confirmed(item_index: int) -> void:
	print("DEBUG: _on_confirmation_confirmed called with item_index:", item_index)
	var price: int = 20  # Fixed price for MVP
	held_item_label.text = "Holding Item #" + str(item_index + 1)
	held_item_label.visible = true
	_deliver_item_to_customer_with_price(price)

func _on_confirmation_cancelled() -> void:
	item_selection_ui.show_selection()

# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	# Keyboard shortcut to open item drawer
	if event.is_action_pressed("open_drawer"):
		if item_selection_ui:
			item_selection_ui.show_selection()

	# Click on customer to deliver held item
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if held_item != null and current_customer != null and camera:
			var from := camera.project_ray_origin(event.position)
			var to := from + camera.project_ray_normal(event.position) * 100.0
			var query := PhysicsRayQueryParameters3D.create(from, to)
			var result := get_world_3d().direct_space_state.intersect_ray(query)
			if result and result.collider == current_customer:
				_deliver_item_to_customer()

# --- Delivery ---

func _deliver_item_to_customer() -> void:
	if current_customer == null or held_item == null:
		return

	var is_correct := current_customer.check_item(held_item)
	var price := held_item.price
	add_money(price)

	if current_customer.item_icon and held_item.texture:
		current_customer.item_icon.texture = held_item.texture

	var dialogue_res = load("res://Dialogue/customer.dialogue")
	if is_correct:
		DialogueManager.show_dialogue_balloon_scene(DIALOGUE_BALLOON, dialogue_res, "customer_satisfied", [self])
	else:
		DialogueManager.show_dialogue_balloon_scene(DIALOGUE_BALLOON, dialogue_res, "customer_rejected", [self])

	held_item = null
	held_item_label.visible = false

func _deliver_item_to_customer_with_price(price: int) -> void:
	if current_customer == null:
		return

	add_money(price)

	if current_customer.item_icon:
		current_customer.item_icon.visible = true
		var item_index := 0
		if held_item_label.text.begins_with("Holding Item #"):
			var parts := held_item_label.text.split("#")
			if parts.size() > 1:
				item_index = parts[1].to_int() - 1
		var texture: Texture2D = load("res://Assets/items/%d.png" % (item_index + 1))
		if texture:
			current_customer.item_icon.texture = texture

	var dialogue_res = load("res://Dialogue/customer.dialogue")
	DialogueManager.show_dialogue_balloon_scene(DIALOGUE_BALLOON, dialogue_res, "customer_satisfied", [self])

	held_item = null
	held_item_label.visible = false

# --- Item → Tray interaction ---

func _on_item_placed(item: DraggableItem) -> void:
	if current_customer and current_customer.is_waiting:
		if current_customer.check_item(item.item_data):
			item.queue_free()
		else:
			print("Customer rejected item")
			item.return_to_start()
	else:
		item.return_to_start()
