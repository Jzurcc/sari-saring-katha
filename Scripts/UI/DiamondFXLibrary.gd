class_name DiamondFXLibrary
extends RefCounted

## Modernized library of 30 roguelike / card-game diamond emblem effects across 4 families:
##   1. Lucide Micro-Particle FX (15+ verified Lucide icons)
##   2. Border & Rim FX (chromatic chase, gilded streaks, filigree corners, barbed warning rim)
##   3. Color / Foil / Atmospheric Wash FX (holographic foil, aurora veil, eclipse shadow)
##   4. Geometric & Ambient Particle FX (fireflies, monsoon rain, embers, orbits, confetti)
##
## Follows game-ui-design clarity principles: keeps the center 50% glyph silhouette crisp
## while concentrating motion along the inner bevel, outer rim, corners, and peripheral drift.
## Shared by HadesDiamondEmblem and MayariCardHUD's MiniDiamondIcon.

const FX_POOL: Array[String] = [
	# Original 12 (upgraded)
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
	# New 18 (Border, Color, Lucide, Particle)
	"chromatic_border",
	"gilded_chase",
	"filigree_corners",
	"frost_crystal_rim",
	"eclipse_wash",
	"aurora_veil",
	"coin_shower",
	"monsoon_rain",
	"spectral_wisps",
	"mist_shroud",
	"warm_steam",
	"heartbeat_aura",
	"radio_waves",
	"festive_confetti",
	"lucky_fireflies",
	"speed_streaks",
	"golden_laurel",
	"crimson_barbed_rim",
]

const ICON_SPARKLES := "res://Assets/ui/icons/sparkles.png"
const ICON_FLAME := "res://Assets/ui/icons/flame.png"
const ICON_SNOWFLAKE := "res://Assets/ui/icons/snowflake.png"
const ICON_ZAP := "res://Assets/ui/icons/zap.png"
const ICON_MOON_STAR := "res://Assets/ui/icons/moon-star.png"
const ICON_MOON := "res://Assets/ui/icons/moon.png"
const ICON_SUN := "res://Assets/ui/icons/sun-medium.png"
const ICON_WIND := "res://Assets/ui/icons/wind.png"
const ICON_BANKNOTE := "res://Assets/ui/icons/banknote.png"
const ICON_CLOUD_RAIN := "res://Assets/ui/icons/cloud-rain.png"
const ICON_CLOUD_FOG := "res://Assets/ui/icons/cloud-fog.png"
const ICON_GHOST := "res://Assets/ui/icons/ghost.png"
const ICON_COFFEE := "res://Assets/ui/icons/coffee.png"
const ICON_HEART_PULSE := "res://Assets/ui/icons/heart-pulse.png"
const ICON_RADIO_TOWER := "res://Assets/ui/icons/radio-tower.png"
const ICON_PARTY_POPPER := "res://Assets/ui/icons/party-popper.png"
const ICON_TROPHY := "res://Assets/ui/icons/trophy.png"
const ICON_ROUTE := "res://Assets/ui/icons/route.png"

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

static func _pick_from(pool: Array[String], key: String) -> String:
	var h := absi(("katha_diamond_fx_v3::" + key).hash())
	return pool[h % pool.size()]

