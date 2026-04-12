extends Control

signal catalog_purchase_confirmed(total_cost: int, items_bought: Dictionary)
signal catalog_menu_closed
## Emitted when the restock screen should close — the parent scene handles visibility.
signal menu_close_requested

@export_group("Card Sizes")
## Size of each product card in the grid
@export var card_size := Vector2(120, 140)
## Size of the product icon inside each card
@export var card_icon_size := Vector2(80, 80)

@export_group("Audio")
@export_range(-80.0, 24.0) var sfx_volume_db: float = 0.0

@export_group("Font Sizes")
## Font size for product names on cards
@export var card_font_size: int = 13
## Font size for the detail panel product name
@export var detail_name_font_size: int = 18
## Font size for the detail panel price
@export var detail_price_font_size: int = 15
## Font size for order list items
@export var order_list_font_size: int = 14
## Font size for the list header
@export var list_header_font_size: int = 20
## Font size for tab buttons
@export var tab_font_size: int = 15



@export_group("Detail Panel")
## Size of the product icon in the detail panel
@export var detail_icon_size := Vector2(70, 70)

# Node references (assign these in the editor or use unique names)
@onready var tab_container: HBoxContainer = %TabBar
@onready var tab_scroll: ScrollContainer = %TabScroll
@onready var product_grid: HFlowContainer = %ProductGrid
@onready var detail_icon: TextureRect = %DetailIcon
@onready var detail_name: Label = %DetailName
@onready var detail_price: Label = %DetailPrice
@onready var add_btn: Button = %AddBtn
@onready var order_list_container: VBoxContainer = %OrderList
@onready var cancel_btn: Button = %CancelBtn
@onready var confirm_btn: Button = %ConfirmBtn
@onready var list_header: Label = %ListHeader
@onready var total_amount_label: Label = %TotalAmountLabel

# Drag-to-scroll state for the tab bar
var _tab_drag_active: bool = false
var _tab_drag_start_x: float = 0.0
var _tab_scroll_start: float = 0.0

var selected_items: Dictionary = {}  # ItemData -> int (order count)
var total_price: float = 0.0
var current_category: String = ""
var currently_selected_item: ItemData = null

# Category display names and their internal keys (must match category = "..." in .tres files)
# NOTE: "candycontainer" is intentionally excluded — those are physical equipment that spawn in-world.
var category_tabs: Array[String] = [
	"snack", "can", "cigarette", "candy",
	"bottle", "pack", "frozen"
]
var category_labels: Dictionary = {
	"snack": "Snack",
	"sachet": "Sachets",
	"can": "Can",
	"candy": "Candy",
	"cigarette": "Cigarette",
	"pack": "Noodles",
	"frozen": "Frozen",
	"bottle": "Beverages"
}



# --- Audio Resources ---
var stream_sfx_4 = preload("res://Audio/SFX/ui_sfx_4.mp3")
var stream_sfx_3 = preload("res://Audio/SFX/ui_sfx_3.mp3")
var stream_sfx_7 = preload("res://Audio/SFX/ui_sfx_7.mp3")
var stream_sfx_9 = preload("res://Audio/SFX/ui_sfx_9.mp3")
var stream_sfx_12 = preload("res://Audio/SFX/ui_sfx_12.mp3")
var stream_sfx_15 = preload("res://Audio/SFX/ui_sfx_15.mp3")
var stream_sfx_kaching = preload("res://Audio/SFX/money kaching.mp3")
var sfx_player: AudioStreamPlayer

# --- Colors ---
var COLOR_TAB_BG := Color("D4A85C")         # warm brown tab bar
var COLOR_TAB_ACTIVE := Color("C8944A")      # darker active tab
var COLOR_TAB_NORMAL := Color("F0E0C8")      # light inactive tab
var COLOR_CONTENT_BG := Color("D9B876")      # warm tan content area
var COLOR_CARD_BG := Color(1, 1, 1, 1)       # white product cards
var COLOR_CARD_SELECTED := Color("FFF3D6")   # soft yellow when selected
var COLOR_DETAIL_BG := Color("E8CFA0")       # slightly darker detail panel
var COLOR_CANCEL := Color("C0544E")          # red cancel button
var COLOR_CONFIRM := Color("5A8C5A")         # green confirm button
var COLOR_LIST_BG := Color("F5E6CC")         # light beige list panel

