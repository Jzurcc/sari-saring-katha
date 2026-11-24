extends Control

signal catalog_purchase_confirmed(total_cost: int, items_bought: Dictionary)
signal catalog_menu_closed
## Emitted when the restock screen should close — the parent scene handles visibility.
signal menu_close_requested

# Keep exported properties so RestockMenu.tscn doesn't lose scene overrides
@export_group("Card Sizes")
@export var card_size := Vector2(196, 174)
@export var card_icon_size := Vector2(62, 62)

@export_group("Font Sizes")
@export var card_font_size: int = 15
@export var detail_name_font_size: int = 18
@export var detail_price_font_size: int = 15
@export var order_list_font_size: int = 15
@export var list_header_font_size: int = 18
@export var tab_font_size: int = 15

@export_group("Detail Panel")
@export var detail_icon_size := Vector2(56, 56)

# Sari-Saring Katha Brand Palette (Warm Espresso, Antique Gold, Warm Cream)
const COL_ESPRESSO := Color(0.082, 0.074, 0.066, 0.97)
const COL_ESPRESSO_PANEL := Color(0.114, 0.102, 0.090, 0.96)
const COL_ESPRESSO_CARD := Color(0.145, 0.128, 0.112, 0.96)
const COL_ESPRESSO_CARD_SEL := Color(0.195, 0.162, 0.122, 0.98)
const COL_GOLD := Color(0.835, 0.624, 0.278, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.875, 0.56, 1.0)
const COL_CREAM := Color(1.0, 0.922, 0.792, 1.0)
const COL_CREAM_MUTED := Color(0.82, 0.75, 0.64, 0.82)
const COL_BORDER := Color(0.482, 0.306, 0.102, 0.78)
const COL_POSITIVE := Color(0.54, 0.88, 0.52, 1.0)
const COL_CORAL := Color(0.92, 0.44, 0.40, 1.0)
const COL_HOT := Color(0.96, 0.62, 0.24, 1.0)
const COL_BTN_DARK := Color(0.20, 0.17, 0.14, 1.0)

var order: RestockOrder = RestockOrder.new()

var selected_items: Dictionary:
	get: return order.selected_items
var total_price: float:
	get: return order.total_price

var current_category: String = "recommended"
var currently_selected_item: ItemData = null
var _category_cache: Dictionary = {} # cat_key -> Array[ItemData]

var category_tabs: Array[String] = [
	"recommended", "all",
	"snack", "sachets", "can", "cigarette", "candy",
	"bottle", "pack", "frozen"
]
var category_labels: Dictionary = {
	"recommended": "Recommended",
	"all": "All",
	"snack": "Snack",
	"sachets": "Sachet",
	"can": "Can",
	"candy": "Candy",
	"cigarette": "Cigarette",
	"pack": "Noodles",
	"frozen": "Frozen",
	"bottle": "Beverage"
}

# Drag-to-scroll state for the tab bar
var _tab_drag_active: bool = false
var _tab_drag_start_x: float = 0.0
var _tab_scroll_start: float = 0.0

# Programmatically constructed UI references
var _shell: PanelContainer
var _regulars_row: HBoxContainer
var _shelf_cap_lbl: Label
var _fridge_cap_lbl: Label
var _wallet_lbl: Label
var _tab_scroll: ScrollContainer
var _tab_bar: HBoxContainer
var _product_grid: HFlowContainer
var _grid_empty_lbl: Label

# Right Order Slip references
var _peek_icon: TextureRect
var _peek_name: Label
var _peek_prices: Label
var _peek_liked_by: Label
var _fill_rec_btn: Button
var _order_list_container: VBoxContainer
var _total_amount_label: Label
var _cancel_btn: Button
var _confirm_btn: Button

var _card_nodes: Dictionary = {} # ItemData -> Dictionary of controls for fast refresh
var _bold_font: FontVariation

func _ready() -> void:
	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_INDER
	_bold_font.variation_embolden = 0.55

	# Hide legacy scene children so the redesigned espresso/gold UI owns the screen cleanly
	for child in get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false

	_build_redesigned_ui()
	EventBus.restock_catalog_refresh.connect(_on_catalog_refresh_requested)
	hide()

