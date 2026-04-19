class_name VariablePrerequisite
extends StoryPrerequisite

## Requires a specific Dialogic variable to have a specific value.

## The full path to the variable (e.g. "Global_Money" or "Buboy.Trust").
@export var variable_name: String
## The required value to compare against.
@export var required_value: String
## The comparison operator.
@export_enum("==", ">=", "<=", ">", "<", "!=") var operator: String = "=="

func is_met(_story_manager: Node) -> bool:
	if variable_name == "" or not Dialogic.VAR.has_variable(variable_name):
		return true
		
	var actual_value = Dialogic.VAR.get_variable(variable_name)
	
	# Handle numeric comparison if possible
	var is_numeric = (actual_value is float or actual_value is int)
	
	match operator:
		"==":
			return str(actual_value) == required_value
		"!=":
			return str(actual_value) != required_value
		">=":
			if is_numeric: return float(actual_value) >= float(required_value)
		"<=":
			if is_numeric: return float(actual_value) <= float(required_value)
		">":
			if is_numeric: return float(actual_value) > float(required_value)
		"<":
			if is_numeric: return float(actual_value) < float(required_value)
			
	return false
