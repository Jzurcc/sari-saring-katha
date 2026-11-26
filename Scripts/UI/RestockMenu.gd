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

# Top Header & Toolbar references
var _money_lbl: Label
var _shelf_cap_lbl: Label
var _fridge_cap_lbl: Label
var _category_dropdown: OptionButton
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
		if _regulars_popover and _regulars_popover.visible:
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


# ── UI Construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	# 1. Clean borderless full-screen Dark Warm Espresso backdrop
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = COL_BACKDROP
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	# 2. Title-Safe Container (5% margins on all sides = 90% safe area)
	var safe_root := VBoxContainer.new()
	safe_root.anchor_left = 0.05
	safe_root.anchor_right = 0.95
	safe_root.anchor_top = 0.045
	safe_root.anchor_bottom = 0.955
	safe_root.add_theme_constant_override("separation", 16)
	add_child(safe_root)

	_build_top_bar(safe_root)
	_build_toolbar(safe_root)
	_build_body_area(safe_root)
	_build_regulars_popover()
	_build_delayed_tooltip()


func _build_top_bar(parent: VBoxContainer) -> void:
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 14)
	parent.add_child(top_bar)

	# Top-Left: White Money readout (matches Main HUD & Store Upgrades) + quiet capacity pills
	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 8)
	money_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(money_row)

	var peso_tex := TextureRect.new()
	peso_tex.texture = PESO_ICON
	peso_tex.custom_minimum_size = Vector2(30, 30)
	peso_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	peso_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	peso_tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	peso_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money_row.add_child(peso_tex)

	_money_lbl = Label.new()
	_money_lbl.text = "0.00"
	_money_lbl.add_theme_font_override("font", _bold_font)
	_money_lbl.add_theme_font_size_override("font_size", 28)
	_money_lbl.add_theme_color_override("font_color", Color.WHITE)
	_money_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	_money_lbl.add_theme_constant_override("outline_size", 4)
	money_row.add_child(_money_lbl)

	var cap_spacer := Control.new()
	cap_spacer.custom_minimum_size = Vector2(12, 0)
	top_bar.add_child(cap_spacer)

	_shelf_cap_lbl = _make_status_pill(top_bar, "Shelf 0/36")
	_fridge_cap_lbl = _make_status_pill(top_bar, "Fridge 0/12")

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

	# Category Dropdown (replaces 10-button tab strip)
	_category_dropdown = OptionButton.new()
	_category_dropdown.custom_minimum_size = Vector2(0, 48)
	_category_dropdown.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_category_dropdown.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_category_dropdown.add_theme_font_override("font", _bold_font)
	_category_dropdown.add_theme_font_size_override("font_size", 18)
	_apply_button_theme(_category_dropdown, COL_SURFACE, COL_GOLD, COL_CREAM, 10, 18)
	var popup := _category_dropdown.get_popup()
	popup.add_theme_font_override("font", UIStyle.FONT_INDER)
	popup.add_theme_font_size_override("font_size", 17)
	popup.add_theme_color_override("font_color", COL_CREAM)
	popup.add_theme_color_override("font_hover_color", COL_GOLD_BRIGHT)
	popup.add_theme_color_override("font_disabled_color", Color(0.55, 0.50, 0.44, 0.55))
	var pop_style := UIStyle.create_flat_stylebox(COL_DRAWER, 10, 14, 10)
	pop_style.border_color = COL_GOLD
	pop_style.set_border_width_all(2)
	popup.add_theme_stylebox_override("panel", pop_style)
	var pop_hover := UIStyle.create_flat_stylebox(Color(0.24, 0.19, 0.13, 1.0), 6, 10, 6)
	popup.add_theme_stylebox_override("hover", pop_hover)
	_category_dropdown.item_selected.connect(_on_category_dropdown_selected)
	bar.add_child(_category_dropdown)

	# Toggleable Regulars & Quick-Fill Popover Button (closed by default)
	_regulars_btn = Button.new()
	_regulars_btn.text = "Today's Regulars ▾"
	_regulars_btn.custom_minimum_size = Vector2(0, 48)
	_regulars_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_regulars_btn.add_theme_font_override("font", UIStyle.FONT_INDER)
	_regulars_btn.add_theme_font_size_override("font_size", 17)
	_apply_button_theme(_regulars_btn, COL_SURFACE, COL_BORDER_SUBTLE, COL_CREAM, 10, 16)
	_regulars_btn.pressed.connect(func(): _set_regulars_open(not _regulars_popover.visible))
	bar.add_child(_regulars_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	# Toggleable Order Slip Drawer Button
	_slip_toggle_btn = Button.new()
	_slip_toggle_btn.text = "Order Slip (0) ◂"
	_slip_toggle_btn.custom_minimum_size = Vector2(0, 48)
	_slip_toggle_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_slip_toggle_btn.add_theme_font_override("font", _bold_font)
	_slip_toggle_btn.add_theme_font_size_override("font_size", 17)
	_apply_button_theme(_slip_toggle_btn, COL_SURFACE, COL_BORDER_SUBTLE, COL_CREAM, 10, 18)
	_slip_toggle_btn.pressed.connect(func(): _set_slip_open(not _slip_open))
	bar.add_child(_slip_toggle_btn)

	# Direct Primary Order CTA (so players can order immediately without even opening the slip)
	_quick_order_btn = Button.new()
	_quick_order_btn.text = "Order"
	_quick_order_btn.custom_minimum_size = Vector2(0, 48)
	_quick_order_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_quick_order_btn.add_theme_font_override("font", _bold_font)
	_quick_order_btn.add_theme_font_size_override("font_size", 18)
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
	_drawer_order_btn.custom_minimum_size = Vector2(0, 48)
	_drawer_order_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_drawer_order_btn.add_theme_font_override("font", _bold_font)
	_drawer_order_btn.add_theme_font_size_override("font_size", 18)
	_drawer_order_btn.pressed.connect(_on_confirm_pressed)
	dv.add_child(_drawer_order_btn)


func _build_regulars_popover() -> void:
	# Invisible click-catcher so clicking anywhere outside closes the popover cleanly
	_regulars_backdrop = Control.new()
	_regulars_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_regulars_backdrop.visible = false
	_regulars_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_set_regulars_open(false)
	)
	add_child(_regulars_backdrop)

	_regulars_popover = PanelContainer.new()
	_regulars_popover.visible = false
	var ps := UIStyle.create_flat_stylebox(COL_DRAWER, 12, 16, 14)
	ps.border_color = COL_GOLD
	ps.set_border_width_all(2)
	ps.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	ps.shadow_size = 18
	ps.shadow_offset = Vector2(0, 6)
	_regulars_popover.add_theme_stylebox_override("panel", ps)
	add_child(_regulars_popover)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	_regulars_popover.add_child(pv)

	var phdr := Label.new()
	phdr.text = "Expected Regulars Today"
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
	_fill_rec_btn.custom_minimum_size = Vector2(0, 46)
	_fill_rec_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_fill_rec_btn.add_theme_font_override("font", _bold_font)
	_fill_rec_btn.add_theme_font_size_override("font_size", 16)
	_apply_button_theme(_fill_rec_btn, Color(0.32, 0.24, 0.13, 0.98), COL_GOLD, COL_CREAM, 8, 16)
	_fill_rec_btn.pressed.connect(func():
		_on_fill_recommended_pressed()
		_set_regulars_open(false)
	)
	pv.add_child(_fill_rec_btn)


