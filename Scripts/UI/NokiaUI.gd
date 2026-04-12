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

var _cancel_btn: Button = null


func _ready() -> void:
	button_audio_player = AudioStreamPlayer.new()
	add_child(button_audio_player)
	
	# Recursively find the Label and buttons anywhere in the scene!
	_scan_and_connect_nodes(self)
	_add_cancel_button()

func _add_cancel_button() -> void:
	# Inject a cancel button so the player can always exit the Nokia UI.
	# Positioned at the bottom-centre of the screen, above the keypad area.
	_cancel_btn = Button.new()
	_cancel_btn.name = "CancelOverlay"
	_cancel_btn.text = "✕  Cancel"
	_cancel_btn.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cancel_btn.offset_top = -60
	_cancel_btn.offset_bottom = -12
	_cancel_btn.offset_left = 60
	_cancel_btn.offset_right = -60
	# Style — dark semi-transparent pill
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_cancel_btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate()
	(hover_style as StyleBoxFlat).bg_color = Color(0.7, 0.15, 0.1, 0.95)
	_cancel_btn.add_theme_stylebox_override("hover", hover_style)
	_cancel_btn.add_theme_color_override("font_color", Color.WHITE)
	_cancel_btn.add_theme_font_size_override("font_size", 15)
	_cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_cancel_btn.pressed.connect(_on_close_pressed)
	add_child(_cancel_btn)

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

func _on_enter_pressed() -> void:
	if _is_calling: return
	_play_button_sound("enter")
	if current_input == target_number:
		_trigger_store_menu()

func _trigger_store_menu() -> void:
	_is_calling = true
	print("[NokiaUI] Triggering direct Mario call via Dialogic...")
	
	var timeline_path = "res://Dialogue/unclemario/UncleMario_Call.dtl"
	
	Dialogic.Styles.load_style("FollowBubble")
	var layout = Dialogic.start(timeline_path)
	
	# Dynamically grab the marker if not explicitly assigned
	if not phone_anchor:
		phone_anchor = get_tree().root.find_child("PhoneMarker3D", true, false) as Node3D
		print("found phone anchor at ", phone_anchor.global_position)
	
	if layout and phone_anchor:
		# Use Dialogic's internal cache to get the EXACT character resource instance.
		# Loading the path directly creates a duplicate object that Dialogic won't match!
		var mario_dch = DialogicResourceUtil.get_character_resource("UncleMario")
		if mario_dch and layout.has_method("register_character"):
			layout.register_character(mario_dch, phone_anchor)
			print("registered mario dch")
	elif not phone_anchor:
		push_error("[NokiaUI] Could not find PhoneMarker3D in the scene tree to anchor the bubble!")
				
	Dialogic.timeline_ended.connect(_on_call_ended, CONNECT_ONE_SHOT)

func _on_call_ended() -> void:
	print("[NokiaUI] Mario call ended.")
	_is_calling = false
	current_input = ""
	_update_screen()
	
	# Hide the Nokia interface child (we don't hide self, because we are the RestockScreen holding both)
	var nokia_ui = get_node_or_null("Nokia")
	if nokia_ui:
		nokia_ui.visible = false
	if _cancel_btn:
		_cancel_btn.visible = false
	
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

func _update_screen() -> void:
	if screen_label:
		screen_label.text = current_input

func _on_close_pressed() -> void:
	if _is_calling: return
	nokia_closed.emit()
	queue_free()
