extends Node

var _is_dragging: bool = false
var _dragged_item: DraggableItem = null
var _dragged_texture_rect: TextureRect = null
var _canvas_layer: CanvasLayer = null
var _drag_start_frame: int = -1

# For future sway mechanics
var _sway_offset: Vector2 = Vector2.ZERO
var _drag_velocity: Vector2 = Vector2.ZERO

# 3D Ghost preview support
var _ghost_parent: Node3D = null
var _ghost_sprite: Sprite3D = null

# Reuse raycast query parameters instead of creating new ones each frame
var _raycast_query: PhysicsRayQueryParameters3D

func _ready() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 100 # Ensure it's on top of everything
	add_child(_canvas_layer)

	_dragged_texture_rect = TextureRect.new()
	_dragged_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dragged_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_dragged_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_dragged_texture_rect.hide()
	_canvas_layer.add_child(_dragged_texture_rect)

	_raycast_query = PhysicsRayQueryParameters3D.new()
	_raycast_query.collide_with_areas = true
	_raycast_query.collide_with_bodies = false
	_raycast_query.collision_mask = 19  # Layer 1 (tray) + layer 2 (shelf) + layer 5 (customer)

	# Release the drag reference if the held node is freed (e.g. scene change).
	get_tree().node_removed.connect(_on_node_removed)