func _build_redesigned_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.025, 0.02, 0.72)
	add_child(backdrop)

	_shell = PanelContainer.new()
	_shell.anchor_left = 0.045
	_shell.anchor_right = 0.955
	_shell.anchor_top = 0.045
	_shell.anchor_bottom = 0.955
	var shell_style := UIStyle.create_flat_stylebox(COL_ESPRESSO, 12, 20, 16)
	shell_style.border_color = COL_GOLD
	shell_style.set_border_width_all(2)
	shell_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	shell_style.shadow_size = 24
	_shell.add_theme_stylebox_override("panel", shell_style)
	add_child(_shell)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 12)
	_shell.add_child(root_v)

	# ── 1. TOP STORE PULSE BAR ──────────────────────────────────────────
	var pulse_bar := PanelContainer.new()
	var pulse_style := UIStyle.create_flat_stylebox(COL_ESPRESSO_PANEL, 8, 16, 10)
	pulse_style.border_color = COL_BORDER
	pulse_style.set_border_width_all(1)
	pulse_bar.add_theme_stylebox_override("panel", pulse_style)
	root_v.add_child(pulse_bar)

	var pulse_h := HBoxContainer.new()
	pulse_h.add_theme_constant_override("separation", 16)
	pulse_bar.add_child(pulse_h)

	var brand_col := VBoxContainer.new()
	brand_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand_col.add_theme_constant_override("separation", 6)
	pulse_h.add_child(brand_col)

	var title_lbl := Label.new()
	title_lbl.text = "UNCLE MARIO'S WHOLESALE"
	title_lbl.add_theme_font_override("font", _bold_font)
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	brand_col.add_child(title_lbl)

	_regulars_row = HBoxContainer.new()
	_regulars_row.add_theme_constant_override("separation", 8)
	brand_col.add_child(_regulars_row)

	# Right metrics: Capacity pills + Wallet + Close
	var metrics_h := HBoxContainer.new()
	metrics_h.alignment = BoxContainer.ALIGNMENT_END
	metrics_h.add_theme_constant_override("separation", 10)
	pulse_h.add_child(metrics_h)

	_shelf_cap_lbl = _make_metric_pill(metrics_h, "Shelf: 0 / 36")
	_fridge_cap_lbl = _make_metric_pill(metrics_h, "Fridge: 0 / 12")
	_wallet_lbl = _make_metric_pill(metrics_h, "₱0.00", COL_GOLD_BRIGHT)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_font_override("font", _bold_font)
	close_btn.add_theme_font_size_override("font_size", 20)
	var close_s := UIStyle.create_flat_stylebox(Color(0.24, 0.14, 0.12, 0.9), 8, 6, 4)
	close_s.border_color = COL_CORAL
	close_s.set_border_width_all(1)
	close_btn.add_theme_stylebox_override("normal", close_s)
	var close_h: StyleBoxFlat = close_s.duplicate()
	close_h.bg_color = Color(0.45, 0.20, 0.18, 1.0)
	close_btn.add_theme_stylebox_override("hover", close_h)
	close_btn.add_theme_stylebox_override("pressed", close_h)
	close_btn.add_theme_color_override("font_color", COL_CREAM)
	close_btn.pressed.connect(_on_cancel_pressed)
	metrics_h.add_child(close_btn)

	# ── 2. BODY SPLIT (LEFT CATALOG 68% | RIGHT ORDER SLIP 32%) ─────────
	var body_split := HBoxContainer.new()
	body_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_split.add_theme_constant_override("separation", 14)
	root_v.add_child(body_split)

	# Left Catalog Column
	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 2.15
	var left_style := UIStyle.create_flat_stylebox(COL_ESPRESSO_PANEL, 10, 14, 12)
	left_style.border_color = COL_BORDER
	left_style.set_border_width_all(1)
	left_panel.add_theme_stylebox_override("panel", left_style)
	body_split.add_child(left_panel)

	var left_v := VBoxContainer.new()
	left_v.add_theme_constant_override("separation", 10)
	left_panel.add_child(left_v)

	# Smart Filter Tab Bar
	_tab_scroll = ScrollContainer.new()
	_tab_scroll.custom_minimum_size = Vector2(0, 44)
	_tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_scroll.gui_input.connect(_on_tab_scroll_input)
	left_v.add_child(_tab_scroll)

	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 6)
	_tab_scroll.add_child(_tab_bar)

	# Product Grid Scroll
	var grid_scroll := ScrollContainer.new()
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_v.add_child(grid_scroll)

	var grid_wrap := VBoxContainer.new()
	grid_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.add_child(grid_wrap)

	_grid_empty_lbl = Label.new()
	_grid_empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grid_empty_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_grid_empty_lbl.add_theme_font_size_override("font_size", 17)
	_grid_empty_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	_grid_empty_lbl.visible = false
	grid_wrap.add_child(_grid_empty_lbl)

	_product_grid = HFlowContainer.new()
	_product_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_product_grid.add_theme_constant_override("h_separation", 10)
	_product_grid.add_theme_constant_override("v_separation", 10)
	grid_wrap.add_child(_product_grid)

	# Right Order Slip Column
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.0
	var right_style := UIStyle.create_flat_stylebox(COL_ESPRESSO_PANEL, 10, 14, 12)
	right_style.border_color = COL_GOLD
	right_style.set_border_width_all(1)
	right_panel.add_theme_stylebox_override("panel", right_style)
	body_split.add_child(right_panel)

	var right_v := VBoxContainer.new()
	right_v.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_v)

	# Selected Item Peek Box
	var peek_box := PanelContainer.new()
	var peek_style := UIStyle.create_flat_stylebox(COL_ESPRESSO_CARD, 8, 10, 8)
	peek_style.border_color = COL_BORDER
	peek_style.set_border_width_all(1)
	peek_box.add_theme_stylebox_override("panel", peek_style)
	right_v.add_child(peek_box)

	var peek_h := HBoxContainer.new()
	peek_h.add_theme_constant_override("separation", 10)
	peek_box.add_child(peek_h)

	_peek_icon = TextureRect.new()
	_peek_icon.custom_minimum_size = detail_icon_size
	_peek_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_peek_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_peek_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	peek_h.add_child(_peek_icon)

	var peek_info := VBoxContainer.new()
	peek_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	peek_info.add_theme_constant_override("separation", 2)
	peek_h.add_child(peek_info)

	_peek_name = Label.new()
	_peek_name.text = "Select an item to inspect"
	_peek_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_peek_name.add_theme_font_override("font", _bold_font)
	_peek_name.add_theme_font_size_override("font_size", 16)
	_peek_name.add_theme_color_override("font_color", COL_CREAM)
	peek_info.add_child(_peek_name)

	_peek_prices = Label.new()
	_peek_prices.text = "Click any card for price & profit"
	_peek_prices.add_theme_font_override("font", UIStyle.FONT_INDER)
	_peek_prices.add_theme_font_size_override("font_size", 13)
	_peek_prices.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	peek_info.add_child(_peek_prices)

	_peek_liked_by = Label.new()
	_peek_liked_by.text = ""
	_peek_liked_by.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_peek_liked_by.add_theme_font_override("font", UIStyle.FONT_INDER)
	_peek_liked_by.add_theme_font_size_override("font_size", 13)
	_peek_liked_by.add_theme_color_override("font_color", COL_CREAM_MUTED)
	peek_info.add_child(_peek_liked_by)

	# Slip Header + Fill Recommended CTA
	var slip_hdr_row := HBoxContainer.new()
	slip_hdr_row.add_theme_constant_override("separation", 8)
	right_v.add_child(slip_hdr_row)

	var slip_title := Label.new()
	slip_title.text = "ORDER SLIP"
	slip_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slip_title.add_theme_font_override("font", _bold_font)
	slip_title.add_theme_font_size_override("font_size", 17)
	slip_title.add_theme_color_override("font_color", COL_GOLD)
	slip_hdr_row.add_child(slip_title)

	_fill_rec_btn = Button.new()
	_fill_rec_btn.text = "⚡ Fill Recommended"
	_fill_rec_btn.focus_mode = Control.FOCUS_NONE
	_fill_rec_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_fill_rec_btn.add_theme_font_override("font", _bold_font)
	_fill_rec_btn.add_theme_font_size_override("font_size", 13)
	var fill_s := UIStyle.create_flat_stylebox(Color(0.36, 0.27, 0.13, 0.95), 6, 10, 5)
	fill_s.border_color = COL_GOLD
	fill_s.set_border_width_all(1)
	var fill_h: StyleBoxFlat = fill_s.duplicate()
	fill_h.bg_color = Color(0.50, 0.37, 0.17, 1.0)
	_fill_rec_btn.add_theme_stylebox_override("normal", fill_s)
	_fill_rec_btn.add_theme_stylebox_override("hover", fill_h)
	_fill_rec_btn.add_theme_stylebox_override("pressed", fill_s)
	_fill_rec_btn.add_theme_color_override("font_color", COL_CREAM)
	_fill_rec_btn.pressed.connect(_on_fill_recommended_pressed)
	slip_hdr_row.add_child(_fill_rec_btn)

	var sep := HSeparator.new()
	var sep_s := StyleBoxLine.new()
	sep_s.color = COL_BORDER
	sep.add_theme_stylebox_override("separator", sep_s)
	right_v.add_child(sep)

	# Order List Scroll
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_v.add_child(list_scroll)

	_order_list_container = VBoxContainer.new()
	_order_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_order_list_container.add_theme_constant_override("separation", 6)
	list_scroll.add_child(_order_list_container)

	# Total Row
	var total_sep := HSeparator.new()
	total_sep.add_theme_stylebox_override("separator", sep_s)
	right_v.add_child(total_sep)

	var total_row := HBoxContainer.new()
	right_v.add_child(total_row)

	var total_lbl := Label.new()
	total_lbl.text = "TOTAL"
	total_lbl.add_theme_font_override("font", _bold_font)
	total_lbl.add_theme_font_size_override("font_size", 18)
	total_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	total_row.add_child(total_lbl)

	_total_amount_label = Label.new()
	_total_amount_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_total_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_total_amount_label.text = "₱0.00"
	_total_amount_label.add_theme_font_override("font", _bold_font)
	_total_amount_label.add_theme_font_size_override("font_size", 22)
	_total_amount_label.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	total_row.add_child(_total_amount_label)

	# Action Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	right_v.add_child(btn_row)

	_cancel_btn = Button.new()
	_cancel_btn.text = "Cancel"
	_cancel_btn.custom_minimum_size = Vector2(0, 44)
	_cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_btn.focus_mode = Control.FOCUS_NONE
	_cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_cancel_btn.add_theme_font_override("font", _bold_font)
	_cancel_btn.add_theme_font_size_override("font_size", 17)
	UIStyle.style_button(_cancel_btn, Color(0.58, 0.24, 0.22, 1.0), COL_CREAM, 17.0, 8)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	btn_row.add_child(_cancel_btn)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Order"
	_confirm_btn.custom_minimum_size = Vector2(0, 44)
	_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_btn.size_flags_stretch_ratio = 1.5
	_confirm_btn.focus_mode = Control.FOCUS_NONE
	_confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_confirm_btn.add_theme_font_override("font", _bold_font)
	_confirm_btn.add_theme_font_size_override("font_size", 18)
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	btn_row.add_child(_confirm_btn)

