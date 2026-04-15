class_name SachetContainerItem
extends WorldInteractor

## An interactable sachet strip or box that spawns a [DraggableItem] when clicked.
##
## Unlike [CandyContainerItem], this is dedicated to a single [ItemData] sachet type.
## It pulls stock from the global [InventoryManager].

const DRAGGABLE_ITEM_SCENE: PackedScene = preload("res://Scenes/DraggableItem.tscn")

@export var sachet_item: ItemData
@export var max_stock: int = 5
var _is_unlocked: bool = false
var current_stock: int = 0

@onready var sprite: Sprite3D = $Sprite3D

func _ready() -> void:
	super._ready()
	# Ensure the container faces the camera for easier interaction
	billboard_collision = true
	
	EventBus.tier_advanced.connect(_on_tier_advanced)
	_check_unlock_status()

func _on_tier_advanced(_new_tier: int, _source: String) -> void:
	_check_unlock_status()

func _check_unlock_status() -> void:
	if not sachet_item:
		_is_unlocked = true
	else:
		_is_unlocked = sachet_item.tier <= StoryManager.current_tier
	
	visible = _is_unlocked
	process_mode = Node.PROCESS_MODE_INHERIT if _is_unlocked else Node.PROCESS_MODE_DISABLED

func on_hover(is_hovered: bool) -> void:
	if not _is_unlocked:
		return
		
	super.on_hover(is_hovered)
	if not is_hovered:
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
