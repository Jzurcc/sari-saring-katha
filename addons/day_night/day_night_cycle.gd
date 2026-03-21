extends Node
class_name DayNightCycle

## This class is used to manage the day/night cycle. It automatically manages the passage time.
## Time is measured as a timeline and therefore can be though of as a calendar with days, weeks, months, etc.
## A point on this timeline is called and [Instant]. And instand can be manipulated by converting it to a [GameTime].
## The amount of time inbetween two [Instant]'s is a [Duration].
## [br][br]With these simple rules, this Node allows you to schedule events on the timeline. Craft different types of days
## using [DayConfig] with different effects during that day represented by [DayPeriodConfig]. Each [DayPeriodConfig] can potentialy
## have a [WeatherConfig] associated with it.
## [br]For example, you could create a "Rainy" [DayConfig] with several [DayPeriodConfig]s to make the day seem more dark during those periods. Then each of those periods could
## have a chance of triggering a [WeatherConfig] that starts some sort of [Script] to spawn in rain.
## You can then schedule those [DayConfig]s using the [DayScheduler] which gives you control over the order or lack thereof of these [DayConfig]s.
## [br][br]You are required to set a default [DayConfig] before you can use the [DayNightCycle]. This default will be the day that is used whenever no other [DayConfig] is set.
## [br][br]• You can maniulate the speed in which time passes, or pause and resume it.
## [br]• You can override,queue,or remove any [DayConfig]s or [DayScheduler]s or [DayPeriodConfig]s.
## [br]• You can create reminders that will emit when the current game time reaches the reminder [GameTime].
## [br]• The sun/environment are not required to be set. If they are, this script will control them as well. Or you can manually set them if you would like. The methods to get the color,light intensity, and rotation are also available to be called if you don't want to calculate them yourself.
## [br]• There are many events that are available to be listened to, see the documentation for more details.
## [br]• This also exposes a way to save and load the current state of the day night cycle. Please see the [method save] and [method load_from_json] for details on that.


# TODO code cleanup, public on top, function docs, DRY
# TODO make example scenes(have stop time too): saving/loading, no scheduler, warp time, scheduler(all types)
# TODO Write readme
# TODO check godot making a plugin for anything missed
# TODO publish

## This is the game version that will be looked for when loading saves.
## Please note that this should reflect your game version and you will need to handle any differences between versions
const _GAME_VERSION: String = "1.0.0"
## This is the plugin version that will be looked for when loading saves.
## Please note that this should never change. It is for the plugin to coerce different versions of this to be able to maintain the code if possible
const _PLUGIN_VERSION: String = "1.0.0"

## This is the minimim amount of time in seconds that can be set for a day
const _MIN_DAY_LENGTH: int = 3
## This represents 100% of a day
const _FULL_DAY_PERCENTAGE: int = 1
## This is the maximum amount of time in seconds that can be set for a day
## It is calculate to be 100 * an earth day length in seconds
const _MAX_DAY_LENGTH: int = 8640000
## This is the maximum multiplier that can be set
const _MAX_TIME_MULTIPLIER: float = 100.0
## This helps to regulate the color transition period.
## Higher the value, the slower the transition will be.
const _AUTO_COLOR_TRANSTION: float = 100
## This is the maximum light intensity that can be set
const _MAX_LIGHT_INTENSITY_POSSIBLE: float = 16.0

## REQUIRED, this will be the default day config. It needs to be defined for a fallback day.
## This will close the game if it is not set
@export var default_day_config: DayConfig = null

@export_category("Auto Control Settings")
## When set, the day night cycle will move and control the light color automatically
## This is not required to be set if you want to manually control the light parameters
@export var sun_3d: DirectionalLight3D
## When set, the day night cycle will move and control the light color automatically
## This is not required to be set if you want to manually control the light parameters
@export var sun_2d: DirectionalLight2D
## When set, the day night cycle control the ambient light color automatically
## This is not required to be set if you want to manually control the light parameters
@export var environment: WorldEnvironment
## The day scheduler that will be used. This can be null.
@export var day_scheduler: DayScheduler

@export_group("Time Settings")
## This is how long the day will last in earth time seconds
@export var day_lenth_in_seconds: int = 5 :
	get:
		return day_lenth_in_seconds
	set(value):
		day_lenth_in_seconds = clamp(value, _MIN_DAY_LENGTH, _MAX_DAY_LENGTH)
## How many days in the game time year, Clamped between 1-1_000_000_000
@export var days_in_year: int = 1 :
	get:
		return days_in_year
	set(value):
		days_in_year = clamp(value, 1, 1_000_000_000)
## The default time speed multiplier that will be used as the initial time speed and the value for reseting the time multilier.
@export_range(0.1, _MAX_TIME_MULTIPLIER) var default_time_speed_multiplier: float = 1.0


@export_group("Begining of Time Settings")
## If set to true, start year will be before 0 and it will count down to zero before counting up
@export var before_year_zero: bool = false
## The year time that will be used as the start time
@export var start_year: int = 0
## The day time that will be used as the start time
@export var start_day: int = 0
## The hour time that will be used as the start time
@export var start_hour: int = 0
## The minute time that will be used as the start time
@export var start_minute: int = 0
## The second time that will be used as the start time
@export var start_second: int = 0

@export_group("Misc Settings")
## If set to [code]true[/code], all of the calculated details will be recalculated every frame even when the time is paused.
## This is helpful if you want the information to be up to date even when the time calculation is paused.
## If set to [code]false[/code], the calculations will only be recalculated when the time is not paused
## This saves on performance if you are not going to be altering any time details when the game is paused
@export var should_calculate_when_paused: bool = true
## If set to [code]true[/code], the debug info will be shown in the console
@export var show_debug_info: bool = false

