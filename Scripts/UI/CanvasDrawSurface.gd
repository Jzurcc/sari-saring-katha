class_name CanvasDrawSurface
extends Control

## Interactive raster paint + product-sticker canvas surface for Roof Signage & Promo Poster.
## Supports smooth interpolated brush/eraser strokes, iterative scanline flood-fill bucket,
## composited eyedropper picking, sticker selection/drag/scale/rotation, 25-step undo/redo,
## and exact CPU alpha-composited PNG export.

signal stroke_committed(color_used: Color)
signal eyedropper_picked(color: Color)
signal stickers_changed()
signal sticker_selection_changed(selected_index: int)
signal history_changed(can_undo: bool, can_redo: bool)

enum Tool { BRUSH, ERASER, BUCKET, EYEDROPPER, SELECT }

const MAX_UNDO := 25
const FLOOD_TOLERANCE := 22

var canvas_size: Vector2i = Vector2i(1024, 368)
var active_tool: Tool = Tool.BRUSH:
	set(v):
		active_tool = v
		if active_tool != Tool.SELECT and _selected_sticker != -1:
			_selected_sticker = -1
			sticker_selection_changed.emit(-1)
		_update_cursor_shape()
		queue_redraw()

var brush_color: Color = Color(0.14, 0.12, 0.10, 1.0)
var brush_radius: float = 12.0:
	set(v):
		brush_radius = clampf(v, 1.5, 64.0)
		queue_redraw()

var _paint_image: Image = null
var _paint_texture: ImageTexture = null
var _stickers: Array[Dictionary] = []
var _tex_cache: Dictionary = {} # item_path -> Texture2D
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []

var _selected_sticker: int = -1
var _is_painting: bool = false
var _last_paint_px: Vector2 = Vector2.ZERO
var _is_dragging_sticker: bool = false
var _sticker_drag_offset: Vector2 = Vector2.ZERO
var _hover_screen_pos: Vector2 = Vector2.ZERO
var _is_hovering: bool = false
var _canvas_rect: Rect2 = Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	mouse_exited.connect(func():
		_is_hovering = false
		queue_redraw()
	)
	_init_blank_canvas(canvas_size)


func setup_canvas(target_size: Vector2i, paint_img: Image = null, saved_stickers: Array = []) -> void:
	canvas_size = target_size
	if paint_img != null and not paint_img.is_empty():
		var img := paint_img.duplicate() as Image
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		if img.get_size() != canvas_size:
			img.resize(canvas_size.x, canvas_size.y, Image.INTERPOLATE_BILINEAR)
		_paint_image = img
		_paint_texture = ImageTexture.create_from_image(_paint_image)
	else:
		_init_blank_canvas(canvas_size)

	_stickers.clear()
	for entry in saved_stickers:
		if entry is Dictionary:
			var item_path := str(entry.get("item_path", ""))
			if item_path == "":
				continue
			var pos_x := float(entry.get("x", float(canvas_size.x) * 0.5))
			var pos_y := float(entry.get("y", float(canvas_size.y) * 0.5))
			_stickers.append({
				"item_path": item_path,
				"item_name": str(entry.get("item_name", "")),
				"category": str(entry.get("category", "")),
				"x": clampf(pos_x, 0.0, float(canvas_size.x)),
				"y": clampf(pos_y, 0.0, float(canvas_size.y)),
				"scale": clampf(float(entry.get("scale", 1.0)), 0.35, 2.2),
				"rot": float(entry.get("rot", 0.0)),
			})
			_get_item_texture(item_path)

	_selected_sticker = -1
	_undo_stack.clear()
	_redo_stack.clear()
	_emit_history()
	stickers_changed.emit()
	sticker_selection_changed.emit(-1)
	queue_redraw()


func _init_blank_canvas(sz: Vector2i) -> void:
	canvas_size = sz
	_paint_image = Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	_paint_image.fill(Color.WHITE)
	_paint_texture = ImageTexture.create_from_image(_paint_image)


