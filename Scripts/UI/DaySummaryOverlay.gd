class_name DaySummaryOverlay
extends CanvasLayer

## End-of-day Nightly Ledger Summary.
## Leads the player's eyes sequentially through:
##   1. Cashflow & Ledger (all channels shown even when ₱0.00, big numbers, one-by-one reveal)
##   2. Store Performance (one-by-one reveal + rounded animated Player XP bar)
##   3. Bottom Row (Larger Diamond Condition Medallions with hover Event Cards at cursor + Specific Highlights)
##   4. Slam-down Daily Rank Stamp positioned cleanly to the left of the Cashflow numbers.
## Clicking or pressing Space skips straight to the completed state.

signal completed(grade: String, quip: String)

const MAYARI_SPRITE_PATH := "res://Assets/characters/sprites/ReynaMayariUI.png"
const HadesEmblem = preload("res://Scripts/UI/HadesDiamondEmblem.gd")

const COL_ESPRESSO_DEEP := Color(0.055, 0.048, 0.042, 0.96)
const COL_CARD_BG := Color(0.085, 0.074, 0.064, 0.95)
const COL_WHITE_HDR := Color(0.98, 0.97, 0.94, 1.0)
const COL_GOLD := Color(0.835, 0.624, 0.278, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.875, 0.56, 1.0)
const COL_GOLD_LABEL := Color(0.98, 0.84, 0.48, 1.0)
const COL_GOLD_ZERO := Color(0.86, 0.72, 0.44, 0.68)
const COL_CREAM := Color(1.0, 0.935, 0.82, 1.0)
const COL_CREAM_MUTED := Color(0.92, 0.84, 0.68, 0.88)
const COL_BOLD_CREAM := "#FFF6E5"
const COL_BROWN_BORDER := Color(0.482, 0.306, 0.102, 0.9)
const COL_POS := Color(0.56, 0.94, 0.52, 1.0)
const COL_NEG := Color(0.98, 0.50, 0.46, 1.0)

const SHORT_MONTHS: Array[String] = [
	"Jan", "Feb", "Mar", "Apr", "May", "Jun",
	"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
]

var _bold_font: FontVariation
var _root: Control
var _backdrop: ColorRect
var _banner: Control
var _skip_hint_pill: PanelContainer
var _frame: PanelContainer
var _mayari_portrait: TextureRect
var _close_btn: Button
var _stamp_panel: PanelContainer
var _xp_bar_fill: Panel
var _xp_bar_track: Panel

var _cashflow_card: PanelContainer
var _cashflow_sep: ColorRect
var _perf_card: PanelContainer
var _perf_foot: Label
var _bottom_row: HBoxContainer
var _hover_card_holder: Control
var _active_hover_card: PanelContainer

var _stats: Dictionary = {}
var _day_number: int = 1
var _show_mayari: bool = true
var _grade: String = "B"
var _grade_title: String = "Mahinahon"
var _grade_col: Color = COL_GOLD_BRIGHT
var _quip: String = ""
var _highlights: Array[String] = []

var _skip_requested: bool = false
var _last_skip_tap_msec: int = -10000
var _tally_finished: bool = false
var _closing: bool = false

# Sequential animation queues
var _cashflow_entries: Array[Dictionary] = []
var _net_entry: Dictionary = {}
var _perf_entries: Array[Dictionary] = []
var _condition_nodes: Array[Control] = []
var _highlight_nodes: Array[Control] = []


func setup(day_num: int, daily_stats: Dictionary, _show_mayari_arg: bool = false) -> void:
	_day_number = day_num
	_stats = daily_stats.duplicate(true)
	_show_mayari = false
	_compute_grade_and_highlights()


func _ready() -> void:
	layer = 62
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("day_summary_overlay_active")
	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_FREDOKA_SEMIBOLD
	_build_ui()
	_run_sequence()


func _process(_delta: float) -> void:
	if not _closing and Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if is_instance_valid(_hover_card_holder) and _hover_card_holder.visible and is_instance_valid(_active_hover_card):
		_position_hover_card()


func _format_short_date(day_num: int) -> String:
	var total_idx := maxi(0, day_num - 1)
	@warning_ignore("integer_division")
	var months_elapsed := total_idx / 31
	var day_in_month := (total_idx % 31) + 1
	var month_idx := (7 + months_elapsed) % 12
	return "%s %d" % [SHORT_MONTHS[month_idx], day_in_month]


