extends Node
class_name GameManager

## Central manager for progression out of MainGame.gd

@export var starting_money: int = 0
var money: int = 0
var day: int = 1

func _ready() -> void:
	add_to_group("game_manager")
	money = starting_money
	# Wait two frames so every node's _ready() — including CustomerSpawner's
	# signal connections — completes before we broadcast day_started.
	await get_tree().process_frame
	await get_tree().process_frame
	EventBus.money_changed.emit(money)
	
	EventBus.transaction_completed.connect(_on_transaction_completed)
	EventBus.day_ended.connect(_on_day_ended)

	print("[GameManager] Started Day 1")
	EventBus.day_started.emit(day)

func _on_transaction_completed(item: ItemData, was_correct: bool) -> void:
	if was_correct and item:
		money += item.price
		EventBus.money_changed.emit(money)
		print("[GameManager] Earned %d. Total: %d" % [item.price, money])

func _on_day_ended(ended_day_number: int) -> void:
	print("[GameManager] Day %d ended!" % ended_day_number)
	if Dialogic.current_timeline == null:
		Dialogic.Styles.load_style("DialogueStyle")
		await get_tree().process_frame
		Dialogic.start("res://Dialogue/day_ended.dtl")
	# In a full game, wait for Dialogue to end then show Day Summary. Here we just increment
	day += 1
	EventBus.day_started.emit(day)
