extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var front_cam_pos: Marker3D = $FrontCamPos
@onready var back_cam_pos: Marker3D = $BackCamPos
@onready var tray: TransactionTray
@onready var money_label: Label = $CanvasLayer/MoneyLabel
@onready var customer_spawn_pos: Marker3D = $CustomerSpawnPos
@onready var customer_target_pos: Marker3D = $CustomerTargetPos
@onready var dialogue_ui: DialogueUI = $DialogueUI

var current_view: String = "front"
var left_transform: Transform3D
var right_transform: Transform3D
var money: int = 0
var current_customer: Customer

const CUSTOMER_SCENE = preload("res://Scenes/Customer.tscn")
const TRAY_SCENE = preload("res://Scenes/TransactionTray.tscn")
const ITEMS = [
	preload("res://Resources/Sardines.tres")
]

func _ready() -> void:
	if camera and (camera.fov < 1.0 or camera.fov > 179.0):
		camera.fov = 75.0

	var tray_node = get_node_or_null("FrontStore/TransactionTray")
	if tray_node:
		tray = tray_node
	else:
		tray = TRAY_SCENE.instantiate()
		var front_store = get_node_or_null("FrontStore")
		if front_store:
			front_store.add_child(tray)
		else:
			add_child(tray)
			tray.global_position = front_cam_pos.global_position + Vector3(0, -1, -2) # Guessing a good spot if missing
			
	InputManager.view_requested.connect(switch_view)
	tray.item_placed.connect(_on_item_placed)
	dialogue_ui.closed.connect(_on_dialogue_closed)
	
	# Calculate center pivot to dynamically create left and right transforms
	var center = (front_cam_pos.global_position + back_cam_pos.global_position) / 2.0
	
	# Left transform is front rotated 90 deg (PI/2) around Y at center
	var basis_left = front_cam_pos.global_transform.basis.rotated(Vector3.UP, PI / 2.0)
	var pos_left = center + (front_cam_pos.global_position - center).rotated(Vector3.UP, PI / 2.0)
	left_transform = Transform3D(basis_left, pos_left)
	
	# Right transform is front rotated -90 deg (-PI/2) around Y at center
	var basis_right = front_cam_pos.global_transform.basis.rotated(Vector3.UP, -PI / 2.0)
	var pos_right = center + (front_cam_pos.global_position - center).rotated(Vector3.UP, -PI / 2.0)
	right_transform = Transform3D(basis_right, pos_right)
	
	spawn_customer()

func switch_view(action: String) -> void:
	var target_view: String = current_view
	
	match action:
		"look_front":
			target_view = "front" 
		"look_left":
			match current_view:
				"front": target_view = "left"
				"left": target_view = "back"
				"back": target_view = "right"
				"right": target_view = "front"
		"look_right":
			match current_view:
				"front": target_view = "right"
				"right": target_view = "back"
				"back": target_view = "left"
				"left": target_view = "front"
		"look_back":
			match current_view:
				"front": target_view = "back"
				"back": target_view = "front"
				"left": target_view = "right"
				"right": target_view = "left"
				
	if current_view == target_view: return
	current_view = target_view
	
	var target_transform: Transform3D
	match target_view:
		"front": target_transform = front_cam_pos.global_transform
		"back": target_transform = back_cam_pos.global_transform
		"left": target_transform = left_transform
		"right": target_transform = right_transform
		
	var tween = create_tween()
	tween.set_parallel(true)
	
	# To avoid euler angle wrap-around (spinning the long way), we tween position and quaternion locally.
	var local_target: Transform3D = camera.get_parent().global_transform.affine_inverse() * target_transform
	var target_pos: Vector3 = local_target.origin
	var target_quat: Quaternion = local_target.basis.get_rotation_quaternion()
	
	tween.tween_property(camera, "position", target_pos, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "quaternion", target_quat, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func spawn_customer() -> void:
	if current_customer: return
	
	await get_tree().create_timer(2.0).timeout
	
	var customer: Customer = CUSTOMER_SCENE.instantiate()
	add_child(customer)
	customer.global_position = customer_spawn_pos.global_position
	
	# Pick random item
	var desired_item = ITEMS.pick_random()
	customer.setup(desired_item, customer_target_pos.global_position)
	
	current_customer = customer
	current_customer.satisfied.connect(_on_customer_satisfied)
	
	# Connect new 'arrived' signal to show dialogue
	if not customer.is_connected("arrived", _on_customer_arrived):
		customer.arrived.connect(_on_customer_arrived)

func _on_customer_arrived(customer: Customer) -> void:
	var dialogue_text = "*Neigh* Pahingi ako %s!" % customer.desire.item_name
	# We use the body sprite texture for the portrait
	dialogue_ui.show_dialogue(customer.body_sprite.texture, dialogue_text)

func _on_item_placed(item: DraggableItem) -> void:
	if current_customer and current_customer.is_waiting:
		if current_customer.check_item(item.item_data):
			# Success
			add_money(item.item_data.price)
			item.queue_free() # Remove sold item
		else:
			# Wrong item logic
			print("Customer rejected item")
			item.return_to_start()
	else:
		# No customer or not ready
		item.return_to_start()

var _waiting_for_next_customer: bool = false

func _on_customer_satisfied() -> void:
	# Customer texture might still be valid before queue_free if we act fast, 
	# but safer to grab it from our reference or assume DialogueUI still has it if we pass null?
	# DialogueUI.show_dialogue replaces texture. 
	# current_customer is about to be freed.
	var tex = current_customer.body_sprite.texture
	dialogue_ui.show_dialogue(tex, "Salamat bossing!")
	_waiting_for_next_customer = true

func _on_dialogue_closed() -> void:
	if _waiting_for_next_customer:
		_waiting_for_next_customer = false
		current_customer = null
		spawn_customer()

func add_money(amount: int) -> void:
	money += amount
	money_label.text = "Peso: " + str(money)
