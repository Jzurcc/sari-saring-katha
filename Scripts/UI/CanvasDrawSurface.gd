class_name CanvasDrawSurface
extends Control

## Interactive raster paint + product-sticker + text canvas surface for Roof Signage & Promo Poster.
## Supports smooth interpolated brush/eraser strokes, iterative scanline flood-fill bucket,
## composited eyedropper picking, movable/scalable/rotatable stickers & text layers
## (with Figma-style draggable corner scaling & corner rotation), 25-step undo/redo,
## and crisp composited PNG export.

signal stroke_committed(color_used: Color)
signal eyedropper_picked(color: Color)
signal stickers_changed()
signal sticker_selection_changed(selected_index: int)
signal text_layer_placed(selected_index: int)
signal history_changed(can_undo: bool, can_redo: bool)
signal zoom_changed(new_zoom: float)

enum Tool { BRUSH, ERASER, BUCKET, EYEDROPPER, TEXT, SELECT }
enum DragMode { NONE, MOVE, SCALE, ROTATE }

const MAX_UNDO := 25
const FLOOD_TOLERANCE := 22
const MIN_ZOOM := 0.5
const MAX_ZOOM := 4.0
const CUSTOM_UPLOADS_DIR := "user://custom_uploads"

var canvas_size: Vector2i = Vector2i(1024, 368)
var active_tool: Tool = Tool.BRUSH:
	set(v):
		active_tool = v
		if active_tool != Tool.SELECT and active_tool != Tool.TEXT and _selected_sticker != -1:
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
var _stickers: Array[Dictionary] = [] # Unified layers: kind="sticker" or kind="text"
var _tex_cache: Dictionary = {} # item_path -> Texture2D
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _bold_font: FontVariation = null

var _selected_sticker: int = -1
var _is_painting: bool = false
var _last_paint_px: Vector2 = Vector2.ZERO
var _drag_mode: DragMode = DragMode.NONE
var _sticker_drag_offset: Vector2 = Vector2.ZERO
var _drag_start_dist: float = 1.0
var _drag_start_scale: float = 1.0
var _drag_start_angle: float = 0.0
var _drag_start_rot: float = 0.0
var _hover_screen_pos: Vector2 = Vector2.ZERO
var _is_hovering: bool = false
var _canvas_rect: Rect2 = Rect2()
var _zoom: float = 1.0
var _pan_offset: Vector2 = Vector2.ZERO
var _is_panning: bool = false
var _pan_last_screen: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_INDER
	_bold_font.variation_embolden = 0.70
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
		if not (entry is Dictionary):
			continue
		var kind := str(entry.get("kind", "sticker"))
		var pos_x := clampf(float(entry.get("x", float(canvas_size.x) * 0.5)), 0.0, float(canvas_size.x))
		var pos_y := clampf(float(entry.get("y", float(canvas_size.y) * 0.5)), 0.0, float(canvas_size.y))
		if kind == "text":
			var txt := str(entry.get("text", "")).strip_edges()
			if txt == "":
				continue
			_stickers.append({
				"kind": "text",
				"text": txt,
				"color": str(entry.get("color", "#231E1A")),
				"font_size": clampi(int(entry.get("font_size", 56)), 18, 160),
				"bold": bool(entry.get("bold", true)),
				"visible": bool(entry.get("visible", true)),
				"x": pos_x,
				"y": pos_y,
				"scale": clampf(float(entry.get("scale", 1.0)), 0.30, 3.0),
				"rot": float(entry.get("rot", 0.0)),
			})
		elif kind == "image":
			var img_path := str(entry.get("image_path", ""))
			if img_path == "" or not FileAccess.file_exists(img_path):
				continue
			_stickers.append({
				"kind": "image",
				"image_path": img_path,
				"label": str(entry.get("label", img_path.get_file())),
				"visible": bool(entry.get("visible", true)),
				"x": pos_x,
				"y": pos_y,
				"scale": clampf(float(entry.get("scale", 1.0)), 0.15, 3.5),
				"rot": float(entry.get("rot", 0.0)),
			})
			_get_uploaded_texture(img_path)
		else:
			var item_path := str(entry.get("item_path", ""))
			if item_path == "":
				continue
			_stickers.append({
				"kind": "sticker",
				"item_path": item_path,
				"item_name": str(entry.get("item_name", "")),
				"category": str(entry.get("category", "")),
				"visible": bool(entry.get("visible", true)),
				"x": pos_x,
				"y": pos_y,
				"scale": clampf(float(entry.get("scale", 1.0)), 0.30, 2.6),
				"rot": float(entry.get("rot", 0.0)),
			})
			_get_item_texture(item_path)

	_selected_sticker = -1
	_drag_mode = DragMode.NONE
	_zoom = 1.0
	_pan_offset = Vector2.ZERO
	_is_panning = false
	_undo_stack.clear()
	_redo_stack.clear()
	_emit_history()
	zoom_changed.emit(_zoom)
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
		var kind := str(s.get("kind", "sticker"))
		if kind == "text":
			out.append({
				"kind": "text",
				"text": str(s.get("text", "")),
				"color": str(s.get("color", "#231E1A")),
				"font_size": int(s.get("font_size", 56)),
				"bold": bool(s.get("bold", true)),
				"visible": bool(s.get("visible", true)),
				"x": float(s.get("x", 0.0)),
				"y": float(s.get("y", 0.0)),
				"scale": float(s.get("scale", 1.0)),
				"rot": float(s.get("rot", 0.0)),
			})
		elif kind == "image":
			out.append({
				"kind": "image",
				"image_path": str(s.get("image_path", "")),
				"label": str(s.get("label", "Image")),
				"visible": bool(s.get("visible", true)),
				"x": float(s.get("x", 0.0)),
				"y": float(s.get("y", 0.0)),
				"scale": float(s.get("scale", 1.0)),
				"rot": float(s.get("rot", 0.0)),
			})
		else:
			out.append({
				"kind": "sticker",
				"item_path": str(s.get("item_path", "")),
				"item_name": str(s.get("item_name", "")),
				"category": str(s.get("category", "")),
				"visible": bool(s.get("visible", true)),
				"x": float(s.get("x", 0.0)),
				"y": float(s.get("y", 0.0)),
				"scale": float(s.get("scale", 1.0)),
				"rot": float(s.get("rot", 0.0)),
			})
	return out