func get_paint_image() -> Image:
	return _paint_image.duplicate() as Image


func get_serialized_stickers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in _stickers:
		out.append({
			"item_path": str(s.get("item_path", "")),
			"item_name": str(s.get("item_name", "")),
			"category": str(s.get("category", "")),
			"x": float(s.get("x", 0.0)),
			"y": float(s.get("y", 0.0)),
			"scale": float(s.get("scale", 1.0)),
			"rot": float(s.get("rot", 0.0)),
		})
	return out


func get_selected_sticker_index() -> int:
	return _selected_sticker


func get_selected_sticker() -> Dictionary:
	if _selected_sticker >= 0 and _selected_sticker < _stickers.size():
		return _stickers[_selected_sticker]
	return {}


func get_sticker_count() -> int:
	return _stickers.size()


func get_sticker_category_counts() -> Dictionary:
	var counts := {}
	for s in _stickers:
		var cat := str(s.get("category", ""))
		if cat == "":
			continue
		counts[cat] = int(counts.get(cat, 0)) + 1
	return counts


func add_sticker(item: ItemData) -> void:
	if item == null or item.resource_path == "":
		return
	_push_undo()
	_get_item_texture(item.resource_path)
	var idx_offset := float((_stickers.size() % 5) - 2) * 28.0
	var cx := clampf(float(canvas_size.x) * 0.5 + idx_offset, 48.0, float(canvas_size.x) - 48.0)
	var cy := clampf(float(canvas_size.y) * 0.5 + float((_stickers.size() % 3) - 1) * 22.0, 48.0, float(canvas_size.y) - 48.0)
	_stickers.append({
		"item_path": item.resource_path,
		"item_name": item.item_name,
		"category": item.category,
		"x": cx,
		"y": cy,
		"scale": 1.0,
		"rot": 0.0,
	})
	_selected_sticker = _stickers.size() - 1
	active_tool = Tool.SELECT
	stickers_changed.emit()
	sticker_selection_changed.emit(_selected_sticker)
	queue_redraw()


func adjust_selected_scale(delta: float) -> void:
	if _selected_sticker < 0 or _selected_sticker >= _stickers.size():
		return
	_push_undo()
	var s := _stickers[_selected_sticker]
	s["scale"] = clampf(float(s.get("scale", 1.0)) + delta, 0.35, 2.2)
	sticker_selection_changed.emit(_selected_sticker)
	queue_redraw()


func adjust_selected_rotation(delta_deg: float) -> void:
	if _selected_sticker < 0 or _selected_sticker >= _stickers.size():
		return
	_push_undo()
	var s := _stickers[_selected_sticker]
	s["rot"] = fmod(float(s.get("rot", 0.0)) + deg_to_rad(delta_deg), TAU)
	sticker_selection_changed.emit(_selected_sticker)
	queue_redraw()


func bring_selected_to_front() -> void:
	if _selected_sticker < 0 or _selected_sticker >= _stickers.size() - 1:
		return
	_push_undo()
	var picked := _stickers[_selected_sticker]
	_stickers.remove_at(_selected_sticker)
	_stickers.append(picked)
	_selected_sticker = _stickers.size() - 1
	sticker_selection_changed.emit(_selected_sticker)
	queue_redraw()


func delete_selected_sticker() -> void:
	if _selected_sticker < 0 or _selected_sticker >= _stickers.size():
		return
	_push_undo()
	_stickers.remove_at(_selected_sticker)
	_selected_sticker = -1
	stickers_changed.emit()
	sticker_selection_changed.emit(-1)
	queue_redraw()


func clear_canvas() -> void:
	_push_undo()
	_paint_image.fill(Color.WHITE)
	_paint_texture.update(_paint_image)
	_stickers.clear()
	_selected_sticker = -1
	stickers_changed.emit()
	sticker_selection_changed.emit(-1)
	queue_redraw()


func undo() -> void:
	if _undo_stack.is_empty():
		return
	_redo_stack.append(_capture_snapshot())
	var snap: Dictionary = _undo_stack.pop_back()
	_restore_snapshot(snap)


