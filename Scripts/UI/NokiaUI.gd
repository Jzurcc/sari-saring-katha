extends Control

## Emitted when the Nokia UI closes so the owner can restore mouse capture.
signal nokia_closed

var current_input: String = ""
var target_number: String = "62777444666"

@export var store_menu: Control

## DEV: Tick this in the Inspector to skip Uncle Mario's cooldown for testing.
@export var bypass_cooldown: bool = false

@export_range(-80.0, 24.0) var button_volume_db: float = -9.0

## 3D marker in MainGame where Uncle Mario's speech bubble anchors.
@export var phone_anchor: Node3D

var screen_label: Label = null
var _is_calling: bool = false
var _is_on_side: bool = false

const T9_MAP = {
	"1": ".,!",
	"2": "abc",
	"3": "def",
	"4": "ghi",
	"5": "jkl",
	"6": "mno",
	"7": "pqrs",
	"8": "tuv",
	"9": "wxyz",
	"0": " "
}

var _last_digit: String = ""
var _tap_index: int = -1
var _last_tap_time: int = 0
var _tap_timeout_ms: int = 1000

var sfx_btn_1: AudioStream = preload("res://Audio/SFX/phone_btn_1.mp3")
var sfx_btn_2: AudioStream = preload("res://Audio/SFX/phone_btn_2.mp3")
var sfx_btn_3: AudioStream = preload("res://Audio/SFX/phone_btn_3.mp3")

var button_audio_player: AudioStreamPlayer



func _ready() -> void:
	add_to_group("nokia_ui_active")
	button_audio_player = AudioStreamPlayer.new()
	button_audio_player.bus = "SFX"
	add_child(button_audio_player)
	
	# Recursively find the Label and buttons anywhere in the scene!
	_scan_and_connect_nodes(self)
	
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and gm.tutorial and gm.tutorial.has_method("on_tutorial_phone_opened"):
		gm.tutorial.on_tutorial_phone_opened()

	_animate_entrance()