func _compute_grade_and_highlights() -> void:
	var cash_sales := float(_stats.get("cash_sales", 0.0))
	var utang_repaid := float(_stats.get("utang_repaid", 0.0))
	var tips := float(_stats.get("tips_earned", 0.0))
	var buyers := int(_stats.get("buyers_served", 0))
	var visits := int(_stats.get("visits_served", 0))
	var total_served := buyers + visits
	var items_sold := int(_stats.get("items_sold", 0))
	var xp_earned := int(_stats.get("xp_earned", 0))
	var level_ups := int(_stats.get("level_ups", 0))
	var upgrades_bought := int(_stats.get("upgrades_bought", 0))
	var utang_granted := int(_stats.get("utang_granted", 0))
	var smalltalks := int(_stats.get("smalltalks_done", 0))
	var returning_buyers := int(_stats.get("returning_buyers", 0))
	var sto_nino_taps := int(_stats.get("sto_nino_taps", 0))
	var missed_total := 0
	for k in StoryManager.todays_missed_items.keys():
		missed_total += int(StoryManager.todays_missed_items[k])
	var chapters: Array = _stats.get("story_chapters", [])
	var arcs: Array = _stats.get("arcs_completed", [])
	var milestones: Array = _stats.get("milestones_unlocked", [])

	# Weighted daily score (finances carry primary weight)
	var score := 0
	var spent_restock := float(_stats.get("spent_restock", 0.0))
	var mayari_tribute := float(_stats.get("mayari_tribute", 0.0))
	var day_idx := maxi(0, _day_number - 1)
	var gross_income := cash_sales + utang_repaid + tips
	var net_profit := gross_income - spent_restock - mayari_tribute
	var gross_target := (140.0 + float(day_idx) * 14.0) * (1.0 + float(day_idx) * 0.04)
	score += mini(45, int(roundf((gross_income / maxf(1.0, gross_target)) * 45.0)))
	if net_profit >= 0.0:
		score += mini(15, int(roundf((net_profit / maxf(1.0, gross_target * 0.45)) * 15.0)))
	else:
		score -= mini(20, int(roundf(absf(net_profit) / 20.0)))
	score += mini(30, total_served * 4)
	score += mini(18, chapters.size() * 6 + arcs.size() * 10)
	if total_served >= 3 and missed_total == 0:
		score += 12
	elif missed_total > 0:
		score -= mini(10, missed_total * 2)
	if StoryManager.last_tally_tier == "generous" or StoryManager.last_tally_tier == "cleared":
		score += 12
	elif StoryManager.last_tally_tier == "balanced":
		score += 6
	elif StoryManager.last_tally_tier == "shortfall":
		score -= 6

	# Deep negative net profit caps the maximum achievable grade
	if net_profit <= -400.0:
		score = mini(score, 35) # Max C
	elif net_profit <= -200.0:
		score = mini(score, 57) # Max B

	if score >= 82:
		_grade = "S"
		_grade_title = "Paldo"
		_grade_col = Color(1.0, 0.88, 0.42, 1.0)
	elif score >= 58:
		_grade = "A"
		_grade_title = "Mabenta"
		_grade_col = Color(0.58, 0.94, 0.56, 1.0)
	elif score >= 36:
		_grade = "B"
		_grade_title = "Mahinahon"
		_grade_col = Color(0.96, 0.88, 0.72, 1.0)
	else:
		_grade = "C"
		_grade_title = "Matumal"
		_grade_col = Color(0.62, 0.80, 0.98, 1.0)

	# Build prioritized Top 3 Highlights (specific arc names, no em-dashes)
	var candidates: Array[String] = []
	for arc_entry in arcs:
		var arc_str := str(arc_entry)
		if arc_str.contains("'s "):
			candidates.append("Completed %s!" % arc_str)
		else:
			candidates.append("Completed %s's Story Arc!" % arc_str)
	for m_title in milestones:
		candidates.append("Unlocked Ledger Milestone: %s!" % str(m_title))
	if level_ups > 0:
		candidates.append("Leveled Up to Player Lv. %d!" % StoryManager.player_level)
	if upgrades_bought >= 2:
		candidates.append("Upgraded the Store %d times!" % upgrades_bought)
	elif upgrades_bought == 1:
		candidates.append("Upgraded the Store!")
	if returning_buyers >= 2:
		candidates.append("%d Tambayan Visitors Came Back to Buy!" % returning_buyers)
	elif returning_buyers == 1:
		candidates.append("Tambayan Visitor Came Back to Buy!")

	var best_item := ""
	var best_qty := 0
	var item_counts: Dictionary = _stats.get("items_sold_counts", {})
	for iname in item_counts.keys():
		var qty := int(item_counts[iname])
		if qty > best_qty:
			best_qty = qty
			best_item = str(iname)
	if best_item != "" and best_qty >= 2:
		candidates.append("Best Seller: %s (%d sold)" % [best_item, best_qty])

	if total_served >= 3 and missed_total == 0:
		candidates.append("Zero Missed Requests Today!")
	if chapters.size() >= 2:
		candidates.append("Progressed %d Story Chapters!" % chapters.size())
	elif chapters.size() == 1:
		candidates.append("Progressed %s's Story!" % str(chapters[0]))
	if utang_granted >= 2:
		candidates.append("Helped %d Neighbors on Utang!" % utang_granted)
	elif utang_granted == 1:
		candidates.append("Trusted a Neighbor with Utang!")
	if smalltalks >= 2:
		candidates.append("%d Cozy Tambayan Smalltalks!" % smalltalks)
	if sto_nino_taps >= 2:
		candidates.append("Prayed to Sto. Niño %d times!" % sto_nino_taps)
	elif sto_nino_taps == 1:
		candidates.append("Received Sto. Niño's Blessing!")
	if cash_sales >= 100.0:
		candidates.append("Earned ₱%.0f in Cash Sales!" % cash_sales)
	if items_sold >= 10:
		candidates.append("Sold %d Items Across the Counter!" % items_sold)
	if xp_earned >= 80:
		candidates.append("Gained +%d Player XP Today!" % xp_earned)

	_highlights.clear()
	for i in range(mini(3, candidates.size())):
		_highlights.append(candidates[i])

	# Contextual post-summary quip for Reyna Mayari at the counter (reactive to arcs, Omens, upgrades, and daily grade)
	var had_active_omen := false
	var check_cards: Array[String] = StoryManager.active_mayari_cards.duplicate()
	if check_cards.is_empty() and StoryManager.active_mayari_card != "":
		check_cards.append(StoryManager.active_mayari_card)
	for cid in check_cards:
		if MayariCardRegistry.is_chill(cid):
			had_active_omen = true
			break

	if not arcs.is_empty():
		var first_arc := str(arcs[0])
		var first_char := first_arc.split("'s ")[0] if first_arc.contains("'s ") else first_arc
		var arc_key := first_char.to_lower().replace(" ", "").replace(".", "")
		var arc_quips: Dictionary = {
			"kuyakap": "The giant under the acacia breathes easier now. Even Biringan notices when an old smoke clears.",
			"manangana": "Your karinderya neighbor took to the sky at last. A good counter knows when to let someone rest.",
			"buboy": "Even the loud one-eyed boy pulled off a real errand. Karimlan surprises me every week.",
			"lolopilo": "That old duwende is grinning like it is 1968 again. You certainly keep the plaza lively.",
			"tk": "A tikbalang who finally knows his own roads. Do not tell the Silver Council, they will never believe it.",
			"rodel": "Neighbors are greeting the Litao by his true name again. Memory is rarer than silver, shopkeeper.",
			"sarimanok": "The gilded rooster actually bowed to a neighbor. I would have paid silver to witness that.",
			"brahim": "That young albularyo's wards are clean and warm. Your Lola would have liked him.",
			"danilo": "The quiet watcher by your awning finally stepped off his bench. You have a strange gravity, shopkeeper.",
			"rosalyn": "The highway bend feels quiet and warm now. Some errands only needed Lola's counter to finish.",
			"reynamayari": "A strange feeling, standing on this side of the counter without a ledger. Rest well, shopkeeper.",
		}
		if arc_quips.has(arc_key):
			_quip = str(arc_quips[arc_key])
		else:
			_quip = "You saw %s's story through to a turning point. Karimlan remembers such patience." % first_char
	elif not milestones.is_empty():
		var m_quips: Array[String] = [
			"Another seal breaks on the Silver Ledger. Biringan's Council is watching your numbers closely now.",
			"A new seal opens on Lola's pact. You have more nerve behind that counter than I expected.",
		]
		_quip = m_quips[randi() % m_quips.size()]
	elif had_active_omen and (_grade == "S" or _grade == "A"):
		var omen_quips: Array[String] = [
			"You turned a lunar Omen into a gleaming ledger. Your Lola used to grin the exact same way.",
			"An Omen hung over Karimlan and you still cleared the shelves. Impressive, shopkeeper.",
		]
		_quip = omen_quips[randi() % omen_quips.size()]
	elif upgrades_bought >= 1:
		var upg_quips: Array[String] = [
			"New fixtures behind the counter. Keep polishing this little tindahan and Biringan might get jealous.",
			"Fresh upgrades for Lola's shop. Careful, or your regulars will never leave the awning.",
		]
		_quip = upg_quips[randi() % upg_quips.size()]
	elif _grade == "S":
		var s_quips: Array[String] = [
			"A gleaming ledger, shopkeeper. Even the Silver Spires would call that a royal haul.",
			"Paldo, as your neighbors say. Rest your hands, you earned every peso on that wood.",
		]
		_quip = s_quips[randi() % s_quips.size()]
	elif _grade == "A":
		var a_quips: Array[String] = [
			"Steady hands and brisk trade. Keep your candy jar stocked and we will get along fine.",
			"Clean numbers and happy regulars. Your Lola's counter is in capable hands.",
		]
		_quip = a_quips[randi() % a_quips.size()]
	elif missed_total >= 3:
		_quip = "Empty shelves send neighbors home hungry. Call your uncle early and restock the jars."
	elif utang_granted >= 2:
		_quip = "Generous with the lista, shopkeeper. Just make sure your neighbors honor their word."
	elif _grade == "B":
		var b_quips: Array[String] = [
			"A calm shift behind the wood. Rest up, fresh coins will roll in soon enough.",
			"Measured and steady. Not every shift needs fireworks to hold the border open.",
		]
		_quip = b_quips[randi() % b_quips.size()]
	else:
		var c_quips: Array[String] = [
			"A quiet ledger. Let the cool air clear the dust, and open sharp next shift.",
			"Slow trade happens even in Biringan. Rest well, shopkeeper.",
		]
		_quip = c_quips[randi() % c_quips.size()]


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.030, 0.024, 0.020, 0.82)
	_root.add_child(_backdrop)

	# Borderless 5%-Safe Top Header (Nightly Ledger + short date pill "Aug 14" + Skip hint)
	_banner = HBoxContainer.new()
	_banner.anchor_left = 0.18
	_banner.anchor_right = 0.82
	_banner.anchor_top = 0.042
	_banner.anchor_bottom = 0.128
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.add_theme_constant_override("separation", 16)
	_root.add_child(_banner)

	var left_hdr := HBoxContainer.new()
	left_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_hdr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left_hdr.add_theme_constant_override("separation", 14)
	_banner.add_child(left_hdr)

	var hdr_title := Label.new()
	hdr_title.text = "Nightly Ledger"
	hdr_title.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	hdr_title.add_theme_font_size_override("font_size", 32)
	hdr_title.add_theme_color_override("font_color", COL_WHITE_HDR)
	hdr_title.add_theme_color_override("font_outline_color", COL_BROWN_BORDER)
	hdr_title.add_theme_constant_override("outline_size", 3)
	left_hdr.add_child(hdr_title)

	var date_pill := PanelContainer.new()
	date_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dp_st := UIStyle.create_flat_stylebox(Color(0.09, 0.078, 0.066, 0.94), 9, 14, 6)
	dp_st.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.68)
	dp_st.set_border_width_all(1)
	date_pill.add_theme_stylebox_override("panel", dp_st)
	left_hdr.add_child(date_pill)

	var date_lbl := Label.new()
	date_lbl.text = _format_short_date(_day_number)
	date_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	date_lbl.add_theme_font_size_override("font_size", 17)
	date_lbl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	date_pill.add_child(date_lbl)

	_skip_hint_pill = PanelContainer.new()
	_skip_hint_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skip_hint_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sk_st := UIStyle.create_flat_stylebox(Color(0.08, 0.07, 0.06, 0.88), 8, 12, 6)
	sk_st.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.42)
	sk_st.set_border_width_all(1)
	_skip_hint_pill.add_theme_stylebox_override("panel", sk_st)
	_banner.add_child(_skip_hint_pill)

	var sk_row := HBoxContainer.new()
	sk_row.add_theme_constant_override("separation", 8)
	sk_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_hint_pill.add_child(sk_row)

	sk_row.add_child(TopBannerQueue.create_keycap_pill("Space"))

	var sk_lbl := Label.new()
	sk_lbl.text = "Double-tap to skip"
	sk_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_MED)
	sk_lbl.add_theme_font_size_override("font_size", 14)
	sk_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	sk_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sk_row.add_child(sk_lbl)

	# Main Center Frame (grows taller per animated line like an unrolling ledger!)
	_frame = PanelContainer.new()
	_frame.anchor_left = 0.18
	_frame.anchor_right = 0.82
	_frame.anchor_top = 0.148
	_frame.anchor_bottom = 0.148
	_frame.offset_top = 0.0
	_frame.offset_bottom = 64.0
	_frame.clip_contents = true
	var f_style := UIStyle.create_flat_stylebox(Color(0.055, 0.048, 0.042, 0.96), 10, 24, 16)
	f_style.border_color = Color(0.835, 0.624, 0.278, 0.82)
	f_style.set_border_width_all(2)
	f_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	f_style.shadow_size = 24
	_frame.add_theme_stylebox_override("panel", f_style)
	_root.add_child(_frame)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	_frame.add_child(main_vbox)

	# 1. Top Card: Cashflow & Ledger
	_cashflow_card = _build_cashflow_card()
	_cashflow_card.visible = false
	_cashflow_card.modulate.a = 0.0
	main_vbox.add_child(_cashflow_card)

	# 2. Middle Card: Store Performance
	_perf_card = _build_performance_card()
	_perf_card.visible = false
	_perf_card.modulate.a = 0.0
	main_vbox.add_child(_perf_card)

	# 3. Bottom Row: Today's Conditions + Highlights of the Day
	_bottom_row = _build_bottom_row()
	_bottom_row.visible = false
	_bottom_row.modulate.a = 0.0
	main_vbox.add_child(_bottom_row)

	# Slam-Down Daily Rank Stamp — placed cleanly TO THE LEFT of the Cashflow numbers!
	_stamp_panel = PanelContainer.new()
	_stamp_panel.anchor_left = 0.82
	_stamp_panel.anchor_right = 0.82
	_stamp_panel.anchor_top = 0.148
	_stamp_panel.anchor_bottom = 0.148
	_stamp_panel.offset_left = -385.0
	_stamp_panel.offset_right = -215.0
	_stamp_panel.offset_top = 34.0
	_stamp_panel.offset_bottom = 152.0
	_stamp_panel.rotation_degrees = -5.5
	_stamp_panel.z_index = 14
	_stamp_panel.visible = false
	_stamp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st_style := UIStyle.create_flat_stylebox(Color(0.09, 0.075, 0.06, 0.96), 10, 6, 6)
	st_style.border_color = _grade_col
	st_style.set_border_width_all(3)
	st_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	st_style.shadow_size = 16
	_stamp_panel.add_theme_stylebox_override("panel", st_style)
	_root.add_child(_stamp_panel)

	var inner_seal := PanelContainer.new()
	inner_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var is_style := UIStyle.create_flat_stylebox(Color(0.0, 0.0, 0.0, 0.0), 7, 10, 4)
	is_style.border_color = Color(_grade_col.r, _grade_col.g, _grade_col.b, 0.55)
	is_style.set_border_width_all(1)
	inner_seal.add_theme_stylebox_override("panel", is_style)
	_stamp_panel.add_child(inner_seal)

	var sv := VBoxContainer.new()
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	sv.add_theme_constant_override("separation", 0)
	inner_seal.add_child(sv)

	var g_lbl := Label.new()
	g_lbl.text = _grade
	g_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_BOLD)
	g_lbl.add_theme_font_size_override("font_size", 54)
	g_lbl.add_theme_color_override("font_color", _grade_col)
	sv.add_child(g_lbl)

	var gt_lbl := Label.new()
	gt_lbl.text = _grade_title
	gt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gt_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	gt_lbl.add_theme_font_size_override("font_size", 17)
	gt_lbl.add_theme_color_override("font_color", COL_WHITE_HDR)
	sv.add_child(gt_lbl)

	# Compact "Close Shop" button in the bottom-right corner outside the ledger (hidden until tally finishes)
	_close_btn = Button.new()
	_close_btn.text = "Close Shop"
	if ResourceLoader.exists("res://Assets/ui/icons/moon.png"):
		_close_btn.icon = load("res://Assets/ui/icons/moon.png")
		_close_btn.add_theme_constant_override("icon_max_width", 20)
		_close_btn.add_theme_constant_override("h_separation", 10)
	_close_btn.anchor_left = 1.0
	_close_btn.anchor_right = 1.0
	_close_btn.anchor_top = 1.0
	_close_btn.anchor_bottom = 1.0
	_close_btn.offset_left = -224.0
	_close_btn.offset_right = -32.0
	_close_btn.offset_top = -78.0
	_close_btn.offset_bottom = -28.0
	_close_btn.z_index = 14
	_close_btn.visible = false
	_close_btn.modulate.a = 0.0
	_close_btn.disabled = true
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_btn.add_theme_font_override("font", _bold_font)
	_close_btn.add_theme_font_size_override("font_size", 19)
	var cb_style := UIStyle.create_flat_stylebox(Color(0.38, 0.29, 0.14, 0.98), 8, 22, 8)
	cb_style.border_color = COL_GOLD_BRIGHT
	cb_style.set_border_width_all(2)
	cb_style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	cb_style.shadow_size = 14
	var cb_hov: StyleBoxFlat = cb_style.duplicate()
	cb_hov.bg_color = Color(0.48, 0.37, 0.18, 0.98)
	cb_hov.border_color = COL_WHITE_HDR
	var cb_dis: StyleBoxFlat = cb_style.duplicate()
	cb_dis.bg_color = Color(0.14, 0.12, 0.10, 0.82)
	cb_dis.border_color = Color(0.45, 0.38, 0.28, 0.45)
	_close_btn.add_theme_stylebox_override("normal", cb_style)
	_close_btn.add_theme_stylebox_override("hover", cb_hov)
	_close_btn.add_theme_stylebox_override("pressed", cb_style)
	_close_btn.add_theme_stylebox_override("disabled", cb_dis)
	_close_btn.add_theme_color_override("font_color", COL_WHITE_HDR)
	_close_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_close_btn.add_theme_color_override("font_disabled_color", Color(0.65, 0.60, 0.52, 0.55))
	_close_btn.pressed.connect(_on_close_pressed)
	_root.add_child(_close_btn)

	# Reyna Mayari Portrait (same framing as MayariTallyOverlay)
	if _show_mayari:
		_mayari_portrait = TextureRect.new()
		if ResourceLoader.exists(MAYARI_SPRITE_PATH):
			_mayari_portrait.texture = load(MAYARI_SPRITE_PATH)
		_mayari_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_mayari_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_mayari_portrait.anchor_left = -0.055
		_mayari_portrait.anchor_right = 0.354
		_mayari_portrait.anchor_top = 0.235
		_mayari_portrait.anchor_bottom = 1.240
		_mayari_portrait.z_index = 10
		_mayari_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(_mayari_portrait)

	# Mouse-following Hover Event Card Container (for Today's Conditions diamonds)
	_hover_card_holder = Control.new()
	_hover_card_holder.z_index = 40
	_hover_card_holder.visible = false
	_hover_card_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hover_card_holder)