func get_layers() -> Array[Dictionary]:
	return _stickers


func get_selected_index() -> int:
	return _selected_sticker


func get_selected_layer() -> Dictionary:
	if _selected_sticker >= 0 and _selected_sticker < _stickers.size():
		return _stickers[_selected_sticker]
	return {}


func has_text_layers() -> bool:
	for s in _stickers:
		if str(s.get("kind", "sticker")) == "text" and bool(s.get("visible", true)):
			return true
	return false


func get_sticker_category_counts() -> Dictionary:
	var counts: Dictionary = {}
	for s in _stickers:
		if str(s.get("kind", "sticker")) != "sticker" or not bool(s.get("visible", true)):
			continue
		var cat := str(s.get("category", "")).to_lower()
		if cat == "":
			continue
		counts[cat] = int(counts.get(cat, 0)) + 1
	return counts


func get_zoom() -> float:
	return _zoom


func set_zoom(new_zoom: float, anchor_screen: Vector2 = Vector2(-1.0, -1.0)) -> void:
	var clamped := clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(clamped, _zoom):
		return
	var anchor := anchor_screen
	if anchor.x < 0.0 or anchor.y < 0.0:
		anchor = size * 0.5
	var before_canvas := _screen_to_canvas(anchor)
	_zoom = clamped
	if _zoom <= 1.001:
		_pan_offset = Vector2.ZERO
	else:
		_canvas_rect = _compute_canvas_rect()
		var after_screen := _canvas_to_screen(before_canvas)
		_pan_offset += (anchor - after_screen)
		_clamp_pan_offset()
	zoom_changed.emit(_zoom)
	queue_redraw()


func zoom_by(factor: float, anchor_screen: Vector2 = Vector2(-1.0, -1.0)) -> void:
	set_zoom(_zoom * factor, anchor_screen)


func reset_view() -> void:
	_zoom = 1.0
	_pan_offset = Vector2.ZERO
	zoom_changed.emit(_zoom)
	queue_redraw()


func _clamp_pan_offset() -> void:
	var max_x := maxf(size.x * 0.75 * _zoom, 240.0)
	var max_y := maxf(size.y * 0.75 * _zoom, 240.0)
	_pan_offset.x = clampf(_pan_offset.x, -max_x, max_x)
	_pan_offset.y = clampf(_pan_offset.y, -max_y, max_y)


func select_layer(index: int) -> void:
	if index < 0 or index >= _stickers.size():
		_selected_sticker = -1
		sticker_selection_changed.emit(-1)
		queue_redraw()
		return
	if not bool(_stickers[index].get("visible", true)):
		_stickers[index]["visible"] = true
		stickers_changed.emit()
	active_tool = Tool.SELECT
	_selected_sticker = index
	sticker_selection_changed.emit(_selected_sticker)
	queue_redraw()


func toggle_layer_visible(index: int) -> void:
	if index < 0 or index >= _stickers.size():
		return
	_push_undo()
	var now_vis := not bool(_stickers[index].get("visible", true))
	_stickers[index]["visible"] = now_vis
	if not now_vis and _selected_sticker == index:
		_selected_sticker = -1
		sticker_selection_changed.emit(-1)
	stickers_changed.emit()
	queue_redraw()


