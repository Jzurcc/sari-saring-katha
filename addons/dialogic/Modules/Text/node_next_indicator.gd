@icon("node_next_indicator_icon.svg")
class_name DialogicNode_NextIndicator
extends Control

## Node that is shown when the text is fully revealed.
## Displays a sleek pulsing keycap badge (e.g. [SPACE]) reflecting the player's
## configured `dialogic_default_action` keybind directly inside the dialogue box.


@export var enabled := true

## If true the next indicator will also be shown if the text is a question.
@export var show_on_questions := false
## If true the next indicator will be shown even if dialogic will autocontinue.
@export var show_on_autoadvance := false

enum Animations {BOUNCE, BLINK, NONE}

## What animation should the indicator do.
@export var animation := Animations.BOUNCE

var texture_rect: TextureRect
var _keycap_panel: PanelContainer
var _keycap_lbl: Label

## Set the image to use as the indicator.
@export var texture: Texture2D = preload("res://addons/dialogic/Example Assets/next-indicator/next-indicator.png") as Texture2D:
	set(_texture):
		texture = _texture
		if texture_rect:
			texture_rect.texture = texture

@export var texture_size := Vector2(32,32):
	set(_texture_size):
		texture_size = _texture_size
		if has_node('Texture'):
			get_node('Texture').size = _texture_size
			get_node('Texture').position = -_texture_size

@export var indicator_offset := Vector2(0, 0):
	set(_indicator_offset):
		indicator_offset = _indicator_offset
		if has_node('Texture'):
			texture_rect.position = indicator_offset

var tween: Tween

func _ready() -> void:
	add_to_group('dialogic_next_indicator')
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Build keycap prompt (e.g. [SPACE]) in light cream straddling the bottom-right outer edge
	_keycap_panel = PanelContainer.new()
	_keycap_panel.name = "AdvanceKeycap"
	_keycap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keycap_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_keycap_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_keycap_panel.offset_right = 8.0
	_keycap_panel.offset_bottom = 10.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.961, 0.961, 0.863, 0.98)
	style.border_color = Color(0.26, 0.19, 0.13, 0.92)
	style.set_border_width_all(1)
	style.border_width_bottom = 2
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_keycap_panel.add_theme_stylebox_override("panel", style)

	_keycap_lbl = Label.new()
	_keycap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keycap_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_keycap_lbl.add_theme_font_size_override("font_size", 12)
	_keycap_lbl.add_theme_color_override("font_color", Color(0.18, 0.12, 0.08, 1.0))
	_keycap_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keycap_panel.add_child(_keycap_lbl)
	add_child(_keycap_panel)

	_refresh_keycap_text()
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("keybinds_changed") and not eb.keybinds_changed.is_connected(_refresh_keycap_text):
		eb.keybinds_changed.connect(_refresh_keycap_text)

	hide()
	visibility_changed.connect(_on_visibility_changed)


func _refresh_keycap_text() -> void:
	if not is_instance_valid(_keycap_lbl):
		return
	var raw_label := "SPACE"
	var nav := get_node_or_null("/root/DialogueChoiceNavigator")
	if nav and nav.has_method("get_action_key_label"):
		raw_label = nav.get_action_key_label("dialogic_default_action", "SPACE")
	if raw_label == "SPACE":
		_keycap_lbl.text = "⎵"
		_keycap_lbl.add_theme_font_size_override("font_size", 15)
	else:
		_keycap_lbl.text = raw_label
		_keycap_lbl.add_theme_font_size_override("font_size", 12)


func _on_visibility_changed() -> void:
	if visible:
		_refresh_keycap_text()
		play_animation(animation, 1.0)
	elif tween and tween.is_valid():
		tween.kill()


func play_animation(_current_animation: int, _time: float) -> void:
	if tween and tween.is_valid():
		tween.kill()
	if not is_instance_valid(_keycap_panel):
		return

	_keycap_panel.scale = Vector2.ONE
	_keycap_panel.modulate.a = 1.0