@onready var _on_day_change: Subject = Subject.new()
@onready var _on_year_change: Subject = Subject.new()
@onready var _on_night_time_start: Subject = Subject.new()
@onready var _on_day_time_start: Subject = Subject.new()
@onready var _on_time_paused: Subject = Subject.new()
@onready var _on_time_resumed: Subject = Subject.new()
@onready var _on_time_speed_change: Subject = Subject.new()
@onready var _on_time_speed_end: Subject = Subject.new()
@onready var _on_day_period_start: Subject = Subject.new()
@onready var _on_day_period_end: Subject = Subject.new()
@onready var _on_day_period_overwrite: Subject = Subject.new()
@onready var _on_weather_start: Subject = Subject.new()
@onready var _on_weather_end: Subject = Subject.new()
@onready var _on_day_config_change: Subject = Subject.new()
@onready var _on_day_scheduler_change: Subject = Subject.new()
@onready var _on_day_scheduler_finish: Subject = Subject.new()
## Will emit when the day changes with the [GameTime] of the new day
@onready var on_day_change: Observable = _on_day_change.as_observable()
## Will emit when the year changes with the [GameTime] of the new day
@onready var on_year_change: Observable = _on_year_change.as_observable()
## Will emit when the night time starts with the [GameTime] of when the night time starts.
## The time emitted is not the time that the night time starts but the first tick of time past the sunset time of the current [DayConfig]
@onready var on_night_time_start: Observable = _on_night_time_start.as_observable()
## Will emit when the day time starts with the [GameTime] of when the day time starts.
## The time emitted is not the time that the day time starts but the first tick of time past the sunrise time of the current [DayConfig]
@onready var on_day_time_start: Observable = _on_day_time_start.as_observable()
## Will emit when the time progession is paused. If the time is already pause, it will not emit again
@onready var on_time_paused: Observable = _on_time_paused.as_observable()
## Will emit when the time progession is resumed. If the time is already resumed, it will not emit again
@onready var on_time_resumed: Observable = _on_time_resumed.as_observable()
## Will emit when the time speed changes with the new time speed multiplier as a [code]float[/code]
@onready var on_time_speed_change: Observable = _on_time_speed_change.as_observable()
## Will emit when the altering of the time speed ends with the [GameTime] of when the time speed ends
@onready var on_time_speed_end: Observable = _on_time_speed_end.as_observable()
## Will emit when a new day period starts with the [DayPeriodConfig] of the new period
@onready var on_day_period_start: Observable = _on_day_period_start.as_observable()
## Will emit when a day period ends with the [DayPeriodConfig] of the period that ended
@onready var on_day_period_end: Observable = _on_day_period_end.as_observable()
## Will emit whenever an existing [DayPeriodConfig] is overwritten with a new one.
## Emits a [Dictionary] with the old [DayPeriodConfig] (called "old_period") and the new [DayPeriodConfig] (called "new_period").
## Will emit before the [code]on_day_period_end[/code] event is emitted.
@onready var on_day_period_overwrite: Observable = _on_day_period_overwrite.as_observable()
## Will emit when the weather starts with the [WeatherConfig] of the new weather
@onready var on_weather_start: Observable = _on_weather_start.as_observable()
## Will emit when the weather ends with the [WeatherConfig] of the weather that ended
@onready var on_weather_end: Observable = _on_weather_end.as_observable()
## Will emit when the [DayConfig] changes with the new [DayConfig]
@onready var on_day_config_change: Observable = _on_day_config_change.as_observable()
## Will emit when the day scheduler changes with the new [DayScheduler]
@onready var on_day_scheduler_change: Observable = _on_day_scheduler_change.as_observable()
## Will emit when the day scheduler finishes with the new [DayScheduler]
@onready var on_day_scheduler_finish: Observable = _on_day_scheduler_finish.as_observable()

var _percentage_through_day: float = 0
var _time_speed_multiplier: float = 1
var _time_to_stop_multiplier: GameTime = null
var _time_stopped: bool = false
var _current_date_at_start_of_day: GameTime
var _current_date_at_end_of_day: GameTime
var _sunrise_start_percentage: float
var _sunset_start_percentage: float
var _reminders: Dictionary = {}
var _repeating_reminders: Dictionary = {}
var _todays_reminders: Array[Variant] = []
var _reminder_index: int = 0
var _day_period_index: int = 0
var _has_day_periods: bool = false
var _active_period: DayPeriodConfig = null
var _active_weather: WeatherConfig = null
var _game_time_this_frame: GameTime
var _color_lerp_time: float = 0
var _day_config: DayConfig = null
var _sunrise_today: GameTime
var _sunset_today: GameTime
var _middle_of_day_time: GameTime
var _sunset_yesterday: GameTime
var _sunrise_tomorrow: GameTime
var _middle_of_night_begin: GameTime
var _middle_of_night_end: GameTime
var _queued_day_config: DayConfig = null
var _queued_day_config_overwrite: bool = false
var _queued_scheduler: DayScheduler = null
var _yesterday: DayConfig
var _is_day: bool = false

func _ready() -> void:
	if default_day_config == null:
		assert(default_day_config != null, "No default day config set! A default day config is required for the day night cycle to work!")

	# TODO cleanup ready func
	if show_debug_info:
		on_day_period_overwrite.subscribe(func(information: Dictionary): print("Day Period Overwriten. Old period: " + information.get("old_period").period_name + " - New period: " + information.get("new_period").period_name)).dispose_with(self)

	GameTime.DAYS_IN_YEAR = days_in_year
	GameTime.YEAR_DIVISOR = GameTime.DAYS_IN_YEAR * GameTime.DAY_DIVISOR
	
	set_time(GameTime.create_from_instant(Instant.new(start_year, start_day, start_hour, start_minute, start_second, 0, before_year_zero)))
	#print(_current_date_at_start_of_day.add_unit(13, TimeUnit.HOURS).get_time_as_string())
	var o: Observable = create_reminder(_current_date_at_start_of_day.add_unit(13, TimeUnit.HOURS),"1", true)
	var o2: Observable = create_reminder(_current_date_at_start_of_day.add_unit(12, TimeUnit.HOURS),"noon", true)
	var o3: Observable = create_reminder(_current_date_at_start_of_day.add_unit(14, TimeUnit.HOURS),"2", true)

	on_day_change \
		.subscribe(func(newTime: GameTime): _populate_reminders(newTime)).dispose_with(self)
	on_day_period_start \
		.subscribe(func(period: DayPeriodConfig): print("Starting Day Period: " + period.period_name + " at time: " + _game_time_this_frame.get_date_time_as_string())).dispose_with(self)
	on_day_period_end \
		.subscribe(func(period: DayPeriodConfig): print("Ending Day Period: " + period.period_name + " at time: " + _game_time_this_frame.get_date_time_as_string())).dispose_with(self)

	#GDRx.start_periodic_timer(0.1).subscribe(func(i): print("Interval time: " + get_time().get_date_as_string() + " - " + get_time().get_time_as_string(), " - percentage through day: ", percentage_through_day)).dispose_with(self)

	on_day_change.subscribe(func(time: GameTime): print("subscribing new day game time: ", time.get_date_as_string() )).dispose_with(self)

	on_time_speed_end.subscribe(func(time: GameTime): print("warp ends at time: ", time.get_date_as_string(), " - ", time.get_time_as_string() )).dispose_with(self)
	o.subscribe(func(name: String): print(name+ " - Reminder that is is 13 hours at the time: " + _game_time_this_frame.get_time_as_string())).dispose_with(self)
	o2.subscribe(func(name: String): print(name+ " - Reminder that is is 12 hours at the time: " + _game_time_this_frame.get_time_as_string())).dispose_with(self)
	o3.subscribe(func(name: String): print(name+ " - Reminder that is is 14 hours at the time: " + _game_time_this_frame.get_time_as_string())).dispose_with(self)