func _ready() -> void:
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	
	# Debug: print which nodes were found
	if not cancel_btn:
		push_error("[RestockMenu] CancelBtn not found via %CancelBtn")
	if not confirm_btn:
		push_error("[RestockMenu] ConfirmBtn not found via %ConfirmBtn")
	if not add_btn:
		push_error("[RestockMenu] AddBtn not found via %AddBtn")
	if not tab_scroll:
		push_error("[RestockMenu] TabScroll not found via %TabScroll")
	
	if cancel_btn:
		cancel_btn.pressed.connect(_on_cancel_pressed)
		_style_button(cancel_btn, COLOR_CANCEL, Color.WHITE)
	if confirm_btn:
		confirm_btn.pressed.connect(_on_confirm_pressed)
		_style_button(confirm_btn, COLOR_CONFIRM, Color.WHITE)
	if add_btn:
		add_btn.pressed.connect(_on_add_pressed)
		_style_button(add_btn, Color("D4A85C"), Color.WHITE)
	if tab_scroll:
		tab_scroll.gui_input.connect(_on_tab_scroll_input)
	
	var close_btn_node = get_node_or_null("%CloseBtn")
	if close_btn_node:
		close_btn_node.pressed.connect(_on_cancel_pressed)
	
	hide()

# Drag-to-scroll handler for the tab bar
func _on_tab_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_tab_drag_active = true
				_tab_drag_start_x = event.global_position.x
				_tab_scroll_start = tab_scroll.scroll_horizontal
			else:
				_tab_drag_active = false
	elif event is InputEventMouseMotion and _tab_drag_active:
		var delta = event.global_position.x - _tab_drag_start_x
		tab_scroll.scroll_horizontal = int(_tab_scroll_start - delta)

func open_menu() -> void:
	print("[RestockMenu] open_menu() called")
	show()
	selected_items.clear()
	total_price = 0
	currently_selected_item = null
	if detail_icon and detail_name and detail_price and add_btn:
		_clear_detail_panel()
	else:
		push_warning("[RestockMenu] Some detail panel nodes are null — skipping _clear_detail_panel()")
	_build_tabs()
	_update_order_list()
	
	# Select first category that has items
	if category_tabs.size() > 0:
		_select_category(category_tabs[0])

# ========== TAB SYSTEM ==========
var COLOR_TAB_LOCKED := Color("4D4D4D")       # dark grey for locked tabs
var COLOR_TAB_LOCKED_FONT := Color("878787")  # muted text for locked tabs

func _build_tabs() -> void:
	# Clear existing tabs
	for child in tab_container.get_children():
		child.queue_free()
	
	# Category tabs — always show ALL categories, dim the locked ones
	for cat_key in category_tabs:
		var items = _get_items_for_category(cat_key)
		var is_locked = items.size() == 0
		
		var tab_btn = Button.new()
		tab_btn.text = category_labels.get(cat_key, cat_key.capitalize())
		tab_btn.custom_minimum_size = Vector2(80, 40)
		tab_btn.name = "Tab_" + cat_key.replace(" ", "_")
		tab_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		
		if is_locked:
			_style_button(tab_btn, COLOR_TAB_LOCKED, COLOR_TAB_LOCKED_FONT, float(tab_font_size))
		else:
			_style_button(tab_btn, COLOR_TAB_NORMAL, Color("333333"), float(tab_font_size))
		
		tab_btn.pressed.connect(_on_tab_pressed.bind(cat_key))
		tab_container.add_child(tab_btn)

func _on_tab_pressed(cat_key: String) -> void:
	# Always play the tab SFX
	_play_sfx(stream_sfx_4)
	
	# Block switching if the category has no unlocked items
	var items = _get_items_for_category(cat_key)
	if items.size() == 0:
		return
	
	_select_category(cat_key)

func _play_sfx(stream: AudioStream) -> void:
	if not is_instance_valid(sfx_player):
		return
	sfx_player.stream = stream
	sfx_player.volume_db = sfx_volume_db
	sfx_player.play()

func _select_category(cat_key: String) -> void:
	current_category = cat_key
	
	# Update tab visuals
	for child in tab_container.get_children():
		if child is Button and child.name.begins_with("Tab_"):
			var child_cat = child.name.trim_prefix("Tab_")
			var child_items = _get_items_for_category(child_cat)
			var child_locked = child_items.size() == 0
			var is_active = child_cat == cat_key.replace(" ", "_")
			
			if child_locked:
				_style_button(child, COLOR_TAB_LOCKED, COLOR_TAB_LOCKED_FONT, float(tab_font_size))
			elif is_active:
				_style_button(child, COLOR_TAB_ACTIVE, Color.WHITE, float(tab_font_size))
			else:
				_style_button(child, COLOR_TAB_NORMAL, Color("333333"), float(tab_font_size))
	
	_populate_grid(cat_key)