func move_layer(index: int, delta: int) -> void:
	var target := index + delta
	if index < 0 or index >= _stickers.size() or target < 0 or target >= _stickers.size() or target == index:
		return
	_push_undo()
	var layer_dict: Dictionary = _stickers[index]
	_stickers.remove_at(index)
	_stickers.insert(target, layer_dict)
	if _selected_sticker == index:
		_selected_sticker = target
	elif _selected_sticker == target:
		_selected_sticker = index
	stickers_changed.emit()
	sticker_selection_changed.emit(_selected_sticker)
	queue_redraw()


func delete_layer(index: int) -> void:
	if index < 0 or index >= _stickers.size():
		return
	_push_undo()
	_stickers.remove_at(index)
	if _selected_sticker == index:
		_selected_sticker = -1
	elif _selected_sticker > index:
		_selected_sticker -= 1
	stickers_changed.emit()
	sticker_selection_changed.emit(_selected_sticker)
	queue_redraw()


func add_uploaded_image(source_file_path: String) -> bool:
	if source_file_path == "" or not FileAccess.file_exists(source_file_path):
		return false
	var img := Image.load_from_file(source_file_path)
	if img == null or img.is_empty():
		return false
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var max_dim := maxi(img.get_width(), img.get_height())
	if max_dim > 1024:
		var ratio := 1024.0 / float(max_dim)
		img.resize(maxi(1, int(roundf(img.get_width() * ratio))), maxi(1, int(roundf(img.get_height() * ratio))), Image.INTERPOLATE_LANCZOS)

	var abs_dir := ProjectSettings.globalize_path(CUSTOM_UPLOADS_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var base_name := source_file_path.get_file().get_basename()
	var clean_base := ""
	for i in range(base_name.length()):
		var ch := base_name.substr(i, 1)
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
			clean_base += ch
	if clean_base == "":
		clean_base = "upload"
	var saved_path := "%s/img_%d_%s.png" % [CUSTOM_UPLOADS_DIR, Time.get_ticks_msec(), clean_base.substr(0, 20)]
	var err := img.save_png(saved_path)
	if err != OK:
		return false

	_tex_cache[saved_path] = ImageTexture.create_from_image(img)
	_push_undo()
	_stickers.append({
		"kind": "image",
		"image_path": saved_path,
		"label": source_file_path.get_file(),
		"visible": true,
		"x": float(canvas_size.x) * 0.5,
		"y": float(canvas_size.y) * 0.5,
		"scale": 1.0,
		"rot": 0.0,
	})
	active_tool = Tool.SELECT
	_selected_sticker = _stickers.size() - 1
	stickers_changed.emit()
	sticker_selection_changed.emit(_selected_sticker)
	queue_redraw()
	return true


func add_sticker(item: ItemData) -> void:
	if item == null or item.resource_path == "":
		return
	_push_undo()
	var jitter := Vector2(randf_range(-28.0, 28.0), randf_range(-22.0, 22.0))
	var center := Vector2(float(canvas_size.x) * 0.5, float(canvas_size.y) * 0.5) + jitter
	center.x = clampf(center.x, 48.0, float(canvas_size.x) - 48.0)
	center.y = clampf(center.y, 48.0, float(canvas_size.y) - 48.0)
	_stickers.append({
		"kind": "sticker",
		"item_path": item.resource_path,
		"item_name": item.item_name,
		"category": item.category.to_lower(),
		"visible": true,
		"x": center.x,
		"y": center.y,
		"scale": 1.0,
		"rot": 0.0,
	})
	_get_item_texture(item.resource_path)
	active_tool = Tool.SELECT
	_selected_sticker = _stickers.size() - 1
	stickers_changed.emit()
	sticker_selection_changed.emit(_selected_sticker)
	queue_redraw()


func add_text_layer(initial_text: String = "Sari-Sari", pos_px: Vector2 = Vector2(-1, -1)) -> void:
	_push_undo()
	var center := pos_px
	if center.x < 0.0 or center.y < 0.0:
		center = Vector2(float(canvas_size.x) * 0.5, float(canvas_size.y) * 0.5)
	center.x = clampf(center.x, 40.0, float(canvas_size.x) - 40.0)
	center.y = clampf(center.y, 40.0, float(canvas_size.y) - 40.0)
	_stickers.append({
		"kind": "text",
		"text": initial_text if initial_text.strip_edges() != "" else "Text",
		"color": "#" + brush_color.to_html(false).to_upper(),
		"font_size": 58,
		"bold": true,
		"visible": true,
		"x": center.x,
		"y": center.y,
		"scale": 1.0,
		"rot": 0.0,
	})
	active_tool = Tool.SELECT
	_selected_sticker = _stickers.size() - 1
	stickers_changed.emit()
	sticker_selection_changed.emit(_selected_sticker)
	text_layer_placed.emit(_selected_sticker)
	queue_redraw()


func update_selected_text(new_text: String) -> void:
	if _selected_sticker < 0 or _selected_sticker >= _stickers.size():
		return
	var s := _stickers[_selected_sticker]
	if str(s.get("kind", "sticker")) != "text":
		return
	s["text"] = new_text
	queue_redraw()


func update_selected_text_color(col: Color) -> void:
	if _selected_sticker < 0 or _selected_sticker >= _stickers.size():
		return
	var s := _stickers[_selected_sticker]
	if str(s.get("kind", "sticker")) != "text":
		return
	s["color"] = "#" + col.to_html(false).to_upper()
	queue_redraw()


func toggle_selected_text_bold() -> void:
	if _selected_sticker < 0 or _selected_sticker >= _stickers.size():
		return
	var s := _stickers[_selected_sticker]
	if str(s.get("kind", "sticker")) != "text":
		return
	_push_undo()
	s["bold"] = not bool(s.get("bold", true))
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


func delete_selected_sticker() -> void:
	if _selected_sticker < 0 or _selected_sticker >= _stickers.size():
		return
	_push_undo()
	_stickers.remove_at(_selected_sticker)
	_selected_sticker = -1
	stickers_changed.emit()
	sticker_selection_changed.emit(-1)
	queue_redraw()


func adjust_selected_scale(delta: float) -> void:
	if _selected_sticker < 0 or _selected_sticker >= _stickers.size():
		return
	_push_undo()
	var s := _stickers[_selected_sticker]
	s["scale"] = clampf(float(s.get("scale", 1.0)) + delta, 0.30, 3.0)
	queue_redraw()


func adjust_selected_rotation(delta_rad: float) -> void:
	if _selected_sticker < 0 or _selected_sticker >= _stickers.size():
		return
	_push_undo()
	var s := _stickers[_selected_sticker]
	s["rot"] = wrapf(float(s.get("rot", 0.0)) + delta_rad, -PI, PI)
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


func render_composited_image() -> Image:
	var out := _paint_image.duplicate() as Image
	if out.get_format() != Image.FORMAT_RGBA8:
		out.convert(Image.FORMAT_RGBA8)
	var w := out.get_width()
	var h := out.get_height()
	var out_bytes := out.get_data()

	for s in _stickers:
		if not bool(s.get("visible", true)):
			continue
		var kind := str(s.get("kind", "sticker"))
		if kind != "sticker" and kind != "image":
			continue
		var tex := _get_layer_texture(s)
		if tex == null:
			continue
		var src_img := tex.get_image()
		if src_img == null or src_img.is_empty():
			continue
		if src_img.is_compressed():
			src_img.decompress()
		if src_img.get_format() != Image.FORMAT_RGBA8:
			src_img.convert(Image.FORMAT_RGBA8)

		var src_w := src_img.get_width()
		var src_h := src_img.get_height()
		var src_bytes := src_img.get_data()

		var base_sz := _get_layer_base_size(s)
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


## Full GPU-accelerated export that bakes paint + stickers + crisp vector text layers!
## Falls back seamlessly to CPU render_composited_image() in headless mode or when no text exists.
func render_composited_image_async() -> Image:
	if not has_text_layers() or DisplayServer.get_name() == "headless":
		return render_composited_image()

	var svp := SubViewport.new()
	svp.size = canvas_size
	svp.transparent_bg = false
	svp.render_target_update_mode = SubViewport.UPDATE_ONCE
	svp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE

	var drawer := _ExportCanvasNode.new()
	drawer.size = Vector2(canvas_size)
	drawer.paint_tex = _paint_texture
	drawer.layers = _stickers.duplicate(true)
	drawer.tex_cache = _tex_cache
	drawer.bold_font = _bold_font
	drawer.surface_ref = self
	svp.add_child(drawer)
	add_child(svp)
	drawer.queue_redraw()

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var vp_tex := svp.get_texture()
	var img: Image = vp_tex.get_image() if vp_tex else null
	svp.queue_free()
	if img != null and not img.is_empty():
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		return img
	return render_composited_image()


class _ExportCanvasNode extends Control:
	var paint_tex: Texture2D
	var layers: Array[Dictionary] = []
	var tex_cache: Dictionary = {}
	var bold_font: Font
	var surface_ref: CanvasDrawSurface

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, true)
		if paint_tex:
			draw_texture_rect(paint_tex, Rect2(Vector2.ZERO, size), false)
		for s in layers:
			if not bool(s.get("visible", true)):
				continue
			var center := Vector2(float(s.get("x", 0.0)), float(s.get("y", 0.0)))
			var sc := float(s.get("scale", 1.0))
			var rot := float(s.get("rot", 0.0))
			if str(s.get("kind", "sticker")) == "text":
				surface_ref._draw_text_layer_on(self, s, center, sc, rot)
			else:
				var tex: Texture2D = surface_ref._get_layer_texture(s)
				if tex:
					var base_sz := surface_ref._get_layer_base_size(s)
					draw_set_transform(center, rot, Vector2(sc, sc))
					draw_texture_rect(tex, Rect2(-base_sz * 0.5, base_sz), false)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
	var pad := 24.0
	var avail_w := maxf(40.0, size.x - pad * 2.0)
	var avail_h := maxf(40.0, size.y - pad * 2.0)
	var aspect := float(canvas_size.x) / maxf(1.0, float(canvas_size.y))
	var target_w := avail_w
	var target_h := target_w / aspect
	if target_h > avail_h:
		target_h = avail_h
		target_w = target_h * aspect
	var zoomed_sz := Vector2(target_w, target_h) * _zoom
	var pos := (size - zoomed_sz) * 0.5 + _pan_offset
	return Rect2(pos, zoomed_sz)


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


