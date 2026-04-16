extends CanvasLayer

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var tier_label: Label = %TierLabel
@onready var source_label: Label = %SourceLabel
@onready var grid: GridContainer = %ItemGrid
@onready var control: Control = $Control

var sfx_player: AudioStreamPlayer
var stream_notification = preload("res://Audio/SFX/ui_sfx_7.mp3")

func _ready() -> void:
	control.visible = false
	EventBus.upgrade_available.connect(_on_upgrade_available)
	
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	sfx_player.stream = stream_notification
	
	# Apply glassmorphic transparency to match the Alt/Pricing UI
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.082, 0.078, 0.071, 0.5) 
	style.set_corner_radius_all(20)
	var panel = $Control/Panel
	if panel:
		panel.add_theme_stylebox_override("panel", style)

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
		tex.custom_minimum_size = Vector2(48, 48)
		grid.add_child(tex)
	
	# Play sound
	sfx_player.play()
	
	# VFX: Rank Up Fanfare (3D) spawned in front of the camera
	var cam = get_viewport().get_camera_3d()
	if cam:
		var spawn_pos = cam.global_position + (-cam.global_transform.basis.z * 2.5)
		VisualEffectManager.spawn_rank_up_fanfare(spawn_pos)
	
	# Position at TOP (Notification Style)
	control.anchor_left = 0.5
	control.anchor_right = 0.5
	control.anchor_top = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = -200 # Assuming a 400px wide panel
	control.offset_right = 200
	control.offset_top = 20
	control.offset_bottom = 150
	
	# Visual Fanfare (Tween)
	control.visible = true
	control.modulate.a = 0
	control.scale = Vector2(0.8, 0.8)
	control.pivot_offset = Vector2(200, 0) # Pivot at the top-center
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, 0.4)
	tween.tween_property(control, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "offset_top", 40.0, 0.4).from(0.0)
	
	# Wait 2 seconds then auto-dismiss
	await get_tree().create_timer(2.5).timeout
	_on_close_pressed()

func _on_close_pressed() -> void:
	if not control.visible: return
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(control, "modulate:a", 0.0, 0.4)
	tween.tween_property(control, "offset_top", 0.0, 0.4)
	await tween.finished
	control.visible = false
