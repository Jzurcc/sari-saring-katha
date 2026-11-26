class_name TopBannerQueue
extends RefCounted

## Centralized FIFO queue and shared visual shell for all top-center banners:
## NoticeOverlay, RepRankUpHUD, and TierAdvanceOverlay.
## Guarantees zero overlaps and zero dropped toasts.

const COL_BG := Color(0.068, 0.055, 0.047, 0.96)
const COL_OUTLINE := Color(0.06, 0.045, 0.03, 0.95)
const COL_CREAM := Color(1.0, 0.95, 0.84, 1.0)
const COL_CREAM_MUTED := Color(0.92, 0.87, 0.77, 0.95)

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


static func _pump() -> void:
	while not _queue.is_empty():
		var next_fn: Callable = _queue.pop_front()
		if next_fn.is_valid():
			_busy = true
			next_fn.call()
			return
	_busy = false


static func create_banner_style(border_color: Color, pad_x: int = 24, pad_y: int = 14) -> StyleBoxFlat:
	var style := UIStyle.create_flat_stylebox(COL_BG, 14, pad_x, pad_y)
	style.border_color = Color(border_color.r, border_color.g, border_color.b, 0.84)
	style.set_border_width_all(2)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.60)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 6)
	return style
