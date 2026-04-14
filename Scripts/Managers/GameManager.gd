extends Node
class_name GameManager

## Central manager for progression out of MainGame.gd

const MAX_DAYS := 7

@export var starting_money: float = 200.0
var money: float = 0.0
var day: int = 1
var _last_earning: float = 0.0

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
	EventBus.utang_accepted.connect(_on_utang_accepted)

	# Reset the clock to 5 AM for day 1
	_reset_clock_to_morning()

	print("[GameManager] Started Day 1")
	EventBus.day_started.emit(day)

func _on_transaction_completed(item: ItemData, was_correct: bool) -> void:
	if was_correct and item:
		_last_earning = item.get_final_price()
		money += _last_earning
		EventBus.money_changed.emit(money)
		print("[GameManager] Sold %s for %.2f (Base: %.2f, Margin: %d%%). TOTAL: %.2f" % [
			item.item_name, _last_earning, item.price, int(item.profit_margin * 100), money
		])

func _on_utang_accepted(_customer: Customer) -> void:
	money -= _last_earning
	EventBus.money_changed.emit(money)
	print("[GameManager] Utang accepted! Reverted %.2f. New balance: %.2f" % [_last_earning, money])
	
	# Future: We could update a persistent Debt dictionary here if needed for more complex logic.
	# For now, Dialogic handles its own {Stats.Debt} variable via [set] events in the timeline.

func deduct_money(amount: float) -> void:
	if money >= amount:
		money -= amount
		EventBus.money_changed.emit(money)
		print("[GameManager] Spent %.2f. Remaining: %.2f" % [amount, money])
	else:
		print("[GameManager] Error: Tried to spend %.2f but only has %.2f!" % [amount, money])

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

func _reset_clock_to_morning() -> void:
	# Set the initial hour in StoryManager context
	StoryManager._current_display_time = StoryManager.DAY_START_HOUR

	# Configure the sky / TimeOfDay node
	var tod = get_tree().root.find_child("TimeOfDay", true, false)
	if tod and tod.has_method("set_time"):
		tod.system_sync = false
		tod.minutes_per_day = 10.0 # 25s/hour * 24h = 600s = 10m
		tod.set_time(int(StoryManager.DAY_START_HOUR), 0, 0)
	
	# Start the clock via StoryManager's managed property
	# This automatically sets tod.game_time_enabled = true
	StoryManager.is_clock_running = true

func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_L and not event.echo:
		print("[GameManager] DEBUG: Skip to next day triggered via L key")
		
		# End any current dialogue to prevent locking
		if Dialogic.current_timeline != null:
			Dialogic.end_timeline()
			
		# Despawn any active customers safely
		var customers = get_tree().get_nodes_in_group("customer")
		for c in customers:
			# Emit dismissed so UI reacts (if any)
			EventBus.customer_dismissed.emit(c)
			c.queue_free()
			
		# Trigger the normal end of day sequence
		_on_day_ended(day)
