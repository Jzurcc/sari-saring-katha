extends Control

@onready var buttons = $Buttons
var target_scene = "res://Scenes/MainGame.tscn"
var original_styles = {}

var cam: Camera3D = null
var cam_origin_rot: Vector3
var cam_origin_pos: Vector3
var is_starting_game: bool = false
var pan_sensitivity: float = 0.5
var current_offset_x: float = 0.0
var current_offset_y: float = 0.0


func _ready() -> void:
	if has_node("TitleScreen3D/Camera3D"):
		cam = $TitleScreen3D/Camera3D
		cam_origin_rot = cam.rotation
		cam_origin_pos = cam.position
		
	for btn in buttons.get_children():
		if btn is Button:
			original_styles[btn] = {
				"font_color": btn.get_theme_color("font_color"),
				"shadow_color": btn.get_theme_color("font_shadow_color"),
				"outline_color": btn.get_theme_color("font_outline_color"),
				"outline_size": btn.get_theme_constant("outline_size"),
				"shadow_x": btn.get_theme_constant("shadow_offset_x"),
				"shadow_y": btn.get_theme_constant("shadow_offset_y")
			}
			btn.mouse_entered.connect(_on_btn_hover.bind(btn))
			btn.mouse_exited.connect(_on_btn_unhover.bind(btn))
			btn.focus_entered.connect(_on_btn_hover.bind(btn))
			btn.focus_exited.connect(_on_btn_unhover.bind(btn))
	buttons.get_node("NewGame").grab_focus()

func _on_btn_hover(btn: Button) -> void:
	# Change font color to pure white
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	# Remove outline stroke completely
	btn.add_theme_constant_override("outline_size", 0)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))

func _on_btn_unhover(btn: Button) -> void:
	var orig = original_styles[btn]
	btn.add_theme_color_override("font_color", orig["font_color"])
	btn.add_theme_color_override("font_shadow_color", orig["shadow_color"])
	btn.add_theme_color_override("font_outline_color", orig["outline_color"])
	btn.add_theme_constant_override("outline_size", orig["outline_size"])

func _process(delta: float) -> void:
	if is_starting_game or cam == null:
		return
		
	var mouse_pos = get_viewport().get_mouse_position()
	var window_size = get_viewport().get_visible_rect().size
	
	var is_hovering_menu = buttons.get_global_rect().has_point(mouse_pos)
	
	if not is_hovering_menu:
		# Mapped from -1.0 to 1.0 based on screen center
		current_offset_x = (mouse_pos.x / window_size.x) * 2.0 - 1.0
		current_offset_y = (mouse_pos.y / window_size.y) * 2.0 - 1.0
	
	var target_rot_x = cam_origin_rot.x - (current_offset_y * pan_sensitivity)
	var target_rot_y = cam_origin_rot.y - (current_offset_x * pan_sensitivity)
	
	var target_pos_x = cam_origin_pos.x + (current_offset_x * 0.05)
	var target_pos_y = cam_origin_pos.y - (current_offset_y * 0.05)
	
	# Smoothly interpolate the camera's transform
	cam.rotation.x = lerp(cam.rotation.x, target_rot_x, delta * 3.0)
	cam.rotation.y = lerp(cam.rotation.y, target_rot_y, delta * 3.0)
	cam.position.x = lerp(cam.position.x, target_pos_x, delta * 3.0)
	cam.position.y = lerp(cam.position.y, target_pos_y, delta * 3.0)

func _on_new_game_pressed() -> void:
	is_starting_game = true
	buttons.hide()
	$LeftVignette.hide()
	
	if cam == null:
		get_tree().change_scene_to_file(target_scene)
		return
		
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var target_pos = Vector3(-1.638, 4.1, -0.05)
	var target_rot = Vector3(0, deg_to_rad(90.0), 0)
	
	tween.set_parallel(true)
	tween.tween_property(cam, "position", target_pos, 1.8)
	tween.tween_property(cam, "rotation", target_rot, 1.8)
	tween.tween_property(cam, "fov", 75.0, 1.8)
	tween.tween_property(cam, "near", 0.05, 1.8)
	tween.tween_property(cam, "far", 4000.0, 1.8)
	tween.set_parallel(false)
	
	tween.chain().tween_callback(_on_pan_finished)

func _on_pan_finished() -> void:
	get_tree().change_scene_to_file(target_scene)

func _on_options_pressed() -> void:
	$OptionsOverlay.show()

func _on_options_close_pressed() -> void:
	$OptionsOverlay.hide()

func _on_exit_pressed() -> void:
	get_tree().quit()
