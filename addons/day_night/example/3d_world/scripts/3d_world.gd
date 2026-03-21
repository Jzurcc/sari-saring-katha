extends Node

@onready var date_label: Label = $Date
@onready var time_label: Label = $Time
@onready var time_multiplier_label: Label = $TimeMultiplier
@onready var sun_intensity_label: Label = $"Sun intensity"

@onready var day_night: DayNightCycle = get_node("DayNightCycle")


func _process(delta: float) -> void:
	date_label.text = "Year: " +  str(day_night.get_time_this_frame().get_year()) + " / Day: " + str(day_night.get_time_this_frame().get_day())
	time_label.text = day_night.get_time_this_frame().get_time_as_string()
	time_multiplier_label.text = str(day_night.get_time_speed_multiplier())
	sun_intensity_label.text = str(day_night.calculate_light_intesity())
