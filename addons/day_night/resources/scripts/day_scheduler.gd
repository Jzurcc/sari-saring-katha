@icon("res://addons/day_night/scheduler-logo.svg")
extends Resource
class_name DayScheduler

@export_category("Scheduler Configuration")
@export_placeholder("Some Nickname") var scheduler_name: String

@export_group("Scheduler Settings")
## If this is checked the scheduler will repeat itself instead of stopping
@export var should_repeat: bool = false
## This is home many repeating cycles before and after to generate in order to retrieve the previous/next day configurations past the bounds
@export_range(0,100,1) var buffer_size: int = 1

@export_group("Day Configurations")
@export_enum("In Order", "Random In Order","Weighted Random Pick", "Random Pick") var selection_type: String = "In Order"
@export var day_configs: Array[DayConfig] = []

func _ready() -> void:
	verify()

var _index: int = -1
var _ordered_config_indexes: Array[int] = []

func verify() -> void:
	assert(day_configs.size() > 0, "At least one day config is required in a scheduler!")

func is_done() -> bool:
	if should_repeat:
		return false
	return is_last()

func is_last() -> bool:
	return (get_current_index() + 1) > day_configs.size() - 1

func advance_and_get_day_config() -> DayConfig:
	if is_done():
		return null
	advance_day_config()
	return get_at_index(_index)

func advance_day_config() -> void:
	if is_done():
		return
	_index = (_index + 1)
	if _index >= day_configs.size():
		_create_ordered_config_indexes()
		print(str(_ordered_config_indexes))
		_index = 0

func get_previous_day_config() -> DayConfig:
	if not should_repeat:
		return get_at_index(get_current_index() -1) if get_current_index() > 0 else null

	return get_at_index(get_current_index() - 1)

func get_next_day_config() -> DayConfig:
	if not should_repeat:
		return get_at_index(get_current_index() + 1) if !is_done() else null

	return get_at_index(get_current_index() + 1)

func get_current_day_config() -> DayConfig:
	return get_at_index(get_current_index())

## Can access the day config at the given index. The scheduler saves the previous array iteration the next array iteration in addition to the current array when it repeats.
## Any index outside the bounds of the size of the day config size will look in the next array if positive and the previous array if negative.
## The index is always modulated to the size of the config array minus 1 so any int can be passed in. Note that when repeating, you will need to specify the correct index in order to get the correct days
func get_at_index(index: int) -> DayConfig:
	if _ordered_config_indexes.size() == 0:
		_create_ordered_config_indexes()
	if !should_repeat:
		return day_configs[index]
	return day_configs[_ordered_config_indexes[index + (day_configs.size() * buffer_size)]]

func get_ordered_day_configs() -> Array[DayConfig]:
	var configs: Array[DayConfig] = []
	for index in _ordered_config_indexes:
		configs.append(day_configs[index])
	return configs

func get_current_index() -> int:
	# We take the max here as we start at -1 so the first advance returns 0
	return max(_index, 0)

func reset_index(value: int = 0) -> void:
	_index = clampi(value, 0, day_configs.size() - 1)

func save() -> String:
	# TODO relook at
	return JSON.stringify({
		"length": day_configs.size(),
		"config_indexes": _ordered_config_indexes,
		"index": _index,
		"name": scheduler_name,
		"should_repeat": should_repeat,
		"buffer_size": buffer_size,
		"selection_type": selection_type,
		"day_configs": day_configs.map(func(day_config): day_config.save()),
	})

func load_from_json(data_string: String) -> void:
	var data = JSON.parse_string(data_string)
	if not data is Dictionary:
		push_error("Invalid data type parsed from JSON! Expected: Dictionary - Got: " + str(typeof(data)))
		return
	if data.get("length", 0) != day_configs.size():
		printerr("Could not load Day Scheduler. Mismatching length.")
		push_error("Day Scheduler length does not match while loading. Expected: " + str(day_configs.size()) + " - Got: " + str(data.get("length", 0)))
		return
	_ordered_config_indexes = data.get("config_indexes", [])
	_index = data.get("index", 0)
	scheduler_name = data.get("name", null)
	should_repeat = data.get("should_repeat", false)
	buffer_size = data.get("buffer_size", 1)
	selection_type = data.get("selection_type", "In Order")
	day_configs = []
	for day_config_string in data.get("day_configs", []):
		var new_day_config: DayConfig = DayConfig.new()
		new_day_config.load_from_json(day_config_string)
		day_configs.append(new_day_config)

