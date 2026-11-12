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

var order: RestockOrder = RestockOrder.new()

var selected_items: Dictionary:
	get: return order.selected_items
var total_price: float:
	get: return order.total_price

var current_category: String = ""
var currently_selected_item: ItemData = null
var _category_cache: Dictionary = {} # cat_key -> Array[ItemData]

# Category display names and their internal keys (must match category = "..." in .tres files)
# NOTE: "candycontainer" is intentionally excluded — those are physical equipment that spawn in-world.
var category_tabs: Array[String] = [
	"upgrades", "snack", "sachets", "can", "cigarette", "candy",
	"bottle", "pack", "frozen"
]
var category_labels: Dictionary = {
	"upgrades": "Upgrades",
	"snack": "Snack",
	"sachets": "Sachet",
	"can": "Can",
	"candy": "Candy",
	"cigarette": "Cigarette",
	"pack": "Noodles",
	"frozen": "Frozen",
	"bottle": "Beverage"
}

# --- Colors (delegated to UIStyle) ---
const COLOR_TAB_BG := UIStyle.COLOR_TAB_BG
const COLOR_TAB_ACTIVE := UIStyle.COLOR_TAB_ACTIVE
const COLOR_TAB_NORMAL := UIStyle.COLOR_TAB_NORMAL
const COLOR_TAB_LOCKED := UIStyle.COLOR_TAB_LOCKED
const COLOR_TAB_LOCKED_FONT := UIStyle.COLOR_TAB_LOCKED_FONT
const COLOR_CONTENT_BG := UIStyle.COLOR_CONTENT_BG
const COLOR_CARD_BG := UIStyle.COLOR_CARD_BG
const COLOR_CARD_SELECTED := UIStyle.COLOR_CARD_SELECTED
const COLOR_DETAIL_BG := UIStyle.COLOR_DETAIL_BG
const COLOR_CANCEL := UIStyle.COLOR_CANCEL
const COLOR_CONFIRM := UIStyle.COLOR_CONFIRM
const COLOR_LIST_BG := UIStyle.COLOR_LIST_BG
const COLOR_BEIGE := UIStyle.COLOR_BEIGE
const COLOR_DARK_BG := UIStyle.COLOR_DARK_BG

func _ready() -> void:
	
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
		UIStyle.style_button(cancel_btn, UIStyle.COLOR_CANCEL, Color.WHITE)
	if confirm_btn:
		confirm_btn.pressed.connect(_on_confirm_pressed)
		UIStyle.style_button(confirm_btn, UIStyle.COLOR_CONFIRM, Color.WHITE)
	if add_btn:
		add_btn.pressed.connect(_on_add_pressed)
		UIStyle.style_button(add_btn, UIStyle.COLOR_DARK_BG, Color.WHITE)
	if tab_scroll:
		tab_scroll.gui_input.connect(_on_tab_scroll_input)
	
	EventBus.restock_catalog_refresh.connect(_on_catalog_refresh_requested)
	
	var close_btn_node = get_node_or_null("%CloseBtn")
	if close_btn_node:
		close_btn_node.pressed.connect(_on_cancel_pressed)
	
	hide()

func _on_catalog_refresh_requested() -> void:
	# If the menu is open, we need to rebuild the grid to show new unlocks
	if is_visible_in_tree():
		print("[RestockMenu] Refreshing catalog UI...")
		_build_category_cache()
		_build_tabs()
		_select_category(current_category)

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
	_build_category_cache()
	show()
	
	# NEW: Explicitly grab focus on a button to prevent keyboard input (like Space)
	# from accidentally hitting background phone buttons.
	var all_btn = get_node_or_null("%AllBtn")
	if all_btn:
		all_btn.grab_focus()
		
	_animate_entrance()
	order.clear()
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

func _build_category_cache() -> void:
	_category_cache.clear()
	for item in InventoryManager.get_all_items():
		var cat = item.category
		
		# Map singular 'sachet' to plural 'sachets' for the UI identifier
		if cat == "sachet":
			# Explicitly filter out sachet containers (props) from the purchase catalog
			if "/sachetcontainers/" in item.resource_path:
				continue
			cat = "sachets"
			
		if not _category_cache.has(cat):
			var empty: Array[ItemData] = []
			_category_cache[cat] = empty
		_category_cache[cat].append(item)

func _animate_entrance() -> void:
	# Slide in from bottom
	modulate.a = 0.0
	position.y += 100
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y - 100, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.3)