func _make_section_card(title: String, icon_path: String = "") -> Array:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := UIStyle.create_flat_stylebox(COL_CARD_BG, 8, 20, 12)
	st.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.54)
	st.border_width_left = 4
	st.border_width_top = 1
	st.border_width_right = 1
	st.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", st)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 9)
	vb.add_child(hdr_row)

	if icon_path != "":
		var tex := HadesEmblem.load_lucide_icon(icon_path)
		if tex != null:
			var ico := TextureRect.new()
			ico.texture = tex
			ico.custom_minimum_size = Vector2(20, 20)
			ico.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ico.modulate = COL_GOLD_BRIGHT
			hdr_row.add_child(ico)

	var hdr := Label.new()
	hdr.text = title
	hdr.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	hdr.add_theme_font_size_override("font_size", 20)
	hdr.add_theme_color_override("font_color", COL_WHITE_HDR)
	hdr_row.add_child(hdr)
	return [panel, vb]


func _create_stat_row(parent: VBoxContainer, label_txt: String, target: float, prefix: String, suffix: String, val_col: Color, is_int: bool = false, is_bold: bool = false) -> Dictionary:
	var row := HBoxContainer.new()
	row.visible = false
	row.modulate.a = 0.0
	parent.add_child(row)

	var l := Label.new()
	l.text = label_txt
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _bold_font if is_bold else UIStyle.FONT_INDER)
	l.add_theme_font_size_override("font_size", 21 if is_bold else 18)
	l.add_theme_color_override("font_color", COL_WHITE_HDR if is_bold else COL_GOLD_LABEL)
	row.add_child(l)

	var v := Label.new()
	v.text = _format_val(0.0, prefix, suffix, is_int)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_theme_font_override("font", _bold_font)
	v.add_theme_font_size_override("font_size", 27 if is_bold else 22)
	v.add_theme_color_override("font_color", val_col)
	row.add_child(v)

	return {
		"label": v,
		"name_label": l,
		"target": target,
		"prefix": prefix,
		"suffix": suffix,
		"is_int": is_int,
		"is_bold": is_bold,
		"row": row,
	}


