extends Control

@onready var buttons = $Buttons

# Standalone UI components
@onready var options_overlay : Control = $OptionsOverlay
@onready var confirm_overlay : Control = $ConfirmationOverlay

const MENU_FONT_PATH := "res://Assets/Fonts/Fredoka/Fredoka-SemiBold.ttf"
const BODY_FONT := preload("res://Assets/Fonts/Fredoka/Fredoka-Regular.ttf")
const LIGHT_FONT := preload("res://Assets/Fonts/Fredoka/Fredoka-Light.ttf")
const SEMIBOLD_FONT := preload("res://Assets/Fonts/Fredoka/Fredoka-SemiBold.ttf")

const GAME_VERSION := "v0.4.2 · Early Build"
const DEVLOG_TITLE := "Dev News"
const DEVLOG_SUBTITLE := "Latest Storefront Update"
const DEVLOG_ENTRIES: Array[String] = [
	"Modernized Price Ledger with interactive step gauges & active effect cards",
	"Cozy skribbl-style Storefront Drawing Studio with Stamp Mode & custom uploads",
	"Papa Ulap's Radio now broadcasts Daily Visitor sightings alongside Market Events",
	"Added Wholesale Pass II & Recycling Program upgrades to the Store Upgrade Tree",
]

const COL_ESPRESSO := Color(0.068, 0.056, 0.046, 0.88)
const COL_GOLD := Color(0.86, 0.67, 0.32, 0.85)
const COL_GOLD_BRIGHT := Color(1.0, 0.89, 0.58, 1.0)
const COL_CREAM := Color(1.0, 0.94, 0.84, 1.0)
const COL_CREAM_MUTED := Color(0.86, 0.79, 0.69, 0.88)

var target_scene = "res://Scenes/IntroCutscene.tscn"
var original_styles = {}

var cam: Camera3D = null
var cam_origin_rot: Vector3
var cam_origin_pos: Vector3
var is_starting_game: bool = false
var pan_sensitivity: float = 0.15
var current_offset_x: float = 0.0
var current_offset_y: float = 0.0

var _menu_font: Font
var _bold_body: FontVariation
var _gradient_vignette: TextureRect
var _hover_diamond: Label
var _devlog_panel: PanelContainer
var _devlog_body: VBoxContainer
var _devlog_toggle_btn: Button
var _version_lbl: Label
var _btn_tweens: Dictionary = {}
var _glow_tween: Tween = null
var _active_btn: Button = null

# ── UI Sound ─────────────────────────────────────────────────────────────────
var _sfx_click : AudioStream = preload("res://Audio/SFX/ui_sfx_4.mp3")
var _sfx_hover : AudioStream = preload("res://Audio/SFX/ui_sfx_12.mp3")
var _ui_player : AudioStreamPlayer


# ─── Ready ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_menu_font = load(MENU_FONT_PATH) if ResourceLoader.exists(MENU_FONT_PATH) else BODY_FONT
	_bold_body = FontVariation.new()
	_bold_body.base_font = SEMIBOLD_FONT

	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = "SFX"
	add_child(_ui_player)

	options_overlay.hide()
	options_overlay.closed.connect(_on_options_closed)
	confirm_overlay.confirmed.connect(_on_new_game_confirmed)
	confirm_overlay.cancelled.connect(func(): _update_menu_interaction(true))

	if has_node("TitleScreen3D/Camera3D"):
		cam = $TitleScreen3D/Camera3D
		cam_origin_rot = cam.rotation
		cam_origin_pos = cam.position

	_build_directional_vignette()
	_build_hover_glow()
	_build_devlog_and_version()

	# Hook up button hover glow + slide + click sound
	for btn in buttons.get_children():
		if btn is Button:
			_register_button(btn)

	# Show Continue only if a save file exists
	var continue_btn = buttons.get_node_or_null("Continue")
	var new_game_btn = buttons.get_node("NewGame")
	var can_continue = continue_btn != null and SaveManager.has_save()

	if continue_btn:
		continue_btn.visible = can_continue

	_play_entrance_animation()

	if can_continue:
		continue_btn.grab_focus()
	else:
		new_game_btn.grab_focus()