# ========== PRODUCT GRID ==========
func _populate_grid(cat_key: String) -> void:
	# Clear grid
	for child in product_grid.get_children():
		child.queue_free()
	
	var items = _get_items_for_category(cat_key)
	
	for item in items:
		var card = _create_product_card(item)
		product_grid.add_child(card)

func _create_product_card(item: ItemData) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = card_size
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 1) # Black
	style.border_color = Color(0.15, 0.15, 0.15, 1) # Dark grey
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Item icon only — no name label on card
	var icon = TextureRect.new()
	icon.custom_minimum_size = card_icon_size
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if item.texture:
		icon.texture = item.texture
	vbox.add_child(icon)
	
	card.add_child(vbox)
	
	# Make the whole card clickable via gui_input
	card.gui_input.connect(_on_card_clicked.bind(item, card))
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	return card

func _on_card_clicked(event: InputEvent, item: ItemData, card: PanelContainer) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_play_sfx(stream_sfx_3)
		currently_selected_item = item
		_update_detail_panel(item)
		
		# Highlight selected card (using border color)
		for child in product_grid.get_children():
			if child is PanelContainer:
				var s = child.get_theme_stylebox("panel") as StyleBoxFlat
				if s:
					s.border_color = Color(0.15, 0.15, 0.15, 1)
		
		var selected_style = card.get_theme_stylebox("panel") as StyleBoxFlat
		if selected_style:
			selected_style.border_color = Color(0.84, 0.64, 0.33, 1) # Yellow highlight

# ========== DETAIL PANEL ==========
func _update_detail_panel(item: ItemData) -> void:
	if item.texture:
		detail_icon.texture = item.texture
	detail_icon.custom_minimum_size = detail_icon_size
	detail_name.text = _get_display_name(item)
	detail_name.add_theme_font_size_override("font_size", detail_name_font_size)
	detail_price.text = "₱%.2f" % item.price
	detail_price.add_theme_font_size_override("font_size", detail_price_font_size)
	add_btn.visible = true

func _clear_detail_panel() -> void:
	detail_icon.texture = null
	detail_name.text = "Select a product"
	detail_price.text = ""
	add_btn.visible = false

func _on_add_pressed() -> void:
	if currently_selected_item == null:
		return
	
	_play_sfx(stream_sfx_12)
	var item = currently_selected_item
	var current_count = selected_items.get(item, 0)
	
	# max_stock is the shelf capacity; allow ordering up to that many units.
	var order_cap = item.max_stock if item.max_stock > 0 else 99
	
	if current_count + 1 > order_cap:
		return
	
	var gm_nodes = get_tree().get_nodes_in_group("game_manager")
	var money: float = 0.0
	if gm_nodes.size() > 0: money = gm_nodes[0].money
	if total_price + item.price > money:
		EventBus.insufficient_funds.emit()
		return
	
	_play_sfx(stream_sfx_12)
	selected_items[item] = current_count + 1
	total_price += item.price
	_update_order_list()

# ========== ORDER LIST ==========
func _update_order_list() -> void:
	# Clear the list
	for child in order_list_container.get_children():
		child.queue_free()
	
	if selected_items.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No items added yet"
		empty_lbl.add_theme_color_override("font_color", Color("999999"))
		empty_lbl.add_theme_font_size_override("font_size", 13)
		order_list_container.add_child(empty_lbl)
	else:
		for item in selected_items.keys():
			var count = selected_items[item]
			if count <= 0:
				continue
			var row = _create_order_row(item, count)
			order_list_container.add_child(row)
			
	total_amount_label.text = "₱%.2f" % total_price
	
	# Keep header static — total shown separately at confirm
	list_header.text = "Order List"
	list_header.add_theme_font_size_override("font_size", list_header_font_size)