func _build_cashflow_card() -> PanelContainer:
	var built := _make_section_card("Cashflow & Ledger", "res://Assets/ui/icons/banknote.png")
	var panel: PanelContainer = built[0]
	var vb: VBoxContainer = built[1]

	var cash_sales := float(_stats.get("cash_sales", 0.0))
	var utang_repaid := float(_stats.get("utang_repaid", 0.0))
	var tips := float(_stats.get("tips_earned", 0.0))
	var spent_restock := float(_stats.get("spent_restock", 0.0))
	var tribute := float(_stats.get("mayari_tribute", 0.0))
	var net := (cash_sales + utang_repaid + tips) - (spent_restock + tribute)

	# Always show all Cashflow & Ledger rows (even when ₱0.00) so players see every channel
	_cashflow_entries.clear()
	_cashflow_entries.append(_create_stat_row(vb, "Cash Sales", cash_sales, "+₱" if cash_sales > 0.01 else "₱", "", COL_POS if cash_sales > 0.01 else COL_GOLD_ZERO))
	_cashflow_entries.append(_create_stat_row(vb, "Utang Repaid", utang_repaid, "+₱" if utang_repaid > 0.01 else "₱", "", COL_POS if utang_repaid > 0.01 else COL_GOLD_ZERO))
	_cashflow_entries.append(_create_stat_row(vb, "Tips & Bonuses", tips, "+₱" if tips > 0.01 else "₱", "", COL_GOLD_BRIGHT if tips > 0.01 else COL_GOLD_ZERO))
	_cashflow_entries.append(_create_stat_row(vb, "Restock & Upgrades", spent_restock, "-₱" if spent_restock > 0.01 else "₱", "", COL_NEG if spent_restock > 0.01 else COL_GOLD_ZERO))
	_cashflow_entries.append(_create_stat_row(vb, "Mayari's Tribute", tribute, "-₱" if tribute > 0.01 else "₱", "", COL_NEG if tribute > 0.01 else COL_GOLD_ZERO))

	_cashflow_sep = ColorRect.new()
	_cashflow_sep.custom_minimum_size = Vector2(0, 1)
	_cashflow_sep.color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.42)
	_cashflow_sep.visible = false
	_cashflow_sep.modulate.a = 0.0
	vb.add_child(_cashflow_sep)

	var net_prefix := "+₱" if net > 0.01 else ("-₱" if net < -0.01 else "₱")
	var net_col := COL_POS if net > 0.01 else (COL_NEG if net < -0.01 else COL_GOLD_BRIGHT)
	_net_entry = _create_stat_row(vb, "Net Profit Today", absf(net), net_prefix, "", net_col, false, true)
	return panel


