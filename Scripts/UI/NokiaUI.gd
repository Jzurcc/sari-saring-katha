extends Control

var current_input: String = ""
var target_number: String = "62777444666"

@export var store_menu: Control

## DEV: Tick this in the Inspector to skip Uncle Mario's cooldown for testing.
@export var bypass_cooldown: bool = false

@export_range(-80.0, 24.0) var button_volume_db: float = 0.0

var screen_label: Label = null

var sfx_btn_1: AudioStream = preload("res://Audio/SFX/phone_btn_1.mp3")
var sfx_btn_2: AudioStream = preload("res://Audio/SFX/phone_btn_2.mp3")
var sfx_btn_3: AudioStream = preload("res://Audio/SFX/phone_btn_3.mp3")

var button_audio_player: AudioStreamPlayer

func _ready() -> void:
	button_audio_player = AudioStreamPlayer.new()
	add_child(button_audio_player)
	
	# Recursively find the Label and buttons anywhere in the scene!
	_scan_and_connect_nodes(self)

func _scan_and_connect_nodes(node: Node) -> void:
	# Skip the RestockMenu subtree entirely — its buttons are NOT Nokia keys
	if node.name == "RestockMenu":
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

func _play_button_sound(key: String) -> void:
	if key in ["1", "4", "7", "clear"]:
		button_audio_player.stream = sfx_btn_1
	elif key in ["2", "5", "8"]:
		button_audio_player.stream = sfx_btn_2
	elif key in ["3", "6", "9", "enter", "call", "ok"]:
		button_audio_player.stream = sfx_btn_3
	else:
		# Default for Star, Hash, 0, or any other button
		button_audio_player.stream = sfx_btn_2
	
	button_audio_player.volume_db = button_volume_db
	button_audio_player.play()

func _on_key_pressed(digit: String) -> void:
	_play_button_sound(digit)
	# Max character limit of 14
	if current_input.length() < 14:
		current_input += digit
		if screen_label:
			screen_label.text = current_input

func _on_clear_pressed() -> void:
	_play_button_sound("clear")
	if current_input.length() > 0:
		current_input = current_input.left(current_input.length() - 1)
		if screen_label:
			screen_label.text = current_input

func _on_enter_pressed() -> void:
	_play_button_sound("enter")
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
	print("[NokiaUI] Dialogue ended — looking for RestockMenu...")
	# After Uncle Mario agrees, open the store catalog
	var store = get_node_or_null("RestockMenu")
	print("[NokiaUI] RestockMenu node: ", store)
	if store and store.has_method("open_menu"):
		store.open_menu()
	elif store_menu and store_menu.has_method("open_menu"):
		store_menu.open_menu()
	else:
		push_warning("[NokiaUI] No RestockMenu found to open!")

func _on_close_pressed() -> void:
	# Safely return to crosshair control and close screen
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()
