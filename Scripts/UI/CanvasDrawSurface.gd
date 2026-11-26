class_name CanvasDrawSurface
extends Control

## Cozy skribbl.io-style raster paint + Stamp Mode canvas surface for Roof Signage & Promo Poster.
## Supports smooth interpolated brush/eraser strokes, iterative scanline flood-fill bucket,
## click-to-stamp product & uploaded-image stickers (with live cursor preview),
## 25-step undo/redo (preserving both pixels and promo stamp counts), and clean PNG export.

signal stroke_committed(color_used: Color)
signal stroke_updated()
signal stamps_changed()
signal tool_changed(new_tool: int)
signal history_changed(can_undo: bool, can_redo: bool)

enum Tool { BRUSH, ERASER, BUCKET, STAMP }

const MAX_UNDO := 25
const FLOOD_TOLERANCE := 22
const CUSTOM_UPLOADS_DIR := "user://custom_uploads"

const BRUSH_SIZES: Array[float] = [4.0, 10.0, 20.0, 34.0]
const STAMP_SCALES: Array[float] = [0.65, 1.0, 1.4, 1.85]

var canvas_size: Vector2i = Vector2i(1024, 368)
var transparent_background: bool = false
var background_texture: Texture2D = null
var guide_draw_callback: Callable = Callable()
var show_frame_chrome: bool = true
var input_enabled: bool = true
var canvas_padding: float = 16.0
var active_tool: Tool = Tool.BRUSH:
	set(v):
		active_tool = v
		_update_cursor_shape()
		queue_redraw()

var brush_color: Color = Color(0.84, 0.18, 0.16, 1.0)
var size_index: int = 1:
	set(v):
		size_index = clampi(v, 0, BRUSH_SIZES.size() - 1)
		queue_redraw()
var stamp_rotation: float = 0.0

var _paint_image: Image = null
var _paint_texture: ImageTexture = null
var _stamp_records: Array[Dictionary] = [] # Lightweight history of stamped items for Poster promo counts
var _active_stamp: Dictionary = {} # {kind, item_path/image_path, item_name/label, category, texture}
var _tex_cache: Dictionary = {}
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []

var _is_painting: bool = false
var _last_paint_px: Vector2 = Vector2.ZERO
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


func get_brush_radius() -> float:
	return BRUSH_SIZES[clampi(size_index, 0, BRUSH_SIZES.size() - 1)]


func get_stamp_scale() -> float:
	return STAMP_SCALES[clampi(size_index, 0, STAMP_SCALES.size() - 1)]


func get_active_stamp() -> Dictionary:
	return _active_stamp


func set_active_stamp_item(item: ItemData) -> void:
	if item == null or item.resource_path == "":
		return
	var tex := _get_item_texture(item.resource_path)
	if tex == null:
		return
	_active_stamp = {
		"kind": "sticker",
		"item_path": item.resource_path,
		"item_name": item.item_name,
		"category": item.category.to_lower(),
		"texture": tex,
	}
	stamp_rotation = 0.0
	active_tool = Tool.STAMP
	tool_changed.emit(active_tool)


func set_active_stamp_upload(image_path: String, label: String = "") -> void:
	if image_path == "" or not FileAccess.file_exists(image_path):
		return
	var tex := _get_uploaded_texture(image_path)
	if tex == null:
		return
	_active_stamp = {
		"kind": "image",
		"image_path": image_path,
		"label": label if label != "" else image_path.get_file(),
		"category": "",
		"texture": tex,
	}
	stamp_rotation = 0.0
	active_tool = Tool.STAMP
	tool_changed.emit(active_tool)


func clear_active_stamp() -> void:
	_active_stamp.clear()
	if active_tool == Tool.STAMP:
		active_tool = Tool.BRUSH
		tool_changed.emit(active_tool)


