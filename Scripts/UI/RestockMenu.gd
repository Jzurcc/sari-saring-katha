extends Control

## Calm, progressive-disclosure Wholesale Catalog for Uncle Mario.
## Built on a borderless Dark Warm Espresso canvas with 5% title-safe margins,
## category dropdown, toggleable Regulars popover, click-to-add product cards
## with contextual steppers, delayed hover tooltips, and a collapsible Order Slip drawer.

signal catalog_purchase_confirmed(total_cost: int, items_bought: Dictionary)
signal catalog_menu_closed
signal menu_close_requested

# Keep exported properties so RestockMenu.tscn doesn't lose scene overrides
@export_group("Card Sizes")
@export var card_size := Vector2(196, 174)
@export var card_icon_size := Vector2(62, 62)

@export_group("Font Sizes")
@export var card_font_size: int = 16
@export var detail_name_font_size: int = 18
@export var detail_price_font_size: int = 16
@export var order_list_font_size: int = 16
@export var list_header_font_size: int = 18
@export var tab_font_size: int = 16

@export_group("Detail Panel")
@export var detail_icon_size := Vector2(56, 56)

const PESO_ICON: Texture2D = preload("res://Assets/ui/peso_icon.png")
const IC_SPARKLES: Texture2D = preload("res://Assets/ui/icons/sparkles.png")
const IC_LAYERS: Texture2D = preload("res://Assets/ui/icons/layers-2.png")
const IC_PACKAGE: Texture2D = preload("res://Assets/ui/icons/package.png")
const IC_COFFEE: Texture2D = preload("res://Assets/ui/icons/coffee.png")
const IC_GIFT: Texture2D = preload("res://Assets/ui/icons/gift.png")
const IC_SNOWFLAKE: Texture2D = preload("res://Assets/ui/icons/snowflake.png")
const IC_FLAME: Texture2D = preload("res://Assets/ui/icons/flame.png")
const IC_USERS: Texture2D = preload("res://Assets/ui/icons/users.png")
const IC_BASKET: Texture2D = preload("res://Assets/ui/icons/shopping-basket.png")
const IC_TRUCK: Texture2D = preload("res://Assets/ui/icons/truck.png")
const IC_ZAP: Texture2D = preload("res://Assets/ui/icons/zap.png")

# Palette: Borderless Dark Warm Espresso + Antique Gold + Crisp Cream
const COL_BACKDROP := Color(0.052, 0.044, 0.038, 0.95)
const COL_SURFACE := Color(0.105, 0.090, 0.078, 0.96)
const COL_CARD := Color(0.132, 0.114, 0.098, 0.94)
const COL_CARD_HOVER := Color(0.168, 0.144, 0.122, 0.98)
const COL_CARD_ACTIVE := Color(0.188, 0.154, 0.112, 0.98)
const COL_DRAWER := Color(0.092, 0.078, 0.068, 0.98)
const COL_GOLD := Color(0.86, 0.67, 0.32, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.89, 0.58, 1.0)
const COL_CREAM := Color(1.0, 0.95, 0.86, 1.0)
const COL_CREAM_MUTED := Color(0.82, 0.76, 0.67, 0.88)
const COL_BORDER_SUBTLE := Color(0.42, 0.31, 0.18, 0.52)
const COL_OUTLINE := Color(0.05, 0.038, 0.028, 0.95)
const COL_POSITIVE := Color(0.56, 0.90, 0.56, 1.0)
const COL_CORAL := Color(0.94, 0.48, 0.44, 1.0)
const COL_HOT := Color(0.98, 0.68, 0.30, 1.0)
const COL_BTN_DARK := Color(0.18, 0.15, 0.125, 1.0)

var order: RestockOrder = RestockOrder.new()

var selected_items: Dictionary:
	get: return order.selected_items
var total_price: float:
	get: return order.total_price

var current_category: String = "recommended"
var _category_cache: Dictionary = {} # cat_key -> Array[ItemData]
var _dropdown_keys: Array[String] = []

var category_tabs: Array[String] = [
	"recommended", "all",
	"snack", "sachets", "can", "bottle", "candy",
	"pack", "frozen", "cigarette"
]
var category_labels: Dictionary = {
	"recommended": "Recommended",
	"all": "All Items",
	"snack": "Snacks",
	"sachets": "Sachets",
	"can": "Canned Goods",
	"bottle": "Beverages",
	"candy": "Candy",
	"pack": "Noodles",
	"frozen": "Frozen",
	"cigarette": "Cigarettes",
}

var _bold_font: FontVariation

# Dedicated high CanvasLayer (55) hides other HUD elements; main HUD MoneyContainer is elevated into it
var _overlay_layer: CanvasLayer
var _overlay_root: Control
var _hud_money: Control
var _hud_money_parent: Node
var _hud_money_index: int = 0

# Top Header & Toolbar references
var _shelf_cap_lbl: Label
var _fridge_cap_lbl: Label
var _category_btn: Button
var _category_backdrop: Control
var _category_popover: PanelContainer
var _category_list_box: VBoxContainer
var _regulars_btn: Button
var _slip_toggle_btn: Button
var _quick_order_btn: Button

# Main Grid & Collapsible Panels
var _grid_scroll: ScrollContainer
var _product_grid: HFlowContainer
var _grid_empty_lbl: Label
var _slip_drawer: PanelContainer
var _slip_open: bool = false
var _order_list_container: VBoxContainer
var _drawer_total_lbl: Label
var _drawer_remaining_lbl: Label
var _drawer_order_btn: Button
var _drawer_clear_btn: Button

# Popovers & Delayed Tooltip
var _regulars_backdrop: Control
var _regulars_popover: PanelContainer
var _regulars_list_box: VBoxContainer
var _fill_rec_btn: Button

var _tooltip_panel: PanelContainer
var _tooltip_title_lbl: Label
var _tooltip_price_lbl: Label
var _tooltip_meta_lbl: Label
var _tooltip_timer: Timer
var _hovered_item: ItemData = null
var _hovered_card: Control = null

var _card_nodes: Dictionary = {} # ItemData -> Dictionary


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_INDER
	_bold_font.variation_embolden = 0.58

	# Hide legacy scene children cleanly
	for child in get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false

	_build_ui()
	EventBus.restock_catalog_refresh.connect(_on_catalog_refresh_requested)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _category_popover and _category_popover.visible:
			_set_category_open(false)
		elif _regulars_popover and _regulars_popover.visible:
			_set_regulars_open(false)
		elif _slip_open:
			_set_slip_open(false)
		else:
			_on_cancel_pressed()
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.keycode == KEY_TAB:
			get_viewport().set_input_as_handled()
			_set_slip_open(not _slip_open)


func _exit_tree() -> void:
	_restore_hud_money()


func _elevate_hud_money() -> void:
	if is_instance_valid(_hud_money) or not is_instance_valid(_overlay_root):
		return
	var cur_scene := get_tree().current_scene
	if not is_instance_valid(cur_scene):
		return
	var m := cur_scene.get_node_or_null("CanvasLayer/LeftHUD/MoneyContainer") as Control
	if m == null:
		return
	_hud_money = m
	_hud_money_parent = m.get_parent()
	_hud_money_index = m.get_index()
	m.reparent(_overlay_root, true)
	if is_instance_valid(_category_backdrop):
		_overlay_root.move_child(m, _category_backdrop.get_index())
	elif is_instance_valid(_regulars_backdrop):
		_overlay_root.move_child(m, _regulars_backdrop.get_index())


func _restore_hud_money() -> void:
	if not is_instance_valid(_hud_money):
		return
	if is_instance_valid(_hud_money_parent):
		_hud_money.reparent(_hud_money_parent, true)
		_hud_money_parent.move_child(_hud_money, mini(_hud_money_index, _hud_money_parent.get_child_count() - 1))
	_hud_money = null


