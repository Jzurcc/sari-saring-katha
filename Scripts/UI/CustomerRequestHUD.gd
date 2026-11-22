extends CanvasLayer

const RIDDLE_ICON = preload("res://icon.svg")
const ICON_SIZE := 84
const PORTRAIT_SIZE := 72

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

var _rows: Dictionary = {} # customer_name -> { "row": HBoxContainer, "items_box": HBoxContainer, "items": Array[ItemData], "is_riddle": bool }
var is_visible_hud: bool = false

func _ready() -> void:
	panel_container.modulate.a = 0.0

	EventBus.customer_order_updated.connect(_on_order_updated)
	EventBus.customer_order_cleared.connect(_on_order_cleared)
	EventBus.tier_advanced.connect(_on_tier_advanced)

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

func _create_row(customer_name: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var portrait_tex := _get_portrait_texture(customer_name)
	if portrait_tex != null:
		var portrait_rect := TextureRect.new()
		portrait_rect.texture = portrait_tex
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_rect.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
		portrait_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(portrait_rect)
	else:
		var name_lbl := Label.new()
		name_lbl.text = customer_name
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", Color(0.96, 0.92, 0.80, 0.95))
		name_lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.04, 0.9))
		name_lbl.add_theme_constant_override("outline_size", 4)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_lbl)

	var items_box := HBoxContainer.new()
	items_box.alignment = BoxContainer.ALIGNMENT_END
	items_box.add_theme_constant_override("separation", 10)
	items_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(items_box)

	rows_container.add_child(row)

	row.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(row, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)

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

func _update_icon_visuals(rect_container: Control, item: ItemData, is_riddle: bool) -> void:
	var icon = rect_container.get_child(0) as TextureRect
	if not icon:
		return

	if is_riddle:
		if icon.texture != RIDDLE_ICON:
			icon.texture = RIDDLE_ICON
		icon.modulate = Color(0, 0, 0, 1)

		var label = rect_container.get_node_or_null("RiddleLabel") as Label
		if not label:
			label = Label.new()
			label.name = "RiddleLabel"
			label.text = "?"
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.size = Vector2(ICON_SIZE, ICON_SIZE)
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_font_size_override("font_size", 46)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rect_container.add_child(label)
	else:
		icon.texture = item.texture
		icon.modulate = Color(0.2, 0.2, 0.2, 1) if item.tier > StoryManager.current_tier else Color.WHITE

		var label = rect_container.get_node_or_null("RiddleLabel")
		if label:
			label.queue_free()

func _add_item_icon(items_box: HBoxContainer, item: ItemData, is_riddle: bool) -> void:
	var rect_container = Control.new()
	rect_container.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	rect_container.clip_contents = false
	rect_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.pivot_offset = Vector2(ICON_SIZE * 0.5, ICON_SIZE * 0.5)
	icon.position = Vector2.ZERO
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	rect_container.add_child(icon)
	_update_icon_visuals(rect_container, item, is_riddle)

	items_box.add_child(rect_container)

	rect_container.set_meta("item_data", item)
	rect_container.set_meta("is_popping", false)

	icon.scale = Vector2.ZERO
	var tw = create_tween()
	tw.tween_property(icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_apply_sway(icon)

func _pop_and_remove_item(child: Control) -> void:
	if child.get_child_count() == 0:
		child.queue_free()
		return

	child.set_meta("is_popping", true)
	var icon = child.get_child(0)

	if icon.get_meta("sway_tween", null):
		var sw_tw = icon.get_meta("sway_tween")
		sw_tw.kill()

	var tw = create_tween().set_parallel(true)
	tw.tween_property(icon, "scale", Vector2(1.7, 1.7), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
	panel_container.position.x = 200
	var tw = create_tween().set_parallel(true)
	tw.tween_property(panel_container, "position:x", 0, 0.35).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel_container, "modulate:a", 1.0, 0.25)

func _hide_hud() -> void:
	if not is_visible_hud:
		return
	is_visible_hud = false
	var tw = create_tween().set_parallel(true)
	tw.tween_property(panel_container, "position:x", 200, 0.28).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(panel_container, "modulate:a", 0.0, 0.28)

	tw.chain().tween_callback(func():
		if not is_visible_hud:
			for c in rows_container.get_children():
				if is_instance_valid(c):
					c.queue_free()
	)

func _apply_sway(icon: Control) -> void:
	var tw = icon.create_tween().set_loops()
	icon.set_meta("sway_tween", tw)
	var duration = randf_range(2.5, 4.5)
	var angle = randf_range(3.0, 6.0)

	icon.rotation_degrees = randf_range(-angle, angle)
	tw.tween_property(icon, "rotation_degrees", angle, duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(icon, "rotation_degrees", -angle, duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