func _create_order_row(item: ItemData, count: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	
	# Product name
	var name_lbl = Label.new()
	name_lbl.text = item.item_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", order_list_font_size)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(name_lbl)
	
	# Minus / Trash button
	var minus_btn = Button.new()
	minus_btn.custom_minimum_size = Vector2(30, 30)
	_update_minus_btn_appearance(minus_btn, count)
	row.add_child(minus_btn)
	
	# Count label
	var count_lbl = Label.new()
	count_lbl.text = str(count)
	count_lbl.custom_minimum_size = Vector2(24, 0)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_size_override("font_size", order_list_font_size)
	count_lbl.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(count_lbl)
	
	# Plus button
	var plus_btn = Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(30, 30)
	_style_button(plus_btn, Color("5A8C5A"), Color.WHITE, 14.0)
	row.add_child(plus_btn)
	
	# Connect buttons — pass references so they can update each other
	minus_btn.pressed.connect(_on_minus_pressed.bind(item, count_lbl, minus_btn, row))
	plus_btn.pressed.connect(_on_plus_pressed.bind(item, count_lbl, minus_btn))
	
	return row

func _update_minus_btn_appearance(btn: Button, count: int) -> void:
	if count <= 1:
		# Show trash icon — pressing it will remove the item
		btn.text = "🗑"
		_style_button(btn, Color("C0544E"), Color.WHITE, 14.0)
	else:
		btn.text = "-"
		_style_button(btn, Color("D4A85C"), Color.WHITE, 14.0)

func _on_minus_pressed(item: ItemData, count_lbl: Label, minus_btn: Button, row: HBoxContainer) -> void:
	var count = selected_items.get(item, 0)
	if count <= 0:
		return
	
	_play_sfx(stream_sfx_15)
	
	var new_count = count - 1
	total_price -= item.price
	
	if new_count <= 0:
		# Remove the item entirely and destroy the row
		selected_items.erase(item)
		row.queue_free()
		_update_order_list()
		return
	
	selected_items[item] = new_count
	count_lbl.text = str(new_count)
	_update_minus_btn_appearance(minus_btn, new_count)
	total_amount_label.text = "₱%.2f" % total_price

func _on_plus_pressed(item: ItemData, count_lbl: Label, minus_btn: Button) -> void:
	var count = selected_items.get(item, 0)
	var order_cap = item.max_stock if item.max_stock > 0 else 99
	
	if count + 1 > order_cap:
		return
		
	var gm_nodes = get_tree().get_nodes_in_group("game_manager")
	var money: float = 0.0
	if gm_nodes.size() > 0: money = gm_nodes[0].money
	if total_price + item.price > money:
		EventBus.insufficient_funds.emit()
		return
	
	_play_sfx(stream_sfx_12)
	var new_count = count + 1
	selected_items[item] = new_count
	total_price += item.price
	count_lbl.text = str(new_count)
	_update_minus_btn_appearance(minus_btn, new_count)
	total_amount_label.text = "₱%.2f" % total_price

# ========== ACTIONS ==========
func _close_restock_screen() -> void:
	menu_close_requested.emit()
	hide()

func _on_cancel_pressed() -> void:
	_play_sfx(stream_sfx_9)
	catalog_menu_closed.emit()
	_close_restock_screen()

func _on_confirm_pressed() -> void:
	if total_price <= 0:
		return
	_play_sfx(stream_sfx_7)
	catalog_purchase_confirmed.emit(total_price, selected_items)
	_close_restock_screen()
	# Set delivery cooldown and trigger the manager
	InventoryManager.start_delivery_cooldown()
	MarioManager.start_delivery(selected_items)
# ========== HELPERS ==========
func _get_unlock_day(item_id: String) -> int:
	# Returns the day number when this item first becomes available.
	# item_id matches the .tres filename (without extension), case-sensitive.
	var unlock_map: Dictionary = {
		# DAY 1
		"Anoba": 1, "Patos": 1,
		"Argentita": 1, "Cenchuree": 1,
		"Champyon": 1,
		# DAY 2
		"Mentor": 2, "Pocha": 2,
		"Water": 2,
		"Chicken": 2, "Pantit": 2,
		# DAY 3
		"Hotdog": 3, "Borgir": 3,
		"NgaragYa": 3, "Dantes": 3,
		"Mayti": 3,
		# DAY 4
		"Coke": 4,
		"Marites": 4, "Utang": 4,
		# DAY 5
		"Lucky9": 5, "Mema": 5,
		"Nagets": 5,
		# DAY 6
		"Marboro": 6,
		"Gin": 6,
		# DAY 7
		"Tocino": 7,
		"Scam": 7,
		"Chubs": 7,
	}
	return unlock_map.get(item_id, 1)  # Default to Day 1 if not found

func _get_current_day() -> int:
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	return gm.day if gm else 1

func _get_display_name(item: ItemData) -> String:
	return item.item_name

func _get_items_for_category(cat_key: String) -> Array[ItemData]:
	var result: Array[ItemData] = []
	var current_day = _get_current_day()
	for item in InventoryManager.get_all_items():
		if item.category == cat_key:
			var unlock_day = _get_unlock_day(item.id)
			if current_day >= unlock_day:
				result.append(item)
	return result

func _style_button(btn: Button, bg_color: Color, font_color: Color, font_size: float = 14.0) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = bg_color.lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = style.duplicate()
	pressed_style.bg_color = bg_color.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_font_size_override("font_size", int(font_size))
