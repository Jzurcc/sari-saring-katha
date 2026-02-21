extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var front_cam_pos: Marker3D = $FrontCamPos
@onready var back_cam_pos: Marker3D = $BackCamPos
@onready var tray: TransactionTray = $FrontStore/TransactionTray
@onready var money_label: Label = $CanvasLayer/MoneyLabel
@onready var customer_spawn_pos: Marker3D = $CustomerSpawnPos
@onready var customer_target_pos: Marker3D = $CustomerTargetPos
@onready var dialogue_ui: DialogueUI = $DialogueUI

var is_front_view: bool = true
var money: int = 0
var current_customer: Customer

const CUSTOMER_SCENE = preload("res://Scenes/Customer.tscn")
const ITEMS = [
	preload("res://Resources/Sardines.tres")
]

func _ready() -> void:
	InputManager.view_switch_requested.connect(switch_view)
	tray.item_placed.connect(_on_item_placed)
	dialogue_ui.closed.connect(_on_dialogue_closed)
	
	spawn_customer()

func switch_view() -> void:
	is_front_view = !is_front_view
	var target_transform = front_cam_pos.global_transform if is_front_view else back_cam_pos.global_transform
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(camera, "global_position", target_transform.origin, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_rotation", target_transform.basis.get_euler(), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

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