func redo() -> void:
	if _redo_stack.is_empty():
		return
	_undo_stack.append(_capture_snapshot())
	var snap: Dictionary = _redo_stack.pop_back()
	_restore_snapshot(snap)


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


## Synchronous CPU export compositing the painted layer + all stickers into a final crisp RGBA8 image.
func render_composited_image() -> Image:
	var out := _paint_image.duplicate() as Image
	if out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)

	if _stickers.is_empty():
		return out

	var w := canvas_size.x
	var h := canvas_size.y
	var out_bytes := out.get_data()

	for s in _stickers:
		var item_path := str(s.get("item_path", ""))
		var tex := _get_item_texture(item_path)
		if not tex:
			continue
		var src_img := tex.get_image()
		if not src_img or src_img.is_empty():
			continue
		if src_img.is_compressed():
			src_img.decompress()
		if src_img.get_format() != Image.FORMAT_RGBA8:
			src_img.convert(Image.FORMAT_RGBA8)

		var src_w := src_img.get_width()
		var src_h := src_img.get_height()
		if src_w <= 0 or src_h <= 0:
			continue
		var src_bytes := src_img.get_data()

		var base_sz := _get_sticker_base_size(s)
		var sc := float(s.get("scale", 1.0))
		var half_w := maxf(1.0, base_sz.x * sc * 0.5)
		var half_h := maxf(1.0, base_sz.y * sc * 0.5)
		var cx_pos := float(s.get("x", float(w) * 0.5))
		var cy_pos := float(s.get("y", float(h) * 0.5))
		var rot := float(s.get("rot", 0.0))
		var cos_r := cos(-rot)
		var sin_r := sin(-rot)

		var abs_cos := absf(cos(rot))
		var abs_sin := absf(sin(rot))
		var ext_x := abs_cos * half_w + abs_sin * half_h
		var ext_y := abs_sin * half_w + abs_cos * half_h

		var min_px := maxi(0, floori(cx_pos - ext_x) - 1)
		var max_px := mini(w - 1, ceili(cx_pos + ext_x) + 1)
		var min_py := maxi(0, floori(cy_pos - ext_y) - 1)
		var max_py := mini(h - 1, ceili(cy_pos + ext_y) + 1)

		for py in range(min_py, max_py + 1):
			var dy := float(py) + 0.5 - cy_pos
			var row_offset := py * w
			for px in range(min_px, max_px + 1):
				var dx := float(px) + 0.5 - cx_pos
				var lx := dx * cos_r - dy * sin_r
				var ly := dx * sin_r + dy * cos_r
				var u := (lx / half_w) * 0.5 + 0.5
				var v := (ly / half_h) * 0.5 + 0.5
				if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
					continue

				# Bilinear sample from sticker image
				var sx_f := clampf(u * float(src_w) - 0.5, 0.0, float(src_w - 1))
				var sy_f := clampf(v * float(src_h) - 0.5, 0.0, float(src_h - 1))
				var sx0 := int(floorf(sx_f))
				var sy0 := int(floorf(sy_f))
				var sx1 := mini(sx0 + 1, src_w - 1)
				var sy1 := mini(sy0 + 1, src_h - 1)
				var tx := sx_f - float(sx0)
				var ty := sy_f - float(sy0)

				var i00 := (sy0 * src_w + sx0) * 4
				var i10 := (sy0 * src_w + sx1) * 4
				var i01 := (sy1 * src_w + sx0) * 4
				var i11 := (sy1 * src_w + sx1) * 4

				var w00 := (1.0 - tx) * (1.0 - ty)
				var w10 := tx * (1.0 - ty)
				var w01 := (1.0 - tx) * ty
				var w11 := tx * ty

				var sr := float(src_bytes[i00]) * w00 + float(src_bytes[i10]) * w10 + float(src_bytes[i01]) * w01 + float(src_bytes[i11]) * w11
				var sg := float(src_bytes[i00 + 1]) * w00 + float(src_bytes[i10 + 1]) * w10 + float(src_bytes[i01 + 1]) * w01 + float(src_bytes[i11 + 1]) * w11
				var sb := float(src_bytes[i00 + 2]) * w00 + float(src_bytes[i10 + 2]) * w10 + float(src_bytes[i01 + 2]) * w01 + float(src_bytes[i11 + 2]) * w11
				var sa := (float(src_bytes[i00 + 3]) * w00 + float(src_bytes[i10 + 3]) * w10 + float(src_bytes[i01 + 3]) * w01 + float(src_bytes[i11 + 3]) * w11) / 255.0

				if sa <= 0.004:
					continue

				var oi := (row_offset + px) * 4
				var inv_a := 1.0 - sa
				out_bytes[oi] = clampi(int(roundf(sr * sa + float(out_bytes[oi]) * inv_a)), 0, 255)
				out_bytes[oi + 1] = clampi(int(roundf(sg * sa + float(out_bytes[oi + 1]) * inv_a)), 0, 255)
				out_bytes[oi + 2] = clampi(int(roundf(sb * sa + float(out_bytes[oi + 2]) * inv_a)), 0, 255)
				out_bytes[oi + 3] = 255

	out.set_data(w, h, false, Image.FORMAT_RGBA8, out_bytes)
	return out


