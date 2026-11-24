extends Control

## Diegetic spiral-bound Utang (Loan) Ledger UI using Assets/ui/ledger_ui.jpg.
## Aligns every header, pending-loan entry, and recorded-debt line directly onto
## the printed horizontal ruled lines to the right of the red margin line.

signal notebook_closed

const LEDGER_TEX_PATH := "res://Assets/ui/ledger_ui.jpg"
const INK_FONT_PATH := "res://Assets/Fonts/Inder/Inder-Regular.ttf"
const BOLD_FONT_PATH := "res://Assets/Fonts/Balete Trial/BaleteTrial-Bold.ttf"

const LEDGER_ASPECT := 1504.0 / 1776.0
## Measured normalized ruled-line spacing and red-margin x on Assets/ui/ledger_ui.jpg
const MARGIN_LEFT_ANCHOR := 0.288
const MARGIN_RIGHT_ANCHOR := 0.908
const HEADER_LINE_TOP := 0.132
const ROWS_TOP_ANCHOR := 0.171
const ROWS_BOTTOM_ANCHOR := 0.892
const RULED_LINE_STEP := 0.03715

const INK_DARK := Color(0.14, 0.16, 0.28, 0.94)     # Ballpoint blue-black ink
const INK_RED := Color(0.70, 0.13, 0.11, 0.96)      # Red accounting ink
const INK_MUTED := Color(0.36, 0.33, 0.30, 0.78)    # Soft pencil gray
const INK_HEADER := Color(0.24, 0.16, 0.10, 0.95)   # Deep sepia ink

var _ink_font: Font
var _bold_font: FontVariation
var _page_rect: TextureRect
var _no_lbl: Label
var _date_lbl: Label
var _header_total_lbl: Label
var _rows_vbox: VBoxContainer
var _line_h: float = 28.0

func _ready() -> void:
	# Remove legacy template children from NotebookUI.tscn so we render cleanly on ledger_ui.jpg
	for child in get_children():
		child.queue_free()

	_ink_font = load(INK_FONT_PATH) if ResourceLoader.exists(INK_FONT_PATH) else UIStyle.FONT_INDER
	_bold_font = FontVariation.new()
	_bold_font.base_font = load(BOLD_FONT_PATH) if ResourceLoader.exists(BOLD_FONT_PATH) else _ink_font
	_bold_font.variation_embolden = 0.25

	_build_ui()
	_populate_debts()

