class_name DiamondFXLibrary
extends RefCounted

## Compiled library of 12 subtle roguelike / card-game diamond emblem effects.
## Shared by HadesDiamondEmblem (EventsOverlay, MayariTallyOverlay, DaySummaryOverlay,
## Morning Card Toast) and MayariCardHUD's MiniDiamondIcon so every event, visitor,
## Moon Card, and Sto. Niño Blessing displays the exact same signature effect in every view.

const FX_POOL: Array[String] = [
	"holographic_foil",
	"arcane_orbit",
	"celestial_sparkles",
	"rising_embers",
	"crimson_flames",
	"frost_drift",
	"electric_arc",
	"lunar_halo",
	"solar_rays",
	"sonic_ripple",
	"wind_swirl",
	"prism_pulse",
]

const ICON_SPARKLES := "res://Assets/ui/icons/sparkles.png"
const ICON_FLAME := "res://Assets/ui/icons/flame.png"
const ICON_SNOWFLAKE := "res://Assets/ui/icons/snowflake.png"
const ICON_ZAP := "res://Assets/ui/icons/zap.png"
const ICON_MOON_STAR := "res://Assets/ui/icons/moon-star.png"
const ICON_SUN := "res://Assets/ui/icons/sun-medium.png"
const ICON_WIND := "res://Assets/ui/icons/wind.png"

static var _tex_cache: Dictionary = {}

static func _get_icon(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_tex_cache[path] = tex
	return tex

## Deterministic random assignment from canonical ID -> one of the 12 compiled effects.
## Identical across Main HUD, Calendar & Events, Morning Toast, Mayari Tally, and Day Summary.
static func fx_kind_for_id(canonical_id: String) -> String:
	var key := canonical_id.strip_edges().to_lower()
	if key == "":
		return "prism_pulse"
	var h := absi(("katha_diamond_fx_v2::" + key).hash())
	return FX_POOL[h % FX_POOL.size()]

static func fx_phase_for_id(canonical_id: String) -> float:
	var key := canonical_id.strip_edges().to_lower()
	return float(absi(("phase::" + key).hash()) % 120) * 0.05236

static func _diamond_pts(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	])

