class_name CandyContainerItem
extends WorldInteractor

## An interactable candy bowl that spawns a random [DraggableItem] when clicked.
##
## On interact, picks a random in-stock candy from [member possible_candies],
## deducts one unit from [InventoryManager], and hands it off to [DragManager]
## as a transient item ready to drag to the transaction tray.

const DRAGGABLE_ITEM_SCENE: PackedScene = preload("res://Scenes/DraggableItem.tscn")

@export var possible_candies: Array[ItemData] = []
@export var max_stock: int = 5
var current_stock: int = 0

@onready var sprite: Sprite3D = $Sprite3D

func _ready() -> void:
	super._ready()
	# Set baseline settings for WorldInteractor
	billboard_collision = true

func on_hover(is_hovered: bool) -> void:
	# Keep base behavior for standard outlines
	super.on_hover(is_hovered)
	
	if not is_hovered:
		_reset_outline_color()

func on_interact() -> void:
	if DragManager._is_dragging:
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
