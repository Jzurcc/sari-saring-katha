class_name PriceLedgerOverlay
extends CanvasLayer

## Modernized Store Price Ledger Overlay (Hotkey: L).
## Reuses RestockMenu's borderless Dark Warm Espresso + 5% safe-area layout,
## Lucide-icon Category & Active Effects popovers, and PricingOverlay's
## interactive bidirectional diamond-capped PriceStepGauge + Effect Tooltip cards.

const FONT_INDER := preload("res://Assets/Fonts/Fredoka/Fredoka-Regular.ttf")
const IC_SPARKLES: Texture2D = preload("res://Assets/ui/icons/sparkles.png")
const IC_LAYERS: Texture2D = preload("res://Assets/ui/icons/layers-2.png")
const IC_PACKAGE: Texture2D = preload("res://Assets/ui/icons/package.png")
const IC_COFFEE: Texture2D = preload("res://Assets/ui/icons/coffee.png")
const IC_GIFT: Texture2D = preload("res://Assets/ui/icons/gift.png")
const IC_SNOWFLAKE: Texture2D = preload("res://Assets/ui/icons/snowflake.png")
const IC_FLAME: Texture2D = preload("res://Assets/ui/icons/flame.png")
const IC_SCALE: Texture2D = preload("res://Assets/ui/icons/scale.png")

# Palette: exact match with RestockMenu & PricingOverlay
const COL_BACKDROP := Color(0.052, 0.044, 0.038, 0.95)
const COL_SURFACE := Color(0.105, 0.090, 0.078, 0.96)
const COL_ESPRESSO := Color(0.068, 0.058, 0.050, 0.98)
const COL_CARD := Color(0.132, 0.114, 0.098, 0.94)
const COL_CARD_HOVER := Color(0.168, 0.144, 0.122, 0.98)
const COL_GOLD := Color(0.86, 0.67, 0.32, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.89, 0.58, 1.0)
const COL_GOLD_SOFT := Color(0.96, 0.85, 0.52, 1.0)
const COL_CREAM := Color(1.0, 0.95, 0.86, 1.0)
const COL_CREAM_MUTED := Color(0.82, 0.76, 0.67, 0.88)
const COL_BORDER_SUBTLE := Color(0.42, 0.31, 0.18, 0.52)
const COL_OUTLINE := Color(0.05, 0.038, 0.028, 0.95)
const COL_DISCOUNT := Color(0.50, 0.88, 0.58, 1.0)
const COL_RISKY := Color(0.98, 0.68, 0.28, 1.0)
const COL_DANGER := Color(0.96, 0.42, 0.34, 1.0)
const COL_CORAL := Color(0.94, 0.48, 0.44, 1.0)
const COL_WARM := Color(1.0, 0.56, 0.34, 1.0)

const CATEGORY_DEFS: Array[Dictionary] = [
	{"id": "all", "label": "All Items"},
	{"id": "hot", "label": "Hot Today"},
	{"id": "snack", "label": "Snacks"},
	{"id": "sachet", "label": "Sachets"},
	{"id": "can", "label": "Canned Goods"},
	{"id": "bottle", "label": "Beverages"},
	{"id": "candy", "label": "Candy"},
	{"id": "pack", "label": "Noodles"},
	{"id": "frozen", "label": "Frozen"},
	{"id": "cigarette", "label": "Cigarettes"},
]


