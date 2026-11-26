extends ColorRect

signal confirmed
signal cancelled

@onready var panel_box    : PanelContainer = $PanelContainer
@onready var title_label  : Label = $PanelContainer/MarginContainer/VBoxContainer/Title
@onready var message_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Message
@onready var confirm_btn  : Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_btn   : Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/CancelButton

# UI Sounds
var _sfx_click   : AudioStream = preload("res://Audio/SFX/ui_sfx_4.mp3")
var _sfx_confirm : AudioStream = preload("res://Audio/SFX/ui_sfx_9.mp3")
var _ui_player   : AudioStreamPlayer
var _anim_tween  : Tween = null

func _ready() -> void:
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = "SFX"
	add_child(_ui_player)

	_apply_modern_style()
	confirm_btn.pressed.connect(_on_confirm_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	hide()

func _apply_modern_style() -> void:
	color = Color(0.03, 0.024, 0.02, 0.76)

	var ps := UIStyle.create_flat_stylebox(Color(0.088, 0.074, 0.062, 0.97), 14, 28, 24)
	ps.border_color = Color(0.86, 0.67, 0.32, 0.85)
	ps.set_border_width_all(2)
	ps.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	ps.shadow_size = 20
	ps.shadow_offset = Vector2(0, 8)
	panel_box.add_theme_stylebox_override("panel", ps)

	title_label.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62, 1.0))

	message_label.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.82, 0.94))

	for btn in [confirm_btn, cancel_btn]:
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(148, 44)
		btn.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
		btn.add_theme_font_size_override("font_size", 18)

	_style_modal_btn(confirm_btn, Color(0.76, 0.28, 0.24, 0.95), Color(0.96, 0.48, 0.42, 0.95), Color(1.0, 0.95, 0.88, 1.0))
	_style_modal_btn(cancel_btn, Color(0.16, 0.135, 0.11, 0.95), Color(0.86, 0.67, 0.32, 0.72), Color(0.96, 0.91, 0.82, 1.0))

func _style_modal_btn(btn: Button, bg: Color, border: Color, fg: Color) -> void:
	var st := UIStyle.create_flat_stylebox(bg, 10, 18, 8)
	st.border_color = border
	st.set_border_width_all(1)
	var hov := st.duplicate() as StyleBoxFlat
	hov.bg_color = bg.lightened(0.12)
	hov.border_color = border.lightened(0.15)
	var prs := st.duplicate() as StyleBoxFlat
	prs.bg_color = bg.darkened(0.10)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", prs)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	btn.add_theme_color_override("font_pressed_color", fg)

func open(title: String, message: String) -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	title_label.text = title
	message_label.text = message
	show()
	modulate.a = 0.0
	panel_box.pivot_offset = panel_box.size * 0.5
	panel_box.scale = Vector2(0.94, 0.94)
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(self, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(panel_box, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	cancel_btn.grab_focus()

func close() -> void:
	hide()

func _on_confirm_pressed() -> void:
	_play_confirm()
	confirmed.emit()
	close()

func _on_cancel_pressed() -> void:
	_play_click()
	cancelled.emit()
	close()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()

func _play_click() -> void:
	_ui_player.stream = _sfx_click
	_ui_player.play()

func _play_confirm() -> void:
	_ui_player.stream = _sfx_confirm
	_ui_player.play()