#	on_year_change.as_observable() \
#		.filter(func(newTime: GameTime): return newTime !=null)  \
#		.subscribe(func(newTime: GameTime): print("The year has changed: " + newTime.get_date_as_string() + " - " + newTime.get_time_as_string())).dispose_with(self)
#	on_day_time_start.as_observable().filter(func(newTime: GameTime): return newTime !=null).subscribe(func(time): print("day time start: " + time.get_date_as_string() + " - " + time.get_time_as_string())).dispose_with(self)
#	on_night_time_start.as_observable().filter(func(newTime: GameTime): return newTime !=null).subscribe(func(time): print("night time start: " + time.get_date_as_string() + " - " + time.get_time_as_string())).dispose_with(self)
	print("setting time this frame to: " + _game_time_this_frame.get_date_as_string() + " - " + _game_time_this_frame.get_time_as_string())
	alter_time_speed(10, _game_time_this_frame.add_unit(1,TimeUnit.DAY))
	# NEEDED
	if (_day_config != null) && (_day_config.day_periods != null):
		_has_day_periods = true
		_day_config.day_periods.sort_custom(func(a, b): return a.start_time < b.start_time)
	else:
		_has_day_periods = false

func _process(delta: float) -> void:
	if not _time_stopped:
		_percentage_through_day += (delta / day_lenth_in_seconds) * _time_speed_multiplier;
		# Needs to make sure the percentage never goes over _FULL_DAY_PERCENTAGE, so handle day end first
		if _percentage_through_day >= _FULL_DAY_PERCENTAGE:
			_handle_day_end();
	elif not should_calculate_when_paused:
		return

	_game_time_this_frame = _calculate_game_time_for_frame()
	_send_potential_reminders()
	_handle_time_speed()
	_update_day_state()

	if sun_3d != null:
		sun_3d.rotation.x = deg_to_rad(get_sun_rotation().x)
		sun_3d.set_color(get_light_color(delta))
		sun_3d.light_energy = calculate_light_intesity() if _is_day else 0.0
	if sun_2d != null:
		sun_2d.set_color(get_light_color(delta))
		sun_2d.energy = calculate_light_intesity() if _is_day else 0.0
	if environment != null:
		environment.environment.ambient_light_energy = calculate_light_intesity() if !_is_day else 0

## This will queue a [DayConfig] for the next day. Meaning when the day changes, the queued [DayConfig] will be used.
## If [param overwrite_day] is [code]true[/code] then the queued [DayConfig] will take the place of the next day's [DayConfig].
## If [param overwrite_day] is [code]false[/code] (default behavior) then the queued [DayConfig] will push what would be the next [DayConfig] to be the the day after the queued [DayConfig].
func queue_day_config(config: DayConfig, overwrite_day: bool = false) -> void:
	_queued_day_config_overwrite = overwrite_day
	_queued_day_config = config

## Returns [code]true[/code] if there is a queued day config, [code]false[/code] otherwise
func has_queued_day_config() -> bool:
	return _queued_day_config != null

## Removes the queued [DayConfig]. Does nothing if there is no queued [DayConfig]
func remove_queued_day_config() -> void:
	if !has_queued_day_config():
		return
	_queued_day_config = null

## This will queue a [DayScheduler] to be used after the current [DayScheduler] is done.
## If there is not already a current [DayScheduler] then this will set the [DayScheduler] immediately
func queue_scheduler(scheduler: DayScheduler) -> void:
	if day_scheduler == null:
		set_new_scheduler(scheduler)
		return
	_queued_scheduler = scheduler

## Returns [code]true[/code] if there is a queued [DayScheduler], [code]false[/code] otherwise
func has_queued_scheduler() -> bool:
	return _queued_scheduler != null

## Removes the queued [DayScheduler]. Does nothing if there is no queued [DayScheduler]
func remove_queued_scheduler() -> void:
	if !has_queued_scheduler():
		return
	_queued_scheduler = null

## Returns the current [DayScheduler]
func get_current_scheduler() -> DayScheduler:
	return day_scheduler

## Returns the current [DayConfig]
func get_current_day_config() -> DayConfig:
	return _day_config

## Returns [code]true[/code] if it is day time, [code]false[/code] if it is in night time.
## This is based on the current [GameTime] in relation to the current [DayConfig].
func is_day() -> bool:
	return _is_day

## Returns [code]true[/code] if it is night time, [code]false[/code] if it is in day time.
## This is based on the current [GameTime] in relation to the current [DayConfig].
func is_night() -> bool:
	return !_is_day

## Sets the current [DayPeriodConfig] to be active immediately for the length of [param length_of_period_in_seconds] seconds.
## The start time of this period will be set to the current [GameTime].
## The [param length_of_period_in_seconds] is how many [GameTime] seconds the period should last.
func set_day_period(period: DayPeriodConfig, length_of_period_in_seconds: int) -> void:
	period.start_hour = _game_time_this_frame.get_hour()
	period.start_minute = _game_time_this_frame.get_minute()
	period.start_second = _game_time_this_frame.get_second()
	period.start_millisecond = _game_time_this_frame.get_millisecond()

	var length_in_milliseconds: int = length_of_period_in_seconds * GameTime.MILLISECONDS_IN_SECOND
	var instant_representing_length = Instant.new(0, 0, 0, 0, 0, length_in_milliseconds)
	period.length_hour = instant_representing_length.get_hour()
	period.length_minute = instant_representing_length.get_minute()
	period.length_second = instant_representing_length.get_second()
	period.length_millisecond = instant_representing_length.get_millisecond()

	_set_active_period(period)

## Returns a dictionary of times that are milestones. This includes:[br]
## [br][code]sunset_yesterday[/code] - the [GameTime] of yesterday's sunset
## [br][code]start_of_day[/code] - the [GameTime] of the start of the current day
## [br][code]sunrise_today[/code] - the [GameTime] of today's sunrise
## [br][code]sunset_today[/code] - the [GameTime] of today's sunset
## [br][code]end_of_day[/code] - the [GameTime] of the end of the current day
## [br][code]sunrise_tomorrow[/code] - the [GameTime] of tomorrow's sunrise
func get_milestone_times() -> Dictionary:
	return {
		"sunset_yesterday": _sunset_yesterday,
		"start_of_day": _current_date_at_start_of_day,
		"sunrise_today": _sunrise_today,
		"sunset_today": _sunset_today,
		"end_of_day": _current_date_at_end_of_day,
		"sunrise_tomorrow": _sunrise_tomorrow
	}

## This pauses the passage of time. If the time has not already been paused, this will emit [code]on_time_paused[/code].
func stop_time() -> void:
	if !_time_stopped:
		_on_time_paused.on_next(_time_stopped)
	_time_stopped = true