func _make_metric_pill(parent: HBoxContainer, text: String, col: Color = COL_CREAM) -> Label:
	var panel := PanelContainer.new()
	var s := UIStyle.create_flat_stylebox(COL_ESPRESSO_CARD, 8, 12, 6)
	s.border_color = COL_BORDER
	s.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", s)
	parent.add_child(panel)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _bold_font)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", col)
	panel.add_child(lbl)
	return lbl

# ── Lifecycle & Open ─────────────────────────────────────────────────────────

func _on_catalog_refresh_requested() -> void:
	if is_visible_in_tree():
		_build_category_cache()
		_refresh_regulars_strip()
		_build_tabs()
		_select_category(current_category)
		_refresh_capacity_and_wallet()

func _on_tab_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_tab_drag_active = true
				_tab_drag_start_x = mb.global_position.x
				_tab_scroll_start = _tab_scroll.scroll_horizontal
			else:
				_tab_drag_active = false
	elif event is InputEventMouseMotion and _tab_drag_active:
		var mm := event as InputEventMouseMotion
		var delta := mm.global_position.x - _tab_drag_start_x
		_tab_scroll.scroll_horizontal = int(_tab_scroll_start - delta)

func open_menu() -> void:
	StoryManager.ensure_daily_demand_rolled()
	_build_category_cache()
	show()
	_animate_entrance()
	order.clear()
	currently_selected_item = null
	_clear_peek_panel()
	_refresh_regulars_strip()
	_build_tabs()
	_update_order_list()
	_refresh_capacity_and_wallet()
	_select_category("recommended")

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