# ── UI Construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 55
	_overlay_layer.visible = false
	add_child(_overlay_layer)

	_overlay_root = Control.new()
	_overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.add_child(_overlay_root)

	# 1. Clean borderless full-screen Dark Warm Espresso backdrop
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = COL_BACKDROP
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_root.add_child(backdrop)

	# 2. Title-Safe Container (5% margins on all sides = 90% safe area)
	var safe_root := VBoxContainer.new()
	safe_root.anchor_left = 0.05
	safe_root.anchor_right = 0.95
	safe_root.anchor_top = 0.045
	safe_root.anchor_bottom = 0.955
	safe_root.add_theme_constant_override("separation", 16)
	_overlay_root.add_child(safe_root)

	_build_top_bar(safe_root)
	_build_toolbar(safe_root)
	_build_body_area(safe_root)
	_build_category_popover()
	_build_regulars_popover()
	_build_delayed_tooltip()


func _build_top_bar(parent: VBoxContainer) -> void:
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 14)
	parent.add_child(top_bar)

	var mid_spacer := Control.new()
	mid_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(mid_spacer)

	# Top-Right: Title + 48x48 Close Button
	var title_lbl := Label.new()
	title_lbl.text = "Uncle Mario's Wholesale"
	title_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_lbl.add_theme_font_override("font", _bold_font)
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", COL_CREAM)
	title_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	title_lbl.add_theme_constant_override("outline_size", 4)
	top_bar.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(48, 48)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_font_override("font", _bold_font)
	close_btn.add_theme_font_size_override("font_size", 20)
	_apply_button_theme(close_btn, Color(0.22, 0.14, 0.13, 0.95), COL_CORAL, COL_CREAM, 10)
	close_btn.pressed.connect(_on_cancel_pressed)
	top_bar.add_child(close_btn)