func _get_uploaded_texture(image_path: String) -> Texture2D:
	if image_path == "":
		return null
	if _tex_cache.has(image_path):
		return _tex_cache[image_path]
	if FileAccess.file_exists(image_path):
		var img := Image.load_from_file(image_path)
		if img != null and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			_tex_cache[image_path] = tex
			return tex
	return null


func _get_layer_texture(s: Dictionary) -> Texture2D:
	if str(s.get("kind", "sticker")) == "image":
		return _get_uploaded_texture(str(s.get("image_path", "")))
	return _get_item_texture(str(s.get("item_path", "")))


func _get_layer_font(s: Dictionary) -> Font:
	return _bold_font if (bool(s.get("bold", true)) and _bold_font) else UIStyle.FONT_INDER


func _get_layer_base_size(s: Dictionary) -> Vector2:
	var kind := str(s.get("kind", "sticker"))
	if kind == "text":
		var f := _get_layer_font(s)
		var fsz := clampi(int(s.get("font_size", 58)), 18, 160)
		var txt := str(s.get("text", "Text"))
		if txt == "":
			txt = " "
		var sz := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz)
		return Vector2(maxf(sz.x + 22.0, 48.0), maxf(sz.y + 12.0, float(fsz)))
	if kind == "image":
		var tex := _get_uploaded_texture(str(s.get("image_path", "")))
		var max_w := float(canvas_size.x) * 0.58
		var max_h := float(canvas_size.y) * 0.68
		if tex and tex.get_width() > 0 and tex.get_height() > 0:
			var aspect := float(tex.get_width()) / float(tex.get_height())
			var w := max_w
			var h := w / aspect
			if h > max_h:
				h = max_h
				w = h * aspect
			return Vector2(maxf(48.0, w), maxf(48.0, h))
		return Vector2(180.0, 180.0)
	var base_h := clampf(float(canvas_size.y) * 0.30, 108.0, 170.0)
	var tex := _get_item_texture(str(s.get("item_path", "")))
	if tex and tex.get_height() > 0:
		var aspect := float(tex.get_width()) / float(tex.get_height())
		return Vector2(base_h * aspect, base_h)
	return Vector2(base_h, base_h)


