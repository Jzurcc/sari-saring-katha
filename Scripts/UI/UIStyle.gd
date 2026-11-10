class_name UIStyle
extends RefCounted

## Centralized UI styling helper providing consistent palette colors, StyleBox configurations,
## and button/card theme overrides for store and settings overlays.

# --- Palette Colors ---
const COLOR_TAB_BG := Color("666666")            # Background gray
const COLOR_TAB_ACTIVE := Color("7EC292")         # Nokia green active tab
const COLOR_TAB_NORMAL := Color("BFC0BA")         # Light gray inactive tab
const COLOR_TAB_LOCKED := Color("4D4D4D")         # Dark gray locked tab
const COLOR_TAB_LOCKED_FONT := Color("878787")     # Muted text for locked tabs
const COLOR_CONTENT_BG := Color("7EC292")         # Nokia green accents
const COLOR_CARD_BG := Color("7EC292")            # Product card background
const COLOR_CARD_SELECTED := Color("D59F47")      # Gold highlight when selected
const COLOR_CARD_BORDER := Color(0.15, 0.15, 0.15, 1.0) # Dark gray card border
const COLOR_CARD_OWNED_BG := Color(0.2, 0.4, 0.2, 0.6) # Dimmed green for owned upgrades
const COLOR_DETAIL_BG := Color("BFC0BA")          # Light gray detail panel
const COLOR_CANCEL := Color("C0544E")             # Red cancel button
const COLOR_CONFIRM := Color("7EC292")            # Nokia green confirm button
const COLOR_LIST_BG := Color("BFC0BA")            # Light gray list panel
const COLOR_BEIGE := Color("F5F5DC")              # Light beige for upgrade
const COLOR_DARK_BG := Color("151412")            # Dark background black
const COLOR_GOLD_TEXT := Color(1.0, 0.922, 0.792, 1.0) # Golden label text

const FONT_INDER: Font = preload("res://Assets/Fonts/Inder/Inder-Regular.ttf")

## Creates a flat styled box with uniform corners and internal padding.
static func create_flat_stylebox(
	bg_color: Color,
	corner_radius: int = 6,
	padding_x: int = 10,
	padding_y: int = 4
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.content_margin_left = padding_x
	style.content_margin_right = padding_x
	style.content_margin_top = padding_y
	style.content_margin_bottom = padding_y
	return style

## Creates a product card StyleBox with a distinct border and margin.
static func create_card_style(
	bg_color: Color = COLOR_CARD_BG,
	border_color: Color = COLOR_CARD_BORDER,
	border_width: int = 2
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

## Applies interactive state styleboxes (normal, hover, pressed, disabled) and font settings to a button.
static func style_button(
	btn: Button,
	bg_color: Color,
	font_color: Color = Color.WHITE,
	font_size: float = 14.0,
	corner_radius: int = 6
) -> void:
	if not btn:
		return
	var style := create_flat_stylebox(bg_color, corner_radius, 10, 4)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = bg_color.lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style: StyleBoxFlat = style.duplicate()
	pressed_style.bg_color = bg_color.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	var disabled_style: StyleBoxFlat = style.duplicate()
	disabled_style.bg_color = bg_color.darkened(0.5)
	disabled_style.bg_color.a = 0.6
	btn.add_theme_stylebox_override("disabled", disabled_style)

	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_color_override("font_disabled_color", font_color.darkened(0.4))
	btn.add_theme_font_size_override("font_size", int(font_size))

## Styles a tab button according to its active/locked state.
static func style_tab_button(btn: Button, is_active: bool, is_locked: bool, font_size: float = 15.0) -> void:
	if is_locked:
		style_button(btn, COLOR_TAB_LOCKED, COLOR_TAB_LOCKED_FONT, font_size)
	elif is_active:
		style_button(btn, COLOR_TAB_ACTIVE, Color.WHITE, font_size)
	else:
		style_button(btn, COLOR_TAB_NORMAL, Color.WHITE, font_size)