func _capture_snapshot() -> Dictionary:
	return {
		"bytes": _paint_image.get_data(),
		"stickers": get_serialized_stickers(),
		"selected": _selected_sticker,
	}


func _push_undo() -> void:
	_undo_stack.append(_capture_snapshot())
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.remove_at(0)
	_redo_stack.clear()
	_emit_history()


func _restore_snapshot(snap: Dictionary) -> void:
	var bytes: PackedByteArray = snap.get("bytes", PackedByteArray())
	if bytes.size() == canvas_size.x * canvas_size.y * 4:
		_paint_image.set_data(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8, bytes)
		_paint_texture.update(_paint_image)
	_stickers.clear()
	for s in snap.get("stickers", []):
		if s is Dictionary:
			_stickers.append(s.duplicate(true))
	var sel := int(snap.get("selected", -1))
	_selected_sticker = sel if (sel >= 0 and sel < _stickers.size()) else -1
	_emit_history()
	stickers_changed.emit()
	sticker_selection_changed.emit(_selected_sticker)
	queue_redraw()


func _emit_history() -> void:
	history_changed.emit(not _undo_stack.is_empty(), not _redo_stack.is_empty())


func _compute_canvas_rect() -> Rect2:
	var pad := 18.0
	var avail_w := maxf(40.0, size.x - pad * 2.0)
	var avail_h := maxf(40.0, size.y - pad * 2.0)
	var aspect := float(canvas_size.x) / maxf(1.0, float(canvas_size.y))
	var target_w := avail_w
	var target_h := target_w / aspect
	if target_h > avail_h:
		target_h = avail_h
		target_w = target_h * aspect
	var pos := (size - Vector2(target_w, target_h)) * 0.5
	return Rect2(pos, Vector2(target_w, target_h))


func _screen_to_canvas(screen_pos: Vector2) -> Vector2:
	if _canvas_rect.size.x <= 0.0 or _canvas_rect.size.y <= 0.0:
		return Vector2.ZERO
	var nx := (screen_pos.x - _canvas_rect.position.x) / _canvas_rect.size.x
	var ny := (screen_pos.y - _canvas_rect.position.y) / _canvas_rect.size.y
	return Vector2(nx * float(canvas_size.x), ny * float(canvas_size.y))


func _canvas_to_screen(canvas_px: Vector2) -> Vector2:
	var nx := canvas_px.x / maxf(1.0, float(canvas_size.x))
	var ny := canvas_px.y / maxf(1.0, float(canvas_size.y))
	return _canvas_rect.position + Vector2(nx * _canvas_rect.size.x, ny * _canvas_rect.size.y)


