extends Control

var current_input: String = ""
var target_number: String = "62777444666"

@export var store_menu: Control

## DEV: Tick this in the Inspector to skip Uncle Mario's cooldown for testing.
@export var bypass_cooldown: bool = false

var screen_label: Label = null

func _ready() -> void:
	# Recursively find the Label and buttons anywhere in the scene!
	_scan_and_connect_nodes(self)

func _scan_and_connect_nodes(node: Node) -> void:
	# Skip the StoreTableMenu subtree entirely — its buttons are NOT Nokia keys
	if node.name == "StoreTableMenu":
		return
	
	# Find the Nokia screen label
	if node is Label and node.name == "Label":
		screen_label = node
		screen_label.text = ""
	elif node is Button:
		var btn_name = node.name.to_lower()
		if btn_name == "clear":
			node.pressed.connect(_on_clear_pressed)
		elif btn_name == "enter" or btn_name == "call" or btn_name == "ok":
			node.pressed.connect(_on_enter_pressed)
		elif btn_name == "back":
			node.pressed.connect(_on_close_pressed)
		elif str(node.name).length() == 1 and str(node.name)[0].is_valid_int():
			# Single digit number buttons only
			node.pressed.connect(_on_key_pressed.bind(str(node.name)))
		elif node.name == "Star":
			node.pressed.connect(_on_key_pressed.bind("*"))
		elif node.name == "Hash":
			node.pressed.connect(_on_key_pressed.bind("#"))
		# All other buttons (Add, Cancel, Order, tab buttons, etc.) are ignored
		
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
	# Hide Nokia UI so Dialogic can receive input to advance dialogue
	self.visible = false
	
	var on_cooldown = InventoryManager.customers_needed_for_delivery > 0 and not bypass_cooldown
	if on_cooldown:
		Dialogic.start("UncleMario_Call_Rest")
		Dialogic.timeline_ended.connect(_on_dialogue_ended_rest, CONNECT_ONE_SHOT)
	else:
		# Correct number — Uncle Mario picks up!
		Dialogic.start("UncleMario_Call")
		Dialogic.timeline_ended.connect(_on_dialogue_ended_call, CONNECT_ONE_SHOT)

func _on_dialogue_ended_rest() -> void:
	# After the "rest" dialogue, show the Nokia UI again and reset input
	self.visible = true
	current_input = ""
	if screen_label:
		screen_label.text = ""

func _on_dialogue_ended_call() -> void:
	# Make the screen visible again so the store menu can appear
	self.visible = true
	# After Uncle Mario agrees, open the store catalog
	var store = get_node_or_null("StoreTableMenu")
	if store and store.has_method("open_menu"):
		store.open_menu()
	elif store_menu and store_menu.has_method("open_menu"):
		store_menu.open_menu()
	else:
		push_warning("[NokiaUI] No StoreTableMenu found to open!")

func _on_close_pressed() -> void:
	# Safely return to crosshair control and close screen
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()