func _build_toolbar(parent: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	parent.add_child(bar)

	# Custom Lucide-icon Category Dropdown Button (100% reliable on CanvasLayer 55)
	_category_btn = Button.new()
	_category_btn.text = "Recommended ▾"
	_category_btn.icon = IC_SPARKLES
	_category_btn.custom_minimum_size = Vector2(0, 48)
	_category_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_category_btn.add_theme_font_override("font", _bold_font)
	_category_btn.add_theme_font_size_override("font_size", 18)
	_category_btn.add_theme_constant_override("icon_max_width", 20)
	_category_btn.add_theme_constant_override("h_separation", 8)
	_apply_button_theme(_category_btn, COL_SURFACE, COL_GOLD, COL_CREAM, 10, 16)
	_category_btn.pressed.connect(func(): _set_category_open(not _category_popover.visible))
	bar.add_child(_category_btn)

	# Toggleable Today's Visitors & Quick-Fill Popover Button (closed by default)
	_regulars_btn = Button.new()
	_regulars_btn.text = "Today's Visitors ▾"
	_regulars_btn.icon = preload("res://Assets/ui/icons/user-round-exclamation-point.png") if ResourceLoader.exists("res://Assets/ui/icons/user-round-exclamation-point.png") else IC_USERS
	_regulars_btn.custom_minimum_size = Vector2(0, 48)
	_regulars_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_regulars_btn.add_theme_font_override("font", UIStyle.FONT_INDER)
	_regulars_btn.add_theme_font_size_override("font_size", 17)
	_regulars_btn.add_theme_constant_override("icon_max_width", 20)
	_regulars_btn.add_theme_constant_override("h_separation", 8)
	_apply_button_theme(_regulars_btn, COL_SURFACE, COL_BORDER_SUBTLE, COL_CREAM, 10, 16)
	_regulars_btn.pressed.connect(func(): _set_regulars_open(not _regulars_popover.visible))
	bar.add_child(_regulars_btn)

	# Single Combined Shelf + Fridge Storage Rectangle (bigger & right beside Regulars)
	var storage_panel := PanelContainer.new()
	storage_panel.custom_minimum_size = Vector2(0, 48)
	storage_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st_style := UIStyle.create_flat_stylebox(COL_SURFACE, 10, 16, 8)
	st_style.border_color = COL_BORDER_SUBTLE
	st_style.set_border_width_all(1)
	storage_panel.add_theme_stylebox_override("panel", st_style)
	bar.add_child(storage_panel)

	var st_row := HBoxContainer.new()
	st_row.alignment = BoxContainer.ALIGNMENT_CENTER
	st_row.add_theme_constant_override("separation", 10)
	storage_panel.add_child(st_row)

	var sh_ic := TextureRect.new()
	sh_ic.texture = IC_PACKAGE
	sh_ic.custom_minimum_size = Vector2(20, 20)
	sh_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sh_ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sh_ic.modulate = COL_GOLD_BRIGHT
	st_row.add_child(sh_ic)

	_shelf_cap_lbl = Label.new()
	_shelf_cap_lbl.text = "Shelf 0/36"
	_shelf_cap_lbl.add_theme_font_override("font", _bold_font)
	_shelf_cap_lbl.add_theme_font_size_override("font_size", 17)
	_shelf_cap_lbl.add_theme_color_override("font_color", COL_CREAM)
	_shelf_cap_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_shelf_cap_lbl.add_theme_constant_override("outline_size", 3)
	st_row.add_child(_shelf_cap_lbl)

	var divider := Label.new()
	divider.text = "•"
	divider.add_theme_font_size_override("font_size", 17)
	divider.add_theme_color_override("font_color", COL_BORDER_SUBTLE)
	st_row.add_child(divider)

	var fr_ic := TextureRect.new()
	fr_ic.texture = IC_SNOWFLAKE
	fr_ic.custom_minimum_size = Vector2(20, 20)
	fr_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fr_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fr_ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fr_ic.modulate = COL_GOLD_BRIGHT
	st_row.add_child(fr_ic)

	_fridge_cap_lbl = Label.new()
	_fridge_cap_lbl.text = "Fridge 0/12"
	_fridge_cap_lbl.add_theme_font_override("font", _bold_font)
	_fridge_cap_lbl.add_theme_font_size_override("font_size", 17)
	_fridge_cap_lbl.add_theme_color_override("font_color", COL_CREAM)
	_fridge_cap_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_fridge_cap_lbl.add_theme_constant_override("outline_size", 3)
	st_row.add_child(_fridge_cap_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	# Toggleable Order Slip Drawer Button
	_slip_toggle_btn = Button.new()
	_slip_toggle_btn.text = "Order Slip (0) ◂"
	_slip_toggle_btn.icon = IC_BASKET
	_slip_toggle_btn.custom_minimum_size = Vector2(0, 48)
	_slip_toggle_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_slip_toggle_btn.add_theme_font_override("font", _bold_font)
	_slip_toggle_btn.add_theme_font_size_override("font_size", 17)
	_slip_toggle_btn.add_theme_constant_override("icon_max_width", 20)
	_slip_toggle_btn.add_theme_constant_override("h_separation", 8)
	_apply_button_theme(_slip_toggle_btn, COL_SURFACE, COL_BORDER_SUBTLE, COL_CREAM, 10, 16)
	_slip_toggle_btn.pressed.connect(func(): _set_slip_open(not _slip_open))
	bar.add_child(_slip_toggle_btn)

	# Direct Primary Order CTA (so players can order immediately without even opening the slip)
	_quick_order_btn = Button.new()
	_quick_order_btn.text = "Order"
	_quick_order_btn.icon = IC_TRUCK
	_quick_order_btn.custom_minimum_size = Vector2(0, 48)
	_quick_order_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_quick_order_btn.add_theme_font_override("font", _bold_font)
	_quick_order_btn.add_theme_font_size_override("font_size", 18)
	_quick_order_btn.add_theme_constant_override("icon_max_width", 20)
	_quick_order_btn.add_theme_constant_override("h_separation", 8)
	_quick_order_btn.pressed.connect(_on_confirm_pressed)
	bar.add_child(_quick_order_btn)


func _build_body_area(parent: VBoxContainer) -> void:
	var body_split := HBoxContainer.new()
	body_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_split.add_theme_constant_override("separation", 18)
	parent.add_child(body_split)

	# Left / Full-Width Borderless Product Grid
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_scroll.size_flags_stretch_ratio = 1.0
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_warm_scrollbar(_grid_scroll)
	body_split.add_child(_grid_scroll)

	var grid_col := VBoxContainer.new()
	grid_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_col.add_theme_constant_override("separation", 12)
	_grid_scroll.add_child(grid_col)

	_grid_empty_lbl = Label.new()
	_grid_empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grid_empty_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_grid_empty_lbl.add_theme_font_size_override("font_size", 18)
	_grid_empty_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	_grid_empty_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_grid_empty_lbl.add_theme_constant_override("outline_size", 3)
	_grid_empty_lbl.visible = false
	grid_col.add_child(_grid_empty_lbl)

	_product_grid = HFlowContainer.new()
	_product_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_product_grid.add_theme_constant_override("h_separation", 14)
	_product_grid.add_theme_constant_override("v_separation", 14)
	grid_col.add_child(_product_grid)

	# Right Collapsible Order Slip Drawer (closed by default)
	_slip_drawer = PanelContainer.new()
	_slip_drawer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slip_drawer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slip_drawer.size_flags_stretch_ratio = 0.46
	var drawer_style := UIStyle.create_flat_stylebox(COL_DRAWER, 14, 18, 16)
	drawer_style.border_color = COL_GOLD
	drawer_style.set_border_width_all(2)
	drawer_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	drawer_style.shadow_size = 18
	_slip_drawer.add_theme_stylebox_override("panel", drawer_style)
	_slip_drawer.visible = false
	body_split.add_child(_slip_drawer)

	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 12)
	_slip_drawer.add_child(dv)

	var dhdr := HBoxContainer.new()
	dhdr.add_theme_constant_override("separation", 8)
	dv.add_child(dhdr)

	var dtitle := Label.new()
	dtitle.text = "Order Slip"
	dtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dtitle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dtitle.add_theme_font_override("font", _bold_font)
	dtitle.add_theme_font_size_override("font_size", 22)
	dtitle.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	dtitle.add_theme_color_override("font_outline_color", COL_OUTLINE)
	dtitle.add_theme_constant_override("outline_size", 4)
	dhdr.add_child(dtitle)

	_drawer_clear_btn = Button.new()
	_drawer_clear_btn.text = "Clear"
	_drawer_clear_btn.custom_minimum_size = Vector2(68, 44)
	_drawer_clear_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_drawer_clear_btn.add_theme_font_override("font", UIStyle.FONT_INDER)
	_drawer_clear_btn.add_theme_font_size_override("font_size", 15)
	_apply_button_theme(_drawer_clear_btn, COL_BTN_DARK, COL_BORDER_SUBTLE, COL_CREAM_MUTED, 8, 12)
	_drawer_clear_btn.pressed.connect(_on_clear_order_pressed)
	dhdr.add_child(_drawer_clear_btn)

	var collapse_btn := Button.new()
	collapse_btn.text = "▸"
	collapse_btn.custom_minimum_size = Vector2(44, 44)
	collapse_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	collapse_btn.add_theme_font_override("font", _bold_font)
	collapse_btn.add_theme_font_size_override("font_size", 18)
	_apply_button_theme(collapse_btn, COL_BTN_DARK, COL_BORDER_SUBTLE, COL_CREAM, 8, 8)
	collapse_btn.pressed.connect(func(): _set_slip_open(false))
	dhdr.add_child(collapse_btn)

	var sep_top := HSeparator.new()
	var sep_line := StyleBoxLine.new()
	sep_line.color = COL_BORDER_SUBTLE
	sep_top.add_theme_stylebox_override("separator", sep_line)
	dv.add_child(sep_top)

	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_warm_scrollbar(list_scroll)
	dv.add_child(list_scroll)

	_order_list_container = VBoxContainer.new()
	_order_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_order_list_container.add_theme_constant_override("separation", 8)
	list_scroll.add_child(_order_list_container)

	var sep_bot := HSeparator.new()
	sep_bot.add_theme_stylebox_override("separator", sep_line)
	dv.add_child(sep_bot)

	var tot_row := HBoxContainer.new()
	dv.add_child(tot_row)

	var tot_lbl := Label.new()
	tot_lbl.text = "Total"
	tot_lbl.add_theme_font_override("font", _bold_font)
	tot_lbl.add_theme_font_size_override("font_size", 18)
	tot_lbl.add_theme_color_override("font_color", COL_CREAM)
	tot_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	tot_lbl.add_theme_constant_override("outline_size", 3)
	tot_row.add_child(tot_lbl)

	_drawer_total_lbl = Label.new()
	_drawer_total_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawer_total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_drawer_total_lbl.text = "₱0.00"
	_drawer_total_lbl.add_theme_font_override("font", _bold_font)
	_drawer_total_lbl.add_theme_font_size_override("font_size", 24)
	_drawer_total_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_drawer_total_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_drawer_total_lbl.add_theme_constant_override("outline_size", 4)
	tot_row.add_child(_drawer_total_lbl)

	_drawer_remaining_lbl = Label.new()
	_drawer_remaining_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_drawer_remaining_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_drawer_remaining_lbl.add_theme_font_size_override("font_size", 15)
	_drawer_remaining_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	_drawer_remaining_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_drawer_remaining_lbl.add_theme_constant_override("outline_size", 2)
	dv.add_child(_drawer_remaining_lbl)

	_drawer_order_btn = Button.new()
	_drawer_order_btn.text = "Order Delivery"
	_drawer_order_btn.icon = IC_TRUCK
	_drawer_order_btn.custom_minimum_size = Vector2(0, 48)
	_drawer_order_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_drawer_order_btn.add_theme_font_override("font", _bold_font)
	_drawer_order_btn.add_theme_font_size_override("font_size", 18)
	_drawer_order_btn.add_theme_constant_override("icon_max_width", 20)
	_drawer_order_btn.add_theme_constant_override("h_separation", 8)
	_drawer_order_btn.pressed.connect(_on_confirm_pressed)
	dv.add_child(_drawer_order_btn)


func _style_warm_scrollbar(scroll: ScrollContainer) -> void:
	var vbar := scroll.get_v_scroll_bar()
	if not is_instance_valid(vbar):
		return
	var track := UIStyle.create_flat_stylebox(Color(0.06, 0.05, 0.04, 0.72), 6, 3, 4)
	var grab := UIStyle.create_flat_stylebox(COL_GOLD, 6, 3, 4)
	var grab_hov := UIStyle.create_flat_stylebox(COL_GOLD_BRIGHT, 6, 3, 4)
	var grab_prs := UIStyle.create_flat_stylebox(COL_GOLD.darkened(0.12), 6, 3, 4)
	vbar.add_theme_stylebox_override("scroll", track)
	vbar.add_theme_stylebox_override("grabber", grab)
	vbar.add_theme_stylebox_override("grabber_highlight", grab_hov)
	vbar.add_theme_stylebox_override("grabber_pressed", grab_prs)


func _get_category_icon(cat_key: String) -> Texture2D:
	return UIStyle.get_category_icon(cat_key)


func _build_category_popover() -> void:
	_category_backdrop = Control.new()
	_category_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_category_backdrop.visible = false
	_category_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_set_category_open(false)
	)
	_overlay_root.add_child(_category_backdrop)

	_category_popover = PanelContainer.new()
	_category_popover.visible = false
	var ps := UIStyle.create_flat_stylebox(COL_DRAWER, 12, 10, 10)
	ps.border_color = COL_GOLD
	ps.set_border_width_all(2)
	ps.shadow_color = Color(0.0, 0.0, 0.0, 0.68)
	ps.shadow_size = 18
	ps.shadow_offset = Vector2(0, 6)
	_category_popover.add_theme_stylebox_override("panel", ps)
	_overlay_root.add_child(_category_popover)

	_category_list_box = VBoxContainer.new()
	_category_list_box.add_theme_constant_override("separation", 4)
	_category_popover.add_child(_category_list_box)