# ─── Modern Atmospheric Framing, Glow, Dev Notes & Version ───────────────────

func _build_directional_vignette() -> void:
	# Soft left-edge gradient only so the sunny 3D sari-sari storefront stays bright & vibrant
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.34, 0.62, 1.0])
	grad.colors = PackedColorArray([
		Color(0.04, 0.028, 0.018, 0.68),
		Color(0.04, 0.028, 0.018, 0.24),
		Color(0.04, 0.028, 0.018, 0.0),
		Color(0.04, 0.028, 0.018, 0.16),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 512
	tex.height = 16
	tex.fill_from = Vector2(0.0, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)

	_gradient_vignette = TextureRect.new()
	_gradient_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gradient_vignette.texture = tex
	_gradient_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gradient_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gradient_vignette)
	move_child(_gradient_vignette, buttons.get_index())


func _build_hover_glow() -> void:
	# Glowing antique-gold diamond marker beside the active menu item
	_hover_diamond = Label.new()
	_hover_diamond.text = "◆"
	_hover_diamond.add_theme_font_override("font", BODY_FONT)
	_hover_diamond.add_theme_font_size_override("font_size", 22)
	_hover_diamond.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	_hover_diamond.add_theme_color_override("font_outline_color", Color(0.18, 0.10, 0.04, 0.90))
	_hover_diamond.add_theme_constant_override("outline_size", 3)
	_hover_diamond.modulate.a = 0.0
	_hover_diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hover_diamond)


func _build_devlog_and_version() -> void:
	# Calm top-right Dev News card tucked cleanly away from the storefront
	_devlog_panel = PanelContainer.new()
	_devlog_panel.anchor_left = 1.0
	_devlog_panel.anchor_right = 1.0
	_devlog_panel.anchor_top = 0.0
	_devlog_panel.anchor_bottom = 0.0
	_devlog_panel.offset_left = -384.0
	_devlog_panel.offset_right = -32.0
	_devlog_panel.offset_top = 28.0
	_devlog_panel.grow_vertical = Control.GROW_DIRECTION_END
	var st := UIStyle.create_flat_stylebox(COL_ESPRESSO, 12, 18, 14)
	st.border_color = COL_GOLD
	st.set_border_width_all(1)
	st.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	st.shadow_size = 12
	_devlog_panel.add_theme_stylebox_override("panel", st)
	add_child(_devlog_panel)
	move_child(_devlog_panel, options_overlay.get_index())

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_devlog_panel.add_child(vb)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	vb.add_child(hdr)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 2)
	hdr.add_child(title_col)

	var title_lbl := Label.new()
	title_lbl.text = DEVLOG_TITLE
	title_lbl.add_theme_font_override("font", _bold_body)
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	title_col.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = DEVLOG_SUBTITLE
	sub_lbl.add_theme_font_override("font", LIGHT_FONT)
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	title_col.add_child(sub_lbl)

	_devlog_toggle_btn = Button.new()
	_devlog_toggle_btn.text = "▴"
	_devlog_toggle_btn.custom_minimum_size = Vector2(30, 30)
	_devlog_toggle_btn.focus_mode = Control.FOCUS_NONE
	_devlog_toggle_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_devlog_toggle_btn.tooltip_text = "Collapse / Expand Dev News"
	UIStyle.style_button(_devlog_toggle_btn, Color(0.14, 0.11, 0.09, 0.85), COL_CREAM_MUTED, 15.0, 6)
	_devlog_toggle_btn.pressed.connect(func():
		_play_click()
		_devlog_body.visible = not _devlog_body.visible
		_devlog_toggle_btn.text = "▴" if _devlog_body.visible else "▾"
	)
	hdr.add_child(_devlog_toggle_btn)

	_devlog_body = VBoxContainer.new()
	_devlog_body.add_theme_constant_override("separation", 7)
	vb.add_child(_devlog_body)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.32)
	_devlog_body.add_child(sep)

	for entry in DEVLOG_ENTRIES:
		var lbl := Label.new()
		lbl.text = "▸ " + entry
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_override("font", BODY_FONT)
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", COL_CREAM)
		_devlog_body.add_child(lbl)

	# Subtle Version Tag tucked in bottom-right corner
	var proj_ver: String = str(ProjectSettings.get_setting("application/config/version", ""))
	_version_lbl = Label.new()
	_version_lbl.text = ("v%s" % proj_ver) if proj_ver != "" else GAME_VERSION
	_version_lbl.anchor_left = 1.0
	_version_lbl.anchor_right = 1.0
	_version_lbl.anchor_top = 1.0
	_version_lbl.anchor_bottom = 1.0
	_version_lbl.offset_left = -260.0
	_version_lbl.offset_right = -34.0
	_version_lbl.offset_top = -38.0
	_version_lbl.offset_bottom = -16.0
	_version_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_version_lbl.add_theme_font_override("font", LIGHT_FONT)
	_version_lbl.add_theme_font_size_override("font_size", 13)
	_version_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.84, 0.62))
	_version_lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.02, 0.80))
	_version_lbl.add_theme_constant_override("outline_size", 2)
	_version_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_version_lbl)
	move_child(_version_lbl, options_overlay.get_index())


