class_name PriceLedgerOverlay
extends CanvasLayer

## Master Store Price Ledger Overlay (Hotkey: L).
## Styled to match Uncle Mario's delivery catalog (UIStyle.gd).
## Displays daily market events, rumors, and catalog repricing with 7-step steppers.

const FONT_INDER := preload("res://Assets/Fonts/Inder/Inder-Regular.ttf")

@onready var background_panel: PanelContainer = %BackgroundPanel
@onready var close_btn: Button = %CloseBtn
@onready var tab_container: HBoxContainer = %TabContainer
@onready var events_list: VBoxContainer = %EventsList
@onready var items_list: VBoxContainer = %ItemsList
@onready var title_label: Label = %TitleLabel

var _current_tab: String = "all"
var _item_rows: Dictionary = {} # ItemData -> Dictionary of UI node references
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var is_open: bool = false

const CATEGORIES: Array[Dictionary] = [
	{"id": "all", "label": "All"},
	{"id": "snack", "label": "Snacks"},
	{"id": "sachet", "label": "Sachets"},
	{"id": "can", "label": "Canned"},
	{"id": "bottle", "label": "Drinks"},
	{"id": "other", "label": "Other"}
]

func _ready() -> void:
	layer = 50
	add_to_group("price_ledger_overlay")
	hide()
	close_btn.pressed.connect(close_ledger)
	EventBus.price_ledger_toggled.connect(_on_ledger_toggled)
	
	_setup_tabs()
	_apply_styles()

func _setup_tabs() -> void:
	for child in tab_container.get_children():
		child.queue_free()

	for cat in CATEGORIES:
		var btn := Button.new()
		btn.text = cat.label
		btn.add_theme_font_override("font", FONT_INDER)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(func(): _select_tab(cat.id))
		tab_container.add_child(btn)

	_update_tab_styles()

func _apply_styles() -> void:
	title_label.add_theme_font_override("font", FONT_INDER)
	title_label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.78))

func _on_ledger_toggled(opened: bool) -> void:
	if opened:
		if is_open:
			close_ledger()
		else:
			open_ledger()
	else:
		close_ledger()

func open_ledger() -> void:
	if is_open:
		return
	is_open = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("tab_switch")

	show()
	refresh_events()
	refresh_catalog()

func close_ledger() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	Input.mouse_mode = _previous_mouse_mode
	
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("drop")

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_L or event.keycode == KEY_L)):
		close_ledger()
		get_viewport().set_input_as_handled()

func _select_tab(tab_id: String) -> void:
	_current_tab = tab_id
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("tab_switch")
	_update_tab_styles()
	refresh_catalog()

func _update_tab_styles() -> void:
	var tabs := tab_container.get_children()
	for i in range(tabs.size()):
		var btn = tabs[i] as Button
		if not btn:
			continue
		var cat_id: String = CATEGORIES[i].id
		var is_active := (cat_id == _current_tab)
		UIStyle.style_tab_button(btn, is_active, false, 15.0)

# ─── Daily Market Events Panel ────────────────────────────────────────────────

func refresh_events() -> void:
	for child in events_list.get_children():
		child.queue_free()

	var active_events: Array[StoreEventData] = []
	if is_instance_valid(StoreEventManager):
		active_events = StoreEventManager.get_active_events()

	if active_events.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "The neighborhood is quiet today.\nMarket demand and prices are stable."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_override("font", FONT_INDER)
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 0.8))
		events_list.add_child(empty_lbl)
		return

	for event in active_events:
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.94, 0.92, 0.86)
		card_style.set_corner_radius_all(6)
		card_style.set_content_margin_all(10)
		card_style.border_width_left = 3
		card_style.border_color = Color(0.85, 0.55, 0.2)
		card.add_theme_stylebox_override("panel", card_style)

		var vbox := VBoxContainer.new()
		vbox.theme_override_constants.separation = 4
		card.add_child(vbox)

		# Event Name
		var name_lbl := Label.new()
		name_lbl.text = event.event_name
		name_lbl.add_theme_font_override("font", FONT_INDER)
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12))
		vbox.add_child(name_lbl)

		# Modifier summary
		var mod_lbl := Label.new()
		mod_lbl.text = "Demand: %.1fx | Tolerance: +%d steps" % [event.demand_multiplier, event.tolerance_offset]
		mod_lbl.add_theme_font_override("font", FONT_INDER)
		mod_lbl.add_theme_font_size_override("font_size", 12)
		mod_lbl.add_theme_color_override("font_color", Color(0.7, 0.4, 0.1))
		vbox.add_child(mod_lbl)

		# Rumor Quote
		if not event.rumor_text.is_empty():
			var rumor_lbl := Label.new()
			rumor_lbl.text = "“%s”" % event.rumor_text
			rumor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rumor_lbl.add_theme_font_override("font", FONT_INDER)
			rumor_lbl.add_theme_font_size_override("font_size", 12)
			rumor_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
			vbox.add_child(rumor_lbl)

		events_list.add_child(card)

