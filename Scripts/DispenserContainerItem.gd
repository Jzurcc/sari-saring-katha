class_name DispenserContainerItem
extends WorldInteractor

## Base class for interactable containers (e.g. CandyContainerItem, SachetContainerItem)
## that dispense transient DraggableItems, display pricing UI overlays, and gate visibility by tier.

const DRAGGABLE_ITEM_SCENE: PackedScene = preload("res://Scenes/DraggableItem.tscn")

@export var max_stock: int = 5
@export var min_unlock_tier: int = 0
@export var disable_at_tier: int = -1

var current_stock: int = 0
var _is_unlocked: bool = false
var is_hovered: bool = false
var _pricing_mode_active: bool = false

@onready var sprite: Sprite3D = $Sprite3D

func _ready() -> void:
	super._ready()
	add_to_group("pricing_ui_containers")
	billboard_collision = false
	
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
	_update_local_stock()

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
		var overlay = get_node_or_null("/root/PricingOverlay")
		if is_instance_valid(overlay):
			overlay.hide_ui()
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
func adjust_price(_delta: float) -> void:
	pass

func update_pricing_ui() -> void:
	pass

func _update_local_stock() -> void:
	pass

func _check_unlock_status() -> void:
	pass

func _on_inventory_stock_changed(_item: ItemData, _new_stock: int) -> void:
	pass

