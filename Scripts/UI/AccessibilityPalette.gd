class_name AccessibilityPalette
extends RefCounted

## Centralized Colorblind Accessibility palette & settings helper.
## Persisted in user://settings.cfg under [accessibility] colorblind_mode.
## Modes:
##   - "off"           : Default Sari-Saring Katha palette
##   - "deuteranopia"  : Red-Green safe (Okabe-Ito inspired Blue / Amber / Vermilion-Magenta)
##   - "tritanopia"    : Blue-Yellow safe (Teal-Cyan / Crimson / Rose / Silver-White)
##   - "high_contrast" : Maximum luminance contrast + crisp symbols

const SETTINGS_PATH := "user://settings.cfg"

const MODES: Array[String] = ["off", "deuteranopia", "tritanopia", "high_contrast"]
const MODE_LABELS: Dictionary = {
	"off": "Off",
	"deuteranopia": "Red-Green",
	"tritanopia": "Blue-Yellow",
	"high_contrast": "High Contrast",
}

static var _loaded: bool = false
static var _mode: String = "off"


static func get_mode() -> String:
	if not _loaded:
		_loaded = true
		var cfg := ConfigFile.new()
		if cfg.load(SETTINGS_PATH) == OK:
			var saved := str(cfg.get_value("accessibility", "colorblind_mode", "off"))
			_mode = saved if (saved in MODES) else "off"
	return _mode


static func set_mode(new_mode: String) -> void:
	_loaded = true
	_mode = new_mode if (new_mode in MODES) else "off"


static func is_active() -> bool:
	return get_mode() != "off"


static func get_mode_label(mode: String = "") -> String:
	var m := mode if mode != "" else get_mode()
	return str(MODE_LABELS.get(m, "Off"))


static func next_mode(current: String = "") -> String:
	var m := current if current != "" else get_mode()
	var idx := MODES.find(m)
	return MODES[(idx + 1) % MODES.size()]


## Returns the 4 Talisman Tracing Minigame ink swatches for the active colorblind mode.
## Each entry: { "name": String, "symbol": String, "color": Color, "guide": Color }
static func get_talisman_swatches() -> Array[Dictionary]:
	match get_mode():
		"deuteranopia":
			# Okabe-Ito Red-Green safe: Charcoal, Vivid Vermilion-Orange, Sky Blue, Bright Gold
			return [
				{"name": "Charcoal", "symbol": "1", "color": Color(0.10, 0.08, 0.07, 1.0), "guide": Color(0.13, 0.10, 0.09, 1.0)},
				{"name": "Vermilion", "symbol": "2", "color": Color(0.84, 0.37, 0.00, 1.0), "guide": Color(0.92, 0.44, 0.04, 1.0)},
				{"name": "Sky Indigo", "symbol": "3", "color": Color(0.05, 0.45, 0.78, 1.0), "guide": Color(0.20, 0.62, 0.94, 1.0)},
				{"name": "Bright Gold", "symbol": "4", "color": Color(0.96, 0.88, 0.28, 1.0), "guide": Color(1.00, 0.92, 0.38, 1.0)},
			]
		"tritanopia":
			# Blue-Yellow safe: Charcoal, Deep Crimson, Bright Teal-Cyan, Crisp Silver-White
			return [
				{"name": "Charcoal", "symbol": "1", "color": Color(0.10, 0.08, 0.08, 1.0), "guide": Color(0.14, 0.11, 0.11, 1.0)},
				{"name": "Crimson", "symbol": "2", "color": Color(0.84, 0.16, 0.24, 1.0), "guide": Color(0.94, 0.24, 0.32, 1.0)},
				{"name": "Teal", "symbol": "3", "color": Color(0.06, 0.62, 0.64, 1.0), "guide": Color(0.16, 0.78, 0.80, 1.0)},
				{"name": "Moon Silver", "symbol": "4", "color": Color(0.95, 0.96, 0.98, 1.0), "guide": Color(0.98, 0.98, 1.00, 1.0)},
			]
		"high_contrast":
			# Maximum luminance + hue separation
			return [
				{"name": "Obsidian", "symbol": "1", "color": Color(0.05, 0.05, 0.06, 1.0), "guide": Color(0.08, 0.08, 0.10, 1.0)},
				{"name": "Magenta", "symbol": "2", "color": Color(0.88, 0.12, 0.56, 1.0), "guide": Color(0.96, 0.22, 0.66, 1.0)},
				{"name": "Electric Cyan", "symbol": "3", "color": Color(0.04, 0.68, 0.94, 1.0), "guide": Color(0.18, 0.82, 1.00, 1.0)},
				{"name": "Pure Yellow", "symbol": "4", "color": Color(1.00, 0.94, 0.22, 1.0), "guide": Color(1.00, 0.96, 0.36, 1.0)},
			]
		_:
			return [
				{"name": "Charcoal", "symbol": "", "color": Color(0.11, 0.08, 0.06, 1.0), "guide": Color(0.14, 0.10, 0.08, 1.0)},
				{"name": "Orasyon Crimson", "symbol": "", "color": Color(0.68, 0.14, 0.12, 1.0), "guide": Color(0.78, 0.16, 0.14, 1.0)},
				{"name": "Indigo Night", "symbol": "", "color": Color(0.13, 0.24, 0.52, 1.0), "guide": Color(0.18, 0.34, 0.70, 1.0)},
				{"name": "Sacred Gold", "symbol": "", "color": Color(1.00, 0.90, 0.52, 1.0), "guide": Color(0.98, 0.82, 0.26, 1.0)},
			]


## Semantic status colors for Pricing Lens, Money HUD, and positive/warning/negative badges.
## Keys: "positive" (discount/gain), "fair" (safe/gold), "risky" (warning), "danger" (overpriced/spend)
static func get_semantic_color(kind: String) -> Color:
	match get_mode():
		"deuteranopia":
			match kind:
				"positive": return Color("#56B4E9") # Sky blue
				"fair":     return Color("#F0E442") # Clear yellow
				"risky":    return Color("#E69F00") # Vivid amber
				"danger":   return Color("#D55E00") # Strong vermilion-orange
				_:          return Color("#F0E442")
		"tritanopia":
			match kind:
				"positive": return Color("#2EC4B6") # Crisp teal-cyan
				"fair":     return Color("#F8F4EC") # Bright ivory
				"risky":    return Color("#FF7597") # Bright rose
				"danger":   return Color("#E63946") # Deep crimson
				_:          return Color("#F8F4EC")
		"high_contrast":
			match kind:
				"positive": return Color("#38E8FF") # Electric cyan
				"fair":     return Color("#FFF05A") # Pure yellow
				"risky":    return Color("#FF9E2C") # Bright orange
				"danger":   return Color("#FF3B9A") # Vivid magenta
				_:          return Color("#FFF05A")
		_:
			match kind:
				"positive": return Color(0.50, 0.88, 0.58, 1.0) # Warm mint green
				"fair":     return Color(0.98, 0.87, 0.54, 1.0) # Antique gold
				"risky":    return Color(0.98, 0.64, 0.26, 1.0) # Amber
				"danger":   return Color(0.96, 0.42, 0.34, 1.0) # Coral red
				_:          return Color(0.98, 0.87, 0.54, 1.0)
