class_name DayNightManager
extends Node

signal day_ended(day_number: int)

const CUSTOMERS_PER_DAY: int = 5
var day: int = 1
var customers_served_today: int = 0

var time_of_day: Node

# time goes from 6 AM to 6 PM (6.0 to 18.0)
var _current_time: float = 6.0

func setup(sky3d_time_of_day: Node) -> void:
	time_of_day = sky3d_time_of_day
	
	if time_of_day:
		time_of_day.current_time = _current_time
		if time_of_day.has_method("pause"):
			time_of_day.pause()

func advance_time() -> void:
	customers_served_today += 1
	var portion_hours = 12.0 / CUSTOMERS_PER_DAY
	var target_time = _current_time + portion_hours
	
	print("[DayNight] Customer %d/%d served. Advancing time 7 seconds..." % [customers_served_today, CUSTOMERS_PER_DAY])
	
	var tween := create_tween()
	# Tweens current_time over 7 seconds
	tween.tween_method(_apply_time, _current_time, target_time, 7.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	
	if customers_served_today >= CUSTOMERS_PER_DAY:
		await tween.finished
		day_ended.emit(day)
		day += 1
		customers_served_today = 0
		_current_time = 6.0
		if time_of_day:
			time_of_day.current_time = _current_time

func _apply_time(time_val: float) -> void:
	_current_time = time_val
	if time_of_day:
		time_of_day.current_time = time_val
