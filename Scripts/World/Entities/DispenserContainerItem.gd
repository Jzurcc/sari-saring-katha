class_name DispenserContainerItem
extends WorldInteractor

## Base class for interactable containers (e.g. CandyContainerItem, SachetContainerItem)
## that dispense transient DraggableItems, display pricing UI overlays, and gate visibility by tier.

const DRAGGABLE_ITEM_SCENE: PackedScene = preload("res://Scenes/DraggableItem.tscn")

@export var max_stock: int = 5
@export var min_unlock_tier: int = 0
@export var disable_at_tier: int = -1
@export var container_item: ItemData

var current_stock: int = 0
var _is_unlocked: bool = false
var _is_placed: bool = false
var _is_ghost_mode: bool = false
var is_hovered: bool = false
var _pricing_mode_active: bool = false
var _original_alpha_cut: SpriteBase3D.AlphaCutMode = SpriteBase3D.ALPHA_CUT_DISABLED
var _base_sprite_scale: Vector3 = Vector3.ONE
var _ghost_blink_tween: Tween = null

@onready var sprite: Sprite3D = $Sprite3D

static func is_container_prop(item: ItemData) -> bool:
	if not item:
		return false
	return item.category == "candycontainer" \
		or "/candycontainer/" in item.resource_path \
		or "/sachetcontainers/" in item.resource_path

static func is_dispenser_refill(item: ItemData) -> bool:
	if not item or is_container_prop(item):
		return false
	return item.category == "candy" \
		or item.category == "sachet" \
		or item.type == ItemData.ItemType.CANDY_CONTAINER \
		or item.type == ItemData.ItemType.SACHET_CONTAINER

func _ready() -> void:
	super._ready()
	add_to_group("pricing_ui_containers")
	add_to_group("dispenser_containers")
	billboard_collision = false
	if sprite:
		_original_alpha_cut = sprite.alpha_cut
		_base_sprite_scale = sprite.scale
	
	EventBus.tier_advanced.connect(_on_tier_advanced)
	EventBus.day_started.connect(_on_day_started)
	InventoryManager.stock_changed.connect(_on_inventory_stock_changed)
	_check_unlock_status()
	_update_local_stock()

func _on_day_started(_day: int) -> void:
	_check_unlock_status()
	_update_local_stock()

func _on_tier_advanced(_new_tier: int, _source: String) -> void:
	_check_unlock_status()

func refresh_stock() -> void:
	_check_unlock_status()
	_update_local_stock()

func _apply_visibility_state() -> void:
	if container_item:
		_is_placed = StoryManager.is_container_placed(container_item.resource_path)
	else:
		_is_placed = true

	if _is_ghost_mode:
		return

	var active: bool = _is_unlocked and _is_placed
	visible = active
	monitorable = active
	monitoring = active
	collision_layer = 1 if active else 0
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func matches_container_item(item: ItemData) -> bool:
	if not container_item or not item:
		return false
	return item == container_item or (item.resource_path != "" and item.resource_path == container_item.resource_path)

func set_ghost_preview_for(dragged_item: ItemData) -> void:
	if dragged_item != null and _is_unlocked and not _is_placed and matches_container_item(dragged_item):
		_enter_ghost_mode()
	elif _is_ghost_mode:
		_exit_ghost_mode()

