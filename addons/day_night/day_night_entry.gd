@tool
extends EditorPlugin


const NODE_NAME: String = "DayNightCycle"
const INHERITANCE: String = "Node"
const NODE_SCRIPT: Script = preload("res://addons/day_night/day_night_cycle.gd")
const NODE_ICON: Texture2D = preload("res://addons/day_night/sun-logo.svg")


func _enter_tree() -> void:
	# Add DayNightCycle-Node to the scene
	add_custom_type(NODE_NAME, INHERITANCE, NODE_SCRIPT, NODE_ICON)


func _exit_tree() -> void:
	# Remove DayNightCycle-Node to the scene
	remove_custom_type(NODE_NAME)
