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

var _focused_upgrade: ItemData = null
var _queued_upgrades: Array[ItemData] = []
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

	# Prevent Godot 4 ScrollContainer + wrapped-Label scrollbar width oscillation hangs
	if unlocks_list and unlocks_list.get_parent() is ScrollContainer:
		(unlocks_list.get_parent() as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER

	EventBus.restock_catalog_refresh.connect(_on_catalog_refresh_requested)
	hide()

func _on_catalog_refresh_requested() -> void:
	if is_visible_in_tree():
		_populate_upgrades()

func open_menu() -> void:
	show()
	_animate_entrance()
	_focused_upgrade = null
	_queued_upgrades.clear()
	_populate_upgrades()

	# Auto-focus the next purchasable tier (or next fridge upgrade) without auto-queueing
	var next_tier := StoryManager.current_tier + 1
	if next_tier <= StoryManager.max_unlocked_tier and next_tier <= 10:
		var next_item := StoryManager.get_tier_upgrade_item(next_tier)
		if next_item and _card_map.has(next_item):
			_focus_upgrade(next_item)
			return
	if StoryManager.fridge_upgrade_level < 3:
		var next_fridge := StoryManager.get_fridge_upgrade_item(StoryManager.fridge_upgrade_level + 1)
		if next_fridge and StoryManager.player_level >= int(next_fridge.get_meta("req_level", 1)) and _card_map.has(next_fridge):
			_focus_upgrade(next_fridge)
			return
	if StoryManager.cat_upgrade_level < 2:
		var next_cat := StoryManager.get_cat_upgrade_item(StoryManager.cat_upgrade_level + 1)
		if next_cat and StoryManager.player_level >= int(next_cat.get_meta("req_level", 1)) and _card_map.has(next_cat):
			_focus_upgrade(next_cat)
			return
	if not StoryManager.has_trash_can:
		var trash_item := StoryManager.get_trash_can_upgrade_item()
		if trash_item and StoryManager.player_level >= int(trash_item.get_meta("req_level", 1)) and _card_map.has(trash_item):
			_focus_upgrade(trash_item)
			return
	if StoryManager.maneki_upgrade_level < 2:
		var next_maneki := StoryManager.get_maneki_upgrade_item(StoryManager.maneki_upgrade_level + 1)
		if next_maneki and StoryManager.player_level >= int(next_maneki.get_meta("req_level", 1)) and _card_map.has(next_maneki):
			_focus_upgrade(next_maneki)
			return
	if StoryManager.radio_upgrade_level < 3:
		var next_radio := StoryManager.get_radio_upgrade_item(StoryManager.radio_upgrade_level + 1)
		if next_radio and StoryManager.player_level >= int(next_radio.get_meta("req_level", 1)) and _card_map.has(next_radio):
			_focus_upgrade(next_radio)
			return
	if not StoryManager.has_mario_deals:
		var deals_item := StoryManager.get_mario_deals_upgrade_item()
		if deals_item and StoryManager.player_level >= int(deals_item.get_meta("req_level", 1)) and _card_map.has(deals_item):
			_focus_upgrade(deals_item)
			return
	_clear_detail_panel()

func _animate_entrance() -> void:
	modulate.a = 0.0
	position.y += 100
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y - 100, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.3)

