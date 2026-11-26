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

## Soft pastel Tier 1–10 colors (starting from soft white), readable on dark surfaces.
const TIER_COLORS: Array[Color] = [
	Color(0.96, 0.95, 0.92, 1.0), # Tier 1: Soft White
	Color(0.72, 0.93, 0.78, 1.0), # Tier 2: Pastel Mint
	Color(0.68, 0.87, 0.98, 1.0), # Tier 3: Pastel Sky Blue
	Color(0.98, 0.90, 0.64, 1.0), # Tier 4: Pastel Buttercream
	Color(0.98, 0.78, 0.64, 1.0), # Tier 5: Pastel Peach
	Color(0.82, 0.75, 0.98, 1.0), # Tier 6: Pastel Lavender
	Color(0.98, 0.74, 0.82, 1.0), # Tier 7: Pastel Rose
	Color(0.64, 0.93, 0.90, 1.0), # Tier 8: Pastel Aqua
	Color(0.98, 0.68, 0.66, 1.0), # Tier 9: Pastel Coral
	Color(1.00, 0.89, 0.58, 1.0), # Tier 10: Pastel Champagne Gold
]

static func get_tier_color(tier: int) -> Color:
	var idx := clampi(tier - 1, 0, TIER_COLORS.size() - 1)
	return TIER_COLORS[idx]

## Unified per-step color ramp for Price Lens & Price Ledger (-5 to +5, tolerance-aware).
## Every discount step (-1..-5) has a distinct green progression, and +4 vs +5 are clearly distinct reds.
static func get_price_step_color(step: int, eff_tol: int = 0) -> Color:
	if step < 0:
		match step:
			-1: return Color(0.68, 0.90, 0.68, 1.0) # Soft Sage
			-2: return Color(0.52, 0.88, 0.58, 1.0) # Fresh Mint
			-3: return Color(0.36, 0.85, 0.52, 1.0) # Vivid Leaf
			-4: return Color(0.22, 0.82, 0.56, 1.0) # Bright Emerald
			_:  return Color(0.14, 0.88, 0.70, 1.0) # Radiant Jade (-5)
	var eff_step: int = step - eff_tol
	if step == 0 and eff_step <= 2:
		return Color(1.0, 0.95, 0.86, 1.0) # Soft Cream (Base)
	if eff_step <= 1:
		return Color(0.98, 0.90, 0.62, 1.0) # Warm Cream-Gold (Very Safe)
	if eff_step == 2:
		return Color(0.96, 0.79, 0.38, 1.0) # Rich Antique Gold (Safe Max)
	if eff_step == 3:
		return Color(0.98, 0.60, 0.22, 1.0) # Warm Amber-Orange (Risky)
	if eff_step == 4:
		return Color(0.96, 0.38, 0.28, 1.0) # Coral Red-Orange (High Danger)
	return Color(0.82, 0.14, 0.18, 1.0)     # Deep Crimson Red (Extreme Danger, +5+)

const _CAT_ICONS: Dictionary = {
	"recommended": preload("res://Assets/ui/icons/sparkles.png"),
	"hot": preload("res://Assets/ui/icons/flame.png"),
	"all": preload("res://Assets/ui/icons/layers-2.png"),
	"bottle": preload("res://Assets/ui/icons/coffee.png"),
	"sachet": preload("res://Assets/ui/icons/coffee.png"),
	"sachets": preload("res://Assets/ui/icons/coffee.png"),
	"can": preload("res://Assets/ui/icons/can.png"),
	"candy": preload("res://Assets/ui/icons/gift.png"),
	"frozen": preload("res://Assets/ui/icons/snowflake.png"),
	"cigarette": preload("res://Assets/ui/icons/flame.png"),
	"snack": preload("res://Assets/ui/icons/package.png"),
	"pack": preload("res://Assets/ui/icons/package.png"),
}
const _CAT_ICON_DEFAULT: Texture2D = preload("res://Assets/ui/icons/package.png")

## Unified category icon lookup shared across Restock Menu, Price Ledger, and other overlays.
static func get_category_icon(cat_key: String) -> Texture2D:
	return _CAT_ICONS.get(cat_key.to_lower(), _CAT_ICON_DEFAULT)

const _CUSTOMER_PORTRAITS: Dictionary = {
	"brahim": preload("res://Assets/characters/portraits/Brahim Face.png"),
	"buboy": preload("res://Assets/characters/portraits/Buboy Face.png"),
	"danilo": preload("res://Assets/characters/portraits/Danilo Face.png"),
	"kuyakap": preload("res://Assets/characters/portraits/Kuya_Kap Face.png"),
	"lolopilo": preload("res://Assets/characters/portraits/LoloPilo Face.png"),
	"manangana": preload("res://Assets/characters/portraits/ManangAna Face.png"),
	"reynamayari": preload("res://Assets/characters/portraits/ReynaMayari Face.png"),
	"rodel": preload("res://Assets/characters/portraits/Rodel Face.png"),
	"rosalyn": preload("res://Assets/characters/portraits/Rosalyn Face.png"),
	"sarimanok": preload("res://Assets/characters/portraits/Sarimanok Face.png"),
	"tk": preload("res://Assets/characters/portraits/TK Face.png"),
	"unclemario": preload("res://Assets/characters/portraits/UncleMario Face.png"),
}

## Returns the cropped face portrait for a customer name, or null if not found.
static func get_customer_portrait(customer_name: String) -> Texture2D:
	var norm := customer_name.to_lower().replace(" ", "").replace(".", "").replace("_", "")
	return _CUSTOMER_PORTRAITS.get(norm, null)

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
