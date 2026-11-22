extends Control

signal upgrade_purchase_confirmed(total_cost: float, upgrade_item: ItemData)
signal upgrade_menu_closed
signal menu_close_requested

@onready var upgrade_list_container: VBoxContainer = %UpgradeList
@onready var current_tier_label: Label = %CurrentTierLabel
@onready var detail_header: Label = %DetailHeader
@onready var detail_icon: TextureRect = %DetailIcon
@onready var detail_name: Label = %DetailName
@onready var detail_subtitle: Label = %DetailSubtitle
@onready var unlocks_list: VBoxContainer = %UnlocksList
@onready var total_amount_label: Label = %TotalAmountLabel
@onready var cancel_btn: Button = %CancelBtn
@onready var confirm_btn: Button = %ConfirmBtn

var _selected_upgrade: ItemData = null
var _card_map: Dictionary = {} # ItemData -> PanelContainer

func _ready() -> void:
	if cancel_btn:
		cancel_btn.pressed.connect(_on_cancel_pressed)
		UIStyle.style_button(cancel_btn, UIStyle.COLOR_CANCEL, Color.WHITE, 18.0)
	if confirm_btn:
		confirm_btn.pressed.connect(_on_confirm_pressed)
		UIStyle.style_button(confirm_btn, UIStyle.COLOR_CONFIRM, Color.WHITE, 18.0)

	var close_btn_node = get_node_or_null("%CloseBtn")
	if close_btn_node:
		close_btn_node.pressed.connect(_on_cancel_pressed)

	EventBus.restock_catalog_refresh.connect(_on_catalog_refresh_requested)
	hide()

func _on_catalog_refresh_requested() -> void:
	if is_visible_in_tree():
		_populate_upgrades()

func open_menu() -> void:
	show()
	_animate_entrance()
	_selected_upgrade = null
	_populate_upgrades()

	# Auto-select the next purchasable tier if available
	var next_tier := StoryManager.current_tier + 1
	if next_tier <= StoryManager.max_unlocked_tier and next_tier <= 10:
		var next_item := StoryManager.get_tier_upgrade_item(next_tier)
		if next_item and _card_map.has(next_item):
			_select_upgrade(next_item)
	else:
		_clear_detail_panel()

func _animate_entrance() -> void:
	modulate.a = 0.0
	position.y += 100
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y - 100, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.3)

func _populate_upgrades() -> void:
	for child in upgrade_list_container.get_children():
		child.queue_free()
	_card_map.clear()

	if current_tier_label:
		current_tier_label.text = "Current: Tier %d" % StoryManager.current_tier

	for t in range(2, 11):
		var item := StoryManager.get_tier_upgrade_item(t)
		var card := _create_upgrade_bar(item, t)
		upgrade_list_container.add_child(card)
		_card_map[item] = card

	# Refrigerator Upgrades section
	var fridge_header := Label.new()
	fridge_header.text = "REFRIGERATOR UPGRADES"
	fridge_header.add_theme_font_override("font", UIStyle.FONT_INDER)
	fridge_header.add_theme_font_size_override("font_size", 15)
	fridge_header.add_theme_color_override("font_color", Color("#8CE6FF"))
	var hdr_margin := MarginContainer.new()
	hdr_margin.add_theme_constant_override("margin_top", 10)
	hdr_margin.add_theme_constant_override("margin_bottom", 2)
	hdr_margin.add_child(fridge_header)
	upgrade_list_container.add_child(hdr_margin)

	for lvl in range(1, 4):
		var f_item := StoryManager.get_fridge_upgrade_item(lvl)
		var f_card := _create_fridge_upgrade_bar(f_item, lvl)
		upgrade_list_container.add_child(f_card)
		_card_map[f_item] = f_card

func _get_tier_sellable_items(tier: int) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in InventoryManager.get_all_items():
		if item and item.tier == tier and item.can_be_sold:
			result.append(item)
	return result