static func _closed_pts(pts: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	return closed

static func _draw_four_point_star(canvas: CanvasItem, center: Vector2, rad: float, col: Color) -> void:
	var inner_r := rad * 0.28
	var pts := PackedVector2Array([
		center + Vector2(0.0, -rad),
		center + Vector2(inner_r, -inner_r),
		center + Vector2(rad, 0.0),
		center + Vector2(inner_r, inner_r),
		center + Vector2(0.0, rad),
		center + Vector2(-inner_r, inner_r),
		center + Vector2(-rad, 0.0),
		center + Vector2(-inner_r, -inner_r),
	])
	canvas.draw_colored_polygon(pts, col)

static func _draw_lucide_sprite(canvas: CanvasItem, icon_path: String, center: Vector2, px: float, col: Color) -> void:
	var tex := _get_icon(icon_path)
	if tex == null or col.a <= 0.02 or px <= 1.0:
		return
	var half := Vector2(px * 0.5, px * 0.5)
	canvas.draw_texture_rect(tex, Rect2(center - half, Vector2(px, px)), false, col)

## Layer 1: Rendered BEHIND the diamond frame (auras, halos, rays, shockwaves).
static func draw_pre_fx(canvas: CanvasItem, fx_kind: String, c: Vector2, r: float, accent: Color, accent_bright: Color, t: float) -> void:
	match fx_kind:
		"prism_pulse":
			var p := 0.5 + 0.5 * sin(t * 2.4)
			var aura_r1 := r * (1.06 + p * 0.10)
			var aura_r2 := r * (1.14 + (1.0 - p) * 0.07)
			canvas.draw_polyline(_closed_pts(_diamond_pts(c, aura_r2)), Color(accent.r, accent.g, accent.b, 0.09 + p * 0.12), 4.0, true)
			canvas.draw_polyline(_closed_pts(_diamond_pts(c, aura_r1)), Color(accent_bright.r, accent_bright.g, accent_bright.b, 0.16 + p * 0.24), 4.8, true)

		"sonic_ripple":
			for i in range(2):
				var cyc := fmod(t * 0.42 + float(i) * 0.5, 1.0)
				var ease_c := 1.0 - pow(1.0 - cyc, 2.2)
				var rip_r := r * lerpf(0.98, 1.36, ease_c)
				var rip_a := (1.0 - cyc) * 0.44
				if rip_a > 0.02:
					canvas.draw_polyline(_closed_pts(_diamond_pts(c, rip_r)), Color(accent_bright.r, accent_bright.g, accent_bright.b, rip_a), 2.0, true)

		"lunar_halo":
			var ring_r := r * 1.12
			var segs := 10
			var rot := t * 0.45
			var arc_col := Color(accent_bright.r, accent_bright.g, accent_bright.b, 0.30)
			for i in range(segs):
				var a0 := rot + (float(i) / float(segs)) * TAU
				var a1 := a0 + (TAU / float(segs)) * 0.48
				canvas.draw_arc(c, ring_r, a0, a1, 5, arc_col, 1.7, true)

		"solar_rays":
			var ray_count := 8
			var rot := t * 0.32
			for i in range(ray_count):
				var a := rot + (float(i) / float(ray_count)) * TAU
				var pulse := 0.5 + 0.5 * sin(t * 2.6 + float(i) * 1.4)
				var r0 := r * 0.88
				var r1 := r * (1.16 + pulse * 0.16)
				var dir := Vector2(cos(a), sin(a))
				var col := Color(accent_bright.r, accent_bright.g, accent_bright.b, 0.16 + pulse * 0.22)
				canvas.draw_line(c + dir * r0, c + dir * r1, col, 2.2, true)

		"crimson_flames":
			var p := 0.5 + 0.5 * sin(t * 4.2)
			var glow_r := r * (1.05 + p * 0.06)
			canvas.draw_polyline(_closed_pts(_diamond_pts(c, glow_r)), Color(1.0, 0.52, 0.24, 0.14 + p * 0.16), 4.5, true)

		"frost_drift":
			var p := 0.5 + 0.5 * sin(t * 1.8)
			var glow_r := r * (1.06 + p * 0.05)
			canvas.draw_polyline(_closed_pts(_diamond_pts(c, glow_r)), Color(0.68, 0.90, 1.0, 0.14 + p * 0.16), 4.0, true)

## Layer 2: Rendered INSIDE the diamond face (holographic foil, subtle inner glints).
static func draw_inner_fx(canvas: CanvasItem, fx_kind: String, c: Vector2, r: float, accent: Color, accent_bright: Color, t: float) -> void:
	match fx_kind:
		"holographic_foil":
			var cyc := fmod(t * 0.34, 1.0)
			if cyc < 0.44:
				var f := cyc / 0.44
				var off := lerpf(-r * 0.72, r * 0.72, f)
				var s_a := sin(f * PI)
				# Primary bright foil band
				var p1 := c + Vector2(off - r * 0.26, -r * 0.36)
				var p2 := c + Vector2(off + r * 0.26, r * 0.36)
				canvas.draw_line(p1, p2, Color(1.0, 0.98, 0.88, s_a * 0.38), 5.2, true)
				# Secondary prismatic trailing band
				var p3 := p1 + Vector2(-r * 0.18, 0.0)
				var p4 := p2 + Vector2(-r * 0.18, 0.0)
				var prism_col := Color(accent_bright.r, minf(1.0, accent_bright.g + 0.12), 1.0, s_a * 0.24)
				canvas.draw_line(p3, p4, prism_col, 2.8, true)

		"electric_arc":
			var cyc := fmod(t * 0.72, 1.0)
			if cyc < 0.14:
				var flash := sin((cyc / 0.14) * PI)
				var inner_pts := _diamond_pts(c, r * 0.78)
				canvas.draw_colored_polygon(inner_pts, Color(accent_bright.r, accent_bright.g, 1.0, flash * 0.16))

		"wind_swirl":
			var cyc := fmod(t * 0.45, 1.0)
			var f := cyc
			var s_a := sin(f * PI) * 0.26
			if s_a > 0.02:
				var pts := PackedVector2Array()
				for i in range(6):
					var u := float(i) / 5.0
					var x := lerpf(-r * 0.56, r * 0.56, u)
					var y := sin(u * PI * 1.6 + t * 3.8) * r * 0.18 + lerpf(r * 0.12, -r * 0.12, u)
					pts.append(c + Vector2(x, y))
				canvas.draw_polyline(pts, Color(1.0, 0.98, 0.92, s_a), 2.0, true)

## Layer 3: Rendered ABOVE the diamond frame (sparkles, embers, Lucide micro-particles, orbits, arcs).
static func draw_post_fx(canvas: CanvasItem, fx_kind: String, c: Vector2, r: float, outer: PackedVector2Array, accent: Color, accent_bright: Color, t: float) -> void:
	match fx_kind:
		"celestial_sparkles":
			var spots := [
				c + Vector2(0.0, -r * 0.94),
				c + Vector2(r * 0.88, -r * 0.22),
				c + Vector2(-r * 0.82, r * 0.34),
			]
			for i in range(spots.size()):
				var twk := maxf(0.0, sin(t * 3.0 + float(i) * 2.15))
				twk = twk * twk
				if twk > 0.08:
					if i == 0:
						_draw_lucide_sprite(canvas, ICON_SPARKLES, spots[i], 9.0 + twk * 6.0, Color(1.0, 0.96, 0.80, 0.90 * twk))
					else:
						_draw_four_point_star(canvas, spots[i], 2.2 + twk * 4.2, Color(1.0, 0.96, 0.82, 0.88 * twk))

		"arcane_orbit":
			for orb in range(2):
				var speed := 0.28 if orb == 0 else -0.22
				var base_frac := fposmod(t * speed + float(orb) * 0.5, 1.0)
				# Fading comet tail (3 steps)
				for tail in range(3, 0, -1):
					var tf := fposmod(base_frac - float(tail) * 0.022 * signf(speed), 1.0) * 4.0
					var ei := int(floorf(tf)) % 4
					var st := tf - floorf(tf)
					var tp := outer[ei].lerp(outer[(ei + 1) % 4], st)
					var ta := (1.0 - float(tail) / 3.5) * 0.34
					canvas.draw_circle(tp, 2.6 - float(tail) * 0.45, Color(accent_bright.r, accent_bright.g, accent_bright.b, ta))
				var frac := base_frac * 4.0
				var edge_i := int(floorf(frac)) % 4
				var sub_t := frac - floorf(frac)
				var pt := outer[edge_i].lerp(outer[(edge_i + 1) % 4], sub_t)
				canvas.draw_circle(pt, 5.2, Color(accent_bright.r, accent_bright.g, accent_bright.b, 0.28))
				canvas.draw_circle(pt, 2.3, Color(1.0, 0.98, 0.90, 0.96))

		"rising_embers":
			for i in range(5):
				var cyc := fmod(t * (0.36 + float(i % 2) * 0.08) + float(i) * 0.21, 1.0)
				var x_base := lerpf(-r * 0.65, r * 0.65, float(i) / 4.0)
				var sway := sin(t * 3.4 + float(i) * 1.9) * r * 0.10
				var px := c.x + x_base + sway
				var py := c.y + lerpf(r * 0.72, -r * 1.08, cyc)
				var alpha := sin(cyc * PI) * 0.88
				var rad := lerpf(2.8, 1.2, cyc)
				if alpha > 0.04:
					canvas.draw_circle(Vector2(px, py), rad * 2.1, Color(accent.r, accent.g, accent.b, alpha * 0.28))
					canvas.draw_circle(Vector2(px, py), rad, Color(1.0, 0.95, 0.78, alpha))

		"crimson_flames":
			for i in range(3):
				var cyc := fmod(t * 0.58 + float(i) * 0.33, 1.0)
				var x_off := lerpf(-r * 0.52, r * 0.52, float(i) / 2.0)
				var y_off := lerpf(-r * 0.32, -r * 0.96, cyc)
				var alpha := sin(cyc * PI) * 0.82
				var sz := lerpf(8.5, 13.0, sin(cyc * PI))
				_draw_lucide_sprite(canvas, ICON_FLAME, c + Vector2(x_off, y_off), sz, Color(1.0, 0.76, 0.42, alpha))

		"frost_drift":
			for i in range(3):
				var cyc := fmod(t * 0.30 + float(i) * 0.34, 1.0)
				var x_off := lerpf(-r * 0.62, r * 0.62, float(i) / 2.0) + sin(t * 2.0 + float(i) * 2.1) * r * 0.12
				var y_off := lerpf(-r * 0.92, r * 0.88, cyc)
				var alpha := sin(cyc * PI) * 0.82
				_draw_lucide_sprite(canvas, ICON_SNOWFLAKE, c + Vector2(x_off, y_off), 10.5, Color(0.84, 0.96, 1.0, alpha))

		"electric_arc":
			var cyc := fmod(t * 0.72, 1.0)
			if cyc < 0.24:
				var f := sin((cyc / 0.24) * PI)
				var idx := int(floorf(t * 0.72)) % 4
				var a := outer[idx]
				var b := outer[(idx + 1) % 4]
				var mid1 := a.lerp(b, 0.33) + Vector2(sin(t * 41.0) * 4.5, cos(t * 37.0) * 4.5)
				var mid2 := a.lerp(b, 0.67) + Vector2(cos(t * 47.0) * 4.5, sin(t * 43.0) * 4.5)
				var bolt := PackedVector2Array([a, mid1, mid2, b])
				canvas.draw_polyline(bolt, Color(accent_bright.r, accent_bright.g, 1.0, f * 0.55), 3.6, true)
				canvas.draw_polyline(bolt, Color(1.0, 1.0, 0.96, f * 0.95), 1.5, true)
				_draw_lucide_sprite(canvas, ICON_ZAP, a.lerp(b, 0.5), 11.0, Color(1.0, 0.98, 0.80, f * 0.85))

		"lunar_halo":
			var ang := t * 0.55
			var moon_pos := c + Vector2(cos(ang), sin(ang)) * (r * 1.08)
			_draw_lucide_sprite(canvas, ICON_MOON_STAR, moon_pos, 12.0, Color(accent_bright.r, accent_bright.g, accent_bright.b, 0.90))

		"solar_rays":
			var p := 0.5 + 0.5 * sin(t * 2.8)
			_draw_lucide_sprite(canvas, ICON_SUN, c + Vector2(r * 0.78, -r * 0.76), 10.5 + p * 2.5, Color(1.0, 0.92, 0.64, 0.55 + p * 0.35))

		"wind_swirl":
			var cyc := fmod(t * 0.48, 1.0)
			var alpha := sin(cyc * PI) * 0.78
			var wpos := c + Vector2(lerpf(-r * 0.85, r * 0.85, cyc), -r * 0.55 + sin(cyc * PI * 2.0) * r * 0.18)
			_draw_lucide_sprite(canvas, ICON_WIND, wpos, 12.0, Color(0.95, 0.98, 1.0, alpha))

		"prism_pulse":
			var p := 0.5 + 0.5 * sin(t * 2.4)
			if p > 0.35:
				var ba := (p - 0.35) / 0.65
				for pt in outer:
					_draw_four_point_star(canvas, pt, 2.4 + ba * 3.2, Color(1.0, 0.97, 0.85, ba * 0.75))

		"holographic_foil":
			# Subtle top-right specular glint on foil sweep
			var cyc := fmod(t * 0.34, 1.0)
			if cyc > 0.16 and cyc < 0.40:
				var gl := sin(((cyc - 0.16) / 0.24) * PI)
				_draw_four_point_star(canvas, c + Vector2(r * 0.55, -r * 0.55), 3.0 + gl * 4.5, Color(1.0, 0.99, 0.90, gl * 0.88))
