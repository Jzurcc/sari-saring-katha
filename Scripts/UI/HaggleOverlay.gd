class_name HaggleOverlay
extends CanvasLayer

## "Tawaran Card Duel" — Strategic, timed verbal haggle card duel!
## Plays "So What" minigame BGM while keeping the 3D customer framed behind a warm vignette.
## Read the customer's Stance (Skeptical / Impatient / Open), avoid Stale repeats, beat the
## per-turn selection timer, and parry Counter! rings to fill Convince to 100% before Patience runs out.

signal haggle_finished(accepted: bool, offered_step: int)

const Juice := preload("res://Scripts/UI/Minigames/MinigameJuice.gd")

const IC_SPARKLES: Texture2D = preload("res://Assets/ui/icons/sparkles.png")
const IC_FLAME: Texture2D = preload("res://Assets/ui/icons/flame.png")
const IC_TRUCK: Texture2D = preload("res://Assets/ui/icons/truck.png")
const IC_HEART: Texture2D = preload("res://Assets/ui/icons/heart-handshake.png")
const IC_PERCENT: Texture2D = preload("res://Assets/ui/icons/percent.png")
const IC_COFFEE: Texture2D = preload("res://Assets/ui/icons/coffee.png")
const IC_AWARD: Texture2D = preload("res://Assets/ui/icons/award.png")
const IC_CLOCK: Texture2D = preload("res://Assets/ui/icons/clock.png")

# Warm Espresso + Antique Gold + Cream palette
const COL_ESPRESSO := Color(0.075, 0.062, 0.052, 0.96)
const COL_CARD := Color(0.125, 0.104, 0.088, 0.97)
const COL_CARD_HOVER := Color(0.175, 0.145, 0.120, 0.99)
const COL_GOLD := Color(0.86, 0.67, 0.32, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.90, 0.58, 1.0)
const COL_GOLD_SOFT := Color(0.96, 0.85, 0.52, 1.0)
const COL_CREAM := Color(1.0, 0.95, 0.86, 1.0)
const COL_CREAM_MUTED := Color(0.84, 0.78, 0.69, 0.92)
const COL_OUTLINE := Color(0.04, 0.03, 0.025, 0.95)
const COL_GOOD := Color(0.48, 0.90, 0.58, 1.0)
const COL_WARN := Color(0.98, 0.68, 0.28, 1.0)
const COL_BAD := Color(0.96, 0.42, 0.34, 1.0)
const COL_TEAL := Color(0.46, 0.86, 0.94, 1.0)

const TURN_TIMER_BASE := 7.5
const COUNTER_DURATION := 1.25
const COUNTER_ZONE_MIN := 0.55
const COUNTER_ZONE_MAX := 0.96

