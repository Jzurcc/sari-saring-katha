extends Node3D

var pricing_ui: Sprite3D
var pricing_viewport: SubViewport
var name_label: Label
var price_label: Label
var comparison_label: Label
var stock_label: Label
var pricing_panel: PanelContainer

const INDER_FONT := preload("res://Assets/Fonts/Inder/Inder-Regular.ttf")

func _ready() -> void:
	name = "PricingOverlay"
	
	pricing_viewport = SubViewport.new()
	pricing_viewport.transparent_bg = true
	pricing_viewport.size = Vector2(666, 280)
	pricing_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(pricing_viewport)

	pricing_panel = PanelContainer.new()
	pricing_viewport.add_child(pricing_panel)
	pricing_panel.size = Vector2(666, 280)
	pricing_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.082, 0.078, 0.071, 0.75) 
	style.set_corner_radius_all(26)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	pricing_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pricing_panel.add_child(vbox)

	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 34)
	name_label.add_theme_color_override("font_color", Color(1, 0.92, 0.79, 0.8))
	vbox.add_child(name_label)

	price_label = Label.new()
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 47)
	price_label.add_theme_color_override("font_color", Color(1, 0.92, 0.79))
	vbox.add_child(price_label)

	comparison_label = Label.new()
	comparison_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	comparison_label.add_theme_font_size_override("font_size", 28)
	comparison_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
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

	pricing_ui = Sprite3D.new()
	pricing_ui.texture = pricing_viewport.get_texture()
	pricing_ui.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pricing_ui.no_depth_test = true
	pricing_ui.fixed_size = true
	pricing_ui.pixel_size = 0.001
	pricing_ui.alpha_cut = Sprite3D.ALPHA_CUT_DISABLED
	pricing_ui.transparent = true
	pricing_ui.shaded = false
	pricing_ui.render_priority = 10
	add_child(pricing_ui)

	hide_ui()

func show_item(item_data: ItemData, basis_position: Vector3, is_container: bool = false, custom_name: String = "", stock_text: String = "") -> void:
	if not item_data:
		hide_ui()
		return
		
	var final_price = item_data.get_final_price()
	var base_price = item_data.price

	var added_price = final_price - base_price
	var margin_pct = (added_price / base_price) * 100.0 if base_price > 0 else 0.0

	name_label.text = custom_name if custom_name != "" else item_data.item_name
	price_label.text = "₱%.2f" % [final_price]
	comparison_label.text = "+₱%.2f (%.0f%%)" % [added_price, margin_pct]
	
	if stock_text != "":
		stock_label.text = stock_text
		stock_label.show()
	else:
		stock_label.hide()

	if is_container:
		pricing_ui.global_position = basis_position + Vector3(0, 0.3, 0.2)
	else:
		pricing_ui.global_position = basis_position + Vector3(0, item_data.display_height_meters / 2.0, 0.15)
	
	pricing_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	pricing_ui.show()

func hide_ui() -> void:
	pricing_ui.hide()