func _populate_upgrades() -> void:
	for child in upgrade_list_container.get_children():
		upgrade_list_container.remove_child(child)
		child.queue_free()
	_card_map.clear()

	if current_tier_label:
		var xp_need := StoryManager.get_xp_for_next_level()
		if xp_need > 0:
			current_tier_label.text = "Player Lv. %d (%d/%d XP)  •  Tier %d" % [StoryManager.player_level, StoryManager.player_xp, xp_need, StoryManager.current_tier]
		else:
			current_tier_label.text = "Player Lv. %d (MAX)  •  Tier %d" % [StoryManager.player_level, StoryManager.current_tier]

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

	# Store Props & Cats section
	var cat_header := Label.new()
	cat_header.text = "STORE PROPS & CATS"
	cat_header.add_theme_font_override("font", UIStyle.FONT_INDER)
	cat_header.add_theme_font_size_override("font_size", 15)
	cat_header.add_theme_color_override("font_color", Color("#FFD98A"))
	var cat_hdr_margin := MarginContainer.new()
	cat_hdr_margin.add_theme_constant_override("margin_top", 10)
	cat_hdr_margin.add_theme_constant_override("margin_bottom", 2)
	cat_hdr_margin.add_child(cat_header)
	upgrade_list_container.add_child(cat_hdr_margin)

	var trash_item := StoryManager.get_trash_can_upgrade_item()
	var trash_card := _create_trash_upgrade_bar(trash_item)
	upgrade_list_container.add_child(trash_card)
	_card_map[trash_item] = trash_card

	for lvl in range(1, 3):
		var c_item := StoryManager.get_cat_upgrade_item(lvl)
		var c_card := _create_cat_upgrade_bar(c_item, lvl)
		upgrade_list_container.add_child(c_card)
		_card_map[c_item] = c_card

	for lvl in range(1, 3):
		var m_item := StoryManager.get_maneki_upgrade_item(lvl)
		var m_card := _create_maneki_upgrade_bar(m_item, lvl)
		upgrade_list_container.add_child(m_card)
		_card_map[m_item] = m_card

	# Store Intel & Wholesale Deals section
	var intel_header := Label.new()
	intel_header.text = "STORE INTEL & WHOLESALE DEALS"
	intel_header.add_theme_font_override("font", UIStyle.FONT_INDER)
	intel_header.add_theme_font_size_override("font_size", 15)
	intel_header.add_theme_color_override("font_color", Color("#F5C97B"))
	var intel_hdr_margin := MarginContainer.new()
	intel_hdr_margin.add_theme_constant_override("margin_top", 10)
	intel_hdr_margin.add_theme_constant_override("margin_bottom", 2)
	intel_hdr_margin.add_child(intel_header)
	upgrade_list_container.add_child(intel_hdr_margin)

	var deals_item := StoryManager.get_mario_deals_upgrade_item()
	var deals_card := _create_mario_deals_upgrade_bar(deals_item)
	upgrade_list_container.add_child(deals_card)
	_card_map[deals_item] = deals_card

	for lvl in range(1, 4):
		var r_item := StoryManager.get_radio_upgrade_item(lvl)
		var r_card := _create_radio_upgrade_bar(r_item, lvl)
		upgrade_list_container.add_child(r_card)
		_card_map[r_item] = r_card

func _get_tier_sellable_items(tier: int) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in InventoryManager.get_all_items():
		if item and item.tier == tier and item.can_be_sold:
			result.append(item)
	return result

func _get_effective_tier() -> int:
	var eff := StoryManager.current_tier
	for q in _queued_upgrades:
		if q.get_meta("is_upgrade", false):
			eff = maxi(eff, int(q.get_meta("target_tier", eff)))
	return eff

func _get_effective_fridge_level() -> int:
	var eff := StoryManager.fridge_upgrade_level
	for q in _queued_upgrades:
		if q.get_meta("is_fridge_upgrade", false):
			eff = maxi(eff, int(q.get_meta("fridge_level", eff)))
	return eff

func _get_effective_cat_level() -> int:
	var eff := StoryManager.cat_upgrade_level
	for q in _queued_upgrades:
		if q.get_meta("is_cat_upgrade", false):
			eff = maxi(eff, int(q.get_meta("cat_level", eff)))
	return eff

func _get_effective_maneki_level() -> int:
	var eff := StoryManager.maneki_upgrade_level
	for q in _queued_upgrades:
		if q.get_meta("is_maneki_upgrade", false):
			eff = maxi(eff, int(q.get_meta("maneki_level", eff)))
	return eff

func _get_effective_radio_level() -> int:
	var eff := StoryManager.radio_upgrade_level
	for q in _queued_upgrades:
		if q.get_meta("is_radio_upgrade", false):
			eff = maxi(eff, int(q.get_meta("radio_level", eff)))
	return eff

func _get_queued_total_cost() -> float:
	var total := 0.0
	for q in _queued_upgrades:
		total += q.price
	return total