func start_drag(item: DraggableItem, texture: Texture2D) -> void:
	if _is_dragging:
		return

	_is_dragging = true
	_dragged_item = item
	_drag_start_frame = Engine.get_frames_drawn()

	if texture:
		_dragged_texture_rect.texture = texture
		
		# Scale dragged UI to closely match real-world physical proportions, but scaled up to look held
		var pixels_per_meter: float = 960.0 * 1.5
		var display_w: float = 128.0
		var display_h: float = 128.0
		if item and item.collider and item.collider.shape:
			display_w = item.collider.shape.size.x * pixels_per_meter
			display_h = item.collider.shape.size.y * pixels_per_meter

		_dragged_texture_rect.custom_minimum_size = Vector2(display_w, display_h)
		_dragged_texture_rect.size = Vector2(display_w, display_h)
		_dragged_texture_rect.pivot_offset = _dragged_texture_rect.size / 2.0
		# Start from slightly below for a nice jump-in animation
		_dragged_texture_rect.position = get_viewport().get_mouse_position() - (_dragged_texture_rect.size / 2.0) + Vector2(0, 150)
		_dragged_texture_rect.show()
		
		# Squash and stretch pop-in animation
		_dragged_texture_rect.scale = Vector2(0.6, 1.4)
		var tween = create_tween()
		tween.tween_property(_dragged_texture_rect, "scale", Vector2(1.15, 0.85), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(_dragged_texture_rect, "scale", Vector2(0.95, 1.05), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(_dragged_texture_rect, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_sway_offset = Vector2.ZERO
	_drag_velocity = Vector2.ZERO
	_dragged_texture_rect.rotation = 0.0

	# Setup 3D Ghost Preview
	if is_instance_valid(_ghost_parent):
		_ghost_parent.queue_free()
	
	_ghost_parent = Node3D.new()
	_ghost_parent.hide()
	var scene = get_tree().current_scene
	if scene:
		scene.add_child(_ghost_parent)
	else:
		add_child(_ghost_parent)
		
	if item.sprite:
		_ghost_sprite = item.sprite.duplicate()
		_ghost_sprite.material_overlay = null # Ensure no highlight outline on ghost
		_ghost_sprite.show()
		_ghost_parent.add_child(_ghost_sprite)

	EventBus.drag_started.emit(_dragged_item)
	
	# (Disabled for now) Show pricing tip if item hasn't been priced yet
	#var is_configured = InventoryManager.is_item_configured(_dragged_item.item_data)
	#LogManager.debug("DragManager", "Checking config for %s (ID: %s). Result: %s" % [_dragged_item.item_data.item_name, _dragged_item.item_data.get_clean_id(), is_configured])
	
	#if _dragged_item.item_data and not is_configured:
		#EventBus.show_notification.emit("Unconfigured Item", "Toggle ALT to set your own rates and earn more!", "notif_info")

	# Notify the item that dragging has started so it can hide its 3D visuals
	_dragged_item._on_drag_started_by_manager()

	# Highlight the drop zone
	var tray_nodes := get_tree().get_nodes_in_group("transaction_tray")
	if tray_nodes.size() > 0 and tray_nodes[0].has_method("activate_dropzone"):
		tray_nodes[0].activate_dropzone()

func _process(_delta: float) -> void:
	if not _is_dragging:
		return

	var target_pos: Vector2
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		target_pos = get_viewport().get_visible_rect().size / 2.0
	else:
		target_pos = get_viewport().get_mouse_position()
		
	# Offset downward to mimic holding the item rather than impaling it on the crosshair/cursor
	target_pos.y += _dragged_texture_rect.size.y * 0.45

	# Decay sway back to zero
	_sway_offset = _sway_offset.lerp(Vector2.ZERO, 10.0 * _delta)
	
	# Clamp sway to prevent it from going offscreen
	var max_sway := 80.0
	_sway_offset.x = clamp(_sway_offset.x, -max_sway, max_sway)
	_sway_offset.y = clamp(_sway_offset.y, -max_sway, max_sway)

	# Calculate final intended position of the rect
	var final_pos = target_pos - (_dragged_texture_rect.size / 2.0) + _sway_offset
	
	# Smoothly interpolate position using Spring Physics (Natural Ease In/Out)
	var diff = final_pos - _dragged_texture_rect.position
	var spring_force = diff * 150.0  # Stiffness
	var damping = _drag_velocity * 20.0  # Friction
	_drag_velocity += (spring_force - damping) * _delta
	_dragged_texture_rect.position += _drag_velocity * _delta
	
	# Apply dynamic tilt/rotation based on the horizontal sway
	var target_rotation = _sway_offset.x * 0.003
	_dragged_texture_rect.rotation = lerp(_dragged_texture_rect.rotation, target_rotation, 15.0 * _delta)

	# --- 3D Ghost Preview Logic ---
	var result := _get_drag_raycast_result()
	var valid_ghost := false
	if result and result.collider:
		var collider = (result.collider as Node)
		if collider.is_in_group("shelf_drop_zone"):
			var shelf = collider.get_parent()
			if shelf and shelf.has_method("receive_item"):
				var local_x = shelf.to_local(result.position).x
				var slot_idx: int = shelf._find_nearest_empty_slot(local_x)
				if slot_idx >= 0:
					var slot_pos: Vector3 = shelf._slot_transforms[slot_idx].origin
					var world_pos: Vector3 = shelf.to_global(slot_pos)
					if is_instance_valid(_ghost_parent):
						_ghost_parent.show()
						var slot_transform = shelf.global_transform * shelf._slot_transforms[slot_idx]
						_ghost_parent.global_transform = Transform3D(slot_transform.basis, world_pos)
						
						var can_accept = shelf.accepts_drop(_dragged_item.item_data)
						if is_instance_valid(_ghost_sprite):
							_ghost_sprite.modulate = Color(1.0, 1.0, 1.0, 0.4) if can_accept else Color(1.0, 0.3, 0.3, 0.5)
						valid_ghost = true

	if not valid_ghost and is_instance_valid(_ghost_parent):
		_ghost_parent.hide()

func _input(event: InputEvent) -> void:
	if not _is_dragging:
		return
		
	if event is InputEventMouseMotion:
		# Add inertial lag
		_sway_offset -= event.relative * 0.4
		
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Only end the drag if this isn't the same press that started it.
			# Using Engine.get_frames_drawn() ensures we ignore the pick-up frame.
			if Engine.get_frames_drawn() > _drag_start_frame:
				get_viewport().set_input_as_handled()
				end_drag()

func end_drag() -> void:
	if not _is_dragging:
		return

	_is_dragging = false
	_dragged_texture_rect.hide()

	var success = false

	if is_instance_valid(_ghost_parent):
		_ghost_parent.queue_free()

	# Deactivate drop zone highlight (will also fire on bad drop)
	var tray_nodes := get_tree().get_nodes_in_group("transaction_tray")
	if tray_nodes.size() > 0 and tray_nodes[0].has_method("deactivate_dropzone"):
		tray_nodes[0].deactivate_dropzone()

	var camera := get_viewport().get_camera_3d()
	if not camera:
		_cancel_drag()
		return

	var result := _get_drag_raycast_result()

	if result:
		var collider: Node = result.collider
		if collider.is_in_group("transaction_tray") and collider.has_method("receive_item"):
			collider.receive_item(_dragged_item)
			success = true
		elif collider.is_in_group("trash") and collider.has_method("receive_item"):
			collider.receive_item(_dragged_item)
			success = true
		elif collider is Customer:
			# Redirect the drop to the standard transaction tray logic
			tray_nodes = get_tree().get_nodes_in_group("transaction_tray")
			if tray_nodes.size() > 0 and tray_nodes[0].has_method("receive_item"):
				tray_nodes[0].receive_item(_dragged_item)
				success = true
		elif collider.is_in_group("shelf_drop_zone"):
			# The drop zone Area3D's parent is the ShelfSurface
			var shelf_surface := collider.get_parent()
			if shelf_surface and shelf_surface.has_method("receive_item"):
				shelf_surface.receive_item(_dragged_item, result.position)
				success = true
		elif collider.is_in_group("delivery_bag"):
			if collider.has_method("receive_item"):
				collider.receive_item(_dragged_item)
				success = true

	EventBus.drag_ended.emit(_dragged_item, success)

	if not success:
		_cancel_drag()
	else:
		_dragged_item = null



func _get_drag_raycast_result() -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return {}

	var screen_pos: Vector2
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		screen_pos = get_viewport().get_visible_rect().size / 2.0
	else:
		screen_pos = get_viewport().get_mouse_position()

	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	var ray_end := ray_origin + ray_dir * 50.0

	var space_state := camera.get_world_3d().direct_space_state
	_raycast_query.from = ray_origin
	_raycast_query.to = ray_end

	var exclude_rids: Array[RID] = []
	if _dragged_item and is_instance_valid(_dragged_item):
		exclude_rids.append(_dragged_item.get_rid())
	_raycast_query.exclude = exclude_rids

	return space_state.intersect_ray(_raycast_query)

func _cancel_drag() -> void:
	if _dragged_item:
		_dragged_item._on_drag_cancelled_by_manager()
		_dragged_item.return_to_start()
		_dragged_item = null


## Called when any node is removed from the scene tree.
## Ensures a dangling item reference doesn’t persist across scene changes.
func _on_node_removed(node: Node) -> void:
	if node == _dragged_item:
		_is_dragging = false
		_dragged_item = null
		_dragged_texture_rect.hide()
		if is_instance_valid(_ghost_parent):
			_ghost_parent.queue_free()
