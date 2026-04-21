extends ColorRect

signal confirmed
signal cancelled

@onready var title_label  : Label = $PanelContainer/MarginContainer/VBoxContainer/Title
@onready var message_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Message
@onready var confirm_btn  : Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_btn   : Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/CancelButton

# UI Sounds
var _sfx_click   : AudioStream = preload("res://Audio/SFX/ui_sfx_4.mp3")
var _sfx_confirm : AudioStream = preload("res://Audio/SFX/ui_sfx_9.mp3")
var _ui_player   : AudioStreamPlayer

func _ready() -> void:
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = "SFX"
	add_child(_ui_player)
	
	confirm_btn.pressed.connect(_on_confirm_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	hide()

func open(title: String, message: String) -> void:
	title_label.text = title
	message_label.text = message
	show()
	cancel_btn.grab_focus()

func close() -> void:
	hide()

func _on_confirm_pressed() -> void:
	_play_confirm()
	confirmed.emit()
	close()

func _on_cancel_pressed() -> void:
	_play_click()
	cancelled.emit()
	close()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()

func _play_click() -> void:
	_ui_player.stream = _sfx_click
	_ui_player.play()

func _play_confirm() -> void:
	_ui_player.stream = _sfx_confirm
	_ui_player.play()