func _create_upgrade_bar(item: ItemData, target_tier: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 74)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE

	var owned: bool = target_tier <= StoryManager.current_tier
	var is_queued: bool = item in _queued_upgrades
	var unlocked: bool = target_tier <= StoryManager.max_unlocked_tier
	var is_next_available: bool = (not owned) and unlocked and (target_tier == _get_effective_tier() + 1)

	var bg_col := UIStyle.COLOR_CARD_BG
	if owned:
		bg_col = UIStyle.COLOR_CARD_OWNED_BG
	elif is_queued:
		bg_col = Color(0.14, 0.28, 0.16, 0.95)
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
	elif is_queued:
		status_lbl.text = "QUEUED ✓"
		status_lbl.add_theme_color_override("font_color", Color("#8BF08E"))
	elif is_next_available:
		status_lbl.text = "AVAILABLE"
		status_lbl.add_theme_color_override("font_color", Color.WHITE)
	elif unlocked:
		status_lbl.text = "BUY TIER %d FIRST" % (target_tier - 1)
		status_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55, 0.95))
	else:
		status_lbl.text = "REQUIRES LV. %d" % target_tier
		status_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.9))
	right_vbox.add_child(status_lbl)

	# Interactivity & state visuals
	if owned:
		icon.modulate = Color(1, 1, 1, 0.5)
		card.modulate = Color(0.85, 1.0, 0.85, 0.7)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif is_queued or is_next_available:
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

	var req_lvl: int = int(item.get_meta("req_level", 1))
	var level_unlocked: bool = StoryManager.player_level >= req_lvl
	var owned: bool = target_level <= StoryManager.fridge_upgrade_level
	var is_queued: bool = item in _queued_upgrades
	var is_next_available: bool = (not owned) and level_unlocked and (target_level == _get_effective_fridge_level() + 1)

	var bg_col := UIStyle.COLOR_CARD_BG
	if owned:
		bg_col = UIStyle.COLOR_CARD_OWNED_BG
	elif is_queued:
		bg_col = Color(0.14, 0.28, 0.16, 0.95)
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
	elif is_queued:
		status_lbl.text = "QUEUED ✓"
		status_lbl.add_theme_color_override("font_color", Color("#8BF08E"))
	elif is_next_available:
		status_lbl.text = "AVAILABLE"
		status_lbl.add_theme_color_override("font_color", Color.WHITE)
	elif not level_unlocked:
		status_lbl.text = "REQUIRES LV. %d" % req_lvl
		status_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.9))
	else:
		status_lbl.text = "BUY LVL %d FIRST" % (target_level - 1)
		status_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55, 0.95))
	right_vbox.add_child(status_lbl)

	if owned:
		icon.modulate = Color(1, 1, 1, 0.5)
		card.modulate = Color(0.85, 1.0, 0.85, 0.7)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif is_queued or is_next_available:
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

func _create_trash_upgrade_bar(item: ItemData) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 74)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE

	var req_lvl: int = int(item.get_meta("req_level", 1))
	var level_unlocked: bool = StoryManager.player_level >= req_lvl
	var owned: bool = StoryManager.has_trash_can
	var is_queued: bool = item in _queued_upgrades

	var bg_col := UIStyle.COLOR_CARD_BG
	if owned:
		bg_col = UIStyle.COLOR_CARD_OWNED_BG
	elif is_queued:
		bg_col = Color(0.14, 0.28, 0.16, 0.95)
	elif not level_unlocked:
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
	icon_frame.add_theme_stylebox_override("panel", UIStyle.create_flat_stylebox(Color(0.24, 0.17, 0.08, 0.55), 6, 4, 4))
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

	var sub_lbl := Label.new()
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.text = "Discard unwanted or extra shelf stock anytime"
	sub_lbl.add_theme_color_override("font_color", Color("#FFECC4"))
	info_vbox.add_child(sub_lbl)

	var right_vbox := VBoxContainer.new()
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(right_vbox)

	var price_lbl := Label.new()
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.add_theme_font_size_override("font_size", 17)
	price_lbl.text = "₱%.2f" % item.price
	price_lbl.add_theme_color_override("font_color", UIStyle.COLOR_GOLD_TEXT if not owned else Color(0.85, 0.85, 0.85, 0.9))
	right_vbox.add_child(price_lbl)

	var status_lbl := Label.new()
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_lbl.add_theme_font_size_override("font_size", 12)
	if owned:
		status_lbl.text = "OWNED"
		status_lbl.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75, 1.0))
	elif is_queued:
		status_lbl.text = "QUEUED ✓"
		status_lbl.add_theme_color_override("font_color", Color("#8BF08E"))
	elif level_unlocked:
		status_lbl.text = "AVAILABLE"
		status_lbl.add_theme_color_override("font_color", Color.WHITE)
	else:
		status_lbl.text = "REQUIRES LV. %d" % req_lvl
		status_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.9))
	right_vbox.add_child(status_lbl)

	if owned:
		icon.modulate = Color(1, 1, 1, 0.5)
		card.modulate = Color(0.85, 1.0, 0.85, 0.7)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif is_queued or level_unlocked:
		icon.modulate = Color(1, 1, 1, 1)
		card.modulate = Color(1, 1, 1, 1)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(_on_card_clicked.bind(item))
	else:
		icon.modulate = Color(0.3, 0.25, 0.2, 0.8)
		card.modulate = Color(0.7, 0.7, 0.7, 0.85)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.mouse_default_cursor_shape = Control.CURSOR_ARROW

	return card

