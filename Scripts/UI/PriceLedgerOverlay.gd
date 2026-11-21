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
		btn.custom_minimum_size = Vector2(74, 38)
		btn.add_theme_font_override("font", FONT_INDER)
		btn.add_theme_font_size_override("font_size", 17)
		btn.pressed.connect(func(): _select_tab(cat.id))
		tab_container.add_child(btn)

	_update_tab_styles()

func _apply_styles() -> void:
	title_label.add_theme_font_override("font", FONT_INDER)
	title_label.add_theme_color_override("font_color", UIStyle.COLOR_GOLD_TEXT)

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
	_update_tab_styles()
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
	if tab_id != "all" and not _has_owned_items_for_tab(tab_id):
		return
	_current_tab = tab_id
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("tab_switch")
	_update_tab_styles()
	refresh_catalog()

func _has_owned_items_for_tab(tab_id: String) -> bool:
	for item in InventoryManager._items:
		if item and item.can_be_sold and item.tier <= StoryManager.current_tier and _matches_tab_id(item, tab_id):
			return true
	return false

func _update_tab_styles() -> void:
	var tabs := tab_container.get_children()
	for i in range(tabs.size()):
		var btn = tabs[i] as Button
		if not btn:
			continue
		var cat_id: String = CATEGORIES[i].id
		var is_locked := (cat_id != "all") and not _has_owned_items_for_tab(cat_id)
		var is_active := (cat_id == _current_tab)
		UIStyle.style_tab_button(btn, is_active, is_locked, 17.0)

# ─── Daily Market Events Panel ────────────────────────────────────────────────

func refresh_events() -> void:
	for child in events_list.get_children():
		child.queue_free()

	var active_events: Array[StoreEventData] = []
	if is_instance_valid(StoreEventManager):
		active_events = StoreEventManager.get_active_events()

	if active_events.is_empty():
		var empty_card := PanelContainer.new()
		var empty_style := UIStyle.create_flat_stylebox(Color(0.16, 0.15, 0.135, 1.0), 8, 16, 16)
		empty_card.add_theme_stylebox_override("panel", empty_style)

		var empty_lbl := Label.new()
		empty_lbl.text = "The neighborhood is quiet today.\n\nMarket demand and prices are stable."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_override("font", FONT_INDER)
		empty_lbl.add_theme_font_size_override("font_size", 17)
		empty_lbl.add_theme_color_override("font_color", Color(0.75, 0.73, 0.68, 0.95))
		empty_card.add_child(empty_lbl)
		events_list.add_child(empty_card)
		return

	for event in active_events:
		var card := PanelContainer.new()
		var card_style := UIStyle.create_flat_stylebox(Color(0.16, 0.15, 0.135, 1.0), 8, 16, 14)
		card_style.border_width_left = 4
		card_style.border_color = UIStyle.COLOR_CARD_SELECTED
		card.add_theme_stylebox_override("panel", card_style)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		card.add_child(vbox)

		# Event Name
		var name_lbl := Label.new()
		name_lbl.text = event.event_name
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.add_theme_font_override("font", FONT_INDER)
		name_lbl.add_theme_font_size_override("font_size", 21)
		name_lbl.add_theme_color_override("font_color", UIStyle.COLOR_GOLD_TEXT)
		vbox.add_child(name_lbl)

		# Modifier summary
		var mod_lbl := Label.new()
		mod_lbl.text = "Demand: %.1fx   •   Tolerance: +%d steps" % [event.demand_multiplier, event.tolerance_offset]
		mod_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mod_lbl.add_theme_font_override("font", FONT_INDER)
		mod_lbl.add_theme_font_size_override("font_size", 15)
		mod_lbl.add_theme_color_override("font_color", UIStyle.COLOR_TAB_ACTIVE)
		vbox.add_child(mod_lbl)

		# Rumor Quote
		if not event.rumor_text.is_empty():
			var rumor_lbl := Label.new()
			rumor_lbl.text = "“%s”" % event.rumor_text
			rumor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rumor_lbl.add_theme_font_override("font", FONT_INDER)
			rumor_lbl.add_theme_font_size_override("font_size", 16)
			rumor_lbl.add_theme_color_override("font_color", Color(0.92, 0.9, 0.84))
			vbox.add_child(rumor_lbl)

		events_list.add_child(card)

# ─── Product Catalog & Steppers ───────────────────────────────────────────────