func _animate_entrance() -> void:
	var nokia = get_node("Nokia")
	var screen_size = get_viewport_rect().size
	
	# Center horizontally
	var target_x = (screen_size.x - nokia.size.x * nokia.scale.x) / 2
	nokia.position.x = target_x
	
	# Slide up from bottom
	var start_y = nokia.position.y + 600
	var final_y = nokia.position.y
	nokia.position.y = start_y
	
	var tween = create_tween()
	tween.tween_property(nokia, "position:y", final_y, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _move_to_side() -> void:
	if _is_on_side: return
	_is_on_side = true
	var nokia = get_node("Nokia")
	var tween = create_tween()
	# Move to the left (e.g., 80px from left)
	tween.tween_property(nokia, "position:x", 80, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _animate_exit_and_free() -> void:
	var nokia = get_node("Nokia")
	var tween = create_tween()
	tween.tween_property(nokia, "position:y", nokia.position.y + 600, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): queue_free())



func _scan_and_connect_nodes(node: Node) -> void:
	# Skip the RestockMenu and UpgradeMenu subtrees — their buttons are NOT Nokia keys
	if node.name == "RestockMenu" or node.name == "UpgradeMenu":
		return
	
	# Find the Nokia screen label
	if node is Label and node.name == "Label":
		screen_label = node
		screen_label.text = ""
	elif node is Button:
		# Prevent Space/Enter during Dialogic dialogue from re-activating focused Nokia keypad buttons
		node.focus_mode = Control.FOCUS_NONE
		var btn_name = node.name.to_lower()
		match btn_name:
			"clear":
				node.pressed.connect(_on_clear_pressed)
			"enter", "call", "ok":
				node.pressed.connect(_on_enter_pressed)
			"back", "cancel":
				node.pressed.connect(_on_close_pressed)
			"asterisk", "star":
				node.pressed.connect(_on_asterisk_pressed)
			"home", "hash":
				node.pressed.connect(_on_home_pressed)
			_:
				if btn_name.length() == 1 and btn_name.is_valid_int():
					node.pressed.connect(_on_key_pressed.bind(str(node.name)))
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
	
	var now = Time.get_ticks_msec()
	var letters = T9_MAP.get(digit, digit) # Fallback to digit if not in map
	
	# Handle multi-tap
	if digit == _last_digit and (now - _last_tap_time) < _tap_timeout_ms:
		# Cycle through letters
		_tap_index = (_tap_index + 1) % letters.length()
		# Replace last character
		if current_input.length() > 0:
			current_input = current_input.left(current_input.length() - 1)
	else:
		# New digit or timeout: start new character
		_last_digit = digit
		_tap_index = 0
	
	_last_tap_time = now
	
	# Max character limit of 14
	if current_input.length() < 14:
		current_input += letters[_tap_index]
		_update_screen()

func _on_clear_pressed() -> void:
	if _is_calling: return
	_play_button_sound("clear")
	_reset_t9_state()
	if current_input.length() > 0:
		current_input = current_input.left(current_input.length() - 1)
		_update_screen()

func _reset_t9_state() -> void:
	_last_digit = ""
	_tap_index = -1
	_last_tap_time = 0

func _on_home_pressed() -> void:
	if _is_calling: return
	_play_button_sound("home")
	_on_close_pressed()

func _on_enter_pressed() -> void:
	if _is_calling: return
	_play_button_sound("enter")
	if current_input.to_upper() == "MARIO" or current_input == target_number:
		_trigger_store_menu()

func _on_asterisk_pressed() -> void:
	if _is_calling: return
	_play_button_sound("asterisk")
	_trigger_store_menu()

func start_incoming_answer() -> void:
	if _is_calling:
		return
	_is_calling = true
	_move_to_side()

	if not phone_anchor:
		phone_anchor = get_tree().root.find_child("PhoneMarker3D", true, false) as Node3D

	if not phone_anchor:
		push_error("[NokiaUI] No phone_anchor found for incoming call!")
		_is_calling = false
		return

	MarioManager.call_ended.connect(_on_mario_call_finished, CONNECT_ONE_SHOT)
	MarioManager.answer_incoming_upgrade_call(phone_anchor)

func _trigger_store_menu() -> void:
	# Special Tutorial Step 4: play ringtone, close phone, and turn around to face Uncle Mario
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm and gm.tutorial and gm.tutorial.is_waiting_for_phone_call():
		if _is_calling:
			return
		_is_calling = true
		var ring_player := AudioStreamPlayer.new()
		ring_player.bus = "SFX"
		ring_player.stream = MarioManager.sfx_dial
		add_child(ring_player)
		ring_player.play()
		await get_tree().create_timer(1.4).timeout
		if is_instance_valid(ring_player):
			ring_player.stop()
			ring_player.queue_free()
		_is_calling = false
		_on_close_pressed()
		if is_instance_valid(gm) and gm.tutorial:
			gm.tutorial.complete_tutorial_phone_call()
		return

	# Block if already in a call or restocking is active
	if _is_calling or MarioManager.is_restocking_active:
		return
		
	_is_calling = true
	_move_to_side()
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

func _fade_out_nokia() -> void:
	var nokia := get_node_or_null("Nokia") as Control
	if not nokia:
		return
	nokia.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in nokia.find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(nokia, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		if is_instance_valid(nokia):
			nokia.visible = false
	)


func _on_mario_call_finished(success: bool, action: String = "restock") -> void:
	print("[NokiaUI] Mario call finished. Success: ", success, " Action: ", action)
	_is_calling = false
	
	if success:
		if action == "upgrade":
			_on_close_pressed()
			get_tree().call_group("upgrade_tree_overlay", "open_tree")
			return
		var target_menu: Control = store_menu if store_menu else get_node_or_null("RestockMenu")
		if target_menu:
			_fade_out_nokia()
			target_menu.move_to_front()
			target_menu.visible = true
			if target_menu.has_method("open_menu"):
				target_menu.open_menu()
	else:
		# CallRest, Busy, or Nevermind — close the phone cleanly after Mario finishes talking
		_on_close_pressed()

func _update_screen() -> void:
	if not screen_label:
		return
	screen_label.text = current_input
	
	# Change color to dark green if input contains alphabetical characters
	var has_alpha: bool = false
	for c in current_input:
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z"):
			has_alpha = true
			break
	
	if has_alpha:
		screen_label.add_theme_color_override("font_color", Color("004d00")) # Dark Green
	else:
		screen_label.remove_theme_color_override("font_color")

func _on_close_pressed() -> void:
	if _is_calling: return
	
	# Defensive: Ensure the restock state is cleaned up if the phone is closed manually 
	# while the ordering menu was meant to be active.
	if MarioManager.is_restocking_active and not MarioManager.is_mario_physically_present:
		LogManager.debug("NokiaUI", "Phone closed while ordering. Cancelling restock state.")
		MarioManager.cancel_restock()
		
	_reset_t9_state()
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and gm.tutorial and gm.tutorial.has_method("on_tutorial_phone_closed"):
		gm.tutorial.on_tutorial_phone_closed()
	nokia_closed.emit()
	_animate_exit_and_free()
