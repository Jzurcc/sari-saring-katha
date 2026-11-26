class_name TopBannerQueue
extends RefCounted

## Centralized FIFO queue and shared visual shell for all top-center banners:
## NoticeOverlay, MayariCardHUD (Morning Moon Cards & Radio Event/Visitor Cards),
## RepRankUpHUD, and TierAdvanceOverlay.
## Guarantees zero overlaps, safe-zone positioning, and consistent Espresso + Gold styling.

const COL_BG := Color(0.064, 0.054, 0.046, 0.96)
const COL_OUTLINE := Color(0.05, 0.04, 0.03, 0.95)
const COL_GOLD := Color(0.835, 0.624, 0.278, 1.0)
const COL_CREAM := Color(1.0, 0.94, 0.83, 1.0)
const COL_CREAM_MUTED := Color(0.86, 0.80, 0.70, 0.92)

static var _queue: Array[Callable] = []
static var _busy: bool = false


static func enqueue(show_fn: Callable) -> void:
	if not show_fn.is_valid():
		return
	_queue.append(show_fn)
	if not _busy:
		_pump()


static func complete() -> void:
	_busy = false
	_pump()


static func clear() -> void:
	_queue.clear()
	_busy = false


static func get_pending_count() -> int:
	return _queue.size()


static func get_safe_top_y(vp_height: float) -> float:
	return clampf(vp_height * 0.042, 26.0, 48.0)


## Exact 1:1 event/moon card dimensions matching EventsOverlay & MayariTallyOverlay.
static func get_unified_card_size(vp_size: Vector2) -> Vector2:
	var cw := clampf(vp_size.x * 0.580, 560.0, 1200.0)
	var ch := maxf(130.0, (vp_size.y * 0.680 - 135.0) / 3.0)
	return Vector2(cw, ch)


static func _pump() -> void:
	while not _queue.is_empty():
		var next_fn: Callable = _queue.pop_front()
		if next_fn.is_valid():
			_busy = true
			next_fn.call()
			return
	_busy = false


## Modernized Dark Warm Espresso shell with 4px semantic left accent bar and crisp 1px outer frame.
static func create_banner_style(accent_color: Color, pad_x: int = 22, pad_y: int = 14) -> StyleBoxFlat:
	var style := UIStyle.create_flat_stylebox(COL_BG, 10, pad_x, pad_y)
	style.content_margin_bottom = pad_y + 7
	style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.88)
	style.border_width_left = 4
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	style.shadow_size = 20
	style.shadow_offset = Vector2(0, 6)
	return style


class BannerTimerBar extends Control:
	var bar_color: Color = Color(0.835, 0.624, 0.278, 0.80)
	var progress: float = 1.0:
		set(v):
			progress = clampf(v, 0.0, 1.0)
			queue_redraw()

	func _draw() -> void:
		if progress <= 0.005 or size.x <= 4.0 or size.y <= 4.0:
			return
		var h := 3.0
		var w := size.x * progress
		# Draw down inside the bottom content_margin so it sits cleanly near the bottom border, well below icons & text
		draw_rect(Rect2(0.0, size.y + 10.0, w, h), bar_color, true)


## Creates a subtle 3px draining timer strip drawn along the bottom edge of a banner PanelContainer.
static func attach_timer_bar(banner: Control, accent_color: Color) -> BannerTimerBar:
	var bar := BannerTimerBar.new()
	bar.bar_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.80)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(bar)
	return bar


## Animates the timer bar draining smoothly from full width to 0 over duration seconds.
static func start_timer_bar(owner: Node, bar: Control, duration: float) -> Tween:
	if not is_instance_valid(bar) or not is_instance_valid(owner):
		return null
	if bar is BannerTimerBar:
		(bar as BannerTimerBar).progress = 1.0
		var tw := owner.create_tween()
		tw.tween_property(bar, "progress", 0.0, maxf(0.1, duration)).set_trans(Tween.TRANS_LINEAR)
		return tw
	return null


## Compact inline keycap pill (e.g. [J], [C]) matching MayariCardHUD's keycap style.
static func create_keycap_pill(key_text: String) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := UIStyle.create_flat_stylebox(Color(0.12, 0.10, 0.085, 0.96), 5, 8, 2)
	st.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.80)
	st.set_border_width_all(1)
	pill.add_theme_stylebox_override("panel", st)

	var lbl := Label.new()
	lbl.text = key_text
	lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", COL_CREAM)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(lbl)
	return pill