func _get_item_texture(item_path: String) -> Texture2D:
	if item_path == "":
		return null
	if _tex_cache.has(item_path):
		return _tex_cache[item_path]
	if ResourceLoader.exists(item_path):
		var res := load(item_path)
		if res is ItemData and res.texture:
			_tex_cache[item_path] = res.texture
			return res.texture
	return null


func _get_sticker_base_size(sticker: Dictionary) -> Vector2:
	var base_h := clampf(float(canvas_size.y) * 0.30, 108.0, 170.0)
	var tex := _get_item_texture(str(sticker.get("item_path", "")))
	if tex and tex.get_height() > 0:
		var aspect := float(tex.get_width()) / float(tex.get_height())
		return Vector2(base_h * aspect, base_h)
	return Vector2(base_h, base_h)


func _get_sticker_delete_badge_screen_pos(sticker: Dictionary) -> Vector2:
	var screen_scale := _canvas_rect.size.x / maxf(1.0, float(canvas_size.x))
	var base_sz := _get_sticker_base_size(sticker) * float(sticker.get("scale", 1.0)) * screen_scale
	var rot := float(sticker.get("rot", 0.0))
	var center := _canvas_to_screen(Vector2(float(sticker.get("x", 0.0)), float(sticker.get("y", 0.0))))
	var corner := Vector2(base_sz.x * 0.5, -base_sz.y * 0.5).rotated(rot)
	return center + corner


func _hit_test_sticker(canvas_px: Vector2) -> int:
	for i in range(_stickers.size() - 1, -1, -1):
		var s := _stickers[i]
		var center := Vector2(float(s.get("x", 0.0)), float(s.get("y", 0.0)))
		var rot := float(s.get("rot", 0.0))
		var sc := float(s.get("scale", 1.0))
		var half_sz := _get_sticker_base_size(s) * sc * 0.5
		var local := (canvas_px - center).rotated(-rot)
		if absf(local.x) <= half_sz.x and absf(local.y) <= half_sz.y:
			return i
	return -1


