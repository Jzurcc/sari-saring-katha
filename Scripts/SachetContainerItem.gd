class_name SachetContainerItem
extends WorldInteractor

## An interactable sachet strip or box that spawns a [DraggableItem] when clicked.
##
## Unlike [CandyContainerItem], this is dedicated to a single [ItemData] sachet type.
## It pulls stock from the global [InventoryManager].

const DRAGGABLE_ITEM_SCENE: PackedScene = preload("res://Scenes/DraggableItem.tscn")
const INDER_FONT := preload("res://Assets/Fonts/Inder/Inder-Regular.ttf")

@export var sachet_item: ItemData
@export var max_stock: int = 5
@export var min_unlock_tier: int = 0
@export var disable_at_tier: int = -1
var _is_unlocked: bool = false
var current_stock: int = 0



var is_hovered: bool = false
var _pricing_mode_active: bool = false

@onready var sprite: Sprite3D = $Sprite3D

func _ready() -> void:
	super._ready()
	add_to_group("pricing_ui_containers")
	# Ensure the container faces the camera for easier interaction
	billboard_collision = true
	
	EventBus.tier_advanced.connect(_on_tier_advanced)
	_check_unlock_status()
	_update_local_stock()
	# UI is now handled by the global PricingOverlay



func set_pricing_ui_active(active: bool) -> void:
	_pricing_mode_active = active
	
	on_hover(is_hovered)
	
	if active and is_hovered:
		update_pricing_ui()
	elif not active and is_hovered:
		_update_label_visibility()

func adjust_price(delta: float) -> void:
	if not sachet_item: return
	
	var base_price : float = sachet_item.price
	var current_price : float = sachet_item.get_final_price()
	
	var min_price : float = base_price
	var tier : int = sachet_item.tier
	var max_margin : float = 0.25 + (float(max(1, tier)) - 1.0) * (0.25 / 9.0)
	var max_price : float = round(base_price * (1.0 + max_margin))
	
	var new_price : float = clamp(current_price + delta, min_price, max_price)
	
	sachet_item.selling_price = new_price
	
	# Refresh all pricing UIs
	get_tree().call_group("draggable_items", "update_pricing_ui")
	get_tree().call_group("pricing_ui_containers", "update_pricing_ui")

func update_pricing_ui() -> void:
	if not sachet_item: return
	if not is_hovered or not _pricing_mode_active: return
	
	if is_instance_valid(get_node_or_null("/root/PricingOverlay")):
		var stock_info = "Stock: %d / %d" % [current_stock, max_stock]
		get_node("/root/PricingOverlay").show_item(sachet_item, global_position, true, "", stock_info)

func _update_label_visibility() -> void:
	if not _pricing_mode_active or not is_hovered:
		if is_instance_valid(get_node_or_null("/root/PricingOverlay")):
			get_node("/root/PricingOverlay").hide_ui()
	elif _pricing_mode_active and is_hovered:
		update_pricing_ui()

func _on_tier_advanced(_new_tier: int, _source: String) -> void:
	_check_unlock_status()

func _check_unlock_status() -> void:
	var tier = StoryManager.current_tier
	var within_range = false
	
	if min_unlock_tier > 0:
		within_range = tier >= min_unlock_tier
	elif sachet_item:
		within_range = sachet_item.tier <= tier
	
	if disable_at_tier >= 0 and tier >= disable_at_tier:
		within_range = false
		
	_is_unlocked = within_range
	
	visible = _is_unlocked
	process_mode = Node.PROCESS_MODE_INHERIT if _is_unlocked else Node.PROCESS_MODE_DISABLED

func on_hover(is_hov: bool) -> void:
	if not _is_unlocked:
		return
	
	self.is_hovered = is_hov
	
	if is_hov and _pricing_mode_active:
		_remove_outline()
	else:
		super.on_hover(is_hov)
	
	_update_label_visibility()
	
	if not is_hov:
		_reset_outline_color()

func on_interact() -> void:
	if not _is_unlocked or DragManager._is_dragging:
		return
	
	_update_local_stock()

	if not sachet_item:
		push_warning("[SachetContainerItem] No sachet_item assigned to %s" % name)
		return

	if InventoryManager.get_stock(sachet_item) <= 0:
		_play_error_animation()
		return

	if InventoryManager.take_item(sachet_item):
		_update_local_stock()
		var drag_item: DraggableItem = DRAGGABLE_ITEM_SCENE.instantiate()
		get_tree().current_scene.add_child(drag_item)
		drag_item.is_transient = true
		drag_item.setup(sachet_item, self.global_transform)
		drag_item.sprite.hide()
		DragManager.start_drag(drag_item, sachet_item.texture)

func _update_local_stock() -> void:
	if sachet_item:
		current_stock = InventoryManager.get_stock(sachet_item)
		max_stock = InventoryManager.get_max_stock(sachet_item)
	
	# Refresh UI if active
	if is_instance_valid(get_node_or_null("/root/PricingOverlay")) and is_hovered and _pricing_mode_active:
		update_pricing_ui()

# --- Private ---

func _reset_outline_color() -> void:
	if _outline_mat:
		_outline_mat.set_shader_parameter("outline_color", default_outline_color)

func _play_error_animation() -> void:
	_apply_outline(Color(1.0, 0.2, 0.2))

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