func _build_regulars_popover() -> void:
	# Invisible click-catcher so clicking anywhere outside closes the popover cleanly
	_regulars_backdrop = Control.new()
	_regulars_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_regulars_backdrop.visible = false
	_regulars_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_set_regulars_open(false)
	)
	_overlay_root.add_child(_regulars_backdrop)

	_regulars_popover = PanelContainer.new()
	_regulars_popover.visible = false
	var ps := UIStyle.create_flat_stylebox(COL_DRAWER, 12, 16, 14)
	ps.border_color = COL_GOLD
	ps.set_border_width_all(2)
	ps.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	ps.shadow_size = 18
	ps.shadow_offset = Vector2(0, 6)
	_regulars_popover.add_theme_stylebox_override("panel", ps)
	_overlay_root.add_child(_regulars_popover)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	_regulars_popover.add_child(pv)

	var phdr := Label.new()
	phdr.text = "Today's Visitors"
	phdr.add_theme_font_override("font", _bold_font)
	phdr.add_theme_font_size_override("font_size", 17)
	phdr.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	phdr.add_theme_color_override("font_outline_color", COL_OUTLINE)
	phdr.add_theme_constant_override("outline_size", 3)
	pv.add_child(phdr)

	_regulars_list_box = VBoxContainer.new()
	_regulars_list_box.add_theme_constant_override("separation", 8)
	pv.add_child(_regulars_list_box)

	var sep := HSeparator.new()
	var sl := StyleBoxLine.new()
	sl.color = COL_BORDER_SUBTLE
	sep.add_theme_stylebox_override("separator", sl)
	pv.add_child(sep)

	_fill_rec_btn = Button.new()
	_fill_rec_btn.text = "Auto-Fill Recommended Stock"
	_fill_rec_btn.icon = IC_ZAP
	_fill_rec_btn.custom_minimum_size = Vector2(0, 46)
	_fill_rec_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_fill_rec_btn.add_theme_font_override("font", _bold_font)
	_fill_rec_btn.add_theme_font_size_override("font_size", 16)
	_fill_rec_btn.add_theme_constant_override("icon_max_width", 18)
	_fill_rec_btn.add_theme_constant_override("h_separation", 8)
	_apply_button_theme(_fill_rec_btn, Color(0.32, 0.24, 0.13, 0.98), COL_GOLD, COL_CREAM, 8, 16)
	_fill_rec_btn.pressed.connect(func():
		_on_fill_recommended_pressed()
		_set_regulars_open(false)
	)
	pv.add_child(_fill_rec_btn)


func _build_delayed_tooltip() -> void:
	_tooltip_timer = Timer.new()
	_tooltip_timer.one_shot = true
	_tooltip_timer.wait_time = 0.10
	_tooltip_timer.timeout.connect(_show_delayed_tooltip)
	add_child(_tooltip_timer)

	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ts := UIStyle.create_flat_stylebox(Color(0.08, 0.068, 0.058, 0.98), 10, 14, 10)
	ts.border_color = COL_GOLD
	ts.set_border_width_all(2)
	ts.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	ts.shadow_size = 14
	ts.shadow_offset = Vector2(0, 4)
	_tooltip_panel.add_theme_stylebox_override("panel", ts)
	_overlay_root.add_child(_tooltip_panel)

	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.add_child(tv)

	_tooltip_title_lbl = Label.new()
	_tooltip_title_lbl.add_theme_font_override("font", _bold_font)
	_tooltip_title_lbl.add_theme_font_size_override("font_size", 17)
	_tooltip_title_lbl.add_theme_color_override("font_color", COL_CREAM)
	_tooltip_title_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_tooltip_title_lbl.add_theme_constant_override("outline_size", 3)
	_tooltip_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(_tooltip_title_lbl)

	_tooltip_price_lbl = Label.new()
	_tooltip_price_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_tooltip_price_lbl.add_theme_font_size_override("font_size", 15)
	_tooltip_price_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_tooltip_price_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_tooltip_price_lbl.add_theme_constant_override("outline_size", 2)
	_tooltip_price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(_tooltip_price_lbl)

	_tooltip_meta_lbl = Label.new()
	_tooltip_meta_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_tooltip_meta_lbl.add_theme_font_size_override("font_size", 14)
	_tooltip_meta_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	_tooltip_meta_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_tooltip_meta_lbl.add_theme_constant_override("outline_size", 2)
	_tooltip_meta_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(_tooltip_meta_lbl)


func _make_status_pill(parent: HBoxContainer, text: String) -> Label:
	var pill := PanelContainer.new()
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var s := UIStyle.create_flat_stylebox(COL_SURFACE, 8, 12, 6)
	s.border_color = COL_BORDER_SUBTLE
	s.set_border_width_all(1)
	pill.add_theme_stylebox_override("panel", s)
	parent.add_child(pill)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	lbl.add_theme_constant_override("outline_size", 3)
	pill.add_child(lbl)
	return lbl


