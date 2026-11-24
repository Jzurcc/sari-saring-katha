extends WorldInteractor
class_name PlasticDeliveryItem

## A temporary container for delivered items. 
## Each bag holds up to 5 items and disappears when empty.

const DRAGGABLE_ITEM_SCENE: PackedScene = preload("res://Scenes/DraggableItem.tscn")

var items: Array[ItemData] = []
var is_fading_in: bool = true
var base_scale: Vector3 = Vector3.ONE
var in_flight_count: int = 0

# Optional curved projectile launch from Mario's tricycle into the store
var use_arc_launch: bool = false
var launch_from_pos: Vector3 = Vector3.ZERO
var launch_target_pos: Vector3 = Vector3.ZERO
var launch_delay: float = 0.0

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

		if use_arc_launch:
			_play_arc_launch()
		else:
			sprite.modulate.a = 0.0
			var tween = create_tween()
			tween.tween_property(sprite, "modulate:a", 1.0, 1.0)
			await tween.finished
			is_fading_in = false

func _play_arc_launch() -> void:
	is_fading_in = true
	global_position = launch_from_pos
	sprite.modulate.a = 0.0
	sprite.scale = base_scale * 0.55

	if launch_delay > 0.0:
		await get_tree().create_timer(launch_delay).timeout
		if not is_inside_tree():
			return

	var start_pos := launch_from_pos
	var end_pos := launch_target_pos
	var duration := randf_range(0.95, 1.15)
	var arc_height := randf_range(1.4, 1.85)

	var arc_tween := create_tween()
	arc_tween.tween_method(func(t: float):
		if not is_instance_valid(self) or not is_instance_valid(sprite):
			return
		var xz_pos := start_pos.lerp(end_pos, t)
		var y_base := lerpf(start_pos.y, end_pos.y, t)
		var y_arc := sin(t * PI) * arc_height
		global_position = Vector3(xz_pos.x, y_base + y_arc, xz_pos.z)
		sprite.modulate.a = clampf(t / 0.14, 0.0, 1.0)
		sprite.scale = base_scale * lerpf(0.55, 1.0, minf(1.0, t * 1.15))
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await arc_tween.finished
	if not is_inside_tree() or not is_instance_valid(sprite):
		return

	global_position = end_pos
	sprite.modulate.a = 1.0
	if EventBus.has_signal("request_sfx"):
		EventBus.request_sfx.emit("plastic")

	# Juicy squash-and-stretch landing bounce
	sprite.scale = base_scale * Vector3(1.26, 0.72, 1.26)
	var land_tw := create_tween()
	land_tw.tween_property(sprite, "scale", base_scale, 0.30).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	is_fading_in = false

func _apply_outline(color: Color) -> void:
	super._apply_outline(color)
	if _outline_mat:
		_outline_mat.set_shader_parameter("fixed_y_billboard", false)

func on_interact() -> void:
	if is_fading_in or DragManager.is_dragging:
		return
		
	if items.is_empty():
		_fade_out_and_destroy()
		return
		
	# 1) Always pop unplaced container props in this bag first
	var item_data: ItemData = null
	var pick_idx: int = -1
	for i in range(items.size()):
		if DispenserContainerItem.is_container_prop(items[i]):
			pick_idx = i
			break

	# 2) Otherwise prefer any regular item or a refill whose dispenser container is already placed
	if pick_idx < 0:
		for i in range(items.size() - 1, -1, -1):
			if _is_item_ready_to_unpack(items[i]):
				pick_idx = i
				break

	# 3) Soft fix: if this bag only holds refills whose container is still sitting in another bag,
	#    seamlessly pull that container prop first so the player never unpacks a refill before its container!
	if pick_idx < 0:
		var pulled_container := _pull_matching_container_from_other_bag(items[items.size() - 1])
		if pulled_container != null:
			item_data = pulled_container
		else:
			item_data = items.pop_back()
	else:
		item_data = items[pick_idx]
		items.remove_at(pick_idx)
	
	# Instantiate a DraggableItem
	var drag_item: DraggableItem = DRAGGABLE_ITEM_SCENE.instantiate()
	get_tree().current_scene.add_child(drag_item)
	
	# Setup the drag
	drag_item.setup(item_data, global_transform, self)
	drag_item.is_transient = true # It shouldn't persist if dropped in mid-air
	drag_item.sprite.hide() # Hide base sprite as DragManager provides a cursor sprite
	
	# Subtract from digital stock immediately for pre-credited shelf/fridge items.
	# Container props and bagged candy/sachet refills are credited only when placed in their container.
	if not DispenserContainerItem.is_container_prop(item_data) and not DispenserContainerItem.is_dispenser_refill(item_data):
		InventoryManager.take_item(item_data)
	in_flight_count += 1
	
	DragManager.start_drag(drag_item, item_data.texture)
	
	if EventBus.has_signal("request_sfx"):
		EventBus.request_sfx.emit("plastic")
	
	# Visual feedback
	if not items.is_empty():
		_refresh_visuals()

func _is_item_ready_to_unpack(item: ItemData) -> bool:
	if not DispenserContainerItem.is_dispenser_refill(item):
		return true
	var tree := get_tree()
	if not tree:
		return true
	var found_matching := false
	for node in tree.get_nodes_in_group("dispenser_containers"):
		var disp := node as DispenserContainerItem
		if disp and disp.accepts_refill(item):
			found_matching = true
			if disp._is_placed:
				return true
	return not found_matching

func _pull_matching_container_from_other_bag(refill_item: ItemData) -> ItemData:
	var tree := get_tree()
	if not tree:
		return null
	var target_container_item: ItemData = null
	for node in tree.get_nodes_in_group("dispenser_containers"):
		var disp := node as DispenserContainerItem
		if disp and disp.accepts_refill(refill_item) and not disp._is_placed and disp.container_item:
			target_container_item = disp.container_item
			break
	if target_container_item == null:
		return null
	for bag_node in tree.get_nodes_in_group("delivery_bag"):
		var other_bag := bag_node as PlasticDeliveryItem
		if not other_bag or other_bag == self:
			continue
		for i in range(other_bag.items.size()):
			var cand := other_bag.items[i]
			if cand and cand.resource_path == target_container_item.resource_path:
				other_bag.items.remove_at(i)
				if other_bag.items.is_empty() and other_bag.in_flight_count <= 0:
					other_bag._fade_out_and_destroy()
				else:
					other_bag._refresh_visuals()
				return cand
	return null

func receive_item(drag_item: DraggableItem) -> void:
	if items.size() >= 5:
		return # Bag is full
		
	items.push_back(drag_item.item_data)
	
	# Restore digital stock for pre-credited shelf/fridge items
	if not DispenserContainerItem.is_container_prop(drag_item.item_data) and not DispenserContainerItem.is_dispenser_refill(drag_item.item_data):
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