## Thematic + deterministic assignment from canonical ID -> one of the 30 compiled effects.
## Identical across Main HUD, Calendar & Events, Morning Toast, Mayari Tally, and Day Summary.
static func fx_kind_for_id(canonical_id: String) -> String:
	var key := canonical_id.strip_edges().to_lower()
	if key == "":
		return "prism_pulse"

	# 1. Cold / Frost / Fridge
	if "frost" in key or "chill" in key or "cold" in key:
		return _pick_from(["frost_drift", "frost_crystal_rim"], key)
	# 2. Rain / Flood / Typhoon / Basaan
	if "rain" in key or "flood" in key or "typhoon" in key or "basaan" in key or "sunshower" in key:
		return _pick_from(["monsoon_rain", "wind_swirl"], key)
	# 3. Wind / Draft / Breeze / Mist
	if "wind" in key or "draft" in key or "breeze" in key or "amihan" in key:
		return _pick_from(["wind_swirl", "mist_shroud"], key)
	if "mist" in key or "fog" in key or "smoke" in key or "kapre" in key:
		return _pick_from(["mist_shroud", "spectral_wisps", "aurora_veil"], key)
	# 4. Electricity / Brownout / Voltage / Static
	if "brownout" in key or "outage" in key or "voltage" in key or "static" in key or "zap" in key:
		return _pick_from(["electric_arc", "crimson_barbed_rim"], key)
	# 5. Radio / Signal / Dial / Videoke / Chorus
	if "radio" in key or "dial" in key or "signal" in key or "airwaves" in key or "videoke" in key or "chorus" in key:
		return _pick_from(["radio_waves", "sonic_ripple"], key)
	# 6. Ghost / Phantom / Folklore Omen / Eclipse / Blood Moon
	if "ghost" in key or "phantom" in key or "duwende" in key or "tiktik" in key or "aswang" in key or "eerie" in key:
		return _pick_from(["spectral_wisps", "eclipse_wash", "crimson_barbed_rim"], key)
	if "eclipse" in key or "blood_moon" in key or "dusk" in key or "borrowed_hour" in key:
		return _pick_from(["eclipse_wash", "crimson_barbed_rim", "lunar_halo"], key)
	# 7. Moon / Lunar / Silver / Mayari
	if "moon" in key or "lunar" in key or "mayari" in key or "silver" in key:
		return _pick_from(["lunar_halo", "holographic_foil", "celestial_sparkles", "aurora_veil"], key)
	# 8. Heat / Fire / Flame / Sun / Thirsty / Stubborn
	if "heat" in key or "scorching" in key or "flame" in key or "thirsty" in key or "stubborn" in key:
		return _pick_from(["crimson_flames", "rising_embers", "solar_rays"], key)
	if "sun" in key or "bright" in key or "glow" in key or "warm_trade" in key:
		return _pick_from(["solar_rays", "gilded_chase", "rising_embers"], key)
	# 9. Money / Tips / Gold / Payday / Coin / Peligro
	if "tip" in key or "gold" in key or "coin" in key or "payday" in key or "penny" in key or "peligro" in key or "sour_change" in key:
		return _pick_from(["coin_shower", "gilded_chase", "chromatic_border"], key)
	# 10. Fiesta / Party / Balikbayan / Sipa / Trophy / Lucky
	if "fiesta" in key or "balikbayan" in key or "sipa" in key or "liga" in key or "basketball" in key or "lucky" in key:
		return _pick_from(["festive_confetti", "golden_laurel", "celestial_sparkles"], key)
	# 11. Restock / Delivery / Road / Highway / Detour / Shortcut / Bag
	if "road" in key or "highway" in key or "detour" in key or "shortcut" in key or "restock" in key or "truck" in key or "fuel" in key or "bag" in key or "bounty" in key or "toda" in key:
		return _pick_from(["speed_streaks", "gilded_chase", "arcane_orbit"], key)
	# 12. Coffee / Merienda / Tambayan / Warm Welcome / Health / Albularyo
	if "merienda" in key or "coffee" in key or "tambayan" in key or "bench" in key:
		return _pick_from(["warm_steam", "lucky_fireflies"], key)
	if "welcome" in key or "health" in key or "albularyo" in key or "heart" in key or "care" in key:
		return _pick_from(["heartbeat_aura", "lucky_fireflies", "aurora_veil"], key)
	# 13. Haggle / Bargain / Scale / Lista / Utang / Story / Ears
	if "haggle" in key or "bargain" in key or "sharp" in key or "restless" in key or "picky" in key:
		return _pick_from(["chromatic_border", "crimson_barbed_rim", "filigree_corners"], key)
	if "lista" in key or "tab" in key or "story" in key or "stories" in key or "ears" in key or "memory" in key:
		return _pick_from(["filigree_corners", "arcane_orbit", "prism_pulse"], key)
	# 14. Visitors / Crowded / Stoop / Brisk
	if "visitor_" in key:
		return _pick_from(["lucky_fireflies", "celestial_sparkles", "chromatic_border", "gilded_chase"], key)

	return _pick_from(FX_POOL, key)