func _apply_button_theme(btn: Button, bg: Color, border: Color, txt: Color, radius: int = 8, pad_x: int = 14) -> void:
	var normal := UIStyle.create_flat_stylebox(bg, radius, pad_x, 8)
	normal.border_color = border
	normal.set_border_width_all(2 if border == COL_GOLD or border == COL_GOLD_BRIGHT else 1)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = bg.lightened(0.10)
	hover.border_color = COL_GOLD_BRIGHT if border != COL_CORAL else COL_CORAL.lightened(0.18)

	var pressed_s: StyleBoxFlat = normal.duplicate()
	pressed_s.bg_color = bg.darkened(0.08)

	var focus_s: StyleBoxFlat = hover.duplicate()
	focus_s.border_color = COL_GOLD_BRIGHT
	focus_s.set_border_width_all(2)

	var disabled_s := UIStyle.create_flat_stylebox(Color(0.13, 0.11, 0.095, 0.70), radius, pad_x, 8)
	disabled_s.border_color = Color(0.28, 0.24, 0.20, 0.45)
	disabled_s.set_border_width_all(1)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed_s)
	btn.add_theme_stylebox_override("focus", focus_s)
	btn.add_theme_stylebox_override("disabled", disabled_s)
	btn.add_theme_color_override("font_color", txt)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", txt)
	btn.add_theme_color_override("font_focus_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.58, 0.53, 0.46, 0.55))
	btn.add_theme_color_override("font_outline_color", COL_OUTLINE)
	btn.add_theme_constant_override("outline_size", 3)


# ── Lifecycle & Open / Close ─────────────────────────────────────────────────

func _on_catalog_refresh_requested() -> void:
	if is_visible_in_tree():
		_build_category_cache()
		_refresh_regulars_popover_content()
		_rebuild_category_dropdown()
		_select_category(current_category)
		_refresh_capacity_and_wallet()


func open_menu() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	StoryManager.ensure_daily_demand_rolled()
	_build_category_cache()
	order.clear()
	_set_category_open(false)
	_set_regulars_open(false)
	_set_slip_open(false)
	_hide_tooltip()
	_refresh_regulars_popover_content()

	var rec_items := _get_unlocked_items_for_category("recommended")
	var start_cat := "recommended" if not rec_items.is_empty() else "all"
	current_category = start_cat
	_rebuild_category_dropdown()
	_select_category(start_cat)
	_update_order_list()
	_refresh_capacity_and_wallet()

	show()
	_overlay_layer.visible = true
	_elevate_hud_money()
	_animate_entrance()
	if is_instance_valid(AudioManager):
		AudioManager.play_restock_bgm()


func _animate_entrance() -> void:
	_overlay_root.modulate.a = 0.0
	_overlay_root.scale = Vector2(0.985, 0.985)
	_overlay_root.pivot_offset = get_viewport_rect().size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_overlay_root, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_overlay_root, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_slip_open(open_state: bool) -> void:
	_slip_open = open_state
	if not _slip_drawer:
		return
	if _slip_open:
		_set_regulars_open(false)
		_slip_drawer.visible = true
		_slip_drawer.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_slip_drawer, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_slip_drawer.visible = false
	_update_slip_toggle_ui()


func _set_category_open(open_state: bool) -> void:
	if not _category_popover:
		return
	if open_state:
		_set_regulars_open(false)
		_rebuild_category_dropdown()
	_category_backdrop.visible = open_state
	_category_popover.visible = open_state
	_update_category_button_label()
	if open_state:
		var btn_rect := _category_btn.get_global_rect()
		_category_popover.position = Vector2(btn_rect.position.x, btn_rect.end.y + 8.0)
		_category_popover.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_category_popover, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_regulars_open(open_state: bool) -> void:
	if not _regulars_popover:
		return
	if open_state:
		_set_category_open(false)
	_regulars_backdrop.visible = open_state
	_regulars_popover.visible = open_state
	var rev_count := StoryManager.get_revealed_expected_regulars().size()
	var suffix := " ▴" if open_state else " ▾"
	_regulars_btn.text = ("Today's Regulars (%d)%s" % [rev_count, suffix]) if rev_count > 0 else ("Today's Regulars%s" % suffix)
	if open_state:
		_refresh_regulars_popover_content()
		var btn_rect := _regulars_btn.get_global_rect()
		_regulars_popover.position = Vector2(btn_rect.position.x, btn_rect.end.y + 8.0)
		_regulars_popover.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_regulars_popover, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ── Category Cache & Custom Lucide Dropdown ──────────────────────────────────

func _build_category_cache() -> void:
	_category_cache.clear()
	for item in InventoryManager.get_all_items():
		if not item or not item.can_be_sold:
			continue
		var cat := item.category
		if cat == "sachet":
			if "/sachetcontainers/" in item.resource_path:
				continue
			cat = "sachets"
		if not _category_cache.has(cat):
			var empty: Array[ItemData] = []
			_category_cache[cat] = empty
		_category_cache[cat].append(item)


func _update_category_button_label() -> void:
	if not _category_btn:
		return
	var base_label := str(category_labels.get(current_category, current_category.capitalize()))
	var cnt := _get_unlocked_items_for_category(current_category).size()
	var arrow := " ▴" if (_category_popover and _category_popover.visible) else " ▾"
	_category_btn.text = "%s (%d)%s" % [base_label, cnt, arrow]
	_category_btn.icon = _get_category_icon(current_category)


func _rebuild_category_dropdown() -> void:
	if not _category_list_box:
		return
	for child in _category_list_box.get_children():
		child.queue_free()
	_dropdown_keys.clear()

	for cat_key in category_tabs:
		var unlocked_items := _get_unlocked_items_for_category(cat_key)
		var is_locked := unlocked_items.is_empty() and cat_key != "recommended" and cat_key != "all"
		var base_label := str(category_labels.get(cat_key, cat_key.capitalize()))
		_dropdown_keys.append(cat_key)

		var opt := Button.new()
		opt.alignment = HORIZONTAL_ALIGNMENT_LEFT
		opt.icon = _get_category_icon(cat_key)
		opt.custom_minimum_size = Vector2(240, 44)
		opt.disabled = is_locked
		opt.mouse_default_cursor_shape = Control.CURSOR_ARROW if is_locked else Control.CURSOR_POINTING_HAND
		opt.add_theme_font_override("font", _bold_font if cat_key == current_category else UIStyle.FONT_INDER)
		opt.add_theme_font_size_override("font_size", 17)
		opt.add_theme_constant_override("icon_max_width", 20)
		opt.add_theme_constant_override("h_separation", 10)
		opt.text = ("%s (Locked)" % base_label) if is_locked else ("%s (%d)" % [base_label, unlocked_items.size()])

		var is_active := (cat_key == current_category)
		var bg := COL_CARD_ACTIVE if is_active else Color(0.11, 0.095, 0.082, 0.90)
		var border := COL_GOLD if is_active else Color(0.0, 0.0, 0.0, 0.0)
		var txt := COL_GOLD_BRIGHT if is_active else COL_CREAM
		_apply_button_theme(opt, bg, border, txt, 8, 14)
		opt.pressed.connect(func():
			AudioManager.play_sfx("tab_switch")
			_select_category(cat_key)
			_set_category_open(false)
		)
		_category_list_box.add_child(opt)

	_update_category_button_label()


func _select_category(cat_key: String) -> void:
	current_category = cat_key
	_update_category_button_label()
	_hide_tooltip()
	_populate_grid(cat_key)


func _is_item_currently_requested_oos(item: ItemData) -> bool:
	if not item:
		return false
	if InventoryManager.get_total_item_stock(item) > 0:
		return false
	var spawner := get_tree().get_first_node_in_group("customer_spawner")
	if not is_instance_valid(spawner) or not ("counter_slots" in spawner):
		return false
	for cust in spawner.counter_slots:
		if not is_instance_valid(cust) or not cust.transaction_context:
			continue
		for want in cust.transaction_context.desired_items:
			if want == item or (want and want.resource_path != "" and want.resource_path == item.resource_path):
				return true
	return false


func _get_item_priority(item: ItemData) -> int:
	if _is_item_currently_requested_oos(item):
		return 5
	var stock := InventoryManager.get_total_item_stock(item)
	var is_hot := is_instance_valid(StoreEventManager) and StoreEventManager.is_item_in_demand(item)
	var is_missed := StoryManager.get_missed_count(item) > 0
	var is_regular_match := not StoryManager.get_regulars_who_like_item(item, true).is_empty()
	var is_deal := StoryManager.is_item_on_sulit_deal(item)

	if is_hot and stock <= 2:
		return 10
	if is_missed and stock <= 1:
		return 20
	if is_regular_match and stock <= 2:
		return 30
	if is_deal and stock <= 3:
		return 40
	if stock <= 0:
		return 50
	if stock == 1:
		return 60
	if is_hot:
		return 70
	if is_deal:
		return 80
	return 999


func _get_unlocked_items_for_category(cat_key: String) -> Array[ItemData]:
	var result: Array[ItemData] = []
	if cat_key == "recommended":
		for item in InventoryManager.get_all_items():
			if not item or not item.can_be_sold or item.tier > StoryManager.current_tier:
				continue
			if "/sachetcontainers/" in item.resource_path:
				continue
			if _get_item_priority(item) < 900:
				result.append(item)
		result.sort_custom(func(a: ItemData, b: ItemData) -> bool:
			var pa := _get_item_priority(a)
			var pb := _get_item_priority(b)
			if pa != pb:
				return pa < pb
			var at := a.get_effective_tier()
			var bt := b.get_effective_tier()
			if at != bt:
				return at > bt
			return a.item_name.naturalnocasecmp_to(b.item_name) < 0
		)
		return result

	if cat_key == "all":
		for item in InventoryManager.get_all_items():
			if not item or not item.can_be_sold or item.tier > StoryManager.current_tier:
				continue
			if "/sachetcontainers/" in item.resource_path:
				continue
			result.append(item)
		result.sort_custom(func(a: ItemData, b: ItemData) -> bool:
			var at := a.get_effective_tier()
			var bt := b.get_effective_tier()
			if at != bt:
				return at > bt
			return a.item_name.naturalnocasecmp_to(b.item_name) < 0
		)
		return result

	if _category_cache.has(cat_key):
		for item in _category_cache[cat_key]:
			if item.tier <= StoryManager.current_tier:
				result.append(item)
	result.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		if a.tier != b.tier:
			return a.tier > b.tier
		return a.item_name.naturalnocasecmp_to(b.item_name) < 0
	)
	return result


# ── Regulars Popover & Capacity / Wallet ─────────────────────────────────────

func _refresh_regulars_popover_content() -> void:
	for child in _regulars_list_box.get_children():
		child.queue_free()

	var revealed := StoryManager.get_revealed_expected_regulars()
	var max_slots := StoryManager.get_revealed_regular_count()
	var suffix := " ▴" if (_regulars_popover and _regulars_popover.visible) else " ▾"
	_regulars_btn.text = ("Today's Visitors (%d)%s" % [revealed.size(), suffix]) if revealed.size() > 0 else ("Today's Visitors%s" % suffix)

	if max_slots <= 0:
		var hint := Label.new()
		hint.text = "Upgrade the Barangay Radio to reveal\nwhich visitors are dropping by today."
		hint.add_theme_font_override("font", UIStyle.FONT_INDER)
		hint.add_theme_font_size_override("font_size", 15)
		hint.add_theme_color_override("font_color", COL_CREAM_MUTED)
		_regulars_list_box.add_child(hint)
		return

	if revealed.is_empty():
		var tune_hint := Label.new()
		tune_hint.text = "Tune in to Papa Ulap on your Counter Radio\nto spot Today's Visitors."
		tune_hint.add_theme_font_override("font", UIStyle.FONT_INDER)
		tune_hint.add_theme_font_size_override("font_size", 15)
		tune_hint.add_theme_color_override("font_color", COL_CREAM_MUTED)
		_regulars_list_box.add_child(tune_hint)
		return

	for c in revealed:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var portrait_tex: Texture2D = UIStyle.get_customer_portrait(c.character_name)
		if portrait_tex == null:
			portrait_tex = c.sprite_texture
		if portrait_tex:
			var thumb := TextureRect.new()
			thumb.custom_minimum_size = Vector2(36, 36)
			thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			thumb.texture = portrait_tex
			row.add_child(thumb)

		var fav_names: PackedStringArray = []
		for f_cat in c.get_favorite_categories():
			var ui_key := "sachets" if f_cat == "sachet" else f_cat
			fav_names.append(str(category_labels.get(ui_key, f_cat.capitalize())))
		var fav_str := ", ".join(fav_names)

		var lbl := Label.new()
		lbl.text = "%s  •  %s" % [c.character_name, fav_str]
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", COL_CREAM)
		row.add_child(lbl)

		_regulars_list_box.add_child(row)

	var hidden_left := maxi(0, StoryManager.todays_expected_regulars.size() - revealed.size())
	if hidden_left > 0:
		var more_lbl := Label.new()
		more_lbl.text = "+%d more hidden (upgrade Barangay Radio)" % hidden_left
		more_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		more_lbl.add_theme_font_size_override("font_size", 14)
		more_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
		_regulars_list_box.add_child(more_lbl)


