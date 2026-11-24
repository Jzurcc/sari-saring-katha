extends Control

## Shared Hades-style boon emblem: a saturated right-triangle corner backing (bottom-left,
## hypotenuse running through the diamond) behind a rotated, double-bordered diamond.
## Used by the Neighborhood Events menu and the Reyna Mayari card draft.
## Colors by kind: EVENT = light green, FAVOR = soft saturated yellow, CHILL = light blue.

var accent: Color = Color(1.0, 0.78, 0.16, 1.0)
var accent_bright: Color = Color(1.0, 0.90, 0.48, 1.0)
## Leave fully transparent to auto-derive a dark accent-tinted inner fill.
var fill_color: Color = Color(0.0, 0.0, 0.0, 0.0)

static func palette(kind: String) -> Dictionary:
	match kind:
		"event":
			return {
				"accent": Color(0.34, 0.82, 0.32, 1.0),
				"bright": Color(0.68, 0.97, 0.58, 1.0),
				"bg": Color(0.060, 0.092, 0.064, 0.96),
				"tag": "EVENT",
			}
		"chill":
			return {
				"accent": Color(0.26, 0.60, 1.0, 1.0),
				"bright": Color(0.64, 0.85, 1.0, 1.0),
				"bg": Color(0.056, 0.076, 0.118, 0.96),
				"tag": "CHILL",
			}
		_:
			return {
				"accent": Color(1.0, 0.78, 0.16, 1.0),
				"bright": Color(1.0, 0.90, 0.48, 1.0),
				"bg": Color(0.098, 0.084, 0.052, 0.96),
				"tag": "FAVOR",
			}

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.46

	# True right-triangle corner backing (saturated), like the Hades boon slot
	var tri := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(0.0, size.y),
		Vector2(size.x, size.y),
	])
	draw_colored_polygon(tri, Color(accent.r, accent.g, accent.b, 0.92))

	var outer := _diamond_pts(c, r)
	draw_colored_polygon(outer, Color(0.04, 0.035, 0.03, 0.97))
	draw_polyline(_closed_pts(outer), accent_bright, 2.5, true)

	var inner_fill := fill_color
	if inner_fill.a <= 0.01:
		inner_fill = Color(accent.r * 0.26, accent.g * 0.26, accent.b * 0.26, 0.98)
	var inner := _diamond_pts(c, r * 0.84)
	draw_colored_polygon(inner, inner_fill)
	draw_polyline(_closed_pts(inner), Color(accent.r, accent.g, accent.b, 0.85), 1.5, true)

	for pt in outer:
		draw_colored_polygon(_diamond_pts(pt, 3.5), accent_bright)

func _diamond_pts(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	])

func _closed_pts(pts: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	return closed
