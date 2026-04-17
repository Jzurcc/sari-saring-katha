extends CanvasLayer

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var tier_label: Label = %TierLabel
@onready var source_label: Label = %SourceLabel
@onready var grid: HFlowContainer = %ItemGrid
@onready var control: Control = $Control

var sfx_player: AudioStreamPlayer
var stream_notification = preload("res://Audio/SFX/ui_sfx_7.mp3")

func _ready() -> void:
	control.visible = false
	EventBus.upgrade_available.connect(_on_upgrade_available)
	
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	sfx_player.stream = stream_notification
	# The Panel's background color is now controlled purely via the Godot Editor Theme Overrides.

func _input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_J and not event.echo:
		print("[TierAdvanceOverlay] DEBUG: Triggering test notification...")
		var test_items: Array[ItemData] = [
			preload("res://Resources/items/bottle/Water.tres"),
			preload("res://Resources/items/frozen/Nagets.tres"),
			preload("res://Resources/items/frozen/Tocino.tres")
		]
		_on_upgrade_available(2, 250.0, test_items)

func _on_upgrade_available(_new_tier: int, cost: float, items: Array[ItemData]) -> void:
	tier_label.text = "UPGRADE AVAILABLE (₱%.2f)" % cost
	source_label.text = "Call Uncle Mario to expand your catalog!"
	
	# Clear old items
	for child in grid.get_children():
		child.queue_free()
	
	# Add new item icons
	for item in items:
		var tex = TextureRect.new()
		tex.texture = item.texture
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(72, 72)
		grid.add_child(tex)
	
	# Play sound
	sfx_player.play()
	
	# VFX: Rank Up Fanfare (3D) spawned in front of the camera
	var cam = get_viewport().get_camera_3d()
	if cam:
		var spawn_pos = cam.global_position + (-cam.global_transform.basis.z * 2.5)
		VisualEffectManager.spawn_rank_up_fanfare(spawn_pos)
	
	# Visual Fanfare (Tween)
	var panel = $Control/Panel
	control.visible = true
	
	# Wait one frame so PanelContainer calculates its minimum size from children
	await get_tree().process_frame
	
	# Center horizontally at the top of the viewport
	var vp_width = get_viewport().get_visible_rect().size.x
	var panel_width = panel.size.x
	panel.position.x = (vp_width - panel_width) / 2.0
	panel.pivot_offset = panel.size / 2.0  # Pivot at center for scale animation
	
	panel.modulate.a = 0
	panel.scale = Vector2(0.8, 0.8)
	panel.position.y = -panel.size.y  # Start above screen
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.4)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "position:y", 20.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Wait 2 seconds then auto-dismiss
	await get_tree().create_timer(2.5).timeout
	_on_close_pressed()

func _on_close_pressed() -> void:
	if not control.visible: return
	
	var panel = $Control/Panel
	var tween = create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_property(panel, "position:y", -panel.size.y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	control.visible = false