func _refresh_capacity_and_wallet() -> void:
	var eff_types := order.get_effective_types()
	var shelf_owned := InventoryManager.get_total_owned_count(ItemData.ItemType.SHELF)
	var shelf_limit := InventoryManager.get_capacity_limit(ItemData.ItemType.SHELF)
	var shelf_add := int(eff_types.get(ItemData.ItemType.SHELF, 0))
	if shelf_owned + shelf_add >= shelf_limit:
		_shelf_cap_lbl.text = "Shelf FULL (%d/%d)" % [shelf_owned + shelf_add, shelf_limit]
		_shelf_cap_lbl.add_theme_color_override("font_color", COL_CORAL)
	elif shelf_add > 0:
		_shelf_cap_lbl.text = "Shelf %d +%d / %d" % [shelf_owned, shelf_add, shelf_limit]
		_shelf_cap_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	else:
		_shelf_cap_lbl.text = "Shelf %d/%d" % [shelf_owned, shelf_limit]
		_shelf_cap_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)

	var fridge_owned := InventoryManager.get_total_owned_count(ItemData.ItemType.FRIDGE)
	var fridge_limit := InventoryManager.get_capacity_limit(ItemData.ItemType.FRIDGE)
	var fridge_add := int(eff_types.get(ItemData.ItemType.FRIDGE, 0))
	if fridge_owned + fridge_add >= fridge_limit:
		_fridge_cap_lbl.text = "Fridge FULL (%d/%d)" % [fridge_owned + fridge_add, fridge_limit]
		_fridge_cap_lbl.add_theme_color_override("font_color", COL_CORAL)
	elif fridge_add > 0:
		_fridge_cap_lbl.text = "Fridge %d +%d / %d" % [fridge_owned, fridge_add, fridge_limit]
		_fridge_cap_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	else:
		_fridge_cap_lbl.text = "Fridge %d/%d" % [fridge_owned, fridge_limit]
		_fridge_cap_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)


# ── Calm Product Cards (Click to +1, Contextual Stepper when qty > 0) ────────

func _populate_grid(cat_key: String) -> void:
	for child in _product_grid.get_children():
		child.queue_free()
	_card_nodes.clear()

	var items := _get_unlocked_items_for_category(cat_key)
	if items.is_empty():
		_grid_empty_lbl.visible = true
		_grid_empty_lbl.text = "All shelves look well-stocked right now! Choose 'All Items' in the dropdown to browse everything." if cat_key == "recommended" else "No unlocked items in this category yet."
		return

	_grid_empty_lbl.visible = false
	for item in items:
		_product_grid.add_child(_create_product_card(item))


func _create_product_card(item: ItemData) -> PanelContainer:
	var card := PanelContainer.new()
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var style := UIStyle.create_flat_stylebox(COL_CARD, 12, 16, 12)
	style.border_color = COL_BORDER_SUBTLE
	style.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", style)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)

	# Top quiet status row (only shows -20% Wholesale Deal or OUT badge)
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_END
	top_row.custom_minimum_size = Vector2(0, 22)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top_row)

	var status_pill := PanelContainer.new()
	status_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_pill.visible = false
	var status_style := UIStyle.create_flat_stylebox(Color(0, 0, 0, 0.35), 6, 8, 2)
	status_style.set_border_width_all(1)
	status_pill.add_theme_stylebox_override("panel", status_style)
	var status_lbl := Label.new()
	status_lbl.add_theme_font_override("font", _bold_font)
	status_lbl.add_theme_font_size_override("font_size", 14)
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_pill.add_child(status_lbl)
	top_row.add_child(status_pill)

	# Crisp 76x76 centered item icon (locks gentle card width via 76px + margins without 3-digit hardcoded vector)
	var icon_wrap := MarginContainer.new()
	icon_wrap.add_theme_constant_override("margin_left", 42)
	icon_wrap.add_theme_constant_override("margin_right", 42)
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon_wrap)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(76, 76)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item.texture:
		icon.texture = item.texture
	icon_wrap.add_child(icon)

	# Item Name (18px bold, 3px outline)
	var name_lbl := Label.new()
	name_lbl.text = item.item_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_override("font", _bold_font)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", COL_CREAM)
	name_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	name_lbl.add_theme_constant_override("outline_size", 3)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_lbl)

	# Fixed 44px bottom slot: swaps cleanly between Glance Info (qty == 0) and Stepper (qty > 0)
	var bottom_slot := MarginContainer.new()
	bottom_slot.custom_minimum_size = Vector2(0, 44)
	bottom_slot.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(bottom_slot)

	# State A (qty == 0): Clean Price + Stock row
	var glance_row := HBoxContainer.new()
	glance_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glance_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_slot.add_child(glance_row)

	var eff_cost := order.get_effective_unit_price(item)
	var is_discounted := eff_cost < item.price - 0.01

	var price_lbl := Label.new()
	price_lbl.text = "₱%d" % int(roundf(eff_cost))
	price_lbl.add_theme_font_override("font", _bold_font)
	price_lbl.add_theme_font_size_override("font_size", 17)
	price_lbl.add_theme_color_override("font_color", COL_POSITIVE if is_discounted else COL_GOLD_BRIGHT)
	price_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	price_lbl.add_theme_constant_override("outline_size", 3)
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glance_row.add_child(price_lbl)

	var g_spacer := Control.new()
	g_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glance_row.add_child(g_spacer)

	var stock_lbl := Label.new()
	stock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stock_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	stock_lbl.add_theme_font_size_override("font_size", 15)
	stock_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	stock_lbl.add_theme_constant_override("outline_size", 2)
	stock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glance_row.add_child(stock_lbl)

	# State B (qty > 0): Generous 44px − / qty / + Stepper
	var stepper_row := HBoxContainer.new()
	stepper_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stepper_row.add_theme_constant_override("separation", 10)
	stepper_row.visible = false
	bottom_slot.add_child(stepper_row)

	var minus_btn := _make_stepper_btn("−", false)
	var qty_lbl := Label.new()
	qty_lbl.custom_minimum_size = Vector2(36, 0)
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_lbl.add_theme_font_override("font", _bold_font)
	qty_lbl.add_theme_font_size_override("font_size", 18)
	qty_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	qty_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	qty_lbl.add_theme_constant_override("outline_size", 3)
	qty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plus_btn := _make_stepper_btn("+", true)

	stepper_row.add_child(minus_btn)
	stepper_row.add_child(qty_lbl)
	stepper_row.add_child(plus_btn)

	minus_btn.pressed.connect(_on_card_stepper.bind(item, -1))
	plus_btn.pressed.connect(_on_card_stepper.bind(item, 1))
	card.gui_input.connect(_on_card_gui_input.bind(item, card))
	card.mouse_entered.connect(_on_card_mouse_entered.bind(item, card))
	card.mouse_exited.connect(_on_card_mouse_exited.bind(item, card))
	card.focus_entered.connect(func(): _refresh_single_card(item))
	card.focus_exited.connect(func(): _refresh_single_card(item))

	_card_nodes[item] = {
		"card": card,
		"style": style,
		"status_pill": status_pill,
		"status_style": status_style,
		"status_lbl": status_lbl,
		"glance_row": glance_row,
		"stepper_row": stepper_row,
		"stock_lbl": stock_lbl,
		"qty_lbl": qty_lbl,
	}
	_refresh_single_card(item)
	return card


