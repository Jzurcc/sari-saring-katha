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

var _rows: Dictionary = {} # customer_name -> { "row": Control, ... }
var _trimmed_tex_cache: Dictionary = {} # ItemData -> Texture2D
var _hovered_row_key: String = ""
var _hovered_is_dragging: bool = false
var is_visible_hud: bool = false

func _ready() -> void:
	panel_container.modulate.a = 0.0

	EventBus.customer_order_updated.connect(_on_order_updated)
	EventBus.customer_order_cleared.connect(_on_order_cleared)
	EventBus.transaction_completed.connect(_on_transaction_completed)
	EventBus.tier_advanced.connect(_on_tier_advanced)
	EventBus.customer_hover_changed.connect(_on_customer_hover_changed)

func _on_transaction_completed(_item: ItemData, was_correct: bool, _wants_debt: bool, customer_path: String) -> void:
	if was_correct or customer_path == "":
		return
	var matched_key := _find_row_key_by_path(customer_path)
	if matched_key != "" and _rows.has(matched_key):
		_pulse_row_rejected(_rows[matched_key], false)

func _find_row_key_by_path(customer_path: String) -> String:
	var file_id := customer_path.get_file().get_basename().to_lower().replace("_", "").replace(" ", "")
	for key in _rows.keys():
		var norm_key := str(key).to_lower().replace(".", "").replace(" ", "").replace("_", "").replace("-", "")
		if norm_key == file_id:
			return str(key)
	return ""

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
		# All items fulfilled! Pop remaining icons with celebration burst, then slide the row out
		_remove_row(key, true)
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

	var fulfilled_any := false
	# Match right-to-left so leftmost duplicate pops first
	for i in range(active_children.size() - 1, -1, -1):
		var child: Control = active_children[i]
		var bound_item = child.get_meta("item_data", null)
		var match_idx := checklist.find(bound_item)
		if match_idx != -1:
			_update_icon_visuals(child, bound_item, is_riddle)
			checklist.remove_at(match_idx)
		else:
			fulfilled_any = true
			_pop_and_remove_item(child)

	if fulfilled_any:
		_pulse_medallion_happy(entry)

	var stagger_idx := 0
	for item in checklist:
		_add_item_icon(items_box, item, is_riddle, float(stagger_idx) * 0.075)
		stagger_idx += 1

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
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 1. Left Side: Floating items resting along a sleek bottom shelf-line bar
	var items_margin := MarginContainer.new()
	items_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items_margin.add_theme_constant_override("margin_left", 16)
	items_margin.add_theme_constant_override("margin_right", 16)
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
		portrait_rect.pivot_offset = Vector2(PORTRAIT_IMG_SIZE * 0.5, PORTRAIT_IMG_SIZE * 0.65)
		var img_offset := (PORTRAIT_RING_SIZE - PORTRAIT_IMG_SIZE) * 0.5
		portrait_rect.position = Vector2(img_offset, img_offset - 3.0)
		portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_holder.add_child(portrait_rect)
		_apply_portrait_bob(portrait_rect)
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

	# Juicy entrance: portrait pops & tilts in, bottom shelf-bar unfurls, row glides in from right
	row.modulate.a = 0.0
	badge_holder.pivot_offset = Vector2(PORTRAIT_RING_SIZE * 0.5, PORTRAIT_RING_SIZE * 0.5)
	badge_holder.scale = Vector2(0.35, 0.35)
	badge_holder.rotation_degrees = -12.0
	shelf_container.modulate.a = 0.0

	var enter_tw := create_tween().set_parallel(true)
	enter_tw.tween_property(row, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	enter_tw.tween_property(badge_holder, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter_tw.tween_property(badge_holder, "rotation_degrees", 0.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter_tw.tween_property(shelf_container, "modulate:a", 1.0, 0.26).set_delay(0.05).set_trans(Tween.TRANS_SINE)

	# Animate bottom bar unfurling horizontally once layout computes its width
	bottom_bar.scale.x = 0.05
	call_deferred("_unfurl_bottom_bar", bottom_bar)

	var entry := {
		"row": row,
		"items_box": items_box,
		"shelf_container": shelf_container,
		"bottom_bar": bottom_bar,
		"bar_style": bar_style,
		"badge_holder": badge_holder,
		"ring_panel": ring_panel,
		"ring_style": ring_style,
		"hover_tween": null,
		"entered": false,
		"items": [],
		"is_riddle": false
	}
	enter_tw.chain().tween_callback(func():
		entry["entered"] = true
		_refresh_row_hover_visuals()
	)
	return entry

func _unfurl_bottom_bar(bar: Control) -> void:
	if not is_instance_valid(bar):
		return
	bar.pivot_offset = Vector2(bar.size.x, bar.size.y * 0.5)
	var tw := bar.create_tween()
	tw.tween_property(bar, "scale:x", 1.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _pulse_medallion_happy(entry: Dictionary) -> void:
	var badge := entry.get("badge_holder") as Control
	var ring := entry.get("ring_panel") as Panel
	if is_instance_valid(badge):
		badge.pivot_offset = Vector2(PORTRAIT_RING_SIZE * 0.5, PORTRAIT_RING_SIZE * 0.5)
		var tw := badge.create_tween()
		tw.tween_property(badge, "scale", Vector2(1.18, 0.86), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(badge, "scale", Vector2(0.95, 1.08), 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(badge, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if is_instance_valid(ring):
		var glow_tw := ring.create_tween()
		glow_tw.tween_property(ring, "modulate", Color(0.82, 1.35, 0.88, 1.0), 0.10).set_trans(Tween.TRANS_SINE)
		glow_tw.tween_property(ring, "modulate", Color.WHITE, 0.28).set_trans(Tween.TRANS_SINE)

func _pulse_row_rejected(entry: Dictionary, _spawn_cross: bool = false) -> void:
	var row := entry.get("row") as Control
	var ring := entry.get("ring_panel") as Panel
	var items_box := entry.get("items_box") as HBoxContainer

	if is_instance_valid(ring):
		var glow_tw := ring.create_tween()
		glow_tw.tween_property(ring, "modulate", Color(1.55, 0.45, 0.42, 1.0), 0.09).set_trans(Tween.TRANS_SINE)
		glow_tw.tween_property(ring, "modulate", Color.WHITE, 0.32).set_trans(Tween.TRANS_SINE)

	if is_instance_valid(items_box):
		var item_tint := items_box.create_tween()
		item_tint.tween_property(items_box, "modulate", Color(1.45, 0.50, 0.48, 1.0), 0.09).set_trans(Tween.TRANS_SINE)
		item_tint.tween_property(items_box, "modulate", Color.WHITE, 0.32).set_trans(Tween.TRANS_SINE)

	if is_instance_valid(row):
		var shake := row.create_tween()
		shake.tween_property(row, "position:x", -9.0, 0.045).as_relative().set_trans(Tween.TRANS_SINE)
		shake.tween_property(row, "position:x", 16.0, 0.055).as_relative().set_trans(Tween.TRANS_SINE)
		shake.tween_property(row, "position:x", -12.0, 0.055).as_relative().set_trans(Tween.TRANS_SINE)
		shake.tween_property(row, "position:x", 5.0, 0.05).as_relative().set_trans(Tween.TRANS_SINE)

func _remove_row(customer_name: String, fulfilled_celebration: bool = false, rejected_anim: bool = false) -> void:
	if not _rows.has(customer_name):
		return
	var entry: Dictionary = _rows[customer_name]
	_rows.erase(customer_name)
	var old_hover_tw = entry.get("hover_tween", null)
	if old_hover_tw and old_hover_tw.is_valid():
		old_hover_tw.kill()
	if _hovered_row_key == customer_name:
		_hovered_row_key = ""
		_hovered_is_dragging = false
		_refresh_row_hover_visuals()

	var row: Control = entry.get("row") as Control
	var items_box: HBoxContainer = entry.get("items_box") as HBoxContainer
	var exit_delay := 0.0

	if fulfilled_celebration:
		if is_instance_valid(items_box):
			for child in items_box.get_children():
				if is_instance_valid(child) and not child.get_meta("is_popping", false):
					_pop_and_remove_item(child)
		_pulse_medallion_happy(entry)
		exit_delay = 0.52
	elif rejected_anim:
		_pulse_row_rejected(entry, true)
		exit_delay = 0.26

	if is_instance_valid(row):
		row.pivot_offset = Vector2(row.size.x, row.size.y * 0.5)
		var tw := create_tween()
		if exit_delay > 0.0:
			tw.tween_interval(exit_delay)
		tw.tween_property(row, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(row, "scale", Vector2(0.86, 0.86), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(row, "position:x", 90.0, 0.28).as_relative().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			if is_instance_valid(row):
				row.queue_free()
			if _rows.is_empty():
				_hide_hud()
		)
	elif _rows.is_empty():
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

func _add_item_icon(items_box: HBoxContainer, item: ItemData, is_riddle: bool, stagger_delay: float = 0.0) -> void:
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

	var anim_target: Control = rect_container.get_node_or_null("RiddleBadge") as Control if is_riddle else icon
	if not is_instance_valid(anim_target):
		anim_target = icon
	var base_y := anim_target.position.y
	anim_target.pivot_offset = anim_target.size * 0.5
	anim_target.scale = Vector2(0.35, 1.35)
	anim_target.position.y = base_y - 20.0
	anim_target.modulate.a = 0.0

	var tw := anim_target.create_tween()
	if stagger_delay > 0.0:
		tw.tween_interval(stagger_delay)
	# Drop in with squash-and-stretch landing
	tw.tween_property(anim_target, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(anim_target, "position:y", base_y, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(anim_target, "scale", Vector2(1.14, 0.88), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(anim_target, "scale", Vector2(0.96, 1.05), 0.10).set_trans(Tween.TRANS_SINE)
	tw.tween_property(anim_target, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if is_instance_valid(anim_target):
			_apply_sway(anim_target)
	)

func _spawn_fulfill_burst(source_control: Control) -> void:
	var host := get_node_or_null("Control") as Control
	if not is_instance_valid(host) or not is_instance_valid(source_control):
		return
	var center := source_control.get_global_rect().get_center()

	# Floating green-gold checkmark
	var check := Label.new()
	check.text = "✓"
	check.add_theme_font_override("font", UIStyle.FONT_INDER)
	check.add_theme_font_size_override("font_size", 34)
	check.add_theme_color_override("font_color", Color("#8BF08E"))
	check.add_theme_color_override("font_outline_color", Color(0.05, 0.12, 0.06, 0.95))
	check.add_theme_constant_override("outline_size", 6)
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	check.position = center - Vector2(14, 22)
	check.pivot_offset = Vector2(14, 20)
	check.scale = Vector2(0.3, 0.3)
	host.add_child(check)

	var ctw := check.create_tween()
	ctw.tween_property(check, "scale", Vector2(1.22, 1.22), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ctw.parallel().tween_property(check, "position:y", center.y - 44.0, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ctw.tween_interval(0.28)
	ctw.tween_property(check, "modulate:a", 0.0, 0.34).set_trans(Tween.TRANS_SINE)
	ctw.parallel().tween_property(check, "position:y", -12.0, 0.34).as_relative().set_trans(Tween.TRANS_SINE)
	ctw.tween_callback(check.queue_free)

	# 5 mini gold/green sparkle dots bursting outward
	var spark_colors: Array[Color] = [
		Color(1.0, 0.92, 0.55, 1.0),
		Color(0.55, 0.95, 0.62, 1.0),
		Color(1.0, 0.98, 0.85, 1.0)
	]
	for i in range(5):
		var angle := (TAU / 5.0) * float(i) + randf_range(-0.3, 0.3)
		var dist := randf_range(30.0, 50.0)
		var dot := Panel.new()
		var sz := randf_range(7.0, 11.0)
		dot.size = Vector2(sz, sz)
		dot.pivot_offset = dot.size * 0.5
		dot.position = center - dot.pivot_offset
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_theme_stylebox_override("panel", _make_circle_style(spark_colors[i % spark_colors.size()], Color.TRANSPARENT, 0, 999, 0))
		host.add_child(dot)

		var target := center + Vector2(cos(angle), sin(angle)) * dist - dot.pivot_offset
		var dtw := dot.create_tween().set_parallel(true)
		dtw.tween_property(dot, "position", target, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		dtw.tween_property(dot, "scale", Vector2.ZERO, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		dtw.tween_property(dot, "modulate:a", 0.0, 0.48).set_trans(Tween.TRANS_SINE)
		dtw.chain().tween_callback(dot.queue_free)

func _pop_and_remove_item(child: Control) -> void:
	if child.get_child_count() == 0:
		child.queue_free()
		return

	child.set_meta("is_popping", true)
	var riddle_badge := child.get_node_or_null("RiddleBadge") as Control
	var icon := child.get_node_or_null("ItemIcon") as Control
	var anim_target: Control = riddle_badge if (is_instance_valid(riddle_badge) and riddle_badge.visible) else icon
	if not is_instance_valid(anim_target):
		anim_target = child.get_child(0) as Control

	if anim_target and anim_target.get_meta("sway_tween", null):
		var sw_tw = anim_target.get_meta("sway_tween")
		if sw_tw and sw_tw.is_valid():
			sw_tw.kill()
	if anim_target and anim_target.get_meta("bob_tween", null):
		var bb_tw = anim_target.get_meta("bob_tween")
		if bb_tw and bb_tw.is_valid():
			bb_tw.kill()

	_spawn_fulfill_burst(child)

	var spin_dir := 1.0 if randf() < 0.5 else -1.0
	var tw := create_tween()
	# Phase 1: Readable green-gold pop & playful spin while fully opaque
	if anim_target:
		tw.tween_property(anim_target, "modulate", Color(0.75, 1.42, 0.85, 1.0), 0.14).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(anim_target, "scale", Vector2(1.28, 1.28), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(anim_target, "position:y", -18.0, 0.24).as_relative().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(anim_target, "rotation_degrees", spin_dir * 14.0, 0.24).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Phase 2: Smooth glide fade-out and gentle slot collapse
	tw.tween_property(child, "modulate:a", 0.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if anim_target:
		tw.parallel().tween_property(anim_target, "position:y", -10.0, 0.30).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(anim_target, "scale", Vector2(0.85, 0.85), 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(child, "custom_minimum_size:x", 0.0, 0.34).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)

	tw.tween_callback(func():
		if is_instance_valid(child):
			child.queue_free()
	)

func _on_order_cleared(customer_name: String = "") -> void:
	if customer_name == "":
		_rows.clear()
		_hide_hud()
	else:
		# If the customer still had unfulfilled items in the HUD when leaving, play the red rejection animation
		var had_unfulfilled := _rows.has(customer_name) and not (_rows[customer_name].get("items", []) as Array).is_empty()
		_remove_row(customer_name, false, had_unfulfilled)

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

func _apply_portrait_bob(portrait: Control) -> void:
	# Pure rotational head-tilt with anticipation + overshoot game juice (no vertical/horizontal position drift)
	var tilt_deg := randf_range(4.2, 6.8)
	var tilt_dir := 1.0 if randf() < 0.5 else -1.0
	var swing_dur := randf_range(0.62, 0.92)
	var hold_dur := randf_range(0.18, 0.36)
	portrait.rotation_degrees = -tilt_deg * tilt_dir

	var tilt_tw := portrait.create_tween().set_loops()
	portrait.set_meta("portrait_tilt_tween", tilt_tw)
	# TRANS_BACK + EASE_IN_OUT gives natural anticipation pull-back before swinging and overshoot settle on arrival
	tilt_tw.tween_property(portrait, "rotation_degrees", tilt_deg * tilt_dir, swing_dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tilt_tw.tween_interval(hold_dur)
	tilt_tw.tween_property(portrait, "rotation_degrees", -tilt_deg * tilt_dir, swing_dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tilt_tw.tween_interval(hold_dur)

func _apply_sway(icon: Control) -> void:
	# Varied per-item rock + independent vertical float so neighboring items never bob in lockstep
	var sway_dir := 1.0 if randf() < 0.5 else -1.0
	var sway_dur := randf_range(1.8, 4.6)
	var angle := randf_range(2.5, 8.0)
	icon.rotation_degrees = randf_range(-angle, angle)

	var tw := icon.create_tween().set_loops()
	icon.set_meta("sway_tween", tw)
	tw.tween_property(icon, "rotation_degrees", angle * sway_dir, sway_dur * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(icon, "rotation_degrees", -angle * sway_dir, sway_dur * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var base_y := icon.position.y
	var bob_amp := randf_range(2.0, 5.2)
	var bob_half := randf_range(0.85, 1.75)
	var bob_dir := 1.0 if randf() < 0.5 else -1.0
	var bob_tw := icon.create_tween().set_loops()
	icon.set_meta("bob_tween", bob_tw)
	bob_tw.tween_property(icon, "position:y", base_y - bob_amp * bob_dir, bob_half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob_tw.tween_property(icon, "position:y", base_y + bob_amp * bob_dir, bob_half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_customer_hover_changed(customer: Customer, is_dragging: bool) -> void:
	var next_key := customer.get_order_hud_key().strip_edges() if is_instance_valid(customer) else ""
	if next_key != "" and not _rows.has(next_key):
		next_key = ""
	if next_key == _hovered_row_key and is_dragging == _hovered_is_dragging:
		return
	_hovered_row_key = next_key
	_hovered_is_dragging = is_dragging if next_key != "" else false
	_refresh_row_hover_visuals()

func _refresh_row_hover_visuals() -> void:
	var target_key := _hovered_row_key if (_hovered_row_key != "" and _rows.has(_hovered_row_key)) else ""
	var highlight_col := Color("#8CF5A2") if _hovered_is_dragging else Color("#FFE082")
	var resting_ring_col := Color(0.88, 0.72, 0.42, 0.85)
	var resting_bar_col := Color(0.88, 0.72, 0.42, 0.48)
	var resting_bar_bg := Color(0.07, 0.06, 0.05, 0.80)
	var active_bar_bg := Color(0.11, 0.14, 0.10, 0.90) if _hovered_is_dragging else Color(0.13, 0.11, 0.08, 0.88)

	for raw_key in _rows.keys():
		var key := str(raw_key)
		var entry: Dictionary = _rows[key]
		if not entry.get("entered", false):
			continue
		var row := entry.get("row") as Control
		var shelf := entry.get("shelf_container") as Control
		var badge := entry.get("badge_holder") as Control
		var ring_style := entry.get("ring_style") as StyleBoxFlat
		var bar_style := entry.get("bar_style") as StyleBoxFlat
		if not is_instance_valid(row):
			continue

		var old_tw = entry.get("hover_tween", null)
		if old_tw and old_tw.is_valid():
			old_tw.kill()

		var is_target: bool = (target_key != "" and key == target_key)
		var dim_other: bool = (target_key != "" and not is_target)

		if ring_style:
			ring_style.border_color = highlight_col if is_target else resting_ring_col
			ring_style.set_border_width_all(3 if is_target else 2)
		if bar_style:
			bar_style.border_color = highlight_col if is_target else resting_bar_col
			bar_style.bg_color = active_bar_bg if is_target else resting_bar_bg

		var tw := create_tween().set_parallel(true)
		entry["hover_tween"] = tw
		tw.tween_property(row, "modulate:a", 0.76 if dim_other else 1.0, 0.14).set_trans(Tween.TRANS_SINE)

		if is_instance_valid(badge):
			badge.pivot_offset = Vector2(PORTRAIT_RING_SIZE * 0.5, PORTRAIT_RING_SIZE * 0.5)
			tw.tween_property(badge, "scale", Vector2(1.08, 1.08) if is_target else Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if is_instance_valid(shelf):
			shelf.pivot_offset = Vector2(shelf.size.x, shelf.size.y * 0.5)
			tw.tween_property(shelf, "scale", Vector2(1.03, 1.03) if is_target else Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