func _create_cat_upgrade_bar(item: ItemData, target_level: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 74)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE

	var req_lvl: int = int(item.get_meta("req_level", 1))
	var level_unlocked: bool = StoryManager.player_level >= req_lvl
	var owned: bool = target_level <= StoryManager.cat_upgrade_level
	var is_queued: bool = item in _queued_upgrades
	var is_next_available: bool = (not owned) and level_unlocked and (target_level == _get_effective_cat_level() + 1)

	var bg_col := UIStyle.COLOR_CARD_BG
	if owned:
		bg_col = UIStyle.COLOR_CARD_OWNED_BG
	elif is_queued:
		bg_col = Color(0.14, 0.28, 0.16, 0.95)
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
	icon_frame.add_theme_stylebox_override("panel", UIStyle.create_flat_stylebox(Color(0.24, 0.17, 0.08, 0.55), 6, 4, 4))
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

	var slots: int = int(item.get_meta("slots", target_level + 1))
	var sub_lbl := Label.new()
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.text = "Counter Slots: %d  •  Pettable store cat" % slots if target_level == 1 else "Counter Slots: %d  •  Well-fed lucky cat" % slots
	sub_lbl.add_theme_color_override("font_color", Color("#FFECC4"))
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
	elif is_queued:
		status_lbl.text = "QUEUED ✓"
		status_lbl.add_theme_color_override("font_color", Color("#8BF08E"))
	elif is_next_available:
		status_lbl.text = "AVAILABLE"
		status_lbl.add_theme_color_override("font_color", Color.WHITE)
	elif not level_unlocked:
		status_lbl.text = "REQUIRES LV. %d" % req_lvl
		status_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.9))
	else:
		status_lbl.text = "ADOPT CAT FIRST"
		status_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55, 0.95))
	right_vbox.add_child(status_lbl)

	if owned:
		icon.modulate = Color(1, 1, 1, 0.5)
		card.modulate = Color(0.85, 1.0, 0.85, 0.7)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif is_queued or is_next_available:
		icon.modulate = Color(1, 1, 1, 1)
		card.modulate = Color(1, 1, 1, 1)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(_on_card_clicked.bind(item))
	else:
		icon.modulate = Color(0.3, 0.25, 0.2, 0.8)
		card.modulate = Color(0.7, 0.7, 0.7, 0.85)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.mouse_default_cursor_shape = Control.CURSOR_ARROW

	return card

func _format_hours_short(hours: float) -> String:
	if hours < 1.0:
		return "%dm" % int(roundf(hours * 60.0))
	if is_equal_approx(hours, roundf(hours)):
		return "%dh" % int(roundf(hours))
	return "%.1fh" % hours

func _create_maneki_upgrade_bar(item: ItemData, target_level: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 74)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE

	var req_lvl: int = int(item.get_meta("req_level", 1))
	var level_unlocked: bool = StoryManager.player_level >= req_lvl
	var owned: bool = target_level <= StoryManager.maneki_upgrade_level
	var is_queued: bool = item in _queued_upgrades
	var is_next_available: bool = (not owned) and level_unlocked and (target_level == _get_effective_maneki_level() + 1)

	var bg_col := UIStyle.COLOR_CARD_BG
	if owned:
		bg_col = UIStyle.COLOR_CARD_OWNED_BG
	elif is_queued:
		bg_col = Color(0.14, 0.28, 0.16, 0.95)
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
	icon_frame.add_theme_stylebox_override("panel", UIStyle.create_flat_stylebox(Color(0.28, 0.20, 0.08, 0.60), 6, 4, 4))
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

	var c_hrs: float = float(item.get_meta("customer_hours", 3.0))
	var v_hrs: float = float(item.get_meta("visit_hours", 1.0))
	var sub_lbl := Label.new()
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.text = "Customer %s / Visit %s  •  More daily foot traffic" % [_format_hours_short(c_hrs), _format_hours_short(v_hrs)]
	sub_lbl.add_theme_color_override("font_color", Color("#FFECC4"))
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
	elif is_queued:
		status_lbl.text = "QUEUED ✓"
		status_lbl.add_theme_color_override("font_color", Color("#8BF08E"))
	elif is_next_available:
		status_lbl.text = "AVAILABLE"
		status_lbl.add_theme_color_override("font_color", Color.WHITE)
	elif not level_unlocked:
		status_lbl.text = "REQUIRES LV. %d" % req_lvl
		status_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.9))
	else:
		status_lbl.text = "BUY LV.1 FIRST"
		status_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55, 0.95))
	right_vbox.add_child(status_lbl)

	if owned:
		icon.modulate = Color(1, 1, 1, 0.5)
		card.modulate = Color(0.85, 1.0, 0.85, 0.7)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif is_queued or is_next_available:
		icon.modulate = Color(1, 1, 1, 1)
		card.modulate = Color(1, 1, 1, 1)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(_on_card_clicked.bind(item))
	else:
		icon.modulate = Color(0.3, 0.25, 0.2, 0.8)
		card.modulate = Color(0.7, 0.7, 0.7, 0.85)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.mouse_default_cursor_shape = Control.CURSOR_ARROW

	return card