func _create_upgrade_bar(item: ItemData, target_tier: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 74)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE

	var owned: bool = target_tier <= StoryManager.current_tier
	var unlocked: bool = target_tier <= StoryManager.max_unlocked_tier
	var is_next_available: bool = (not owned) and unlocked and (target_tier == StoryManager.current_tier + 1)

	var bg_col := UIStyle.COLOR_CARD_BG
	if owned:
		bg_col = UIStyle.COLOR_CARD_OWNED_BG
	elif not is_next_available:
		bg_col = UIStyle.COLOR_TAB_LOCKED

	var style := UIStyle.create_card_style(bg_col, UIStyle.COLOR_CARD_BORDER, 2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(hbox)

	# Left icon frame
	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(54, 54)
	icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var frame_style := UIStyle.create_flat_stylebox(Color(0, 0, 0, 0.22), 6, 4, 4)
	icon_frame.add_theme_stylebox_override("panel", frame_style)
	hbox.add_child(icon_frame)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if item.texture:
		icon.texture = item.texture
	icon_frame.add_child(icon)

	# Middle info: Name + unlocked products preview
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_lbl := Label.new()
	name_lbl.text = item.item_name
	name_lbl.add_theme_font_size_override("font_size", 19)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	info_vbox.add_child(name_lbl)

	var tier_items := _get_tier_sellable_items(target_tier)
	var sub_lbl := Label.new()
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if owned or unlocked:
		var item_names: PackedStringArray = []
		for ti in tier_items:
			item_names.append(ti.item_name)
		sub_lbl.text = "Unlocks: " + (", ".join(item_names) if not item_names.is_empty() else "New store stock")
		sub_lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 0.95, 0.9))
	else:
		sub_lbl.text = "Serve more customers to unlock"
		sub_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 0.85))
	info_vbox.add_child(sub_lbl)

	# Right info: Price + Status badge
	var right_vbox := VBoxContainer.new()
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(right_vbox)

	var price_lbl := Label.new()
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.add_theme_font_size_override("font_size", 17)
	price_lbl.text = "₱%.2f" % item.price
	price_lbl.add_theme_color_override("font_color", UIStyle.COLOR_GOLD_TEXT if is_next_available else Color(0.85, 0.85, 0.85, 0.9))
	right_vbox.add_child(price_lbl)

	var status_lbl := Label.new()
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_lbl.add_theme_font_size_override("font_size", 12)
	if owned:
		status_lbl.text = "OWNED"
		status_lbl.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75, 1.0))
	elif is_next_available:
		status_lbl.text = "AVAILABLE"
		status_lbl.add_theme_color_override("font_color", Color.WHITE)
	elif unlocked:
		status_lbl.text = "BUY TIER %d FIRST" % (target_tier - 1)
		status_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55, 0.95))
	else:
		status_lbl.text = "LOCKED"
		status_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.9))
	right_vbox.add_child(status_lbl)

	# Interactivity & state visuals
	if owned:
		icon.modulate = Color(1, 1, 1, 0.5)
		card.modulate = Color(0.85, 1.0, 0.85, 0.7)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif is_next_available:
		icon.modulate = Color(1, 1, 1, 1)
		card.modulate = Color(1, 1, 1, 1)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(_on_card_clicked.bind(item))
	else:
		icon.modulate = Color(0, 0, 0, 1)
		card.modulate = Color(0.7, 0.7, 0.7, 0.85)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.mouse_default_cursor_shape = Control.CURSOR_ARROW

	return card

func _create_fridge_upgrade_bar(item: ItemData, target_level: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 74)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE

	var owned: bool = target_level <= StoryManager.fridge_upgrade_level
	var is_next_available: bool = (not owned) and (target_level == StoryManager.fridge_upgrade_level + 1)

	var bg_col := UIStyle.COLOR_CARD_BG
	if owned:
		bg_col = UIStyle.COLOR_CARD_OWNED_BG
	elif not is_next_available:
		bg_col = UIStyle.COLOR_TAB_LOCKED

	var style := UIStyle.create_card_style(bg_col, UIStyle.COLOR_CARD_BORDER, 2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(hbox)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(54, 54)
	icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_frame.add_theme_stylebox_override("panel", UIStyle.create_flat_stylebox(Color(0.05, 0.16, 0.22, 0.55), 6, 4, 4))
	hbox.add_child(icon_frame)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if item.texture:
		icon.texture = item.texture
	icon_frame.add_child(icon)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_lbl := Label.new()
	name_lbl.text = item.item_name
	name_lbl.add_theme_font_size_override("font_size", 19)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	info_vbox.add_child(name_lbl)

	var drain_s: float = float(item.get_meta("drain_sec", 10.0))
	var regen_s: float = float(item.get_meta("regen_sec", 7.5))
	var sub_lbl := Label.new()
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.text = "Cold lasts %.0fs open  •  Recovers in %.1fs closed" % [drain_s, regen_s]
	sub_lbl.add_theme_color_override("font_color", Color(0.75, 0.94, 1.0, 0.92))
	info_vbox.add_child(sub_lbl)

	var right_vbox := VBoxContainer.new()
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(right_vbox)

	var price_lbl := Label.new()
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.add_theme_font_size_override("font_size", 17)
	price_lbl.text = "₱%.2f" % item.price
	price_lbl.add_theme_color_override("font_color", UIStyle.COLOR_GOLD_TEXT if is_next_available else Color(0.85, 0.85, 0.85, 0.9))
	right_vbox.add_child(price_lbl)

	var status_lbl := Label.new()
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_lbl.add_theme_font_size_override("font_size", 12)
	if owned:
		status_lbl.text = "OWNED"
		status_lbl.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75, 1.0))
	elif is_next_available:
		status_lbl.text = "AVAILABLE"
		status_lbl.add_theme_color_override("font_color", Color.WHITE)
	else:
		status_lbl.text = "BUY LVL %d FIRST" % (target_level - 1)
		status_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55, 0.95))
	right_vbox.add_child(status_lbl)

	if owned:
		icon.modulate = Color(1, 1, 1, 0.5)
		card.modulate = Color(0.85, 1.0, 0.85, 0.7)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif is_next_available:
		icon.modulate = Color(1, 1, 1, 1)
		card.modulate = Color(1, 1, 1, 1)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(_on_card_clicked.bind(item))
	else:
		icon.modulate = Color(0.35, 0.45, 0.5, 0.8)
		card.modulate = Color(0.7, 0.7, 0.7, 0.85)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.mouse_default_cursor_shape = Control.CURSOR_ARROW

	return card

