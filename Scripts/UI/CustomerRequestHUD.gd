extends CanvasLayer

const ITEM_HEIGHT := 92.0
const ITEM_MIN_WIDTH := 40.0
const ITEM_MAX_WIDTH := 96.0
const RIDDLE_SIZE := 74.0
const PORTRAIT_RING_SIZE := 76
const PORTRAIT_IMG_SIZE := 92

const PORTRAIT_MAP := {
	"brahim": preload("res://Assets/characters/portraits/Brahim Face.png"),
	"buboy": preload("res://Assets/characters/portraits/Buboy Face.png"),
	"danilo": preload("res://Assets/characters/portraits/Danilo Face.png"),
	"kuyakap": preload("res://Assets/characters/portraits/Kuya_Kap Face.png"),
	"manangana": preload("res://Assets/characters/portraits/ManangAna Face.png"),
	"reynamayari": preload("res://Assets/characters/portraits/ReynaMayari Face.png"),
	"rodel": preload("res://Assets/characters/portraits/Rodel Face.png"),
	"rosalyn": preload("res://Assets/characters/portraits/Rosalyn Face.png"),
	"sarimanok": preload("res://Assets/characters/portraits/Sarimanok Face.png"),
	"tk": preload("res://Assets/characters/portraits/TK Face.png"),
	"unclemario": preload("res://Assets/characters/portraits/UncleMario Face.png"),
}

@onready var panel_container: PanelContainer = %PanelContainer
@onready var rows_container: VBoxContainer = %RowsContainer

var _rows: Dictionary = {} # customer_name -> { "row": Control, "items_box": HBoxContainer, "items": Array[ItemData], "is_riddle": bool }
var _trimmed_tex_cache: Dictionary = {} # ItemData -> Texture2D
var is_visible_hud: bool = false

func _ready() -> void:
	panel_container.modulate.a = 0.0

	EventBus.customer_order_updated.connect(_on_order_updated)
	EventBus.customer_order_cleared.connect(_on_order_cleared)
	EventBus.tier_advanced.connect(_on_tier_advanced)

func _process(_delta: float) -> void:
	# Hide order previews whenever any modal menu (Restock, Upgrade, Ledger, Pause, Notebook) unlocks the cursor
	var in_gameplay := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if visible != in_gameplay:
		visible = in_gameplay

func _on_tier_advanced(_new_tier: int, _source: String) -> void:
	if not is_visible_hud:
		return
	for customer_name in _rows.keys():
		var entry: Dictionary = _rows[customer_name]
		_on_order_updated(customer_name, entry["items"], entry["is_riddle"])

func _on_order_updated(customer_name: String, items: Array[ItemData], is_riddle: bool) -> void:
	var key := customer_name.strip_edges()
	if key == "":
		key = "Customer"

	if items.is_empty():
		_remove_row(key)
		return

	_show_hud()

	var entry: Dictionary = _rows.get(key, {})
	if entry.is_empty() or not is_instance_valid(entry.get("row")):
		entry = _create_row(key)
		_rows[key] = entry

	entry["items"] = items.duplicate()
	entry["is_riddle"] = is_riddle

	var items_box: HBoxContainer = entry["items_box"]
	var checklist: Array = items.duplicate()
	var active_children: Array = []

	for child in items_box.get_children():
		if not child.get_meta("is_popping", false):
			active_children.append(child)

	# Match right-to-left so leftmost duplicate pops first
	for i in range(active_children.size() - 1, -1, -1):
		var child: Control = active_children[i]
		var bound_item = child.get_meta("item_data", null)
		var match_idx := checklist.find(bound_item)
		if match_idx != -1:
			_update_icon_visuals(child, bound_item, is_riddle)
			checklist.remove_at(match_idx)
		else:
			_pop_and_remove_item(child)

	for item in checklist:
		_add_item_icon(items_box, item, is_riddle)

func _get_portrait_texture(customer_name: String) -> Texture2D:
	var norm := customer_name.to_lower().replace(".", "").replace(" ", "").replace("_", "").replace("-", "")
	if PORTRAIT_MAP.has(norm):
		return PORTRAIT_MAP[norm]
	return null