func _enter_ghost_mode() -> void:
	if _is_ghost_mode:
		return
	_is_ghost_mode = true
	visible = true
	monitorable = true
	monitoring = true
	collision_layer = 1
	process_mode = Node.PROCESS_MODE_INHERIT
	add_to_group("container_drop_slot")

	if sprite:
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		sprite.modulate = Color(0.85, 1.0, 0.9, 0.22)
		if _ghost_blink_tween and _ghost_blink_tween.is_valid():
			_ghost_blink_tween.kill()
		_ghost_blink_tween = create_tween().set_loops()
		_ghost_blink_tween.tween_property(sprite, "modulate:a", 0.55, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_ghost_blink_tween.tween_property(sprite, "modulate:a", 0.20, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _exit_ghost_mode() -> void:
	if not _is_ghost_mode:
		return
	_is_ghost_mode = false
	if is_in_group("container_drop_slot"):
		remove_from_group("container_drop_slot")
	if _ghost_blink_tween and _ghost_blink_tween.is_valid():
		_ghost_blink_tween.kill()
	_ghost_blink_tween = null
	if sprite:
		sprite.alpha_cut = _original_alpha_cut
		sprite.modulate = Color.WHITE
	_apply_visibility_state()

func accepts_container(item: ItemData) -> bool:
	return _is_ghost_mode and _is_unlocked and not _is_placed and matches_container_item(item)

func place_container(drag_item: DraggableItem) -> bool:
	if not drag_item or not accepts_container(drag_item.item_data):
		return false

	_is_ghost_mode = false
	if is_in_group("container_drop_slot"):
		remove_from_group("container_drop_slot")
	if _ghost_blink_tween and _ghost_blink_tween.is_valid():
		_ghost_blink_tween.kill()
	_ghost_blink_tween = null

	_is_placed = true
	if container_item:
		StoryManager.mark_container_placed(container_item.resource_path)

	visible = true
	monitorable = true
	monitoring = true
	collision_layer = 1
	process_mode = Node.PROCESS_MODE_INHERIT

	if sprite:
		sprite.alpha_cut = _original_alpha_cut
		sprite.modulate = Color.WHITE
		sprite.scale = _base_sprite_scale * Vector3(1.2, 0.8, 1.2)
		var tw := create_tween()
		tw.tween_property(sprite, "scale", _base_sprite_scale, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		VisualEffectManager.spawn_impact_dust(sprite.global_position)

	EventBus.request_sfx.emit("drop")
	drag_item.notify_placed()
	drag_item.queue_free()
	_update_local_stock()
	return true

func is_placed_and_active() -> bool:
	return _is_unlocked and _is_placed and not _is_ghost_mode

func accepts_refill(_item: ItemData) -> bool:
	return false

func receive_refill(drag_item: DraggableItem) -> bool:
	if not drag_item or not drag_item.item_data or not is_placed_and_active():
		return false
	if not accepts_refill(drag_item.item_data):
		return false
	_update_local_stock()
	if current_stock >= max_stock:
		_play_error_animation()
		EventBus.request_sfx.emit("error")
		return false

	InventoryManager.add_stock(drag_item.item_data, 1)
	_update_local_stock()

	if sprite:
		var tw := create_tween()
		sprite.scale = _base_sprite_scale * Vector3(1.15, 0.88, 1.15)
		tw.tween_property(sprite, "scale", _base_sprite_scale, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		VisualEffectManager.spawn_impact_dust(sprite.global_position)

	EventBus.request_sfx.emit("drop")
	drag_item.notify_placed()
	drag_item.queue_free()
	return true

func set_pricing_ui_active(active: bool) -> void:
	_pricing_mode_active = active
	on_hover(is_hovered)
	if active and is_hovered:
		update_pricing_ui()
	elif not active and is_hovered:
		_update_label_visibility()

func on_hover(is_hov: bool) -> void:
	self.is_hovered = is_hov
	if is_hov and _pricing_mode_active:
		_remove_outline()
	else:
		super.on_hover(is_hov)
	_update_label_visibility()
	if not is_hov:
		_reset_outline_color()

func _update_label_visibility() -> void:
	if not _pricing_mode_active or not is_hovered:
		if is_instance_valid(PricingOverlay):
			PricingOverlay.hide_ui()
	elif _pricing_mode_active and is_hovered:
		update_pricing_ui()

func _reset_outline_color() -> void:
	if _outline_mat:
		_outline_mat.set_shader_parameter("outline_color", default_outline_color)

func _play_error_animation() -> void:
	_apply_outline(Color(1.0, 0.2, 0.2))
	if not sprite:
		return
	var tween := create_tween()
	var base_x := sprite.position.x
	const INTENSITY := 0.05
	const STEP := 0.05
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:x", base_x - INTENSITY, STEP)
	tween.tween_property(sprite, "position:x", base_x + INTENSITY, STEP)
	tween.tween_property(sprite, "position:x", base_x - INTENSITY, STEP)
	tween.tween_property(sprite, "position:x", base_x + INTENSITY, STEP)
	tween.tween_property(sprite, "position:x", base_x, STEP)
	get_tree().create_timer(0.4).timeout.connect(_reset_outline_color)

func _spawn_and_drag_item(item_data: ItemData) -> void:
	if not item_data:
		return
	_update_local_stock()
	var drag_item: DraggableItem = DRAGGABLE_ITEM_SCENE.instantiate()
	get_tree().current_scene.add_child(drag_item)
	drag_item.is_transient = true
	drag_item.setup(item_data, self.global_transform)
	drag_item.sprite.hide()
	DragManager.start_drag(drag_item, item_data.texture)

# Virtual methods to override in subclasses:
func can_adjust_price() -> bool:
	return is_placed_and_active() and not get_available_items().is_empty()

func adjust_price(_delta: float) -> bool:
	return false

func update_pricing_ui() -> void:
	pass

## Returns an array of [ItemData] items currently in-stock and available to dispense.
## Overridden by subclasses.
func get_available_items() -> Array[ItemData]:
	return []

func _update_local_stock() -> void:
	pass

func _check_unlock_status() -> void:
	pass

func _on_inventory_stock_changed(_item: ItemData, _new_stock: int) -> void:
	pass

