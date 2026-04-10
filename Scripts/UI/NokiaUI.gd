extends Control

var current_input: String = ""
var target_number: String = "62777444666"

@export var store_menu: Control

@onready var close_btn = $CloseButton
var screen_label: Label = null

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	
	# Recursively find the Label and buttons anywhere in the scene!
	_scan_and_connect_nodes(self)

func _scan_and_connect_nodes(node: Node) -> void:
	# Explicitly find the node named "Label" to act as our screen
	if node is Label and node.name == "Label":
		screen_label = node
		screen_label.text = ""
	elif node is Button and node != close_btn:
		var btn_name = node.name.to_lower()
		if btn_name == "clear":
			node.pressed.connect(_on_clear_pressed)
		elif btn_name == "enter" or btn_name == "call" or btn_name == "ok":
			node.pressed.connect(_on_enter_pressed)
		elif btn_name == "back":
			node.pressed.connect(_on_close_pressed)
		else:
			# We assume it's a number key
			var digit = node.name
			if digit == "Star": digit = "*"
			if digit == "Hash": digit = "#"
			node.pressed.connect(_on_key_pressed.bind(digit))
			
	for child in node.get_children():
		_scan_and_connect_nodes(child)

func _on_key_pressed(digit: String) -> void:
	# Max character limit of 14
	if current_input.length() < 14:
		current_input += digit
		if screen_label:
			screen_label.text = current_input

func _on_clear_pressed() -> void:
	if current_input.length() > 0:
		current_input = current_input.left(current_input.length() - 1)
		if screen_label:
			screen_label.text = current_input

func _on_enter_pressed() -> void:
	if current_input == target_number:
		_trigger_store_menu()

func _trigger_store_menu() -> void:
	if InventoryManager.customers_needed_for_delivery > 0:
		Dialogic.start("UncleMario_Call_Rest")
		Dialogic.timeline_ended.connect(_on_dialogue_ended_rest, CONNECT_ONE_SHOT)
	else:
		# Correct number — Uncle Mario picks up!
		Dialogic.start("UncleMario_Call")
		Dialogic.timeline_ended.connect(_on_dialogue_ended_call, CONNECT_ONE_SHOT)

func _on_dialogue_ended_rest() -> void:
	# After the "rest" dialogue, just reset the input so they can try again
	current_input = ""
	if screen_label:
		screen_label.text = ""

func _on_dialogue_ended_call() -> void:
	# After Uncle Mario agrees, open the store catalog
	if store_menu and store_menu.has_method("open_menu"):
		store_menu.open_menu()

func _on_close_pressed() -> void:
	# Safely return to crosshair control and close screen
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()