func _make_stepper_btn(glyph: String, is_plus: bool) -> Button:
	var btn := Button.new()
	btn.text = glyph
	btn.custom_minimum_size = Vector2(44, 44)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", _bold_font)
	btn.add_theme_font_size_override("font_size", 20)
	var bg := Color(0.38, 0.28, 0.13, 1.0) if is_plus else COL_BTN_DARK
	var border := COL_GOLD if is_plus else COL_BORDER_SUBTLE
	_apply_button_theme(btn, bg, border, COL_CREAM, 8, 8)
	return btn


func _refresh_single_card(item: ItemData) -> void:
	if not _card_nodes.has(item):
		return
	var refs: Dictionary = _card_nodes[item]
	var card: PanelContainer = refs["card"]
	var style: StyleBoxFlat = refs["style"]
	var status_pill: PanelContainer = refs["status_pill"]
	var status_style: StyleBoxFlat = refs["status_style"]
	var status_lbl: Label = refs["status_lbl"]
	var glance_row: HBoxContainer = refs["glance_row"]
	var stepper_row: HBoxContainer = refs["stepper_row"]
	var stock_lbl: Label = refs["stock_lbl"]
	var qty_lbl: Label = refs["qty_lbl"]

	var stock := InventoryManager.get_total_item_stock(item)
	var max_s := InventoryManager.get_max_stock(item)
	var in_basket := order.get_item_count(item)
	var is_requested_oos := _is_item_currently_requested_oos(item)
	var is_deal := StoryManager.is_item_on_sulit_deal(item)
	var is_hot := is_instance_valid(StoreEventManager) and StoreEventManager.is_item_in_demand(item)

	# Top pill: redundant color + text label for Requested (OOS) / Deals / Demand
	if is_requested_oos:
		status_pill.visible = true
		status_lbl.text = "Requested"
		status_lbl.add_theme_color_override("font_color", COL_CORAL)
		status_style.border_color = COL_CORAL
		status_style.bg_color = Color(COL_CORAL.r, COL_CORAL.g, COL_CORAL.b, 0.18)
	elif is_deal:
		status_pill.visible = true
		status_lbl.text = "-20%"
		status_lbl.add_theme_color_override("font_color", COL_POSITIVE)
		status_style.border_color = COL_POSITIVE
		status_style.bg_color = Color(COL_POSITIVE.r, COL_POSITIVE.g, COL_POSITIVE.b, 0.16)
	elif is_hot:
		status_pill.visible = true
		status_lbl.text = "Hot"
		status_lbl.add_theme_color_override("font_color", COL_HOT)
		status_style.border_color = COL_HOT
		status_style.bg_color = Color(COL_HOT.r, COL_HOT.g, COL_HOT.b, 0.16)
	else:
		status_pill.visible = false

	# Stock label (when qty == 0)
	if max_s < 50 and stock >= max_s:
		stock_lbl.text = "Full (%d)" % stock
		stock_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	else:
		stock_lbl.text = "Stock: %d" % stock
		stock_lbl.add_theme_color_override("font_color", COL_CORAL if stock <= 0 else COL_CREAM_MUTED)

	# Contextual toggle: Glance Row vs Stepper Row
	if in_basket > 0:
		glance_row.visible = false
		stepper_row.visible = true
		qty_lbl.text = "×%d" % in_basket
	else:
		glance_row.visible = true
		stepper_row.visible = false

	var is_hovered := (_hovered_item == item)
	var has_kbd_focus := card.has_focus()
	if in_basket > 0:
		style.bg_color = COL_CARD_ACTIVE
		style.border_color = COL_GOLD_BRIGHT if (is_hovered or has_kbd_focus) else COL_GOLD
		style.set_border_width_all(2)
	elif is_hovered or has_kbd_focus:
		style.bg_color = COL_CARD_HOVER
		style.border_color = COL_GOLD_BRIGHT if has_kbd_focus else COL_GOLD
		style.set_border_width_all(2)
	else:
		style.bg_color = COL_CARD
		style.border_color = COL_BORDER_SUBTLE
		style.set_border_width_all(1)


func _refresh_all_visible_cards() -> void:
	for item in _card_nodes.keys():
		_refresh_single_card(item)


func _on_card_gui_input(event: InputEvent, item: ItemData, card: Control) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_on_card_stepper(item, 1)
				_pulse_card(card)
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_on_card_stepper(item, -1)
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_card_stepper(item, 1)
		_pulse_card(card)


