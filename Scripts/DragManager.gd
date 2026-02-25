extends Node

var _is_dragging: bool = false
var _dragged_item: DraggableItem = null
var _dragged_texture_rect: TextureRect = null
var _canvas_layer: CanvasLayer = null

# For future sway mechanics
var _last_mouse_pos: Vector2
var _current_velocity: Vector2

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

func start_drag(item: DraggableItem, texture: Texture2D) -> void:
	if _is_dragging: return
	
	_is_dragging = true
	_dragged_item = item
	
	if texture:
		_dragged_texture_rect.texture = texture
		# Set an appropriate size
		_dragged_texture_rect.custom_minimum_size = Vector2(128, 128)
		_dragged_texture_rect.size = Vector2(128, 128)
		# Center the texture rect on cursor
		_dragged_texture_rect.position = get_viewport().get_mouse_position() - (_dragged_texture_rect.size / 2.0)
		_dragged_texture_rect.show()
	
	_last_mouse_pos = get_viewport().get_mouse_position()
	
	# Notify the item that dragging has started so it can hide its 3D representation
	if _dragged_item.has_method("_on_drag_started_by_manager"):
		_dragged_item._on_drag_started_by_manager()

func _process(delta: float) -> void:
	if _is_dragging:
		var current_mouse_pos = get_viewport().get_mouse_position()
		if delta > 0:
			_current_velocity = (current_mouse_pos - _last_mouse_pos) / delta
		_last_mouse_pos = current_mouse_pos
		
		# Center on cursor
		_dragged_texture_rect.position = current_mouse_pos - (_dragged_texture_rect.size / 2.0)
		
		# Note: Future item sway can be applied here using _current_velocity to rotate or offset _dragged_texture_rect
		# e.g., _dragged_texture_rect.rotation = lerp(...)

func _input(event: InputEvent) -> void:
	if _is_dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			get_viewport().set_input_as_handled()
			end_drag()

func end_drag() -> void:
	if not _is_dragging: return
	
	_is_dragging = false
	_dragged_texture_rect.hide()
	
	# Raycast to find 3D drop target
	var camera = get_viewport().get_camera_3d()
	if not camera:
		_cancel_drag()
		return
		
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var ray_length = 50.0
	var ray_end = ray_origin + ray_dir * ray_length
	
	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var result = space_state.intersect_ray(query)
	var valid_drop = false
	
	if result:
		var collider = result.collider
		if collider.is_in_group("transaction_tray") and collider.has_method("receive_item"):
			collider.receive_item(_dragged_item)
			valid_drop = true
			
	if not valid_drop:
		_cancel_drag()
	else:
		_dragged_item = null

func _cancel_drag() -> void:
	if _dragged_item:
		if _dragged_item.has_method("_on_drag_cancelled_by_manager"):
			_dragged_item._on_drag_cancelled_by_manager()
		_dragged_item.return_to_start()
		_dragged_item = null
