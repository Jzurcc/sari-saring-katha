extends CanvasLayer

@onready var panel_container: PanelContainer = %PanelContainer
@onready var item_container: HBoxContainer = %ItemContainer

var is_visible_hud: bool = false

func _ready() -> void:
	panel_container.modulate.a = 0.0
	
	EventBus.customer_order_updated.connect(_on_order_updated)
	EventBus.customer_order_cleared.connect(_on_order_cleared)

func _on_order_updated(_customer_name: String, items: Array[ItemData], is_riddle: bool) -> void:
	_show_hud()
	
	# 1. Identify which icons to remove (those not in the new list)
	var children = item_container.get_children()
	for child in children:
		if child.get_meta("is_popping", false):
			continue
			
		var bound_item = child.get_meta("item_data", null)
		if not items.has(bound_item):
			_pop_and_remove_item(child)
	
	# 2. Identify which items to add (those not already in the container)
	for item in items:
		var already_exists = false
		for child in item_container.get_children():
			if child.get_meta("item_data", null) == item and not child.get_meta("is_popping", false):
				already_exists = true
				break
		
		if not already_exists:
			_add_item_icon(item, is_riddle)

	if items.is_empty():
		_hide_hud()

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
	icon.texture = item.texture
	
	rect_container.add_child(icon)
	
	# Riddle specific silhouette
	if is_riddle:
		icon.texture = preload("res://icon.svg")
		icon.modulate = Color(0, 0, 0, 1)
		
		var label = Label.new()
		label.text = "?"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(120, 120)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_font_size_override("font_size", 64)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect_container.add_child(label)
	elif item.tier > StoryManager.current_tier:
		icon.modulate = Color(0.2, 0.2, 0.2, 1)
	else:
		icon.modulate = Color.WHITE
	
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