func _create_ordered_config_indexes() -> void:
	if selection_type == "In Order":
		_ordered_config_indexes = _create_in_order()
	elif selection_type == "Random In Order":
		_ordered_config_indexes = _create_in_randomized_order()
	elif selection_type == "Random Pick":
		_ordered_config_indexes = _create_random_pick()
	elif selection_type == "Weighted Random Pick":
		_ordered_config_indexes = _create_weighted_random_pick()
	else:
		push_error("Selection type not found: " + selection_type)

func _create_weighted_random_pick() -> Array[int]:
	var indexes: Array[int] = []
	# If is already generated, we just shift everything and generate more afterwards
	if _ordered_config_indexes.size() > 0:
		for i in range(_ordered_config_indexes.size() - day_configs.size()):
			indexes.append(_ordered_config_indexes[i + day_configs.size()])
		for i in range(day_configs.size()):
			indexes.append(_pick_weighted_element_index(day_configs))
		return indexes

	# Generate the entire schedule
	var loop_size: int = ((day_configs.size() * buffer_size) * 2) + day_configs.size()
	for i in range(loop_size):
		indexes.append(_pick_weighted_element_index(day_configs))
	return indexes

func _create_random_pick() -> Array[int]:
	var indexes: Array[int] = []
	# If is already generated, we just shift everything and generate more afterwards
	if _ordered_config_indexes.size() > 0:
		for i in range(_ordered_config_indexes.size() - day_configs.size()):
			indexes.append(_ordered_config_indexes[i + day_configs.size()])
		for i in range(day_configs.size()):
			indexes.append(randi_range(0,day_configs.size() -1))
		return indexes

	# Generate the entire schedule
	var loop_size: int = ((day_configs.size() * buffer_size) * 2) + day_configs.size()
	for i in range(loop_size):
		indexes.append(randi_range(0,day_configs.size() -1))
	return indexes

func _create_in_order() -> Array[int]:
	# If is already generated, we can return the already generated since it is the same pattern
	if _ordered_config_indexes.size() > 0:
		return _ordered_config_indexes
	# Generate the entire schedule
	var loop_size: int = ((day_configs.size() * buffer_size) * 2) + day_configs.size()

	var ordered_indexes: Array[int] = []
	for i in range(loop_size):
		ordered_indexes.append(i % day_configs.size())
	return ordered_indexes

func _create_in_randomized_order() -> Array[int]:
	# If is already generated, we just shift everything and generate more afterwards
	if _ordered_config_indexes.size() > 0:
		var ordered_indexes: Array[int] = []
		for i in range(_ordered_config_indexes.size() - day_configs.size()):
			ordered_indexes.append(_ordered_config_indexes[i + day_configs.size()])
		var array: Array[int] = []
		for j in range(day_configs.size()):
			array.append(j)
		array.shuffle()
		for j in range(day_configs.size()):
			ordered_indexes.append(array[j])
		return ordered_indexes
	# Generate the entire schedule
	var loop_size: int = ((day_configs.size() * buffer_size) * 2) + day_configs.size()

	var ordered_indexes: Array[int] = []
	for i in range(0,loop_size,day_configs.size()):
		var array: Array[int] = []
		for j in range(day_configs.size()):
			array.append(j)
		array.shuffle()
		for j in range(day_configs.size()):
			ordered_indexes.append(array[j])
	return ordered_indexes


func _pick_weighted_element_index(day_configs: Array[DayConfig])-> int:
	var total_weight: int = 0
	for day_config in day_configs:
		total_weight += day_config.day_weight

	var random_value: int = randi_range(0,total_weight)

	var current_weight: int = 0

	for i in range(day_configs.size()):
		current_weight += day_configs[i].day_weight
		if random_value <= current_weight:
			return i

	# If random_value exceeds all weights (unlikely), return the last element index
	return day_configs.size() - 1