## This resumes the passage of time. If the time has already been paused, this will emit [code]on_time_resumed[/code].
func start_time() -> void:
	if _time_stopped:
		_on_time_resumed.on_next(_time_stopped)
	_time_stopped = false

## This will overwrite the current [DayConfig] with the [param config]. If the [param config] is the same as the current [DayConfig] then this will do nothing.
## If the [DayConfig] is successfully set then this will emit [code]on_day_config_change[/code].
func set_day_config(config: DayConfig) -> void:
	if config == null:
		return
	if (_day_config != null) && (config.get_instance_id() == _day_config.get_instance_id()):
		return
	_color_lerp_time = 0
	_day_config = config
	_on_day_config_change.on_next(_day_config)

## This will overwrite the current [DayScheduler] with the [param scheduler]. If the [param scheduler] is the same as the current [DayScheduler] then this will do nothing.
## If the [DayScheduler] is successfully set then this will emit [code]on_day_scheduler_change[/code]
## If [param overwrite_day_config] is [code]true[/code] then this will also overwrite the current [DayConfig] with the [param scheduler]'s current [DayConfig]
func set_new_scheduler(scheduler: DayScheduler, overwrite_day_config: bool = false) -> void:
	if scheduler == null:
		return
	if (day_scheduler != null) && (scheduler.get_instance_id() == day_scheduler.get_instance_id()):
		return
	day_scheduler.verify()
	day_scheduler = scheduler
	_on_day_scheduler_change.on_next(day_scheduler)
	if overwrite_day_config:
		set_day_config(day_scheduler.get_current_day_config())

## Overwrites the current [GameTime] with the [param time].
## [param new_day_config] and [param new_scheduler] are optional values.
## If [param new_day_config] is provided, it will set the current [DayConfig] to that value.
## If [param new_scheduler] is provided, it will set the current [DayScheduler] to that value.
## If both [param new_day_config] and [param new_scheduler] are provided, it will set the current [DayConfig] to [param new_day_config] and [DayScheduler] will take effect the next day.
## This will not emit any events except for [code]on_day_config_change[/code] and [code]on_day_scheduler_change[/code] if they are different from the respective current values are.
func set_time(time: GameTime, new_day_config: DayConfig = null, new_scheduler: DayScheduler = null) -> void:
	_current_date_at_start_of_day = GameTime.create_from_instant(Instant.new(
		time.get_year(),
		time.get_day(),
		0,
		0,
		0,
		0
	))
	_current_date_at_end_of_day = GameTime.create_from_instant(Instant.new(
		time.get_year(),
		time.get_day(),
		23,
		59,
		59,
		999
	))
	if new_day_config != null:
		set_day_config(new_day_config)
	if new_scheduler != null:
		set_new_scheduler(new_scheduler)
	if _day_config == null:
		if day_scheduler != null:
			day_scheduler.verify()
			if day_scheduler.get_current_index() < 0:
				set_day_config(day_scheduler.advance_and_get_day_config())
			else:
				set_day_config(day_scheduler.get_current_day_config())
			if day_scheduler.is_done():
				_end_current_scheduler()
		else:
			set_day_config(default_day_config)

	if (_day_config != null) && (_day_config.day_periods != null):
		_has_day_periods = true
		_day_config.day_periods.sort_custom(func(a, b): return a.start_time < b.start_time)
	else:
		_has_day_periods = false

	_percentage_through_day = _calculate_percent_of_day_by_time(time)
	_game_time_this_frame = _calculate_game_time_for_frame()
	_sunrise_start_percentage = _calculate_percent_of_day_by_time(GameTime.create_from_instant(_day_config.get_sunrise()))
	_sunset_start_percentage = _calculate_percent_of_day_by_time(GameTime.create_from_instant(_day_config.get_sunset()))
	_update_day_state()
	_populate_reminders(_current_date_at_start_of_day)
	_is_day = (_percentage_through_day >= _sunrise_start_percentage) && (_percentage_through_day < _sunset_start_percentage)
	_calculate_milestone_times()

	if sun_3d:
		sun_3d.rotation.x = deg_to_rad(get_sun_rotation().x)
		sun_3d.set_color(get_light_color(0,true))
		sun_3d.light_energy = calculate_light_intesity()
	if sun_2d != null:
		sun_2d.set_color(get_light_color(0,true))
		sun_2d.energy = calculate_light_intesity() if _is_day else 0.0
	if environment != null:
		environment.environment.ambient_light_energy = calculate_light_intesity() if !_is_day else 0

## Returns the current [GameTime].
func get_time_this_frame() -> GameTime:
	return _game_time_this_frame

## Returns the current time speed multiplier.
func get_time_speed_multiplier() -> float:
	return _time_speed_multiplier

## Returns the calculated light color for the current frame.
## This is used automatically if the sun/environment is provided to set the color.
func get_light_color(delta: float, immediate: bool = false) -> Color:
	if (_color_lerp_time > 1):
		return sun_3d.get_color();
	_color_lerp_time += (delta / (day_lenth_in_seconds * _AUTO_COLOR_TRANSTION)) * _time_speed_multiplier
	var new_color: Color
	if _active_weather != null:
		new_color = _active_weather.day_time_weather_color if _is_day else _active_weather.night_time_weather_color
	elif _active_period != null:
		new_color = _active_period.day_time_period_color if _is_day else _active_period.night_time_period_color
	else:
		new_color = _day_config.get_day_time_color() if _is_day else _day_config.get_night_time_color()

	if immediate:
		_color_lerp_time=2
		return new_color
	else:
		var current_color =  sun_2d.color if sun_2d != null else sun_3d.light_color
		return lerp(current_color, new_color, _color_lerp_time) as Color

## Returns the calculated light intensity for the current frame.
## This is used automatically if the sun/environment is provided to set the light intensity.
func calculate_light_intesity() -> float:
	var intensity: float
	var min_intensity: float
	if _active_weather != null:
		intensity = _active_weather.day_time_light_intensity if _is_day else _active_weather.night_time_light_intensity
		min_intensity = _active_weather.minimum_light_intensity
	elif _active_period != null:
		intensity = _active_period.day_time_light_intensity if _is_day else _active_period.night_time_light_intensity
		min_intensity = _active_period.minimum_light_intensity
	else:
		intensity = _day_config.day_time_light_intensity if _is_day else _day_config.night_time_light_intensity
		min_intensity = _day_config.minimum_light_intensity
	return clampf(intensity * _get_light_intensity_percentage(), min_intensity, _MAX_LIGHT_INTENSITY_POSSIBLE)