func _animate_entrance() -> void:
	modulate.a = 0.0
	position.y += 40.0
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 40.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.22)

# ── Top Pulse Bar: Expected Regulars & Capacity ──────────────────────────────

func _refresh_regulars_strip() -> void:
	for child in _regulars_row.get_children():
		child.queue_free()

	var revealed := StoryManager.get_revealed_expected_regulars()
	var max_slots := StoryManager.get_revealed_regular_count()

	if max_slots <= 0:
		var locked_lbl := Label.new()
		locked_lbl.text = "Today's Regulars: Hidden  •  Upgrade Barangay Radio to reveal who's visiting"
		locked_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		locked_lbl.add_theme_font_size_override("font_size", 13)
		locked_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
		_regulars_row.add_child(locked_lbl)
		return

	var prefix := Label.new()
	prefix.text = "TODAY'S REGULARS:"
	prefix.add_theme_font_override("font", _bold_font)
	prefix.add_theme_font_size_override("font_size", 13)
	prefix.add_theme_color_override("font_color", COL_GOLD)
	_regulars_row.add_child(prefix)

	for c in revealed:
		var chip := PanelContainer.new()
		var cs := UIStyle.create_flat_stylebox(COL_ESPRESSO_CARD, 6, 8, 3)
		cs.border_color = COL_GOLD
		cs.set_border_width_all(1)
		chip.add_theme_stylebox_override("panel", cs)

		var fav_names: PackedStringArray = []
		for f_cat in c.get_favorite_categories():
			var ui_key := "sachets" if f_cat == "sachet" else f_cat
			fav_names.append(str(category_labels.get(ui_key, f_cat.capitalize())))
		var fav_str := ", ".join(fav_names)
		chip.tooltip_text = "%s — Usually craves: %s" % [c.character_name, fav_str]

		var ch := HBoxContainer.new()
		ch.add_theme_constant_override("separation", 6)
		chip.add_child(ch)

		if c.sprite_texture:
			var thumb := TextureRect.new()
			thumb.custom_minimum_size = Vector2(22, 22)
			thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			thumb.texture = c.sprite_texture
			ch.add_child(thumb)

		var lbl := Label.new()
		lbl.text = "%s (%s)" % [c.character_name, fav_str]
		lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", COL_CREAM)
		ch.add_child(lbl)

		_regulars_row.add_child(chip)

	# Show remaining locked slots if Radio isn't maxed yet
	var total_expected := StoryManager.todays_expected_regulars.size()
	var hidden_left := maxi(0, total_expected - revealed.size())
	if hidden_left > 0:
		var more_lbl := Label.new()
		more_lbl.text = "+%d hidden" % hidden_left
		more_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		more_lbl.add_theme_font_size_override("font_size", 12)
		more_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
		_regulars_row.add_child(more_lbl)