static func fx_phase_for_id(canonical_id: String) -> float:
	var key := canonical_id.strip_edges().to_lower()
	return float(absi(("phase::" + key).hash()) % 120) * 0.05236

## Returns a subtle, clarity-safe micro-motion preset for the center Lucide icon:
## "breathe" | "float" | "sway" | "pulse_beat" | "shimmer"
static func glyph_motion_for_fx(fx_kind: String) -> String:
	match fx_kind:
		"heartbeat_aura", "crimson_barbed_rim", "sonic_ripple":
			return "pulse_beat"
		"wind_swirl", "mist_shroud", "spectral_wisps", "monsoon_rain", "warm_steam", "frost_drift":
			return "float"
		"electric_arc", "speed_streaks", "radio_waves":
			return "shimmer"
		"festive_confetti", "coin_shower", "lucky_fireflies", "arcane_orbit":
			return "sway"
		_:
			return "breathe"

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

static func _point_on_diamond(outer: PackedVector2Array, frac01: float) -> Vector2:
	var f := fposmod(frac01, 1.0) * 4.0
	var ei := int(floorf(f)) % 4
	var st := f - floorf(f)
	return outer[ei].lerp(outer[(ei + 1) % 4], st)

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

## Layer 1: Rendered BEHIND the diamond frame (auras, halos, rays, shockwaves, rim glows).
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

		"chromatic_border":
			var hue := fposmod(t * 0.18, 1.0)
			var c_outer := Color.from_hsv(hue, 0.65, 1.0, 0.24)
			var c_inner := Color.from_hsv(fposmod(hue + 0.28, 1.0), 0.72, 1.0, 0.32)
			canvas.draw_polyline(_closed_pts(_diamond_pts(c, r * 1.13)), c_outer, 4.2, true)
			canvas.draw_polyline(_closed_pts(_diamond_pts(c, r * 1.06)), c_inner, 2.6, true)

		"gilded_chase":
			var p := 0.5 + 0.5 * sin(t * 2.2)
			canvas.draw_polyline(_closed_pts(_diamond_pts(c, r * (1.06 + p * 0.04))), Color(1.0, 0.86, 0.38, 0.16 + p * 0.14), 3.8, true)

		"frost_crystal_rim":
			var p := 0.5 + 0.5 * sin(t * 2.0)
			var dirs := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
			for d in dirs:
				var tip: Vector2 = c + d * (r * (1.20 + p * 0.06))
				var perp := Vector2(-d.y, d.x)
				var base_a: Vector2 = c + d * (r * 0.96) + perp * (r * 0.10)
				var base_b: Vector2 = c + d * (r * 0.96) - perp * (r * 0.10)
				canvas.draw_colored_polygon(PackedVector2Array([base_a, tip, base_b]), Color(0.74, 0.95, 1.0, 0.34 + p * 0.22))

		"eclipse_wash":
			var p := 0.5 + 0.5 * sin(t * 1.9)
			canvas.draw_arc(c, r * (1.09 + p * 0.04), 0.0, TAU, 32, Color(0.95, 0.42, 0.28, 0.18 + p * 0.16), 3.0, true)

		"heartbeat_aura":
			# Classic double-beat systolic pulse (lub-dub)
			var cyc := fmod(t * 0.85, 1.0)
			var beat1 := exp(-pow((cyc - 0.12) * 14.0, 2.0))
			var beat2 := exp(-pow((cyc - 0.28) * 16.0, 2.0)) * 0.72
			var beat := maxf(beat1, beat2)
			if beat > 0.04:
				var hr := r * (1.05 + beat * 0.18)
				canvas.draw_polyline(_closed_pts(_diamond_pts(c, hr)), Color(1.0, 0.48, 0.56, beat * 0.48), 3.6, true)

		"radio_waves":
			for i in range(3):
				var cyc := fmod(t * 0.52 + float(i) * 0.33, 1.0)
				var wr := r * lerpf(0.92, 1.38, cyc)
				var wa := (1.0 - cyc) * 0.42
				if wa > 0.02:
					canvas.draw_arc(c + Vector2(r * 0.22, -r * 0.22), wr * 0.65, -PI * 0.42, PI * 0.08, 12, Color(accent_bright.r, accent_bright.g, accent_bright.b, wa), 2.0, true)

		"golden_laurel":
			var p := 0.5 + 0.5 * sin(t * 2.0)
			canvas.draw_arc(c, r * 1.12, PI * 0.15, PI * 0.85, 16, Color(1.0, 0.88, 0.42, 0.28 + p * 0.18), 2.6, true)
			canvas.draw_arc(c, r * 1.12, -PI * 0.85, -PI * 0.15, 16, Color(1.0, 0.88, 0.42, 0.22 + p * 0.14), 2.2, true)

		"crimson_barbed_rim":
			var p := 0.5 + 0.5 * sin(t * 3.8)
			var col := Color(1.0, 0.28, 0.26, 0.18 + p * 0.22)
			canvas.draw_polyline(_closed_pts(_diamond_pts(c, r * (1.07 + p * 0.05))), col, 3.8, true)

		"spectral_wisps":
			var p := 0.5 + 0.5 * sin(t * 1.7)
			canvas.draw_polyline(_closed_pts(_diamond_pts(c, r * (1.08 + p * 0.06))), Color(0.56, 0.88, 0.98, 0.14 + p * 0.12), 4.2, true)