func _build_performance_card() -> PanelContainer:
	var built := _make_section_card("Store Performance", "res://Assets/ui/icons/trending-up.png")
	var panel: PanelContainer = built[0]
	var vb: VBoxContainer = built[1]

	var buyers := int(_stats.get("buyers_served", 0))
	var visits := int(_stats.get("visits_served", 0))
	var items_sold := int(_stats.get("items_sold", 0))
	var xp_earned := int(_stats.get("xp_earned", 0))
	var chapters: Array = _stats.get("story_chapters", [])
	var utang_cnt := int(_stats.get("utang_granted", 0))
	var missed_cnt := 0
	for k in StoryManager.todays_missed_items.keys():
		missed_cnt += int(StoryManager.todays_missed_items[k])

	_perf_entries.clear()
	_perf_entries.append(_create_stat_row(vb, "Neighbors Served (%d buyers, %d visits)" % [buyers, visits], float(buyers + visits), "", "", COL_WHITE_HDR, true))
	_perf_entries.append(_create_stat_row(vb, "Items Handed Over", float(items_sold), "", "", COL_WHITE_HDR, true))
	if not chapters.is_empty():
		var unique_ch: Array[String] = []
		for cn in chapters:
			if not (str(cn) in unique_ch):
				unique_ch.append(str(cn))
		var ch_suffix := " (%s)" % ", ".join(unique_ch)
		_perf_entries.append(_create_stat_row(vb, "Story Chapters Progressed", float(chapters.size()), "", ch_suffix, COL_GOLD_BRIGHT, true))
	_perf_entries.append(_create_stat_row(vb, "Player XP Earned (Lv. %d)" % StoryManager.player_level, float(xp_earned), "+", " XP", COL_POS, true))

	# Rounded Mini XP Progress Bar (matching rounded track & rounded fill)
	_xp_bar_track = Panel.new()
	_xp_bar_track.custom_minimum_size = Vector2(0, 12)
	_xp_bar_track.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_xp_bar_track.visible = false
	_xp_bar_track.modulate.a = 0.0
	var ts := UIStyle.create_flat_stylebox(Color(0.04, 0.035, 0.03, 0.96), 6, 0, 0)
	ts.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.55)
	ts.set_border_width_all(1)
	_xp_bar_track.add_theme_stylebox_override("panel", ts)
	vb.add_child(_xp_bar_track)

	_xp_bar_fill = Panel.new()
	var fs := UIStyle.create_flat_stylebox(COL_GOLD_BRIGHT, 6, 0, 0)
	fs.border_color = Color(1.0, 0.95, 0.78, 0.65)
	fs.border_width_top = 1
	_xp_bar_fill.add_theme_stylebox_override("panel", fs)
	_xp_bar_fill.anchor_left = 0.0
	_xp_bar_fill.anchor_top = 0.0
	_xp_bar_fill.anchor_bottom = 1.0
	_xp_bar_fill.anchor_right = 0.0
	_xp_bar_fill.offset_left = 1.0
	_xp_bar_fill.offset_top = 1.0
	_xp_bar_fill.offset_bottom = -1.0
	_xp_bar_fill.offset_right = -1.0
	_xp_bar_fill.visible = false
	_xp_bar_track.add_child(_xp_bar_fill)

	_perf_foot = Label.new()
	_perf_foot.text = "Utang Extended: %d   ·   Missed Requests: %d" % [utang_cnt, missed_cnt]
	_perf_foot.add_theme_font_override("font", UIStyle.FONT_INDER)
	_perf_foot.add_theme_font_size_override("font_size", 18)
	_perf_foot.add_theme_color_override("font_color", COL_POS if missed_cnt == 0 else COL_GOLD_LABEL)
	_perf_foot.visible = false
	_perf_foot.modulate.a = 0.0
	vb.add_child(_perf_foot)

	return panel


func _build_bottom_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	# Left: Today's Conditions (Adaptive scrollable grid for 8+ late-game conditions)
	var cond_built := _make_section_card("Today's Conditions", "res://Assets/ui/icons/sparkles.png")
	var cond_panel: PanelContainer = cond_built[0]
	var cond_vb: VBoxContainer = cond_built[1]
	cond_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cond_panel.size_flags_stretch_ratio = 0.44
	row.add_child(cond_panel)

	var all_cond_infos: Array[Dictionary] = []
	if is_instance_valid(StoreEventManager):
		for ev in StoreEventManager.get_active_events():
			all_cond_infos.append(_make_event_hover_info(ev))

	var mayari_ids: Array[String] = StoryManager.active_mayari_cards
	if mayari_ids.is_empty() and StoryManager.active_mayari_card != "":
		mayari_ids = [StoryManager.active_mayari_card]
	for mid in mayari_ids:
		var c := MayariCardRegistry.get_card(mid)
		if not c.is_empty():
			var kind_str := "favor" if MayariCardRegistry.is_favor(mid) else "omen"
			all_cond_infos.append(_make_card_hover_info(c, kind_str))

	for bid in _stats.get("blessings_used", []):
		var bc := MayariCardRegistry.get_card(str(bid))
		if not bc.is_empty():
			all_cond_infos.append(_make_card_hover_info(bc, "blessing"))

	# Adaptive diamond sizing so 8+ late-game conditions stay crisp & compact
	var cond_cnt := all_cond_infos.size()
	var diamond_px := 64 if cond_cnt <= 6 else (54 if cond_cnt <= 10 else 48)
	var sep_px := 12 if cond_cnt <= 6 else 8

	var cond_scroll := ScrollContainer.new()
	cond_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cond_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	cond_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if cond_cnt > 8:
		cond_scroll.custom_minimum_size = Vector2(0, 144)
	else:
		cond_scroll.custom_minimum_size = Vector2(0, diamond_px + 26)
	cond_vb.add_child(cond_scroll)

	var flow_pad := MarginContainer.new()
	flow_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow_pad.add_theme_constant_override("margin_top", 10)
	flow_pad.add_theme_constant_override("margin_bottom", 10)
	flow_pad.add_theme_constant_override("margin_left", 8)
	flow_pad.add_theme_constant_override("margin_right", 12)
	cond_scroll.add_child(flow_pad)

	var icons_flow := HFlowContainer.new()
	icons_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icons_flow.add_theme_constant_override("h_separation", sep_px)
	icons_flow.add_theme_constant_override("v_separation", sep_px)
	flow_pad.add_child(icons_flow)

	_condition_nodes.clear()
	for c_info in all_cond_infos:
		var d_btn := _make_condition_diamond(c_info, diamond_px)
		icons_flow.add_child(d_btn)
		_condition_nodes.append(d_btn)

	if _condition_nodes.is_empty():
		cond_scroll.visible = false
		var quiet := Label.new()
		quiet.text = "Quiet day in Karimlan."
		quiet.add_theme_font_override("font", UIStyle.FONT_FREDOKA_REG)
		quiet.add_theme_font_size_override("font_size", 16)
		quiet.add_theme_color_override("font_color", COL_GOLD_LABEL)
		cond_vb.add_child(quiet)
	else:
		var hint_lbl := Label.new()
		hint_lbl.text = "Hover an event to inspect" + (" · Scroll for more" if cond_cnt > 10 else "")
		hint_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_MED)
		hint_lbl.add_theme_font_size_override("font_size", 14)
		hint_lbl.add_theme_color_override("font_color", COL_GOLD_ZERO)
		cond_vb.add_child(hint_lbl)

	# Right: Top 3 Highlights of the Day
	var hl_built := _make_section_card("Highlights of the Day", "res://Assets/ui/icons/award.png")
	var hl_panel: PanelContainer = hl_built[0]
	var hl_vb: VBoxContainer = hl_built[1]
	hl_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl_panel.size_flags_stretch_ratio = 0.56
	row.add_child(hl_panel)

	_highlight_nodes.clear()
	var combined_hl: Array[String] = []
	if is_instance_valid(CharacterProgressionManager) and not CharacterProgressionManager.todays_rep_deltas.is_empty():
		var ranked_names: PackedStringArray = []
		var total_rep_gained := 0
		for cpath in CharacterProgressionManager.todays_rep_deltas.keys():
			var d: Dictionary = CharacterProgressionManager.todays_rep_deltas[cpath]
			var delta_val := int(d.get("delta", 0))
			if delta_val > 0:
				total_rep_gained += delta_val
			if bool(d.get("ranked_up", false)):
				var cd: CustomerData = StoryManager._get_character_data(str(cpath))
				var cn := cd.character_name if (cd and cd.character_name != "") else str(cpath).get_file().get_basename()
				ranked_names.append("%s (Rank %d)" % [cn, int(d.get("rank", 1))])
		if not ranked_names.is_empty():
			combined_hl.append("Reputation Rank Up: %s" % ", ".join(ranked_names))
		elif total_rep_gained > 0:
			combined_hl.append("Earned +%d Reputation across %d neighbor(s)" % [total_rep_gained, CharacterProgressionManager.todays_rep_deltas.size()])
	for h_txt in _highlights:
		combined_hl.append(str(h_txt))

	if combined_hl.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "Another honest day behind the counter."
		none_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		none_lbl.add_theme_font_size_override("font_size", 17)
		none_lbl.add_theme_color_override("font_color", COL_GOLD_LABEL)
		hl_vb.add_child(none_lbl)
	else:
		for h_txt in combined_hl:
			var hl := Label.new()
			hl.text = "★  %s" % h_txt
			hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hl.add_theme_font_override("font", UIStyle.FONT_INDER)
			hl.add_theme_font_size_override("font_size", 17)
			hl.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
			hl.modulate.a = 0.0
			hl_vb.add_child(hl)
			_highlight_nodes.append(hl)

	return row


