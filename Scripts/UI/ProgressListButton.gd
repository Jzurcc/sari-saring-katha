extends Button

@onready var label: Label = $Margin/HBox/Label
@onready var status_icon: TextureRect = $Margin/HBox/StatusIcon

var _item_index: int = -1
var _is_locked: bool = false

func setup(text: String, is_locked: bool, is_completed: bool) -> void:
	label.text = text
	_is_locked = is_locked
	disabled = is_locked
	
	if is_locked:
		modulate = Color(0.5, 0.5, 0.5, 0.8)
		status_icon.modulate = Color(0.3, 0.3, 0.3, 1)
	elif is_completed:
		modulate = Color(1, 0.95, 0.85, 1)
		status_icon.modulate = Color(0.2, 0.8, 0.2, 1) # Green for complete
	else:
		modulate = Color(1, 1, 1, 1)
		status_icon.modulate = Color(0.6, 0.6, 0.6, 1)
