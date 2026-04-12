extends Node
class_name GameManager

## Central manager for progression out of MainGame.gd

const MAX_DAYS := 7

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

	# Reset the clock to 5 AM for day 1
	_reset_clock_to_morning()

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
		Dialogic.start("res://Dialogue/day_ended.dtl")
	
	if day >= MAX_DAYS:
		print("[GameManager] Final day complete!")
		# Future: show end-game summary screen
		return
	
	day += 1
	_reset_clock_to_morning()
	EventBus.day_started.emit(day)

## Resets the in-game clock back to 5:00 AM for the new day.
func _reset_clock_to_morning() -> void:
	# Reset StoryManager's internal display time so it doesn't carry over
	StoryManager._current_display_time = 5.0
	StoryManager._clock_cap_hour = 6.0
	StoryManager._clock_running = false

	# Reset the sky / TimeOfDay node
	var tod = get_tree().root.find_child("TimeOfDay", true, false)
	if tod and tod.has_method("set_time"):
		tod.game_time_enabled = false
		tod.system_sync = false
		tod.set_time(5, 0, 0)
