extends Node
class_name CustomerSpawner

@export var customer_scene: PackedScene = preload("res://Scenes/Customer.tscn")
@export var spawn_pos: NodePath
@export var target_pos: NodePath

@export var customers_per_day: int = 5

var current_customer: Customer = null
var customers_served_today: int = 0
var _encounter_count: int = 0

func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.customer_satisfied.connect(_on_customer_finished)
	EventBus.customer_rejected.connect(_on_customer_finished)
	Dialogic.timeline_ended.connect(_on_dialogue_ended)

func _on_day_started(_day: int) -> void:
	customers_served_today = 0
	_spawn_next_customer()

func _spawn_next_customer() -> void:
	if current_customer != null:
		return

	if customers_served_today >= customers_per_day:
		EventBus.day_ended.emit(1) # We just pass 1 or read from GameManager later
		return

	print("[CustomerSpawner] Spawning in 2s...")
	await get_tree().create_timer(2.0).timeout

	# Use standard placeholder for now
	var desired_item: ItemData = load("res://Resources/items/food/Cigarettes.tres")

	if not desired_item or not spawn_pos or not target_pos:
		push_error("[CustomerSpawner] Missing configuration!")
		return

	current_customer = customer_scene.instantiate()
	# Add to the same parent as the spawner, typically MainGame
	get_parent().add_child(current_customer)
	current_customer.global_position = get_node(spawn_pos).global_position
	current_customer.setup(desired_item, get_node(target_pos).global_position)

	current_customer.arrived.connect(_on_customer_arrived)
	
	# The Customer script emits satisfied naturally, but we also let DragManager trigger it through check_item
	EventBus.customer_spawned.emit(current_customer)

func _on_customer_arrived(customer: Customer) -> void:
	EventBus.customer_arrived.emit(customer)

	var item_name = customer.desire.item_name if customer.desire else "something"
	InventoryManager.current_item_name = item_name

	var timeline_path: String
	if _encounter_count == 0:
		timeline_path = "res://Dialogue/customer_greeting.dtl"
	else:
		timeline_path = "res://Dialogue/customer_returning.dtl"

	if Dialogic.current_timeline == null:
		Dialogic.start(timeline_path)

func _on_customer_finished(_customer: Customer) -> void:
	customers_served_today += 1
	_encounter_count += 1
	current_customer = null

	if Dialogic.current_timeline == null:
		# If satisfied
		# Actually we depend on the return of DragManager to know if satisfied or reject
		# Dialogic.start("res://Dialogue/customer_satisfied.dtl")
		pass
	
	# Dialogue ended will catch the end of the satisfied/reject dialogues and spawn next

func _on_dialogue_ended() -> void:
	if current_customer == null and customers_served_today < customers_per_day:
		_spawn_next_customer()