func _category_display(cat: String) -> String:
	match cat.to_lower():
		"bottle": return "Beverages"
		"snack": return "Snacks"
		"can": return "Canned Goods"
		"cigarette": return "Cigarettes"
		"candy": return "Candies"
		"pack": return "Noodles"
		"sachet": return "Sachets"
		"frozen": return "Frozen"
		_: return cat.capitalize()


func _event_sigil(event_id: String) -> String:
	match event_id:
		"barangay_liga": return "◈"
		"brownout_notice": return "⚡"
		"payday_friday": return "₱"
		"summer_heat": return "☀"
		"typhoon_warning": return "〰"
		_: return "✦"


func _format_natural_list(names: PackedStringArray) -> String:
	var count := names.size()
	if count == 0:
		return "Featured Stock"
	if count == 1:
		return names[0]
	if count == 2:
		return "%s and %s" % [names[0], names[1]]
	var leading := PackedStringArray()
	for i in range(count - 1):
		leading.append(names[i])
	return "%s, and %s" % [", ".join(leading), names[count - 1]]


func _make_event_hover_info(ev: StoreEventData) -> Dictionary:
	var desc_rich := ev.description
	if ev.has_target_items():
		var target_names := PackedStringArray()
		for cat in ev.affected_categories:
			target_names.append(_category_display(cat))
		if target_names.is_empty():
			for it in ev.affected_items:
				if it:
					target_names.append(it.item_name)
		var targets_str := _format_natural_list(target_names)
		desc_rich = "%s Neighbors are actively seeking [b]%s[/b] today." % [ev.description, targets_str]
	var stats: Array = ev.build_stat_rows()
	return {
		"fx_id": ev.event_id,
		"title": ev.event_name,
		"sigil": _event_sigil(ev.event_id),
		"icon": ev.get_icon_path(),
		"desc_rich": desc_rich,
		"stats": stats,
		"kind": "event",
	}


func _make_card_hover_info(c_data: Dictionary, kind: String) -> Dictionary:
	var raw_id := str(c_data.get("id", c_data.get("title", "")))
	return {
		"fx_id": ("blessing_" + raw_id) if kind == "blessing" else raw_id,
		"title": str(c_data.get("title", "Moon Card")),
		"sigil": str(c_data.get("sigil", "☽")),
		"icon": str(c_data.get("icon", "")),
		"desc_rich": str(c_data.get("description_rich", c_data.get("description", ""))),
		"stats": c_data.get("stats", []),
		"kind": kind,
	}