func _get_layer_corners_screen(s: Dictionary) -> Array[Vector2]:
	var screen_scale := _canvas_rect.size.x / maxf(1.0, float(canvas_size.x))
	var half := _get_layer_base_size(s) * float(s.get("scale", 1.0)) * screen_scale * 0.5
	var rot := float(s.get("rot", 0.0))
	var center := _canvas_to_screen(Vector2(float(s.get("x", 0.0)), float(s.get("y", 0.0))))
	return [
		center + Vector2(-half.x, -half.y).rotated(rot), # 0: TL
		center + Vector2(half.x, -half.y).rotated(rot),  # 1: TR (delete badge)
		center + Vector2(half.x, half.y).rotated(rot),   # 2: BR (scale + rotate outside)
		center + Vector2(-half.x, half.y).rotated(rot),  # 3: BL
	]


func _get_rotate_knob_screen_pos(s: Dictionary) -> Vector2:
	var corners := _get_layer_corners_screen(s)
	var center := _canvas_to_screen(Vector2(float(s.get("x", 0.0)), float(s.get("y", 0.0))))
	var br: Vector2 = corners[2]
	var out_dir := (br - center).normalized()
	return br + out_dir * 22.0


func _hit_test_sticker(canvas_px: Vector2) -> int:
	for i in range(_stickers.size() - 1, -1, -1):
		var s := _stickers[i]
		if not bool(s.get("visible", true)):
			continue
		var center := Vector2(float(s.get("x", 0.0)), float(s.get("y", 0.0)))
		var rot := float(s.get("rot", 0.0))
		var sc := float(s.get("scale", 1.0))
		var half_sz := _get_layer_base_size(s) * sc * 0.5
		var local := (canvas_px - center).rotated(-rot)
		if absf(local.x) <= half_sz.x and absf(local.y) <= half_sz.y:
			return i
	return -1