func _build_delayed_tooltip() -> void:
	_tooltip_timer = Timer.new()
	_tooltip_timer.one_shot = true
	_tooltip_timer.wait_time = 0.35
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
	add_child(_tooltip_panel)

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
	_animate_entrance()


func _animate_entrance() -> void:
	modulate.a = 0.0
	scale = Vector2(0.98, 0.98)
	pivot_offset = get_viewport_rect().size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


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


func _set_regulars_open(open_state: bool) -> void:
	if not _regulars_popover:
		return
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
		tw.tween_property(_regulars_popover, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ── Category Cache & Dropdown ────────────────────────────────────────────────

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


func _rebuild_category_dropdown() -> void:
	_category_dropdown.clear()
	_dropdown_keys.clear()

	var selected_idx := 0
	for cat_key in category_tabs:
		var unlocked_items := _get_unlocked_items_for_category(cat_key)
		var is_locked := unlocked_items.is_empty() and cat_key != "recommended" and cat_key != "all"
		var base_label := str(category_labels.get(cat_key, cat_key.capitalize()))
		var idx := _dropdown_keys.size()
		_dropdown_keys.append(cat_key)

		if is_locked:
			_category_dropdown.add_item("%s (Locked)" % base_label, idx)
			_category_dropdown.set_item_disabled(idx, true)
		else:
			_category_dropdown.add_item("%s (%d)" % [base_label, unlocked_items.size()], idx)

		if cat_key == current_category and not is_locked:
			selected_idx = idx

	_category_dropdown.select(selected_idx)


func _on_category_dropdown_selected(index: int) -> void:
	if index < 0 or index >= _dropdown_keys.size():
		return
	var cat_key := _dropdown_keys[index]
	AudioManager.play_sfx("tab_switch")
	_select_category(cat_key)


func _select_category(cat_key: String) -> void:
	current_category = cat_key
	var idx := _dropdown_keys.find(cat_key)
	if idx >= 0 and _category_dropdown.selected != idx:
		_category_dropdown.select(idx)
	_hide_tooltip()
	_populate_grid(cat_key)


func _get_item_priority(item: ItemData) -> int:
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
		return result

	if _category_cache.has(cat_key):
		for item in _category_cache[cat_key]:
			if item.tier <= StoryManager.current_tier:
				result.append(item)
	return result


# ── Regulars Popover & Capacity / Wallet ─────────────────────────────────────

func _refresh_regulars_popover_content() -> void:
	for child in _regulars_list_box.get_children():
		child.queue_free()

	var revealed := StoryManager.get_revealed_expected_regulars()
	var max_slots := StoryManager.get_revealed_regular_count()
	var suffix := " ▴" if (_regulars_popover and _regulars_popover.visible) else " ▾"
	_regulars_btn.text = ("Today's Regulars (%d)%s" % [revealed.size(), suffix]) if revealed.size() > 0 else ("Today's Regulars%s" % suffix)

	if max_slots <= 0:
		var hint := Label.new()
		hint.text = "Upgrade the Barangay Radio to reveal\nwhich regulars are visiting today."
		hint.add_theme_font_override("font", UIStyle.FONT_INDER)
		hint.add_theme_font_size_override("font_size", 15)
		hint.add_theme_color_override("font_color", COL_CREAM_MUTED)
		_regulars_list_box.add_child(hint)
		return

	for c in revealed:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		if c.sprite_texture:
			var thumb := TextureRect.new()
			thumb.custom_minimum_size = Vector2(34, 34)
			thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			thumb.texture = c.sprite_texture
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

	var money := _get_money()
	_money_lbl.text = "%.2f" % money
	_money_lbl.add_theme_color_override("font_color", COL_CORAL if order.total_price > money else Color.WHITE)


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
	var is_deal := StoryManager.is_item_on_sulit_deal(item)
	var is_hot := is_instance_valid(StoreEventManager) and StoreEventManager.is_item_in_demand(item)

	# Top pill: redundant color + text label for Deals / Demand / Out of Stock
	if is_deal:
		status_pill.visible = true
		status_lbl.text = "-20%"
		status_lbl.add_theme_color_override("font_color", COL_POSITIVE)
		status_style.border_color = COL_POSITIVE
		status_style.bg_color = Color(COL_POSITIVE.r, COL_POSITIVE.g, COL_POSITIVE.b, 0.16)
	elif stock <= 0 and in_basket <= 0:
		status_pill.visible = true
		status_lbl.text = "Out"
		status_lbl.add_theme_color_override("font_color", COL_CORAL)
		status_style.border_color = COL_CORAL
		status_style.bg_color = Color(COL_CORAL.r, COL_CORAL.g, COL_CORAL.b, 0.16)
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
	_tooltip_timer.start(0.35)


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
	tw.tween_property(_tooltip_panel, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _populate_tooltip(item: ItemData) -> void:
	_tooltip_title_lbl.text = item.item_name
	var eff_cost := order.get_effective_unit_price(item)
	var sell := item.get_final_price()
	var profit := sell - eff_cost
	_tooltip_price_lbl.text = "Wholesale ₱%.0f  •  Sell ₱%.0f  (+₱%.0f profit)" % [eff_cost, sell, profit]

	var notes: PackedStringArray = []
	var stock := InventoryManager.get_total_item_stock(item)
	var max_s := InventoryManager.get_max_stock(item)
	notes.append("Stock: %d/%d" % [stock, max_s] if max_s < 50 else "Stock: %d" % stock)
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
	_set_regulars_open(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		menu_close_requested.emit()
		hide()
		modulate.a = 1.0
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
