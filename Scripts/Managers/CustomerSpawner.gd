extends Node
class_name CustomerSpawner

@export var customer_scene: PackedScene = preload("res://Scenes/Customer.tscn")
@export var spawn_pos: NodePath
@export var target_pos: NodePath

@export var customers_per_day: int = 5

var current_customer: Customer = null
var customers_served_today: int = 0
var _encounter_count: int = 0
var _pending_dismiss: bool = false

func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.customer_satisfied.connect(_on_customer_finished)
	EventBus.customer_dismissed.connect(_on_customer_dismissed)
	# customer_rejected intentionally NOT connected here — a rejection means the
	# customer is still at the counter waiting for the correct item.
	Dialogic.timeline_ended.connect(_on_dialogue_ended)
	Dialogic.signal_event.connect(_on_dialogic_signal)

func _on_day_started(_day: int) -> void:
	customers_served_today = 0
	_spawn_next_customer()

func _spawn_next_customer() -> void:
	if current_customer != null:
		return

	if customers_served_today >= customers_per_day:
		var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
		var day_num := gm.day if gm else 1
		EventBus.day_ended.emit(day_num)
		return

	print("[CustomerSpawner] Spawning in 2s...")
	await get_tree().create_timer(2.0).timeout

	# Use standard placeholder for now
	var desired_item: ItemData = load("res://Resources/items/cigarette/Marboro.tres")

	if not desired_item or not spawn_pos or not target_pos:
		push_error("[CustomerSpawner] Missing configuration!")
		return

	current_customer = customer_scene.instantiate()
	# Add to the same parent as the spawner, typically MainGame
	get_parent().add_child(current_customer)
	current_customer.global_position = get_node(spawn_pos).global_position
	current_customer.setup(desired_item, get_node(target_pos).global_position)

	current_customer.arrived.connect(_on_customer_arrived)
	current_customer.clicked.connect(_on_customer_clicked)
	
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
		Dialogic.Styles.load_style("bubble_style_dialogue")
		Dialogic.start(timeline_path)

func _on_customer_finished(_customer: Customer) -> void:
	# Null the customer reference immediately so _spawn_next_customer() can
	# proceed even while the satisfaction animation is still playing.
	current_customer = null
	customers_served_today += 1
	_encounter_count += 1

	# _on_dialogue_ended triggers the next spawn once the satisfied/rejected
	# timeline ends, so no explicit call is needed here.

func _on_customer_dismissed(_customer: Customer) -> void:
	# Customer left after being refused — move on without counting as sold.
	current_customer = null
	_encounter_count += 1
	_spawn_next_customer()

func _on_customer_clicked(_customer: Customer) -> void:
	if Dialogic.current_timeline == null:
		Dialogic.Styles.load_style("bubble_style_dialogue")
		Dialogic.start("res://Dialogue/customer_talk.dtl")

func _on_dialogic_signal(argument: String) -> void:
	if argument == "refuse_service":
		_pending_dismiss = true

func _on_dialogue_ended() -> void:
	if _pending_dismiss and is_instance_valid(current_customer):
		_pending_dismiss = false
		current_customer.dismiss()
		return

	# Only spawn the next customer when no one is currently at the counter.
	# If current_customer is still set, the last dialogue was a rejection and
	# the same customer is still waiting — do not spawn a new one.
	if current_customer == null and customers_served_today < customers_per_day:
		_spawn_next_customer()