func _make_condition_diamond(info: Dictionary, diamond_px: int = 64) -> Control:
	var pal: Dictionary = HadesEmblem.palette(str(info.get("kind", "event")))
	var accent: Color = pal["accent"]
	var accent_bright: Color = pal["bright"]

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(diamond_px, diamond_px)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	holder.pivot_offset = Vector2(diamond_px * 0.5, diamond_px * 0.5)
	holder.modulate.a = 0.0

	var emblem := HadesEmblem.new()
	emblem.show_triangle = false
	emblem.set_anchors_preset(Control.PRESET_FULL_RECT)
	emblem.accent = accent
	emblem.accent_bright = accent_bright
	emblem.set_fx_from_id(str(info.get("fx_id", info.get("title", ""))))
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(emblem)

	var icon_px := roundf(float(diamond_px) * 0.40)
	HadesEmblem.populate_emblem_glyph(
		emblem,
		str(info.get("icon", "")),
		str(info.get("sigil", "✦")),
		accent_bright,
		icon_px,
		int(icon_px)
	)

	holder.mouse_entered.connect(func():
		EventBus.request_sfx.emit("ui_hover")
		var tw := holder.create_tween()
		tw.tween_property(holder, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_show_hover_card(info)
	)
	holder.mouse_exited.connect(func():
		var tw := holder.create_tween()
		tw.tween_property(holder, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_SINE)
		_hide_hover_card()
	)
	return holder


func _show_hover_card(info: Dictionary) -> void:
	if not is_instance_valid(_hover_card_holder):
		return
	for ch in _hover_card_holder.get_children():
		ch.queue_free()

	_active_hover_card = _build_hover_event_card(info)
	_hover_card_holder.add_child(_active_hover_card)
	_hover_card_holder.visible = true
	_position_hover_card()


func _hide_hover_card() -> void:
	if is_instance_valid(_hover_card_holder):
		_hover_card_holder.visible = false
	_active_hover_card = null


func _get_unified_hover_card_size() -> Vector2:
	# Exact 1:1 width & height ratio as EventsOverlay / MayariTallyOverlay cards!
	var vp_size := get_viewport().get_visible_rect().size
	var w := maxf(680.0, vp_size.x * 0.53 - 48.0)
	var h := maxf(130.0, (vp_size.y * 0.680 - 135.0) / 3.0)
	return Vector2(w, h)


func _position_hover_card() -> void:
	if not is_instance_valid(_active_hover_card):
		return
	var vp_size := get_viewport().get_visible_rect().size
	var mpos := get_viewport().get_mouse_position()
	var unified := _get_unified_hover_card_size()
	var card_sz := _active_hover_card.get_combined_minimum_size()
	var card_w := unified.x
	var card_h := maxf(unified.y, card_sz.y)
	_active_hover_card.size = Vector2(card_w, card_h)

	var x := mpos.x + 20.0
	var y := mpos.y - card_h - 14.0
	if x + card_w > vp_size.x - 16.0:
		x = mpos.x - card_w - 20.0
	if x < 16.0:
		x = clampf(mpos.x - card_w * 0.5, 16.0, maxf(16.0, vp_size.x - card_w - 16.0))
	if y < 16.0:
		y = mpos.y + 22.0
	if y + card_h > vp_size.y - 16.0:
		y = vp_size.y - card_h - 16.0
	_hover_card_holder.position = Vector2(x, y)


func _build_hover_event_card(info: Dictionary) -> PanelContainer:
	var kind := str(info.get("kind", "event"))
	var pal: Dictionary = HadesEmblem.palette(kind)
	var accent: Color = pal["accent"]
	var accent_bright: Color = pal["bright"]
	var row_bg: Color = pal["bg"]
	var tag: String = str(pal["tag"])
	var unified := _get_unified_hover_card_size()

	var card := PanelContainer.new()
	card.custom_minimum_size = unified
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UIStyle.create_flat_stylebox(row_bg, 6, 16, 10)
	style.content_margin_right = 20
	style.border_color = Color(accent.r, accent.g, accent.b, 0.88)
	style.border_width_left = 4
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 6)
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 52)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	var emblem := HadesEmblem.new()
	emblem.custom_minimum_size = Vector2(88, 88)
	emblem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	emblem.accent = accent
	emblem.accent_bright = accent_bright
	emblem.set_fx_from_id(str(info.get("fx_id", info.get("title", ""))))
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(emblem)

	HadesEmblem.populate_emblem_glyph(
		emblem,
		str(info.get("icon", "")),
		str(info.get("sigil", "✦")),
		accent_bright,
		36.0,
		36
	)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.add_theme_constant_override("separation", 3)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_col)

	var top_line := HBoxContainer.new()
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(top_line)

	var title_lbl := Label.new()
	title_lbl.text = str(info.get("title", "Condition"))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", accent_bright)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_line.add_child(title_lbl)

	var tag_lbl := Label.new()
	tag_lbl.text = tag.capitalize()
	tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag_lbl.add_theme_font_override("font", UIStyle.FONT_FREDOKA_SEMIBOLD)
	tag_lbl.add_theme_font_size_override("font_size", 18)
	tag_lbl.add_theme_color_override("font_color", accent_bright)
	tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_line.add_child(tag_lbl)

	var desc_rt := RichTextLabel.new()
	desc_rt.bbcode_enabled = true
	desc_rt.fit_content = true
	desc_rt.scroll_active = false
	desc_rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_rt.add_theme_font_override("normal_font", UIStyle.FONT_INDER)
	desc_rt.add_theme_font_override("bold_font", _bold_font)
	desc_rt.add_theme_font_size_override("normal_font_size", 18)
	desc_rt.add_theme_font_size_override("bold_font_size", 18)
	desc_rt.add_theme_color_override("default_color", COL_CREAM_MUTED)
	var raw_desc := str(info.get("desc_rich", ""))
	desc_rt.text = raw_desc.replace("[b]", "[b][color=%s]" % COL_BOLD_CREAM).replace("[/b]", "[/color][/b]")
	text_col.add_child(desc_rt)

	var stats: Array = info.get("stats", [])
	if stats.size() >= 3:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 20)
		grid.add_theme_constant_override("v_separation", 2)
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_child(grid)
		for st in stats:
			var stat_dict: Dictionary = st
			var s_row := HBoxContainer.new()
			s_row.add_theme_constant_override("separation", 8)
			s_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			s_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(s_row)

			var s_name := Label.new()
			s_name.text = "▸ " + str(stat_dict.get("label", ""))
			s_name.add_theme_font_override("font", UIStyle.FONT_INDER)
			s_name.add_theme_font_size_override("font_size", 15)
			s_name.add_theme_color_override("font_color", COL_CREAM)
			s_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_row.add_child(s_name)

			var s_val := Label.new()
			s_val.text = str(stat_dict.get("value", ""))
			s_val.add_theme_font_override("font", _bold_font)
			s_val.add_theme_font_size_override("font_size", 16)
			var tone := str(stat_dict.get("tone", "pos"))
			var val_col := COL_POS if tone == "pos" else (COL_NEG if tone == "neg" else COL_GOLD_BRIGHT)
			s_val.add_theme_color_override("font_color", val_col)
			s_val.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_row.add_child(s_val)
	elif not stats.is_empty():
		var stats_box := VBoxContainer.new()
		stats_box.add_theme_constant_override("separation", 1 if stats.size() == 2 else 2)
		stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_col.add_child(stats_box)
		var lbl_sz := 16 if stats.size() == 2 else 18
		var val_sz := 17 if stats.size() == 2 else 19
		for st in stats:
			var stat_dict: Dictionary = st
			var s_row := HBoxContainer.new()
			s_row.add_theme_constant_override("separation", 12)
			s_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_box.add_child(s_row)

			var s_name := Label.new()
			s_name.text = "▸ " + str(stat_dict.get("label", ""))
			s_name.custom_minimum_size = Vector2(345, 0)
			s_name.add_theme_font_override("font", UIStyle.FONT_INDER)
			s_name.add_theme_font_size_override("font_size", lbl_sz)
			s_name.add_theme_color_override("font_color", COL_CREAM)
			s_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_row.add_child(s_name)

			var s_val := Label.new()
			s_val.text = str(stat_dict.get("value", ""))
			s_val.add_theme_font_override("font", _bold_font)
			s_val.add_theme_font_size_override("font_size", val_sz)
			var tone := str(stat_dict.get("tone", "pos"))
			var val_col := COL_POS if tone == "pos" else (COL_NEG if tone == "neg" else COL_GOLD_BRIGHT)
			s_val.add_theme_color_override("font_color", val_col)
			s_val.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s_row.add_child(s_val)

	return card


func _format_val(val: float, prefix: String, suffix: String, is_int: bool) -> String:
	if is_int:
		return "%s%d%s" % [prefix, roundi(val), suffix]
	return "%s%.2f%s" % [prefix, val, suffix]


