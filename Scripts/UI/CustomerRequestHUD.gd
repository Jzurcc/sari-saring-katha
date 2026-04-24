extends CanvasLayer

@onready var panel_container: PanelContainer = %PanelContainer
@onready var item_container: HBoxContainer = %ItemContainer

var _last_customer_name: String = ""
var _last_items: Array[ItemData] = []
var _last_is_riddle: bool = false
var is_visible_hud: bool = false

func _ready() -> void:
	panel_container.modulate.a = 0.0
	
	EventBus.customer_order_updated.connect(_on_order_updated)
	EventBus.customer_order_cleared.connect(_on_order_cleared)
	EventBus.tier_advanced.connect(_on_tier_advanced)

func _on_tier_advanced(_new_tier: int, _source: String) -> void:
	if is_visible_hud and not _last_items.is_empty():
		_on_order_updated(_last_customer_name, _last_items, _last_is_riddle)

func _on_order_updated(customer_name: String, items: Array[ItemData], is_riddle: bool) -> void:
	_last_customer_name = customer_name
	_last_items = items
	_last_is_riddle = is_riddle
	
	_show_hud()
	
	# 1. Identify which icons to remove and which to keep
	# We use a checklist strategy to handle duplicate items (e.g., two of the same item)
	var checklist = items.duplicate()
	var active_children = []
	
	for child in item_container.get_children():
		if not child.get_meta("is_popping", false):
			active_children.append(child)
	
	# Match right-to-left to prioritize keeping the rightmost icons
	# This causes the leftmost icon of a duplicate set to be the one that pops
	for i in range(active_children.size() - 1, -1, -1):
		var child = active_children[i]
		var bound_item = child.get_meta("item_data", null)
		
		var match_idx = checklist.find(bound_item)
		if match_idx != -1:
			# This icon is accounted for in the new list, keep it
			_update_icon_visuals(child, bound_item, is_riddle)
			checklist.remove_at(match_idx)
		else:
			# This icon is no longer in the order, remove it
			_pop_and_remove_item(child)
	
	# 2. Add any remaining items in the checklist (truly new items)
	var is_refresh = not checklist.is_empty() and items.size() == _last_items.size()
	for item in checklist:
		_add_item_icon(item, is_riddle)

	if items.is_empty():
		_hide_hud()

func _update_icon_visuals(rect_container: Control, item: ItemData, is_riddle: bool) -> void:
	var icon = rect_container.get_child(0) as TextureRect
	if not icon: return
	
	# Riddle specific silhouette
	if is_riddle:
		if icon.texture != preload("res://icon.svg"):
			icon.texture = preload("res://icon.svg")
		icon.modulate = Color(0, 0, 0, 1)
		
		# Ensure label exists
		var has_label = false
		for c in rect_container.get_children():
			if c is Label:
				has_label = true
				break
		
		if not has_label:
			var label = Label.new()
			label.text = "?"
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.size = Vector2(120, 120)
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_font_size_override("font_size", 64)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rect_container.add_child(label)
	else:
		icon.texture = item.texture
		if item.tier > StoryManager.current_tier:
			icon.modulate = Color(0.2, 0.2, 0.2, 1)
		else:
			icon.modulate = Color.WHITE
		
		# Remove riddle label if it exists
		for c in rect_container.get_children():
			if c is Label:
				c.queue_free()

func _add_item_icon(item: ItemData, is_riddle: bool) -> void:
	var rect_container = Control.new()
	rect_container.custom_minimum_size = Vector2(120, 120)
	rect_container.clip_contents = false
	
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(120, 120)
	icon.pivot_offset = Vector2(60, 60)
	icon.position = Vector2.ZERO
	
	rect_container.add_child(icon)
	_update_icon_visuals(rect_container, item, is_riddle)
	
	item_container.add_child(rect_container)
	
	rect_container.set_meta("item_data", item)
	rect_container.set_meta("is_popping", false)
	
	# Entrance animation
	icon.scale = Vector2.ZERO
	var tw = create_tween()
	tw.tween_property(icon, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	_apply_sway(icon)

func _pop_and_remove_item(child: Control) -> void:
	if child.get_child_count() == 0:
		child.queue_free()
		return
		
	child.set_meta("is_popping", true)
	var icon = child.get_child(0)
	
	# Stop sway
	if icon.get_meta("sway_tween", null):
		var sw_tw = icon.get_meta("sway_tween")
		sw_tw.kill()
	
	var tw = create_tween().set_parallel(true)
	# Pop effect (Animate individual icon for scale, but whole child for fade)
	tw.tween_property(icon, "scale", Vector2(1.8, 1.8), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(child, "modulate:a", 0.0, 0.2)
	
	# Smoothly shrink the container size to close the gap
	tw.tween_property(child, "custom_minimum_size:x", 0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tw.chain().tween_callback(func():
		if is_instance_valid(child):
			child.queue_free()
	)

func _on_order_cleared() -> void:
	_hide_hud()

func _show_hud() -> void:
	if is_visible_hud:
		return
	is_visible_hud = true
	panel_container.position.x = 200
	var tw = create_tween().set_parallel(true)
	tw.tween_property(panel_container, "position:x", 0, 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel_container, "modulate:a", 1.0, 0.3)

func _hide_hud() -> void:
	if not is_visible_hud:
		return
	is_visible_hud = false
	var tw = create_tween().set_parallel(true)
	tw.tween_property(panel_container, "position:x", 200, 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(panel_container, "modulate:a", 0.0, 0.3)
	
	# Don't clear immediately, let animations finish if any are running
	tw.chain().tween_callback(func():
		if not is_visible_hud:
			for c in item_container.get_children():
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
