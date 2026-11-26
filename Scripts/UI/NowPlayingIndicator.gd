extends Control

@onready var label: Label = $Label

var current_tween: Tween
var _pill: PanelContainer = null
var _pill_lbl: Label = null

func _ready() -> void:
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if is_instance_valid(label):
		label.visible = false
	_build_pill()
	EventBus.music_title_changed.connect(_on_music_title_changed)

func _build_pill() -> void:
	_pill = PanelContainer.new()
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.anchor_left = 0.72
	_pill.anchor_right = 0.72
	_pill.anchor_top = 0.0
	_pill.anchor_bottom = 0.0
	_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pill.grow_vertical = Control.GROW_DIRECTION_END
	_pill.offset_top = 24.0
	var st := UIStyle.create_flat_stylebox(Color(0.064, 0.054, 0.046, 0.90), 9, 14, 7)
	st.border_color = Color(0.835, 0.624, 0.278, 0.55)
	st.set_border_width_all(1)
	st.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	st.shadow_size = 10
	_pill.add_theme_stylebox_override("panel", st)
	add_child(_pill)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.add_child(row)

	var note := Label.new()
	note.text = "♪"
	note.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	note.add_theme_font_size_override("font_size", 16)
	note.add_theme_color_override("font_color", Color(0.98, 0.86, 0.52, 1.0))
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(note)

	_pill_lbl = Label.new()
	_pill_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_MED)
	_pill_lbl.add_theme_font_size_override("font_size", 15)
	_pill_lbl.add_theme_color_override("font_color", Color(0.96, 0.91, 0.80, 0.94))
	_pill_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_pill_lbl)

func _on_music_title_changed(title: String) -> void:
	var txt := "Now Playing · %s" % title
	if is_instance_valid(_pill_lbl):
		_pill_lbl.text = txt
	elif is_instance_valid(label):
		label.text = txt

	if current_tween and current_tween.is_valid():
		current_tween.kill()

	current_tween = create_tween()
	current_tween.tween_property(self, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_CUBIC)
	current_tween.tween_interval(3.0)
	current_tween.tween_property(self, "modulate:a", 0.0, 0.75).set_trans(Tween.TRANS_CUBIC)
