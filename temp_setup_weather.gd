extends SceneTree

func _init() -> void:
	print("Generating DayConfig resources...")
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("Resources/weather_system"):
		var err = dir.make_dir_recursive("Resources/weather_system")
		if err != OK:
			push_error("Failed to create Resources/weather_system directory")

	# Create Weathers
	var clear_weather = preload("res://addons/day_night/resources/scripts/weather_config.gd").new()
	clear_weather.weather_weight = 10
	clear_weather.weather_chance = 0.8
	clear_weather.day_time_weather_color = Color(1.0, 0.95, 0.85)
	clear_weather.day_time_light_intensity = 1.0
	clear_weather.night_time_weather_color = Color(0.15, 0.15, 0.3)
	clear_weather.night_time_light_intensity = 0.1
	clear_weather.minimum_light_intensity = 0.05
	ResourceSaver.save(clear_weather, "res://Resources/weather_system/clear_weather.tres")

	var cloudy_weather = clear_weather.duplicate()
	cloudy_weather.weather_weight = 5
	cloudy_weather.weather_chance = 0.5
	cloudy_weather.day_time_weather_color = Color(0.7, 0.75, 0.8)
	cloudy_weather.day_time_light_intensity = 0.6
	cloudy_weather.night_time_weather_color = Color(0.1, 0.1, 0.2)
	cloudy_weather.night_time_light_intensity = 0.05
	ResourceSaver.save(cloudy_weather, "res://Resources/weather_system/cloudy_weather.tres")
	
	var rain_weather = cloudy_weather.duplicate()
	rain_weather.weather_weight = 2
	rain_weather.weather_chance = 0.2
	rain_weather.day_time_weather_color = Color(0.5, 0.55, 0.6)
	rain_weather.day_time_light_intensity = 0.4
	ResourceSaver.save(rain_weather, "res://Resources/weather_system/light_rain_weather.tres")

	# Create Periods
	var morning_period = preload("res://addons/day_night/resources/scripts/day_period_config.gd").new()
	morning_period.period_name = "Morning"
	morning_period.start_hour = 6
	morning_period.length_hour = 6
	morning_period.day_time_period_color = Color(1.0, 0.8, 0.6)
	morning_period.night_time_period_color = Color(0.2, 0.2, 0.4)
	morning_period.day_time_light_intensity = 0.8
	morning_period.night_time_light_intensity = 0.1
	morning_period.minimum_light_intensity = 0.05
	morning_period.possible_weather = [clear_weather, cloudy_weather]
	ResourceSaver.save(morning_period, "res://Resources/weather_system/morning_period.tres")

	var afternoon_period = preload("res://addons/day_night/resources/scripts/day_period_config.gd").new()
	afternoon_period.period_name = "Afternoon"
	afternoon_period.start_hour = 12
	afternoon_period.length_hour = 6
	afternoon_period.day_time_period_color = Color(1.0, 0.98, 0.92)
	afternoon_period.night_time_period_color = Color(0.2, 0.2, 0.4)
	afternoon_period.day_time_light_intensity = 1.2
	afternoon_period.night_time_light_intensity = 0.1
	afternoon_period.minimum_light_intensity = 0.05
	afternoon_period.possible_weather = [clear_weather, cloudy_weather, rain_weather]
	ResourceSaver.save(afternoon_period, "res://Resources/weather_system/afternoon_period.tres")

	var evening_period = preload("res://addons/day_night/resources/scripts/day_period_config.gd").new()
	evening_period.period_name = "Evening"
	evening_period.start_hour = 18
	evening_period.length_hour = 4
	evening_period.day_time_period_color = Color(1.0, 0.5, 0.15)
	evening_period.night_time_period_color = Color(0.15, 0.15, 0.3)
	evening_period.day_time_light_intensity = 0.7
	evening_period.night_time_light_intensity = 0.1
	evening_period.minimum_light_intensity = 0.05
	evening_period.possible_weather = [clear_weather, cloudy_weather]
	ResourceSaver.save(evening_period, "res://Resources/weather_system/evening_period.tres")

	# Create Day Config
	var cozy_day = preload("res://addons/day_night/resources/scripts/day_config.gd").new()
	cozy_day.day_name = "Cozy Day"
	cozy_day.day_weight = 1
	cozy_day.day_color = Color(1.0, 0.95, 0.85)
	cozy_day.day_time_light_intensity = 1.0
	cozy_day.night_color = Color(0.15, 0.15, 0.3)
	cozy_day.night_time_light_intensity = 0.1
	cozy_day.minimum_light_intensity = 0.05
	cozy_day.sunrise_hour = 6
	cozy_day.sunset_hour = 18
	cozy_day.day_periods = [morning_period, afternoon_period, evening_period]
	ResourceSaver.save(cozy_day, "res://Resources/weather_system/cozy_day_config.tres")

	print("Successfully generated all weather resources!")
	quit()