func refresh_catalog() -> void:
	for child in items_list.get_children():
		child.queue_free()
	_item_rows.clear()

	# Only display sellable items from tiers the player currently OWNS
	var owned_tier: int = StoryManager.current_tier
	var all_items: Array[ItemData] = InventoryManager._items
	var filtered_items: Array[ItemData] = []

	for item in all_items:
		if not item or not item.can_be_sold:
			continue
		if item.tier > owned_tier:
			continue
		if _matches_tab(item):
			filtered_items.append(item)

	if filtered_items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No owned items in this category yet."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_override("font", FONT_INDER)
		empty_lbl.add_theme_font_size_override("font_size", 19)
		empty_lbl.add_theme_color_override("font_color", Color(0.75, 0.73, 0.68))
		items_list.add_child(empty_lbl)
		return

	for item in filtered_items:
		var row := _create_product_row(item)
		items_list.add_child(row)

func _matches_tab(item: ItemData) -> bool:
	return _matches_tab_id(item, _current_tab)

func _matches_tab_id(item: ItemData, tab_id: String) -> bool:
	if tab_id == "all":
		return true
	if tab_id == "other":
		return item.category != "snack" and item.category != "sachet" and item.category != "can" and item.category != "bottle"
	return item.category == tab_id

func _create_product_row(item: ItemData) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 76)
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.165, 0.158, 0.145, 1.0)
	row_style.set_corner_radius_all(8)
	row_style.content_margin_left = 14
	row_style.content_margin_right = 16
	row_style.content_margin_top = 10
	row_style.content_margin_bottom = 10
	row_style.border_width_left = 2
	row_style.border_width_top = 2
	row_style.border_width_right = 2
	row_style.border_width_bottom = 2
	row_style.border_color = Color(0.27, 0.25, 0.22, 1.0)
	row.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	row.add_child(hbox)

	# Product Icon
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(56, 56)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = item.texture
	hbox.add_child(icon_rect)

	# Name & Info VBox
	var info_vbox := VBoxContainer.new()
	info_vbox.custom_minimum_size = Vector2(180, 0)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	var name_lbl := Label.new()
	name_lbl.text = item.item_name
	name_lbl.add_theme_font_override("font", FONT_INDER)
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", UIStyle.COLOR_GOLD_TEXT)
	info_vbox.add_child(name_lbl)

	# Subline: Cost + In Demand tag
	var sub_hbox := HBoxContainer.new()
	sub_hbox.add_theme_constant_override("separation", 10)
	info_vbox.add_child(sub_hbox)

	var cost_lbl := Label.new()
	cost_lbl.text = "Base: ₱%.2f" % item.price
	cost_lbl.add_theme_font_override("font", FONT_INDER)
	cost_lbl.add_theme_font_size_override("font_size", 15)
	cost_lbl.add_theme_color_override("font_color", Color(0.72, 0.7, 0.65))
	sub_hbox.add_child(cost_lbl)

	var in_demand: bool = false
	if is_instance_valid(StoreEventManager):
		in_demand = StoreEventManager.is_item_in_demand(item)
	if in_demand:
		var demand_lbl := Label.new()
		demand_lbl.text = "★ IN DEMAND"
		demand_lbl.add_theme_font_override("font", FONT_INDER)
		demand_lbl.add_theme_font_size_override("font_size", 14)
		demand_lbl.add_theme_color_override("font_color", Color(0.98, 0.78, 0.28))
		sub_hbox.add_child(demand_lbl)

	# Framed Stepper Pill (separate bordered box with hover highlight + wheel scrolling)
	var stepper_box := PanelContainer.new()
	stepper_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stepper_box.mouse_filter = Control.MOUSE_FILTER_STOP
	stepper_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var stepper_normal := StyleBoxFlat.new()
	stepper_normal.bg_color = Color(0.08, 0.075, 0.07, 1.0)
	stepper_normal.set_corner_radius_all(8)
	stepper_normal.content_margin_left = 6
	stepper_normal.content_margin_right = 6
	stepper_normal.content_margin_top = 5
	stepper_normal.content_margin_bottom = 5
	stepper_normal.border_width_left = 2
	stepper_normal.border_width_top = 2
	stepper_normal.border_width_right = 2
	stepper_normal.border_width_bottom = 2
	stepper_normal.border_color = Color(0.28, 0.26, 0.23, 1.0)

	var stepper_hover: StyleBoxFlat = stepper_normal.duplicate()
	stepper_hover.bg_color = Color(0.15, 0.145, 0.13, 1.0)
	stepper_hover.border_color = UIStyle.COLOR_CARD_SELECTED

	stepper_box.add_theme_stylebox_override("panel", stepper_normal)
	hbox.add_child(stepper_box)

	var stepper_hbox := HBoxContainer.new()
	stepper_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stepper_hbox.add_theme_constant_override("separation", 8)
	stepper_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	stepper_box.add_child(stepper_hbox)

	var minus_btn := Button.new()
	minus_btn.text = "−"
	minus_btn.custom_minimum_size = Vector2(36, 36)
	minus_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	minus_btn.focus_mode = Control.FOCUS_NONE
	UIStyle.style_button(minus_btn, Color(0.3, 0.3, 0.3), Color.WHITE, 20.0, 6)
	minus_btn.pressed.connect(func(): _adjust_step(item, -1))
	stepper_hbox.add_child(minus_btn)

	var pips_lbl := Label.new()
	pips_lbl.custom_minimum_size = Vector2(165, 36)
	pips_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pips_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pips_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	pips_lbl.add_theme_font_override("font", FONT_INDER)
	pips_lbl.add_theme_font_size_override("font_size", 22)
	stepper_hbox.add_child(pips_lbl)

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(36, 36)
	plus_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plus_btn.focus_mode = Control.FOCUS_NONE
	UIStyle.style_button(plus_btn, UIStyle.COLOR_CONFIRM, Color.WHITE, 20.0, 6)
	plus_btn.pressed.connect(func(): _adjust_step(item, 1))
	stepper_hbox.add_child(plus_btn)

	# Wire hover highlight + mouse-wheel price stepping across the stepper pill & its children
	var on_stepper_wheel := func(event: InputEvent, ctrl: Control):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_adjust_step(item, 1)
				ctrl.accept_event()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_adjust_step(item, -1)
				ctrl.accept_event()

	var update_hover := func():
		if not is_instance_valid(stepper_box):
			return
		var local_mouse := stepper_box.get_local_mouse_position()
		var inside := Rect2(Vector2.ZERO, stepper_box.size).has_point(local_mouse)
		stepper_box.add_theme_stylebox_override("panel", stepper_hover if inside else stepper_normal)

	for ctrl in [stepper_box, minus_btn, pips_lbl, plus_btn]:
		ctrl.gui_input.connect(on_stepper_wheel.bind(ctrl))
		ctrl.mouse_entered.connect(func(): stepper_box.add_theme_stylebox_override("panel", stepper_hover))
		ctrl.mouse_exited.connect(update_hover)

	# Price & Step Readout VBox
	var price_vbox := VBoxContainer.new()
	price_vbox.custom_minimum_size = Vector2(138, 0)
	price_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	price_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(price_vbox)

	var price_lbl := Label.new()
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.add_theme_font_override("font", FONT_INDER)
	price_lbl.add_theme_font_size_override("font_size", 23)
	price_vbox.add_child(price_lbl)

	var step_info_lbl := Label.new()
	step_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	step_info_lbl.add_theme_font_override("font", FONT_INDER)
	step_info_lbl.add_theme_font_size_override("font_size", 14)
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

	# Circle track string: • for selected and ◦ for not selected
	var pips_text := ""
	for i in range(-3, 4):
		if i == step:
			pips_text += "•  "
		else:
			pips_text += "◦  "
	pips_lbl.text = pips_text.strip_edges()

	# Price and status readout
	price_lbl.text = "₱%.2f" % final_price

	if step > 0:
		step_info_lbl.text = "+₱%.2f" % diff
		var factor = float(step) / 3.0
		var markup_color = Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.35, 0.2), factor)
		price_lbl.add_theme_color_override("font_color", markup_color)
		step_info_lbl.add_theme_color_override("font_color", markup_color)
	elif step < 0:
		step_info_lbl.text = "-₱%.2f" % absf(diff)
		price_lbl.add_theme_color_override("font_color", Color(0.494, 0.761, 0.573))
		step_info_lbl.add_theme_color_override("font_color", Color(0.494, 0.761, 0.573))
	else:
		step_info_lbl.text = "+₱0.00"
		price_lbl.add_theme_color_override("font_color", Color(0.92, 0.9, 0.78))
		step_info_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))

	minus_btn.disabled = (step <= -3)
	plus_btn.disabled = (step >= 3)
