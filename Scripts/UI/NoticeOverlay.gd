extends CanvasLayer

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var control: Control = $Control
@onready var panel: PanelContainer = %Panel

func _ready() -> void:
	print("[NoticeOverlay] Ready and listening for notifications...")
	control.visible = false
	
	# Create a default style for the "Toast" look
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.1, 0.9) # Slightly warmer dark background
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	style.shadow_size = 8
	style.shadow_color = Color(0, 0, 0, 0.3)
	panel.add_theme_stylebox_override("panel", style)
	
	# Apply soft beige theme and smaller header
	var beige := Color(0.92, 0.9, 0.78)
	title_label.add_theme_color_override("font_color", beige)
	message_label.add_theme_color_override("font_color", beige.lerp(Color.WHITE, 0.3))
	title_label.add_theme_font_size_override("font_size", 22)
	message_label.add_theme_font_size_override("font_size", 16)
	
	EventBus.show_notification.connect(_on_show_notification)

var _last_message: String = ""
var _last_show_time: float = 0.0

func _on_show_notification(title: String, message: String, sfx_name: String = "") -> void:
	# Debounce: Skip identical messages within 2 seconds to prevent spam
	var current_time = Time.get_ticks_msec() / 1000.0
	if message == _last_message and (current_time - _last_show_time) < 2.0:
		return
		
	_last_message = message
	_last_show_time = current_time
	
	title_label.text = title
	message_label.text = message
	
	if sfx_name != "":
		AudioManager.play_sfx(sfx_name)
	
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
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "position:y", 30.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Auto dismiss
	await get_tree().create_timer(2.5).timeout
	_animate_out()

func _animate_out() -> void:
	if not control.visible: return
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, 0.25)
	tween.tween_property(panel, "position:y", -panel.size.y - 10, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	await tween.finished
	control.visible = false