func _draw_text_layer_on(target: CanvasItem, s: Dictionary, center: Vector2, sc: float, rot: float) -> void:
	var f := _get_layer_font(s)
	var fsz := clampi(int(s.get("font_size", 58)), 18, 160)
	var txt := str(s.get("text", ""))
	if txt == "":
		return
	var col := Color.html(str(s.get("color", "#231E1A")))
	var sz := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz)
	var ascent := f.get_ascent(fsz)
	var descent := f.get_descent(fsz)
	var baseline_y := (ascent - descent) * 0.5
	target.draw_set_transform(center, rot, Vector2(sc, sc))
	target.draw_string(f, Vector2(-sz.x * 0.5, baseline_y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, col)
	target.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	_canvas_rect = _compute_canvas_rect()

	# Soft drafting mat shadow + gold trim + crisp white canvas board
	var shadow_rect := _canvas_rect.grow(10.0)
	shadow_rect.position += Vector2(0.0, 5.0)
	draw_rect(shadow_rect, Color(0.0, 0.0, 0.0, 0.48), true)
	draw_rect(_canvas_rect.grow(2.5), Color(0.835, 0.624, 0.278, 0.85), true)
	draw_rect(_canvas_rect, Color.WHITE, true)

	if _paint_texture:
		draw_texture_rect(_paint_texture, _canvas_rect, false)

	var screen_scale := _canvas_rect.size.x / maxf(1.0, float(canvas_size.x))

	# Draw product stickers, uploaded images & text layers in order
	for i in range(_stickers.size()):
		var s := _stickers[i]
		if not bool(s.get("visible", true)):
			continue
		var center := _canvas_to_screen(Vector2(float(s.get("x", 0.0)), float(s.get("y", 0.0))))
		var sc := float(s.get("scale", 1.0)) * screen_scale
		var rot := float(s.get("rot", 0.0))
		if str(s.get("kind", "sticker")) == "text":
			_draw_text_layer_on(self, s, center, sc, rot)
		else:
			var tex := _get_layer_texture(s)
			if not tex:
				continue
			var base_sz := _get_layer_base_size(s)
			draw_set_transform(center, rot, Vector2(sc, sc))
			draw_texture_rect(tex, Rect2(-base_sz * 0.5, base_sz), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Selected layer Figma-style gizmo: bounding box, corner scale handles, corner rotate knob (↻), & delete badge (×)
	if _selected_sticker >= 0 and _selected_sticker < _stickers.size():
		var sel := _stickers[_selected_sticker]
		var center := _canvas_to_screen(Vector2(float(sel.get("x", 0.0)), float(sel.get("y", 0.0))))
		var sc := float(sel.get("scale", 1.0)) * screen_scale
		var rot := float(sel.get("rot", 0.0))
		var base_sz := _get_layer_base_size(sel)
		var rect := Rect2(-base_sz * 0.5, base_sz)

		var box_col := Color(1.0, 0.88, 0.48, 0.98) if _drag_mode == DragMode.ROTATE else Color(0.96, 0.79, 0.48, 0.95)
		draw_set_transform(center, rot, Vector2(sc, sc))
		draw_rect(rect, box_col, false, 2.0 / maxf(0.25, sc))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		var corners := _get_layer_corners_screen(sel)
		# Corner scale squares on TL (0), BR (2), BL (3)
		for ci in [0, 2, 3]:
			var cp: Vector2 = corners[ci]
			draw_rect(Rect2(cp - Vector2(5.5, 5.5), Vector2(11.0, 11.0)), Color(1.0, 0.95, 0.84, 1.0), true)
			draw_rect(Rect2(cp - Vector2(5.5, 5.5), Vector2(11.0, 11.0)), Color(0.22, 0.16, 0.08, 0.95), false, 1.5)

		# Draggable corner rotation knob (↻) outside BR corner
		var rot_pos := _get_rotate_knob_screen_pos(sel)
		draw_line(corners[2], rot_pos, Color(0.96, 0.79, 0.48, 0.82), 1.6, true)
		var knob_bg := Color(1.0, 0.86, 0.44, 1.0) if _drag_mode == DragMode.ROTATE else Color(0.12, 0.10, 0.08, 0.96)
		var knob_fg := Color(0.10, 0.08, 0.06, 1.0) if _drag_mode == DragMode.ROTATE else Color(1.0, 0.88, 0.54, 1.0)
		draw_circle(rot_pos, 12.0, knob_bg)
		draw_arc(rot_pos, 12.0, 0.0, TAU, 24, Color(1.0, 0.88, 0.54, 0.96), 1.8, true)
		draw_string(_bold_font, rot_pos + Vector2(-6.5, 5.5), "↻", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, knob_fg)

		# Live angle badge while rotating
		if _drag_mode == DragMode.ROTATE:
			var deg := int(roundf(rad_to_deg(rot)))
			var badge_pos := rot_pos + Vector2(18.0, -8.0)
			draw_rect(Rect2(badge_pos, Vector2(46.0, 22.0)), Color(0.08, 0.07, 0.06, 0.92), true)
			draw_rect(Rect2(badge_pos, Vector2(46.0, 22.0)), Color(1.0, 0.86, 0.48, 0.90), false, 1.2)
			draw_string(_bold_font, badge_pos + Vector2(6.0, 16.0), "%d°" % deg, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.94, 0.80, 1.0))

		# Delete badge (×) on TR corner (1)
		var del_pos: Vector2 = corners[1]
		draw_circle(del_pos, 11.0, Color(0.80, 0.24, 0.22, 1.0))
		draw_arc(del_pos, 11.0, 0.0, TAU, 20, Color.WHITE, 1.5, true)
		draw_line(del_pos + Vector2(-4.0, -4.0), del_pos + Vector2(4.0, 4.0), Color.WHITE, 2.0)
		draw_line(del_pos + Vector2(4.0, -4.0), del_pos + Vector2(-4.0, 4.0), Color.WHITE, 2.0)

	# Brush/Eraser cursor preview
	if _is_hovering and _canvas_rect.has_point(_hover_screen_pos):
		if active_tool == Tool.BRUSH or active_tool == Tool.ERASER:
			var screen_r := maxf(2.0, brush_radius * screen_scale)
			var outline_col := Color(0.25, 0.25, 0.25, 0.85) if active_tool == Tool.ERASER else Color(0.12, 0.12, 0.12, 0.85)
			draw_arc(_hover_screen_pos, screen_r, 0.0, TAU, 28, outline_col, 1.6, true)
			draw_arc(_hover_screen_pos, maxf(1.0, screen_r - 1.2), 0.0, TAU, 28, Color(1.0, 1.0, 1.0, 0.75), 1.0, true)


func _update_cursor_shape() -> void:
	match active_tool:
		Tool.SELECT:
			mouse_default_cursor_shape = Control.CURSOR_MOVE
		Tool.TEXT:
			mouse_default_cursor_shape = Control.CURSOR_IBEAM
		Tool.EYEDROPPER, Tool.BUCKET:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_:
			mouse_default_cursor_shape = Control.CURSOR_CROSS


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_screen_pos = event.position
		_is_hovering = true
		if _is_panning:
			_pan_offset += event.position - _pan_last_screen
			_pan_last_screen = event.position
			_clamp_pan_offset()
			queue_redraw()
			return
		var canvas_px := _screen_to_canvas(event.position)
		if _is_painting and (active_tool == Tool.BRUSH or active_tool == Tool.ERASER):
			var col := Color.WHITE if active_tool == Tool.ERASER else brush_color
			_paint_stroke(_last_paint_px, canvas_px, brush_radius, col)
			_last_paint_px = canvas_px
		elif _drag_mode != DragMode.NONE and _selected_sticker >= 0 and _selected_sticker < _stickers.size():
			var s := _stickers[_selected_sticker]
			var center := Vector2(float(s.get("x", 0.0)), float(s.get("y", 0.0)))
			match _drag_mode:
				DragMode.MOVE:
					var next_pos := canvas_px + _sticker_drag_offset
					s["x"] = clampf(next_pos.x, 0.0, float(canvas_size.x))
					s["y"] = clampf(next_pos.y, 0.0, float(canvas_size.y))
				DragMode.SCALE:
					var cur_dist := maxf(8.0, canvas_px.distance_to(center))
					s["scale"] = clampf(_drag_start_scale * (cur_dist / maxf(8.0, _drag_start_dist)), 0.15, 3.5)
				DragMode.ROTATE:
					var cur_ang := atan2(canvas_px.y - center.y, canvas_px.x - center.x)
					var new_rot := wrapf(_drag_start_rot + (cur_ang - _drag_start_angle), -PI, PI)
					if Input.is_key_pressed(KEY_SHIFT):
						var snap := deg_to_rad(15.0)
						new_rot = roundf(new_rot / snap) * snap
					s["rot"] = new_rot
		queue_redraw()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if event.alt_pressed and _selected_sticker >= 0:
				adjust_selected_scale(0.08)
			else:
				zoom_by(1.15, event.position)
			accept_event()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if event.alt_pressed and _selected_sticker >= 0:
				adjust_selected_scale(-0.08)
			else:
				zoom_by(1.0 / 1.15, event.position)
			accept_event()
			return

		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed
			_pan_last_screen = event.position
			accept_event()
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if Input.is_key_pressed(KEY_SPACE):
					_is_panning = true
					_pan_last_screen = event.position
				else:
					_handle_left_press(event.position)
			else:
				_is_panning = false
				_handle_left_release()
			accept_event()


func _handle_left_press(screen_pos: Vector2) -> void:
	var canvas_px := _screen_to_canvas(screen_pos)

	# 1. Check active selection gizmo handles first (Delete, Rotate knob, Corner Scale, or Corner-Outside Rotate)
	if _selected_sticker >= 0 and _selected_sticker < _stickers.size():
		var sel := _stickers[_selected_sticker]
		var corners := _get_layer_corners_screen(sel)
		var del_pos: Vector2 = corners[1]
		if screen_pos.distance_to(del_pos) <= 14.0:
			delete_selected_sticker()
			return

		var center := Vector2(float(sel.get("x", 0.0)), float(sel.get("y", 0.0)))
		var rot_knob := _get_rotate_knob_screen_pos(sel)
		if screen_pos.distance_to(rot_knob) <= 15.0:
			_push_undo()
			_drag_mode = DragMode.ROTATE
			_drag_start_angle = atan2(canvas_px.y - center.y, canvas_px.x - center.x)
			_drag_start_rot = float(sel.get("rot", 0.0))
			return

		for ci in [0, 2, 3]:
			var d := screen_pos.distance_to(corners[ci])
			if d <= 12.0:
				_push_undo()
				_drag_mode = DragMode.SCALE
				_drag_start_dist = maxf(8.0, canvas_px.distance_to(center))
				_drag_start_scale = float(sel.get("scale", 1.0))
				return
			elif d <= 28.0 and _hit_test_sticker(canvas_px) != _selected_sticker:
				# Figma-style drag just outside any corner to rotate!
				_push_undo()
				_drag_mode = DragMode.ROTATE
				_drag_start_angle = atan2(canvas_px.y - center.y, canvas_px.x - center.x)
				_drag_start_rot = float(sel.get("rot", 0.0))
				return

	if active_tool == Tool.SELECT:
		var hit := _hit_test_sticker(canvas_px)
		if hit != _selected_sticker:
			_selected_sticker = hit
			sticker_selection_changed.emit(_selected_sticker)
		if hit >= 0:
			_push_undo()
			var s := _stickers[hit]
			_sticker_drag_offset = Vector2(float(s.get("x", 0.0)), float(s.get("y", 0.0))) - canvas_px
			_drag_mode = DragMode.MOVE
		queue_redraw()
		return

	if active_tool == Tool.TEXT:
		if not _canvas_rect.has_point(screen_pos):
			return
		var hit := _hit_test_sticker(canvas_px)
		if hit >= 0 and str(_stickers[hit].get("kind", "sticker")) == "text":
			_selected_sticker = hit
			active_tool = Tool.SELECT
			sticker_selection_changed.emit(_selected_sticker)
			queue_redraw()
		else:
			add_text_layer("Sari-Sari", canvas_px)
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
				if not _undo_stack.is_empty():
					_undo_stack.pop_back()
					_emit_history()
		Tool.EYEDROPPER:
			var picked := _pick_composited_color(canvas_px)
			brush_color = picked
			eyedropper_picked.emit(picked)


func _handle_left_release() -> void:
	_is_painting = false
	_drag_mode = DragMode.NONE
	queue_redraw()


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
	var px_i := Vector2i(
		clampi(int(floorf(canvas_px.x)), 0, canvas_size.x - 1),
		clampi(int(floorf(canvas_px.y)), 0, canvas_size.y - 1)
	)
	var hit := _hit_test_sticker(canvas_px)
	if hit >= 0:
		var s := _stickers[hit]
		if str(s.get("kind", "sticker")) == "text":
			return Color.html(str(s.get("color", "#231E1A")))
		var tex := _get_item_texture(str(s.get("item_path", "")))
		if tex:
			var img := tex.get_image()
			if img and not img.is_empty():
				if img.is_compressed():
					img.decompress()
				var center := Vector2(float(s.get("x", 0.0)), float(s.get("y", 0.0)))
				var rot := float(s.get("rot", 0.0))
				var sc := float(s.get("scale", 1.0))
				var half := _get_layer_base_size(s) * sc * 0.5
				var local := (canvas_px - center).rotated(-rot)
				var u := clampf((local.x / maxf(1.0, half.x)) * 0.5 + 0.5, 0.0, 1.0)
				var v := clampf((local.y / maxf(1.0, half.y)) * 0.5 + 0.5, 0.0, 1.0)
				var sx := clampi(int(u * float(img.get_width() - 1)), 0, img.get_width() - 1)
				var sy := clampi(int(v * float(img.get_height() - 1)), 0, img.get_height() - 1)
				var col := img.get_pixel(sx, sy)
				if col.a > 0.2:
					return Color(col.r, col.g, col.b, 1.0)
	var c := _paint_image.get_pixel(px_i.x, px_i.y)
	return Color(c.r, c.g, c.b, 1.0)
