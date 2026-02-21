class_name DialogueUI
extends CanvasLayer

@onready var portrait: TextureRect = $Control/Portrait
@onready var dialogue_box: PanelContainer = $Control/DialogueBox
@onready var text_label: Label = $Control/DialogueBox/MarginContainer/Label
@onready var control: Control = $Control

func _ready() -> void:
    control.visible = false

func show_dialogue(character_texture: Texture2D, text: String) -> void:
    portrait.texture = character_texture
    text_label.text = text
    control.visible = true
    
    # Simple "pop in" animation
    portrait.modulate.a = 0
    var tween = create_tween()
    tween.tween_property(portrait, "modulate:a", 1.0, 0.3)

signal closed

func _input(event: InputEvent) -> void:
    if control.visible and event.is_action_pressed("ui_accept"):
        hide_dialogue()

func hide_dialogue() -> void:
    control.visible = false
    closed.emit()