## Returns the current sun rotation in degrees for the current frame.
## This is used automatically if the sun/environment is provided.
func get_sun_rotation() -> Vector3:
	var angle: float

	if (_is_day):
		# If it is the day, calculate from 0-180 for time
		var percentage: float = (_percentage_through_day - _sunrise_start_percentage) / (_sunset_start_percentage - _sunrise_start_percentage)
		angle = lerp(0, 180, percentage)
	else:
		var percentage: float
		# If it is the night, calculate from 180-360 for time
		if (_percentage_through_day >= _sunset_start_percentage):
			# Before the 24th hour
			var current: float = (_percentage_through_day - _sunset_start_percentage)
			var total: float = ((_sunrise_start_percentage + _FULL_DAY_PERCENTAGE) - _sunset_start_percentage)
			percentage =  current / total
		else:
			# NOTE: This is potential room for improvement here if we can look at tomorrows
			# Still night but after the 24th hour
			var current: float = _percentage_through_day + float(_FULL_DAY_PERCENTAGE) - _sunset_start_percentage
			var total: float = float(_FULL_DAY_PERCENTAGE) + _sunrise_start_percentage - _sunset_start_percentage
			percentage = (current / total)
		angle = lerp(180, 360, percentage)

	return Vector3(angle+ 180,0, 0)

## Returns [code]true[/code] if it is night time but before midnight, [code]false[/code] if it is day time or night time after midnight.
func is_night_before_midnight() -> bool:
	if is_day():
		return false
	return _percentage_through_day >= _sunset_start_percentage

## Returns a dictionary of the current reminders. This does not include any reminder before the current [GameTime].
## Because subscriptions to reminders are not persisted, they will be lost if the game/scene is closed and re-opened.
## This will give a list of the current reminders in order to resubscribe to them upon re-opening the game/scene.
## In order to restore the state, call [method create_reminders] with the normal reminders and the repeating reminders values from this dictionary.
func save_reminders() -> Dictionary:
	var reminders: Array[Variant] = []
	for reminder in _reminders.values():
		if reminder.time.is_after_or_same(_game_time_this_frame, TimeUnit.DAYS):
			reminders.append({"time":reminder.time.get_epoch(), "name":reminder.name})
	var repeating_reminders: Array[Variant] = []
	for reminder in _repeating_reminders.values():
		if reminder.time.is_after_or_same(_game_time_this_frame, TimeUnit.DAYS):
			repeating_reminders.append({"time":reminder.time.get_epoch(), "name":reminder.name})
	return {
		"reminders": reminders,
		"repeating_reminders": repeating_reminders,
	}

## Returns the current state of the [DayNightCycle] as a JSON string.
## [b]THIS DOES NOT INCLUDE REMINDERS.[/b]
## Use [method save_reminders] to save reminders as they need to be re-subscribed to and that cannot be done automatically.
## [br]The JSON formatted [String] can be used by the [method load_from_json] in order to restore the state of the [DayNightCycle].
func save() -> String:
	var save_object: Dictionary = {
		"game_version": _GAME_VERSION,
		"plugin_version": _PLUGIN_VERSION,
		"current_time": _game_time_this_frame.get_epoch(),
		"time_speed_multiplier": _time_speed_multiplier,
		"time_to_stop_multiplier": _time_to_stop_multiplier.get_epoch() if _time_to_stop_multiplier != null else null,
		"color_lerp_time": _color_lerp_time,
		"time_stopped": _time_stopped,
		"day_config": _day_config.save() if _day_config != null else default_day_config,
		"queued_day_config": _queued_day_config.save() if _queued_day_config != null else null,
		"scheduler": day_scheduler.save() if day_scheduler != null else null,
		"queued_scheduler": _queued_scheduler.save() if _queued_scheduler != null else null,
		"queued_day_config_overwrite": _queued_day_config_overwrite,
		"active_period": _active_period.save() if _active_period != null else null,
		"active_weather": _active_weather.save() if _active_weather != null else null,
		"day_period_index": _day_period_index,
	}
	return JSON.stringify(save_object)

## Loads the state of the [DayNightCycle] from a JSON formatted [String] created by the [method save] function.
## This will not restore the state of the reminders.
## This will error if the JSON is invalid.
## This could potentially error if the [code]game_version[/code] or [code]plugin_version[/code] in the JSON is invalid/does not match.
## Returns [code]true[/code] if successful, [code]false[/code] if not.
func load_from_json(data_string: String) -> bool:
	var data = JSON.parse_string(data_string)
	if not data is Dictionary:
		push_error("Invalid data type parsed from JSON! Expected: Dictionary - Got: " + str(typeof(data)))
		return false
	if data.get("game_version", "unknown") != _GAME_VERSION:
		push_error("Invalid game version! Expected: " + str(_GAME_VERSION) + " - Got: " + str(data.get("game_version", "unknown")))
		return false
	if data.get("plugin_version", "unknown") != _PLUGIN_VERSION:
		push_error("Invalid game version! Expected: " + str(_PLUGIN_VERSION) + " - Got: " + str(data.get("plugin_version", "unknown")))
		return false
	_game_time_this_frame = GameTime.new(data.get("current_time", 0))
	_time_speed_multiplier = data.get("time_speed_multiplier", default_time_speed_multiplier)
	_time_to_stop_multiplier = GameTime.new(data.get("time_to_stop_multiplier")) if data.get("time_to_stop_multiplier") != null else null
	_color_lerp_time = data.get("color_lerp_time", 0.0)
	_time_stopped = data.get("time_stopped", false)
	if data.get("day_config") != null:
		_day_config.load_from_json(data.get("day_config"))
	if data.get("queued_day_config") != null:
		_queued_day_config.load_from_json(data.get("queued_day_config", {}))
	if data.get("scheduler") != null:
		day_scheduler.load_from_json(data.get("scheduler", {}))
	if data.get("queued_scheduler") != null:
		_queued_scheduler.load_from_json(data.get("queued_scheduler", {}))
	_queued_day_config_overwrite = data.get("queued_day_config_overwrite", false)
	if data.get("active_period") != null:
		_active_period.load_from_json(data.get("active_period", {}))
	if data.get("active_weather") != null:
		_active_weather.load_from_json(data.get("active_weather", {}))
	_day_period_index = data.get("day_period_index", 0)
	set_time(_game_time_this_frame)
	return true

