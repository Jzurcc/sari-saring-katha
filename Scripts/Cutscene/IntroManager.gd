extends Node

@export_file("*.tscn") var next_scene_path: String = "res://Scenes/MainGame.tscn"

@onready var sequences_container = $Sequences
@onready var camera: Camera3D = $Camera3D
@onready var bgm_player = $AudioStreamPlayer
@onready var fade_rect: ColorRect = $CanvasLayer/ColorRect
@onready var subtitle_label: Label = $CanvasLayer/SubtitleContainer/SubtitleLabel
@onready var subtitle_container: Control = $CanvasLayer/SubtitleContainer
@onready var indicator: Label = $CanvasLayer/IndicatorLabel
@onready var skip_button: Button = %SkipButton
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@export var characters_per_second: float = 28.0

const COL_ESPRESSO := Color(0.06, 0.052, 0.046, 0.88)
const COL_GOLD := Color(0.835, 0.624, 0.278, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.875, 0.56, 1.0)
const COL_CREAM := Color(1.0, 0.922, 0.792, 1.0)
const LETTERBOX_HEIGHT_RATIO := 0.135

signal player_clicked

var waiting_for_input: bool = false
var fast_forwarding: bool = false
var _is_skipping: bool = false
var _skip_fade_tween: Tween
var _is_mouse_over_skip: bool = false
var _indicator_tween: Tween = null

# Living camera state
var _base_cam_pos: Vector3 = Vector3.ZERO
var _base_cam_quat: Quaternion = Quaternion.IDENTITY
var _cam_active: bool = false
var _breathe_time: float = 0.0
var _base_fov: float = 75.0
var _fov_tween: Tween = null

# Procedural cinematic UI elements
var _vignette_rect: ColorRect = null
var _bar_top: ColorRect = null
var _bar_bottom: ColorRect = null
var _progress_box: HBoxContainer = null
var _progress_dots: Array[Panel] = []
var _sequences: Array[CutsceneSequence] = []
var _current_seq_idx: int = 0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	fade_rect.color = Color(0, 0, 0, 1) # Start fully black
	subtitle_label.text = ""
	subtitle_label.visible_ratio = 0.0
	indicator.hide()
	if camera:
		_base_fov = camera.fov

	if bgm_player and bgm_player.stream:
		# Stop local BGM to let AudioManager's Autumn Wind play continuously without overlap
		bgm_player.stop()

	for child in sequences_container.get_children():
		if child is CutsceneSequence:
			_sequences.append(child)

	_build_cinematic_chrome()
	_style_controls_ui()

	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)
		var skip_area := skip_button.get_parent() as Control
		if skip_area:
			skip_area.mouse_filter = Control.MOUSE_FILTER_STOP
			skip_area.mouse_entered.connect(_on_skip_mouse_entered)
			skip_area.mouse_exited.connect(_on_skip_mouse_exited)
		skip_button.mouse_entered.connect(_on_skip_mouse_entered)
		skip_button.mouse_exited.connect(_on_skip_mouse_exited)
		_fade_out_skip_button()

	play_all_sequences()


func _process(delta: float) -> void:
	if not _cam_active or not is_instance_valid(camera):
		return
	_breathe_time += delta
	# Gentle living handheld breathing so the shot never freezes dead still
	var sway := Vector3(
		sin(_breathe_time * 0.55) * 0.032,
		cos(_breathe_time * 0.42) * 0.022,
		sin(_breathe_time * 0.31) * 0.018
	)
	var pitch_rad := deg_to_rad(sin(_breathe_time * 0.38) * 0.22)
	var yaw_rad := deg_to_rad(cos(_breathe_time * 0.29) * 0.26)
	var micro_q := Quaternion.from_euler(Vector3(pitch_rad, yaw_rad, 0.0))
	camera.global_position = _base_cam_pos + sway
	camera.global_basis = Basis(_base_cam_quat * micro_q)