const VIGNETTE_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.025, 0.020, 0.016, 0.84);
void fragment() {
	vec2 d = UV - vec2(0.5);
	float dist = length(d * vec2(1.12, 1.0));
	float vig = smoothstep(0.16, 0.78, dist);
	COLOR = vec4(tint.rgb, mix(0.26, tint.a, vig));
}
"""

## Customer tactical stances — rotate each turn to force real counterplay instead of spamming Bold.
const STANCES: Dictionary = {
	"skeptical": {
		"label": "Skeptical",
		"hint": "Weak to Pitch & Deal · Resists Charm",
		"color": COL_WARN,
		"weak": ["PITCH", "DEAL"],
		"resist": ["CHARM"],
		"punish_bold": false,
		"lines": [
			"Whoa, wait lang — prove this is worth that markup!",
			"Hmm, don't bola me ha — give me a real reason for that price.",
			"Teka, why is this steeper than down the street?",
		],
	},
	"impatient": {
		"label": "Impatient",
		"hint": "Weak to Calm & Deal · Punishes Bold (-1 Patience)",
		"color": COL_BAD,
		"weak": ["CALM", "DEAL"],
		"resist": [],
		"punish_bold": true,
		"lines": [
			"Make it quick, boss — I'm in a rush and that price stings!",
			"Hala, don't push me ha... cut me a break or keep it brief!",
			"Wait lang, my patience is wearing thin here!",
		],
	},
	"open": {
		"label": "Open",
		"hint": "Weak to Charm & Bold",
		"color": COL_GOOD,
		"weak": ["CHARM", "BOLD"],
		"resist": [],
		"punish_bold": false,
		"lines": [
			"Alright, alright, I'm listening — sell me on it, boss!",
			"Okay, you've got my ear... convince me it's worth it!",
			"Fair point so far — keep talking, suki!",
		],
	},
}
const STANCE_KEYS: Array[String] = ["skeptical", "impatient", "open"]

const COUNTER_RETORT_LINES: Array[String] = [
	"Hold on — isn't it cheaper down at the palengke?!",
	"Teka lang! The other store sells this for way less!",
	"Come on, boss, don't bola me on the markup!",
	"Whoa, easy there — that's still pretty steep ha!",
]

const TIMEOUT_LINES: Array[String] = [
	"Hello? Are we haggling or daydreaming, boss?",
	"Too slow, suki — I don't have all day!",
	"Naku, thinking too hard means it really IS overpriced!",
]

const WIN_LINES: Array[String] = [
	"Sige na nga, deal! You drive a good bargain.",
	"Alright, fair enough! Worth it naman — I'll take it.",
	"Okay, sold! Can't argue with that, boss.",
]

const LOSE_LINES: Array[String] = [
	"Ay nako, never mind na lang — too rich for me today!",
	"Sorry boss, pass muna ako at that price.",
]

const CARD_POOL_BOLD: Array[Dictionary] = [
	{
		"id": "hold_firm",
		"title": "Stand By Quality",
		"tag": "BOLD",
		"icon": IC_FLAME,
		"accent": COL_WARN,
		"convince": 28,
		"patience_delta": 0,
		"step_delta": 0,
		"triggers_counter": true,
		"desc": "+28% Convince\nTriggers a tight Counter! ring",
	},
	{
		"id": "prime_pick",
		"title": "Best on the Shelf",
		"tag": "BOLD",
		"icon": IC_AWARD,
		"accent": COL_WARN,
		"convince": 32,
		"patience_delta": 0,
		"step_delta": 0,
		"triggers_counter": true,
		"desc": "+32% Convince\nTriggers a tight Counter! ring",
	},
]

const CARD_POOL_BANTER: Array[Dictionary] = [
	{
		"id": "bola_talk",
		"title": "Bola-Bola Banter",
		"tag": "CHARM",
		"icon": IC_SPARKLES,
		"accent": COL_GOLD_BRIGHT,
		"convince": 26,
		"patience_delta": -1,
		"step_delta": 0,
		"triggers_counter": false,
		"desc": "+26% Convince\nCosts 1 Patience",
	},
	{
		"id": "fresh_stock",
		"title": "Fresh Delivery",
		"tag": "PITCH",
		"icon": IC_TRUCK,
		"accent": COL_TEAL,
		"convince": 25,
		"patience_delta": -1,
		"step_delta": 0,
		"triggers_counter": false,
		"desc": "+25% Convince\nCosts 1 Patience",
	},
	{
		"id": "goodwill",
		"title": "Neighborly Word",
		"tag": "CHARM",
		"icon": IC_HEART,
		"accent": COL_GOLD_BRIGHT,
		"convince": 27,
		"patience_delta": -1,
		"step_delta": 0,
		"triggers_counter": false,
		"desc": "+27% Convince\nCosts 1 Patience",
	},
]

const CARD_POOL_TACTICAL: Array[Dictionary] = [
	{
		"id": "small_tawad",
		"title": "Small Tawad",
		"tag": "DEAL",
		"icon": IC_PERCENT,
		"accent": COL_GOOD,
		"convince": 34,
		"patience_delta": 1,
		"step_delta": -1,
		"triggers_counter": false,
		"desc": "Lower price 1 step\n+34% Convince & +1 Patience",
	},
	{
		"id": "cool_chat",
		"title": "Easy Kumusta",
		"tag": "CALM",
		"icon": IC_COFFEE,
		"accent": COL_TEAL,
		"convince": 16,
		"patience_delta": 1,
		"step_delta": 0,
		"triggers_counter": false,
		"desc": "+16% Convince\nRestores +1 Patience",
	},
]


## Custom shrinking timing ring for the Counter! QTE prompt.
class CounterRingControl extends Control:
	var progress: float = 0.0
	var flash_col: Color = Color(1.0, 0.90, 0.58, 1.0)

	func _draw() -> void:
		var c := size * 0.5
		var target_r := 38.0
		var start_r := 86.0
		var cur_r := lerpf(start_r, 24.0, clampf(progress, 0.0, 1.0))

		draw_circle(c, target_r + 8.0, Color(0.05, 0.04, 0.035, 0.92))
		draw_arc(c, target_r, 0.0, TAU, 56, Color(0.48, 0.90, 0.58, 0.38), 11.0, true)
		draw_arc(c, target_r, 0.0, TAU, 56, COL_GOLD_BRIGHT, 2.6, true)

		var in_zone := (progress >= COUNTER_ZONE_MIN and progress <= COUNTER_ZONE_MAX)
		var ring_col := COL_GOOD if in_zone else flash_col
		draw_arc(c, cur_r, 0.0, TAU, 64, ring_col, 4.0 if in_zone else 3.0, true)


var _item_data: ItemData
var _customer_data: CustomerData
var _customer_node: Node3D
var _original_step: int = 3
var _offered_step: int = 3
var _tolerance: int = 0
var _resolved: bool = false
var _showing_intro: bool = false
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

# Duel state
var _convince: float = 0.0 # 0..100
var _display_convince: float = 0.0
var _max_patience: int = 3
var _patience: int = 3
var _power_scale: float = 1.0
var _current_stance: String = "skeptical"
var _last_played_tag: String = ""
var _current_hand: Array[Dictionary] = []
var _busy_animating: bool = false

# Turn timer state (scales with distance from -1 of effective base step)
var _turn_timer_duration: float = TURN_TIMER_BASE
var _turn_timer_active: bool = false
var _turn_time_left: float = TURN_TIMER_BASE
var _last_tick_bucket: int = -1

# Counter QTE state
var _counter_active: bool = false
var _counter_elapsed: float = 0.0

# UI nodes
var _root: Control
var _safe_root: MarginContainer
var _main_vbox: VBoxContainer
var _deck_fx_layer: Control
var _fade_rect: ColorRect
var _intro_panel: PanelContainer

var _convince_fill: Control
var _convince_pct_lbl: Label
var _patience_box: HBoxContainer
var _offer_price_lbl: Label
var _offer_step_lbl: Label
var _stance_pill: PanelContainer
var _stance_pill_style: StyleBoxFlat
var _stance_lbl: Label
var _stance_hint_lbl: Label
var _banter_panel: PanelContainer
var _banter_lbl: Label

var _timer_holder: HBoxContainer
var _timer_fill: Panel
var _timer_fill_style: StyleBoxFlat
var _timer_lbl: Label

var _counter_holder: VBoxContainer
var _counter_ring: CounterRingControl
var _hand_row: HBoxContainer
var _card_buttons: Array[Button] = []


static func compute_haggle_accept_chance(offered_step: int, tolerance: int, original_step: int = 3) -> float:
	var steps_dropped: int = original_step - offered_step
	if steps_dropped <= 0:
		return 0.05
	var eff_step: int = offered_step - tolerance
	var base: float = clampf(0.74 - float(eff_step) * 0.17, 0.05, 1.0)
	var shock_penalty: float = 0.19 if (original_step >= 5 and offered_step >= 0) else (0.09 if original_step == 4 else 0.0)
	var relief: float = StoryManager.get_storefront_price_relief() if is_instance_valid(StoryManager) else 0.0
	return clampf(base - shock_penalty + (relief * 0.65), 0.05, 0.95)


func setup(item_data: ItemData, customer_data: CustomerData, customer_node: Node3D = null) -> void:
	_item_data = item_data
	_customer_data = customer_data
	_customer_node = customer_node
	_original_step = item_data.current_step if item_data else 3
	_offered_step = _original_step
	_tolerance = 0
	if is_instance_valid(StoreEventManager) and item_data:
		_tolerance += StoreEventManager.get_item_tolerance_offset(item_data)
	if is_instance_valid(StoryManager):
		_tolerance += StoryManager.get_mayari_tolerance_offset()
	if customer_data != null and is_instance_valid(CharacterProgressionManager) and item_data:
		_tolerance += CharacterProgressionManager.get_reputation_tolerance_bonus(customer_data, item_data)

	# Scale difficulty by distance from -1 of the effective base step (eff_step = original_step - tolerance)
	var eff_step: int = _original_step - _tolerance
	var dist_from_neg1: int = maxi(1, eff_step - (-1))
	_convince = clampf(36.0 - float(dist_from_neg1 - 3) * 10.0, 0.0, 36.0)
	_max_patience = 3
	if is_instance_valid(StoryManager):
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_UNRUSHED_HOUR):
			_max_patience += 1
		if StoryManager.has_mayari_card(MayariCardRegistry.CARD_RESTLESS_CROWD):
			_max_patience = maxi(2, _max_patience - 1)
	_patience = _max_patience

	var relief: float = StoryManager.get_storefront_price_relief() if is_instance_valid(StoryManager) else 0.0
	_power_scale = clampf(1.18 - float(dist_from_neg1 - 3) * 0.12 + relief * 0.45, 0.66, 1.28)
	_turn_timer_duration = clampf(TURN_TIMER_BASE - float(maxi(0, dist_from_neg1 - 3)) * 0.9, 4.5, TURN_TIMER_BASE)
	_turn_time_left = _turn_timer_duration
	_display_convince = _convince
	_current_stance = "impatient" if dist_from_neg1 >= 5 else ("skeptical" if dist_from_neg1 >= 4 else "open")
	_last_played_tag = ""


func _ready() -> void:
	layer = 44
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("minigame_overlay_active")
	add_to_group("haggle_overlay_active")

	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if is_instance_valid(AudioManager):
		AudioManager.play_minigame_bgm("haggle")

	_build_ui()
	_refresh_top_hud(false)
	_apply_stance_ui(true)

	var already_seen: bool = is_instance_valid(CharacterProgressionManager) and bool(CharacterProgressionManager.get_world_flag("haggle_card_tutorial_seen", false))
	_showing_intro = Juice.are_minigame_tutorials_enabled() and not already_seen
	_intro_panel.visible = _showing_intro
	_safe_root.visible = not _showing_intro
	if _showing_intro:
		Juice.pop_panel_in(_intro_panel)
	else:
		_animate_open_and_deal()

	_fade_rect.color.a = 0.80
	var ftw := create_tween()
	ftw.tween_property(_fade_rect, "color:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if not _resolved and Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Smoothly keep camera looking toward the customer behind the vignette
	if not _resolved and is_instance_valid(_customer_node):
		var cam := get_viewport().get_camera_3d()
		if is_instance_valid(cam):
			var target_pos := _customer_node.global_position + Vector3(0.0, 1.32, 0.0)
			var marker := _customer_node.get_node_or_null("SpeechMarker") as Node3D
			if is_instance_valid(marker):
				target_pos = marker.global_position - Vector3(0.0, 0.24, 0.0)
			if cam.global_position.distance_squared_to(target_pos) > 0.01:
				var target_basis := cam.global_transform.looking_at(target_pos, Vector3.UP).basis
				cam.global_transform.basis = cam.global_transform.basis.slerp(target_basis, clampf(delta * 6.5, 0.0, 1.0))

	# Smooth Convince bar fill interpolation
	if absf(_display_convince - _convince) > 0.05:
		_display_convince = lerpf(_display_convince, _convince, clampf(delta * 11.0, 0.0, 1.0))
		if is_instance_valid(_convince_fill):
			_convince_fill.anchor_right = clampf(_display_convince / 100.0, 0.0, 1.0)

	# Per-turn card selection countdown timer
	if _turn_timer_active and not _busy_animating and not _counter_active and not _resolved and not _showing_intro:
		_turn_time_left = maxf(0.0, _turn_time_left - delta)
		_refresh_timer_ui()
		if _turn_time_left <= 2.0 and _turn_time_left > 0.0:
			var bucket := int(ceilf(_turn_time_left * 2.0))
			if bucket != _last_tick_bucket:
				_last_tick_bucket = bucket
				Juice.play_sfx("ui_hover", 1.25 if _turn_time_left <= 1.0 else 1.05, -8.0)
		if _turn_time_left <= 0.0:
			_on_turn_timed_out()

	# Active Counter! shrinking-ring QTE
	if _counter_active and not _resolved:
		_counter_elapsed += delta
		var prog := _counter_elapsed / COUNTER_DURATION
		if is_instance_valid(_counter_ring):
			_counter_ring.progress = prog
			_counter_ring.queue_redraw()
		if prog >= 1.0:
			_resolve_counter_qte(false)


func _input(event: InputEvent) -> void:
	if _resolved:
		return
	if event is InputEventMouseMotion:
		return

	if _showing_intro:
		if event is InputEventKey and event.pressed and not event.is_echo():
			if event.keycode in [KEY_F, KEY_SPACE, KEY_ENTER, KEY_1, KEY_2, KEY_3]:
				get_viewport().set_input_as_handled()
				_dismiss_intro()
			elif event.keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_decline_haggle()
		elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_dismiss_intro()
		return

	if _counter_active:
		if event is InputEventKey and event.pressed and not event.is_echo():
			if event.keycode in [KEY_SPACE, KEY_F, KEY_ENTER]:
				get_viewport().set_input_as_handled()
				var prog := _counter_elapsed / COUNTER_DURATION
				_resolve_counter_qte(prog >= COUNTER_ZONE_MIN and prog <= COUNTER_ZONE_MAX)
				return
			elif event.keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_decline_haggle()
				return
		elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			var prog := _counter_elapsed / COUNTER_DURATION
			_resolve_counter_qte(prog >= COUNTER_ZONE_MIN and prog <= COUNTER_ZONE_MAX)
			return

	if event is InputEventKey and event.pressed and not event.is_echo():
		match event.keycode:
			KEY_1:
				get_viewport().set_input_as_handled()
				_on_card_selected(0)
			KEY_2:
				get_viewport().set_input_as_handled()
				_on_card_selected(1)
			KEY_3:
				get_viewport().set_input_as_handled()
				_on_card_selected(2)
			KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_decline_haggle()


func _dismiss_intro() -> void:
	if not _showing_intro:
		return
	_showing_intro = false
	_intro_panel.visible = false
	_safe_root.visible = true
	if is_instance_valid(CharacterProgressionManager):
		CharacterProgressionManager.set_world_flag("haggle_card_tutorial_seen", true)
	Juice.play_sfx("tab_switch", 1.15)
	_animate_open_and_deal()


func _animate_open_and_deal() -> void:
	if is_instance_valid(_main_vbox):
		for i in range(_main_vbox.get_child_count()):
			var ch := _main_vbox.get_child(i)
			if ch is Control and ch.visible and ch != _hand_row:
				ch.modulate.a = 0.0
				var tw := create_tween()
				tw.tween_property(ch, "modulate:a", 1.0, 0.18).set_delay(0.035 * float(i)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_deal_new_hand(true)


func _roll_next_stance() -> void:
	var pool: Array[String] = []
	for k in STANCE_KEYS:
		if k != _current_stance:
			pool.append(k)
	_current_stance = pool[randi() % pool.size()]
	_apply_stance_ui(true)


func _apply_stance_ui(update_banter: bool = false) -> void:
	var st_info: Dictionary = STANCES.get(_current_stance, STANCES["skeptical"])
	var col: Color = st_info["color"]
	if is_instance_valid(_stance_lbl):
		_stance_lbl.text = str(st_info["label"])
		_stance_lbl.add_theme_color_override("font_color", col)
	if is_instance_valid(_stance_hint_lbl):
		_stance_hint_lbl.text = str(st_info["hint"])
	if _stance_pill_style:
		_stance_pill_style.border_color = Color(col.r, col.g, col.b, 0.85)
		_stance_pill_style.bg_color = Color(col.r * 0.16, col.g * 0.14, col.b * 0.12, 0.95)
	if update_banter:
		var lines: Array = st_info["lines"]
		_set_banter_line(str(lines[randi() % lines.size()]), COL_CREAM)


func _evaluate_card_modifier(c_def: Dictionary) -> Dictionary:
	var tag := str(c_def["tag"])
	var st_info: Dictionary = STANCES.get(_current_stance, STANCES["skeptical"])
	var weak_tags: Array = st_info["weak"]
	var resist_tags: Array = st_info["resist"]
	var mult := 1.0
	var extra_pat := 0
	var badge_txt := ""
	var badge_col := COL_CREAM_MUTED

	if tag in weak_tags:
		mult *= 1.40
		badge_txt = "✦ Effective"
		badge_col = COL_GOOD
	elif tag in resist_tags:
		mult *= 0.55
		badge_txt = "↓ Resisted"
		badge_col = COL_BAD

	if tag == "BOLD" and bool(st_info["punish_bold"]):
		extra_pat -= 1
		badge_txt = "⚠ Risky (-1 Pat)"
		badge_col = COL_BAD

	var is_stale := (_last_played_tag != "" and tag == _last_played_tag)
	if is_stale:
		mult *= 0.60
		badge_txt = "↺ Stale (×0.6)"
		badge_col = COL_WARN

	return {
		"mult": mult,
		"extra_pat": extra_pat,
		"is_stale": is_stale,
		"badge_txt": badge_txt,
		"badge_col": badge_col,
	}


func _scaled_convince(raw_val: int, mult: float = 1.0) -> int:
	return maxi(6, int(roundf(float(raw_val) * _power_scale * mult)))


func _start_turn_timer() -> void:
	_turn_time_left = _turn_timer_duration
	_last_tick_bucket = -1
	_turn_timer_active = true
	if is_instance_valid(_timer_holder):
		_timer_holder.visible = true
	_refresh_timer_ui()


func _stop_turn_timer() -> void:
	_turn_timer_active = false


func _refresh_timer_ui() -> void:
	var frac := clampf(_turn_time_left / maxf(0.1, _turn_timer_duration), 0.0, 1.0)
	var col := COL_BAD if _turn_time_left <= 1.8 else (COL_WARN if _turn_time_left <= 3.2 else COL_GOLD_BRIGHT)
	if is_instance_valid(_timer_fill):
		_timer_fill.anchor_right = frac
	if _timer_fill_style:
		_timer_fill_style.bg_color = col
	if is_instance_valid(_timer_lbl):
		_timer_lbl.text = "%.1fs" % _turn_time_left
		_timer_lbl.add_theme_color_override("font_color", col)


func _on_turn_timed_out() -> void:
	if _resolved or _busy_animating:
		return
	_stop_turn_timer()
	_busy_animating = true
	_patience = maxi(0, _patience - 1)
	Juice.play_sfx("error", 0.90, -0.5)
	_shake_control(_banter_panel)
	_set_banter_line(TIMEOUT_LINES[randi() % TIMEOUT_LINES.size()], COL_BAD)
	_refresh_top_hud(true)

	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree() or _resolved:
		return
	if _patience <= 0:
		_trigger_end_sequence(false)
		return
	_roll_next_stance()
	_deal_new_hand(true)


func _make_card_back_visual(card_sz: Vector2) -> PanelContainer:
	var back := PanelContainer.new()
	back.size = card_sz
	back.pivot_offset = card_sz * 0.5
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := UIStyle.create_flat_stylebox(Color(0.28, 0.11, 0.12, 0.98), 14, 10, 10)
	bs.border_color = COL_GOLD_BRIGHT
	bs.set_border_width_all(2)
	bs.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	bs.shadow_size = 12
	back.add_theme_stylebox_override("panel", bs)

	var inner := PanelContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ist := UIStyle.create_flat_stylebox(Color(0.16, 0.07, 0.08, 0.94), 8, 8, 8)
	ist.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.65)
	ist.set_border_width_all(1)
	inner.add_theme_stylebox_override("panel", ist)
	back.add_child(inner)

	var emblem := _make_label("◈", 42, COL_GOLD_BRIGHT, true, 2)
	emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emblem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_child(emblem)
	return back


func _deal_new_hand(animate: bool = true) -> void:
	_stop_turn_timer()
	_busy_animating = true
	_current_hand.clear()
	for ch in _hand_row.get_children():
		_hand_row.remove_child(ch)
		ch.queue_free()
	_card_buttons.clear()

	# Deal 1 Bold, 1 Banter (Charm or Pitch), and 1 Tactical (Small Tawad or Calm), then SHUFFLE order!
	var bold_card: Dictionary = CARD_POOL_BOLD[randi() % CARD_POOL_BOLD.size()].duplicate()
	var banter_card: Dictionary = CARD_POOL_BANTER[randi() % CARD_POOL_BANTER.size()].duplicate()
	var can_drop_step := (_offered_step > maxi(ItemData.MIN_STEP, 0))
	var tact_card: Dictionary
	if can_drop_step and (_patience <= 2 or _current_stance == "skeptical" or randf() < 0.55):
		tact_card = CARD_POOL_TACTICAL[0].duplicate() # Small Tawad
	else:
		tact_card = CARD_POOL_TACTICAL[1].duplicate() # Easy Kumusta

	_current_hand = [bold_card, banter_card, tact_card]
	_current_hand.shuffle()

	for i in range(_current_hand.size()):
		var c_def: Dictionary = _current_hand[i]
		var btn := _build_card_button(c_def, i)
		if animate:
			btn.modulate.a = 0.0
			btn.disabled = true
		_hand_row.add_child(btn)
		_card_buttons.append(btn)

	if not animate:
		_busy_animating = false
		_start_turn_timer()
		return

	_play_shuffle_and_deal_animation()


func _play_shuffle_and_deal_animation() -> void:
	# Wait 1 frame so _hand_row lays out the exact final global positions of each card slot
	await get_tree().process_frame
	if not is_inside_tree() or _resolved:
		return

	var vp := get_viewport().get_visible_rect().size
	var card_sz := Vector2(246, 186)
	var deck_origin := Vector2(vp.x * 0.5 - card_sz.x * 0.5, vp.y - card_sz.y * 0.65)

	# Clear any leftover FX backs
	for ch in _deck_fx_layer.get_children():
		_deck_fx_layer.remove_child(ch)
		ch.queue_free()

	# Phase A: Riffle shuffle 3 card backs at the deck stack
	var backs: Array[PanelContainer] = []
	for i in range(3):
		var bk := _make_card_back_visual(card_sz)
		bk.position = deck_origin + Vector2(float(i - 1) * 4.0, float(i - 1) * -3.0)
		bk.scale = Vector2(0.72, 0.72)
		bk.modulate.a = 0.0
		_deck_fx_layer.add_child(bk)
		backs.append(bk)

	var shuf_tw := create_tween()
	for i in range(backs.size()):
		shuf_tw.parallel().tween_property(backs[i], "modulate:a", 1.0, 0.10).set_trans(Tween.TRANS_SINE)
	# Riffle split out & snap back together
	shuf_tw.tween_callback(func(): Juice.play_sfx("tab_switch", 1.18, -5.0))
	shuf_tw.tween_property(backs[0], "position:x", deck_origin.x - 58.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	shuf_tw.parallel().tween_property(backs[0], "rotation_degrees", -9.0, 0.10)
	shuf_tw.parallel().tween_property(backs[2], "position:x", deck_origin.x + 58.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	shuf_tw.parallel().tween_property(backs[2], "rotation_degrees", 9.0, 0.10)
	shuf_tw.tween_callback(func(): Juice.play_sfx("tab_switch", 1.28, -5.0))
	shuf_tw.tween_property(backs[0], "position:x", deck_origin.x, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	shuf_tw.parallel().tween_property(backs[0], "rotation_degrees", 0.0, 0.10)
	shuf_tw.parallel().tween_property(backs[2], "position:x", deck_origin.x, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	shuf_tw.parallel().tween_property(backs[2], "rotation_degrees", 0.0, 0.10)
	await shuf_tw.finished
	if not is_inside_tree() or _resolved:
		return

	# Phase B: Deal each card back from the deck into its exact hand slot & flip into the real card!
	var last_deal_tw: Tween = null
	for i in range(mini(backs.size(), _card_buttons.size())):
		var bk := backs[i]
		var target_btn := _card_buttons[i]
		if not is_instance_valid(bk) or not is_instance_valid(target_btn):
			continue
		var target_pos := target_btn.get_global_rect().position
		var delay := 0.08 * float(i)
		var tilt := -8.0 if i == 0 else (8.0 if i == 2 else 0.0)
		bk.rotation_degrees = tilt
		target_btn.pivot_offset = target_btn.size * 0.5
		target_btn.scale = Vector2(0.02, 1.0)
		target_btn.modulate.a = 0.0

		var dtw := create_tween()
		if delay > 0.0:
			dtw.tween_interval(delay)
		dtw.tween_callback(func(): Juice.play_sfx("tab_switch", 1.02 + float(i) * 0.08, -3.0))
		dtw.tween_property(bk, "position", target_pos, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		dtw.parallel().tween_property(bk, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		dtw.parallel().tween_property(bk, "rotation_degrees", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		# Flip reveal: back shrinks X -> 0, real button unfolds X -> 1
		dtw.tween_property(bk, "scale:x", 0.02, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		dtw.tween_callback(func():
			if is_instance_valid(bk):
				bk.queue_free()
			if is_instance_valid(target_btn):
				target_btn.modulate.a = 1.0
				target_btn.disabled = false
		)
		dtw.tween_property(target_btn, "scale:x", 1.0, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		last_deal_tw = dtw

	if last_deal_tw:
		await last_deal_tw.finished
	if not is_inside_tree() or _resolved:
		return

	_busy_animating = false
	_start_turn_timer()


func _on_card_selected(idx: int) -> void:
	if _resolved or _busy_animating or _counter_active or idx < 0 or idx >= _current_hand.size():
		return
	_stop_turn_timer()
	_busy_animating = true
	var c_def: Dictionary = _current_hand[idx]
	var tag := str(c_def["tag"])
	var eval := _evaluate_card_modifier(c_def)
	var gain := _scaled_convince(int(c_def["convince"]), float(eval["mult"]))
	var pat_delta := int(c_def["patience_delta"]) + int(eval["extra_pat"])
	var step_delta := int(c_def["step_delta"])
	var wants_counter := bool(c_def["triggers_counter"])

	_last_played_tag = tag
	Juice.play_sfx("tab_switch", 1.12, -1.0)

	# Punchy slam animation on the played card
	if idx < _card_buttons.size() and is_instance_valid(_card_buttons[idx]):
		var played_btn := _card_buttons[idx]
		played_btn.pivot_offset = played_btn.size * 0.5
		var ptw := create_tween().set_parallel(true)
		ptw.tween_property(played_btn, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ptw.tween_property(played_btn, "position:y", played_btn.position.y - 18.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if step_delta != 0:
		_offered_step = clampi(_offered_step + step_delta, ItemData.MIN_STEP, _original_step)
		Juice.play_sfx("price_change", 1.05, -2.0)

	_convince = clampf(_convince + float(gain), 0.0, 100.0)
	if pat_delta != 0:
		_patience = clampi(_patience + pat_delta, 0, _max_patience)
		if int(eval["extra_pat"]) < 0:
			_shake_control(_banter_panel)
			Juice.play_sfx("error", 0.96, -2.0)

	_refresh_top_hud(true)

	await get_tree().create_timer(0.20).timeout
	if not is_inside_tree() or _resolved:
		return

	if _convince >= 99.9:
		_trigger_end_sequence(true)
		return

	if _patience <= 0:
		_trigger_end_sequence(false)
		return

	if wants_counter:
		_start_counter_qte()
		return

	# Show contextual reaction based on stance/stale match, then shift stance & shuffle next hand
	if bool(eval["is_stale"]):
		_set_banter_line("You just used that line, boss! Try something else!", COL_WARN)
	elif float(eval["mult"]) > 1.1:
		_set_banter_line("Whoa — okay, now THAT actually makes sense!", COL_GOOD)
	elif float(eval["mult"]) < 0.8:
		_set_banter_line("Nice try, suki, but that didn't really land.", COL_WARN)
	else:
		_set_banter_line("Hmm... fair point, pero convince me a little more.", COL_CREAM)

	await get_tree().create_timer(0.32).timeout
	if not is_inside_tree() or _resolved:
		return
	_roll_next_stance()
	_deal_new_hand(true)


func _start_counter_qte() -> void:
	_counter_active = true
	_counter_elapsed = 0.0
	_hand_row.visible = false
	if is_instance_valid(_timer_holder):
		_timer_holder.visible = false
	_counter_holder.visible = true
	_counter_holder.modulate.a = 0.0
	_counter_holder.scale = Vector2(0.88, 0.88)
	_counter_holder.pivot_offset = _counter_holder.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_counter_holder, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_counter_holder, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_set_banter_line(COUNTER_RETORT_LINES[randi() % COUNTER_RETORT_LINES.size()], COL_WARN)
	Juice.play_sfx("interact", 1.25, -2.0)


func _resolve_counter_qte(success: bool) -> void:
	if not _counter_active or _resolved:
		return
	_counter_active = false
	_counter_holder.visible = false
	_hand_row.visible = true

	if success:
		Juice.play_sfx("pickup", 1.24, 0.0)
		_convince = clampf(_convince + 12.0, 0.0, 100.0)
		_set_banter_line("Sharp comeback! Alright, you got me there...", COL_GOOD)
	else:
		Juice.play_sfx("error", 0.90, -0.5)
		_patience = maxi(0, _patience - 1)
		_shake_control(_banter_panel)
		_set_banter_line("See? Couldn't even answer that — still feels steep!", COL_BAD)

	_refresh_top_hud(true)

	if _convince >= 99.9:
		_trigger_end_sequence(true)
		return
	if _patience <= 0:
		_trigger_end_sequence(false)
		return

	await get_tree().create_timer(0.28).timeout
	if not is_inside_tree() or _resolved:
		return
	_roll_next_stance()
	_deal_new_hand(true)


func _trigger_end_sequence(won: bool) -> void:
	if _resolved:
		return
	_resolved = true
	_stop_turn_timer()
	_counter_active = false
	_counter_holder.visible = false
	if is_instance_valid(_timer_holder):
		_timer_holder.visible = false
	for btn in _card_buttons:
		if is_instance_valid(btn):
			btn.disabled = true

	if won:
		Juice.play_sfx("pickup", 1.20, 0.8)
		_set_banter_line(WIN_LINES[randi() % WIN_LINES.size()], COL_GOOD)
	else:
		Juice.play_sfx("error", 0.88, 0.4)
		_set_banter_line(LOSE_LINES[randi() % LOSE_LINES.size()], COL_BAD)
		_shake_control(_banter_panel)

	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return
	_finish(won, _offered_step if won else _original_step)


func _decline_haggle() -> void:
	if _resolved:
		return
	_resolved = true
	_stop_turn_timer()
	Juice.play_sfx("drop", 0.92, -2.0)
	_finish(false, _original_step)


func _finish(accepted: bool, offered_step: int) -> void:
	if is_instance_valid(AudioManager):
		AudioManager.stop_bgm_override()
	Input.mouse_mode = _prev_mouse_mode
	if is_in_group("minigame_overlay_active"):
		remove_from_group("minigame_overlay_active")
	if is_in_group("haggle_overlay_active"):
		remove_from_group("haggle_overlay_active")
	haggle_finished.emit(accepted, offered_step)
	queue_free()


# ── Visual Updates & Helpers ─────────────────────────────────────────────────

func _set_banter_line(txt: String, col: Color = COL_CREAM) -> void:
	if not is_instance_valid(_banter_lbl):
		return
	_banter_lbl.text = "\"%s\"" % txt
	_banter_lbl.add_theme_color_override("font_color", col)
	if is_instance_valid(_banter_panel):
		_banter_panel.pivot_offset = _banter_panel.size * 0.5
		_banter_panel.scale = Vector2(0.96, 0.96)
		var tw := create_tween()
		tw.tween_property(_banter_panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shake_control(ctrl: Control) -> void:
	if not is_instance_valid(ctrl):
		return
	var tw := create_tween()
	tw.tween_property(ctrl, "position:x", -10.0, 0.045).as_relative().set_trans(Tween.TRANS_SINE)
	tw.tween_property(ctrl, "position:x", 18.0, 0.055).as_relative().set_trans(Tween.TRANS_SINE)
	tw.tween_property(ctrl, "position:x", -12.0, 0.055).as_relative().set_trans(Tween.TRANS_SINE)
	tw.tween_property(ctrl, "position:x", 4.0, 0.045).as_relative().set_trans(Tween.TRANS_SINE)


func _refresh_top_hud(animate_pop: bool = false) -> void:
	var pct := int(roundf(_convince))
	if is_instance_valid(_convince_pct_lbl):
		_convince_pct_lbl.text = "%d%%" % pct
		var pcol := COL_GOOD if pct >= 75 else (COL_GOLD_BRIGHT if pct >= 40 else COL_CREAM)
		_convince_pct_lbl.add_theme_color_override("font_color", pcol)
		if animate_pop:
			_convince_pct_lbl.pivot_offset = _convince_pct_lbl.size * 0.5
			_convince_pct_lbl.scale = Vector2(1.18, 1.18)
			var tw := create_tween()
			tw.tween_property(_convince_pct_lbl, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if is_instance_valid(_patience_box):
		for ch in _patience_box.get_children():
			_patience_box.remove_child(ch)
			ch.queue_free()
		for i in range(_max_patience):
			var filled := (i < _patience)
			var pip := Label.new()
			pip.text = "◆" if filled else "◇"
			pip.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
			pip.add_theme_font_size_override("font_size", 22)
			var p_col := (COL_BAD if _patience == 1 else COL_GOLD_BRIGHT) if filled else Color(0.45, 0.40, 0.35, 0.55)
			pip.add_theme_color_override("font_color", p_col)
			_patience_box.add_child(pip)

	if _item_data != null and is_instance_valid(_offer_price_lbl):
		var cur_price := _item_data.get_price_for_step(_offered_step)
		_offer_price_lbl.text = "₱%.2f" % cur_price
		var step_sign := "+" if _offered_step > 0 else ""
		_offer_step_lbl.text = "Offer (%s%d step)" % [step_sign, _offered_step]
		_offer_step_lbl.add_theme_color_override("font_color", UIStyle.get_price_step_color(_offered_step, _tolerance))


func _make_label(txt: String, sz: int, col: Color, semibold: bool = false, outline_sz: int = 3) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD if semibold else UIStyle.FONT_FREDOKA_REG)
	lbl.add_theme_font_size_override("font_size", sz)
	lbl.add_theme_color_override("font_color", col)
	if outline_sz > 0:
		lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
		lbl.add_theme_constant_override("outline_size", outline_sz)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


# ── UI Construction (5% Safe Zone, 3-Zone Layout) ────────────────────────────

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.offset_left = -24
	vig.offset_top = -24
	vig.offset_right = 24
	vig.offset_bottom = 24
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	vig.material = mat
	_root.add_child(vig)

	# 5% Title-Safe Container
	_safe_root = MarginContainer.new()
	_safe_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_safe_root.add_theme_constant_override("margin_left", 72)
	_safe_root.add_theme_constant_override("margin_right", 72)
	_safe_root.add_theme_constant_override("margin_top", 42)
	_safe_root.add_theme_constant_override("margin_bottom", 34)
	_root.add_child(_safe_root)

	_main_vbox = VBoxContainer.new()
	_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_vbox.add_theme_constant_override("separation", 12)
	_safe_root.add_child(_main_vbox)

	# ─── ZONE 1: TOP STATUS BAR ───
	_main_vbox.add_child(_build_top_status_bar())

	# Middle Spacer (keeps center of screen open so you see the 3D customer!)
	var mid_spacer := Control.new()
	mid_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_vbox.add_child(mid_spacer)

	# ─── ZONE 2: STANCE TELEGRAPH + BANTER BUBBLE + COUNTER! RING ───
	var center_stack := VBoxContainer.new()
	center_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	center_stack.add_theme_constant_override("separation", 8)
	center_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_vbox.add_child(center_stack)

	# Customer Stance Pill (communicates counterplay each turn)
	_stance_pill = PanelContainer.new()
	_stance_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stance_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stance_pill_style = UIStyle.create_flat_stylebox(Color(0.14, 0.11, 0.08, 0.95), 9, 16, 6)
	_stance_pill_style.border_color = COL_WARN
	_stance_pill_style.set_border_width_all(1)
	_stance_pill.add_theme_stylebox_override("panel", _stance_pill_style)
	center_stack.add_child(_stance_pill)

	var st_row := HBoxContainer.new()
	st_row.add_theme_constant_override("separation", 10)
	st_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stance_pill.add_child(st_row)

	_stance_lbl = _make_label("Skeptical", 16, COL_WARN, true, 2)
	st_row.add_child(_stance_lbl)
	st_row.add_child(_make_label("·", 16, COL_CREAM_MUTED, true, 0))
	_stance_hint_lbl = _make_label("Weak to Pitch & Deal · Resists Charm", 15, COL_CREAM, false, 2)
	st_row.add_child(_stance_hint_lbl)

	_banter_panel = PanelContainer.new()
	_banter_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_banter_panel.custom_minimum_size = Vector2(560, 0)
	_banter_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bst := UIStyle.create_flat_stylebox(COL_ESPRESSO, 14, 24, 12)
	bst.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.78)
	bst.set_border_width_all(2)
	bst.shadow_size = 12
	bst.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	_banter_panel.add_theme_stylebox_override("panel", bst)
	center_stack.add_child(_banter_panel)

	_banter_lbl = _make_label("", 20, COL_CREAM, true, 3)
	_banter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banter_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banter_panel.add_child(_banter_lbl)

	# Shrinking-ring Counter! QTE prompt
	_counter_holder = VBoxContainer.new()
	_counter_holder.visible = false
	_counter_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	_counter_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_counter_holder.add_theme_constant_override("separation", 6)
	_counter_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_stack.add_child(_counter_holder)

	_counter_ring = CounterRingControl.new()
	_counter_ring.custom_minimum_size = Vector2(180, 180)
	_counter_ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_counter_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counter_holder.add_child(_counter_ring)

	var ring_center_lbl := _make_label("COUNTER!", 20, COL_GOLD_BRIGHT, true, 4)
	ring_center_lbl.set_anchors_preset(Control.PRESET_CENTER)
	ring_center_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ring_center_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ring_center_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	_counter_ring.add_child(ring_center_lbl)

	var counter_hint := _make_label("Press [Space] or Click when the ring hits the gold circle!", 17, COL_GOOD, true, 4)
	counter_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter_holder.add_child(counter_hint)

	# ─── ZONE 3: TURN TIMER BAR + 3-CARD HAND + INPUT LEGEND ───
	_timer_holder = HBoxContainer.new()
	_timer_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	_timer_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_timer_holder.add_theme_constant_override("separation", 10)
	_timer_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_holder.visible = false
	_main_vbox.add_child(_timer_holder)

	var clk_ico := TextureRect.new()
	clk_ico.texture = IC_CLOCK
	clk_ico.custom_minimum_size = Vector2(18, 18)
	clk_ico.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clk_ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	clk_ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	clk_ico.modulate = COL_GOLD_BRIGHT
	clk_ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_holder.add_child(clk_ico)

	var t_track := Panel.new()
	t_track.custom_minimum_size = Vector2(460, 10)
	t_track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tt_st := UIStyle.create_flat_stylebox(Color(0.05, 0.04, 0.035, 0.92), 5, 0, 0)
	tt_st.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.55)
	tt_st.set_border_width_all(1)
	t_track.add_theme_stylebox_override("panel", tt_st)
	_timer_holder.add_child(t_track)

	_timer_fill = Panel.new()
	_timer_fill.anchor_left = 0.0
	_timer_fill.anchor_top = 0.0
	_timer_fill.anchor_bottom = 1.0
	_timer_fill.anchor_right = 1.0
	_timer_fill.offset_left = 1
	_timer_fill.offset_top = 1
	_timer_fill.offset_right = -1
	_timer_fill.offset_bottom = -1
	_timer_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_fill_style = UIStyle.create_flat_stylebox(COL_GOLD_BRIGHT, 4, 0, 0)
	_timer_fill.add_theme_stylebox_override("panel", _timer_fill_style)
	t_track.add_child(_timer_fill)

	_timer_lbl = _make_label("6.5s", 16, COL_GOLD_BRIGHT, true, 2)
	_timer_lbl.custom_minimum_size = Vector2(44, 0)
	_timer_holder.add_child(_timer_lbl)

	_hand_row = HBoxContainer.new()
	_hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_row.add_theme_constant_override("separation", 18)
	_main_vbox.add_child(_hand_row)

	var legend := HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 24)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_child(_make_keycap_hint("1 / 2 / 3", "Play Card"))
	legend.add_child(_make_keycap_hint("Click", "Select Card"))
	legend.add_child(_make_keycap_hint("Esc", "Let Them Go"))
	_main_vbox.add_child(legend)

	# Fullscreen overlay layer for shuffle & deal flying card backs
	_deck_fx_layer = Control.new()
	_deck_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deck_fx_layer.z_index = 25
	_deck_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_deck_fx_layer)

	_build_intro_modal()

	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0.015, 0.012, 0.010, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)


func _build_top_status_bar() -> PanelContainer:
	var bar_panel := PanelContainer.new()
	bar_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar_panel.custom_minimum_size = Vector2(880, 0)
	var st := UIStyle.create_flat_stylebox(COL_ESPRESSO, 14, 22, 14)
	st.border_color = COL_GOLD
	st.set_border_width_all(2)
	st.shadow_size = 14
	st.shadow_color = Color(0.0, 0.0, 0.0, 0.60)
	bar_panel.add_theme_stylebox_override("panel", st)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_panel.add_child(row)

	# Left: Portrait + Name + Patience Pips
	var cust_box := HBoxContainer.new()
	cust_box.add_theme_constant_override("separation", 12)
	row.add_child(cust_box)

	var cname := (_customer_data.character_name if (_customer_data != null and _customer_data.character_name != "") else "Neighbor")
	var ptex := UIStyle.get_customer_portrait(cname)
	if ptex != null:
		var pframe := PanelContainer.new()
		var pst := UIStyle.create_flat_stylebox(Color(0.14, 0.11, 0.09, 0.96), 999, 3, 3)
		pst.border_color = COL_GOLD
		pst.set_border_width_all(2)
		pframe.add_theme_stylebox_override("panel", pst)
		var prect := TextureRect.new()
		prect.texture = ptex
		prect.custom_minimum_size = Vector2(52, 52)
		prect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		prect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pframe.add_child(prect)
		cust_box.add_child(pframe)

	var cust_v := VBoxContainer.new()
	cust_v.alignment = BoxContainer.ALIGNMENT_CENTER
	cust_v.add_theme_constant_override("separation", 2)
	cust_box.add_child(cust_v)

	cust_v.add_child(_make_label(cname, 20, COL_CREAM, true, 2))

	var pat_row := HBoxContainer.new()
	pat_row.add_theme_constant_override("separation", 6)
	cust_v.add_child(pat_row)
	var pat_lbl := _make_label("Patience:", 15, COL_CREAM_MUTED, false, 2)
	pat_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pat_row.add_child(pat_lbl)
	_patience_box = HBoxContainer.new()
	_patience_box.add_theme_constant_override("separation", 4)
	pat_row.add_child(_patience_box)

	# Center: Convince Meter (0% -> 100%)
	var meter_v := VBoxContainer.new()
	meter_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter_v.alignment = BoxContainer.ALIGNMENT_CENTER
	meter_v.add_theme_constant_override("separation", 6)
	row.add_child(meter_v)

	var meter_hdr := HBoxContainer.new()
	meter_v.add_child(meter_hdr)
	var iname := _item_data.item_name if _item_data else "Item"
	var mtitle := _make_label("Convince on %s" % iname, 17, COL_GOLD_SOFT, true, 2)
	mtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter_hdr.add_child(mtitle)
	_convince_pct_lbl = _make_label("0%", 20, COL_CREAM, true, 3)
	meter_hdr.add_child(_convince_pct_lbl)

	var track := Panel.new()
	track.custom_minimum_size = Vector2(320, 20)
	var tst := UIStyle.create_flat_stylebox(Color(0.035, 0.030, 0.026, 0.98), 8, 0, 0)
	tst.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.72)
	tst.set_border_width_all(1)
	track.add_theme_stylebox_override("panel", tst)
	meter_v.add_child(track)

	var fill_panel := Panel.new()
	fill_panel.anchor_left = 0.0
	fill_panel.anchor_top = 0.0
	fill_panel.anchor_bottom = 1.0
	fill_panel.anchor_right = clampf(_convince / 100.0, 0.0, 1.0)
	fill_panel.offset_left = 2
	fill_panel.offset_top = 2
	fill_panel.offset_right = -2
	fill_panel.offset_bottom = -2
	var fst := UIStyle.create_flat_stylebox(COL_GOLD_BRIGHT, 6, 0, 0)
	fill_panel.add_theme_stylebox_override("panel", fst)
	track.add_child(fill_panel)
	_convince_fill = fill_panel

	# Right: Current Offer Readout
	var offer_v := VBoxContainer.new()
	offer_v.alignment = BoxContainer.ALIGNMENT_CENTER
	offer_v.add_theme_constant_override("separation", 1)
	row.add_child(offer_v)

	_offer_price_lbl = _make_label("₱0.00", 28, COL_GOLD_BRIGHT, true, 3)
	_offer_price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	offer_v.add_child(_offer_price_lbl)

	_offer_step_lbl = _make_label("Offer (+3 step)", 14, COL_CREAM_MUTED, true, 2)
	_offer_step_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	offer_v.add_child(_offer_step_lbl)

	return bar_panel


func _build_card_button(c_def: Dictionary, idx: int) -> Button:
	var accent: Color = c_def["accent"]
	var eval := _evaluate_card_modifier(c_def)
	var eff_gain := _scaled_convince(int(c_def["convince"]), float(eval["mult"]))
	var desc_txt := str(c_def["desc"]).replace("+%d%%" % int(c_def["convince"]), "+%d%%" % eff_gain)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(246, 186)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal_st := UIStyle.create_flat_stylebox(COL_CARD, 14, 16, 14)
	normal_st.border_color = Color(accent.r, accent.g, accent.b, 0.72)
	normal_st.set_border_width_all(2)
	normal_st.border_width_top = 4
	normal_st.shadow_size = 10
	normal_st.shadow_color = Color(0.0, 0.0, 0.0, 0.55)

	var hover_st := normal_st.duplicate() as StyleBoxFlat
	hover_st.bg_color = COL_CARD_HOVER
	hover_st.border_color = COL_GOLD_BRIGHT
	hover_st.shadow_size = 16

	btn.add_theme_stylebox_override("normal", normal_st)
	btn.add_theme_stylebox_override("hover", hover_st)
	btn.add_theme_stylebox_override("pressed", hover_st)
	btn.add_theme_stylebox_override("disabled", normal_st)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 16
	vb.offset_right = -16
	vb.offset_top = 12
	vb.offset_bottom = -12
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)

	# Card Top Row: [1/2/3] Keycap + Archetype Tag + Icon
	var top_r := HBoxContainer.new()
	top_r.add_theme_constant_override("separation", 8)
	top_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top_r)

	var kcap := PanelContainer.new()
	kcap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kst := UIStyle.create_flat_stylebox(Color(0.06, 0.052, 0.046, 0.94), 6, 8, 2)
	kst.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.85)
	kst.set_border_width_all(1)
	kcap.add_theme_stylebox_override("panel", kst)
	kcap.add_child(_make_label(str(idx + 1), 14, COL_GOLD_BRIGHT, true, 0))
	top_r.add_child(kcap)

	var tag_lbl := _make_label(str(c_def["tag"]), 14, accent, true, 2)
	tag_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_r.add_child(tag_lbl)

	var ico := TextureRect.new()
	ico.texture = c_def["icon"]
	ico.custom_minimum_size = Vector2(22, 22)
	ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ico.modulate = accent
	ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_r.add_child(ico)

	# Card Title
	var t_lbl := _make_label(str(c_def["title"]), 20, COL_CREAM, true, 3)
	vb.add_child(t_lbl)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(accent.r, accent.g, accent.b, 0.28)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(sep)

	# Card Effect Text
	var d_lbl := _make_label(desc_txt, 15, COL_CREAM_MUTED, false, 2)
	d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(d_lbl)

	# Tactical Stance / Stale indicator chip along card footer
	var badge_txt := str(eval["badge_txt"])
	if badge_txt != "":
		var b_lbl := _make_label(badge_txt, 14, eval["badge_col"], true, 2)
		vb.add_child(b_lbl)

	btn.mouse_entered.connect(func():
		if _busy_animating or _resolved:
			return
		Juice.play_sfx("ui_hover", 1.08, -5.0)
		btn.pivot_offset = btn.size * 0.5
		var htw := create_tween()
		htw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		if _busy_animating or _resolved:
			return
		btn.pivot_offset = btn.size * 0.5
		var htw := create_tween()
		htw.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
	btn.pressed.connect(_on_card_selected.bind(idx))
	return btn


func _make_keycap_hint(key_text: String, action_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cap := PanelContainer.new()
	cap.custom_minimum_size = Vector2(28, 28)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cap_style := UIStyle.create_flat_stylebox(Color(0.06, 0.052, 0.046, 0.94), 6, 8, 3)
	cap_style.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.88)
	cap_style.set_border_width_all(1)
	cap.add_theme_stylebox_override("panel", cap_style)
	row.add_child(cap)

	cap.add_child(_make_label(key_text, 14, COL_GOLD_BRIGHT, true, 0))
	var albl := _make_label(action_text, 15, COL_CREAM_MUTED, false, 3)
	albl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(albl)
	return row


func _build_intro_modal() -> void:
	_intro_panel = PanelContainer.new()
	_intro_panel.set_anchors_preset(Control.PRESET_CENTER)
	_intro_panel.custom_minimum_size = Vector2(580, 290)
	_intro_panel.offset_left = -290
	_intro_panel.offset_right = 290
	_intro_panel.offset_top = -145
	_intro_panel.offset_bottom = 145
	var istyle := UIStyle.create_flat_stylebox(COL_ESPRESSO, 14, 28, 24)
	istyle.border_color = COL_GOLD
	istyle.set_border_width_all(2)
	istyle.shadow_size = 18
	istyle.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	_intro_panel.add_theme_stylebox_override("panel", istyle)
	_intro_panel.visible = false
	_root.add_child(_intro_panel)

	var iv := VBoxContainer.new()
	iv.alignment = BoxContainer.ALIGNMENT_CENTER
	iv.add_theme_constant_override("separation", 14)
	_intro_panel.add_child(iv)

	var ititle := _make_label("Tawaran Card Duel", 28, COL_GOLD_BRIGHT, true, 3)
	ititle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iv.add_child(ititle)

	var idesc := _make_label(
		"Read your neighbor's Stance each turn and play a card ([1]/[2]/[3] or Click) before the timer runs out!\n\n• Match their weakness for bonus Convince — repeating the same tag goes Stale.\n• Bold cards provoke a tight Counter! ring — time [Space] or Click to parry!",
		17,
		COL_CREAM,
		false,
		2
	)
	idesc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	idesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(idesc)

	var ihint := _make_label("Press [Space] or Click to start", 17, COL_GOLD_SOFT, true, 2)
	ihint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iv.add_child(ihint)