func _on_card_clicked(event: InputEvent, item: ItemData) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		AudioManager.play_sfx("interact")
		_select_upgrade(item)

func _select_upgrade(item: ItemData) -> void:
	_selected_upgrade = item

	# Update selection border highlight
	for u_item in _card_map.keys():
		var c: PanelContainer = _card_map[u_item]
		if not is_instance_valid(c):
			continue
		var s := c.get_theme_stylebox("panel") as StyleBoxFlat
		if s:
			s.border_color = UIStyle.COLOR_CARD_SELECTED if u_item == item else UIStyle.COLOR_CARD_BORDER
			s.border_width_left = 3 if u_item == item else 2
			s.border_width_top = 3 if u_item == item else 2
			s.border_width_right = 3 if u_item == item else 2
			s.border_width_bottom = 3 if u_item == item else 2

	_update_detail_panel(item)

func _update_detail_panel(item: ItemData) -> void:
	if item.get_meta("is_fridge_upgrade", false):
		var lvl: int = int(item.get_meta("fridge_level", 1))
		var prev_spec: Dictionary = StoryManager.FRIDGE_UPGRADE_SPECS[lvl - 1]
		var next_spec: Dictionary = StoryManager.FRIDGE_UPGRADE_SPECS[lvl]
		if detail_icon:
			detail_icon.texture = item.texture
		if detail_name:
			detail_name.text = item.item_name
		if detail_subtitle:
			detail_subtitle.text = str(item.get_meta("upgrade_desc", ""))

		for child in unlocks_list.get_children():
			child.queue_free()

		for line in [
			"• Cold Retention: %.0fs → %.0fs open" % [float(prev_spec["drain_sec"]), float(next_spec["drain_sec"])],
			"• Cooling Recovery: %.1fs → %.1fs closed" % [float(prev_spec["regen_sec"]), float(next_spec["regen_sec"])],
			"• Protects chilled & frozen stock from -25% warmth loss"
		]:
			var stat_lbl := Label.new()
			stat_lbl.text = line
			stat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stat_lbl.add_theme_font_size_override("font_size", 15)
			stat_lbl.add_theme_color_override("font_color", Color("#C9F3FF"))
			unlocks_list.add_child(stat_lbl)

		if total_amount_label:
			total_amount_label.text = "₱%.2f" % item.price
		var can_afford_f := _get_money() >= item.price
		if confirm_btn:
			confirm_btn.disabled = not can_afford_f
			if can_afford_f:
				UIStyle.style_button(confirm_btn, UIStyle.COLOR_CONFIRM, Color.WHITE, 18.0)
			else:
				UIStyle.style_button(confirm_btn, UIStyle.COLOR_TAB_LOCKED, UIStyle.COLOR_TAB_LOCKED_FONT, 18.0)
		return

	var target_tier: int = item.get_meta("target_tier", 2)
	if detail_icon:
		detail_icon.texture = item.texture
	if detail_name:
		detail_name.text = item.item_name
	if detail_subtitle:
		detail_subtitle.text = "Includes 2x starter samples of each item:"

	for child in unlocks_list.get_children():
		child.queue_free()

	var tier_items := _get_tier_sellable_items(target_tier)
	if tier_items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "New store catalog items"
		empty_lbl.add_theme_color_override("font_color", Color("CCCCCC"))
		empty_lbl.add_theme_font_size_override("font_size", 15)
		unlocks_list.add_child(empty_lbl)
	else:
		for ti in tier_items:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)

			var mini_icon := TextureRect.new()
			mini_icon.custom_minimum_size = Vector2(28, 28)
			mini_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mini_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if ti.texture:
				mini_icon.texture = ti.texture
			row.add_child(mini_icon)

			var lbl := Label.new()
			lbl.text = ti.item_name
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.add_theme_color_override("font_color", Color.WHITE)
			row.add_child(lbl)

			unlocks_list.add_child(row)

	if total_amount_label:
		total_amount_label.text = "₱%.2f" % item.price

	var can_afford := _get_money() >= item.price
	if confirm_btn:
		confirm_btn.disabled = not can_afford
		if can_afford:
			UIStyle.style_button(confirm_btn, UIStyle.COLOR_CONFIRM, Color.WHITE, 18.0)
		else:
			UIStyle.style_button(confirm_btn, UIStyle.COLOR_TAB_LOCKED, UIStyle.COLOR_TAB_LOCKED_FONT, 18.0)