## This will remove a reminder at the specified [param time] and optionally the [param name].
## If [param name] is not specified, all reminders at that time will be removed.
func remove_reminder(time: GameTime, name: String = "") -> void:
	if _reminders.has(time.get_date_as_string()):
		if (name != "") && _reminders.get(time.get_date_as_string()).name == name:
			_reminders.erase(time.get_date_as_string())
	if _repeating_reminders.has(time.get_date_as_string()):
		if (name != "") && _repeating_reminders.get(time.get_date_as_string()).name == name:
			_repeating_reminders.erase(time.get_date_as_string())


	# If the reminder is for today, we need to remove it from the list of reminders for today
	if time.is_today(_game_time_this_frame):
		## If the time is for today, that means we have already populated the repeating reminder to tomorrow. It needs to be removed
		var tomorrow_time: GameTime = time.add_unit(1, TimeUnit.DAY)
		if _repeating_reminders.has(tomorrow_time.get_date_as_string()):
			if (name != "") && _repeating_reminders.get(tomorrow_time.get_date_as_string()).name == name:
				_repeating_reminders.erase(tomorrow_time.get_date_as_string())
		var new_reminders: Array = []
		for reminder in _todays_reminders:
			if !reminder.time.is_same_time(time):
				new_reminders.append(reminder)
		_todays_reminders = new_reminders
		_reset_reminders_for_today()

## This will remove all reminders with the given [param name].
## This is not an optimal way of removing reminders as it goes through every reminder to check its name (including reminders in the past).
## And it recalculates today's reminders as it cannot be sure that those reminders remain unchanged.
## Please use [method remove_reminder] instead as that specifies a key that allows removing reminders to be more efficient.
## But this is useful if you just want to remove all reminders with a specific [param name].
func remove_reminder_by_name(name: String) -> void:
	for key in _reminders:
		var value = _reminders[key]
		if value.name == name:
			_reminders.erase(key)
	for key in _repeating_reminders:
		var value = _repeating_reminders[key]
		if value.name == name:
			_repeating_reminders.erase(key)
	var new_reminders: Array = []
	for value in _todays_reminders:
		if value.name != name:
			new_reminders.append(value)
	_todays_reminders = new_reminders
	_reset_reminders_for_today()

## Removes the current [DayScheduler] if it is set.
## If [param remove_day_config] is true, it will also remove the current [DayConfig].
## If [param remove_day_config] is false, it will keep the current [DayConfig] which will be changed on the next day change.
func remove_current_scheduler(remove_day_config: bool = false) -> void:
	if day_scheduler == null:
		return
	if remove_day_config:
		remove_current_day_config()
	_end_current_scheduler()

## Sets the current [DayConfig] to the [DayNightCycle] default day config. See [method set_current_day_config] if you would like to change the current [DayConfig] to a different one.
## The the current [DayConfig] is the default [DayConfig], nothing will happen.
func remove_current_day_config() -> void:
	if _day_config.get_instance_id() == default_day_config.get_instance_id():
		return
	_day_config = default_day_config
	_on_day_config_change.on_next(_day_config)

## Removes the current [DayPeriodConfig] if it is set.
func remove_current_day_period() -> void:
	if _active_period == null:
		return
	_end_active_period()

## Removes the current [WeatherConfig] if it is set. This does not change the the current [DayPeriodConfig].
## See [method remove_current_day_period] if you would like to end the current [DayPeriodConfig].
func remove_current_weather() -> void:
	if _active_weather == null:
		return
	_end_active_weather()

## Creates a reminder at the specified [param time] with the specified [param name].
## If [param repeating] is true, it will create a repeating reminder, which will repeat every day at the specified [param time].
## This returns an [Observable] that emits when the reminder is triggered.
func create_reminder(time: GameTime,name: String, repeating: bool = false) -> Observable:
	var observable: Subject = Subject.new()
	if repeating:
		if not _repeating_reminders.has(time.get_date_as_string()):
			_repeating_reminders[time.get_date_as_string()] = []
		_repeating_reminders[time.get_date_as_string()].append({"observable": observable, "time": time, "name": name})
	else:
		if not _reminders.has(time.get_date_as_string()):
			_reminders[time.get_date_as_string()] = []
		_reminders[time.get_date_as_string()].append({"observable": observable, "time": time, "name": name})

	# If the reminder is for today and is after now, we need to add it to the list of reminders for today
	if time.is_today(_game_time_this_frame) and time.is_after(_game_time_this_frame):
		if repeating:
			var new_time: GameTime = time.add_unit(1, TimeUnit.DAY)
			if not _repeating_reminders.has(new_time.get_date_as_string()):
				_repeating_reminders[new_time.get_date_as_string()] = []
			_repeating_reminders[new_time.get_date_as_string()].append({"observable": observable, "time": new_time, "name": name})
		_todays_reminders.append({"observable": observable, "time": time, "name": name})
		_reset_reminders_for_today()

	return observable.as_observable()

## Changes the time speed multiplier to the specified [param time_multiplier].
## If [param time_multiplier] is less than 0.1, it will log an error and not change the time speed.
## If [param time_multiplier] is greater than the [DayNightCycle] constant _MAX_TIME_MULTIPLIER, it will log an error and not change the time speed.
## If [param time_to_stop_at] is specified, the time speed multiplier will be reset to the default time speed on the first tick past the specified [param time_to_stop_at].
## If [param time_to_stop_at] is specified and the time is before the current [GameTime], it will log an error and not change the time speed.
func alter_time_speed(time_multiplier: float, time_to_stop_at: GameTime = null)-> void:
	if time_multiplier < 0.1:
		push_error("Invalid time multiplier: " + str(time_multiplier))
		return
	if time_multiplier > _MAX_TIME_MULTIPLIER:
		push_error("Cannot multiply time speed beyond: " + str(_MAX_TIME_MULTIPLIER))
		return
	if time_to_stop_at != null:
		if(time_to_stop_at.is_before_or_same(_game_time_this_frame)):
			push_error("Must set time to stop at a time after the current time: Current Time[ " + _game_time_this_frame.get_date_as_string()+ " | " + _game_time_this_frame.get_time_as_string() + " ] - Time to stop at [ " + time_to_stop_at.get_date_as_string()+ " | " + time_to_stop_at.get_time_as_string() + " ]")
			return
		_time_to_stop_multiplier = time_to_stop_at
	_on_time_speed_change.on_next(time_multiplier)
	_time_speed_multiplier = time_multiplier

## Resets the time speed multiplier to the default.
## If [param should_fire_time_speed_end_event] is [code]true[/code], it will fire the time speed end event
func reset_default_time_speed(should_fire_time_speed_end_event: bool = false) -> void:
	if should_fire_time_speed_end_event:
		_on_time_speed_end.on_next(_game_time_this_frame)
	alter_time_speed(default_time_speed_multiplier)

## Sorts and sets todays reminders
func _populate_reminders(time: GameTime) -> void:
	_todays_reminders.clear()
	_reminder_index=0
	if _reminders.has(time.get_date_as_string()):
		for reminder in _reminders[time.get_date_as_string()]:
			_todays_reminders.append(reminder)
	if _repeating_reminders.has(time.get_date_as_string()):
		for reminder in _repeating_reminders[time.get_date_as_string()]:
			_todays_reminders.append(reminder)
			var new_time = reminder.time.add_unit(1, TimeUnit.DAY)
			if not _repeating_reminders.has(new_time.get_date_as_string()):
				_repeating_reminders[new_time.get_date_as_string()] = []
			_repeating_reminders[new_time.get_date_as_string()].append({"observable": reminder.observable, "time": new_time, "name": reminder.name})
	_todays_reminders.sort_custom(func(a, b): return a.time.get_epoch() < b.time.get_epoch())