func _refresh_capacity_and_wallet() -> void:
	var eff_types := order.get_effective_types()
	var shelf_owned := InventoryManager.get_total_owned_count(ItemData.ItemType.SHELF)
	var shelf_limit := InventoryManager.get_capacity_limit(ItemData.ItemType.SHELF)
	var shelf_add := int(eff_types.get(ItemData.ItemType.SHELF, 0))
	if shelf_add > 0:
		_shelf_cap_lbl.text = "Shelf: %d +%d / %d" % [shelf_owned, shelf_add, shelf_limit]
		_shelf_cap_lbl.add_theme_color_override("font_color", COL_CORAL if shelf_owned + shelf_add >= shelf_limit else COL_GOLD_BRIGHT)
	else:
		_shelf_cap_lbl.text = "Shelf: %d / %d" % [shelf_owned, shelf_limit]
		_shelf_cap_lbl.add_theme_color_override("font_color", COL_CORAL if shelf_owned >= shelf_limit else COL_CREAM)

	var fridge_owned := InventoryManager.get_total_owned_count(ItemData.ItemType.FRIDGE)
	var fridge_limit := InventoryManager.get_capacity_limit(ItemData.ItemType.FRIDGE)
	var fridge_add := int(eff_types.get(ItemData.ItemType.FRIDGE, 0))
	if fridge_add > 0:
		_fridge_cap_lbl.text = "Fridge: %d +%d / %d" % [fridge_owned, fridge_add, fridge_limit]
		_fridge_cap_lbl.add_theme_color_override("font_color", COL_CORAL if fridge_owned + fridge_add >= fridge_limit else COL_GOLD_BRIGHT)
	else:
		_fridge_cap_lbl.text = "Fridge: %d / %d" % [fridge_owned, fridge_limit]
		_fridge_cap_lbl.add_theme_color_override("font_color", COL_CORAL if fridge_owned >= fridge_limit else COL_CREAM)

	var money := _get_money()
	_wallet_lbl.text = "Wallet: ₱%.2f" % money
	_wallet_lbl.add_theme_color_override("font_color", COL_CORAL if order.total_price > money else COL_GOLD_BRIGHT)

# ── Tabs & Priority Scoring ──────────────────────────────────────────────────

func _build_tabs() -> void:
	for child in _tab_bar.get_children():
		child.queue_free()

	for cat_key in category_tabs:
		var unlocked_items := _get_unlocked_items_for_category(cat_key)
		var is_locked := unlocked_items.is_empty() and cat_key != "recommended" and cat_key != "all"

		var tab_btn := Button.new()
		var base_label: String = str(category_labels.get(cat_key, cat_key.capitalize()))
		if cat_key == "recommended":
			tab_btn.text = "★ Recommended (%d)" % unlocked_items.size()
		else:
			tab_btn.text = base_label
		tab_btn.name = "Tab_" + cat_key
		tab_btn.focus_mode = Control.FOCUS_NONE
		tab_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		tab_btn.mouse_default_cursor_shape = Control.CURSOR_ARROW if is_locked else Control.CURSOR_POINTING_HAND
		tab_btn.add_theme_font_override("font", _bold_font)
		tab_btn.add_theme_font_size_override("font_size", tab_font_size)
		_style_espresso_tab(tab_btn, cat_key == current_category, is_locked)
		tab_btn.pressed.connect(_on_tab_pressed.bind(cat_key))
		_tab_bar.add_child(tab_btn)

func _style_espresso_tab(btn: Button, is_active: bool, is_locked: bool) -> void:
	var bg := Color(0.54, 0.39, 0.16, 1.0) if is_active else (Color(0.10, 0.09, 0.08, 0.55) if is_locked else COL_ESPRESSO_CARD)
	var border := COL_GOLD_BRIGHT if is_active else (Color(0.25, 0.22, 0.18, 0.4) if is_locked else COL_BORDER)
	var txt := Color.WHITE if is_active else (Color(0.55, 0.50, 0.44, 0.45) if is_locked else COL_CREAM)

	var s := UIStyle.create_flat_stylebox(bg, 7, 14, 7)
	s.border_color = border
	s.set_border_width_all(2 if is_active else 1)
	var h: StyleBoxFlat = s.duplicate()
	if not is_locked and not is_active:
		h.bg_color = bg.lightened(0.08)
		h.border_color = COL_GOLD
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_color_override("font_color", txt)
	btn.add_theme_color_override("font_hover_color", Color.WHITE if not is_locked else txt)

func _on_tab_pressed(cat_key: String) -> void:
	AudioManager.play_sfx("tab_switch")
	if cat_key != "recommended" and cat_key != "all" and _get_unlocked_items_for_category(cat_key).is_empty():
		return
	_select_category(cat_key)

