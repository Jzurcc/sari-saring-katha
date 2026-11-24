class_name MayariCardHUD
extends CanvasLayer

## Displays a compact, non-intrusive Moon Card badge on the HUD whenever
## a Biringan's Favor or Biringan's Chill card is active for the current day.

var _panel: PanelContainer
var _style: StyleBoxFlat
var _sigil_lbl: Label
var _title_lbl: Label
var _short_lbl: Label

func _ready() -> void:
	layer = 40
	_build_ui()
	EventBus.mayari_card_changed.connect(_on_card_changed)
	EventBus.day_started.connect(func(_d): _on_card_changed(StoryManager.active_mayari_card))
	_on_card_changed(StoryManager.active_mayari_card)

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.offset_left = 20.0
	_panel.offset_top = 132.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_style = UIStyle.create_flat_stylebox(Color(0.068, 0.082, 0.145, 0.88), 10, 12, 7)
	_style.border_width_left = 2
	_style.border_width_top = 1
	_style.border_width_right = 1
	_style.border_width_bottom = 1
	_panel.add_theme_stylebox_override("panel", _style)
	root.add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)

	_sigil_lbl = Label.new()
	_sigil_lbl.add_theme_font_size_override("font_size", 20)
	_sigil_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sigil_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_sigil_lbl)

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 0)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_col)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_title_lbl.add_theme_font_size_override("font_size", 13)
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(_title_lbl)

	_short_lbl = Label.new()
	_short_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	_short_lbl.add_theme_font_size_override("font_size", 11)
	_short_lbl.add_theme_color_override("font_color", Color(0.84, 0.88, 0.96, 0.9))
	_short_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(_short_lbl)

	_panel.visible = false

func _on_card_changed(card_id: String) -> void:
	if card_id == "":
		_panel.visible = false
		return
	var card := MayariCardRegistry.get_card(card_id)
	if card.is_empty():
		_panel.visible = false
		return

	var is_fav := MayariCardRegistry.is_favor(card_id)
	var accent := Color(1.0, 0.875, 0.56, 1.0) if is_fav else Color(0.95, 0.58, 0.54, 1.0)
	_style.border_color = Color(0.835, 0.624, 0.278, 0.90) if is_fav else Color(0.84, 0.37, 0.36, 0.90)
	_style.bg_color = Color(0.082, 0.074, 0.066, 0.92) if is_fav else Color(0.115, 0.068, 0.068, 0.92)

	_sigil_lbl.text = str(card.get("sigil", "☽"))
	_sigil_lbl.add_theme_color_override("font_color", accent)
	_title_lbl.text = str(card.get("title", "Moon Card"))
	_title_lbl.add_theme_color_override("font_color", accent)
	_short_lbl.text = str(card.get("hud_short", ""))

	_panel.visible = true
	_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
