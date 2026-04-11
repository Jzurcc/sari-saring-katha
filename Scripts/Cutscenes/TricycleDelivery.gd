extends Node

var target_items: Dictionary
var sprite: Sprite3D
var fade_rect: ColorRect
var canvas: CanvasLayer
var _moving: bool = false
var _time: float = 0.0

const START_POS = Vector3(-15.841, 1.909, 15.828)
const TARGET_POS = Vector3(-15.841, 1.909, -6.938)

func _ready() -> void:
	# 1. Setup Fade UI
	canvas = CanvasLayer.new()
	canvas.layer = 120 # above all other UI
	add_child(canvas)
	
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0) # transparent initially
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(fade_rect)
	
	# 2. Setup Sprite3D for tricycle
	sprite = Sprite3D.new()
	sprite.pixel_size = 0.02 # Scale down image appropriately for 3D world
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y # always face camera but keep upright
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD # enable proper cutout transparency
	
	# Load the tricycle asset prioritizing mario_tricycle.png
	var paths = [
		"res://Assets/ui/mario_tricycle.png",
		"res://Assets/ui/Mario_Tricycle.png",
		"res://Assets/ui/tricycle.png",
		"res://Assets/ui/Tricycle.png"
	]
	for path in paths:
		if ResourceLoader.exists(path):
			sprite.texture = load(path)
			break
			
	if not sprite.texture:
		push_warning("[TricycleDelivery] No tricycle texture found!")
		
	sprite.position = START_POS
	sprite.visible = false
	
	# Add the sprite dynamically to the current 3D scene tree
	get_tree().current_scene.add_child(sprite)

func start_delivery(items_to_restock: Dictionary) -> void:
	target_items = items_to_restock
	
	# Sequence: Fade Out -> Make Visible -> Fade In -> Animate -> Dialogue
	var t = create_tween()
	t.tween_property(fade_rect, "color:a", 1.0, 0.5)
	await t.finished
	
	# Wait a tiny bit while screen is black for natural breath
	await get_tree().create_timer(0.3).timeout
	
	sprite.visible = true
	
	# Fade back in to the world
	var t2 = create_tween()
	t2.tween_property(fade_rect, "color:a", 0.0, 0.5)
	await t2.finished
	
	# Start driving
	_moving = true
	var t3 = create_tween()
	# Move from 15.828 to -6.938 smoothly
	t3.tween_property(sprite, "position:z", TARGET_POS.z, 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t3.parallel().tween_property(sprite, "position:x", TARGET_POS.x, 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t3.finished
	_moving = false
	
	# Ensure it snaps to rest position at end of bumpy ride
	sprite.position.y = START_POS.y
	
	# Wait brief pause after stopping before talking
	await get_tree().create_timer(0.5).timeout
	
	# Start dialogue
	if Dialogic.timeline_exists("UncleMario_Delivery"):
		# In Godot 4 Dialogic, we can await the timeline
		Dialogic.timeline_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
		Dialogic.start("UncleMario_Delivery")
	else:
		_on_dialogue_ended()

func _process(delta: float) -> void:
	if _moving:
		_time += delta * 20.0 # Bouncing frequency
		# Add a subtle sine wave bounce (abs for only upward bouncing, 0.15 height)
		sprite.position.y = START_POS.y + (abs(sin(_time)) * 0.15)

func _on_dialogue_ended() -> void:
	# Fade out one last time
	var t = create_tween()
	t.tween_property(fade_rect, "color:a", 1.0, 0.5)
	await t.finished
	
	# Restock inventory items in the background
	for item in target_items.keys():
		var amount_ordered = target_items[item]
		var current_stock = InventoryManager.get_stock(item)
		InventoryManager.restock_item(item, current_stock + amount_ordered)
	
	_refresh_containers(get_tree().root)
	print("[TricycleDelivery] Delivery complete. Restocked shelf containers.")
	InventoryManager.save_state()
	
	# Fade back in to player view
	sprite.queue_free()
	var t2 = create_tween()
	t2.tween_property(fade_rect, "color:a", 0.0, 0.5)
	await t2.finished
	
	queue_free()

func _refresh_containers(node: Node) -> void:
	if node.has_method("refresh_visibility"):
		node.refresh_visibility()
	for child in node.get_children():
		_refresh_containers(child)