func _draw() -> void:
	_canvas_rect = _compute_canvas_rect()

	# Soft drafting mat border & shadow around white board
	var shadow_rect := _canvas_rect.grow(10.0)
	shadow_rect.position += Vector2(0.0, 5.0)
	draw_rect(shadow_rect, Color(0.0, 0.0, 0.0, 0.45), true)
	draw_rect(_canvas_rect.grow(3.0), Color(0.835, 0.624, 0.278, 0.85), true)
	draw_rect(_canvas_rect, Color.WHITE, true)

	if _paint_texture:
		draw_texture_rect(_paint_texture, _canvas_rect, false)

	var screen_scale := _canvas_rect.size.x / maxf(1.0, float(canvas_size.x))

	# Draw product stickers in layer order
	for i in range(_stickers.size()):
		var s := _stickers[i]
		var tex := _get_item_texture(str(s.get("item_path", "")))
		if not tex:
			continue
		var center := _canvas_to_screen(Vector2(float(s.get("x", 0.0)), float(s.get("y", 0.0))))
		var sc := float(s.get("scale", 1.0)) * screen_scale
		var rot := float(s.get("rot", 0.0))
		var base_sz := _get_sticker_base_size(s)
		draw_set_transform(center, rot, Vector2(sc, sc))
		draw_texture_rect(tex, Rect2(-base_sz * 0.5, base_sz), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Selected sticker gizmo & delete button
	if _selected_sticker >= 0 and _selected_sticker < _stickers.size():
		var sel := _stickers[_selected_sticker]
		var center := _canvas_to_screen(Vector2(float(sel.get("x", 0.0)), float(sel.get("y", 0.0))))
		var sc := float(sel.get("scale", 1.0)) * screen_scale
		var rot := float(sel.get("rot", 0.0))
		var base_sz := _get_sticker_base_size(sel)
		var rect := Rect2(-base_sz * 0.5, base_sz)

		draw_set_transform(center, rot, Vector2(sc, sc))
		draw_rect(rect, Color(0.96, 0.79, 0.48, 0.95), false, 2.0 / maxf(0.25, sc))
		var corner_sz := Vector2(9.0 / maxf(0.25, sc), 9.0 / maxf(0.25, sc))
		for c_pos in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			draw_rect(Rect2(c_pos - corner_sz * 0.5, corner_sz), Color(1.0, 0.92, 0.79, 1.0), true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		var del_pos := _get_sticker_delete_badge_screen_pos(sel)
		draw_circle(del_pos, 11.0, Color(0.80, 0.24, 0.22, 1.0))
		draw_arc(del_pos, 11.0, 0.0, TAU, 20, Color.WHITE, 1.5, true)
		draw_line(del_pos + Vector2(-4.0, -4.0), del_pos + Vector2(4.0, 4.0), Color.WHITE, 2.0)
		draw_line(del_pos + Vector2(4.0, -4.0), del_pos + Vector2(-4.0, 4.0), Color.WHITE, 2.0)

	# Brush/Eraser cursor preview
	if _is_hovering and _canvas_rect.has_point(_hover_screen_pos):
		if active_tool == Tool.BRUSH or active_tool == Tool.ERASER:
			var r_px := maxf(2.0, brush_radius * screen_scale)
			var preview_col := Color.WHITE if active_tool == Tool.ERASER else brush_color
			preview_col.a = 0.28
			draw_circle(_hover_screen_pos, r_px, preview_col)
			draw_arc(_hover_screen_pos, r_px, 0.0, TAU, 32, Color(0.12, 0.10, 0.08, 0.85), 1.6, true)
			draw_arc(_hover_screen_pos, r_px + 1.2, 0.0, TAU, 32, Color(1.0, 0.92, 0.79, 0.75), 1.0, true)


func _update_cursor_shape() -> void:
	match active_tool:
		Tool.SELECT:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		Tool.EYEDROPPER, Tool.BUCKET:
			mouse_default_cursor_shape = Control.CURSOR_CROSS
		_:
			mouse_default_cursor_shape = Control.CURSOR_CROSS


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_is_hovering = true
		_hover_screen_pos = event.position
		if _is_painting and (active_tool == Tool.BRUSH or active_tool == Tool.ERASER):
			var cur_px := _screen_to_canvas(event.position)
			var col := Color.WHITE if active_tool == Tool.ERASER else brush_color
			_paint_stroke(_last_paint_px, cur_px, brush_radius, col)
			_last_paint_px = cur_px
			queue_redraw()
			accept_event()
		elif _is_dragging_sticker and _selected_sticker >= 0 and _selected_sticker < _stickers.size():
			var cur_px := _screen_to_canvas(event.position)
			var target := cur_px + _sticker_drag_offset
			_stickers[_selected_sticker]["x"] = clampf(target.x, 0.0, float(canvas_size.x))
			_stickers[_selected_sticker]["y"] = clampf(target.y, 0.0, float(canvas_size.y))
			queue_redraw()
			accept_event()
		else:
			queue_redraw()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if _selected_sticker >= 0:
				adjust_selected_scale(0.08)
				accept_event()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if _selected_sticker >= 0:
				adjust_selected_scale(-0.08)
				accept_event()
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_handle_left_press(event.position)
			else:
				_handle_left_release()
			accept_event()


func _handle_left_press(screen_pos: Vector2) -> void:
	# Check delete badge on currently selected sticker first (works near canvas edges too)
	if _selected_sticker >= 0 and _selected_sticker < _stickers.size():
		var del_pos := _get_sticker_delete_badge_screen_pos(_stickers[_selected_sticker])
		if screen_pos.distance_to(del_pos) <= 14.0:
			delete_selected_sticker()
			return

	var canvas_px := _screen_to_canvas(screen_pos)

	if active_tool == Tool.SELECT:
		var hit := _hit_test_sticker(canvas_px)
		if hit != _selected_sticker:
			_selected_sticker = hit
			sticker_selection_changed.emit(_selected_sticker)
		if hit >= 0:
			_push_undo()
			var s := _stickers[hit]
			_sticker_drag_offset = Vector2(float(s.get("x", 0.0)), float(s.get("y", 0.0))) - canvas_px
			_is_dragging_sticker = true
		queue_redraw()
		return

	if not _canvas_rect.has_point(screen_pos):
		return

	match active_tool:
		Tool.BRUSH, Tool.ERASER:
			_push_undo()
			_is_painting = true
			_last_paint_px = canvas_px
			var col := Color.WHITE if active_tool == Tool.ERASER else brush_color
			_paint_stroke(canvas_px, canvas_px, brush_radius, col)
			if active_tool == Tool.BRUSH:
				stroke_committed.emit(col)
			queue_redraw()
		Tool.BUCKET:
			var px_i := Vector2i(
				clampi(int(floorf(canvas_px.x)), 0, canvas_size.x - 1),
				clampi(int(floorf(canvas_px.y)), 0, canvas_size.y - 1)
			)
			_push_undo()
			if _flood_fill(px_i, brush_color):
				stroke_committed.emit(brush_color)
				queue_redraw()
			else:
				# Nothing changed — discard redundant undo snapshot
				if not _undo_stack.is_empty():
					_undo_stack.pop_back()
					_emit_history()
		Tool.EYEDROPPER:
			var picked := _pick_composited_color(canvas_px)
			brush_color = picked
			eyedropper_picked.emit(picked)


func _handle_left_release() -> void:
	_is_painting = false
	_is_dragging_sticker = false


func _paint_stroke(from_px: Vector2, to_px: Vector2, radius: float, col: Color) -> void:
	var w := canvas_size.x
	var h := canvas_size.y
	var bytes := _paint_image.get_data()
	var r_byte := clampi(int(roundf(col.r * 255.0)), 0, 255)
	var g_byte := clampi(int(roundf(col.g * 255.0)), 0, 255)
	var b_byte := clampi(int(roundf(col.b * 255.0)), 0, 255)

	var dist := from_px.distance_to(to_px)
	var step := maxf(1.0, radius * 0.30)
	var steps := maxi(1, int(ceilf(dist / step)))
	var r_sq := radius * radius
	var r_ceil := int(ceilf(radius))

	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var pt := from_px.lerp(to_px, t)
		var cx := int(roundf(pt.x))
		var cy := int(roundf(pt.y))
		var x0 := maxi(0, cx - r_ceil)
		var x1 := mini(w - 1, cx + r_ceil)
		var y0 := maxi(0, cy - r_ceil)
		var y1 := mini(h - 1, cy + r_ceil)
		for py in range(y0, y1 + 1):
			var dy := float(py) - pt.y
			var dy_sq := dy * dy
			var row_off := py * w
			for px in range(x0, x1 + 1):
				var dx := float(px) - pt.x
				if dx * dx + dy_sq <= r_sq:
					var bi := (row_off + px) * 4
					bytes[bi] = r_byte
					bytes[bi + 1] = g_byte
					bytes[bi + 2] = b_byte
					bytes[bi + 3] = 255

	_paint_image.set_data(w, h, false, Image.FORMAT_RGBA8, bytes)
	_paint_texture.update(_paint_image)


func _flood_fill(start_px: Vector2i, fill_col: Color) -> bool:
	var w := canvas_size.x
	var h := canvas_size.y
	if start_px.x < 0 or start_px.x >= w or start_px.y < 0 or start_px.y >= h:
		return false

	var bytes := _paint_image.get_data()
	var s_off := (start_px.y * w + start_px.x) * 4
	var tr := bytes[s_off]
	var tg := bytes[s_off + 1]
	var tb := bytes[s_off + 2]

	var fr := clampi(int(roundf(fill_col.r * 255.0)), 0, 255)
	var fg := clampi(int(roundf(fill_col.g * 255.0)), 0, 255)
	var fb := clampi(int(roundf(fill_col.b * 255.0)), 0, 255)

	if absi(tr - fr) <= 2 and absi(tg - fg) <= 2 and absi(tb - fb) <= 2:
		return false

	var visited := PackedByteArray()
	visited.resize(w * h)
	visited.fill(0)

	# Iterative scanline flood fill (visits each pixel once)
	var stack: Array[Vector2i] = [start_px]
	while not stack.is_empty():
		var pt: Vector2i = stack.pop_back()
		var y := pt.y
		var row_pix := y * w
		var x := pt.x

		if visited[row_pix + x] != 0:
			continue
		if not _matches_target(bytes, (row_pix + x) * 4, tr, tg, tb):
			continue

		while x > 0 and visited[row_pix + x - 1] == 0 and _matches_target(bytes, (row_pix + x - 1) * 4, tr, tg, tb):
			x -= 1

		var span_above := false
		var span_below := false
		while x < w and visited[row_pix + x] == 0 and _matches_target(bytes, (row_pix + x) * 4, tr, tg, tb):
			var p_idx := row_pix + x
			visited[p_idx] = 1
			var b_idx := p_idx * 4
			bytes[b_idx] = fr
			bytes[b_idx + 1] = fg
			bytes[b_idx + 2] = fb
			bytes[b_idx + 3] = 255

			if y > 0:
				var up_idx := p_idx - w
				var up_match := visited[up_idx] == 0 and _matches_target(bytes, up_idx * 4, tr, tg, tb)
				if not span_above and up_match:
					stack.append(Vector2i(x, y - 1))
					span_above = true
				elif span_above and not up_match:
					span_above = false

			if y < h - 1:
				var dn_idx := p_idx + w
				var dn_match := visited[dn_idx] == 0 and _matches_target(bytes, dn_idx * 4, tr, tg, tb)
				if not span_below and dn_match:
					stack.append(Vector2i(x, y + 1))
					span_below = true
				elif span_below and not dn_match:
					span_below = false

			x += 1

	_paint_image.set_data(w, h, false, Image.FORMAT_RGBA8, bytes)
	_paint_texture.update(_paint_image)
	return true


func _matches_target(bytes: PackedByteArray, bi: int, tr: int, tg: int, tb: int) -> bool:
	return absi(bytes[bi] - tr) <= FLOOD_TOLERANCE \
		and absi(bytes[bi + 1] - tg) <= FLOOD_TOLERANCE \
		and absi(bytes[bi + 2] - tb) <= FLOOD_TOLERANCE


func _pick_composited_color(canvas_px: Vector2) -> Color:
	# Sample top-most sticker pixel if opaque, otherwise sample painted raster layer
	for i in range(_stickers.size() - 1, -1, -1):
		var s := _stickers[i]
		var tex := _get_item_texture(str(s.get("item_path", "")))
		if not tex:
			continue
		var center := Vector2(float(s.get("x", 0.0)), float(s.get("y", 0.0)))
		var rot := float(s.get("rot", 0.0))
		var sc := float(s.get("scale", 1.0))
		var half_sz := _get_sticker_base_size(s) * sc * 0.5
		var local := (canvas_px - center).rotated(-rot)
		var u := (local.x / maxf(1.0, half_sz.x)) * 0.5 + 0.5
		var v := (local.y / maxf(1.0, half_sz.y)) * 0.5 + 0.5
		if u >= 0.0 and u <= 1.0 and v >= 0.0 and v <= 1.0:
			var img := tex.get_image()
			if img and not img.is_empty():
				if img.is_compressed():
					img.decompress()
				var sx := clampi(int(u * float(img.get_width())), 0, img.get_width() - 1)
				var sy := clampi(int(v * float(img.get_height())), 0, img.get_height() - 1)
				var c := img.get_pixel(sx, sy)
				if c.a > 0.35:
					return Color(c.r, c.g, c.b, 1.0)

	var px := clampi(int(floorf(canvas_px.x)), 0, canvas_size.x - 1)
	var py := clampi(int(floorf(canvas_px.y)), 0, canvas_size.y - 1)
	var base := _paint_image.get_pixel(px, py)
	return Color(base.r, base.g, base.b, 1.0)