## Will emit any potential reminder fo rthis frame
func _send_potential_reminders() -> void:
	if (_todays_reminders.size() > 0) and (_reminder_index < _todays_reminders.size()):
		if _todays_reminders[_reminder_index].time.is_before(_game_time_this_frame):
			_todays_reminders[_reminder_index].observable.on_next(_todays_reminders[_reminder_index].name)
			_reminder_index += 1

## Will update the day state as to whether it is day or night. In addition, will update if we are in a [DayPeriodConfig] or have left one
func _update_day_state():
	if (_percentage_through_day < _sunset_start_percentage) && (_percentage_through_day > _sunrise_start_percentage):
		if not _is_day:
			# Just turned day
			_color_lerp_time = 0
			_is_day = true
			_on_day_time_start.on_next(GameTime.new(_game_time_this_frame.get_epoch()))
		else:
			var delete_me
			#it has been day
			# DO NOTHING FOR NOW
	else:
		if _is_day:
			# just turned night
			_color_lerp_time = 0
			_is_day = false
			_on_night_time_start.on_next(GameTime.new(_game_time_this_frame.get_epoch()))
		else:
			var delete_me
			# it has been night
			# DO NOTHING FOR NOW

	if _has_day_periods:
		if (_day_period_index < _day_config.day_periods.size()) && _game_time_this_frame.is_after_or_same(_day_config.day_periods[_day_period_index].get_start_time(_game_time_this_frame.get_year(), _game_time_this_frame.get_day())):
			_set_active_period(_day_config.day_periods[_day_period_index])
			_day_period_index =  _day_period_index + 1
	if _active_period != null:
		if _game_time_this_frame.is_after_or_same(_active_period.get_end_time(_game_time_this_frame.get_year(), _game_time_this_frame.get_day())):
			_end_active_period()

## Returns the percentage of that the light intensity should be in relation to its peak intensity at the current time
func _get_light_intensity_percentage() -> float:
	if _is_day:
		if _game_time_this_frame.is_before(_middle_of_day_time):
			return GameTime.percent_between(_game_time_this_frame, _sunrise_today, _middle_of_day_time)
		else:
			return GameTime.inverted_percent_between(_game_time_this_frame, _middle_of_day_time, _sunset_today)
	else:
		if _game_time_this_frame.is_before(_sunrise_today):
			# We transitioned to night after midnight, se we should use yesterdays values
			if _game_time_this_frame.is_before(_middle_of_night_begin):
				return GameTime.percent_between(_game_time_this_frame, _sunset_yesterday, _middle_of_night_begin)
			else:
				return GameTime.inverted_percent_between(_game_time_this_frame, _middle_of_night_begin, _sunset_today)
		else:
			# We are night before midnight, so we should use todays values
			if _game_time_this_frame.is_before(_middle_of_night_end):
				return GameTime.percent_between(_game_time_this_frame, _sunset_today, _middle_of_night_end)
			else:
				return GameTime.inverted_percent_between(_game_time_this_frame, _middle_of_night_end, _sunrise_tomorrow)

## Sets the active period to the [param period].
func _set_active_period(period: DayPeriodConfig) -> void:
	_color_lerp_time = 0
	if _active_period != null:
		if _active_weather != null:
			_end_active_weather()
		_on_day_period_overwrite.on_next({"old_period": _active_period, "new_period": _day_config.day_periods[_day_period_index]})
	_active_period = period
	_on_day_period_start.on_next(period)

	if _active_period.has_weather():
		var possible_weather: WeatherConfig = _active_period.pick_weather()
		if (possible_weather != null) && possible_weather.should_trigger():
			_active_weather = possible_weather
			_on_weather_start.on_next(_active_weather)

## This will end the active period.
## This assumes that there is an active period to avoid double checking the same thing
func _end_active_period() -> void:
	if _active_weather != null:
		_end_active_weather()
	var old_period: DayPeriodConfig = _active_period
	_active_period = null
	_on_day_period_end.on_next(old_period)
	_color_lerp_time = 0

## This will end the active weather.
## This assumes that there is active weather to avoid double checking the same thing
func _end_active_weather() -> void:
	var old_weather: WeatherConfig = _active_weather
	_active_weather = null
	_on_weather_end.on_next(old_weather)

## This will end the active scheduler.
## This assumes that there is an active scheduler to avoid double checking the same thing
func _end_current_scheduler() -> void:
	var old_scheduler: DayScheduler = day_scheduler
	day_scheduler = null
	_on_day_scheduler_finish.on_next(old_scheduler)

## Returns the percentage of progress through the current day (midnight to midnight)
func _calculate_percent_of_day_by_time(time: GameTime) -> float:
	var milliseconds_passed: int = time.get_epoch() - _current_date_at_start_of_day.get_epoch()
	var percentage: float = float(milliseconds_passed) / float(GameTime.MILLISECONDS_IN_DAY)
	while percentage < 0:
		percentage = 1 + percentage
	return percentage

## Returns the [GameTime] representation for the current frame
func _calculate_game_time_for_frame() -> GameTime:
	var milliseconds_so_far: int = _percentage_through_day * GameTime.MILLISECONDS_IN_DAY
	return GameTime.new(_current_date_at_start_of_day.get_epoch() + milliseconds_so_far)

## Handles the time speed ending if the time to stop multiplier is set and
func _handle_time_speed():
	if (_time_to_stop_multiplier != null) && (_game_time_this_frame.is_after_or_same(_time_to_stop_multiplier)):
		_time_to_stop_multiplier = null
		reset_default_time_speed(true)