## Layer 2: Rendered INSIDE the diamond face (holographic foil, aurora veil, eclipse shadow, glints).
static func draw_inner_fx(canvas: CanvasItem, fx_kind: String, c: Vector2, r: float, accent: Color, accent_bright: Color, t: float) -> void:
	match fx_kind:
		"holographic_foil":
			var cyc := fmod(t * 0.34, 1.0)
			if cyc < 0.44:
				var f := cyc / 0.44
				var off := lerpf(-r * 0.72, r * 0.72, f)
				var s_a := sin(f * PI)
				var p1 := c + Vector2(off - r * 0.26, -r * 0.36)
				var p2 := c + Vector2(off + r * 0.26, r * 0.36)
				canvas.draw_line(p1, p2, Color(1.0, 0.98, 0.88, s_a * 0.38), 5.2, true)
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
			var s_a := sin(cyc * PI) * 0.26
			if s_a > 0.02:
				var pts := PackedVector2Array()
				for i in range(6):
					var u := float(i) / 5.0
					var x := lerpf(-r * 0.56, r * 0.56, u)
					var y := sin(u * PI * 1.6 + t * 3.8) * r * 0.18 + lerpf(r * 0.12, -r * 0.12, u)
					pts.append(c + Vector2(x, y))
				canvas.draw_polyline(pts, Color(1.0, 0.98, 0.92, s_a), 2.0, true)

		"aurora_veil":
			for band in range(2):
				var hue := fposmod(0.42 + float(band) * 0.26 + sin(t * 0.55 + float(band)) * 0.08, 1.0)
				var col := Color.from_hsv(hue, 0.62, 1.0, 0.22)
				var pts := PackedVector2Array()
				for i in range(7):
					var u := float(i) / 6.0
					var x := lerpf(-r * 0.54, r * 0.54, u)
					var y := sin(u * PI * 1.8 + t * 1.8 + float(band) * 2.1) * r * 0.16 + (float(band) - 0.5) * r * 0.22
					pts.append(c + Vector2(x, y))
				canvas.draw_polyline(pts, col, 4.0, true)

		"eclipse_wash":
			var cyc := 0.5 + 0.5 * sin(t * 1.1)
			var shadow_off := Vector2(lerpf(-r * 0.28, r * 0.28, cyc), -r * 0.08)
			canvas.draw_circle(c + shadow_off, r * 0.44, Color(0.03, 0.02, 0.06, 0.42))
			canvas.draw_arc(c + shadow_off, r * 0.44, -PI * 0.35, PI * 0.55, 14, Color(1.0, 0.55, 0.32, 0.30), 1.8, true)

		"frost_crystal_rim":
			var p := 0.5 + 0.5 * sin(t * 2.0)
			canvas.draw_colored_polygon(_diamond_pts(c, r * 0.78), Color(0.62, 0.92, 1.0, 0.08 + p * 0.07))

		"mist_shroud":
			for i in range(2):
				var cyc := fmod(t * (0.22 + float(i) * 0.07) + float(i) * 0.5, 1.0)
				var alpha := sin(cyc * PI) * 0.20
				var y := c.y + (0.20 if i == 0 else -0.18) * r
				var x0 := c.x + lerpf(-r * 0.55, r * 0.15, cyc)
				canvas.draw_line(Vector2(x0, y), Vector2(x0 + r * 0.42, y), Color(0.88, 0.94, 0.98, alpha), 5.0, true)

		"crimson_barbed_rim":
			var p := 0.5 + 0.5 * sin(t * 3.8)
			canvas.draw_polyline(_closed_pts(_diamond_pts(c, r * 0.72)), Color(1.0, 0.32, 0.28, 0.18 + p * 0.22), 1.8, true)

		"golden_laurel":
			var p := 0.5 + 0.5 * sin(t * 2.2)
			canvas.draw_colored_polygon(_diamond_pts(c, r * 0.76), Color(1.0, 0.86, 0.38, 0.06 + p * 0.08))

		"chromatic_border":
			var hue := fposmod(t * 0.18 + 0.5, 1.0)
			canvas.draw_polyline(_closed_pts(_diamond_pts(c, r * 0.74)), Color.from_hsv(hue, 0.58, 1.0, 0.24), 1.6, true)