## Interactive bidirectional diamond-capped PriceStepGauge (reused from PricingOverlay).
class LedgerStepGauge extends Control:
	signal step_requested(new_step: int)

	var step: int = 0
	var min_step: int = ItemData.MIN_STEP
	var max_step: int = ItemData.MAX_STEP
	var accent_color: Color = Color(0.96, 0.85, 0.52, 1.0)
	var _dragging: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw_diamond(center: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array([
			center + Vector2(0.0, -r),
			center + Vector2(r, 0.0),
			center + Vector2(0.0, r),
			center + Vector2(-r, 0.0),
		])
		draw_colored_polygon(pts, col)

	func _step_from_x(local_x: float) -> int:
		var pad_x := 10.0
		var bar_w := maxf(20.0, size.x - pad_x * 2.0)
		var t := clampf((local_x - pad_x) / bar_w, 0.0, 1.0)
		return clampi(int(roundf(lerpf(float(min_step), float(max_step), t))), min_step, max_step)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_dragging = true
					step_requested.emit(_step_from_x(event.position.x))
				else:
					_dragging = false
				accept_event()
		elif event is InputEventMouseMotion and _dragging:
			step_requested.emit(_step_from_x(event.position.x))
			accept_event()

	func _draw() -> void:
		var pad_x := 10.0
		var bar_h := 20.0
		var bar_y := (size.y - bar_h) * 0.5
		var bar_w := maxf(20.0, size.x - pad_x * 2.0)
		var bar_rect := Rect2(pad_x, bar_y, bar_w, bar_h)
		var span := float(max_step - min_step)
		if span <= 0.0:
			return

		var zero_t := float(0 - min_step) / span
		var step_t := clampf(float(step - min_step) / span, 0.0, 1.0)
		var zero_x := pad_x + zero_t * bar_w
		var cur_x := pad_x + step_t * bar_w

		# Deep obsidian recessed track
		draw_rect(bar_rect, Color(0.035, 0.030, 0.026, 0.98), true)

		# Subtle step ruler notches (-5 .. +5)
		for i in range(min_step + 1, max_step):
			var nt := float(i - min_step) / span
			var nx := pad_x + nt * bar_w
			var is_zero := (i == 0)
			var tick_col := Color(0.96, 0.86, 0.58, 0.62) if is_zero else Color(1.0, 0.92, 0.78, 0.14)
			var y_inset := 1.0 if is_zero else 4.0
			draw_line(Vector2(nx, bar_y + y_inset), Vector2(nx, bar_y + bar_h - y_inset), tick_col, 1.8 if is_zero else 1.0, true)

		# Bidirectional fill from 0 to current step
		var inset := 2.0
		if absf(cur_x - zero_x) > 1.0:
			var x0 := minf(zero_x, cur_x)
			var x1 := maxf(zero_x, cur_x)
			draw_rect(Rect2(x0, bar_y + inset, x1 - x0, bar_h - inset * 2.0), accent_color, true)
			draw_rect(Rect2(x0, bar_y + inset, x1 - x0, 4.0), Color(1.0, 0.96, 0.84, 0.25), true)

		# Antique-gold frame + inner bevel
		var frame_col := Color(0.835, 0.624, 0.278, 0.88)
		draw_rect(bar_rect, frame_col, false, 1.8)
		draw_rect(bar_rect.grow(-2.0), Color(0.0, 0.0, 0.0, 0.45), false, 1.0)

		# End-cap diamond ornaments & center marker
		_draw_diamond(Vector2(pad_x, bar_y + bar_h * 0.5), 4.5, frame_col)
		_draw_diamond(Vector2(pad_x + bar_w, bar_y + bar_h * 0.5), 4.5, frame_col)
		_draw_diamond(Vector2(zero_x, bar_y + bar_h + 5.5), 2.8, Color(0.86, 0.72, 0.42, 0.78))

		# Glowing diamond thumb at active step
		var thumb_c := Vector2(cur_x, bar_y + bar_h * 0.5)
		_draw_diamond(thumb_c, 9.5, Color(accent_color.r, accent_color.g, accent_color.b, 0.28))
		_draw_diamond(thumb_c, 7.0, Color(0.06, 0.05, 0.04, 0.96))
		_draw_diamond(thumb_c, 5.0, accent_color.lightened(0.25))


var _current_tab: String = "all"
var _item_rows: Dictionary = {} # ItemData -> Dictionary of UI refs
var _visible_items: Array[ItemData] = []
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var is_open: bool = false

var _bold_font: FontVariation
var _root: Control
var _safe_root: VBoxContainer
var _open_close_tween: Tween = null
var _category_btn: Button
var _category_backdrop: Control
var _category_popover: PanelContainer
var _category_list_box: VBoxContainer
var _effects_btn: Button
var _effects_backdrop: Control
var _effects_popover: PanelContainer
var _effects_list_box: VBoxContainer
var _items_list: VBoxContainer
var _grid_scroll: ScrollContainer

# Delayed Hover Effect Tooltip Stack (exact PricingOverlay Effect Cards)
var _hover_tooltip_col: VBoxContainer
var _hover_timer: Timer
var _hovered_item: ItemData = null
var _hovered_row: Control = null


func _ready() -> void:
	layer = 55
	add_to_group("price_ledger_overlay")

	_bold_font = FontVariation.new()
	_bold_font.base_font = FONT_INDER
	_bold_font.variation_embolden = 0.58

	# Hide legacy scene children cleanly
	for child in get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false

	_build_ui()
	hide()
	EventBus.price_ledger_toggled.connect(_on_ledger_toggled)


func _on_ledger_toggled(opened: bool) -> void:
	if opened:
		if is_open:
			close_ledger()
		else:
			open_ledger()
	else:
		close_ledger()


func open_ledger() -> void:
	if is_open:
		return
	if _open_close_tween and _open_close_tween.is_valid():
		_open_close_tween.kill()
	is_open = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("tab_switch")

	show()
	_set_category_open(false)
	_set_effects_open(false)
	_hide_hover_tooltip()
	_refresh_category_btn()
	_refresh_effects_popover()
	refresh_catalog()

	_root.modulate.a = 0.0
	if is_instance_valid(_safe_root):
		_safe_root.pivot_offset = _safe_root.size * 0.5
		_safe_root.scale = Vector2(0.965, 0.965)
	_open_close_tween = create_tween().set_parallel(true)
	_open_close_tween.tween_property(_root, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_safe_root):
		_open_close_tween.tween_property(_safe_root, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for i in range(_safe_root.get_child_count()):
			var ch := _safe_root.get_child(i)
			if ch is Control:
				ch.modulate.a = 0.0
				_open_close_tween.tween_property(ch, "modulate:a", 1.0, 0.18).set_delay(0.035 * float(i)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_animate_rows_domino_in()


func _animate_rows_domino_in() -> void:
	if not is_instance_valid(_items_list):
		return
	var rows: Array[Control] = []
	for ch in _items_list.get_children():
		if ch is Control and not ch.is_queued_for_deletion():
			rows.append(ch as Control)
	var max_anim := mini(rows.size(), 14)
	var tw := _open_close_tween if (_open_close_tween and _open_close_tween.is_valid()) else create_tween().set_parallel(true)
	for i in range(max_anim):
		var r := rows[i]
		r.modulate.a = 0.0
		r.pivot_offset = r.size * 0.5
		r.scale = Vector2(0.96, 0.96)
		var d := 0.025 * float(i)
		tw.tween_property(r, "modulate:a", 1.0, 0.18).set_delay(d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(r, "scale", Vector2.ONE, 0.22).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close_ledger() -> void:
	if not is_open:
		return
	if _open_close_tween and _open_close_tween.is_valid():
		_open_close_tween.kill()
	is_open = false
	_set_category_open(false)
	_set_effects_open(false)
	_hide_hover_tooltip()
	Input.mouse_mode = _previous_mouse_mode

	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("drop")

	if is_instance_valid(_safe_root):
		_safe_root.pivot_offset = _safe_root.size * 0.5
	_open_close_tween = create_tween().set_parallel(true)
	if is_instance_valid(_items_list):
		var rows := _items_list.get_children()
		var max_anim := mini(rows.size(), 10)
		for i in range(max_anim):
			var r := rows[i]
			if r is Control:
				r.pivot_offset = r.size * 0.5
				var d := 0.012 * float(i)
				_open_close_tween.tween_property(r, "modulate:a", 0.0, 0.11).set_delay(d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				_open_close_tween.tween_property(r, "scale", Vector2(0.96, 0.96), 0.11).set_delay(d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_open_close_tween.tween_property(_root, "modulate:a", 0.0, 0.18).set_delay(0.04).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if is_instance_valid(_safe_root):
		_open_close_tween.tween_property(_safe_root, "scale", Vector2(0.975, 0.975), 0.18).set_delay(0.04).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_open_close_tween.set_parallel(false)
	_open_close_tween.tween_callback(func():
		if not is_open:
			hide()
			if is_instance_valid(_safe_root):
				_safe_root.scale = Vector2.ONE
	)


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var is_esc: bool = event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE))
	var is_l: bool = event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_L or event.keycode == KEY_L)
	if is_esc:
		get_viewport().set_input_as_handled()
		if _category_popover and _category_popover.visible:
			_set_category_open(false)
		elif _effects_popover and _effects_popover.visible:
			_set_effects_open(false)
		else:
			close_ledger()
	elif is_l:
		get_viewport().set_input_as_handled()
		close_ledger()


# ── UI Construction (RestockMenu Shell) ──────────────────────────────────────

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = COL_BACKDROP
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(backdrop)

	# 5% Title-Safe Container (90% safe area, matching RestockMenu)
	_safe_root = VBoxContainer.new()
	_safe_root.anchor_left = 0.05
	_safe_root.anchor_right = 0.95
	_safe_root.anchor_top = 0.045
	_safe_root.anchor_bottom = 0.955
	_safe_root.add_theme_constant_override("separation", 16)
	_root.add_child(_safe_root)

	_build_top_bar(_safe_root)
	_build_toolbar(_safe_root)
	_build_body(_safe_root)
	_build_category_popover()
	_build_effects_popover()
	_build_hover_tooltip()


func _build_top_bar(parent: VBoxContainer) -> void:
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 14)
	parent.add_child(top_bar)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	var title_lbl := Label.new()
	title_lbl.text = "Price Ledger"
	title_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_lbl.add_theme_font_override("font", _bold_font)
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", COL_CREAM)
	title_lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	title_lbl.add_theme_constant_override("outline_size", 4)
	top_bar.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(48, 48)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_font_override("font", _bold_font)
	close_btn.add_theme_font_size_override("font_size", 20)
	_apply_btn_theme(close_btn, Color(0.22, 0.14, 0.13, 0.95), COL_CORAL, COL_CREAM, 10)
	close_btn.pressed.connect(close_ledger)
	top_bar.add_child(close_btn)


func _build_toolbar(parent: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	parent.add_child(bar)

	# Category Dropdown Button (exact RestockMenu Lucide-icon pattern)
	_category_btn = Button.new()
	_category_btn.text = "All Items ▾"
	_category_btn.icon = IC_LAYERS
	_category_btn.custom_minimum_size = Vector2(0, 48)
	_category_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_category_btn.focus_mode = Control.FOCUS_NONE
	_category_btn.add_theme_font_override("font", _bold_font)
	_category_btn.add_theme_font_size_override("font_size", 18)
	_category_btn.add_theme_constant_override("icon_max_width", 20)
	_category_btn.add_theme_constant_override("h_separation", 8)
	_apply_btn_theme(_category_btn, COL_SURFACE, COL_GOLD, COL_CREAM, 10, 16)
	_category_btn.pressed.connect(func(): _set_category_open(not _category_popover.visible))
	bar.add_child(_category_btn)

	# Toggleable Active Effects Popover Button (closed by default, same pattern as Today's Visitors)
	_effects_btn = Button.new()
	_effects_btn.text = "Active Effects ▾"
	_effects_btn.icon = IC_SCALE
	_effects_btn.custom_minimum_size = Vector2(0, 48)
	_effects_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_effects_btn.focus_mode = Control.FOCUS_NONE
	_effects_btn.add_theme_font_override("font", FONT_INDER)
	_effects_btn.add_theme_font_size_override("font_size", 17)
	_effects_btn.add_theme_constant_override("icon_max_width", 20)
	_effects_btn.add_theme_constant_override("h_separation", 8)
	_apply_btn_theme(_effects_btn, COL_SURFACE, COL_BORDER_SUBTLE, COL_CREAM, 10, 16)
	_effects_btn.pressed.connect(func(): _set_effects_open(not _effects_popover.visible))
	bar.add_child(_effects_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	# Calm Bulk Actions scoped to the active category filter
	var bulk_down := _make_toolbar_action("−1 All", "Lower all visible items by 1 step")
	bulk_down.pressed.connect(func(): _adjust_visible_items(-1))
	bar.add_child(bulk_down)

	var bulk_up := _make_toolbar_action("+1 All", "Raise all visible items by 1 step")
	bulk_up.pressed.connect(func(): _adjust_visible_items(1))
	bar.add_child(bulk_up)

	var bulk_reset := _make_toolbar_action("Reset (0)", "Reset all visible items to base price (step 0)")
	bulk_reset.pressed.connect(_reset_visible_items)
	bar.add_child(bulk_reset)


func _make_toolbar_action(lbl: String, tip: String) -> Button:
	var btn := Button.new()
	btn.text = lbl
	btn.tooltip_text = tip
	btn.custom_minimum_size = Vector2(0, 48)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_override("font", _bold_font)
	btn.add_theme_font_size_override("font_size", 16)
	_apply_btn_theme(btn, COL_SURFACE, COL_BORDER_SUBTLE, COL_CREAM, 10, 14)
	return btn


func _build_body(parent: VBoxContainer) -> void:
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(_grid_scroll)

	_items_list = VBoxContainer.new()
	_items_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_list.add_theme_constant_override("separation", 10)
	_grid_scroll.add_child(_items_list)


# ── Popovers (Category & Active Effects) ─────────────────────────────────────

func _build_category_popover() -> void:
	_category_backdrop = Control.new()
	_category_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_category_backdrop.visible = false
	_category_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_set_category_open(false)
	)
	_root.add_child(_category_backdrop)

	_category_popover = PanelContainer.new()
	_category_popover.visible = false
	_category_popover.custom_minimum_size = Vector2(240, 0)
	var st := UIStyle.create_flat_stylebox(COL_ESPRESSO, 10, 8, 8)
	st.border_color = COL_GOLD
	st.set_border_width_all(2)
	st.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	st.shadow_size = 14
	_category_popover.add_theme_stylebox_override("panel", st)
	_root.add_child(_category_popover)

	_category_list_box = VBoxContainer.new()
	_category_list_box.add_theme_constant_override("separation", 4)
	_category_popover.add_child(_category_list_box)


func _build_effects_popover() -> void:
	_effects_backdrop = Control.new()
	_effects_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_effects_backdrop.visible = false
	_effects_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_set_effects_open(false)
	)
	_root.add_child(_effects_backdrop)

	_effects_popover = PanelContainer.new()
	_effects_popover.visible = false
	_effects_popover.custom_minimum_size = Vector2(340, 0)
	var st := UIStyle.create_flat_stylebox(COL_ESPRESSO, 12, 12, 12)
	st.border_color = COL_GOLD
	st.set_border_width_all(2)
	st.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	st.shadow_size = 14
	_effects_popover.add_theme_stylebox_override("panel", st)
	_root.add_child(_effects_popover)

	_effects_list_box = VBoxContainer.new()
	_effects_list_box.add_theme_constant_override("separation", 8)
	_effects_popover.add_child(_effects_list_box)


func _build_hover_tooltip() -> void:
	_hover_tooltip_col = VBoxContainer.new()
	_hover_tooltip_col.visible = false
	_hover_tooltip_col.z_index = 40
	_hover_tooltip_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_tooltip_col.add_theme_constant_override("separation", 8)
	_root.add_child(_hover_tooltip_col)

	_hover_timer = Timer.new()
	_hover_timer.one_shot = true
	_hover_timer.wait_time = 0.22
	_hover_timer.timeout.connect(_on_hover_timer_timeout)
	add_child(_hover_timer)


func _set_category_open(opened: bool) -> void:
	if not is_instance_valid(_category_popover):
		return
	if opened:
		_set_effects_open(false)
		_hide_hover_tooltip()
		_populate_category_popover()
		var br := _category_btn.get_global_rect()
		_category_popover.global_position = Vector2(br.position.x, br.end.y + 6.0)
	_category_backdrop.visible = opened
	_category_popover.visible = opened
	_refresh_category_btn()


func _set_effects_open(opened: bool) -> void:
	if not is_instance_valid(_effects_popover):
		return
	if opened:
		_set_category_open(false)
		_hide_hover_tooltip()
		_refresh_effects_popover()
		var br := _effects_btn.get_global_rect()
		_effects_popover.global_position = Vector2(br.position.x, br.end.y + 6.0)
	_effects_backdrop.visible = opened
	_effects_popover.visible = opened
	_refresh_effects_btn_label()


func _category_icon(cat_id: String) -> Texture2D:
	return UIStyle.get_category_icon(cat_id)


func _refresh_category_btn() -> void:
	if not is_instance_valid(_category_btn):
		return
	var lbl := "All Items"
	for c in CATEGORY_DEFS:
		if str(c["id"]) == _current_tab:
			lbl = str(c["label"])
			break
	var arrow := " ▴" if (_category_popover and _category_popover.visible) else " ▾"
	_category_btn.text = lbl + arrow
	_category_btn.icon = _category_icon(_current_tab)


func _populate_category_popover() -> void:
	for ch in _category_list_box.get_children():
		ch.queue_free()

	for c in CATEGORY_DEFS:
		var cid := str(c["id"])
		if cid != "all" and cid != "hot" and not _has_owned_items_for_tab(cid):
			continue
		var btn := Button.new()
		btn.text = str(c["label"])
		btn.icon = _category_icon(cid)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 38)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_override("font", _bold_font if cid == _current_tab else FONT_INDER)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_constant_override("icon_max_width", 18)
		btn.add_theme_constant_override("h_separation", 8)
		var is_cur := (cid == _current_tab)
		_apply_btn_theme(btn, COL_CARD_HOVER if is_cur else Color(0, 0, 0, 0), COL_GOLD if is_cur else Color(0, 0, 0, 0), COL_GOLD_BRIGHT if is_cur else COL_CREAM, 8, 12)
		btn.pressed.connect(func():
			_current_tab = cid
			_set_category_open(false)
			if is_instance_valid(AudioManager):
				AudioManager.play_sfx("tab_switch")
			refresh_catalog()
			_animate_rows_domino_in()
		)
		_category_list_box.add_child(btn)


func _refresh_effects_popover() -> void:
	if not is_instance_valid(_effects_list_box):
		return
	for ch in _effects_list_box.get_children():
		ch.queue_free()

	var cards := _collect_global_effect_cards()
	if cards.is_empty():
		var empty := Label.new()
		empty.text = "No active pricing modifiers today.\nBase customer tolerance applies."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_override("font", FONT_INDER)
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", COL_CREAM_MUTED)
		_effects_list_box.add_child(empty)
	else:
		for c in cards:
			_effects_list_box.add_child(_make_effect_card(str(c["title"]), c["stats"]))
	_refresh_effects_btn_label(cards.size())


func _refresh_effects_btn_label(count_override: int = -1) -> void:
	if not is_instance_valid(_effects_btn):
		return
	var cnt := count_override if count_override >= 0 else _collect_global_effect_cards().size()
	var arrow := " ▴" if (_effects_popover and _effects_popover.visible) else " ▾"
	_effects_btn.text = ("Active Effects (%d)%s" % [cnt, arrow]) if cnt > 0 else ("Active Effects%s" % arrow)


# ── Effect Cards (Exact PricingOverlay Style) ────────────────────────────────

func _make_effect_card(source_name: String, stats: Array) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st_box := UIStyle.create_flat_stylebox(COL_ESPRESSO, 10, 14, 10)
	st_box.border_color = COL_GOLD
	st_box.set_border_width_all(2)
	st_box.shadow_size = 8
	st_box.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	card.add_theme_stylebox_override("panel", st_box)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vb)

	var title_lbl := Label.new()
	title_lbl.text = source_name
	title_lbl.add_theme_font_override("font", _bold_font)
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", COL_GOLD_SOFT)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(title_lbl)

	for st in stats:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(row)

		var lbl := Label.new()
		lbl.text = "▸ " + str(st.get("label", ""))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_override("font", FONT_INDER)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", COL_CREAM)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lbl)

		var val := Label.new()
		val.text = str(st.get("value", ""))
		val.add_theme_font_override("font", _bold_font)
		val.add_theme_font_size_override("font_size", 15)
		var tone := str(st.get("tone", "pos"))
		var val_col := COL_DISCOUNT if tone == "pos" else (COL_DANGER if tone == "neg" else COL_GOLD_SOFT)
		val.add_theme_color_override("font_color", val_col)
		val.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(val)

	return card


