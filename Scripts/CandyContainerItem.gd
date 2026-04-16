class_name CandyContainerItem
extends WorldInteractor

## An interactable candy bowl that spawns a random [DraggableItem] when clicked.
##
## On interact, picks a random in-stock candy from [member possible_candies],
## deducts one unit from [InventoryManager], and hands it off to [DragManager]
## as a transient item ready to drag to the transaction tray.

const DRAGGABLE_ITEM_SCENE: PackedScene = preload("res://Scenes/DraggableItem.tscn")
const INDER_FONT := preload("res://Assets/Fonts/Inder/Inder-Regular.ttf")

@export var possible_candies: Array[ItemData] = []
@export var max_stock: int = 5
var current_stock: int = 0
var _is_unlocked: bool = false



var is_hovered: bool = false
var _pricing_mode_active: bool = false

@onready var sprite: Sprite3D = $Sprite3D

func _ready() -> void:
	super._ready()
	add_to_group("pricing_ui_containers")
	# Set baseline settings for WorldInteractor
	billboard_collision = false
	
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
	if possible_candies.is_empty(): return
	
	# Use the first candy for range logic
	var ref_item = possible_candies[0]
	var base_price : float = ref_item.price
	var current_price : float = ref_item.get_final_price()
	
	var min_price : float = base_price
	var tier : int = ref_item.tier
	var max_margin : float = 0.25 + (float(max(1, tier)) - 1.0) * (0.25 / 9.0)
	var max_price : float = round(base_price * (1.0 + max_margin))
	
	var new_price : float = clamp(current_price + delta, min_price, max_price)
	
	# Update ALL candies in this container
	for candy in possible_candies:
		candy.selling_price = new_price
	
	# Refresh all pricing UIs
	get_tree().call_group("draggable_items", "update_pricing_ui")
	get_tree().call_group("pricing_ui_containers", "update_pricing_ui")

func update_pricing_ui() -> void:
	if possible_candies.is_empty(): return
	if not is_hovered or not _pricing_mode_active: return
	
	var ref_item = possible_candies[0]
	
	if is_instance_valid(get_node_or_null("/root/PricingOverlay")):
		var stock_info = "Stock: %d / %d" % [current_stock, max_stock]
		get_node("/root/PricingOverlay").show_item(ref_item, global_position, true, "Candies", stock_info)

func _update_label_visibility() -> void:
	if not _pricing_mode_active or not is_hovered:
		if is_instance_valid(get_node_or_null("/root/PricingOverlay")):
			get_node("/root/PricingOverlay").hide_ui()
	elif _pricing_mode_active and is_hovered:
		update_pricing_ui()

func _on_tier_advanced(_new_tier: int, _source: String) -> void:
	_check_unlock_status()

func _check_unlock_status() -> void:
	if possible_candies.is_empty():
		_is_unlocked = true
	else:
		var min_tier = 999
		for candy in possible_candies:
			if candy.tier < min_tier:
				min_tier = candy.tier
		_is_unlocked = min_tier <= StoryManager.current_tier
	
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

	var available_candies: Array[ItemData] = []
	for candy in possible_candies:
		if InventoryManager.get_stock(candy) > 0:
			available_candies.append(candy)

	if available_candies.is_empty():
		_play_error_animation()
		return

	var chosen_candy: ItemData = available_candies[randi() % available_candies.size()]

	if InventoryManager.take_item(chosen_candy):
		_update_local_stock()
		var drag_item: DraggableItem = DRAGGABLE_ITEM_SCENE.instantiate()
		get_tree().current_scene.add_child(drag_item)
		drag_item.is_transient = true
		drag_item.setup(chosen_candy, self.global_transform)
		drag_item.sprite.hide()
		DragManager.start_drag(drag_item, chosen_candy.texture)

func _update_local_stock() -> void:
	current_stock = 0
	for candy in possible_candies:
		current_stock += InventoryManager.get_stock(candy)
	# Also update max_stock from InventoryManager
	if not possible_candies.is_empty():
		max_stock = InventoryManager.get_max_stock(possible_candies[0])
	
	# Refresh UI if active
	if is_instance_valid(get_node_or_null("/root/PricingOverlay")) and is_hovered and _pricing_mode_active:
		update_pricing_ui()


# --- Private ---

## Reset outline to white.
func _reset_outline_color() -> void:
	if _outline_mat:
		_outline_mat.set_shader_parameter("outline_color", default_outline_color)

## Flash the outline red and shake the sprite to signal an empty stock error.
func _play_error_animation() -> void:
	_apply_outline(Color(1.0, 0.2, 0.2))

	var tween := create_tween()
	var base_x := sprite.position.x
	const INTENSITY := 0.05
	const STEP := 0.05
	tween.tween_property(sprite, "position:x", base_x - INTENSITY, STEP)
	tween.tween_property(sprite, "position:x", base_x + INTENSITY, STEP)
	tween.tween_property(sprite, "position:x", base_x - INTENSITY, STEP)
	tween.tween_property(sprite, "position:x", base_x + INTENSITY, STEP)
	tween.tween_property(sprite, "position:x", base_x, STEP)

	get_tree().create_timer(0.4).timeout.connect(_reset_outline_color)