func _create_radio_upgrade_bar(item: ItemData, target_level: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 74)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE

	var req_lvl: int = int(item.get_meta("req_level", 1))
	var level_unlocked: bool = StoryManager.player_level >= req_lvl
	var owned: bool = target_level <= StoryManager.radio_upgrade_level
	var is_queued: bool = item in _queued_upgrades
	var is_next_available: bool = (not owned) and level_unlocked and (target_level == _get_effective_radio_level() + 1)

	var bg_col := UIStyle.COLOR_CARD_BG
	if owned:
		bg_col = UIStyle.COLOR_CARD_OWNED_BG
	elif is_queued:
		bg_col = Color(0.14, 0.28, 0.16, 0.95)
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
	icon_frame.add_theme_stylebox_override("panel", UIStyle.create_flat_stylebox(Color(0.22, 0.16, 0.08, 0.55), 6, 4, 4))
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

	var reveals: int = int(item.get_meta("reveals", target_level))
	var sub_lbl := Label.new()
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.text = "Reveals ALL Expected Regulars daily" if target_level >= 3 else "Reveals %d Expected Regular(s) daily" % reveals
	sub_lbl.add_theme_color_override("font_color", Color("#FFECC4"))
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
	elif is_queued:
		status_lbl.text = "QUEUED ✓"
		status_lbl.add_theme_color_override("font_color", Color("#8BF08E"))
	elif is_next_available:
		status_lbl.text = "AVAILABLE"
		status_lbl.add_theme_color_override("font_color", Color.WHITE)
	elif not level_unlocked:
		status_lbl.text = "REQUIRES LV. %d" % req_lvl
		status_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.9))
	else:
		status_lbl.text = "UPGRADE PREV FIRST"
		status_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55, 0.95))
	right_vbox.add_child(status_lbl)

	if owned:
		icon.modulate = Color(1, 1, 1, 0.5)
		card.modulate = Color(0.85, 1.0, 0.85, 0.7)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif is_queued or is_next_available:
		icon.modulate = Color(1, 1, 1, 1)
		card.modulate = Color(1, 1, 1, 1)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(_on_card_clicked.bind(item))
	else:
		icon.modulate = Color(0.3, 0.25, 0.2, 0.8)
		card.modulate = Color(0.7, 0.7, 0.7, 0.85)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.mouse_default_cursor_shape = Control.CURSOR_ARROW

	return card

