@tool
extends DialogicLayoutLayer
## Bubble Textbox Layer
## Uses a fixed-size TextureRect for the bubble image — no 9-slice stretching.
## All Dialogic text nodes (DialogText, NameLabel, TypeSounds, NextIndicator)
## are positioned manually inside/above the bubble body.

enum AnimationsIn { NONE, POP_IN, FADE_UP }
enum AnimationsOut { NONE, POP_OUT, FADE_DOWN }
enum AnimationsNewText { NONE, WIGGLE }

@export_group("Text")
@export var text_use_global_size: bool = true
@export var text_size: int = 16
@export var text_use_global_color: bool = false
@export var text_custom_color: Color = Color(0.08, 0.06, 0.06, 1)

@export_group("Box")
@export var box_animation_in: AnimationsIn = AnimationsIn.POP_IN
@export var box_animation_out: AnimationsOut = AnimationsOut.POP_OUT
@export var box_animation_new_text: AnimationsNewText = AnimationsNewText.NONE

@export_group("Name Label")
@export var name_label_use_global_color: bool = false
@export var name_label_custom_color: Color = Color(0.08, 0.06, 0.06, 1)
@export var name_label_use_character_color: bool = false

@export_group("Sounds")
@export var typing_sounds_enabled: bool = true
@export var typing_sounds_mode: DialogicNode_TypeSounds.Modes = DialogicNode_TypeSounds.Modes.INTERRUPT
@export_dir var typing_sounds_sounds_folder: String = "res://addons/dialogic/Example Assets/sound-effects/"
@export_range(-80, 24, 0.01) var typing_sounds_volume: float = -10
@export_range(0.0, 3.0) var typing_sounds_pitch_variance: float = 0.0


func _apply_export_overrides() -> void:
	if !is_inside_tree():
		await ready

	_apply_text_settings()
	_apply_name_label_settings()
	_apply_sounds_settings()
	_apply_box_animations_settings()


func _apply_text_settings() -> void:
	var dialog_text: DialogicNode_DialogText = %DialogicNode_DialogText
	if text_use_global_size:
		text_size = get_global_setting(&'font_size', text_size)
	dialog_text.add_theme_font_size_override(&"normal_font_size", text_size)
	dialog_text.add_theme_font_size_override(&"bold_font_size", text_size)
	dialog_text.add_theme_font_size_override(&"italics_font_size", text_size)
	dialog_text.add_theme_font_size_override(&"bold_italics_font_size", text_size)

	if text_use_global_color:
		dialog_text.add_theme_color_override(&"default_color", get_global_setting(&'font_color', text_custom_color) as Color)
	else:
		dialog_text.add_theme_color_override(&"default_color", text_custom_color)


func _apply_name_label_settings() -> void:
	var name_label: DialogicNode_NameLabel = %DialogicNode_NameLabel
	if name_label_use_global_color:
		name_label.add_theme_color_override(&"font_color", get_global_setting(&'font_color', name_label_custom_color) as Color)
	else:
		name_label.add_theme_color_override(&"font_color", name_label_custom_color)
	name_label.use_character_color = name_label_use_character_color


func _apply_sounds_settings() -> void:
	var type_sounds: DialogicNode_TypeSounds = %DialogicNode_TypeSounds
	type_sounds.enabled = typing_sounds_enabled
	type_sounds.mode = typing_sounds_mode
	type_sounds.base_volume = typing_sounds_volume
	type_sounds.pitch_variance = typing_sounds_pitch_variance
	if not typing_sounds_sounds_folder.is_empty():
		type_sounds.sounds = DialogicNode_TypeSounds.load_sounds_from_path(typing_sounds_sounds_folder)


func _apply_box_animations_settings() -> void:
	var animations: AnimationPlayer = %Animations
	animations.set(&'animation_in', box_animation_in)
	animations.set(&'animation_out', box_animation_out)
	animations.set(&'animation_new_text', box_animation_new_text)