func _build_ui() -> void:
	# Dimmed clickable backdrop (clicking outside closes the notebook)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.025, 0.02, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_on_close_button_pressed()
	)
	add_child(backdrop)

	# Aspect-locked notebook page container
	var aspect := AspectRatioContainer.new()
	aspect.anchor_left = 0.0
	aspect.anchor_right = 1.0
	aspect.anchor_top = 0.045
	aspect.anchor_bottom = 0.955
	aspect.ratio = LEDGER_ASPECT
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	aspect.alignment_horizontal = AspectRatioContainer.ALIGNMENT_CENTER
	aspect.alignment_vertical = AspectRatioContainer.ALIGNMENT_CENTER
	aspect.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(aspect)

	_page_rect = TextureRect.new()
	if ResourceLoader.exists(LEDGER_TEX_PATH):
		_page_rect.texture = load(LEDGER_TEX_PATH)
	_page_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_page_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_page_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_page_rect.resized.connect(_on_page_resized)
	aspect.add_child(_page_rect)

	# Top-right printed "NO." and "DATE / /" ink entries
	_no_lbl = Label.new()
	_no_lbl.anchor_left = 0.735
	_no_lbl.anchor_right = 0.885
	_no_lbl.anchor_top = 0.062
	_no_lbl.anchor_bottom = 0.090
	_no_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_no_lbl.add_theme_font_override("font", _ink_font)
	_no_lbl.add_theme_font_size_override("font_size", 16)
	_no_lbl.add_theme_color_override("font_color", INK_DARK)
	_no_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_rect.add_child(_no_lbl)

	_date_lbl = Label.new()
	_date_lbl.anchor_left = 0.730
	_date_lbl.anchor_right = 0.895
	_date_lbl.anchor_top = 0.094
	_date_lbl.anchor_bottom = 0.123
	_date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_date_lbl.add_theme_font_override("font", _ink_font)
	_date_lbl.add_theme_font_size_override("font_size", 15)
	_date_lbl.add_theme_color_override("font_color", INK_DARK)
	_date_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_rect.add_child(_date_lbl)

	# First ruled line: "LISTA NG UTANG" title on left, Total Owed on right
	var header_row := HBoxContainer.new()
	header_row.anchor_left = MARGIN_LEFT_ANCHOR
	header_row.anchor_right = MARGIN_RIGHT_ANCHOR
	header_row.anchor_top = HEADER_LINE_TOP
	header_row.anchor_bottom = ROWS_TOP_ANCHOR
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_rect.add_child(header_row)

	var title_lbl := Label.new()
	title_lbl.text = "LISTA NG UTANG"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	title_lbl.add_theme_font_override("font", _bold_font)
	title_lbl.add_theme_font_size_override("font_size", 19)
	title_lbl.add_theme_color_override("font_color", INK_HEADER)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(title_lbl)

	_header_total_lbl = Label.new()
	_header_total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_header_total_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_header_total_lbl.add_theme_font_override("font", _bold_font)
	_header_total_lbl.add_theme_font_size_override("font_size", 18)
	_header_total_lbl.add_theme_color_override("font_color", INK_RED)
	_header_total_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(_header_total_lbl)

	# Ruled rows scroll region aligned to horizontal lines
	var scroll := ScrollContainer.new()
	scroll.anchor_left = MARGIN_LEFT_ANCHOR
	scroll.anchor_right = MARGIN_RIGHT_ANCHOR
	scroll.anchor_top = ROWS_TOP_ANCHOR
	scroll.anchor_bottom = ROWS_BOTTOM_ANCHOR
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_page_rect.add_child(scroll)

	_rows_vbox = VBoxContainer.new()
	_rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_vbox.add_theme_constant_override("separation", 0)
	scroll.add_child(_rows_vbox)

	# Subtle diegetic Close button tucked in bottom-right paper margin
	var close_btn := Button.new()
	close_btn.text = "✕ Close"
	close_btn.anchor_left = 0.76
	close_btn.anchor_right = 0.915
	close_btn.anchor_top = 0.908
	close_btn.anchor_bottom = 0.954
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var cs := UIStyle.create_flat_stylebox(Color(0.95, 0.90, 0.80, 0.88), 5, 8, 2)
	cs.border_color = Color(0.55, 0.36, 0.22, 0.75)
	cs.set_border_width_all(1)
	var ch: StyleBoxFlat = cs.duplicate()
	ch.bg_color = Color(0.88, 0.80, 0.66, 0.96)
	ch.border_color = INK_RED
	close_btn.add_theme_stylebox_override("normal", cs)
	close_btn.add_theme_stylebox_override("hover", ch)
	close_btn.add_theme_stylebox_override("pressed", cs)
	close_btn.add_theme_font_override("font", _bold_font)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color", INK_HEADER)
	close_btn.add_theme_color_override("font_hover_color", INK_RED)
	close_btn.pressed.connect(_on_close_button_pressed)
	_page_rect.add_child(close_btn)

	_sync_header_date()
	call_deferred("_on_page_resized")

func _sync_header_date() -> void:
	var total_idx := maxi(0, StoryManager.day - 1)
	var months_elapsed := total_idx / 31
	var day_in_month := (total_idx % 31) + 1
	var month_num := ((7 + months_elapsed) % 12) + 1 # August = 8
	var year_short := (2013 + (7 + months_elapsed) / 12) % 100
	if is_instance_valid(_no_lbl):
		_no_lbl.text = "%02d" % StoryManager.day
	if is_instance_valid(_date_lbl):
		_date_lbl.text = "%02d  %02d  %02d" % [month_num, day_in_month, year_short]

func _on_page_resized() -> void:
	if not is_instance_valid(_page_rect):
		return
	var h := _page_rect.size.y
	if h <= 10.0:
		return
	_line_h = h * RULED_LINE_STEP
	if is_instance_valid(_rows_vbox):
		for child in _rows_vbox.get_children():
			if child is Control:
				(child as Control).custom_minimum_size.y = _line_h