func _clear_detail_panel() -> void:
	if detail_icon:
		detail_icon.texture = null
	if detail_name:
		detail_name.text = "No Upgrade Available"
	if detail_subtitle:
		detail_subtitle.text = "Keep serving customers to unlock the next store tier."
	for child in unlocks_list.get_children():
		child.queue_free()
	if total_amount_label:
		total_amount_label.text = "₱0.00"
	if confirm_btn:
		confirm_btn.disabled = true
		UIStyle.style_button(confirm_btn, UIStyle.COLOR_TAB_LOCKED, UIStyle.COLOR_TAB_LOCKED_FONT, 18.0)

func _close_upgrade_screen() -> void:
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y + 100, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		menu_close_requested.emit()
		hide()
		position.y -= 100
		modulate.a = 1.0
	)

func _on_cancel_pressed() -> void:
	AudioManager.play_sfx("drop")
	MarioManager.cancel_restock()
	upgrade_menu_closed.emit()
	_close_upgrade_screen()

func _on_confirm_pressed() -> void:
	if _selected_upgrade == null:
		return
	if confirm_btn:
		confirm_btn.disabled = true

	# Direct validation & instant install for Refrigerator Upgrades (not limited by shelf capacity)
	if _selected_upgrade.get_meta("is_fridge_upgrade", false):
		var f_cost := _selected_upgrade.price
		var target_lvl: int = int(_selected_upgrade.get_meta("fridge_level", 1))
		if target_lvl != StoryManager.fridge_upgrade_level + 1:
			if confirm_btn:
				confirm_btn.disabled = false
			return
		if _get_money() < f_cost:
			EventBus.insufficient_funds.emit()
			if confirm_btn:
				confirm_btn.disabled = false
			return
		AudioManager.play_sfx("purchase")
		var gm_f = get_tree().get_nodes_in_group("game_manager")
		if gm_f.size() > 0 and gm_f[0].has_method("deduct_money"):
			gm_f[0].deduct_money(f_cost)
		StoryManager.purchase_fridge_upgrade(target_lvl)
		EventBus.show_notification.emit("Fridge Upgraded!", "%s installed." % _selected_upgrade.item_name, "purchase")
		MarioManager.cancel_restock()
		_close_upgrade_screen()
		return

	var order := RestockOrder.new()
	var check := order.can_add(_selected_upgrade, _get_money())
	if not check.ok:
		if check.title != "":
			EventBus.show_notification.emit(check.title, check.message, check.sfx)
		if check.sfx != "":
			AudioManager.play_sfx(check.sfx)
		elif check.error == "insufficient_funds":
			EventBus.insufficient_funds.emit()
		if confirm_btn:
			confirm_btn.disabled = false
		return

	var cost := _selected_upgrade.price
	AudioManager.play_sfx("purchase")

	var gm_nodes = get_tree().get_nodes_in_group("game_manager")
	if gm_nodes.size() > 0:
		var gm = gm_nodes[0]
		if gm.has_method("deduct_money"):
			gm.deduct_money(cost)

	var delivery_items: Dictionary = { _selected_upgrade: 1 }
	upgrade_purchase_confirmed.emit(cost, _selected_upgrade)
	_close_upgrade_screen()
	MarioManager.start_delivery(delivery_items)

func _get_money() -> float:
	var gm_nodes = get_tree().get_nodes_in_group("game_manager")
	return gm_nodes[0].money if gm_nodes.size() > 0 else 0.0