func setup_canvas(target_size: Vector2i, base_img: Image = null, saved_stamps: Array = []) -> void:
	canvas_size = target_size
	if base_img != null and not base_img.is_empty():
		var img := base_img.duplicate() as Image
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		if img.get_size() != canvas_size:
			img.resize(canvas_size.x, canvas_size.y, Image.INTERPOLATE_BILINEAR)
		_paint_image = img
		_paint_texture = ImageTexture.create_from_image(_paint_image)
	else:
		_init_blank_canvas(canvas_size)

	_stamp_records.clear()
	for entry in saved_stamps:
		if not (entry is Dictionary):
			continue
		if not bool(entry.get("visible", true)):
			continue
		var kind := str(entry.get("kind", "sticker"))
		if kind == "sticker":
			var cat := str(entry.get("category", "")).to_lower()
			var item_path := str(entry.get("item_path", ""))
			if cat != "" or item_path != "":
				_stamp_records.append({
					"kind": "sticker",
					"item_path": item_path,
					"item_name": str(entry.get("item_name", "")),
					"category": cat,
				})

	_active_stamp.clear()
	_undo_stack.clear()
	_redo_stack.clear()
	_emit_history()
	stamps_changed.emit()
	queue_redraw()


func _get_blank_color() -> Color:
	return Color(0.0, 0.0, 0.0, 0.0) if transparent_background else Color.WHITE


func _init_blank_canvas(sz: Vector2i) -> void:
	canvas_size = sz
	_paint_image = Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	_paint_image.fill(_get_blank_color())
	_paint_texture = ImageTexture.create_from_image(_paint_image)


func get_paint_image() -> Image:
	return _paint_image.duplicate() as Image


func get_raw_paint_image() -> Image:
	return _paint_image


func get_canvas_rect() -> Rect2:
	return _canvas_rect


func has_any_ink() -> bool:
	if _paint_image == null:
		return false
	var bytes := _paint_image.get_data()
	if transparent_background:
		for i in range(3, bytes.size(), 16):
			if bytes[i] > 24:
				return true
		return false
	for i in range(0, bytes.size(), 16):
		if bytes[i] < 245 or bytes[i + 1] < 245 or bytes[i + 2] < 245:
			return true
	return false


func get_serialized_stamps() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in _stamp_records:
		out.append(s.duplicate(true))
	return out


func get_sticker_category_counts() -> Dictionary:
	var counts: Dictionary = {}
	for s in _stamp_records:
		if str(s.get("kind", "sticker")) != "sticker":
			continue
		var cat := str(s.get("category", "")).to_lower()
		if cat == "":
			continue
		counts[cat] = int(counts.get(cat, 0)) + 1
	return counts


func clear_canvas() -> void:
	_push_undo()
	_paint_image.fill(_get_blank_color())
	_paint_texture.update(_paint_image)
	_stamp_records.clear()
	stamps_changed.emit()
	stroke_updated.emit()
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


