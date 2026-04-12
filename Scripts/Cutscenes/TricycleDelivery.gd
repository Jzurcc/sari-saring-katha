extends Node

var target_items: Dictionary
var sprite: Sprite3D
var _moving: bool = false
var _time: float = 0.0

var sfx_player: AudioStreamPlayer

const START_POS = Vector3(-15.299, 3.206, 11.855)
const TARGET_POS = Vector3(-15.299, 3.206, -6.055)
const EXIT_POS = Vector3(-15.299, 3.206, -13.901)

## how long before the tricycle arrives (in seconds)
const DELIVERY_DELAY_SEC := 2.0

var sfx_arrive: AudioStream = preload("res://Audio/SFX/motorcyle arrives and honks.mp3")
var sfx_leave: AudioStream = preload("res://Audio/SFX/motorcyle leaves.mp3")

func _ready() -> void:
	# Audio player for motorcycle SFX
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)

func start_delivery(items_to_restock: Dictionary) -> void:
	target_items = items_to_restock
	
	# Wait before the tricycle shows up
	print("[TricycleDelivery] Waiting %.0f seconds for delivery..." % DELIVERY_DELAY_SEC)
	await get_tree().create_timer(DELIVERY_DELAY_SEC).timeout
	
	# Create the sprite only now — it doesn't exist until delivery is triggered
	sprite = Sprite3D.new()
	sprite.pixel_size = 0.01
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.rotation_degrees.y = 90.0
	sprite.scale = Vector3(1.5, 1.5, 1.5)
	
	var tex = load("res://Assets/ui/mario_tricycle.png") if ResourceLoader.exists("res://Assets/ui/mario_tricycle.png") else null
	if tex:
		sprite.texture = tex
	else:
		push_warning("[TricycleDelivery] No tricycle texture found!")
	
	sprite.position = START_POS
	sprite.visible = true
	get_tree().current_scene.add_child(sprite)
	
	# ── Phase 1: Arrive ──────────────────────────────────────────────
	# Play the arrive + honk audio
	sfx_player.stream = sfx_arrive
	sfx_player.play()
	
	# Start driving toward the stop position
	_moving = true
	var arrive_tween = create_tween()
	arrive_tween.tween_property(sprite, "position:z", TARGET_POS.z, 3.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arrive_tween.parallel().tween_property(sprite, "position:x", TARGET_POS.x, 3.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await arrive_tween.finished
	_moving = false
	
	# Snap Y after bouncing
	sprite.position.y = TARGET_POS.y
	
	# Wait for the arrive + honk audio to fully finish before dialogue
	if sfx_player.playing:
		await sfx_player.finished
	
	# ── Phase 2: Dialogue ────────────────────────────────────────────
	# Uncle Mario says he's put the stocks in place
	if Dialogic.timeline_exists("UncleMario_Delivery"):
		Dialogic.timeline_ended.connect(_on_delivery_dialogue_ended, CONNECT_ONE_SHOT)
		Dialogic.start("UncleMario_Delivery")
	else:
		_on_delivery_dialogue_ended()

func _on_delivery_dialogue_ended() -> void:
	# ── Phase 3: Leave ───────────────────────────────────────────────
	# Play leave audio and drive away simultaneously
	sfx_player.stream = sfx_leave
	sfx_player.play()
	
	_moving = true
	var leave_tween = create_tween()
	leave_tween.tween_property(sprite, "position:z", EXIT_POS.z, 2.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await leave_tween.finished
	_moving = false
	
	# Wait for leave audio to finish before cleanup
	if sfx_player.playing:
		await sfx_player.finished
	
	# ── Phase 4: Restock & Cleanup ───────────────────────────────────
	for item in target_items.keys():
		var amount_ordered = target_items[item]
		var current_stock = InventoryManager.get_stock(item)
		InventoryManager.restock_item(item, current_stock + amount_ordered)
	
	_refresh_containers(get_tree().root)
	print("[TricycleDelivery] Delivery complete. Restocked shelf containers.")
	InventoryManager.save_state()
	
	sprite.queue_free()
	queue_free()

func _process(delta: float) -> void:
	if _moving:
		_time += delta * 20.0
		sprite.position.y = TARGET_POS.y + (abs(sin(_time)) * 0.15)

func _refresh_containers(node: Node) -> void:
	if node.has_method("refresh_visibility"):
		node.refresh_visibility()
	for child in node.get_children():
		_refresh_containers(child)
