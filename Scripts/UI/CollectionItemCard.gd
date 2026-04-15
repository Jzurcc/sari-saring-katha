extends PanelContainer

## Script for individual item cards in the Collection UI.
## Handles the silhouette logic and the subtle sway effect.

var item_data: ItemData
var is_unlocked: bool = false

@onready var texture_rect: TextureRect = TextureRect.new()
@onready var name_label: Label = Label.new()

func setup(data: ItemData, unlocked: bool) -> void:
	item_data = data
	is_unlocked = unlocked
	
	# Style the card
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.09, 0.6) # Semi-transparent dark
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)
	
	custom_minimum_size = Vector2(140, 160)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)
	
	# Texture mapping
	texture_rect.custom_minimum_size = Vector2(100, 100)
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture = item_data.texture
	texture_rect.pivot_offset = Vector2(50, 50) # Center for rotation
	
	if not is_unlocked:
		texture_rect.modulate = Color(0, 0, 0, 1) # Silhouette
	
	vbox.add_child(texture_rect)
	
	# Name label
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 14)
	if is_unlocked:
		name_label.text = item_data.item_name
		name_label.add_theme_color_override("font_color", Color(1, 0.92, 0.79, 1))
	else:
		name_label.text = "???"
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	
	vbox.add_child(name_label)
	
	# --- Sway Effect ---
	_start_sway()

func _start_sway() -> void:
	var tween = create_tween().set_loops()
	var duration = randf_range(3.0, 5.0)
	var angle = randf_range(2.0, 4.0)
	
	# Start at a random point
	texture_rect.rotation_degrees = randf_range(-angle, angle)
	
	tween.tween_property(texture_rect, "rotation_degrees", angle, duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(texture_rect, "rotation_degrees", -angle, duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