static func import_uploaded_sticker(source_file_path: String) -> Dictionary:
	if source_file_path == "" or not FileAccess.file_exists(source_file_path):
		return {}
	var img := Image.load_from_file(source_file_path)
	if img == null or img.is_empty():
		return {}
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var max_dim := maxi(img.get_width(), img.get_height())
	if max_dim > 512:
		var ratio := 512.0 / float(max_dim)
		img.resize(
			maxi(1, int(roundf(img.get_width() * ratio))),
			maxi(1, int(roundf(img.get_height() * ratio))),
			Image.INTERPOLATE_LANCZOS
		)

	var abs_dir := ProjectSettings.globalize_path(CUSTOM_UPLOADS_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var base_name := source_file_path.get_file().get_basename()
	var clean_base := ""
	for i in range(base_name.length()):
		var ch := base_name.substr(i, 1)
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
			clean_base += ch
	if clean_base == "":
		clean_base = "sticker"
	var saved_path := "%s/img_%d_%s.png" % [CUSTOM_UPLOADS_DIR, Time.get_ticks_msec(), clean_base.substr(0, 20)]
	if img.save_png(saved_path) != OK:
		return {}
	return {
		"image_path": saved_path,
		"label": clean_base.substr(0, 16),
	}


static func list_uploaded_stickers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var abs_dir := ProjectSettings.globalize_path(CUSTOM_UPLOADS_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return out
	var dir := DirAccess.open(CUSTOM_UPLOADS_DIR)
	if dir == null:
		return out
	var files: Array[String] = []
	dir.list_dir_begin()
	var fn := dir.get_next()
	while fn != "":
		if not dir.current_is_dir():
			var lower := fn.to_lower()
			if lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp"):
				files.append(fn)
		fn = dir.get_next()
	dir.list_dir_end()
	files.sort()
	files.reverse() # newest timestamps first
	for f in files:
		var path := "%s/%s" % [CUSTOM_UPLOADS_DIR, f]
		var label := f.get_basename()
		if label.begins_with("img_"):
			var parts := label.split("_", false, 2)
			if parts.size() >= 3:
				label = parts[2]
		out.append({"image_path": path, "label": label})
	return out


static func delete_uploaded_sticker(image_path: String) -> bool:
	if image_path == "" or not image_path.begins_with(CUSTOM_UPLOADS_DIR):
		return false
	if FileAccess.file_exists(image_path):
		return DirAccess.remove_absolute(ProjectSettings.globalize_path(image_path)) == OK
	return false


func _capture_snapshot() -> Dictionary:
	return {
		"bytes": _paint_image.get_data(),
		"stamps": get_serialized_stamps(),
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
	_stamp_records.clear()
	for s in snap.get("stamps", []):
		if s is Dictionary:
			_stamp_records.append(s.duplicate(true))
	_emit_history()
	stamps_changed.emit()
	stroke_updated.emit()
	queue_redraw()


func _emit_history() -> void:
	history_changed.emit(not _undo_stack.is_empty(), not _redo_stack.is_empty())


func _compute_canvas_rect() -> Rect2:
	var pad := canvas_padding
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


func _get_stamp_base_size(stamp: Dictionary) -> Vector2:
	var tex: Texture2D = stamp.get("texture")
	var base_h := clampf(float(canvas_size.y) * 0.28, 96.0, 160.0)
	if tex and tex.get_height() > 0:
		var aspect := float(tex.get_width()) / float(tex.get_height())
		var w := base_h * aspect
		var max_w := float(canvas_size.x) * 0.45
		if w > max_w:
			w = max_w
			base_h = w / maxf(0.1, aspect)
		return Vector2(w, base_h)
	return Vector2(base_h, base_h)


func _draw() -> void:
	_canvas_rect = _compute_canvas_rect()

	if background_texture != null:
		var shadow_rect := _canvas_rect
		shadow_rect.position += Vector2(0.0, 10.0)
		draw_texture_rect(background_texture, shadow_rect, false, Color(0.0, 0.0, 0.0, 0.44))
		draw_texture_rect(background_texture, _canvas_rect, false)
	elif show_frame_chrome:
		# Soft drop shadow + subtle antique-gold trim + crisp white paper canvas
		var shadow_rect := _canvas_rect.grow(10.0)
		shadow_rect.position += Vector2(0.0, 6.0)
		draw_rect(shadow_rect, Color(0.0, 0.0, 0.0, 0.50), true)
		draw_rect(_canvas_rect.grow(2.5), Color(0.86, 0.67, 0.32, 0.65), true)
		draw_rect(_canvas_rect, Color.WHITE, true)

	if guide_draw_callback.is_valid():
		guide_draw_callback.call(self, _canvas_rect)

	if _paint_texture:
		draw_texture_rect(_paint_texture, _canvas_rect, false)

	var screen_scale := _canvas_rect.size.x / maxf(1.0, float(canvas_size.x))

	if input_enabled and _is_hovering and _canvas_rect.has_point(_hover_screen_pos):
		if active_tool == Tool.BRUSH or active_tool == Tool.ERASER:
			var screen_r := maxf(2.5, get_brush_radius() * screen_scale)
			var outline_col := Color(0.15, 0.15, 0.15, 0.85)
			draw_arc(_hover_screen_pos, screen_r, 0.0, TAU, 28, outline_col, 1.6, true)
			draw_arc(_hover_screen_pos, maxf(1.0, screen_r - 1.2), 0.0, TAU, 28, Color(1.0, 1.0, 1.0, 0.80), 1.0, true)
		elif active_tool == Tool.STAMP and not _active_stamp.is_empty():
			var tex: Texture2D = _active_stamp.get("texture")
			if tex:
				var sz := _get_stamp_base_size(_active_stamp) * get_stamp_scale() * screen_scale
				var dst := Rect2(-sz * 0.5, sz)
				draw_set_transform(_hover_screen_pos, stamp_rotation, Vector2.ONE)
				draw_texture_rect(tex, dst, false, Color(1.0, 1.0, 1.0, 0.72))
				draw_rect(dst, Color(0.86, 0.67, 0.32, 0.75), false, 1.5)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _update_cursor_shape() -> void:
	match active_tool:
		Tool.BUCKET, Tool.STAMP:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_:
			mouse_default_cursor_shape = Control.CURSOR_CROSS


func _gui_input(event: InputEvent) -> void:
	if not input_enabled:
		if _is_painting:
			_is_painting = false
		return

	if event is InputEventMouseMotion:
		_hover_screen_pos = event.position
		_is_hovering = true
		if _is_painting and (active_tool == Tool.BRUSH or active_tool == Tool.ERASER):
			var canvas_px := _screen_to_canvas(event.position)
			var col := _get_blank_color() if active_tool == Tool.ERASER else brush_color
			_paint_stroke(_last_paint_px, canvas_px, get_brush_radius(), col)
			_last_paint_px = canvas_px
		queue_redraw()
		return

	if event is InputEventMouseButton:
		if active_tool == Tool.STAMP and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				var step := deg_to_rad(5.0 if event.shift_pressed else 15.0)
				stamp_rotation = wrapf(stamp_rotation - step, -PI, PI)
				queue_redraw()
				accept_event()
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var step := deg_to_rad(5.0 if event.shift_pressed else 15.0)
				stamp_rotation = wrapf(stamp_rotation + step, -PI, PI)
				queue_redraw()
				accept_event()
				return

		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Right-click quick-exits Stamp Mode back to Brush
			if active_tool == Tool.STAMP:
				clear_active_stamp()
				accept_event()
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_handle_left_press(event.position)
			else:
				if _is_painting:
					_is_painting = false
					stroke_updated.emit()
				queue_redraw()
			accept_event()


func _handle_left_press(screen_pos: Vector2) -> void:
	if not _canvas_rect.has_point(screen_pos):
		return
	var canvas_px := _screen_to_canvas(screen_pos)

	match active_tool:
		Tool.BRUSH, Tool.ERASER:
			_push_undo()
			_is_painting = true
			_last_paint_px = canvas_px
			var col := _get_blank_color() if active_tool == Tool.ERASER else brush_color
			_paint_stroke(canvas_px, canvas_px, get_brush_radius(), col)
			if active_tool == Tool.BRUSH:
				stroke_committed.emit(col)
			stroke_updated.emit()
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
		Tool.STAMP:
			if _active_stamp.is_empty():
				return
			_push_undo()
			_stamp_texture_at(canvas_px, _active_stamp, get_stamp_scale(), stamp_rotation)
			if str(_active_stamp.get("kind", "")) == "sticker":
				_stamp_records.append({
					"kind": "sticker",
					"item_path": str(_active_stamp.get("item_path", "")),
					"item_name": str(_active_stamp.get("item_name", "")),
					"category": str(_active_stamp.get("category", "")),
				})
				stamps_changed.emit()
			AudioManager.play_sfx("interact")
			queue_redraw()


func _stamp_texture_at(center_px: Vector2, stamp: Dictionary, sc: float, rot: float = 0.0) -> void:
	var tex: Texture2D = stamp.get("texture")
	if tex == null:
		return
	var src_img := tex.get_image()
	if src_img == null or src_img.is_empty():
		return
	if src_img.is_compressed():
		src_img.decompress()
	if src_img.get_format() != Image.FORMAT_RGBA8:
		src_img.convert(Image.FORMAT_RGBA8)

	var src_w := src_img.get_width()
	var src_h := src_img.get_height()
	var src_bytes := src_img.get_data()

	var base_sz := _get_stamp_base_size(stamp) * sc
	var half_w := maxf(1.0, base_sz.x * 0.5)
	var half_h := maxf(1.0, base_sz.y * 0.5)

	var w := canvas_size.x
	var h := canvas_size.y
	var out_bytes := _paint_image.get_data()

	var cos_r := cos(-rot)
	var sin_r := sin(-rot)
	var abs_cos := absf(cos(rot))
	var abs_sin := absf(sin(rot))
	var ext_x := abs_cos * half_w + abs_sin * half_h
	var ext_y := abs_sin * half_w + abs_cos * half_h

	var min_px := maxi(0, floori(center_px.x - ext_x) - 1)
	var max_px := mini(w - 1, ceili(center_px.x + ext_x) + 1)
	var min_py := maxi(0, floori(center_px.y - ext_y) - 1)
	var max_py := mini(h - 1, ceili(center_px.y + ext_y) + 1)

	for py in range(min_py, max_py + 1):
		var dy := float(py) + 0.5 - center_px.y
		var row_offset := py * w

		for px in range(min_px, max_px + 1):
			var dx := float(px) + 0.5 - center_px.x
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

			var sa := (float(src_bytes[i00 + 3]) * w00 + float(src_bytes[i10 + 3]) * w10 + float(src_bytes[i01 + 3]) * w01 + float(src_bytes[i11 + 3]) * w11) / 255.0
			if sa <= 0.01:
				continue

			var sr := float(src_bytes[i00]) * w00 + float(src_bytes[i10]) * w10 + float(src_bytes[i01]) * w01 + float(src_bytes[i11]) * w11
			var sg := float(src_bytes[i00 + 1]) * w00 + float(src_bytes[i10 + 1]) * w10 + float(src_bytes[i01 + 1]) * w01 + float(src_bytes[i11 + 1]) * w11
			var sb := float(src_bytes[i00 + 2]) * w00 + float(src_bytes[i10 + 2]) * w10 + float(src_bytes[i01 + 2]) * w01 + float(src_bytes[i11 + 2]) * w11

			var oi := (row_offset + px) * 4
			var inv_a := 1.0 - sa
			out_bytes[oi] = clampi(int(roundf(sr * sa + float(out_bytes[oi]) * inv_a)), 0, 255)
			out_bytes[oi + 1] = clampi(int(roundf(sg * sa + float(out_bytes[oi + 1]) * inv_a)), 0, 255)
			out_bytes[oi + 2] = clampi(int(roundf(sb * sa + float(out_bytes[oi + 2]) * inv_a)), 0, 255)
			out_bytes[oi + 3] = 255

	_paint_image.set_data(w, h, false, Image.FORMAT_RGBA8, out_bytes)
	_paint_texture.update(_paint_image)


func _paint_stroke(from_px: Vector2, to_px: Vector2, radius: float, col: Color) -> void:
	var w := canvas_size.x
	var h := canvas_size.y
	var bytes := _paint_image.get_data()
	var r_byte := clampi(int(roundf(col.r * 255.0)), 0, 255)
	var g_byte := clampi(int(roundf(col.g * 255.0)), 0, 255)
	var b_byte := clampi(int(roundf(col.b * 255.0)), 0, 255)
	var a_byte := clampi(int(roundf(col.a * 255.0)), 0, 255)

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
					bytes[bi + 3] = a_byte

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
