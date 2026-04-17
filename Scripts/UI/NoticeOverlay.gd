extends CanvasLayer

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var control: Control = $Control
@onready var panel: PanelContainer = %Panel

func _ready() -> void:
	print("[NoticeOverlay] Ready and listening for notifications...")
	control.visible = false
	EventBus.show_notification.connect(_on_show_notification)

func _on_show_notification(title: String, message: String, _sfx_name: String = "") -> void:
	title_label.text = title
	message_label.text = message
	
	_animate_in()

func _animate_in() -> void:
	# Ensure it's on top of everything
	layer = 100 
	control.visible = true
	
	# Reset state for animation
	panel.modulate.a = 0
	panel.scale = Vector2(0.7, 0.7)
	
	# Wait for Godot to calculate the new size based on the text
	await get_tree().process_frame
	await get_tree().process_frame # Double frame wait for safety with PanelContainers
	
	# Center horizontally
	var vp_size = get_viewport().get_visible_rect().size
	panel.position.x = (vp_size.x - panel.size.x) / 2.0
	panel.position.y = -panel.size.y # Start just above the top edge
	panel.pivot_offset = panel.size / 2.0
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "position:y", 40.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Auto dismiss
	await get_tree().create_timer(3.0).timeout
	_animate_out()

func _animate_out() -> void:
	if not control.visible: return
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, 0.25)
	tween.tween_property(panel, "position:y", -panel.size.y - 10, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	await tween.finished
	control.visible = false