func _grow_frame_to_fit(dur: float = 0.16) -> void:
	if not is_instance_valid(_frame):
		return
	var vp_h := get_viewport().get_visible_rect().size.y
	var max_h := maxf(240.0, vp_h * 0.74)
	var target_h := clampf(_frame.get_combined_minimum_size().y, 64.0, max_h)
	if _skip_requested or dur <= 0.01:
		_frame.offset_bottom = target_h
		return
	var gtw := create_tween()
	gtw.tween_property(_frame, "offset_bottom", target_h, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _animate_stat_entry(entry: Dictionary) -> void:
	var row: Control = entry["row"]
	var lbl: Label = entry["label"]
	var target: float = float(entry["target"])
	var prefix: String = str(entry["prefix"])
	var suffix: String = str(entry["suffix"])
	var is_int: bool = bool(entry["is_int"])
	var is_bold: bool = bool(entry.get("is_bold", false))

	row.visible = true
	if _skip_requested:
		row.modulate.a = 1.0
		lbl.text = _format_val(target, prefix, suffix, is_int)
		lbl.scale = Vector2.ONE
		_grow_frame_to_fit(0.0)
		return

	_grow_frame_to_fit(0.16)
	# Reveal the row name first with a soft fade-in
	EventBus.request_sfx.emit("ui_hover")
	var rtw := create_tween()
	rtw.tween_property(row, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE)
	await rtw.finished
	if not is_inside_tree():
		return

	if absf(target) > 0.01:
		var dur := 0.34 if is_bold else 0.24
		var tw := create_tween()
		tw.tween_method(func(v: float):
			if is_instance_valid(lbl):
				lbl.text = _format_val(v, prefix, suffix, is_int)
		, 0.0, target, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await tw.finished
		if not is_inside_tree():
			return
		# Distinct audio cue when the final value lands
		if is_bold:
			EventBus.request_sfx.emit("money_gain" if target >= 0.0 else "money_decrease")
		elif prefix.begins_with("-") or target < 0.0:
			EventBus.request_sfx.emit("money_decrease")
		elif prefix.begins_with("+"):
			EventBus.request_sfx.emit("pickup")
		else:
			EventBus.request_sfx.emit("interact")
		# Subtle scale pop on final landed number
		lbl.pivot_offset = Vector2(lbl.size.x, lbl.size.y * 0.5)
		var pop := create_tween()
		var peak := 1.16 if is_bold else 1.10
		pop.tween_property(lbl, "scale", Vector2(peak, peak), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(lbl, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_SINE)
		await pop.finished
	else:
		EventBus.request_sfx.emit("interact")
		lbl.text = _format_val(0.0, prefix, suffix, is_int)
		await get_tree().create_timer(0.08).timeout


func _run_sequence() -> void:
	_backdrop.modulate.a = 0.0
	_banner.modulate.a = 0.0
	_frame.modulate.a = 0.0
	if is_instance_valid(_mayari_portrait):
		_mayari_portrait.modulate.a = 0.0
		_mayari_portrait.offset_left = 78.0
		_mayari_portrait.offset_right = 78.0

	EventBus.request_sfx.emit("tab_switch")
	var intro := create_tween()
	intro.tween_property(_backdrop, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	intro.parallel().tween_property(_banner, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE)
	intro.parallel().tween_property(_frame, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_SINE)
	if is_instance_valid(_mayari_portrait):
		intro.parallel().tween_property(_mayari_portrait, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
		intro.parallel().tween_property(_mayari_portrait, "offset_left", 30.0, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		intro.parallel().tween_property(_mayari_portrait, "offset_right", 30.0, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await intro.finished
	if not is_inside_tree():
		return

	# 1. Cashflow & Ledger section + one-by-one row reveals (frame grows taller with each line!)
	_cashflow_card.visible = true
	_grow_frame_to_fit(0.18)
	if _skip_requested:
		_cashflow_card.modulate.a = 1.0
	else:
		var ctw := create_tween()
		ctw.tween_property(_cashflow_card, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
		await ctw.finished
		if not is_inside_tree():
			return

	for entry in _cashflow_entries:
		await _animate_stat_entry(entry)
		if not is_inside_tree():
			return

	if is_instance_valid(_cashflow_sep):
		_cashflow_sep.visible = true
		_cashflow_sep.modulate.a = 1.0
	if not _net_entry.is_empty():
		await _animate_stat_entry(_net_entry)
		if not is_inside_tree():
			return

	# 2. Store Performance section + one-by-one row reveals + rounded XP bar
	_perf_card.visible = true
	_grow_frame_to_fit(0.18)
	if _skip_requested:
		_perf_card.modulate.a = 1.0
	else:
		EventBus.request_sfx.emit("tab_switch")
		var ptw := create_tween()
		ptw.tween_property(_perf_card, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
		await ptw.finished
		if not is_inside_tree():
			return

	for entry in _perf_entries:
		await _animate_stat_entry(entry)
		if not is_inside_tree():
			return

	var needed := maxi(1, StoryManager.get_xp_for_next_level())
	var xp_ratio := clampf(float(StoryManager.player_xp) / float(needed), 0.0, 1.0)
	if is_instance_valid(_xp_bar_track):
		_xp_bar_track.visible = true
		_xp_bar_track.modulate.a = 1.0
		_grow_frame_to_fit(0.14)
	if is_instance_valid(_xp_bar_fill):
		_xp_bar_fill.visible = xp_ratio > 0.005
		if _skip_requested:
			_xp_bar_fill.anchor_right = xp_ratio
		elif xp_ratio > 0.005:
			EventBus.request_sfx.emit("pickup")
			var xtw := create_tween()
			xtw.tween_property(_xp_bar_fill, "anchor_right", xp_ratio, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			await xtw.finished
			if not is_inside_tree():
				return
	if is_instance_valid(_perf_foot):
		_perf_foot.visible = true
		_grow_frame_to_fit(0.14)
		if _skip_requested:
			_perf_foot.modulate.a = 1.0
		else:
			var ftw := create_tween()
			ftw.tween_property(_perf_foot, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
			await ftw.finished
			if not is_inside_tree():
				return

	# 3. Bottom Row: Today's Conditions diamonds + Highlights of the Day one by one
	_bottom_row.visible = true
	_grow_frame_to_fit(0.22)
	if _skip_requested:
		_bottom_row.modulate.a = 1.0
	else:
		EventBus.request_sfx.emit("tab_switch")
		var btw := create_tween()
		btw.tween_property(_bottom_row, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
		await btw.finished
		if not is_inside_tree():
			return

	for d_node in _condition_nodes:
		if not is_instance_valid(d_node):
			continue
		if _skip_requested:
			d_node.modulate.a = 1.0
			d_node.scale = Vector2.ONE
		else:
			d_node.scale = Vector2(0.55, 0.55)
			EventBus.request_sfx.emit("pickup")
			var dtw := create_tween().set_parallel(true)
			dtw.tween_property(d_node, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE)
			dtw.tween_property(d_node, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			await dtw.finished
			if not is_inside_tree():
				return

	for h_node in _highlight_nodes:
		if not is_instance_valid(h_node):
			continue
		if _skip_requested:
			h_node.modulate.a = 1.0
		else:
			EventBus.request_sfx.emit("interact")
			var htw := create_tween()
			htw.tween_property(h_node, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
			await htw.finished
			if not is_inside_tree():
				return

	# 4. Slam down the Daily Rank Stamp cleanly to the left of the Cashflow numbers!
	if is_instance_valid(_stamp_panel):
		_stamp_panel.visible = true
		_stamp_panel.pivot_offset = _stamp_panel.size * 0.5
		if _skip_requested:
			_stamp_panel.scale = Vector2.ONE
			_stamp_panel.modulate.a = 1.0
		else:
			_stamp_panel.scale = Vector2(2.35, 2.35)
			_stamp_panel.modulate.a = 0.0
			EventBus.request_sfx.emit("purchase" if _grade in ["S", "A", "B"] else "drop")
			var stw := create_tween()
			stw.tween_property(_stamp_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			stw.parallel().tween_property(_stamp_panel, "modulate:a", 1.0, 0.14)
			await stw.finished
			if not is_inside_tree():
				return

	_tally_finished = true
	if is_instance_valid(_skip_hint_pill):
		var sk_tw := create_tween()
		sk_tw.tween_property(_skip_hint_pill, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
	if is_instance_valid(_close_btn):
		_close_btn.visible = true
		_close_btn.disabled = false
		_close_btn.modulate.a = 0.0
		var ctw := create_tween()
		ctw.tween_property(_close_btn, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)


func _input(event: InputEvent) -> void:
	if _closing:
		return
	# Block Pause Menu (Esc) during End-of-Day Summary so saving mid-summary cannot corrupt day rollover or mouse state
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		return
	var is_skip := false
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		is_skip = true
	elif event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_SPACE or event.keycode == KEY_SPACE or event.is_action_pressed("ui_accept")):
		if _tally_finished:
			_on_close_pressed()
			get_viewport().set_input_as_handled()
			return
		is_skip = true
	if is_skip and not _tally_finished:
		var now_msec := Time.get_ticks_msec()
		if now_msec - _last_skip_tap_msec <= 650:
			_skip_requested = true
		else:
			_last_skip_tap_msec = now_msec
		get_viewport().set_input_as_handled()


func _on_close_pressed() -> void:
	if _closing or not _tally_finished:
		return
	_closing = true
	_close_btn.disabled = true
	_hide_hover_card()
	EventBus.request_sfx.emit("drop")
	var fade := create_tween()
	fade.tween_property(_root, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
	await fade.finished
	completed.emit(_grade, _quip)
	queue_free()