# ========== TAB SYSTEM ==========
func _build_tabs() -> void:
	# Clear existing tabs
	for child in tab_container.get_children():
		child.queue_free()
	
	# Category tabs — always show ALL categories, dim the locked ones
	for cat_key in category_tabs:
		var items = _get_items_for_category(cat_key)
		var is_locked = items.size() == 0 and cat_key != "upgrades"
		
		var tab_btn = Button.new()
		tab_btn.text = category_labels.get(cat_key, cat_key.capitalize())
		tab_btn.custom_minimum_size = Vector2(80, 40)
		tab_btn.name = "Tab_" + cat_key.replace(" ", "_")
		tab_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		
		UIStyle.style_tab_button(tab_btn, false, is_locked, float(tab_font_size))
		tab_btn.pressed.connect(_on_tab_pressed.bind(cat_key))
		tab_container.add_child(tab_btn)

func _on_tab_pressed(cat_key: String) -> void:
	# Always play the tab SFX
	AudioManager.play_sfx("tab_switch")
	
	# Block switching if the category has no unlocked items
	var items = _get_items_for_category(cat_key)
	if items.size() == 0 and cat_key != "upgrades":
		return
	
	_select_category(cat_key)

func _select_category(cat_key: String) -> void:
	current_category = cat_key
	
	# Update tab visuals
	for child in tab_container.get_children():
		if child is Button and child.name.begins_with("Tab_"):
			var child_cat = child.name.trim_prefix("Tab_").replace("_", " ")
			var child_items = _get_items_for_category(child_cat)
			var child_locked = child_items.size() == 0 and child_cat != "upgrades"
			var is_active = child_cat == cat_key
			UIStyle.style_tab_button(child, is_active, child_locked, float(tab_font_size))
	
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
	var is_locked: bool = false
	var is_stacked: bool = false
	var is_upgrade = item.get_meta("is_upgrade", false)
	
	if is_upgrade:
		var target_tier = item.get_meta("target_tier", 1)
		is_locked = target_tier > StoryManager.max_unlocked_tier
		is_stacked = target_tier > StoryManager.pending_upgrade_tier and target_tier <= StoryManager.max_unlocked_tier
	else:
		is_locked = item.tier > StoryManager.current_tier
	
	var bg_col := UIStyle.COLOR_CARD_BG
	if is_upgrade and item.get_meta("target_tier", 1) <= StoryManager.current_tier:
		bg_col = UIStyle.COLOR_CARD_OWNED_BG
	
	card.add_theme_stylebox_override("panel", UIStyle.create_card_style(bg_col))
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	# Set pivot to the center of the card for the sway animation
	vbox.pivot_offset = card_size / 2.0
	
	# Item icon
	var icon = TextureRect.new()
	icon.custom_minimum_size = card_icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if item.texture:
		icon.texture = item.texture
	
	if is_locked:
		icon.modulate = Color(0, 0, 0, 1) # Silhouette
		card.modulate = Color(0.6, 0.6, 0.6, 0.8) # Dimmed card
	elif is_stacked:
		icon.modulate = Color(0.3, 0.3, 0.3, 0.5) # Grayed out
		card.modulate = Color(0.5, 0.5, 0.5, 0.7) # Dimmed card
	
	# Add Label for Tiers
	if is_upgrade:
		var target_tier = item.get_meta("target_tier", 1)
		var tier_lbl = Label.new()
		tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_lbl.add_theme_font_size_override("font_size", 11)
		tier_lbl.add_theme_color_override("font_color", Color.WHITE)
		
		var prereq_met = order.is_upgrade_prerequisite_met(target_tier)
		if target_tier <= StoryManager.current_tier:
			tier_lbl.text = "OWNED"
		elif prereq_met:
			tier_lbl.text = "TIER %d" % target_tier
		else:
			tier_lbl.text = "UNLOCKED"
			
		# Boost label modulate to compensate for the dimmed card parent so text stays white
		tier_lbl.modulate = Color(1.8, 1.8, 1.8, 1.0)
		vbox.add_child(tier_lbl)
	
	vbox.add_child(icon)
	card.add_child(vbox)
	
	# Visibility logic based on whether prerequisite is met
	if is_upgrade:
		var target_tier = item.get_meta("target_tier", 1)
		var prereq_met = order.is_upgrade_prerequisite_met(target_tier)
		var owned = target_tier <= StoryManager.current_tier
		
		if owned:
			icon.modulate = Color(1, 1, 1, 0.4) # Faded green for owned
			card.modulate = Color(0.8, 1, 0.8, 0.6)
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif prereq_met:
			# Fully visible and clickable
			icon.modulate = Color(1, 1, 1, 1)
			card.modulate = Color(1, 1, 1, 1)
			card.gui_input.connect(_on_card_clicked.bind(item, card))
			card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			# Staged but prerequisite not met yet — silhouette
			icon.modulate = Color(0, 0, 0, 1) # Silhouette
			card.modulate = Color(0.6, 0.6, 0.6, 0.8) # Dimmed
			card.mouse_filter = Control.MOUSE_FILTER_PASS 
			card.mouse_default_cursor_shape = Control.CURSOR_ARROW
	else:
		# Regular item logic
		if is_locked:
			icon.modulate = Color(0, 0, 0, 1)
			card.modulate = Color(0.6, 0.6, 0.6, 0.8)
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			icon.modulate = Color(1, 1, 1, 1)
			card.modulate = Color(1, 1, 1, 1)
			card.gui_input.connect(_on_card_clicked.bind(item, card))
			card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# IDLE ANIMATION: Subtle Swaying
	var tw = card.create_tween().set_loops()
	var duration = randf_range(2.5, 4.5) # Different speeds
	var sway_angle = randf_range(1.5, 2.5) # Subtle oscillation
	# Start at a random point in the cycle
	vbox.rotation_degrees = randf_range(-sway_angle, sway_angle)
	tw.tween_property(vbox, "rotation_degrees", sway_angle, duration / 2.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(vbox, "rotation_degrees", -sway_angle, duration / 2.0).set_trans(Tween.TRANS_SINE)
	
	return card

func _on_card_clicked(event: InputEvent, item: ItemData, card: PanelContainer) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		AudioManager.play_sfx("interact")
		currently_selected_item = item
		_update_detail_panel(item)
		
		# Highlight selected card (using border color)
		for child in product_grid.get_children():
			if child is PanelContainer:
				var s = child.get_theme_stylebox("panel") as StyleBoxFlat
				if s:
					s.border_color = UIStyle.COLOR_CARD_BORDER
		
		var selected_style = card.get_theme_stylebox("panel") as StyleBoxFlat
		if selected_style:
			selected_style.border_color = UIStyle.COLOR_CARD_SELECTED

# ========== DETAIL PANEL ==========
func _update_detail_panel(item: ItemData) -> void:
	if item.texture:
		detail_icon.texture = item.texture
	detail_icon.custom_minimum_size = detail_icon_size
	detail_name.text = item.item_name
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
	
	var item := currently_selected_item
	var check := order.can_add(item, _get_money())
	if not check.ok:
		if check.title != "":
			EventBus.show_notification.emit(check.title, check.message, check.sfx)
		if check.sfx != "":
			AudioManager.play_sfx(check.sfx)
		elif check.error == "insufficient_funds":
			EventBus.insufficient_funds.emit()
		return

	AudioManager.play_sfx("pickup")
	order.add_item(item)
	_update_order_list()
	
	# If an upgrade was added, refresh grid to show next tiers
	if item.get_meta("is_upgrade", false):
		_populate_grid(current_category)

# ========== ORDER LIST ==========
func _update_order_list() -> void:
	# Clear the list
	for child in order_list_container.get_children():
		child.queue_free()
	
	if order.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No items added yet"
		empty_lbl.add_theme_color_override("font_color", Color("CCCCCC"))
		empty_lbl.add_theme_font_size_override("font_size", 13)
		order_list_container.add_child(empty_lbl)
	else:
		var items_dict := order.get_items()
		for item in items_dict.keys():
			var count: int = items_dict[item]
			if count <= 0:
				continue
			var row = _create_order_row(item, count)
			order_list_container.add_child(row)
			
	_update_total_amount_ui()
	
	# Disable confirm button if unaffordable or empty
	var money := _get_money()
	confirm_btn.disabled = (order.total_price <= 0) or (order.total_price > money)
	
	# Keep header static — total shown separately at confirm
	list_header.text = "Order List"
	list_header.add_theme_font_size_override("font_size", list_header_font_size)

func _update_total_amount_ui() -> void:
	total_amount_label.text = "₱%.2f" % order.total_price
	if not confirm_btn: return
	
	if order.total_price <= 0:
		confirm_btn.disabled = true
		UIStyle.style_button(confirm_btn, UIStyle.COLOR_TAB_LOCKED, UIStyle.COLOR_TAB_LOCKED_FONT)
	else:
		confirm_btn.disabled = false
		UIStyle.style_button(confirm_btn, UIStyle.COLOR_CONFIRM, Color.WHITE)


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
	UIStyle.style_button(plus_btn, UIStyle.COLOR_CONFIRM, Color.WHITE, 14.0)
	row.add_child(plus_btn)
	
	# Connect buttons — pass references so they can update each other
	minus_btn.pressed.connect(_on_minus_pressed.bind(item, count_lbl, minus_btn, row))
	plus_btn.pressed.connect(_on_plus_pressed.bind(item, count_lbl, minus_btn))
	
	return row

func _update_minus_btn_appearance(btn: Button, count: int) -> void:
	if count <= 1:
		# Show trash icon — pressing it will remove the item
		btn.text = "🗑"
		UIStyle.style_button(btn, UIStyle.COLOR_CANCEL, Color.WHITE, 14.0)
	else:
		btn.text = "-"
		UIStyle.style_button(btn, UIStyle.COLOR_TAB_ACTIVE, Color.WHITE, 14.0)

func _on_minus_pressed(item: ItemData, count_lbl: Label, minus_btn: Button, _row: HBoxContainer) -> void:
	AudioManager.play_sfx("drop")
	var result := order.remove_item(item)
	if result.removed:
		_update_order_list()
		if result.is_upgrade:
			_populate_grid(current_category)
	else:
		count_lbl.text = str(result.new_count)
		_update_minus_btn_appearance(minus_btn, result.new_count)
		_update_total_amount_ui()

func _on_plus_pressed(item: ItemData, count_lbl: Label, minus_btn: Button) -> void:
	if item.get_meta("is_upgrade", false):
		return
	var check := order.can_add(item, _get_money())
	if not check.ok:
		if check.title != "":
			EventBus.show_notification.emit(check.title, check.message, check.sfx)
		if check.sfx != "":
			AudioManager.play_sfx(check.sfx)
		elif check.error == "insufficient_funds":
			EventBus.insufficient_funds.emit()
		return
	
	AudioManager.play_sfx("pickup")
	order.add_item(item)
	var new_count := order.get_item_count(item)
	count_lbl.text = str(new_count)
	_update_minus_btn_appearance(minus_btn, new_count)
	_update_total_amount_ui()

# ========== ACTIONS ==========
func _close_restock_screen() -> void:
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y + 100, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		menu_close_requested.emit()
		hide()
		position.y -= 100 # Reset position for next open
		modulate.a = 1.0
	)