func _create_mario_deals_upgrade_bar(item: ItemData) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 74)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE

	var req_lvl: int = int(item.get_meta("req_level", 1))
	var level_unlocked: bool = StoryManager.player_level >= req_lvl
	var owned: bool = StoryManager.has_mario_deals
	var is_queued: bool = item in _queued_upgrades

	var bg_col := UIStyle.COLOR_CARD_BG
	if owned:
		bg_col = UIStyle.COLOR_CARD_OWNED_BG
	elif is_queued:
		bg_col = Color(0.14, 0.28, 0.16, 0.95)
	elif not level_unlocked:
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
	icon_frame.add_theme_stylebox_override("panel", UIStyle.create_flat_stylebox(Color(0.22, 0.16, 0.08, 0.55), 6, 4, 4))
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

	var sub_lbl := Label.new()
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.text = "2–3 daily wholesale items at 20% OFF"
	sub_lbl.add_theme_color_override("font_color", Color("#FFECC4"))
	info_vbox.add_child(sub_lbl)

	var right_vbox := VBoxContainer.new()
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(right_vbox)

	var price_lbl := Label.new()
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.add_theme_font_size_override("font_size", 17)
	price_lbl.text = "₱%.2f" % item.price
	price_lbl.add_theme_color_override("font_color", UIStyle.COLOR_GOLD_TEXT)
	right_vbox.add_child(price_lbl)

	var status_lbl := Label.new()
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_lbl.add_theme_font_size_override("font_size", 12)
	if owned:
		status_lbl.text = "OWNED"
		status_lbl.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75, 1.0))
	elif is_queued:
		status_lbl.text = "QUEUED ✓"
		status_lbl.add_theme_color_override("font_color", Color("#8BF08E"))
	elif level_unlocked:
		status_lbl.text = "AVAILABLE"
		status_lbl.add_theme_color_override("font_color", Color.WHITE)
	else:
		status_lbl.text = "REQUIRES LV. %d" % req_lvl
		status_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.9))
	right_vbox.add_child(status_lbl)

	if owned:
		icon.modulate = Color(1, 1, 1, 0.5)
		card.modulate = Color(0.85, 1.0, 0.85, 0.7)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif is_queued or level_unlocked:
		icon.modulate = Color(1, 1, 1, 1)
		card.modulate = Color(1, 1, 1, 1)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(_on_card_clicked.bind(item))
	else:
		icon.modulate = Color(0.3, 0.25, 0.2, 0.8)
		card.modulate = Color(0.7, 0.7, 0.7, 0.85)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.mouse_default_cursor_shape = Control.CURSOR_ARROW

	return card

func _on_card_clicked(event: InputEvent, item: ItemData) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		AudioManager.play_sfx("interact")
		_toggle_queue_upgrade.call_deferred(item)

func _toggle_queue_upgrade(item: ItemData) -> void:
	if item in _queued_upgrades:
		# Remove item and cascade-remove any higher dependent tier/fridge level in the queue
		_queued_upgrades.erase(item)
		if item.get_meta("is_upgrade", false):
			var removed_tier: int = int(item.get_meta("target_tier", 1))
			_queued_upgrades = _queued_upgrades.filter(func(q: ItemData) -> bool:
				return not q.get_meta("is_upgrade", false) or int(q.get_meta("target_tier", 1)) < removed_tier
			)
		elif item.get_meta("is_fridge_upgrade", false):
			var removed_lvl: int = int(item.get_meta("fridge_level", 1))
			_queued_upgrades = _queued_upgrades.filter(func(q: ItemData) -> bool:
				return not q.get_meta("is_fridge_upgrade", false) or int(q.get_meta("fridge_level", 1)) < removed_lvl
			)
		elif item.get_meta("is_cat_upgrade", false):
			var removed_cat: int = int(item.get_meta("cat_level", 1))
			_queued_upgrades = _queued_upgrades.filter(func(q: ItemData) -> bool:
				return not q.get_meta("is_cat_upgrade", false) or int(q.get_meta("cat_level", 1)) < removed_cat
			)
		elif item.get_meta("is_maneki_upgrade", false):
			var removed_maneki: int = int(item.get_meta("maneki_level", 1))
			_queued_upgrades = _queued_upgrades.filter(func(q: ItemData) -> bool:
				return not q.get_meta("is_maneki_upgrade", false) or int(q.get_meta("maneki_level", 1)) < removed_maneki
			)
		elif item.get_meta("is_radio_upgrade", false):
			var removed_radio: int = int(item.get_meta("radio_level", 1))
			_queued_upgrades = _queued_upgrades.filter(func(q: ItemData) -> bool:
				return not q.get_meta("is_radio_upgrade", false) or int(q.get_meta("radio_level", 1)) < removed_radio
			)
	else:
		_queued_upgrades.append(item)

	_populate_upgrades()
	_focus_upgrade(item)

func _focus_upgrade(item: ItemData) -> void:
	_focused_upgrade = item

	# Update selection border highlight (gold for focused, green-gold for queued)
	for u_item in _card_map.keys():
		var c: PanelContainer = _card_map[u_item]
		if not is_instance_valid(c):
			continue
		var s := c.get_theme_stylebox("panel") as StyleBoxFlat
		if s:
			var is_focused: bool = (u_item == item)
			var is_queued: bool = (u_item in _queued_upgrades)
			if is_focused:
				s.border_color = UIStyle.COLOR_CARD_SELECTED
				s.set_border_width_all(3)
			elif is_queued:
				s.border_color = Color("#8BF08E")
				s.set_border_width_all(3)
			else:
				s.border_color = UIStyle.COLOR_CARD_BORDER
				s.set_border_width_all(2)

	_update_detail_panel(item)
	_refresh_confirm_summary()

