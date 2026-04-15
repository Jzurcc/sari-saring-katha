extends Control

## Emitted when the Nokia UI closes so the owner can restore mouse capture.
signal nokia_closed

var current_input: String = ""
var target_number: String = "62777444666"

@export var store_menu: Control

## DEV: Tick this in the Inspector to skip Uncle Mario's cooldown for testing.
@export var bypass_cooldown: bool = false

@export_range(-80.0, 24.0) var button_volume_db: float = 0.0

## 3D marker in MainGame where Uncle Mario's speech bubble anchors.
@export var phone_anchor: Node3D

var screen_label: Label = null
var _is_calling: bool = false

var sfx_btn_1: AudioStream = preload("res://Audio/SFX/phone_btn_1.mp3")
var sfx_btn_2: AudioStream = preload("res://Audio/SFX/phone_btn_2.mp3")
var sfx_btn_3: AudioStream = preload("res://Audio/SFX/phone_btn_3.mp3")

var button_audio_player: AudioStreamPlayer



func _ready() -> void:
	button_audio_player = AudioStreamPlayer.new()
	add_child(button_audio_player)
	
	# Recursively find the Label and buttons anywhere in the scene!
	_scan_and_connect_nodes(self)
	_animate_entrance()

func _animate_entrance() -> void:
	position.y += 400
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y - 400, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_exit_and_free() -> void:
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y + 400, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): queue_free())



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
		elif btn_name == "back" or btn_name == "cancel":
			node.pressed.connect(_on_close_pressed)
		elif str(node.name).length() == 1 and str(node.name)[0].is_valid_int():
			# Single digit number buttons only
			node.pressed.connect(_on_key_pressed.bind(str(node.name)))
		elif node.name.to_lower() == "asterisk" or node.name == "Star":
			node.pressed.connect(_on_asterisk_pressed)
		elif node.name.to_lower() == "home" or node.name == "Hash":
			node.pressed.connect(_on_home_pressed)
		# All other buttons (Add, Cancel, Order, tab buttons, etc.) are ignored
		
	for child in node.get_children():
		_scan_and_connect_nodes(child)

func _play_button_sound(key: String) -> void:
	if key in ["1", "4", "7", "clear"]:
		button_audio_player.stream = sfx_btn_1
	elif key in ["2", "5", "8", "0", "home"]:
		button_audio_player.stream = sfx_btn_2
	elif key in ["3", "6", "9", "enter", "call", "ok", "asterisk"]:
		button_audio_player.stream = sfx_btn_3
	else:
		# Default fallback
		button_audio_player.stream = sfx_btn_2
	
	button_audio_player.volume_db = button_volume_db
	button_audio_player.play()

func _on_key_pressed(digit: String) -> void:
	if _is_calling: return
	_play_button_sound(digit)
	# Max character limit of 14
	if current_input.length() < 14:
		current_input += digit
		if screen_label:
			screen_label.text = current_input

func _on_clear_pressed() -> void:
	if _is_calling: return
	_play_button_sound("clear")
	if current_input.length() > 0:
		current_input = current_input.left(current_input.length() - 1)
		if screen_label:
			screen_label.text = current_input

func _on_home_pressed() -> void:
	if _is_calling: return
	_play_button_sound("home")
	_on_close_pressed()

func _on_enter_pressed() -> void:
	if _is_calling: return
	_play_button_sound("enter")
	if current_input == target_number:
		_trigger_store_menu()

func _on_asterisk_pressed() -> void:
	if _is_calling: return
	_play_button_sound("asterisk")
	_trigger_store_menu()

func _trigger_store_menu() -> void:
	# Block if already in a call or restocking is active
	if _is_calling or MarioManager.is_restocking_active:
		return
		
	_is_calling = true
	print("[NokiaUI] Triggering direct Mario call via MarioManager...")
	
	# Dynamically grab the marker if not explicitly assigned
	if not phone_anchor:
		phone_anchor = get_tree().root.find_child("PhoneMarker3D", true, false) as Node3D
	
	if not phone_anchor:
		push_error("[NokiaUI] No phone_anchor found! Aborting call.")
		_is_calling = false
		return

	# Use MarioManager to handle all dialogue logic (states, randomization, etc.)
	MarioManager.call_ended.connect(_on_mario_call_finished, CONNECT_ONE_SHOT)
	MarioManager.initiate_call(phone_anchor, bypass_cooldown)

func _on_mario_call_finished(success: bool) -> void:
	print("[NokiaUI] Mario call finished. Success: ", success)
	_is_calling = false
	current_input = ""
	_update_screen()
	
	if success:
		if not store_menu:
			store_menu = find_child("RestockMenu", true, false)
			
		if store_menu:
			print("[NokiaUI] Opening RestockMenu...")
			store_menu.visible = true
			if store_menu.has_method("open_menu"):
				store_menu.open_menu()
		else:
			push_warning("[NokiaUI] No store_menu found to open!")
			nokia_closed.emit()
	else:
		# If the call failed (Mario was busy or resting), we just close the Nokia UI
		# so the player can continue serving customers.
		var nokia_ui = get_node_or_null("Nokia")
		if nokia_ui:
			nokia_ui.visible = false
		nokia_closed.emit()
		_animate_exit_and_free()

func _update_screen() -> void:
	if screen_label:
		screen_label.text = current_input

func _on_close_pressed() -> void:
	if _is_calling: return
	nokia_closed.emit()
	_animate_exit_and_free()