func _pulse_card(card: Control) -> void:
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size * 0.5
	var tw := create_tween()
	tw.tween_property(card, "scale", Vector2(1.03, 1.03), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_card_stepper(item: ItemData, delta: int) -> void:
	if delta > 0:
		if not _try_add_item_to_order(item):
			return
	else:
		if order.get_item_count(item) <= 0:
			return
		AudioManager.play_sfx("drop")
		order.remove_item(item)
	_update_order_list()
	_refresh_all_visible_cards()
	_refresh_capacity_and_wallet()
	if _tooltip_panel.visible and _hovered_item == item:
		_populate_tooltip(item)


# ── Layer 2: Delayed Hover Tooltip (350ms) ───────────────────────────────────

func _on_card_mouse_entered(item: ItemData, card: Control) -> void:
	_hovered_item = item
	_hovered_card = card
	_refresh_single_card(item)
	_tooltip_panel.visible = false
	_tooltip_timer.start(0.10)


func _on_card_mouse_exited(item: ItemData, _card: Control) -> void:
	if _hovered_item == item:
		_hovered_item = null
		_hovered_card = null
		_hide_tooltip()
	_refresh_single_card(item)


func _hide_tooltip() -> void:
	if _tooltip_timer:
		_tooltip_timer.stop()
	if _tooltip_panel:
		_tooltip_panel.visible = false


func _show_delayed_tooltip() -> void:
	if _hovered_item == null or not is_instance_valid(_hovered_card):
		return
	_populate_tooltip(_hovered_item)
	_tooltip_panel.size = Vector2.ZERO
	_tooltip_panel.visible = true
	_tooltip_panel.modulate.a = 0.0

	var vp_size := get_viewport_rect().size
	var c_rect := _hovered_card.get_global_rect()
	var pos := Vector2(c_rect.position.x, c_rect.end.y + 8.0)
	if pos.y + 96.0 > vp_size.y * 0.95:
		pos.y = maxf(vp_size.y * 0.05, c_rect.position.y - 96.0)
	pos.x = clampf(pos.x, vp_size.x * 0.05, vp_size.x * 0.95 - 260.0)
	_tooltip_panel.position = pos

	var tw := create_tween()
	tw.tween_property(_tooltip_panel, "modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _populate_tooltip(item: ItemData) -> void:
	_tooltip_title_lbl.text = item.item_name
	var ui_cat_key := "sachets" if item.category == "sachet" else item.category
	var cat_label := str(category_labels.get(ui_cat_key, item.category.capitalize()))
	_tooltip_price_lbl.text = "%s  •  Tier %d" % [cat_label, item.tier]

	var notes: PackedStringArray = []
	var stock := InventoryManager.get_total_item_stock(item)
	var max_s := InventoryManager.get_max_stock(item)
	notes.append("Stock: %d/%d" % [stock, max_s] if max_s < 50 else "Stock: %d" % stock)
	if _is_item_currently_requested_oos(item):
		notes.append("Requested Now (Out of Stock)")
	if is_instance_valid(StoreEventManager) and StoreEventManager.is_item_in_demand(item):
		notes.append("In Demand Today")
	var fans := StoryManager.get_regulars_who_like_item(item, true)
	if not fans.is_empty():
		var fnames: PackedStringArray = []
		for f in fans:
			fnames.append(f.character_name.split(" ")[0])
		notes.append("Liked by " + ", ".join(fnames))
	_tooltip_meta_lbl.text = "  •  ".join(notes)


# ── Auto-Fill, Order Slip & Confirmation ─────────────────────────────────────

func _on_fill_recommended_pressed() -> void:
	var candidates := _get_unlocked_items_for_category("recommended")
	if candidates.is_empty():
		EventBus.show_notification.emit("Already Stocked!", "No urgent low-stock items to fill.", "interact")
		return

	var added_any := false
	for item in candidates:
		var stock := InventoryManager.get_total_item_stock(item)
		var already := order.get_item_count(item)
		var target := 2 if _get_item_priority(item) <= 30 else 1
		var needed := maxi(0, target - (stock + already))
		for _n in range(needed):
			var check := order.can_add(item, _get_money())
			if not check.ok:
				break
			order.add_item(item)
			added_any = true

	if added_any:
		AudioManager.play_sfx("pickup")
		_update_order_list()
		_refresh_all_visible_cards()
		_refresh_capacity_and_wallet()
		_set_slip_open(true)
	else:
		EventBus.show_notification.emit("Basket Full or Low Funds", "Cannot auto-add more recommended items within budget or shelf space.", "error")


func _on_clear_order_pressed() -> void:
	if order.is_empty():
		return
	AudioManager.play_sfx("drop")
	order.clear()
	_update_order_list()
	_refresh_all_visible_cards()
	_refresh_capacity_and_wallet()


func _try_add_item_to_order(item: ItemData) -> bool:
	var check := order.can_add(item, _get_money())
	if not check.ok:
		if check.title != "":
			EventBus.show_notification.emit(check.title, check.message, check.sfx)
		if check.sfx != "":
			AudioManager.play_sfx(check.sfx)
		elif check.error == "insufficient_funds":
			EventBus.insufficient_funds.emit()
		return false

	AudioManager.play_sfx("pickup")
	order.add_item(item)
	return true


func _get_total_item_units() -> int:
	var sum_units := 0
	for cnt in order.selected_items.values():
		sum_units += int(cnt)
	return sum_units


func _update_slip_toggle_ui() -> void:
	if not _slip_toggle_btn:
		return
	var units := _get_total_item_units()
	var arrow := "▸" if _slip_open else "◂"
	if units > 0:
		_slip_toggle_btn.text = "Order Slip (%d) • ₱%d %s" % [units, int(roundf(order.total_price)), arrow]
		_apply_button_theme(_slip_toggle_btn, COL_CARD_ACTIVE, COL_GOLD, COL_GOLD_BRIGHT, 10, 18)
	else:
		_slip_toggle_btn.text = "Order Slip (0) %s" % arrow
		_apply_button_theme(_slip_toggle_btn, COL_SURFACE, COL_BORDER_SUBTLE, COL_CREAM, 10, 18)


func _update_order_list() -> void:
	for child in _order_list_container.get_children():
		child.queue_free()

	if order.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Your slip is empty.\nClick any item card to add +1."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		empty_lbl.add_theme_font_size_override("font_size", 16)
		empty_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
		_order_list_container.add_child(empty_lbl)
	else:
		var items_dict := order.get_items()
		for item in items_dict.keys():
			var count: int = items_dict[item]
			if count <= 0:
				continue
			_order_list_container.add_child(_create_order_row(item, count))

	_drawer_clear_btn.disabled = order.is_empty()
	_update_slip_toggle_ui()
	_update_total_amount_ui()


func _update_total_amount_ui() -> void:
	var money := _get_money()
	var can_order := order.total_price > 0.0 and order.total_price <= money
	var rem := money - order.total_price

	_drawer_total_lbl.text = "₱%.2f" % order.total_price
	_drawer_remaining_lbl.text = "Wallet after order: ₱%.2f" % maxf(0.0, rem)

	_quick_order_btn.disabled = not can_order
	_drawer_order_btn.disabled = not can_order

	if can_order:
		var label_txt := "Order • ₱%d" % int(roundf(order.total_price))
		_quick_order_btn.text = label_txt
		_drawer_order_btn.text = "Order Delivery • ₱%d" % int(roundf(order.total_price))
		_apply_button_theme(_quick_order_btn, Color(0.56, 0.41, 0.16, 1.0), COL_GOLD_BRIGHT, Color.WHITE, 10, 20)
		_apply_button_theme(_drawer_order_btn, Color(0.56, 0.41, 0.16, 1.0), COL_GOLD_BRIGHT, Color.WHITE, 10, 20)
	else:
		_quick_order_btn.text = "Order"
		_drawer_order_btn.text = "Order Delivery"
		_apply_button_theme(_quick_order_btn, COL_BTN_DARK, COL_BORDER_SUBTLE, COL_CREAM_MUTED, 10, 20)
		_apply_button_theme(_drawer_order_btn, COL_BTN_DARK, COL_BORDER_SUBTLE, COL_CREAM_MUTED, 10, 20)


func _create_order_row(item: ItemData, count: int) -> PanelContainer:
	var row_card := PanelContainer.new()
	var s := UIStyle.create_flat_stylebox(COL_CARD, 8, 10, 6)
	s.border_color = COL_BORDER_SUBTLE
	s.set_border_width_all(1)
	row_card.add_theme_stylebox_override("panel", s)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row_card.add_child(row)

	if item.texture:
		var thumb := TextureRect.new()
		thumb.texture = item.texture
		thumb.custom_minimum_size = Vector2(36, 36)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(thumb)

	var name_lbl := Label.new()
	name_lbl.text = item.item_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", COL_CREAM)
	row.add_child(name_lbl)

	var minus_btn := _make_stepper_btn("−", false)
	minus_btn.pressed.connect(_on_card_stepper.bind(item, -1))
	row.add_child(minus_btn)

	var count_lbl := Label.new()
	count_lbl.text = str(count)
	count_lbl.custom_minimum_size = Vector2(26, 0)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	count_lbl.add_theme_font_override("font", _bold_font)
	count_lbl.add_theme_font_size_override("font_size", 16)
	count_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	row.add_child(count_lbl)

	var plus_btn := _make_stepper_btn("+", true)
	plus_btn.pressed.connect(_on_card_stepper.bind(item, 1))
	row.add_child(plus_btn)

	var sub_lbl := Label.new()
	sub_lbl.custom_minimum_size = Vector2(54, 0)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sub_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sub_lbl.text = "₱%d" % int(roundf(order.get_effective_unit_price(item) * count))
	sub_lbl.add_theme_font_override("font", _bold_font)
	sub_lbl.add_theme_font_size_override("font_size", 15)
	sub_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	row.add_child(sub_lbl)

	return row_card


# ── Actions ──────────────────────────────────────────────────────────────────

func _close_restock_screen() -> void:
	_hide_tooltip()
	_set_category_open(false)
	_set_regulars_open(false)
	if is_instance_valid(AudioManager):
		AudioManager.stop_bgm_override()
	var tween := create_tween()
	tween.tween_property(_overlay_root, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		_restore_hud_money()
		_overlay_layer.visible = false
		_overlay_root.modulate.a = 1.0
		menu_close_requested.emit()
		hide()
	)


func _on_cancel_pressed() -> void:
	AudioManager.play_sfx("drop")
	MarioManager.cancel_restock()
	catalog_menu_closed.emit()
	_close_restock_screen()


func _on_confirm_pressed() -> void:
	if _quick_order_btn:
		_quick_order_btn.disabled = true
	if _drawer_order_btn:
		_drawer_order_btn.disabled = true

	var actual_items := order.get_actual_items()
	var cost := order.get_total_cost()
	if actual_items.is_empty() or cost <= 0.0:
		_on_cancel_pressed()
		return
	if cost > _get_money():
		EventBus.insufficient_funds.emit()
		_update_total_amount_ui()
		return

	AudioManager.play_sfx("purchase")
	var gm_nodes := get_tree().get_nodes_in_group("game_manager")
	if gm_nodes.size() > 0 and gm_nodes[0].has_method("deduct_money"):
		gm_nodes[0].deduct_money(cost)

	catalog_purchase_confirmed.emit(int(roundf(cost)), actual_items)
	_close_restock_screen()
	InventoryManager.start_delivery_cooldown()
	MarioManager.start_delivery(actual_items)


func _get_money() -> float:
	var gm_nodes := get_tree().get_nodes_in_group("game_manager")
	return gm_nodes[0].money if gm_nodes.size() > 0 else 0.0