## Layer 3: Rendered ABOVE the diamond frame (Lucide micro-particles, border chases, orbits, sparks).
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
				for tail in range(3, 0, -1):
					var tp := _point_on_diamond(outer, base_frac - float(tail) * 0.022 * signf(speed))
					var ta := (1.0 - float(tail) / 3.5) * 0.34
					canvas.draw_circle(tp, 2.6 - float(tail) * 0.45, Color(accent_bright.r, accent_bright.g, accent_bright.b, ta))
				var pt := _point_on_diamond(outer, base_frac)
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
			var cyc := fmod(t * 0.34, 1.0)
			if cyc > 0.16 and cyc < 0.40:
				var gl := sin(((cyc - 0.16) / 0.24) * PI)
				_draw_four_point_star(canvas, c + Vector2(r * 0.55, -r * 0.55), 3.0 + gl * 4.5, Color(1.0, 0.99, 0.90, gl * 0.88))

		# ── 18 New Modernized Effects ──
		"chromatic_border":
			# Smooth rainbow/pearl chase segment + 4 hue-shifted corner gems
			var base_f := fposmod(t * 0.24, 1.0)
			for seg in range(10):
				var f0 := base_f + float(seg) * 0.016
				var f1 := f0 + 0.018
				var hue := fposmod(t * 0.22 + float(seg) * 0.07, 1.0)
				var col := Color.from_hsv(hue, 0.68, 1.0, 0.86)
				canvas.draw_line(_point_on_diamond(outer, f0), _point_on_diamond(outer, f1), col, 3.0, true)
			for i in range(4):
				var chue := fposmod(t * 0.20 + float(i) * 0.25, 1.0)
				_draw_four_point_star(canvas, outer[i], 3.4, Color.from_hsv(chue, 0.55, 1.0, 0.85))

		"gilded_chase":
			# Twin liquid-gold streaks racing on opposite sides of the diamond rim
			for streak in range(2):
				var head := fposmod(t * 0.30 + float(streak) * 0.5, 1.0)
				for s in range(7):
					var fa := head - float(s) * 0.016
					var fb := fa - 0.016
					var a := (1.0 - float(s) / 7.5) * 0.92
					canvas.draw_line(_point_on_diamond(outer, fa), _point_on_diamond(outer, fb), Color(1.0, 0.93, 0.60, a), 3.2 - float(s) * 0.28, true)
				_draw_four_point_star(canvas, _point_on_diamond(outer, head), 4.2, Color(1.0, 0.99, 0.88, 0.95))

		"filigree_corners":
			# Ornate pulsing double-chevron brackets hugging all 4 diamond points
			var p := 0.5 + 0.5 * sin(t * 2.2)
			var col := Color(accent_bright.r, accent_bright.g, accent_bright.b, 0.52 + p * 0.40)
			var offset := r * (0.10 + p * 0.04)
			var arm := r * 0.22
			for i in range(4):
				var dir := (outer[i] - c).normalized()
				var perp := Vector2(-dir.y, dir.x)
				var apex := outer[i] + dir * offset
				var leg_a := apex - dir * arm + perp * arm
				var leg_b := apex - dir * arm - perp * arm
				canvas.draw_polyline(PackedVector2Array([leg_a, apex, leg_b]), col, 2.0, true)

		"frost_crystal_rim":
			var ang := -t * 0.42
			var fpos := c + Vector2(cos(ang), sin(ang)) * (r * 0.96)
			_draw_lucide_sprite(canvas, ICON_SNOWFLAKE, fpos, 11.5, Color(0.86, 0.98, 1.0, 0.90))
			for pt in outer:
				var gl := 0.5 + 0.5 * sin(t * 3.1 + pt.x * 0.1)
				_draw_four_point_star(canvas, pt, 2.2 + gl * 2.6, Color(0.88, 0.98, 1.0, 0.55 + gl * 0.40))

		"eclipse_wash":
			var ang := t * 0.36
			var mpos := c + Vector2(cos(ang), sin(ang)) * (r * 1.04)
			_draw_lucide_sprite(canvas, ICON_MOON, mpos, 11.0, Color(1.0, 0.72, 0.48, 0.88))

		"aurora_veil":
			for i in range(4):
				var cyc := fmod(t * 0.28 + float(i) * 0.25, 1.0)
				var hue := fposmod(0.45 + float(i) * 0.14, 1.0)
				var px := c.x + lerpf(-r * 0.75, r * 0.75, float(i) / 3.0)
				var py := c.y + lerpf(r * 0.45, -r * 0.95, cyc)
				var a := sin(cyc * PI) * 0.78
				if a > 0.04:
					canvas.draw_circle(Vector2(px, py), 2.4, Color.from_hsv(hue, 0.55, 1.0, a))

		"coin_shower":
			for i in range(3):
				var cyc := fmod(t * 0.36 + float(i) * 0.33, 1.0)
				var x_off := lerpf(-r * 0.65, r * 0.65, float(i) / 2.0) + sin(t * 2.5 + float(i)) * r * 0.08
				var y_off := lerpf(r * 0.70, -r * 0.95, cyc)
				var alpha := sin(cyc * PI) * 0.88
				if i == 1:
					_draw_lucide_sprite(canvas, ICON_BANKNOTE, c + Vector2(x_off, y_off), 11.5, Color(1.0, 0.92, 0.48, alpha))
				else:
					canvas.draw_circle(c + Vector2(x_off, y_off), 3.4, Color(1.0, 0.86, 0.32, alpha * 0.45))
					canvas.draw_circle(c + Vector2(x_off, y_off), 2.0, Color(1.0, 0.96, 0.72, alpha))

		"monsoon_rain":
			for i in range(5):
				var cyc := fmod(t * (0.78 + float(i % 2) * 0.14) + float(i) * 0.21, 1.0)
				var x0 := c.x + lerpf(-r * 0.78, r * 0.78, float(i) / 4.0) - cyc * r * 0.35
				var y0 := c.y + lerpf(-r * 0.95, r * 0.85, cyc)
				var a := sin(cyc * PI) * 0.72
				if a > 0.04:
					canvas.draw_line(Vector2(x0, y0), Vector2(x0 - 3.5, y0 + 8.5), Color(0.74, 0.90, 1.0, a), 1.6, true)
			var p := 0.5 + 0.5 * sin(t * 1.8)
			_draw_lucide_sprite(canvas, ICON_CLOUD_RAIN, c + Vector2(-r * 0.68, -r * 0.72), 11.0 + p * 1.5, Color(0.80, 0.92, 1.0, 0.72 + p * 0.20))

		"spectral_wisps":
			for i in range(2):
				var ang := t * (0.62 if i == 0 else -0.48) + float(i) * PI
				var rad_m := r * (0.98 + 0.10 * sin(t * 2.2 + float(i)))
				var pos := c + Vector2(cos(ang), sin(ang)) * rad_m
				canvas.draw_circle(pos, 5.5, Color(0.54, 0.88, 1.0, 0.24))
				if i == 0:
					_draw_lucide_sprite(canvas, ICON_GHOST, pos, 11.5, Color(0.86, 0.96, 1.0, 0.86))
				else:
					canvas.draw_circle(pos, 2.4, Color(0.92, 0.98, 1.0, 0.88))

		"mist_shroud":
			var cyc := fmod(t * 0.26, 1.0)
			var a := sin(cyc * PI) * 0.78
			var mpos := c + Vector2(lerpf(-r * 0.78, r * 0.78, cyc), r * 0.66)
			_draw_lucide_sprite(canvas, ICON_CLOUD_FOG, mpos, 12.5, Color(0.88, 0.94, 1.0, a))

		"warm_steam":
			for i in range(3):
				var cyc := fmod(t * 0.34 + float(i) * 0.33, 1.0)
				var a := sin(cyc * PI) * 0.70
				var x_base := c.x + lerpf(-r * 0.45, r * 0.45, float(i) / 2.0)
				var y_base := c.y + lerpf(r * 0.65, -r * 0.92, cyc)
				var sway := sin(cyc * PI * 2.5 + float(i) * 1.7) * r * 0.10
				if i == 1:
					_draw_lucide_sprite(canvas, ICON_COFFEE, Vector2(x_base + sway, y_base), 10.5, Color(1.0, 0.92, 0.76, a))
				else:
					canvas.draw_circle(Vector2(x_base + sway, y_base), lerpf(2.8, 1.4, cyc), Color(1.0, 0.95, 0.84, a * 0.72))

		"heartbeat_aura":
			var cyc := fmod(t * 0.85, 1.0)
			var beat := exp(-pow((cyc - 0.12) * 14.0, 2.0))
			_draw_lucide_sprite(canvas, ICON_HEART_PULSE, c + Vector2(r * 0.72, -r * 0.72), 10.0 + beat * 3.5, Color(1.0, 0.68, 0.74, 0.62 + beat * 0.36))

		"radio_waves":
			var p := 0.5 + 0.5 * sin(t * 3.4)
			_draw_lucide_sprite(canvas, ICON_RADIO_TOWER, c + Vector2(r * 0.72, -r * 0.74), 11.0 + p * 2.0, Color(accent_bright.r, accent_bright.g, accent_bright.b, 0.68 + p * 0.28))

		"festive_confetti":
			var palette_cols: Array[Color] = [
				Color(1.0, 0.42, 0.46, 1.0),
				Color(1.0, 0.84, 0.32, 1.0),
				Color(0.42, 0.92, 0.62, 1.0),
				Color(0.48, 0.80, 1.0, 1.0),
			]
			for i in range(6):
				var cyc := fmod(t * (0.42 + float(i % 3) * 0.08) + float(i) * 0.17, 1.0)
				var a := sin(cyc * PI) * 0.90
				var px := c.x + lerpf(-r * 0.82, r * 0.82, float(i) / 5.0) + sin(t * 4.0 + float(i) * 2.0) * 4.0
				var py := c.y + lerpf(-r * 0.85, r * 0.85, cyc)
				var col := palette_cols[i % palette_cols.size()]
				col.a = a
				canvas.draw_rect(Rect2(Vector2(px - 2.0, py - 1.5), Vector2(4.0, 3.0)), col)
			var p := 0.5 + 0.5 * sin(t * 2.8)
			_draw_lucide_sprite(canvas, ICON_PARTY_POPPER, c + Vector2(-r * 0.74, -r * 0.74), 11.0 + p * 2.0, Color(1.0, 0.92, 0.62, 0.72 + p * 0.24))

		"lucky_fireflies":
			for i in range(4):
				var ang := t * (0.9 + float(i) * 0.22) + float(i) * 1.6
				var fx := c.x + cos(ang) * r * (0.85 + 0.14 * sin(t * 1.3 + float(i)))
				var fy := c.y + sin(ang * 1.4) * r * 0.82
				var glow := 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 3.6 + float(i) * 2.3))
				canvas.draw_circle(Vector2(fx, fy), 4.6, Color(0.86, 1.0, 0.44, glow * 0.28))
				canvas.draw_circle(Vector2(fx, fy), 1.9, Color(1.0, 0.98, 0.78, glow * 0.95))

		"speed_streaks":
			for i in range(3):
				var cyc := fmod(t * 0.95 + float(i) * 0.33, 1.0)
				var a := sin(cyc * PI) * 0.78
				var y := c.y + lerpf(-r * 0.65, r * 0.65, float(i) / 2.0)
				var x := c.x + lerpf(-r * 1.05, r * 1.05, cyc)
				canvas.draw_line(Vector2(x - 10.0, y), Vector2(x + 4.0, y), Color(accent_bright.r, accent_bright.g, accent_bright.b, a), 2.0, true)
			_draw_lucide_sprite(canvas, ICON_ROUTE, c + Vector2(r * 0.74, r * 0.68), 10.5, Color(accent_bright.r, accent_bright.g, accent_bright.b, 0.78))

		"golden_laurel":
			var p := 0.5 + 0.5 * sin(t * 2.4)
			_draw_lucide_sprite(canvas, ICON_TROPHY, c + Vector2(0.0, -r * 0.96), 11.0 + p * 2.0, Color(1.0, 0.92, 0.52, 0.82 + p * 0.16))
			for pt in outer:
				_draw_four_point_star(canvas, pt, 2.6 + p * 2.0, Color(1.0, 0.96, 0.76, 0.65 + p * 0.30))

		"crimson_barbed_rim":
			# Tense warning ticks at each diamond midpoint
			var p := 0.5 + 0.5 * sin(t * 3.8)
			var col := Color(1.0, 0.42, 0.38, 0.65 + p * 0.30)
			for i in range(4):
				var mid := outer[i].lerp(outer[(i + 1) % 4], 0.5)
				var out_dir := (mid - c).normalized()
				canvas.draw_line(mid - out_dir * 2.0, mid + out_dir * (5.5 + p * 2.5), col, 2.2, true)
