@icon("res://addons/day-config-logo.svg")
extends Resource
class_name DayConfig

## This [Resource] represents a day configuration that can be used in a [DayScheduler] or [DayNightCycle].
## It has the configurable properties for the day configuration; like the color and intensity of the light, the time of milestones of the day, etc.
## [br][br] Usage:
## [br]NOTE: This is primarily meant to be created from the "Create New > Resource" context menu in the Godot Editor
## [codeblock]
## var day_config = DayConfig.new()
## day_config.day_name = "Day 1"
## day_config.day_weight = 1
## day_config.day_color = Color(.9922,.9843,.8275,1)
## day_config.day_time_light_intensity = 1
## day_config.night_color = Color(.2320,.2956,.4724,1)
## day_config.night_time_light_intensity = 0.05
## day_config.minimum_light_intensity = 0.01
## day_config.sunrise_hour = 6
## day_config.sunset_hour = 18
## day_config.day_periods = []
## [/codeblock]

## This is the maximum light intensity that can be set
const _MAX_LIGHT_INTENSITY_POSSIBLE: float = 16.0

@export_category("Day Configuration")

## This is a name for this day configuration
@export_placeholder("Some Nickname") var day_name: String
## How likely this day config is to be picked from the possible day configs in a scheduler. Higher value = more likely
@export_range(1,1000,1) var day_weight: int = 1

@export_group("Light Configuration")
## The color of the day time light
@export_color_no_alpha() var day_color: Color = Color(.9922,.9843,.8275,1)
## The peak light intensity of the day time light
@export_range(0,_MAX_LIGHT_INTENSITY_POSSIBLE,0.01) var day_time_light_intensity: float = 1
## The color of the night time light
@export_color_no_alpha() var night_color: Color = Color(.2320,.2956,.4724,1)
## The peak light intensity of the night time light
@export_range(0,_MAX_LIGHT_INTENSITY_POSSIBLE,0.01) var night_time_light_intensity: float = 0.05
## The minimum light intensity that is allowed at any point in the day
@export_range(0,_MAX_LIGHT_INTENSITY_POSSIBLE,0.01) var minimum_light_intensity: float = 0.01

@export_group("Sunrise Time")
## The hour of the sunrise time. Clamped between 0-23
@export_range(0,23) var sunrise_hour: int = 0 :
	set(value):
		sunrise_hour = clamp(value,0,23)
## The minute of the sunrise time. Clamped between 0-59
@export_range(0,59) var sunrise_minute: int = 0 :
	set(value):
		sunrise_minute = clamp(value,0,59)
## The second of the sunrise time. Clamped between 0-59
@export_range(0,59) var sunrise_second: int = 0 :
	set(value):
		sunrise_second = clamp(value,0,59)
## The millisecond of the sunrise time. Clamped between 0-999
@export_range(0,999) var sunrise_millisecond: int = 0 :
	set(value):
		sunrise_millisecond = clamp(value,0,999)

@export_group("Sunset Time")
## The hour of the sunset time. Clamped between sunrise_hour-23
@export_range(0,23) var sunset_hour: int = 0 :
	set(value):
		sunset_hour = clamp(value,sunrise_hour,23)
## The minute of the sunset time. Clamped between sunrise_minute-59
@export_range(0,59) var sunset_minute: int = 0 :
	set(value):
		var min_value: int = sunrise_minute if sunset_hour == sunrise_hour else 0
		sunset_minute = clamp(value,min_value,59)
## The second of the sunset time. Clamped between sunrise_second-59
@export_range(0,59) var sunset_second: int = 0 :
	set(value):
		var min_value: int = sunrise_second if sunset_minute == sunrise_minute else 0
		sunset_second = clamp(value,min_value,59)
## The millisecond of the sunset time. Clamped between sunrise_millisecond-999
@export_range(0,999) var sunset_millisecond: int = 0 :
	set(value):
		var min_value: int = sunrise_millisecond if sunset_second == sunrise_second else 0
		sunset_millisecond = clamp(value,min_value,999)

@export_group("Day Periods")
## The possible day periods that can be set
@export var day_periods: Array[DayPeriodConfig] = []

## Returns the day name
func get_day_name() -> String:
	return day_name

## Returns the day color
func get_day_time_color() -> Color:
	return day_color

## Returns the night color
func get_night_time_color() -> Color:
	return night_color

## Returns an [Instant] representing the sunrise time
func get_sunrise() -> Instant:
	return Instant.new(0,0,sunrise_hour,sunrise_minute,sunrise_second,sunrise_millisecond)

## Returns a [GameTime] representing the sunrise time
func get_sunrise_time() -> GameTime:
	return GameTime.create_from_instant(get_sunrise())

## Returns an [Instant] representing the sunset time
func get_sunset() -> Instant:
	return Instant.new(0,0,sunset_hour,sunset_minute,sunset_second,sunset_millisecond)

## Returns a [GameTime] representing the sunset time
func get_sunset_time() -> GameTime:
	return GameTime.create_from_instant(get_sunset())

## Returns a JSON string of the day config state
func save() -> String:
	return JSON.stringify({
		"day_name": day_name,
		"day_color": day_color,
		"day_time_light_intensity": day_time_light_intensity,
		"night_color": night_color,
		"night_time_light_intensity": night_time_light_intensity,
		"minimum_light_intensity": minimum_light_intensity,
		"sunrise_hour": sunrise_hour,
		"sunrise_minute": sunrise_minute,
		"sunrise_second": sunrise_second,
		"sunrise_millisecond": sunrise_millisecond,
		"sunset_hour": sunset_hour,
		"sunset_minute": sunset_minute,
		"sunset_second": sunset_second,
		"sunset_millisecond": sunset_millisecond,
		"day_periods": day_periods.map(func(day_period_config: DayPeriodConfig): return day_period_config.save())
	})

## Loads the day config from a JSON string
func load_from_json(data_string: String) -> void:
	var data = JSON.parse_string(data_string)
	if not data is Dictionary:
		push_error("Invalid data type parsed from JSON! Expected: Dictionary - Got: " + str(typeof(data)))
		return
	day_name = data["day_name"]
	day_color = data["day_color"]
	night_color = data["night_color"]
	day_time_light_intensity = data["day_time_light_intensity"]
	night_time_light_intensity = data["night_time_light_intensity"]
	minimum_light_intensity = data["minimum_light_intensity"]
	sunrise_hour = data["sunrise_hour"]
	sunrise_minute = data["sunrise_minute"]
	sunrise_second = data["sunrise_second"]
	sunrise_millisecond = data["sunrise_millisecond"]
	sunset_hour = data["sunset_hour"]
	sunset_minute = data["sunset_minute"]
	sunset_second = data["sunset_second"]
	sunset_millisecond = data["sunset_millisecond"]
	day_periods = []
	for day_config_string in data.get("day_configs", []):
		var new_day_period: DayPeriodConfig = DayPeriodConfig.new()
		new_day_period.load_from_json(day_config_string)
		day_periods.append(new_day_period)