## This is called when the day changes to set up the values for the next day
func _handle_day_end():
	_yesterday = _day_config
	var old_start_of_date = GameTime.new(_current_date_at_start_of_day.get_epoch())
	_current_date_at_start_of_day = _current_date_at_start_of_day.add_unit(1, TimeUnit.DAY)
	_current_date_at_end_of_day = GameTime.create_from_instant(Instant.new(
		_current_date_at_start_of_day.get_year(),
		_current_date_at_start_of_day.get_day(),
		23,
		59,
		59,
		999
	))
	_day_period_index = 0
	if(day_scheduler != null):
		if has_queued_day_config():
			set_day_config(_queued_day_config)
			remove_queued_day_config()
			if _queued_day_config_overwrite && !day_scheduler.is_done():
				day_scheduler.advance_day_config()
		else:
			set_day_config(day_scheduler.advance_and_get_day_config())
		if day_scheduler.is_done():
			_end_current_scheduler()
			if has_queued_scheduler():
				set_new_scheduler(_queued_scheduler)
				remove_queued_scheduler()
	else:
		if has_queued_day_config():
			set_day_config(_queued_day_config)
			remove_queued_day_config()
		elif _day_config.get_instance_id() != default_day_config.get_instance_id():
			set_day_config(default_day_config)

	_queued_day_config_overwrite = false
	if (_day_config != null) && (_day_config.day_periods != null):
		_has_day_periods = true
		_day_config.day_periods.sort_custom(func(a, b): return a.start_time < b.start_time)
	else:
		_has_day_periods = false

	_percentage_through_day -= _FULL_DAY_PERCENTAGE
	_sunrise_start_percentage = _calculate_percent_of_day_by_time(GameTime.create_from_instant(_day_config.get_sunrise()))
	_sunset_start_percentage = _calculate_percent_of_day_by_time(GameTime.create_from_instant(_day_config.get_sunset()))

	_game_time_this_frame = _calculate_game_time_for_frame()
	_calculate_milestone_times()
	_on_day_change.on_next(_current_date_at_start_of_day)
	if not _current_date_at_start_of_day.is_same_unit(old_start_of_date, TimeUnit.YEARS):
		_on_year_change.on_next(_current_date_at_start_of_day)
	if _percentage_through_day >= _FULL_DAY_PERCENTAGE:
		_handle_day_end()

## This calculates the milestone times for the current day.
## These are times that do not change during the day so we don't want to waste effort calulating them every frame
func _calculate_milestone_times() -> void:
	if day_scheduler != null:
		var yesterday_sunset: GameTime
		if _yesterday != null:
			yesterday_sunset = _yesterday.get_sunset_time().set_unit(_game_time_this_frame.get_year(), TimeUnit.YEAR, true).set_unit(_game_time_this_frame.get_day(), TimeUnit.DAY, true).subtract_unit(1, TimeUnit.DAY)
		else:
			if day_scheduler.should_repeat:
				yesterday_sunset = day_scheduler.get_previous_day_config().get_sunset_time().set_unit(_game_time_this_frame.get_year(), TimeUnit.YEAR, true).set_unit(_game_time_this_frame.get_day(), TimeUnit.DAY, true).subtract_unit(1, TimeUnit.DAY)
			else:
				# We default to the default day config is the scheduler does not repeat
				yesterday_sunset = default_day_config.get_sunset_time().set_unit(_game_time_this_frame.get_year(), TimeUnit.YEAR, true).set_unit(_game_time_this_frame.get_day(), TimeUnit.DAY, true).subtract_unit(1, TimeUnit.DAY)
		var tomorrow_sunrise: GameTime
		if day_scheduler.is_done():
			# We default to the default day config if the scheduler is done
			tomorrow_sunrise = default_day_config.get_sunrise_time().set_unit(_game_time_this_frame.get_year(), TimeUnit.YEAR, true).set_unit(_game_time_this_frame.get_day(), TimeUnit.DAY, true).add_unit(1, TimeUnit.DAY)
		else:
			tomorrow_sunrise = day_scheduler.get_next_day_config().get_sunrise_time().set_unit(_game_time_this_frame.get_year(), TimeUnit.YEAR, true).set_unit(_game_time_this_frame.get_day(), TimeUnit.DAY, true).add_unit(1, TimeUnit.DAY)
		_sunset_yesterday = yesterday_sunset
		_sunrise_tomorrow = tomorrow_sunrise
		_sunrise_today = day_scheduler.get_current_day_config().get_sunrise_time().set_unit(_game_time_this_frame.get_year(), TimeUnit.YEAR, true).set_unit(_game_time_this_frame.get_day(), TimeUnit.DAY, true)
		_sunset_today = day_scheduler.get_current_day_config().get_sunset_time().set_unit(_game_time_this_frame.get_year(), TimeUnit.YEAR, true).set_unit(_game_time_this_frame.get_day(), TimeUnit.DAY, true)
		_middle_of_day_time = GameTime.new((_sunrise_today.get_epoch() + _sunset_today.get_epoch()) / 2)
		_middle_of_night_begin = GameTime.new((_sunset_yesterday.get_epoch() + _sunrise_today.get_epoch()) / 2)
		_middle_of_night_end = GameTime.new((_sunset_today.get_epoch() + _sunrise_tomorrow.get_epoch()) / 2)
		return
	# We need to calculate based off of the set day config
	var yesterday_sunset: GameTime
	if _yesterday != null:
		yesterday_sunset = _yesterday.get_sunset_time().set_unit(_game_time_this_frame.get_year(), TimeUnit.YEAR, true).set_unit(_game_time_this_frame.get_day(), TimeUnit.DAY, true).subtract_unit(1, TimeUnit.DAY)
	else:
		yesterday_sunset = _day_config.get_sunset_time().set_unit(_game_time_this_frame.get_year(), TimeUnit.YEAR, true).set_unit(_game_time_this_frame.get_day(), TimeUnit.DAY, true).subtract_unit(1, TimeUnit.DAY)
	_sunset_yesterday = yesterday_sunset
	_sunrise_tomorrow = _day_config.get_sunrise_time().set_unit(_game_time_this_frame.get_year(), TimeUnit.YEAR, true).set_unit(_game_time_this_frame.get_day(), TimeUnit.DAY, true).add_unit(1, TimeUnit.DAY)
	_sunrise_today = _day_config.get_sunrise_time().set_unit(_game_time_this_frame.get_year(), TimeUnit.YEAR, true).set_unit(_game_time_this_frame.get_day(), TimeUnit.DAY, true)
	_sunset_today = _day_config.get_sunset_time().set_unit(_game_time_this_frame.get_year(), TimeUnit.YEAR, true).set_unit(_game_time_this_frame.get_day(), TimeUnit.DAY, true)
	_middle_of_day_time = GameTime.new((_sunrise_today.get_epoch() + _sunset_today.get_epoch()) / 2)
	_middle_of_night_begin = GameTime.new((_sunset_yesterday.get_epoch() + _sunrise_today.get_epoch()) / 2)
	_middle_of_night_end = GameTime.new((_sunset_today.get_epoch() + _sunrise_tomorrow.get_epoch()) / 2)

## This is called when we create/remove a reminder for today in order to reset the sorting and reminder index
func _reset_reminders_for_today() -> void:
	_reminder_index = 0
	if _todays_reminders.size() <= 0:
		return
	_todays_reminders.sort_custom(func(a, b): return a.time.get_epoch() < b.time.get_epoch())
	while _todays_reminders[_reminder_index].time.is_before(_game_time_this_frame):
		_reminder_index += 1