func _build_cinematic_chrome() -> void:
	if not is_instance_valid(canvas_layer):
		return

	# 1. Warm golden-hour vignette + soft bottom subtitle scrim (underneath text & fade)
	_vignette_rect = ColorRect.new()
	_vignette_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vig_shader := Shader.new()
	vig_shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	vec2 centered = uv - vec2(0.5);
	float dist = length(centered * vec2(1.15, 1.0));
	float vig = smoothstep(0.42, 0.92, dist) * 0.52;
	float bottom_scrim = smoothstep(0.66, 0.96, uv.y) * 0.58;
	float alpha = clamp(max(vig, bottom_scrim), 0.0, 0.82);
	COLOR = vec4(0.045, 0.032, 0.022, alpha);
}
"""
	var vig_mat := ShaderMaterial.new()
	vig_mat.shader = vig_shader
	_vignette_rect.material = vig_mat
	canvas_layer.add_child(_vignette_rect)
	canvas_layer.move_child(_vignette_rect, 0)

	# 2. Animated cinema letterbox bars (slide in smoothly on start)
	_bar_top = ColorRect.new()
	_bar_top.color = Color(0.02, 0.016, 0.014, 1.0)
	_bar_top.anchor_left = 0.0
	_bar_top.anchor_right = 1.0
	_bar_top.anchor_top = 0.0
	_bar_top.anchor_bottom = 0.0
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(_bar_top)
	canvas_layer.move_child(_bar_top, 1)

	_bar_bottom = ColorRect.new()
	_bar_bottom.color = Color(0.02, 0.016, 0.014, 1.0)
	_bar_bottom.anchor_left = 0.0
	_bar_bottom.anchor_right = 1.0
	_bar_bottom.anchor_top = 1.0
	_bar_bottom.anchor_bottom = 1.0
	_bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(_bar_bottom)
	canvas_layer.move_child(_bar_bottom, 2)

	var bar_tw := create_tween().set_parallel(true)
	bar_tw.set_ignore_time_scale(true)
	bar_tw.tween_property(_bar_top, "anchor_bottom", LETTERBOX_HEIGHT_RATIO, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bar_tw.tween_property(_bar_bottom, "anchor_top", 1.0 - LETTERBOX_HEIGHT_RATIO, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 4. Minimalist sequence progress dots centered in the bottom letterbox bar
	_progress_box = HBoxContainer.new()
	_progress_box.anchor_left = 0.5
	_progress_box.anchor_right = 0.5
	_progress_box.anchor_top = 1.0 - LETTERBOX_HEIGHT_RATIO * 0.5
	_progress_box.anchor_bottom = 1.0 - LETTERBOX_HEIGHT_RATIO * 0.5
	_progress_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_progress_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_progress_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_progress_box.add_theme_constant_override("separation", 10)
	_progress_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(_progress_box)

	for i in range(_sequences.size()):
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := StyleBoxFlat.new()
		st.bg_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.28)
		st.set_corner_radius_all(99)
		dot.add_theme_stylebox_override("panel", st)
		_progress_box.add_child(dot)
		_progress_dots.append(dot)

	# Ensure fade_rect stays on top of everything
	canvas_layer.move_child(fade_rect, canvas_layer.get_child_count() - 1)


func _style_controls_ui() -> void:
	# Responsive title-safe subtitle container above bottom letterbox
	if is_instance_valid(subtitle_container):
		subtitle_container.anchor_left = 0.14
		subtitle_container.anchor_right = 0.86
		subtitle_container.anchor_top = 1.0 - LETTERBOX_HEIGHT_RATIO - 0.17
		subtitle_container.anchor_bottom = 1.0 - LETTERBOX_HEIGHT_RATIO - 0.015
		subtitle_container.offset_left = 0.0
		subtitle_container.offset_right = 0.0
		subtitle_container.offset_top = 0.0
		subtitle_container.offset_bottom = 0.0
		if subtitle_container is MarginContainer:
			subtitle_container.add_theme_constant_override("margin_left", 0)
			subtitle_container.add_theme_constant_override("margin_right", 0)
			subtitle_container.add_theme_constant_override("margin_bottom", 0)

	if is_instance_valid(subtitle_label):
		subtitle_label.add_theme_font_size_override("font_size", 25)
		subtitle_label.add_theme_color_override("font_color", COL_CREAM)
		subtitle_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.94))
		subtitle_label.add_theme_constant_override("outline_size", 5)

	# Clean bottom-right control prompt inside letterbox safe zone
	if is_instance_valid(indicator):
		indicator.text = "Continue ▾"
		indicator.add_theme_font_size_override("font_size", 15)
		indicator.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
		indicator.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.92))
		indicator.add_theme_constant_override("outline_size", 3)
		indicator.anchor_left = 1.0
		indicator.anchor_right = 1.0
		indicator.anchor_top = 1.0 - LETTERBOX_HEIGHT_RATIO * 0.5
		indicator.anchor_bottom = 1.0 - LETTERBOX_HEIGHT_RATIO * 0.5
		indicator.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		indicator.grow_vertical = Control.GROW_DIRECTION_BOTH
		indicator.offset_left = -280.0
		indicator.offset_right = -36.0
		indicator.offset_top = -12.0
		indicator.offset_bottom = 12.0

	# Clean borderless SKIP text in top-right safe zone
	if is_instance_valid(skip_button):
		skip_button.text = "SKIP"
		skip_button.flat = true
		skip_button.add_theme_font_size_override("font_size", 28)
		skip_button.add_theme_color_override("font_color", COL_CREAM)
		skip_button.add_theme_color_override("font_hover_color", COL_GOLD_BRIGHT)
		skip_button.add_theme_color_override("font_pressed_color", COL_GOLD_BRIGHT)
		skip_button.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.92))
		skip_button.add_theme_constant_override("outline_size", 4)
		var empty_box := StyleBoxEmpty.new()
		skip_button.add_theme_stylebox_override("normal", empty_box)
		skip_button.add_theme_stylebox_override("hover", empty_box)
		skip_button.add_theme_stylebox_override("pressed", empty_box)
		skip_button.add_theme_stylebox_override("focus", empty_box)


func _update_progress_dots(active_idx: int) -> void:
	for i in range(_progress_dots.size()):
		var dot := _progress_dots[i]
		if not is_instance_valid(dot):
			continue
		var st := dot.get_theme_stylebox("panel") as StyleBoxFlat
		var is_active := (i == active_idx)
		var is_done := (i < active_idx)
		if st:
			st.bg_color = COL_GOLD_BRIGHT if is_active else (Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.60) if is_done else Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.24))
		var tw := create_tween()
		tw.set_ignore_time_scale(true)
		tw.tween_property(dot, "custom_minimum_size:x", 22.0 if is_active else 8.0, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_show_skip_button()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_show_skip_button()
		if waiting_for_input:
			waiting_for_input = false
			player_clicked.emit()
		else:
			fast_forwarding = true
	elif event.is_action_pressed("ui_accept"):
		_show_skip_button()
		if waiting_for_input:
			waiting_for_input = false
			player_clicked.emit()
		else:
			fast_forwarding = true
	elif event.is_action_pressed("ui_cancel"):
		_on_skip_pressed()


func wait_for_click() -> void:
	if not is_instance_valid(indicator):
		return
	if _indicator_tween and _indicator_tween.is_valid():
		_indicator_tween.kill()
	indicator.show()
	indicator.modulate.a = 0.0
	var base_top := indicator.offset_top
	var base_bot := indicator.offset_bottom
	_indicator_tween = create_tween()
	_indicator_tween.set_ignore_time_scale(true)
	_indicator_tween.tween_property(indicator, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	_indicator_tween.tween_callback(func():
		if not is_instance_valid(indicator) or not waiting_for_input:
			return
		_indicator_tween = create_tween().set_loops()
		_indicator_tween.set_ignore_time_scale(true)
		_indicator_tween.tween_property(indicator, "modulate:a", 0.55, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_indicator_tween.parallel().tween_property(indicator, "offset_top", base_top + 3.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_indicator_tween.parallel().tween_property(indicator, "offset_bottom", base_bot + 3.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_indicator_tween.tween_property(indicator, "modulate:a", 1.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_indicator_tween.parallel().tween_property(indicator, "offset_top", base_top, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_indicator_tween.parallel().tween_property(indicator, "offset_bottom", base_bot, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	)

	waiting_for_input = true
	fast_forwarding = false
	await player_clicked

	if _indicator_tween and _indicator_tween.is_valid():
		_indicator_tween.kill()
	indicator.offset_top = base_top
	indicator.offset_bottom = base_bot
	indicator.modulate.a = 1.0
	indicator.hide()
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("tab_switch")


func play_all_sequences() -> void:
	for i in range(_sequences.size()):
		if _is_skipping:
			break
		_current_seq_idx = i
		_update_progress_dots(i)
		await play_sequence(_sequences[i])

	if not _is_skipping:
		# Open letterbox bars gently as we hand off to gameplay
		if is_instance_valid(_bar_top) and is_instance_valid(_bar_bottom):
			var open_tw := create_tween().set_parallel(true)
			open_tw.set_ignore_time_scale(true)
			open_tw.tween_property(_bar_top, "anchor_bottom", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			open_tw.tween_property(_bar_bottom, "anchor_top", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_finish_cutscene()


func _fade_out_skip_button() -> void:
	if not skip_button or _is_mouse_over_skip:
		return
	if _skip_fade_tween and _skip_fade_tween.is_valid():
		_skip_fade_tween.kill()
	_skip_fade_tween = create_tween()
	_skip_fade_tween.set_ignore_time_scale(true)
	_skip_fade_tween.tween_interval(2.0)
	_skip_fade_tween.tween_property(skip_button, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	_skip_fade_tween.tween_callback(skip_button.hide)


func _show_skip_button() -> void:
	if not skip_button or _is_skipping:
		return
	skip_button.show()
	if _skip_fade_tween and _skip_fade_tween.is_valid():
		_skip_fade_tween.kill()
	_skip_fade_tween = create_tween()
	_skip_fade_tween.set_ignore_time_scale(true)
	_skip_fade_tween.tween_property(skip_button, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
	if not _is_mouse_over_skip:
		_skip_fade_tween.tween_callback(_fade_out_skip_button)


func _on_skip_mouse_entered() -> void:
	_is_mouse_over_skip = true
	_show_skip_button()


func _on_skip_mouse_exited() -> void:
	_is_mouse_over_skip = false
	_fade_out_skip_button()


func _on_skip_pressed() -> void:
	if _is_skipping:
		return
	_is_skipping = true
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("tab_switch")

	if subtitle_label:
		subtitle_label.hide()
	if indicator:
		indicator.hide()
	if skip_button:
		skip_button.hide()
	if is_instance_valid(_progress_box):
		_progress_box.hide()

	for tween in get_tree().get_processed_tweens():
		if tween.is_valid():
			tween.kill()

	if waiting_for_input:
		waiting_for_input = false
		player_clicked.emit()

	var fade_out := create_tween()
	fade_out.set_ignore_time_scale(true)
	fade_out.tween_property(fade_rect, "color", Color(0, 0, 0, 1), 1.0).set_trans(Tween.TRANS_SINE)
	await fade_out.finished

	_finish_cutscene()


func _finish_cutscene() -> void:
	LogManager.info("IntroCutscene", "Transitions finished. Moving to game!")
	if SceneTransition:
		SceneTransition.transition_to_scene(next_scene_path)
	else:
		var err := get_tree().change_scene_to_file(next_scene_path)
		if err != OK:
			LogManager.error("IntroCutscene", "Failed to load next scene: " + next_scene_path)


func play_sequence(sequence: CutsceneSequence) -> void:
	var full_text := sequence.subtitle_text
	subtitle_label.text = full_text
	subtitle_label.visible_characters = 0
	subtitle_label.modulate.a = 0.0
	fast_forwarding = false
	indicator.hide()

	var pans: Array[CameraPan] = []
	for child in sequence.get_children():
		if child is CameraPan:
			pans.append(child)

	if pans.is_empty():
		LogManager.warn("IntroCutscene", "Sequence has no CameraPans! " + sequence.name)
		return

	# Position camera at first marker immediately and start subtle cinema FOV push-in
	var first_pan := pans[0]
	var first_start := first_pan.get_node_or_null(first_pan.start_marker) as Node3D
	if first_start:
		_base_cam_pos = first_start.global_position
		_base_cam_quat = first_start.global_basis.get_rotation_quaternion()
		_cam_active = true

	if camera:
		if _fov_tween and _fov_tween.is_valid():
			_fov_tween.kill()
		camera.fov = _base_fov
		var total_dur := 0.0
		for p in pans:
			total_dur += p.duration
		_fov_tween = create_tween()
		_fov_tween.set_ignore_time_scale(true)
		_fov_tween.tween_property(camera, "fov", _base_fov - 4.5, maxf(total_dur, 2.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 1. Start fade-in CONCURRENTLY with camera motion (zero dead-air start!)
	var fade_in := create_tween()
	fade_in.set_ignore_time_scale(true)
	fade_in.tween_property(fade_rect, "color", Color(0, 0, 0, 0), 0.85).set_trans(Tween.TRANS_SINE)

	# Soft upward fade-in on subtitle label
	var sub_in := create_tween()
	sub_in.set_ignore_time_scale(true)
	sub_in.tween_interval(0.20)
	sub_in.tween_property(subtitle_label, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)

	# 2. Run quaternion-interpolated pans + punctuation-paced text reveal concurrently
	var char_index := 0
	var char_accum := 0.0
	var text_done := full_text.is_empty()

	for pan_idx in range(pans.size()):
		if _is_skipping:
			return
		var pan := pans[pan_idx]
		var pan_start := pan.get_node_or_null(pan.start_marker) as Node3D
		var pan_end := pan.get_node_or_null(pan.end_marker) as Node3D

		if pan_start:
			_base_cam_pos = pan_start.global_position
			_base_cam_quat = pan_start.global_basis.get_rotation_quaternion()
		if not pan_end:
			continue

		var start_pos := _base_cam_pos
		var end_pos := pan_end.global_position
		var start_q := _base_cam_quat
		var end_q := pan_end.global_basis.get_rotation_quaternion()

		var elapsed := 0.0
		var dur := maxf(pan.duration, 0.1)
		while elapsed < dur:
			if _is_skipping:
				return
			await get_tree().process_frame
			var dt := get_process_delta_time()
			elapsed += dt

			if fast_forwarding:
				_base_cam_pos = end_pos
				_base_cam_quat = end_q
				subtitle_label.visible_characters = -1
				subtitle_label.modulate.a = 1.0
				text_done = true
				break

			# Smooth cosine ease-in-out on position + quaternion slerp
			var u := clampf(elapsed / dur, 0.0, 1.0)
			var eased := 0.5 - 0.5 * cos(u * PI)
			_base_cam_pos = start_pos.lerp(end_pos, eased)
			_base_cam_quat = start_q.slerp(end_q, eased)

			# Punctuation-paced typewriter reveal
			if not text_done and elapsed >= 0.25:
				char_accum += dt * characters_per_second
				while char_accum >= 1.0 and char_index < full_text.length():
					char_index += 1
					char_accum -= 1.0
					subtitle_label.visible_characters = char_index
					var ch := full_text[char_index - 1]
					if ch == "." or ch == "!" or ch == "?":
						char_accum -= 4.5
					elif ch == ",":
						char_accum -= 2.2
				if char_index >= full_text.length():
					text_done = true

		if fast_forwarding:
			break

	# Finish any remaining text if pan ended before typing finished
	while not text_done and not _is_skipping:
		await get_tree().process_frame
		if fast_forwarding:
			subtitle_label.visible_characters = -1
			subtitle_label.modulate.a = 1.0
			text_done = true
			break
		char_accum += get_process_delta_time() * characters_per_second
		while char_accum >= 1.0 and char_index < full_text.length():
			char_index += 1
			char_accum -= 1.0
			subtitle_label.visible_characters = char_index
			var ch := full_text[char_index - 1]
			if ch == "." or ch == "!" or ch == "?":
				char_accum -= 4.5
			elif ch == ",":
				char_accum -= 2.2
		if char_index >= full_text.length():
			text_done = true

	if _is_skipping:
		return
	fast_forwarding = false

	# 3. Wait for player click (camera keeps gently breathing!)
	await wait_for_click()
	if _is_skipping:
		return

	# 4. Smooth fade out to black
	var fade_out := create_tween()
	fade_out.set_ignore_time_scale(true)
	fade_out.tween_property(fade_rect, "color", Color(0, 0, 0, 1), 0.75).set_trans(Tween.TRANS_SINE)
	await fade_out.finished
