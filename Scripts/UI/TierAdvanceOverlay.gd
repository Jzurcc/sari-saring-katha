extends CanvasLayer

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var tier_label: Label = %TierLabel
@onready var source_label: Label = %SourceLabel
@onready var grid: GridContainer = %ItemGrid
@onready var control: Control = $Control

func _ready() -> void:
	control.visible = false
	EventBus.upgrade_available.connect(_on_upgrade_available)
	
	# Apply glassmorphic transparency to match the Alt/Pricing UI
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.082, 0.078, 0.071, 0.5) 
	style.set_corner_radius_all(20)
	var panel = $Control/Panel
	if panel:
		panel.add_theme_stylebox_override("panel", style)

func _on_upgrade_available(new_tier: int, cost: float) -> void:
	tier_label.text = "UPGRADE AVAILABLE (₱%.2f)" % cost
	source_label.text = "Call Uncle Mario to expand your catalog!"
	
	# Clear old items (grid is no longer used for notifications)
	for child in grid.get_children():
		child.queue_free()
	
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