func _refresh_confirm_summary() -> void:
	var total := _get_queued_total_cost()
	if total_amount_label:
		if _queued_upgrades.size() > 1:
			total_amount_label.text = "₱%.2f (%d)" % [total, _queued_upgrades.size()]
		else:
			total_amount_label.text = "₱%.2f" % total

	var can_confirm := (not _queued_upgrades.is_empty()) and (_get_money() >= total)
	if confirm_btn:
		confirm_btn.disabled = not can_confirm
		confirm_btn.text = "Order (%d)" % _queued_upgrades.size() if _queued_upgrades.size() > 1 else "Confirm"
		if can_confirm:
			UIStyle.style_button(confirm_btn, UIStyle.COLOR_CONFIRM, Color.WHITE, 18.0)
		else:
			UIStyle.style_button(confirm_btn, UIStyle.COLOR_TAB_LOCKED, UIStyle.COLOR_TAB_LOCKED_FONT, 18.0)

func _update_detail_panel(item: ItemData) -> void:
	if item.get_meta("is_maneki_upgrade", false):
		var m_lvl: int = int(item.get_meta("maneki_level", 1))
		var prev_s: Dictionary = StoryManager.MANEKI_UPGRADE_SPECS[m_lvl - 1]
		var next_s: Dictionary = StoryManager.MANEKI_UPGRADE_SPECS[m_lvl]
		var prev_c := float(prev_s["customer_hours"])
		var next_c := float(next_s["customer_hours"])
		var prev_v := float(prev_s["visit_hours"])
		var next_v := float(next_s["visit_hours"])
		if detail_icon:
			detail_icon.texture = item.texture
		if detail_name:
			detail_name.text = item.item_name
		if detail_subtitle:
			detail_subtitle.text = str(item.get_meta("upgrade_desc", ""))
		for child in unlocks_list.get_children():
			unlocks_list.remove_child(child)
			child.queue_free()
		for line in [
			"• Customer Time Limit: %s → %s (Half-skip: %s)" % [_format_hours_short(prev_c), _format_hours_short(next_c), _format_hours_short(next_c * 0.5)],
			"• Visit Time Limit: %s → %s (Half-skip: %s)" % [_format_hours_short(prev_v), _format_hours_short(next_v), _format_hours_short(next_v * 0.5)],
			"• Brings in noticeably more customers every day"
		]:
			var stat_lbl := Label.new()
			stat_lbl.text = line
			stat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stat_lbl.add_theme_font_size_override("font_size", 15)
			stat_lbl.add_theme_color_override("font_color", Color("#FFECC4"))
			unlocks_list.add_child(stat_lbl)
		return

	if item.get_meta("is_radio_upgrade", false):
		var r_lvl: int = int(item.get_meta("radio_level", 1))
		var prev_rev: int = int(StoryManager.RADIO_UPGRADE_SPECS[r_lvl - 1]["reveals"])
		var next_rev: int = int(StoryManager.RADIO_UPGRADE_SPECS[r_lvl]["reveals"])
		if detail_icon:
			detail_icon.texture = item.texture
		if detail_name:
			detail_name.text = item.item_name
		if detail_subtitle:
			detail_subtitle.text = str(item.get_meta("upgrade_desc", ""))
		for child in unlocks_list.get_children():
			unlocks_list.remove_child(child)
			child.queue_free()
		var next_txt := "All (3–4)" if r_lvl >= 3 else str(next_rev)
		for line in [
			"• Expected Regulars Revealed: %d → %s daily" % [prev_rev, next_txt],
			"• Shows neighbor portraits & favorite cravings in Restock Menu",
			"• Helps you stock the exact categories neighbors crave today"
		]:
			var stat_lbl := Label.new()
			stat_lbl.text = line
			stat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stat_lbl.add_theme_font_size_override("font_size", 15)
			stat_lbl.add_theme_color_override("font_color", Color("#FFECC4"))
			unlocks_list.add_child(stat_lbl)
		return

	if item.get_meta("is_mario_deals_upgrade", false):
		if detail_icon:
			detail_icon.texture = item.texture
		if detail_name:
			detail_name.text = item.item_name
		if detail_subtitle:
			detail_subtitle.text = str(item.get_meta("upgrade_desc", ""))
		for child in unlocks_list.get_children():
			unlocks_list.remove_child(child)
			child.queue_free()
		for line in [
			"• Unlocks Uncle Mario's Daily Sulit Deals",
			"• 2–3 random unlocked items are 20% OFF wholesale every morning",
			"• Stacks with Reyna Mayari restock discounts"
		]:
			var stat_lbl := Label.new()
			stat_lbl.text = line
			stat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stat_lbl.add_theme_font_size_override("font_size", 15)
			stat_lbl.add_theme_color_override("font_color", Color("#FFECC4"))
			unlocks_list.add_child(stat_lbl)
		return

	if item.get_meta("is_trash_upgrade", false):
		if detail_icon:
			detail_icon.texture = item.texture
		if detail_name:
			detail_name.text = item.item_name
		if detail_subtitle:
			detail_subtitle.text = str(item.get_meta("upgrade_desc", ""))

		for child in unlocks_list.get_children():
			unlocks_list.remove_child(child)
			child.queue_free()

		for line in [
			"• Places a clickable trash bin in the corner of your store",
			"• Drop any extra or unwanted item into it to clear shelf space",
			"• Delivered immediately by Uncle Mario"
		]:
			var stat_lbl := Label.new()
			stat_lbl.text = line
			stat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stat_lbl.add_theme_font_size_override("font_size", 15)
			stat_lbl.add_theme_color_override("font_color", Color("#FFECC4"))
			unlocks_list.add_child(stat_lbl)
		return

	if item.get_meta("is_cat_upgrade", false):
		var c_lvl: int = int(item.get_meta("cat_level", 1))
		var prev_slots: int = int(StoryManager.CAT_UPGRADE_SPECS[c_lvl - 1]["slots"])
		var next_slots: int = int(StoryManager.CAT_UPGRADE_SPECS[c_lvl]["slots"])
		if detail_icon:
			detail_icon.texture = item.texture
		if detail_name:
			detail_name.text = item.item_name
		if detail_subtitle:
			detail_subtitle.text = str(item.get_meta("upgrade_desc", ""))

		for child in unlocks_list.get_children():
			unlocks_list.remove_child(child)
			child.queue_free()

		var lines: Array[String] = [
			"• Simultaneous Counter Slots: %d → %d neighbors" % [prev_slots, next_slots],
			"• Pettable store cat lounges on the counter top shelf",
			"• Click your store cat anytime for lucky meows"
		] if c_lvl == 1 else [
			"• Simultaneous Counter Slots: %d → %d neighbors" % [prev_slots, next_slots],
			"• Keeps Mingming well-fed and extra welcoming",
			"• Attracts lively 3-neighbor rushes to your counter"
		]
		for line in lines:
			var stat_lbl := Label.new()
			stat_lbl.text = line
			stat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stat_lbl.add_theme_font_size_override("font_size", 15)
			stat_lbl.add_theme_color_override("font_color", Color("#FFECC4"))
			unlocks_list.add_child(stat_lbl)
		return

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
			unlocks_list.remove_child(child)
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
	if _queued_upgrades.is_empty():
		return
	if confirm_btn:
		confirm_btn.disabled = true

	var total_cost := _get_queued_total_cost()
	if _get_money() < total_cost:
		EventBus.insufficient_funds.emit()
		if confirm_btn:
			confirm_btn.disabled = false
		return

	# Validate tier-package upgrades through RestockOrder (shelf capacity & tier sequence)
	var order := RestockOrder.new()
	var remaining_budget := _get_money()
	for q_item in _queued_upgrades:
		if q_item.get_meta("is_fridge_upgrade", false) or q_item.get_meta("is_cat_upgrade", false) or q_item.get_meta("is_trash_upgrade", false) or q_item.get_meta("is_maneki_upgrade", false) or q_item.get_meta("is_radio_upgrade", false) or q_item.get_meta("is_mario_deals_upgrade", false):
			remaining_budget -= q_item.price
			continue
		var check := order.can_add(q_item, remaining_budget)
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
		order.add_item(q_item)

	AudioManager.play_sfx("purchase")

	var gm_nodes = get_tree().get_nodes_in_group("game_manager")
	if gm_nodes.size() > 0 and gm_nodes[0].has_method("deduct_money"):
		gm_nodes[0].deduct_money(total_cost)

	var delivery_items: Dictionary = {}
	for q_item in _queued_upgrades:
		delivery_items[q_item] = 1

	var first_item: ItemData = _queued_upgrades[0]
	_queued_upgrades.clear()
	upgrade_purchase_confirmed.emit(total_cost, first_item)
	_close_upgrade_screen()
	MarioManager.start_delivery(delivery_items)

func _get_money() -> float:
	var gm_nodes = get_tree().get_nodes_in_group("game_manager")
	return gm_nodes[0].money if gm_nodes.size() > 0 else 0.0
