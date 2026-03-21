@icon("res://addons/day_night/weather-logo.svg")
extends Resource
class_name WeatherConfig

## This [Resource] represents a weather configuration that can be used in a [DayPeriodConfig].
## It has the configurable properties for a weather effect to be triggered in a [DayPeriodConfig]; like the color and intensity of the light, a path to a node that contains the weather effect, etc.
## [br][br] Usage:
## [br]NOTE: This is primarily meant to be created from the "Create New > Resource" context menu in the Godot Editor
## [codeblock]
## var weather_condition = WeatherConfig.new()
## weather_condition.weather_path = "res://addons/day_night/resources/weather_effects/Clouds.tscn" # Example Path
## weather_condition.weather_weight = 1
## weather_condition.weather_chance = 1
## weather_condition.day_time_weather_color = Color(.9922,.9843,.8275,1)
## weather_condition.day_time_light_intensity = 1
## weather_condition.night_time_weather_color = Color(0,0,0,1)
## weather_condition.night_time_light_intensity = 0
## weather_condition.minimum_light_intensity = 0.01
## [/codeblock]

@export_category("Weather Configuration")

## The path to the node that contains the weather condition if picked and triggered
@export var weather_condition: NodePath

## How likely this weather conditon is to be picked from the possible weather conditions in a [DayPeriodConfig]. Higher value = more likely
@export_range(0,1000,1) var weather_weight: int = 1
## If picked, how likely this weather condition is to trigger. Higher value = more likely
@export_range(0,1,0.01) var weather_chance: float = 1

@export_group("Weather Lighting")
## The day time lighting color that will be used if this weather condition is picked and triggered
@export_color_no_alpha() var day_time_weather_color: Color
## The light intensity during the day that will be used if this weather condition is picked and triggered
@export_range(0,16,.01) var day_time_light_intensity: float = 2
## The day time lighting color that will be used if this weather condition is picked and triggered
@export_color_no_alpha() var night_time_weather_color: Color
## The light intensity during the night that will be used if this weather condition is picked and triggered
@export_range(0,16,.01) var night_time_light_intensity: float = .8
## The the lowest the light intensity can be if this weather condition is picked and triggered
@export_range(0,16,.01) var minimum_light_intensity: float = .1

## Returns [code]true[/code] if this weather condition should be triggered, [code]false[/code] otherwise.
func should_trigger() -> bool:
	return randf() < weather_chance

## Returs a JSON string of the weather config state
func save() -> String:
	return JSON.stringify({
		"weather_path": weather_condition,
		"weather_weight": weather_weight,
		"weather_chance": weather_chance,
		"day_time_weather_color": day_time_weather_color.to_html(),
		"day_time_light_intensity": day_time_light_intensity,
		"night_time_weather_color": night_time_weather_color.to_html(),
		"night_time_light_intensity": night_time_light_intensity,
		"minimum_light_intensity": minimum_light_intensity
	})

## Loads the weather config state from a JSON string
func load_from_json(data_string: String) -> void:
	var data = JSON.parse_string(data_string)
	if not data is Dictionary:
		push_error("Invalid data type parsed from JSON! Expected: Dictionary - Got: " + str(typeof(data)))
		return
	weather_condition = data.get("weather_path", weather_condition)
	weather_weight = data.get("weather_weight", weather_weight)
	weather_chance = data.get("weather_chance", weather_chance)
	day_time_weather_color = Color.from_string(data.get("day_time_weather_color"), Color.WHITE)
	day_time_light_intensity = data.get("day_time_light_intensity", day_time_light_intensity)
	night_time_weather_color = Color.from_string(data.get("night_time_weather_color"), Color.STEEL_BLUE)
	night_time_light_intensity = data.get("night_time_light_intensity", night_time_light_intensity)
	minimum_light_intensity = data.get("minimum_light_intensity", minimum_light_intensity)