func _select_category(cat_key: String) -> void:
	current_category = cat_key
	for child in _tab_bar.get_children():
		if child is Button and child.name.begins_with("Tab_"):
			var c_key := child.name.trim_prefix("Tab_")
			var locked := _get_unlocked_items_for_category(c_key).is_empty() and c_key != "recommended" and c_key != "all"
			_style_espresso_tab(child, c_key == cat_key, locked)
	_populate_grid(cat_key)

func _get_item_priority(item: ItemData) -> int:
	# Lower number = higher priority in Recommended tab
	var stock := InventoryManager.get_total_item_stock(item)
	var is_hot := is_instance_valid(StoreEventManager) and StoreEventManager.get_item_demand_multiplier(item) > 1.05
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

# ── Product Cards with Inline +/- ────────────────────────────────────────────

func _populate_grid(cat_key: String) -> void:
	for child in _product_grid.get_children():
		child.queue_free()
	_card_nodes.clear()

	var items := _get_unlocked_items_for_category(cat_key)
	if items.is_empty():
		_grid_empty_lbl.visible = true
		_grid_empty_lbl.text = "All shelves look well-stocked right now! Switch to 'All' or a category tab to browse." if cat_key == "recommended" else "No unlocked items in this category yet."
		return

	_grid_empty_lbl.visible = false
	for item in items:
		var card := _create_product_card(item)
		_product_grid.add_child(card)

func _get_item_badge(item: ItemData) -> Dictionary:
	if is_instance_valid(StoreEventManager) and StoreEventManager.get_item_demand_multiplier(item) > 1.05:
		return {"text": "HOT", "color": COL_HOT}
	if StoryManager.get_missed_count(item) > 0:
		return {"text": "MISSED", "color": COL_CORAL}
	if StoryManager.is_item_on_sulit_deal(item):
		return {"text": "-20%", "color": COL_POSITIVE}
	return {"text": "", "color": Color.TRANSPARENT}

func _create_product_card(item: ItemData) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(194, 178)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var style := UIStyle.create_flat_stylebox(COL_ESPRESSO_CARD, 8, 10, 8)
	style.border_color = COL_BORDER
	style.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", style)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)

	# Top row: Priority badge (left) + revealed regular match pip (right)
	var top_row := HBoxContainer.new()
	top_row.custom_minimum_size = Vector2(0, 20)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top_row)

	var badge_info := _get_item_badge(item)
	if str(badge_info["text"]) != "":
		var badge_col: Color = badge_info["color"]
		var badge_panel := PanelContainer.new()
		var bs := UIStyle.create_flat_stylebox(Color(badge_col.r, badge_col.g, badge_col.b, 0.22), 4, 6, 1)
		bs.border_color = badge_col
		bs.set_border_width_all(1)
		badge_panel.add_theme_stylebox_override("panel", bs)
		badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var b_lbl := Label.new()
		b_lbl.text = str(badge_info["text"])
		b_lbl.add_theme_font_override("font", _bold_font)
		b_lbl.add_theme_font_size_override("font_size", 11)
		b_lbl.add_theme_color_override("font_color", badge_col)
		b_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_panel.add_child(b_lbl)
		top_row.add_child(badge_panel)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(spacer)

	var today_fans := StoryManager.get_regulars_who_like_item(item, true)
	if not today_fans.is_empty():
		var fan_names: PackedStringArray = []
		for f in today_fans:
			fan_names.append(f.character_name.split(" ")[0])
		var fan_lbl := Label.new()
		fan_lbl.text = "● " + ", ".join(fan_names)
		fan_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		fan_lbl.add_theme_font_size_override("font_size", 11)
		fan_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
		fan_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_row.add_child(fan_lbl)

	# Icon
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(58, 58)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item.texture:
		icon.texture = item.texture
	v.add_child(icon)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = item.item_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_override("font", _bold_font)
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", COL_CREAM)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_lbl)

	# Stock + Cost/Profit row
	var meta_row := HBoxContainer.new()
	meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(meta_row)

	var stock_lbl := Label.new()
	stock_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stock_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	stock_lbl.add_theme_font_size_override("font_size", 12)
	stock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_row.add_child(stock_lbl)

	var eff_cost := order.get_effective_unit_price(item)
	var sell_price := item.get_final_price()
	var profit := sell_price - eff_cost
	var price_lbl := Label.new()
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.text = "₱%d · +₱%d" % [int(roundf(eff_cost)), int(roundf(profit))] if profit >= 0 else "₱%d" % int(roundf(eff_cost))
	price_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	price_lbl.add_theme_font_size_override("font_size", 12)
	price_lbl.add_theme_color_override("font_color", COL_POSITIVE if eff_cost < item.price - 0.01 else COL_GOLD_BRIGHT)
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_row.add_child(price_lbl)

	# Inline - / qty / + Controls
	var ctrl_row := HBoxContainer.new()
	ctrl_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ctrl_row.add_theme_constant_override("separation", 6)
	v.add_child(ctrl_row)

	var minus_btn := _make_stepper_btn("−", false)
	var qty_lbl := Label.new()
	qty_lbl.custom_minimum_size = Vector2(34, 0)
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_lbl.add_theme_font_override("font", _bold_font)
	qty_lbl.add_theme_font_size_override("font_size", 15)
	qty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plus_btn := _make_stepper_btn("+", true)

	ctrl_row.add_child(minus_btn)
	ctrl_row.add_child(qty_lbl)
	ctrl_row.add_child(plus_btn)

	minus_btn.pressed.connect(_on_card_stepper.bind(item, -1))
	plus_btn.pressed.connect(_on_card_stepper.bind(item, 1))
	card.gui_input.connect(_on_card_clicked.bind(item))

	_card_nodes[item] = {
		"card": card,
		"style": style,
		"stock_lbl": stock_lbl,
		"qty_lbl": qty_lbl,
		"minus_btn": minus_btn,
		"plus_btn": plus_btn,
	}
	_refresh_single_card(item)
	return card