func _make_circle_style(bg: Color, border: Color, border_w: int, radius: int = 999, shadow_sz: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	if shadow_sz > 0:
		s.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
		s.shadow_size = shadow_sz
		s.shadow_offset = Vector2(0, 4)
	return s

func _create_row(customer_name: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", -10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 1. Left Side: Floating items resting along a sleek bottom shelf-line bar
	var items_margin := MarginContainer.new()
	items_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items_margin.add_theme_constant_override("margin_left", 16)
	items_margin.add_theme_constant_override("margin_right", 22)
	items_margin.add_theme_constant_override("margin_top", 2)
	items_margin.add_theme_constant_override("margin_bottom", 10)

	# Full-rect background layer inside PanelContainer so bottom_bar keeps its bottom-only anchors
	var bar_layer := Control.new()
	bar_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bottom_bar := Panel.new()
	bottom_bar.anchor_left = 0.0
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_top = -16.0
	bottom_bar.offset_bottom = -2.0
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.07, 0.06, 0.05, 0.80)
	bar_style.border_color = Color(0.88, 0.72, 0.42, 0.48)
	bar_style.border_width_top = 2
	bar_style.border_width_bottom = 1
	bar_style.border_width_left = 1
	bar_style.border_width_right = 1
	bar_style.set_corner_radius_all(999)
	bar_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	bar_style.shadow_size = 6
	bar_style.shadow_offset = Vector2(0, 3)
	bottom_bar.add_theme_stylebox_override("panel", bar_style)
	bar_layer.add_child(bottom_bar)

	var shelf_container := PanelContainer.new()
	shelf_container.size_flags_vertical = Control.SIZE_SHRINK_END
	shelf_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shelf_container.z_index = 1
	shelf_container.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	shelf_container.add_child(bar_layer)
	shelf_container.add_child(items_margin)
	row.add_child(shelf_container)

	var items_box := HBoxContainer.new()
	items_box.alignment = BoxContainer.ALIGNMENT_END
	items_box.add_theme_constant_override("separation", 14)
	items_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items_margin.add_child(items_box)

	# 2. Right Side: Compact Character Portrait Medallion (overlapping onto the right end of the bar)
	var badge_holder := Control.new()
	badge_holder.custom_minimum_size = Vector2(PORTRAIT_RING_SIZE, PORTRAIT_RING_SIZE)
	badge_holder.size_flags_vertical = Control.SIZE_SHRINK_END
	badge_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_holder.z_index = 3
	row.add_child(badge_holder)

	var ring_panel := Panel.new()
	ring_panel.custom_minimum_size = Vector2(PORTRAIT_RING_SIZE, PORTRAIT_RING_SIZE)
	ring_panel.size = Vector2(PORTRAIT_RING_SIZE, PORTRAIT_RING_SIZE)
	ring_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_style := _make_circle_style(
		Color(0.13, 0.10, 0.08, 0.96),
		Color(0.88, 0.72, 0.42, 0.85),
		2,
		999,
		10
	)
	ring_panel.add_theme_stylebox_override("panel", ring_style)
	badge_holder.add_child(ring_panel)

	var inner_ring := Panel.new()
	inner_ring.size = Vector2(PORTRAIT_RING_SIZE - 8, PORTRAIT_RING_SIZE - 8)
	inner_ring.position = Vector2(4, 4)
	inner_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_ring.add_theme_stylebox_override("panel", _make_circle_style(
		Color(0.20, 0.15, 0.11, 0.65),
		Color(1.0, 0.90, 0.68, 0.18),
		1,
		999,
		0
	))
	badge_holder.add_child(inner_ring)

	var portrait_tex := _get_portrait_texture(customer_name)
	if portrait_tex != null:
		var portrait_rect := TextureRect.new()
		portrait_rect.texture = portrait_tex
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_rect.size = Vector2(PORTRAIT_IMG_SIZE, PORTRAIT_IMG_SIZE)
		var offset := (PORTRAIT_RING_SIZE - PORTRAIT_IMG_SIZE) * 0.5
		portrait_rect.position = Vector2(offset, offset - 3.0)
		portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_holder.add_child(portrait_rect)
	else:
		var name_lbl := Label.new()
		name_lbl.text = customer_name.left(2).to_upper()
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.size = Vector2(PORTRAIT_RING_SIZE, PORTRAIT_RING_SIZE)
		name_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.add_theme_color_override("font_color", UIStyle.COLOR_GOLD_TEXT)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_holder.add_child(name_lbl)

	rows_container.add_child(row)

	# Springy entrance animation per customer pill
	row.modulate.a = 0.0
	badge_holder.scale = Vector2(0.6, 0.6)
	badge_holder.pivot_offset = Vector2(PORTRAIT_RING_SIZE * 0.5, PORTRAIT_RING_SIZE * 0.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(row, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(badge_holder, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	return {
		"row": row,
		"items_box": items_box,
		"items": [],
		"is_riddle": false
	}

func _remove_row(customer_name: String) -> void:
	if not _rows.has(customer_name):
		return
	var entry: Dictionary = _rows[customer_name]
	_rows.erase(customer_name)

	var row: Control = entry.get("row") as Control
	if is_instance_valid(row):
		var tw := create_tween()
		tw.tween_property(row, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func():
			if is_instance_valid(row):
				row.queue_free()
		)

	if _rows.is_empty():
		_hide_hud()

func _get_trimmed_item_texture(item: ItemData) -> Texture2D:
	if not item or not item.texture:
		return null
	if _trimmed_tex_cache.has(item):
		return _trimmed_tex_cache[item]
	var used_rect: Rect2i = item.get_used_rect()
	if used_rect.has_area():
		var atlas := AtlasTexture.new()
		atlas.atlas = item.texture
		atlas.region = Rect2(used_rect)
		_trimmed_tex_cache[item] = atlas
		return atlas
	_trimmed_tex_cache[item] = item.texture
	return item.texture

func _get_slot_size_for_item(item: ItemData, is_riddle: bool) -> Vector2:
	if is_riddle:
		return Vector2(RIDDLE_SIZE + 4.0, ITEM_HEIGHT)
	var aspect := item.get_visual_aspect() if item else 1.0
	var width := clampf(ITEM_HEIGHT * aspect, ITEM_MIN_WIDTH, ITEM_MAX_WIDTH)
	return Vector2(width, ITEM_HEIGHT)

func _update_icon_visuals(rect_container: Control, item: ItemData, is_riddle: bool) -> void:
	var icon := rect_container.get_node_or_null("ItemIcon") as TextureRect
	var riddle_badge := rect_container.get_node_or_null("RiddleBadge") as Control
	if not icon:
		return

	var slot_size := _get_slot_size_for_item(item, is_riddle)
	rect_container.custom_minimum_size = slot_size
	icon.size = slot_size
	icon.pivot_offset = slot_size * 0.5
	icon.position = Vector2.ZERO

	if is_riddle:
		icon.hide()
		if not riddle_badge:
			riddle_badge = Panel.new()
			riddle_badge.name = "RiddleBadge"
			riddle_badge.size = Vector2(RIDDLE_SIZE, RIDDLE_SIZE)
			riddle_badge.position = Vector2((slot_size.x - RIDDLE_SIZE) * 0.5, (slot_size.y - RIDDLE_SIZE) * 0.5)
			riddle_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			riddle_badge.add_theme_stylebox_override("panel", _make_circle_style(
				Color(0.16, 0.13, 0.10, 0.95),
				Color(0.92, 0.76, 0.44, 0.65),
				2,
				999,
				0
			))
			var label := Label.new()
			label.text = "?"
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.size = riddle_badge.size
			label.add_theme_font_override("font", UIStyle.FONT_INDER)
			label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62, 1.0))
			label.add_theme_font_size_override("font_size", 44)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			riddle_badge.add_child(label)
			rect_container.add_child(riddle_badge)
		riddle_badge.show()
	else:
		if riddle_badge:
			riddle_badge.hide()
		icon.show()
		icon.texture = _get_trimmed_item_texture(item)
		icon.modulate = Color(0.2, 0.2, 0.2, 1) if item.tier > StoryManager.current_tier else Color.WHITE

func _add_item_icon(items_box: HBoxContainer, item: ItemData, is_riddle: bool) -> void:
	var slot_size := _get_slot_size_for_item(item, is_riddle)
	var rect_container := Control.new()
	rect_container.custom_minimum_size = slot_size
	rect_container.clip_contents = false
	rect_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := TextureRect.new()
	icon.name = "ItemIcon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = slot_size
	icon.pivot_offset = slot_size * 0.5
	icon.position = Vector2.ZERO
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	rect_container.add_child(icon)
	_update_icon_visuals(rect_container, item, is_riddle)

	items_box.add_child(rect_container)

	rect_container.set_meta("item_data", item)
	rect_container.set_meta("is_popping", false)

	icon.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_apply_sway(icon)

func _pop_and_remove_item(child: Control) -> void:
	if child.get_child_count() == 0:
		child.queue_free()
		return

	child.set_meta("is_popping", true)
	var icon := child.get_node_or_null("ItemIcon") as Control
	if not icon:
		icon = child.get_child(0) as Control

	if icon and icon.get_meta("sway_tween", null):
		var sw_tw = icon.get_meta("sway_tween")
		sw_tw.kill()

	var tw := create_tween().set_parallel(true)
	if icon:
		tw.tween_property(icon, "scale", Vector2(1.65, 1.65), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(child, "modulate:a", 0.0, 0.18)
	tw.tween_property(child, "custom_minimum_size:x", 0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tw.chain().tween_callback(func():
		if is_instance_valid(child):
			child.queue_free()
	)

func _on_order_cleared(customer_name: String = "") -> void:
	if customer_name == "":
		_rows.clear()
		_hide_hud()
	else:
		_remove_row(customer_name)

func _show_hud() -> void:
	if is_visible_hud:
		return
	is_visible_hud = true
	panel_container.position.x = 180
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel_container, "position:x", 0, 0.35).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel_container, "modulate:a", 1.0, 0.25)

func _hide_hud() -> void:
	if not is_visible_hud:
		return
	is_visible_hud = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel_container, "position:x", 180, 0.28).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(panel_container, "modulate:a", 0.0, 0.28)

	tw.chain().tween_callback(func():
		if not is_visible_hud:
			for c in rows_container.get_children():
				if is_instance_valid(c):
					c.queue_free()
	)

func _apply_sway(icon: Control) -> void:
	var tw := icon.create_tween().set_loops()
	icon.set_meta("sway_tween", tw)
	var duration := randf_range(2.5, 4.5)
	var angle := randf_range(3.0, 6.0)

	icon.rotation_degrees = randf_range(-angle, angle)
	tw.tween_property(icon, "rotation_degrees", angle, duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(icon, "rotation_degrees", -angle, duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
