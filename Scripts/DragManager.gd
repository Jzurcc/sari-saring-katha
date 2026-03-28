extends Node

var _is_dragging: bool = false
var _dragged_item: DraggableItem = null
var _dragged_texture_rect: TextureRect = null
var _canvas_layer: CanvasLayer = null

# For future sway mechanics
var _sway_offset: Vector2 = Vector2.ZERO
var _drag_velocity: Vector2 = Vector2.ZERO

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

func start_drag(item: DraggableItem, texture: Texture2D) -> void:
	if _is_dragging:
		return

	_is_dragging = true
	_dragged_item = item

	if texture:
		_dragged_texture_rect.texture = texture
		_dragged_texture_rect.custom_minimum_size = Vector2(128, 128)
		_dragged_texture_rect.size = Vector2(128, 128)
		_dragged_texture_rect.pivot_offset = _dragged_texture_rect.size / 2.0
		# Start from slightly below for a nice jump-in animation
		_dragged_texture_rect.position = get_viewport().get_mouse_position() - (_dragged_texture_rect.size / 2.0) + Vector2(0, 100)
		_dragged_texture_rect.show()

	_sway_offset = Vector2.ZERO
	_drag_velocity = Vector2.ZERO
	_dragged_texture_rect.rotation = 0.0

	var crosshair: Control = get_tree().root.get_node_or_null("MainGame/CanvasLayer/CrosshairContainer")
	if crosshair and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		crosshair.hide()
	elif Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	# Notify the item that dragging has started so it can hide its 3D visuals
	_dragged_item._on_drag_started_by_manager()

func _process(_delta: float) -> void:
	if not _is_dragging:
		return

	var target_pos: Vector2
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		target_pos = get_viewport().get_visible_rect().size / 2.0
	else:
		target_pos = get_viewport().get_mouse_position()

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

func _input(event: InputEvent) -> void:
	if not _is_dragging:
		return
		
	if event is InputEventMouseMotion:
		# Add inertial lag
		_sway_offset -= event.relative * 0.4
		
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Toggle grab when mouse is fully locked (true FPS crosshair mode)
			# Revert to classic hold-to-drag when cursor is visible
			var cursor_locked := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
			if cursor_locked:
				if event.pressed:
					get_viewport().set_input_as_handled()
					end_drag()
			else:
				if not event.pressed:
					get_viewport().set_input_as_handled()
					end_drag()

func end_drag() -> void:
	if not _is_dragging:
		return

	_is_dragging = false
	_dragged_texture_rect.hide()

	var crosshair: Control = get_tree().root.get_node_or_null("MainGame/CanvasLayer/CrosshairContainer")
	if crosshair and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		crosshair.show()
	elif Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var camera := get_viewport().get_camera_3d()
	if not camera:
		_cancel_drag()
		return

	# In FPS mode the mouse is locked, so we always raycast from screen center.
	# In cursor mode we use the actual mouse position.
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

	var result := space_state.intersect_ray(_raycast_query)
	var valid_drop := false

	if result:
		var collider: Node = result.collider
		if collider.is_in_group("transaction_tray") and collider.has_method("receive_item"):
			collider.receive_item(_dragged_item)
			valid_drop = true

	if not valid_drop:
		_cancel_drag()
	else:
		_dragged_item = null

## Called by MainGame when the player clicks while in FPS crosshair mode.
## Fires a ray from the screen centre and picks up the first DraggableItem hit.
func fps_try_interact() -> void:
	if _is_dragging:
		end_drag()
		return

	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var center := get_viewport().get_visible_rect().size / 2.0
	var ray_origin := camera.project_ray_origin(center)
	var ray_dir := camera.project_ray_normal(center)

	var query := PhysicsRayQueryParameters3D.new()
	query.from = ray_origin
	query.to = ray_origin + ray_dir * 10.0
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		var collider: Node = result.get("collider")
		if collider is DraggableItem:
			var item: DraggableItem = collider
			if item.item_data and not InventoryManager.is_in_stock(item.item_data):
				print("[DragManager] Out of stock: ", item.item_data.item_name)
				return
			if item.item_data:
				InventoryManager.take_item(item.item_data)
			start_drag(item, item.sprite.texture)

func _cancel_drag() -> void:
	if _dragged_item:
		_dragged_item._on_drag_cancelled_by_manager()
		_dragged_item.return_to_start()
		_dragged_item = null