func _on_cancel_pressed() -> void:
	AudioManager.play_sfx("drop")
	MarioManager.cancel_restock()
	catalog_menu_closed.emit()
	_close_restock_screen()

func _on_confirm_pressed() -> void:
	if confirm_btn:
		confirm_btn.disabled = true
	# Check if the user has actually ordered items
	var actual_items := order.get_actual_items()
	var cost := order.get_total_cost()
			
	if actual_items.is_empty() or cost <= 0:
		print("[RestockMenu] No items ordered. Canceling.")
		_on_cancel_pressed()
		if confirm_btn:
			confirm_btn.disabled = false
		return
	var money = _get_money()
	if cost > money:
		EventBus.insufficient_funds.emit()
		if confirm_btn:
			confirm_btn.disabled = false
		return
		
	AudioManager.play_sfx("purchase")
	
	# Deduct the restock cost from the player's money
	var gm_nodes = get_tree().get_nodes_in_group("game_manager")
	if gm_nodes.size() > 0:
		var gm = gm_nodes[0]
		if gm.has_method("deduct_money"):
			gm.deduct_money(cost)
			print("[RestockMenu] Restock purchased for ₱%.2f. Remaining: ₱%.2f" % [cost, gm.money])
	
	catalog_purchase_confirmed.emit(cost, actual_items)
	_close_restock_screen()
	# Set delivery cooldown and trigger the manager ONLY if items were ordered
	InventoryManager.start_delivery_cooldown()
	MarioManager.start_delivery(actual_items)

func _get_money() -> float:
	var gm_nodes = get_tree().get_nodes_in_group("game_manager")
	return gm_nodes[0].money if gm_nodes.size() > 0 else 0.0

# ========== HELPERS ==========
func _get_items_for_category(cat_key: String) -> Array[ItemData]:
	if cat_key == "upgrades":
		var upgrades: Array[ItemData] = []
		for t in range(2, 11): # Tiers 2 through 10
			upgrades.append(StoryManager.get_tier_upgrade_item(t))
		return upgrades
		
	if _category_cache.has(cat_key):
		return _category_cache[cat_key]
	var empty: Array[ItemData] = []
	return empty
