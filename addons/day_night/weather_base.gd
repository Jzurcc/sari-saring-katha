extends Node
class_name WeatherBase

var _should_quit: bool = false

func _init():
	verify(self)
	
func _enter_tree():
	if _should_quit:
		get_tree().quit()

## The method names that need to be implemented
const weather_interface: Array[String] = ["start_weather", "stop_weather"]

## Check if the object implements the WeatherBase interface
static func check_implements(obj: Variant) -> bool:
	var dict: Dictionary = {}
	for interface in weather_interface:
		dict[interface] = false
	
	var methods = obj.get_method_list()
	for a_func in methods:
		if dict.has(a_func.name):
			dict[a_func.name] = true
	var is_good: bool = true
	for elem in dict:
		if not dict[elem]:
			push_error("Needs to implement the method: " + elem + "() inside " + obj.get_script().get_path())
			printerr("Needs to implement the method: " + elem + "() inside " + obj.get_script().get_path())
			is_good = false
	return is_good
	
## Verify if the node implements the WeatherBase interface
func verify(node: Node):
	if !WeatherBase.check_implements(node):
		_should_quit = true


