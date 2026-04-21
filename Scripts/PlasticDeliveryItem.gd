extends WorldInteractor
class_name PlasticDeliveryItem

## A temporary container for delivered items. 
## Each bag holds up to 5 items and disappears when empty.

const DRAGGABLE_ITEM_SCENE: PackedScene = preload("res://Scenes/DraggableItem.tscn")

var items: Array[ItemData] = []
var is_fading_in: bool = true
var base_scale: Vector3 = Vector3.ONE
var in_flight_count: int = 0

@onready var sprite: Sprite3D = $Sprite3D

func _ready() -> void:
	super._ready()
	# Billboard settings
	billboard_collision = true
	add_to_group("delivery_bag")
	
	if sprite:
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		base_scale = sprite.scale
		# Ground the sprite: pin the texture bottom to the node origin
		if sprite.texture:
			sprite.offset.y = sprite.texture.get_height() / 2.0
			sprite.position.y = 0
			
		# Adjust the collision shape so it tightly fits and sits on the floor
		var col = get_node_or_null("CollisionShape3D")
		if col and col.shape is BoxShape3D and sprite.texture:
			var shape_copy: BoxShape3D = col.shape.duplicate()
			var sprite_w = sprite.texture.get_width() * sprite.pixel_size * sprite.scale.x
			var sprite_h = sprite.texture.get_height() * sprite.pixel_size * sprite.scale.y
			shape_copy.size = Vector3(sprite_w, sprite_h, shape_copy.size.z)
			col.shape = shape_copy
			col.position.y = shape_copy.size.y / 2.0

		# Randomize scale just a little bit from the base
		var random_scale_factor = randf_range(0.9, 1.1)
		sprite.scale = base_scale * random_scale_factor
		base_scale = sprite.scale

		sprite.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 1.0, 1.0)
		await tween.finished
		is_fading_in = false

func _apply_outline(color: Color) -> void:
	super._apply_outline(color)
	if _outline_mat:
		_outline_mat.set_shader_parameter("fixed_y_billboard", false)

func on_interact() -> void:
	if is_fading_in or DragManager._is_dragging:
		return
		
	if items.is_empty():
		_fade_out_and_destroy()
		return
		
	# Pop the last item
	var item_data: ItemData = items.pop_back()
	
	# Instantiate a DraggableItem
	var drag_item: DraggableItem = DRAGGABLE_ITEM_SCENE.instantiate()
	get_tree().current_scene.add_child(drag_item)
	
	# Setup the drag
	drag_item.setup(item_data, global_transform, self)
	drag_item.is_transient = true # It shouldn't persist if dropped in mid-air
	drag_item.sprite.hide() # Hide base sprite as DragManager provides a cursor sprite
	
	# Subtract from digital stock immediately when taken out 
	# (Since add_stock was already called in MarioManager)
	InventoryManager.take_item(item_data)
	in_flight_count += 1
	
	DragManager.start_drag(drag_item, item_data.texture)
	
	if EventBus.has_signal("request_sfx"):
		EventBus.request_sfx.emit("plastic")
	
	# Visual feedback
	if not items.is_empty():
		_refresh_visuals()

func receive_item(drag_item: DraggableItem) -> void:
	if items.size() >= 5:
		return # Bag is full
		
	items.push_back(drag_item.item_data)
	
	# Restore digital stock since it was likely taken out (or just general logic consistency)
	InventoryManager.return_item(drag_item.item_data)
	
	# Visual feedback: tween the item into the bag
	var target_pos = global_position + Vector3(0, 0.1, 0)
	var tween = create_tween()
	tween.tween_property(drag_item, "global_position", target_pos, 0.2).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(drag_item.sprite, "modulate:a", 0.0, 0.2)
	tween.tween_callback(drag_item.queue_free)
	
	if EventBus.has_signal("request_sfx"):
		EventBus.request_sfx.emit("plastic")
	
	in_flight_count -= 1
	_refresh_visuals()

func notify_item_placed(_item: DraggableItem) -> void:
	in_flight_count -= 1
	if items.is_empty() and in_flight_count <= 0:
		_fade_out_and_destroy()

func _refresh_visuals() -> void:
	# Add a little squash juice relative to the original base_scale to show it received/lost something
	var tw = create_tween()
	sprite.scale = base_scale * Vector3(1.2, 0.8, 1.2)
	tw.tween_property(sprite, "scale", base_scale, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _fade_out_and_destroy() -> void:
	if is_fading_in: 
		return
	is_fading_in = true
	
	var tween = create_tween()
	
	# 1. Quick Squash (Anticipation)
	tween.tween_property(sprite, "scale", base_scale * Vector3(1.4, 0.5, 1.4), 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# 2. Stretch and Exit
	# Pop upwards by stretching vertically while shrinking to zero
	tween.tween_property(sprite, "scale", Vector3(0.0, base_scale.y * 2.0, 0.0), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.2)
	
	tween.tween_callback(queue_free)