# ─── Product Catalog & Steppers ───────────────────────────────────────────────

func refresh_catalog() -> void:
	for child in items_list.get_children():
		child.queue_free()
	_item_rows.clear()

	var all_items: Array[ItemData] = InventoryManager._items
	var filtered_items: Array[ItemData] = []

	for item in all_items:
		if not item or not item.can_be_sold:
			continue
		if _matches_tab(item):
			filtered_items.append(item)

	if filtered_items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No items in this category."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_override("font", FONT_INDER)
		empty_lbl.add_theme_font_size_override("font_size", 16)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		items_list.add_child(empty_lbl)
		return

	for item in filtered_items:
		var row := _create_product_row(item)
		items_list.add_child(row)

func _matches_tab(item: ItemData) -> bool:
	if _current_tab == "all":
		return true
	if _current_tab == "other":
		return item.category != "snack" and item.category != "sachet" and item.category != "can" and item.category != "bottle"
	return item.category == _current_tab

func _create_product_row(item: ItemData) -> PanelContainer:
	var row := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.14, 0.13, 0.12, 0.95)
	row_style.set_corner_radius_all(6)
	row_style.set_content_margin_all(8)
	row.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.theme_override_constants.separation = 12
	row.add_child(hbox)

	# Product Icon
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(44, 44)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = item.texture
	hbox.add_child(icon_rect)

	# Name & Info VBox
	var info_vbox := VBoxContainer.new()
	info_vbox.custom_minimum_size = Vector2(170, 0)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.theme_override_constants.separation = 2
	hbox.add_child(info_vbox)

	var name_lbl := Label.new()
	name_lbl.text = item.item_name
	name_lbl.add_theme_font_override("font", FONT_INDER)
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.9, 0.78))
	info_vbox.add_child(name_lbl)

	# Subline: Cost + In Demand tag
	var sub_hbox := HBoxContainer.new()
	sub_hbox.theme_override_constants.separation = 8
	info_vbox.add_child(sub_hbox)

	var cost_lbl := Label.new()
	cost_lbl.text = "Cost: ₱%.2f" % item.price
	cost_lbl.add_theme_font_override("font", FONT_INDER)
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	sub_hbox.add_child(cost_lbl)

	var in_demand: bool = false
	if is_instance_valid(StoreEventManager):
		in_demand = StoreEventManager.is_item_in_demand(item)
	if in_demand:
		var demand_lbl := Label.new()
		demand_lbl.text = "[IN DEMAND]"
		demand_lbl.add_theme_font_override("font", FONT_INDER)
		demand_lbl.add_theme_font_size_override("font_size", 12)
		demand_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.28))
		sub_hbox.add_child(demand_lbl)

	# Stepper Control HBox
	var stepper_hbox := HBoxContainer.new()
	stepper_hbox.theme_override_constants.separation = 6
	hbox.add_child(stepper_hbox)

	var minus_btn := Button.new()
	minus_btn.text = " - "
	minus_btn.custom_minimum_size = Vector2(32, 32)
	UIStyle.style_button(minus_btn, Color(0.3, 0.3, 0.3), Color.WHITE, 16.0, 4)
	minus_btn.pressed.connect(func(): _adjust_step(item, -1))
	stepper_hbox.add_child(minus_btn)

	var pips_lbl := Label.new()
	pips_lbl.custom_minimum_size = Vector2(140, 32)
	pips_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pips_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pips_lbl.add_theme_font_override("font", FONT_INDER)
	pips_lbl.add_theme_font_size_override("font_size", 13)
	stepper_hbox.add_child(pips_lbl)

	var plus_btn := Button.new()
	plus_btn.text = " + "
	plus_btn.custom_minimum_size = Vector2(32, 32)
	UIStyle.style_button(plus_btn, Color(0.494, 0.761, 0.573), Color.WHITE, 16.0, 4)
	plus_btn.pressed.connect(func(): _adjust_step(item, 1))
	stepper_hbox.add_child(plus_btn)

	# Price & Step Readout VBox
	var price_vbox := VBoxContainer.new()
	price_vbox.custom_minimum_size = Vector2(130, 0)
	price_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(price_vbox)

	var price_lbl := Label.new()
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.add_theme_font_override("font", FONT_INDER)
	price_lbl.add_theme_font_size_override("font_size", 20)
	price_vbox.add_child(price_lbl)

	var step_info_lbl := Label.new()
	step_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	step_info_lbl.add_theme_font_override("font", FONT_INDER)
	step_info_lbl.add_theme_font_size_override("font_size", 11)
	price_vbox.add_child(step_info_lbl)

	_item_rows[item] = {
		"pips_lbl": pips_lbl,
		"price_lbl": price_lbl,
		"step_info_lbl": step_info_lbl,
		"minus_btn": minus_btn,
		"plus_btn": plus_btn
	}

	_update_row_display(item)
	return row