func _make_ruled_row(highlight_bg: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var row_wrap := PanelContainer.new()
	row_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_wrap.custom_minimum_size = Vector2(0.0, _line_h)
	var st := StyleBoxFlat.new()
	st.bg_color = highlight_bg
	st.content_margin_left = 4
	st.content_margin_right = 4
	st.content_margin_top = 0
	st.content_margin_bottom = 2
	st.set_corner_radius_all(3)
	row_wrap.add_theme_stylebox_override("panel", st)
	return row_wrap

func _populate_debts() -> void:
	if not is_instance_valid(_rows_vbox):
		return
	for child in _rows_vbox.get_children():
		_rows_vbox.remove_child(child)
		child.queue_free()

	_sync_header_date()
	var total_recorded := 0.0
	for path in StoryManager.customer_debts.keys():
		var amt := float(StoryManager.customer_debts[path])
		if amt > 0.0:
			total_recorded += amt
	if is_instance_valid(_header_total_lbl):
		_header_total_lbl.text = "Total: ₱%.2f" % total_recorded if total_recorded > 0.0 else "All Clear"

	# 1. Pending (unlogged) utang entries with diegetic red-ink "+ Record" stamp
	if StoryManager.has_pending_debts():
		var p_hdr_row := _make_ruled_row(Color(0.95, 0.78, 0.22, 0.18))
		var p_hdr_lbl := Label.new()
		p_hdr_lbl.text = "★  NEW UTANG TO RECORD"
		p_hdr_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		p_hdr_lbl.add_theme_font_override("font", _bold_font)
		p_hdr_lbl.add_theme_font_size_override("font_size", 15)
		p_hdr_lbl.add_theme_color_override("font_color", INK_RED)
		p_hdr_row.add_child(p_hdr_lbl)
		_rows_vbox.add_child(p_hdr_row)

		for i in range(StoryManager.pending_debts.size()):
			var entry: Dictionary = StoryManager.pending_debts[i]
			var path: String = str(entry.get("customer_path", ""))
			var amount: float = float(entry.get("amount", 0.0))
			var data: CustomerData = load(path) as CustomerData if ResourceLoader.exists(path) else null
			var char_name: String = data.character_name if data else "Neighbor"

			var row_wrap := _make_ruled_row(Color(1.0, 0.86, 0.28, 0.24))
			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 8)
			row_wrap.add_child(hbox)

			var name_lbl := Label.new()
			name_lbl.text = "• %s" % char_name
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			name_lbl.add_theme_font_override("font", _ink_font)
			name_lbl.add_theme_font_size_override("font_size", 17)
			name_lbl.add_theme_color_override("font_color", INK_DARK)
			hbox.add_child(name_lbl)

			var amt_lbl := Label.new()
			amt_lbl.text = "₱%.2f" % amount
			amt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			amt_lbl.add_theme_font_override("font", _bold_font)
			amt_lbl.add_theme_font_size_override("font_size", 16)
			amt_lbl.add_theme_color_override("font_color", INK_RED)
			hbox.add_child(amt_lbl)

			var add_btn := Button.new()
			add_btn.text = "+ Record"
			add_btn.focus_mode = Control.FOCUS_NONE
			add_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			add_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var bs := UIStyle.create_flat_stylebox(Color(0.76, 0.18, 0.14, 0.92), 4, 8, 1)
			bs.border_color = Color(0.45, 0.08, 0.06, 0.9)
			bs.set_border_width_all(1)
			var bh: StyleBoxFlat = bs.duplicate()
			bh.bg_color = Color(0.88, 0.24, 0.18, 0.98)
			add_btn.add_theme_stylebox_override("normal", bs)
			add_btn.add_theme_stylebox_override("hover", bh)
			add_btn.add_theme_stylebox_override("pressed", bs)
			add_btn.add_theme_font_override("font", _bold_font)
			add_btn.add_theme_font_size_override("font_size", 13)
			add_btn.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90, 1.0))
			add_btn.pressed.connect(_on_add_loan_pressed.bind(i))
			hbox.add_child(add_btn)

			_rows_vbox.add_child(row_wrap)

		# Blank ruled spacer line between pending and recorded entries
		_rows_vbox.add_child(_make_ruled_row())

	# 2. Recorded utang entries aligned 1-per-ruled-line
	var has_debts := false
	for path in StoryManager.customer_debts.keys():
		var amount := float(StoryManager.customer_debts[path])
		if amount > 0.0:
			has_debts = true
			var data: CustomerData = load(path) as CustomerData if ResourceLoader.exists(path) else null
			var char_name: String = data.character_name if data else "Neighbor"

			var row_wrap := _make_ruled_row()
			var hbox := HBoxContainer.new()
			row_wrap.add_child(hbox)

			var name_lbl := Label.new()
			name_lbl.text = char_name
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			name_lbl.add_theme_font_override("font", _ink_font)
			name_lbl.add_theme_font_size_override("font_size", 18)
			name_lbl.add_theme_color_override("font_color", INK_DARK)
			hbox.add_child(name_lbl)

			var amt_lbl := Label.new()
			amt_lbl.text = "₱%.2f" % amount
			amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			amt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			amt_lbl.add_theme_font_override("font", _bold_font)
			amt_lbl.add_theme_font_size_override("font_size", 17)
			amt_lbl.add_theme_color_override("font_color", INK_RED)
			hbox.add_child(amt_lbl)

			_rows_vbox.add_child(row_wrap)

	if not has_debts and not StoryManager.has_pending_debts():
		var empty_row := _make_ruled_row()
		var empty_lbl := Label.new()
		empty_lbl.text = "No unpaid utang on record."
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		empty_lbl.add_theme_font_override("font", _ink_font)
		empty_lbl.add_theme_font_size_override("font_size", 17)
		empty_lbl.add_theme_color_override("font_color", INK_MUTED)
		empty_row.add_child(empty_lbl)
		_rows_vbox.add_child(empty_row)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_button_pressed()
		get_viewport().set_input_as_handled()

func _on_add_loan_pressed(index: int) -> void:
	AudioManager.play_sfx("interact")
	StoryManager.commit_pending_debt(index)
	_populate_debts()

func _on_close_button_pressed() -> void:
	notebook_closed.emit()
	queue_free()
