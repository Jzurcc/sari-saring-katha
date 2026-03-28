class_name DayNightManager
extends Node


signal day_ended(day_number: int)

const CUSTOMERS_PER_DAY: int = 5


var day: int = 1


var customers_served_today: int = 0

var sun_light: DirectionalLight3D
var world_env: WorldEnvironment
var day_night_cycle: DayNightCycle

var _current_epoch: int = 0

func setup(light: DirectionalLight3D, env_node: WorldEnvironment) -> void:
	sun_light = light
	world_env = env_node

	day_night_cycle = get_node_or_null("DayNightCycle")
	if not day_night_cycle:
		day_night_cycle = DayNightCycle.new()
		day_night_cycle.name = "DayNightCycle"
		
		# Configure before adding to tree so _process doesn't crash on uninitialized vars
		day_night_cycle.sun_3d = sun_light
		day_night_cycle.environment = world_env
		day_night_cycle.day_lenth_in_seconds = 864000
		
		var cozy_day = load("res://Resources/weather_system/cozy_day_config.tres")
		day_night_cycle.default_day_config = cozy_day
		
		add_child(day_night_cycle)
		
	var start_time = GameTime.create_from_instant(Instant.new(0, 0, 6, 0, 0, 0, false))
	day_night_cycle.set_time(start_time)
	
	day_night_cycle.stop_time()
	_current_epoch = start_time.get_epoch()
	
	# Attempt to subscribe if the addon observables are exposed
	if "on_weather_start" in day_night_cycle:
		day_night_cycle.on_weather_start.subscribe(_on_weather_started)
	if "on_day_period_start" in day_night_cycle:
		day_night_cycle.on_day_period_start.subscribe(_on_period_started)

func _on_weather_started(weather_config: WeatherConfig) -> void:
	print("[Weather] It is now " + weather_config.resource_path.get_file().get_basename())

func _on_period_started(period_config: DayPeriodConfig) -> void:
	print("[Time] Entering " + period_config.period_name)

func advance_time() -> void:
	customers_served_today += 1
	var total_day_millis = 12 * 60 * 60 * 1000
	var portion_millis = total_day_millis / CUSTOMERS_PER_DAY
	var target_epoch = _current_epoch + portion_millis
	
	print("[DayNight] Customer %d/%d served. Advancing time 7 seconds..." % [customers_served_today, CUSTOMERS_PER_DAY])
	
	var tween := create_tween()
	# Precisely 7 seconds transition as requested
	tween.tween_method(_apply_time_epoch, _current_epoch, target_epoch, 7.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	
	if customers_served_today >= CUSTOMERS_PER_DAY:
		await tween.finished
		day_ended.emit(day)
		day += 1
		customers_served_today = 0
		var start_time = GameTime.create_from_instant(Instant.new(0, 0, 6, 0, 0, 0, false))
		_current_epoch = start_time.get_epoch()
		day_night_cycle.set_time(start_time)

func _apply_time_epoch(epoch: int) -> void:
	_current_epoch = epoch
	day_night_cycle.set_time(GameTime.new(epoch))
