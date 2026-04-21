extends Node3D

var pricing_ui: Sprite3D
var pricing_viewport: SubViewport
var name_label: Label
var price_label: Label
var comparison_label: Label
var stock_label: Label
var pricing_panel: PanelContainer
var left_arrow: Label
var right_arrow: Label
var _current_item: ItemData

const INDER_FONT := preload("res://Assets/Fonts/Inder/Inder-Regular.ttf")

func _ready() -> void:
	name = "PricingOverlay"
	
	var beige := Color(0.92, 0.9, 0.78)
	var beige_subtle := beige.lerp(Color.BLACK, 0.2)
	var bg_color := Color(0.1, 0.09, 0.08, 0.85)

	pricing_viewport = SubViewport.new()
	pricing_viewport.transparent_bg = true
	pricing_viewport.size = Vector2(400, 220)
	pricing_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(pricing_viewport)

	pricing_panel = PanelContainer.new()
	pricing_viewport.add_child(pricing_panel)
	pricing_panel.size = Vector2(400, 220)
	pricing_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.4)
	pricing_panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	pricing_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", beige_subtle)
	vbox.add_child(name_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	# Price Row with Indicators
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	
	left_arrow = Label.new()
	left_arrow.text = "<"
	left_arrow.add_theme_font_size_override("font_size", 40)
	left_arrow.add_theme_color_override("font_color", beige_subtle)
	left_arrow.pivot_offset = Vector2(10, 20) # Approximate center
	hbox.add_child(left_arrow)
	
	var mid_spacer = Control.new()
	mid_spacer.custom_minimum_size = Vector2(12, 0)
	hbox.add_child(mid_spacer)

	price_label = Label.new()
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 52)
	price_label.add_theme_color_override("font_color", beige)
	hbox.add_child(price_label)
	
	var right_spacer = Control.new()
	right_spacer.custom_minimum_size = Vector2(12, 0)
	hbox.add_child(right_spacer)

	right_arrow = Label.new()
	right_arrow.text = ">"
	right_arrow.add_theme_font_size_override("font_size", 40)
	right_arrow.add_theme_color_override("font_color", beige_subtle)
	right_arrow.pivot_offset = Vector2(10, 20) # Approximate center
	hbox.add_child(right_arrow)

	comparison_label = Label.new()
	comparison_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	comparison_label.add_theme_font_size_override("font_size", 28)
	comparison_label.add_theme_color_override("font_color", beige_subtle)
	vbox.add_child(comparison_label)

	stock_label = Label.new()
	stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock_label.add_theme_font_size_override("font_size", 30)
	stock_label.add_theme_color_override("font_color", Color(0.494, 0.761, 0.573))
	vbox.add_child(stock_label)
	
	if INDER_FONT:
		name_label.add_theme_font_override("font", INDER_FONT)
		price_label.add_theme_font_override("font", INDER_FONT)
		comparison_label.add_theme_font_override("font", INDER_FONT)
		stock_label.add_theme_font_override("font", INDER_FONT)
		left_arrow.add_theme_font_override("font", INDER_FONT)
		right_arrow.add_theme_font_override("font", INDER_FONT)

	pricing_ui = Sprite3D.new()
	pricing_ui.texture = pricing_viewport.get_texture()
	pricing_ui.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pricing_ui.no_depth_test = true
	pricing_ui.fixed_size = true
	pricing_ui.pixel_size = 0.001
	pricing_ui.alpha_cut = Sprite3D.ALPHA_CUT_DISABLED
	pricing_ui.transparent = true
	pricing_ui.shaded = false
	pricing_ui.render_priority = 100 # Ensure on top
	add_child(pricing_ui)

	hide_ui()

func show_item(item_data: ItemData, basis_position: Vector3, is_container: bool = false, custom_name: String = "", stock_text: String = "") -> void:
	if not item_data:
		_current_item = null
		hide_ui()
		return
	
	_current_item = item_data
		
	var final_price = item_data.get_final_price()
	var base_price = item_data.price
	var max_price = item_data.get_max_selling_price()

	var added_price = final_price - base_price
	var margin_pct = (added_price / base_price) * 100.0 if base_price > 0 else 0.0

	name_label.text = custom_name if custom_name != "" else item_data.item_name
	price_label.text = "₱%.2f" % [final_price]
	comparison_label.text = "+₱%.2f (%.0f%%)" % [added_price, margin_pct]
	
	# Markup Heatmap Color
	var room = max_price - base_price
	if room > 0.01:
		var factor = clamp((final_price - base_price) / room, 0.0, 1.0)
		var markup_color: Color
		if factor < 0.5:
			# Green to Yellow
			markup_color = Color(0.49, 0.76, 0.57).lerp(Color(1.0, 1.0, 0.0), factor * 2.0)
		else:
			# Yellow to Red
			markup_color = Color(1.0, 1.0, 0.0).lerp(Color(1.0, 0.3, 0.0), (factor - 0.5) * 2.0)
		comparison_label.add_theme_color_override("font_color", markup_color)
	else:
		comparison_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

	if stock_text != "":
		stock_label.text = stock_text
		stock_label.show()
	else:
		stock_label.hide()

	if is_container:
		# Center horizontally, slightly lower vertical
		pricing_ui.global_position = basis_position + Vector3(0, 0.2, 0.2)
	else:
		# Shelf items: Center horizontally, and set at 50% of the item height
		var h: float = item_data.display_height_meters
		pricing_ui.global_position = basis_position + Vector3(0, h * 0.5, 0.15)
	
	pricing_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	pricing_ui.show()

func hide_ui() -> void:
	_current_item = null
	pricing_ui.hide()
