extends Button

signal item_pressed(data: ItemData)

## Script for individual item cards in the Collection UI.
## Handles the silhouette logic and the subtle sway effect.

var item_data: ItemData
var is_unlocked: bool = false

@onready var texture_rect: TextureRect = TextureRect.new()
@onready var name_label: Label = Label.new()

func setup(data: ItemData, unlocked: bool) -> void:
	item_data = data
	is_unlocked = unlocked
	
	# Style the card - Normal
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.11, 0.09, 0.6) # Semi-transparent dark
	style_normal.corner_radius_top_left = 12
	style_normal.corner_radius_top_right = 12
	style_normal.corner_radius_bottom_right = 12
	style_normal.corner_radius_bottom_left = 12
	style_normal.content_margin_left = 12
	style_normal.content_margin_right = 12
	style_normal.content_margin_top = 12
	style_normal.content_margin_bottom = 12
	add_theme_stylebox_override("normal", style_normal)
	
	# Style Hover
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.18, 0.16, 0.14, 0.8)
	style_hover.border_width_left = 2
	style_hover.border_width_top = 2
	style_hover.border_width_right = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = Color(0.8, 0.7, 0.5, 0.6)
	add_theme_stylebox_override("hover", style_hover)
	add_theme_stylebox_override("focus", style_hover)
	
	# Style Pressed
	var style_pressed = style_hover.duplicate()
	style_pressed.bg_color = Color(0.1, 0.09, 0.08, 0.9)
	add_theme_stylebox_override("pressed", style_pressed)
	
	custom_minimum_size = Vector2(180, 220)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)
	
	# Texture mapping
	texture_rect.custom_minimum_size = Vector2(140, 140)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture = item_data.texture
	texture_rect.pivot_offset = Vector2(70, 70) # Center for rotation
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if not is_unlocked:
		texture_rect.modulate = Color(0, 0, 0, 1) # Silhouette
	
	vbox.add_child(texture_rect)
	
	# Name label
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_unlocked:
		name_label.text = item_data.item_name
		name_label.add_theme_color_override("font_color", Color(1, 0.92, 0.79, 1))
	else:
		name_label.text = "???"
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	
	vbox.add_child(name_label)
	
	# Connect interaction
	pressed.connect(_on_pressed)
	
	# --- Sway Effect ---
	_start_sway()

func _on_pressed() -> void:
	if is_unlocked:
		item_pressed.emit(item_data)

func _start_sway() -> void:
	var tween = create_tween().set_loops()
	var duration = randf_range(3.0, 5.0)
	var angle = randf_range(2.0, 4.0)
	
	# Start at a random point
	texture_rect.rotation_degrees = randf_range(-angle, angle)
	
	tween.tween_property(texture_rect, "rotation_degrees", angle, duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(texture_rect, "rotation_degrees", -angle, duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