func _make_stepper_btn(glyph: String, is_plus: bool) -> Button:
	var btn := Button.new()
	btn.text = glyph
	btn.custom_minimum_size = Vector2(36, 26)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", _bold_font)
	btn.add_theme_font_size_override("font_size", 16)
	var bg := Color(0.36, 0.27, 0.13, 1.0) if is_plus else COL_BTN_DARK
	var s := UIStyle.create_flat_stylebox(bg, 5, 4, 0)
	s.border_color = COL_GOLD if is_plus else COL_BORDER
	s.set_border_width_all(1)
	var h: StyleBoxFlat = s.duplicate()
	h.bg_color = bg.lightened(0.14)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_color_override("font_color", COL_CREAM)
	return btn

func _refresh_single_card(item: ItemData) -> void:
	if not _card_nodes.has(item):
		return
	var refs: Dictionary = _card_nodes[item]
	var style: StyleBoxFlat = refs["style"]
	var stock_lbl: Label = refs["stock_lbl"]
	var qty_lbl: Label = refs["qty_lbl"]
	var minus_btn: Button = refs["minus_btn"]

	var stock := InventoryManager.get_total_item_stock(item)
	var max_s := InventoryManager.get_max_stock(item)
	var in_basket := order.get_item_count(item)

	if max_s < 50:
		if stock + in_basket >= max_s:
			stock_lbl.text = "FULL (%d/%d)" % [stock + in_basket, max_s]
			stock_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
		elif in_basket > 0:
			stock_lbl.text = "Stock: %d+%d/%d" % [stock, in_basket, max_s]
			stock_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
		else:
			stock_lbl.text = "Stock: %d/%d" % [stock, max_s]
			stock_lbl.add_theme_color_override("font_color", COL_CORAL if stock <= 0 else COL_CREAM_MUTED)
	else:
		if in_basket > 0:
			stock_lbl.text = "Stock: %d +%d" % [stock, in_basket]
			stock_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
		else:
			stock_lbl.text = "Stock: %d" % stock
			stock_lbl.add_theme_color_override("font_color", COL_CORAL if stock <= 0 else COL_CREAM_MUTED)

	qty_lbl.text = str(in_basket) if in_basket > 0 else "0"
	qty_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT if in_basket > 0 else COL_CREAM_MUTED)
	minus_btn.disabled = in_basket <= 0

	var is_sel := (item == currently_selected_item)
	style.bg_color = COL_ESPRESSO_CARD_SEL if (is_sel or in_basket > 0) else COL_ESPRESSO_CARD
	style.border_color = COL_GOLD_BRIGHT if is_sel else (COL_GOLD if in_basket > 0 else COL_BORDER)
	style.set_border_width_all(2 if (is_sel or in_basket > 0) else 1)

func _refresh_all_visible_cards() -> void:
	for item in _card_nodes.keys():
		_refresh_single_card(item)

func _on_card_clicked(event: InputEvent, item: ItemData) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			AudioManager.play_sfx("interact")
			currently_selected_item = item
			_update_peek_panel(item)
			_refresh_all_visible_cards()

func _on_card_stepper(item: ItemData, delta: int) -> void:
	currently_selected_item = item
	_update_peek_panel(item)
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

# ── Right Panel: Item Peek & Smart Fill ──────────────────────────────────────

func _update_peek_panel(item: ItemData) -> void:
	_peek_icon.texture = item.texture
	_peek_name.text = item.item_name
	var eff_cost := order.get_effective_unit_price(item)
	var sell := item.get_final_price()
	var profit := sell - eff_cost
	var disc_note := ""
	if eff_cost < item.price - 0.01:
		var pct := int(roundf((1.0 - (eff_cost / maxf(0.01, item.price))) * 100.0))
		disc_note = " (-%d%%)" % pct
	_peek_prices.text = "Cost ₱%.2f%s  •  Sell ₱%.2f  (+₱%.2f)" % [eff_cost, disc_note, sell, profit]

	var fans := StoryManager.get_regulars_who_like_item(item, false)
	if fans.is_empty():
		_peek_liked_by.text = "Everyday staple"
	else:
		var names: PackedStringArray = []
		for f in fans:
			names.append(f.character_name)
		_peek_liked_by.text = "Liked by: " + ", ".join(names)