func _collect_global_effect_cards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if is_instance_valid(StoreEventManager):
		for ev in StoreEventManager.get_active_events():
			if ev == null:
				continue
			var rows := ev.build_stat_rows()
			if not rows.is_empty():
				out.append({"title": ev.event_name, "stats": rows})

	if is_instance_valid(StoryManager):
		var feat_cat := StoryManager.get_poster_featured_category()
		if feat_cat != "":
			out.append({"title": "Promo Poster", "stats": [
				{"label": "Featured:", "value": StoryManager.get_category_display_name(feat_cat), "tone": "neu"},
				{"label": "Sale Bonus:", "value": "+₱3", "tone": "pos"},
			]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_SILVER_TOLERANCE):
			out.append({"title": "Silver Tolerance", "stats": [{"label": "Price Tolerance:", "value": "+1", "tone": "pos"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_SILVER_LEDGER_GRACE):
			out.append({"title": "Silver Ledger Grace", "stats": [{"label": "Price Tolerance:", "value": "+1", "tone": "pos"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_SHARP_BARGAINERS):
			out.append({"title": "Sharp Bargainers", "stats": [{"label": "Price Tolerance:", "value": "+2", "tone": "pos"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_EERIE_MIST_RUSH):
			out.append({"title": "Eerie Mist Rush", "stats": [{"label": "Price Tolerance:", "value": "-1", "tone": "neg"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_RELUCTANT_CARE):
			out.append({"title": "Reluctant Care", "stats": [{"label": "Price Tolerance:", "value": "-1", "tone": "neg"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_RESTLESS_CROWD):
			out.append({"title": "Restless Crowd", "stats": [
				{"label": "Price Tolerance:", "value": "-1", "tone": "neg"},
				{"label": "Sale Bonus (≤ +1):", "value": "+15%", "tone": "pos"},
			]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_STUBBORN_HAGGLERS):
			out.append({"title": "Stubborn Hagglers", "stats": [{"label": "Price Tolerance:", "value": "-1", "tone": "neg"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_MAYARI_FULL_MOON):
			out.append({"title": "Blessing of the Full Moon", "stats": [{"label": "Price Tolerance:", "value": "+1", "tone": "pos"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_SOUR_CHANGE):
			out.append({"title": "Sour Change", "stats": [{"label": "Price Tolerance:", "value": "-1", "tone": "neg"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_DUWENDE_MISCHIEF):
			out.append({"title": "Duwende Mischief", "stats": [{"label": "Price Tolerance:", "value": "-1", "tone": "neg"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_PHANTOM_QUEUE):
			out.append({"title": "Phantom Queue", "stats": [{"label": "Price Tolerance:", "value": "-1", "tone": "neg"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_BLOOD_MOON_BARGAIN):
			out.append({"title": "Blood Moon Bargain", "stats": [
				{"label": "Price Tolerance:", "value": "-2", "tone": "neg"},
				{"label": "All Cash Sales:", "value": "+25%", "tone": "pos"},
			]})
		if StoryManager.is_fridge_warm:
			out.append({"title": "Warm Fridge", "stats": [{"label": "Cold Item Value:", "value": "-20%", "tone": "neg"}]})
	return out


func _collect_item_effect_cards(item: ItemData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if is_instance_valid(StoreEventManager):
		for ev in StoreEventManager.get_active_events():
			if ev == null:
				continue
			var stats: Array = []
			var affects := ev.affects_item(item)
			var tol := (ev.tolerance_offset if affects else 0) + ev.global_tolerance_offset
			if tol != 0:
				stats.append({"label": "Price Tolerance:", "value": "%+d" % tol, "tone": "pos" if tol > 0 else "neg"})
			if affects:
				var dp := int(roundf((ev.demand_multiplier - 1.0) * 100.0))
				if dp != 0:
					stats.append({"label": "Item Demand:", "value": "%+d%%" % dp, "tone": "pos" if dp > 0 else "neg"})
			if not stats.is_empty():
				out.append({"title": ev.event_name, "stats": stats})

	if is_instance_valid(StoryManager):
		if StoryManager.get_featured_category_boost_count(item.category) > 0:
			var f_stats := [{"label": "Featured Bonus:", "value": "+₱3", "tone": "pos"}]
			if StoryManager.has_mayari_card(MayariCardRegistry.CARD_CURBSIDE_GLOW):
				f_stats.append({"label": "Curbside Glow:", "value": "+15%", "tone": "pos"})
			out.append({"title": "Promo Poster", "stats": f_stats})

		var fans := StoryManager.get_regulars_who_like_item(item, true)
		if not fans.is_empty():
			var names := PackedStringArray()
			for f in fans:
				names.append(f.character_name)
			out.append({"title": "Today's Visitor Pick", "stats": [{"label": "Craved by:", "value": ", ".join(names), "tone": "pos"}]})

		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_SILVER_TOLERANCE):
			out.append({"title": "Silver Tolerance", "stats": [{"label": "Price Tolerance:", "value": "+1", "tone": "pos"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_SILVER_LEDGER_GRACE):
			out.append({"title": "Silver Ledger Grace", "stats": [{"label": "Price Tolerance:", "value": "+1", "tone": "pos"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_SHARP_BARGAINERS):
			out.append({"title": "Sharp Bargainers", "stats": [{"label": "Price Tolerance:", "value": "+2", "tone": "pos"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_EERIE_MIST_RUSH):
			out.append({"title": "Eerie Mist Rush", "stats": [{"label": "Price Tolerance:", "value": "-1", "tone": "neg"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_RELUCTANT_CARE):
			out.append({"title": "Reluctant Care", "stats": [{"label": "Price Tolerance:", "value": "-1", "tone": "neg"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_RESTLESS_CROWD):
			out.append({"title": "Restless Crowd", "stats": [
				{"label": "Price Tolerance:", "value": "-1", "tone": "neg"},
				{"label": "Sale Bonus (≤ +1):", "value": "+15%", "tone": "pos"},
			]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_STUBBORN_HAGGLERS):
			out.append({"title": "Stubborn Hagglers", "stats": [{"label": "Price Tolerance:", "value": "-1", "tone": "neg"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_MAYARI_FULL_MOON):
			out.append({"title": "Blessing of the Full Moon", "stats": [{"label": "Price Tolerance:", "value": "+1", "tone": "pos"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_SOUR_CHANGE):
			out.append({"title": "Sour Change", "stats": [{"label": "Price Tolerance:", "value": "-1", "tone": "neg"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_DUWENDE_MISCHIEF):
			out.append({"title": "Duwende Mischief", "stats": [{"label": "Price Tolerance:", "value": "-1", "tone": "neg"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_PHANTOM_QUEUE):
			out.append({"title": "Phantom Queue", "stats": [{"label": "Price Tolerance:", "value": "-1", "tone": "neg"}]})
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_BLOOD_MOON_BARGAIN):
			out.append({"title": "Blood Moon Bargain", "stats": [
				{"label": "Price Tolerance:", "value": "-2", "tone": "neg"},
				{"label": "All Cash Sales:", "value": "+25%", "tone": "pos"},
			]})
		if item.type == ItemData.ItemType.FRIDGE and StoryManager.is_fridge_warm:
			out.append({"title": "Warm Fridge", "stats": [{"label": "Sale Value:", "value": "-20%", "tone": "neg"}]})
	return out


func _get_effective_item_tolerance(item: ItemData) -> int:
	var tol := 0
	if is_instance_valid(StoreEventManager):
		tol += StoreEventManager.get_item_tolerance_offset(item)
	if is_instance_valid(StoryManager):
		tol += StoryManager.get_mayari_tolerance_offset()
	return tol


func _get_step_accent_color(step: int, eff_tol: int) -> Color:
	return UIStyle.get_price_step_color(step, eff_tol)


# ── Catalog & Product Rows ───────────────────────────────────────────────────

func _is_item_hot(item: ItemData) -> bool:
	if is_instance_valid(StoreEventManager) and StoreEventManager.is_item_in_demand(item):
		return true
	if is_instance_valid(StoryManager):
		if StoryManager.get_featured_category_boost_count(item.category) > 0:
			return true
		if not StoryManager.get_regulars_who_like_item(item, true).is_empty():
			return true
	return false


func _has_owned_items_for_tab(tab_id: String) -> bool:
	for item in InventoryManager._items:
		if item and item.can_be_sold and item.tier <= StoryManager.current_tier and _matches_tab_id(item, tab_id):
			return true
	return false


func _matches_tab_id(item: ItemData, tab_id: String) -> bool:
	if tab_id == "all":
		return true
	if tab_id == "hot":
		return _is_item_hot(item)
	return item.category.to_lower() == tab_id


func refresh_catalog() -> void:
	for child in _items_list.get_children():
		_items_list.remove_child(child)
		child.queue_free()
	_item_rows.clear()
	_visible_items.clear()

	var owned_tier: int = StoryManager.current_tier
	for item in InventoryManager._items:
		if not item or not item.can_be_sold or item.tier > owned_tier:
			continue
		if _matches_tab_id(item, _current_tab):
			_visible_items.append(item)

	if _visible_items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No featured or in-demand items right now." if _current_tab == "hot" else "No owned items in this category yet."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_override("font", FONT_INDER)
		empty_lbl.add_theme_font_size_override("font_size", 18)
		empty_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
		_items_list.add_child(empty_lbl)
		return

	# Sort: in-stock hot items first, then in-stock, then out-of-stock, then by tier/name
	_visible_items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		var a_stk := InventoryManager.get_stock(a) > 0
		var b_stk := InventoryManager.get_stock(b) > 0
		if a_stk != b_stk:
			return a_stk
		var a_hot := _is_item_hot(a)
		var b_hot := _is_item_hot(b)
		if a_hot != b_hot:
			return a_hot
		var at := a.get_effective_tier()
		var bt := b.get_effective_tier()
		if at != bt:
			return at < bt
		return a.item_name.naturalnocasecmp_to(b.item_name) < 0
	)

	for item in _visible_items:
		_items_list.add_child(_create_product_row(item))


func _create_product_row(item: ItemData) -> PanelContainer:
	var stock := InventoryManager.get_stock(item)
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 74)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var normal_st := UIStyle.create_flat_stylebox(COL_CARD if stock > 0 else Color(0.10, 0.088, 0.078, 0.72), 10, 14, 10)
	normal_st.border_color = COL_BORDER_SUBTLE
	normal_st.set_border_width_all(1)
	var hover_st: StyleBoxFlat = normal_st.duplicate()
	hover_st.bg_color = COL_CARD_HOVER
	hover_st.border_color = COL_GOLD
	row.add_theme_stylebox_override("panel", normal_st)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(hbox)

	# Product Icon
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(52, 52)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = item.texture
	icon_rect.modulate = Color.WHITE if stock > 0 else Color(0.62, 0.60, 0.56, 0.75)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_rect)

	# Name, Tier, Stock & Compact Badges
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", 3)
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(info_vbox)

	var top_line := HBoxContainer.new()
	top_line.add_theme_constant_override("separation", 8)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(top_line)

	var name_lbl := Label.new()
	name_lbl.text = item.item_name
	name_lbl.add_theme_font_override("font", _bold_font)
	name_lbl.add_theme_font_size_override("font_size", 19)
	name_lbl.add_theme_color_override("font_color", COL_CREAM if stock > 0 else COL_CREAM_MUTED)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_line.add_child(name_lbl)

	var tier_lbl := Label.new()
	var eff_tier := item.get_effective_tier()
	tier_lbl.text = "Tier %d" % eff_tier
	tier_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tier_lbl.add_theme_font_override("font", _bold_font)
	tier_lbl.add_theme_font_size_override("font_size", 13)
	tier_lbl.add_theme_color_override("font_color", UIStyle.get_tier_color(eff_tier))
	tier_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_line.add_child(tier_lbl)

	var sub_line := HBoxContainer.new()
	sub_line.add_theme_constant_override("separation", 10)
	sub_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(sub_line)

	var base_lbl := Label.new()
	base_lbl.text = "Base ₱%.2f" % item.price
	base_lbl.add_theme_font_override("font", FONT_INDER)
	base_lbl.add_theme_font_size_override("font_size", 14)
	base_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	base_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_line.add_child(base_lbl)

	var stock_lbl := Label.new()
	stock_lbl.text = ("Stock %d" % stock) if stock > 0 else "Out of Stock"
	stock_lbl.add_theme_font_override("font", _bold_font if stock == 0 else FONT_INDER)
	stock_lbl.add_theme_font_size_override("font_size", 14)
	stock_lbl.add_theme_color_override("font_color", COL_CORAL if stock == 0 else COL_CREAM_MUTED)
	stock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_line.add_child(stock_lbl)

	# Max 2 compact PricingOverlay-style badges (In Demand / Featured +₱3 / Warm)
	var badge_cnt := 0
	if is_instance_valid(StoreEventManager) and StoreEventManager.is_item_in_demand(item):
		sub_line.add_child(_make_inline_badge("In Demand", Color(0.28, 0.20, 0.06, 0.92), COL_GOLD_SOFT))
		badge_cnt += 1
	if badge_cnt < 2 and is_instance_valid(StoryManager) and StoryManager.get_featured_category_boost_count(item.category) > 0:
		sub_line.add_child(_make_inline_badge("Featured +₱3", Color(0.12, 0.24, 0.14, 0.92), COL_DISCOUNT))
		badge_cnt += 1
	if badge_cnt < 2 and item.type == ItemData.ItemType.FRIDGE and is_instance_valid(StoryManager) and StoryManager.is_fridge_warm:
		sub_line.add_child(_make_inline_badge("Warm -20%", Color(0.28, 0.14, 0.08, 0.92), COL_WARM))

	# Center: ‹ [Interactive PriceStepGauge] › (NO circles!)
	var step_hbox := HBoxContainer.new()
	step_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	step_hbox.add_theme_constant_override("separation", 8)
	step_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(step_hbox)

	var minus_btn := Button.new()
	minus_btn.text = "‹"
	minus_btn.custom_minimum_size = Vector2(36, 36)
	minus_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	minus_btn.focus_mode = Control.FOCUS_NONE
	minus_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	minus_btn.add_theme_font_override("font", _bold_font)
	minus_btn.add_theme_font_size_override("font_size", 24)
	_apply_btn_theme(minus_btn, COL_SURFACE, COL_BORDER_SUBTLE, COL_GOLD_SOFT, 8)
	minus_btn.pressed.connect(func(): _adjust_step(item, -1))
	step_hbox.add_child(minus_btn)

	var gauge := LedgerStepGauge.new()
	gauge.custom_minimum_size = Vector2(240, 34)
	gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gauge.step_requested.connect(func(ns: int): _set_step(item, ns))
	step_hbox.add_child(gauge)

	var plus_btn := Button.new()
	plus_btn.text = "›"
	plus_btn.custom_minimum_size = Vector2(36, 36)
	plus_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plus_btn.focus_mode = Control.FOCUS_NONE
	plus_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	plus_btn.add_theme_font_override("font", _bold_font)
	plus_btn.add_theme_font_size_override("font_size", 24)
	_apply_btn_theme(plus_btn, COL_SURFACE, COL_BORDER_SUBTLE, COL_GOLD_SOFT, 8)
	plus_btn.pressed.connect(func(): _adjust_step(item, 1))
	step_hbox.add_child(plus_btn)

	# Right: Selling Price & Net Delta
	var price_vbox := VBoxContainer.new()
	price_vbox.custom_minimum_size = Vector2(142, 0)
	price_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	price_vbox.add_theme_constant_override("separation", 2)
	price_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(price_vbox)

	var price_lbl := Label.new()
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_lbl.add_theme_font_override("font", _bold_font)
	price_lbl.add_theme_font_size_override("font_size", 22)
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_vbox.add_child(price_lbl)

	var delta_lbl := Label.new()
	delta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	delta_lbl.add_theme_font_override("font", FONT_INDER)
	delta_lbl.add_theme_font_size_override("font_size", 13)
	delta_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_vbox.add_child(delta_lbl)

	# Hover + mouse-wheel price stepping on row & stepper controls
	var on_wheel := func(ev: InputEvent, ctrl: Control):
		if ev is InputEventMouseButton and ev.pressed:
			if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
				_adjust_step(item, 1)
				ctrl.accept_event()
			elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_adjust_step(item, -1)
				ctrl.accept_event()

	for ctrl in [minus_btn, gauge, plus_btn]:
		ctrl.gui_input.connect(on_wheel.bind(ctrl))

	row.mouse_entered.connect(func():
		row.add_theme_stylebox_override("panel", hover_st)
		_begin_hover_tooltip(item, row)
	)
	row.mouse_exited.connect(func():
		var local_m := row.get_local_mouse_position()
		if not Rect2(Vector2.ZERO, row.size).has_point(local_m):
			row.add_theme_stylebox_override("panel", normal_st)
			_end_hover_tooltip(item)
	)

	_item_rows[item] = {
		"gauge": gauge,
		"price_lbl": price_lbl,
		"delta_lbl": delta_lbl,
		"minus_btn": minus_btn,
		"plus_btn": plus_btn,
	}

	_update_row_display(item)
	return row


func _make_inline_badge(txt: String, bg: Color, fg: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := UIStyle.create_flat_stylebox(bg, 6, 8, 2)
	st.border_color = fg
	st.set_border_width_all(1)
	pill.add_theme_stylebox_override("panel", st)
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_override("font", _bold_font)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", fg)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(lbl)
	return pill


func _begin_hover_tooltip(item: ItemData, row: Control) -> void:
	_hovered_item = item
	_hovered_row = row
	_hover_timer.start()


func _end_hover_tooltip(item: ItemData) -> void:
	if _hovered_item == item:
		_hide_hover_tooltip()


func _hide_hover_tooltip() -> void:
	_hovered_item = null
	_hovered_row = null
	if is_instance_valid(_hover_timer):
		_hover_timer.stop()
	if is_instance_valid(_hover_tooltip_col):
		_hover_tooltip_col.visible = false


func _on_hover_timer_timeout() -> void:
	if _hovered_item == null or not is_instance_valid(_hovered_row) or not is_open:
		return
	if (_category_popover and _category_popover.visible) or (_effects_popover and _effects_popover.visible):
		return
	var cards := _collect_item_effect_cards(_hovered_item)
	if cards.is_empty():
		_hover_tooltip_col.visible = false
		return
	for ch in _hover_tooltip_col.get_children():
		ch.queue_free()
	for c in cards:
		_hover_tooltip_col.add_child(_make_effect_card(str(c["title"]), c["stats"]))
	_hover_tooltip_col.visible = true
	_hover_tooltip_col.reset_size()
	call_deferred("_position_hover_tooltip")


func _position_hover_tooltip() -> void:
	if not is_instance_valid(_hover_tooltip_col) or not _hover_tooltip_col.visible or not is_instance_valid(_hovered_row):
		return
	var rr := _hovered_row.get_global_rect()
	var vp := get_viewport().get_visible_rect().size
	var tsz := _hover_tooltip_col.size
	var tx := clampf(rr.end.x - tsz.x - 16.0, 16.0, vp.x - tsz.x - 16.0)
	var ty := rr.end.y + 6.0
	if ty + tsz.y > vp.y - 16.0:
		ty = maxf(16.0, rr.position.y - tsz.y - 6.0)
	_hover_tooltip_col.global_position = Vector2(tx, ty)


# ── Stepper & Bulk Logic ─────────────────────────────────────────────────────

func _set_step(item: ItemData, new_step: int) -> void:
	if not item:
		return
	var clamped := clampi(new_step, ItemData.MIN_STEP, ItemData.MAX_STEP)
	if clamped == item.current_step:
		return
	InventoryManager.set_item_step([item], clamped)
	if is_instance_valid(AudioManager):
		AudioManager.play_sfx("interact")
	_update_row_display(item)


func _adjust_step(item: ItemData, delta: int) -> void:
	if item:
		_set_step(item, item.current_step + delta)


func _adjust_visible_items(delta: int) -> void:
	var changed := false
	for item in _visible_items:
		var ns := clampi(item.current_step + delta, ItemData.MIN_STEP, ItemData.MAX_STEP)
		if ns != item.current_step:
			InventoryManager.set_item_step([item], ns)
			_update_row_display(item)
			changed = true
	if changed and is_instance_valid(AudioManager):
		AudioManager.play_sfx("interact")


func _reset_visible_items() -> void:
	var changed := false
	for item in _visible_items:
		if item.current_step != 0:
			InventoryManager.set_item_step([item], 0)
			_update_row_display(item)
			changed = true
	if changed and is_instance_valid(AudioManager):
		AudioManager.play_sfx("drop")


func _update_row_display(item: ItemData) -> void:
	if not _item_rows.has(item):
		return
	var rd: Dictionary = _item_rows[item]
	var gauge: LedgerStepGauge = rd["gauge"]
	var price_lbl: Label = rd["price_lbl"]
	var delta_lbl: Label = rd["delta_lbl"]
	var minus_btn: Button = rd["minus_btn"]
	var plus_btn: Button = rd["plus_btn"]

	var step: int = item.current_step
	var final_price: float = item.get_final_price()
	var is_warm := item.type == ItemData.ItemType.FRIDGE and is_instance_valid(StoryManager) and StoryManager.is_fridge_warm
	var display_price := maxf(1.0, snapped(final_price * StoryManager.FRIDGE_WARM_VALUE_MULTIPLIER, 0.5)) if is_warm else final_price
	var diff := display_price - item.price
	var eff_tol := _get_effective_item_tolerance(item)
	var accent := _get_step_accent_color(step, eff_tol)

	gauge.step = step
	gauge.accent_color = accent
	gauge.queue_redraw()

	price_lbl.text = "₱%.2f" % display_price
	price_lbl.add_theme_color_override("font_color", accent)

	var diff_txt := ("+₱%.2f" % diff) if diff > 0.005 else (("-₱%.2f" % absf(diff)) if diff < -0.005 else "+₱0.00")
	if is_instance_valid(StoryManager) and StoryManager.get_featured_category_boost_count(item.category) > 0:
		diff_txt += " (+₱3)"
	delta_lbl.text = diff_txt
	delta_lbl.add_theme_color_override("font_color", accent if step != 0 else COL_CREAM_MUTED)

	minus_btn.disabled = (step <= ItemData.MIN_STEP)
	plus_btn.disabled = (step >= ItemData.MAX_STEP)


func _apply_btn_theme(btn: Button, bg: Color, border: Color, fg: Color, radius: int = 8, pad_x: int = 10) -> void:
	var st := UIStyle.create_flat_stylebox(bg, radius, pad_x, 6)
	st.border_color = border
	st.set_border_width_all(1 if border.a > 0.01 else 0)
	var hov: StyleBoxFlat = st.duplicate()
	hov.bg_color = bg.lightened(0.08) if bg.a > 0.01 else COL_CARD_HOVER
	hov.border_color = COL_GOLD_BRIGHT if border.a > 0.01 else COL_BORDER_SUBTLE
	hov.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.add_theme_stylebox_override("disabled", st)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", COL_GOLD_BRIGHT)
	btn.add_theme_color_override("font_disabled_color", Color(fg.r, fg.g, fg.b, 0.35))
