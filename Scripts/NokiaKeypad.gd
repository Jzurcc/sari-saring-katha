extends Node3D

signal store_menu_requested

var current_input: String = ""
var target_number: String = "62777444666"

@export var store_menu: Control

func _ready() -> void:
	# Recursively find Area3Ds in case they are nested under children
	_connect_buttons(self)

func _connect_buttons(node: Node) -> void:
	for child in node.get_children():
		if child is Area3D:
			if not child.input_event.is_connected(_on_button_input_event):
				child.input_event.connect(_on_button_input_event.bind(child.name))
		_connect_buttons(child)

func _on_button_input_event(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int, button_name: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Extract number from the button name (e.g. "Button6" -> "6", "Button0" -> "0")
		# To handle single digit buttons, we get the last character of the name
		var digit = button_name.right(1)
		if digit.is_valid_int():
			_type_digit(digit)

func _type_digit(digit: String) -> void:
	current_input += digit
	print("[Nokia] Typed: ", current_input)
	
	# Check if ends with the target number
	if current_input.ends_with(target_number):
		print("[Nokia] Correct number dialed!")
		current_input = "" # Reset
		_trigger_store_menu()
	
	# Prevent infinite growth of string
	if current_input.length() > 20:
		current_input = current_input.right(11)

func _trigger_store_menu() -> void:
	# Check cooldown first
	if InventoryManager.customers_needed_for_delivery > 0:
		print("[Nokia] Uncle Mario is resting.")
		if Dialogic.timeline_exists("UncleMario_Call_Rest"):
			Dialogic.start("UncleMario_Call_Rest")
	else:
		print("[Nokia] Triggering UI request!")
		store_menu_requested.emit()
		
		# Also directly open if hooked up in inspector
		if store_menu and store_menu.has_method("open_menu"):
			store_menu.open_menu()