func _adjust_step(item: ItemData, delta: int) -> void:
	if not item:
		return
	var new_step := clampi(item.current_step + delta, -3, 3)
	if new_step == item.current_step:
		return
		
	InventoryManager.set_item_step([item], new_step)
	
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("interact")
		
	_update_row_display(item)

func _update_row_display(item: ItemData) -> void:
	if not _item_rows.has(item):
		return
	var row_data: Dictionary = _item_rows[item]
	var pips_lbl: Label = row_data["pips_lbl"]
	var price_lbl: Label = row_data["price_lbl"]
	var step_info_lbl: Label = row_data["step_info_lbl"]
	var minus_btn: Button = row_data["minus_btn"]
	var plus_btn: Button = row_data["plus_btn"]

	var step: int = item.current_step
	var final_price: float = item.get_final_price()
	var base_price: float = item.price
	var diff: float = final_price - base_price

	# Pip track string
	var pips_text := ""
	for i in range(-3, 4):
		if i == step:
			if i > 0:
				pips_text += "[+%d] " % i
			elif i == 0:
				pips_text += "[ 0 ] "
			else:
				pips_text += "[%d] " % i
		else:
			if i > 0:
				pips_text += "+%d " % i
			elif i == 0:
				pips_text += " 0  "
			else:
				pips_text += "%d " % i
	pips_lbl.text = pips_text.strip_edges()

	# Price and status readout
	price_lbl.text = "₱%.2f" % final_price

	if step > 0:
		step_info_lbl.text = "Step +%d (+₱%.2f)" % [step, diff]
		var factor = float(step) / 3.0
		var markup_color = Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.35, 0.2), factor)
		price_lbl.add_theme_color_override("font_color", markup_color)
		step_info_lbl.add_theme_color_override("font_color", markup_color)
	elif step < 0:
		step_info_lbl.text = "Step %d (Loss Leader)" % step
		price_lbl.add_theme_color_override("font_color", Color(0.494, 0.761, 0.573))
		step_info_lbl.add_theme_color_override("font_color", Color(0.494, 0.761, 0.573))
	else:
		step_info_lbl.text = "Step 0 (Cost)"
		price_lbl.add_theme_color_override("font_color", Color(0.92, 0.9, 0.78))
		step_info_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))

	minus_btn.disabled = (step <= -3)
	plus_btn.disabled = (step >= 3)