func _clear_peek_panel() -> void:
	_peek_icon.texture = null
	_peek_name.text = "Select an item to inspect"
	_peek_prices.text = "Use − / + right on any card"
	_peek_liked_by.text = ""

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
	else:
		EventBus.show_notification.emit("Basket Full or Low Funds", "Cannot auto-add more recommended items within budget/space.", "error")

# ── Order Slip List & Confirmation ───────────────────────────────────────────

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

func _update_order_list() -> void:
	for child in _order_list_container.get_children():
		child.queue_free()

	if order.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No items in basket yet.\nUse + on any card or Fill Recommended."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
		_order_list_container.add_child(empty_lbl)
	else:
		var items_dict := order.get_items()
		for item in items_dict.keys():
			var count: int = items_dict[item]
			if count <= 0:
				continue
			_order_list_container.add_child(_create_order_row(item, count))

	_update_total_amount_ui()

func _update_total_amount_ui() -> void:
	_total_amount_label.text = "₱%.2f" % order.total_price
	var money := _get_money()
	var can_order := order.total_price > 0.0 and order.total_price <= money
	_confirm_btn.disabled = not can_order
	if can_order:
		_confirm_btn.text = "Order (₱%d)" % int(roundf(order.total_price))
		UIStyle.style_button(_confirm_btn, Color(0.56, 0.41, 0.16, 1.0), Color.WHITE, 18.0, 8)
	else:
		_confirm_btn.text = "Order"
		UIStyle.style_button(_confirm_btn, Color(0.24, 0.21, 0.18, 0.8), COL_CREAM_MUTED, 18.0, 8)

func _create_order_row(item: ItemData, count: int) -> PanelContainer:
	var wrap := PanelContainer.new()
	var s := UIStyle.create_flat_stylebox(COL_ESPRESSO_CARD, 6, 8, 5)
	s.border_color = COL_BORDER
	s.set_border_width_all(1)
	wrap.add_theme_stylebox_override("panel", s)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	wrap.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = item.item_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", COL_CREAM)
	row.add_child(name_lbl)

	var minus_btn := _make_stepper_btn("−", false)
	minus_btn.custom_minimum_size = Vector2(26, 24)
	minus_btn.pressed.connect(_on_card_stepper.bind(item, -1))
	row.add_child(minus_btn)

	var count_lbl := Label.new()
	count_lbl.text = str(count)
	count_lbl.custom_minimum_size = Vector2(22, 0)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_override("font", _bold_font)
	count_lbl.add_theme_font_size_override("font_size", 14)
	count_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	row.add_child(count_lbl)

	var plus_btn := _make_stepper_btn("+", true)
	plus_btn.custom_minimum_size = Vector2(26, 24)
	plus_btn.pressed.connect(_on_card_stepper.bind(item, 1))
	row.add_child(plus_btn)

	var sub_lbl := Label.new()
	sub_lbl.custom_minimum_size = Vector2(52, 0)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sub_lbl.text = "₱%d" % int(roundf(order.get_effective_unit_price(item) * count))
	sub_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	row.add_child(sub_lbl)

	return wrap

# ── Actions ──────────────────────────────────────────────────────────────────

func _close_restock_screen() -> void:
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y + 40.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.20)
	tween.tween_callback(func():
		menu_close_requested.emit()
		hide()
		position.y -= 40.0
		modulate.a = 1.0
	)

func _on_cancel_pressed() -> void:
	AudioManager.play_sfx("drop")
	MarioManager.cancel_restock()
	catalog_menu_closed.emit()
	_close_restock_screen()

func _on_confirm_pressed() -> void:
	if _confirm_btn:
		_confirm_btn.disabled = true
	var actual_items := order.get_actual_items()
	var cost := order.get_total_cost()
	if actual_items.is_empty() or cost <= 0.0:
		_on_cancel_pressed()
		if _confirm_btn:
			_confirm_btn.disabled = false
		return
	if cost > _get_money():
		EventBus.insufficient_funds.emit()
		if _confirm_btn:
			_confirm_btn.disabled = false
		return

	AudioManager.play_sfx("purchase")
	var gm_nodes := get_tree().get_nodes_in_group("game_manager")
	if gm_nodes.size() > 0 and gm_nodes[0].has_method("deduct_money"):
		gm_nodes[0].deduct_money(cost)

	catalog_purchase_confirmed.emit(cost, actual_items)
	_close_restock_screen()
	InventoryManager.start_delivery_cooldown()
	MarioManager.start_delivery(actual_items)

func _get_money() -> float:
	var gm_nodes := get_tree().get_nodes_in_group("game_manager")
	return gm_nodes[0].money if gm_nodes.size() > 0 else 0.0