func _play_entrance_animation() -> void:
	var idx := 0
	for child in buttons.get_children():
		if child is Button and child.visible:
			child.modulate.a = 0.0
			var tw := create_tween()
			tw.tween_interval(0.08 + idx * 0.06)
			tw.tween_property(child, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			idx += 1
	if is_instance_valid(_devlog_panel):
		_devlog_panel.modulate.a = 0.0
		var dtw := create_tween()
		dtw.tween_interval(0.22)
		dtw.tween_property(_devlog_panel, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ─── UI Sound helpers ─────────────────────────────────────────────────────────

func _play_click() -> void:
	_ui_player.stream = _sfx_click
	_ui_player.play()

func _play_hover() -> void:
	_ui_player.stream = _sfx_hover
	_ui_player.play()

func _register_button(btn: Button) -> void:
	btn.add_theme_font_override("font", _menu_font)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	original_styles[btn] = {
		"font_color":    Color(0.98, 0.90, 0.76, 0.94),
		"shadow_color":  Color(0.12, 0.07, 0.03, 0.72),
		"outline_color": Color(0.24, 0.14, 0.06, 0.90),
		"outline_size":  4,
	}
	btn.add_theme_color_override("font_color", original_styles[btn]["font_color"])
	btn.add_theme_color_override("font_outline_color", original_styles[btn]["outline_color"])
	btn.add_theme_constant_override("outline_size", 4)
	btn.add_theme_color_override("font_shadow_color", original_styles[btn]["shadow_color"])
	btn.add_theme_constant_override("shadow_offset_x", 0)
	btn.add_theme_constant_override("shadow_offset_y", 3)

	btn.mouse_entered.connect(_on_btn_hover.bind(btn))
	btn.mouse_exited.connect(_on_btn_unhover.bind(btn))
	btn.focus_entered.connect(_on_btn_hover.bind(btn))
	btn.focus_exited.connect(_on_btn_unhover.bind(btn))

	if not btn.disabled:
		btn.pressed.connect(_play_click)


# ─── Button hover glow & slide juice ──────────────────────────────────────────

func _on_btn_hover(btn: Button) -> void:
	_active_btn = btn
	_play_hover()
	btn.add_theme_color_override("font_color", Color(1.0, 0.99, 0.94, 1.0))
	btn.add_theme_color_override("font_outline_color", Color(0.86, 0.62, 0.20, 0.95))
	btn.add_theme_constant_override("outline_size", 3)
	btn.add_theme_color_override("font_shadow_color", Color(1.0, 0.78, 0.32, 0.65))
	btn.add_theme_constant_override("shadow_offset_y", 0)
	btn.add_theme_constant_override("shadow_outline_size", 10)

	# Smooth subtle scale-lift
	btn.pivot_offset = Vector2(0.0, btn.size.y * 0.5)
	_tween_btn_scale(btn, Vector2(1.06, 1.06))
	call_deferred("_move_glow_to", btn)


func _on_btn_unhover(btn: Button) -> void:
	var orig: Dictionary = original_styles[btn]
	btn.add_theme_color_override("font_color", orig["font_color"])
	btn.add_theme_color_override("font_outline_color", orig["outline_color"])
	btn.add_theme_constant_override("outline_size", orig["outline_size"])
	btn.add_theme_color_override("font_shadow_color", orig["shadow_color"])
	btn.add_theme_constant_override("shadow_offset_y", 3)
	btn.add_theme_constant_override("shadow_outline_size", 0)
	_tween_btn_scale(btn, Vector2.ONE)


func _tween_btn_scale(btn: Button, target: Vector2) -> void:
	var prev: Tween = _btn_tweens.get(btn)
	if prev and prev.is_valid():
		prev.kill()
	var tw := create_tween()
	tw.tween_property(btn, "scale", target, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_btn_tweens[btn] = tw


func _move_glow_to(btn: Button) -> void:
	if not is_instance_valid(btn) or not is_instance_valid(_hover_diamond) or not btn.is_visible_in_tree():
		return
	var r := btn.get_global_rect()
	var dia_pos := Vector2(r.position.x - 32.0, r.position.y + r.size.y * 0.5 - 15.0)

	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = create_tween().set_parallel(true)
	_glow_tween.tween_property(_hover_diamond, "global_position", dia_pos, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_glow_tween.tween_property(_hover_diamond, "modulate:a", 1.0, 0.14)


# ─── Camera parallax pan ───────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if is_starting_game or cam == null:
		return

	var mouse_pos   = get_viewport().get_mouse_position()
	var window_size = get_viewport().get_visible_rect().size

	current_offset_x = (mouse_pos.x / window_size.x) * 2.0 - 1.0
	current_offset_y = (mouse_pos.y / window_size.y) * 2.0 - 1.0

	var target_rot_x = cam_origin_rot.x - (current_offset_y * pan_sensitivity)
	var target_rot_y = cam_origin_rot.y - (current_offset_x * pan_sensitivity)

	var target_pos_x = cam_origin_pos.x + (current_offset_x * 0.02)
	var target_pos_y = cam_origin_pos.y - (current_offset_y * 0.02)

	cam.rotation.x = lerp(cam.rotation.x, target_rot_x, delta * 3.0)
	cam.rotation.y = lerp(cam.rotation.y, target_rot_y, delta * 3.0)
	cam.position.x = lerp(cam.position.x, target_pos_x, delta * 3.0)
	cam.position.y = lerp(cam.position.y, target_pos_y, delta * 3.0)


# ─── Actions ──────────────────────────────────────────────────────────────────

func _on_new_game_pressed() -> void:
	if SaveManager.has_save():
		_play_click()
		confirm_overlay.open("New Game", "Are you sure you want to start a new game? This will overwrite your current progress.")
		_update_menu_interaction(false)
		return
	_start_new_game()

func _on_new_game_confirmed() -> void:
	_start_new_game()

func _start_new_game() -> void:
	SaveManager.reset_all_state()
	_transition_to_game(target_scene)

func _on_continue_pressed() -> void:
	if SaveManager.has_save():
		_transition_to_game("res://Scenes/MainGame.tscn")

func _transition_to_game(scene_path: String) -> void:
	is_starting_game = true
	buttons.hide()
	if is_instance_valid(_hover_diamond):
		_hover_diamond.hide()
	if is_instance_valid(_devlog_panel):
		_devlog_panel.hide()
	if is_instance_valid(_version_lbl):
		_version_lbl.hide()
	if is_instance_valid(_gradient_vignette):
		_gradient_vignette.hide()
	SceneTransition.change_scene(scene_path)

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_options_pressed() -> void:
	options_overlay.open()
	_update_menu_interaction(false)

func _on_options_closed() -> void:
	_update_menu_interaction(true)

func _update_menu_interaction(enabled: bool) -> void:
	var mode = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	buttons.mouse_filter = mode
	for child in buttons.get_children():
		if child is Control:
			child.mouse_filter = mode
	if is_instance_valid(_devlog_panel):
		_devlog_panel.mouse_filter = mode
