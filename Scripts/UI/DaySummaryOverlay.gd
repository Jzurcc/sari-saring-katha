class_name DaySummaryOverlay
extends CanvasLayer

## End-of-day Papa's Pizzeria / Hades-styled Nightly Ledger Summary.
## Displays animated rolling stats across Top Card (Cashflow), Middle Card (Performance),
## Bottom Row (Today's Active Conditions + Top 3 Highlights), and a slam-down Daily Rank Stamp.
## Clicking or pressing Space skips the roll-up animation immediately.

signal completed(grade: String, quip: String)

const MAYARI_SPRITE_PATH := "res://Assets/characters/sprites/ReynaMayari.png"
const HadesEmblem = preload("res://Scripts/UI/HadesDiamondEmblem.gd")

const COL_ESPRESSO_DEEP := Color(0.055, 0.048, 0.042, 0.96)
const COL_CARD_BG := Color(0.088, 0.078, 0.068, 0.94)
const COL_GOLD := Color(0.835, 0.624, 0.278, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.875, 0.56, 1.0)
const COL_CREAM := Color(1.0, 0.922, 0.792, 1.0)
const COL_CREAM_MUTED := Color(0.82, 0.75, 0.64, 0.84)
const COL_BROWN_BORDER := Color(0.482, 0.306, 0.102, 0.9)
const COL_POS := Color(0.56, 0.92, 0.52, 1.0)
const COL_NEG := Color(0.96, 0.48, 0.45, 1.0)

const SHORT_MONTHS: Array[String] = [
	"Jan", "Feb", "Mar", "Apr", "May", "Jun",
	"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
]

var _bold_font: FontVariation
var _root: Control
var _backdrop: ColorRect
var _banner: PanelContainer
var _frame: PanelContainer
var _mayari_portrait: TextureRect
var _close_btn: Button
var _stamp_panel: PanelContainer
var _xp_bar_fill: ColorRect
var _xp_bar_track: Control

var _stats: Dictionary = {}
var _day_number: int = 1
var _show_mayari: bool = true
var _grade: String = "B"
var _grade_title: String = "STEADY"
var _grade_col: Color = COL_GOLD_BRIGHT
var _quip: String = ""
var _highlights: Array[String] = []

var _skip_requested: bool = false
var _tally_finished: bool = false
var _closing: bool = false

# Animated numeric labels: Array[{ "label": Label, "target": float, "prefix": String, "suffix": String, "is_int": bool, "row": Control }]
var _anim_entries: Array[Dictionary] = []

func setup(day_num: int, daily_stats: Dictionary, show_mayari: bool = true) -> void:
	_day_number = day_num
	_stats = daily_stats.duplicate(true)
	_show_mayari = show_mayari
	_compute_grade_and_highlights()

func _ready() -> void:
	layer = 62
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bold_font = FontVariation.new()
	_bold_font.base_font = UIStyle.FONT_INDER
	_bold_font.variation_embolden = 0.65
	_build_ui()
	_run_sequence()

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

	# Weighted daily score
	var score := 0
	score += mini(40, int(roundf((cash_sales + utang_repaid + tips) * 0.25)))
	score += mini(25, total_served * 4)
	score += mini(15, chapters.size() * 6 + arcs.size() * 10)
	if total_served >= 3 and missed_total == 0:
		score += 12
	elif missed_total > 0:
		score -= mini(15, missed_total * 4)
	if StoryManager.last_tally_tier == "generous" or StoryManager.last_tally_tier == "cleared":
		score += 12
	elif StoryManager.last_tally_tier == "balanced":
		score += 6

	if score >= 72:
		_grade = "S"
		_grade_title = "SUKI MASTER"
		_grade_col = Color(1.0, 0.88, 0.42, 1.0)
	elif score >= 52:
		_grade = "A"
		_grade_title = "MASIPAG"
		_grade_col = Color(0.58, 0.94, 0.56, 1.0)
	elif score >= 32:
		_grade = "B"
		_grade_title = "STEADY"
		_grade_col = Color(0.96, 0.88, 0.72, 1.0)
	else:
		_grade = "C"
		_grade_title = "MATUMAL"
		_grade_col = Color(0.62, 0.80, 0.98, 1.0)

	# Build prioritized Top 3 Highlights (no em-dashes!)
	var candidates: Array[String] = []
	for arc_name in arcs:
		candidates.append("Completed %s's Story Arc!" % str(arc_name))
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

	# Best Seller item
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

	# Contextual 1-line post-summary quip for Reyna Mayari at the counter
	if not arcs.is_empty():
		_quip = "You saw %s's tale to a turning point today. Karimlan remembers such kindness." % str(arcs[0])
	elif not milestones.is_empty():
		_quip = "A new seal opens upon the Silver Ledger. You grow bolder, shopkeeper."
	elif _grade == "S":
		_quip = "A gleaming ledger tonight, shopkeeper. Even Biringan speaks well of your tindahan."
	elif _grade == "A":
		_quip = "Steady hands and brisk trade today. Rest well before the morning bell."
	elif missed_total >= 3:
		_quip = "Empty shelves turn neighbors away. Call your uncle at dawn and stock well."
	elif utang_granted >= 2:
		_quip = "So much credit written in ink today... make sure your neighbors keep their word."
	elif _grade == "B":
		_quip = "A fair day's work behind the counter. Tomorrow brings fresh coin."
	else:
		_quip = "A quiet ledger tonight. Let the night air clear the dust, and try again at dawn."

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.032, 0.026, 0.022, 0.80)
	_root.add_child(_backdrop)

	# Top Hades Banner
	_banner = PanelContainer.new()
	_banner.anchor_left = 0.14
	_banner.anchor_right = 0.86
	_banner.anchor_top = 0.028
	_banner.anchor_bottom = 0.140
	var b_style := UIStyle.create_flat_stylebox(COL_ESPRESSO_DEEP, 6, 32, 10)
	b_style.border_color = COL_GOLD
	b_style.set_border_width_all(2)
	b_style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	b_style.shadow_size = 16
	_banner.add_theme_stylebox_override("panel", b_style)
	_root.add_child(_banner)

	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_theme_constant_override("separation", 2)
	_banner.add_child(bv)

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 16)
	bv.add_child(title_row)

	for s_orn in ["◈", "N I G H T L Y   L E D G E R   ·   %s" % _format_short_date(_day_number).to_upper(), "◈"]:
		var lbl := Label.new()
		lbl.text = s_orn
		if s_orn == "◈":
			lbl.add_theme_font_size_override("font_size", 20)
			lbl.add_theme_color_override("font_color", COL_GOLD)
		else:
			lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
			lbl.add_theme_font_size_override("font_size", 30)
			lbl.add_theme_color_override("font_color", COL_CREAM)
			lbl.add_theme_color_override("font_outline_color", COL_BROWN_BORDER)
			lbl.add_theme_constant_override("outline_size", 4)
		title_row.add_child(lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "End of Day Performance Summary  (Click or press Space to skip)"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
	sub_lbl.add_theme_font_size_override("font_size", 15)
	sub_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
	bv.add_child(sub_lbl)

	# Main Center Frame (same footprint as MayariTallyOverlay)
	_frame = PanelContainer.new()
	_frame.anchor_left = 0.255
	_frame.anchor_right = 0.795
	_frame.anchor_top = 0.165
	_frame.anchor_bottom = 0.865
	var f_style := UIStyle.create_flat_stylebox(Color(0.058, 0.052, 0.046, 0.95), 8, 22, 16)
	f_style.border_color = Color(0.835, 0.624, 0.278, 0.82)
	f_style.set_border_width_all(2)
	f_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	f_style.shadow_size = 24
	_frame.add_theme_stylebox_override("panel", f_style)
	_root.add_child(_frame)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	_frame.add_child(main_vbox)

	# ── 1. TOP CARD: CASHFLOW & LEDGER ──
	main_vbox.add_child(_build_cashflow_card())

	# ── 2. MIDDLE CARD: STORE PERFORMANCE ──
	main_vbox.add_child(_build_performance_card())

	# ── 3. BOTTOM ROW: TODAY'S CONDITIONS + TOP 3 HIGHLIGHTS ──
	main_vbox.add_child(_build_bottom_row())

	# ── SLAM-DOWN DAILY RANK STAMP (Top-Right inside Center Frame) ──
	_stamp_panel = PanelContainer.new()
	_stamp_panel.anchor_left = 0.795
	_stamp_panel.anchor_right = 0.795
	_stamp_panel.anchor_top = 0.165
	_stamp_panel.anchor_bottom = 0.165
	_stamp_panel.offset_left = -168.0
	_stamp_panel.offset_right = -18.0
	_stamp_panel.offset_top = 18.0
	_stamp_panel.offset_bottom = 128.0
	_stamp_panel.rotation_degrees = -6.0
	_stamp_panel.z_index = 14
	_stamp_panel.visible = false
	_stamp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st_style := UIStyle.create_flat_stylebox(Color(0.09, 0.075, 0.06, 0.96), 8, 12, 8)
	st_style.border_color = _grade_col
	st_style.set_border_width_all(3)
	st_style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	st_style.shadow_size = 14
	_stamp_panel.add_theme_stylebox_override("panel", st_style)
	_root.add_child(_stamp_panel)

	var sv := VBoxContainer.new()
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	sv.add_theme_constant_override("separation", 0)
	_stamp_panel.add_child(sv)

	var g_lbl := Label.new()
	g_lbl.text = _grade
	g_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g_lbl.add_theme_font_override("font", _bold_font)
	g_lbl.add_theme_font_size_override("font_size", 46)
	g_lbl.add_theme_color_override("font_color", _grade_col)
	sv.add_child(g_lbl)

	var gt_lbl := Label.new()
	gt_lbl.text = _grade_title
	gt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gt_lbl.add_theme_font_override("font", _bold_font)
	gt_lbl.add_theme_font_size_override("font_size", 13)
	gt_lbl.add_theme_color_override("font_color", COL_CREAM)
	sv.add_child(gt_lbl)

	# ── OVERLAPPING BOTTOM-RIGHT CONTINUE BUTTON ──
	_close_btn = Button.new()
	_close_btn.text = "Close Ledger" if _show_mayari else "Close Shop & Sleep"
	_close_btn.anchor_left = 0.795
	_close_btn.anchor_right = 0.795
	_close_btn.anchor_top = 0.865
	_close_btn.anchor_bottom = 0.865
	_close_btn.offset_left = -246.0
	_close_btn.offset_right = -18.0
	_close_btn.offset_top = -24.0
	_close_btn.offset_bottom = 24.0
	_close_btn.z_index = 14
	_close_btn.disabled = true
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_btn.add_theme_font_override("font", _bold_font)
	_close_btn.add_theme_font_size_override("font_size", 18)
	var cb_style := UIStyle.create_flat_stylebox(Color(0.38, 0.29, 0.14, 0.98), 8, 20, 8)
	cb_style.border_color = COL_GOLD_BRIGHT
	cb_style.set_border_width_all(2)
	cb_style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	cb_style.shadow_size = 14
	var cb_hov: StyleBoxFlat = cb_style.duplicate()
	cb_hov.bg_color = Color(0.48, 0.37, 0.18, 0.98)
	cb_hov.border_color = COL_CREAM
	var cb_dis: StyleBoxFlat = cb_style.duplicate()
	cb_dis.bg_color = Color(0.14, 0.12, 0.10, 0.82)
	cb_dis.border_color = Color(0.45, 0.38, 0.28, 0.45)
	_close_btn.add_theme_stylebox_override("normal", cb_style)
	_close_btn.add_theme_stylebox_override("hover", cb_hov)
	_close_btn.add_theme_stylebox_override("pressed", cb_style)
	_close_btn.add_theme_stylebox_override("disabled", cb_dis)
	_close_btn.add_theme_color_override("font_color", COL_CREAM)
	_close_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_close_btn.add_theme_color_override("font_disabled_color", Color(0.65, 0.60, 0.52, 0.55))
	_close_btn.pressed.connect(_on_close_pressed)
	_root.add_child(_close_btn)

	# ── REYNA MAYARI PORTRAIT ON LEFT (when present) ──
	if _show_mayari:
		_mayari_portrait = TextureRect.new()
		if ResourceLoader.exists(MAYARI_SPRITE_PATH):
			_mayari_portrait.texture = load(MAYARI_SPRITE_PATH)
		_mayari_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_mayari_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_mayari_portrait.anchor_left = -0.03
		_mayari_portrait.anchor_right = 0.36
		_mayari_portrait.anchor_top = 0.34
		_mayari_portrait.anchor_bottom = 1.27
		_mayari_portrait.z_index = 10
		_mayari_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(_mayari_portrait)

func _make_section_card(title: String) -> Array:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := UIStyle.create_flat_stylebox(COL_CARD_BG, 6, 16, 10)
	st.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.52)
	st.border_width_left = 4
	st.border_width_top = 1
	st.border_width_right = 1
	st.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", st)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	var hdr := Label.new()
	hdr.text = title
	hdr.add_theme_font_override("font", _bold_font)
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.add_theme_color_override("font_color", COL_GOLD_BRIGHT)
	vb.add_child(hdr)
	return [panel, vb]

func _add_stat_row(parent: VBoxContainer, label_txt: String, target: float, prefix: String, suffix: String, val_col: Color, is_int: bool = false, is_bold: bool = false) -> void:
	var row := HBoxContainer.new()
	row.modulate.a = 0.0
	parent.add_child(row)

	var l := Label.new()
	l.text = label_txt
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_override("font", _bold_font if is_bold else UIStyle.FONT_INDER)
	l.add_theme_font_size_override("font_size", 18 if is_bold else 16)
	l.add_theme_color_override("font_color", COL_CREAM if is_bold else COL_CREAM_MUTED)
	row.add_child(l)

	var v := Label.new()
	v.text = "%s0%s" % [prefix, suffix]
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_font_override("font", _bold_font)
	v.add_theme_font_size_override("font_size", 20 if is_bold else 16)
	v.add_theme_color_override("font_color", val_col)
	row.add_child(v)

	_anim_entries.append({
		"label": v,
		"target": target,
		"prefix": prefix,
		"suffix": suffix,
		"is_int": is_int,
		"row": row,
	})

func _build_cashflow_card() -> PanelContainer:
	var built := _make_section_card("CASHFLOW & LEDGER")
	var panel: PanelContainer = built[0]
	var vb: VBoxContainer = built[1]

	var cash_sales := float(_stats.get("cash_sales", 0.0))
	var utang_repaid := float(_stats.get("utang_repaid", 0.0))
	var tips := float(_stats.get("tips_earned", 0.0))
	var spent_restock := float(_stats.get("spent_restock", 0.0))
	var tribute := float(_stats.get("mayari_tribute", 0.0))
	var net := (cash_sales + utang_repaid + tips) - (spent_restock + tribute)

	_add_stat_row(vb, "Cash Sales", cash_sales, "+₱", "", COL_POS)
	if utang_repaid > 0.01:
		_add_stat_row(vb, "Utang Repaid", utang_repaid, "+₱", "", COL_POS)
	if tips > 0.01:
		_add_stat_row(vb, "Tips & Bonuses", tips, "+₱", "", COL_GOLD_BRIGHT)
	if spent_restock > 0.01:
		_add_stat_row(vb, "Restock & Upgrades", spent_restock, "-₱", "", COL_NEG)
	if tribute > 0.01:
		_add_stat_row(vb, "Mayari's Tribute", tribute, "-₱", "", COL_NEG)

	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.35)
	vb.add_child(sep)

	var net_prefix := "+₱" if net >= 0.0 else "-₱"
	_add_stat_row(vb, "Net Profit Today", absf(net), net_prefix, "", COL_POS if net >= 0.0 else COL_NEG, false, true)
	return panel

func _build_performance_card() -> PanelContainer:
	var built := _make_section_card("STORE PERFORMANCE")
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

	_add_stat_row(vb, "Neighbors Served (%d buyers, %d visits)" % [buyers, visits], float(buyers + visits), "", "", COL_CREAM, true)
	_add_stat_row(vb, "Items Handed Over", float(items_sold), "", "", COL_CREAM, true)
	var ch_suffix := ""
	if not chapters.is_empty():
		var unique_ch: Array[String] = []
		for cn in chapters:
			if not (str(cn) in unique_ch):
				unique_ch.append(str(cn))
		ch_suffix = " (%s)" % ", ".join(unique_ch)
	_add_stat_row(vb, "Story Chapters Progressed", float(chapters.size()), "", ch_suffix, COL_GOLD_BRIGHT, true)
	_add_stat_row(vb, "Player XP Earned (Lv. %d)" % StoryManager.player_level, float(xp_earned), "+", " XP", COL_POS, true)

	# Mini XP Progress Bar
	_xp_bar_track = Panel.new()
	_xp_bar_track.custom_minimum_size = Vector2(0, 8)
	var ts := UIStyle.create_flat_stylebox(Color(0.04, 0.035, 0.03, 0.95), 4, 0, 0)
	ts.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.45)
	ts.set_border_width_all(1)
	_xp_bar_track.add_theme_stylebox_override("panel", ts)
	vb.add_child(_xp_bar_track)

	_xp_bar_fill = ColorRect.new()
	_xp_bar_fill.color = COL_GOLD_BRIGHT
	_xp_bar_fill.anchor_left = 0.0
	_xp_bar_fill.anchor_top = 0.0
	_xp_bar_fill.anchor_bottom = 1.0
	_xp_bar_fill.anchor_right = 0.0
	_xp_bar_track.add_child(_xp_bar_fill)

	var foot := Label.new()
	foot.text = "Utang Extended: %d   ·   Missed Requests: %d" % [utang_cnt, missed_cnt]
	foot.add_theme_font_override("font", UIStyle.FONT_INDER)
	foot.add_theme_font_size_override("font_size", 13)
	foot.add_theme_color_override("font_color", COL_POS if missed_cnt == 0 else COL_CREAM_MUTED)
	vb.add_child(foot)

	return panel

func _build_bottom_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	# Left: Today's Active Conditions (Events, Today's Moon Cards, Sto. Niño Blessings — NO tomorrow preview)
	var cond_built := _make_section_card("TODAY'S CONDITIONS")
	var cond_panel: PanelContainer = cond_built[0]
	var cond_vb: VBoxContainer = cond_built[1]
	cond_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cond_panel.size_flags_stretch_ratio = 0.44
	row.add_child(cond_panel)

	var icons_flow := HFlowContainer.new()
	icons_flow.add_theme_constant_override("h_separation", 8)
	icons_flow.add_theme_constant_override("v_separation", 6)
	cond_vb.add_child(icons_flow)

	var cond_count := 0
	if is_instance_valid(StoreEventManager):
		for ev in StoreEventManager.get_active_events():
			icons_flow.add_child(_make_condition_pill(ev.event_name, HadesEmblem.palette("event")))
			cond_count += 1
	var mayari_ids: Array[String] = StoryManager.active_mayari_cards
	if mayari_ids.is_empty() and StoryManager.active_mayari_card != "":
		mayari_ids = [StoryManager.active_mayari_card]
	for mid in mayari_ids:
		var c := MayariCardRegistry.get_card(mid)
		if not c.is_empty():
			var pal := HadesEmblem.palette("favor" if MayariCardRegistry.is_favor(mid) else "omen")
			icons_flow.add_child(_make_condition_pill(str(c.get("title", "")), pal))
			cond_count += 1
	for bid in _stats.get("blessings_used", []):
		var bc := MayariCardRegistry.get_card(str(bid))
		if not bc.is_empty():
			icons_flow.add_child(_make_condition_pill(str(bc.get("title", "")), HadesEmblem.palette("blessing")))
			cond_count += 1

	if cond_count == 0:
		var quiet := Label.new()
		quiet.text = "Quiet day in Karimlan."
		quiet.add_theme_font_override("font", UIStyle.FONT_INDER)
		quiet.add_theme_font_size_override("font_size", 14)
		quiet.add_theme_color_override("font_color", COL_CREAM_MUTED)
		cond_vb.add_child(quiet)

	# Right: Top 3 Highlights of the Day
	var hl_built := _make_section_card("HIGHLIGHTS OF THE DAY")
	var hl_panel: PanelContainer = hl_built[0]
	var hl_vb: VBoxContainer = hl_built[1]
	hl_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl_panel.size_flags_stretch_ratio = 0.56
	row.add_child(hl_panel)

	if _highlights.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "Another honest day behind the counter."
		none_lbl.add_theme_font_override("font", UIStyle.FONT_INDER)
		none_lbl.add_theme_font_size_override("font_size", 14)
		none_lbl.add_theme_color_override("font_color", COL_CREAM_MUTED)
		hl_vb.add_child(none_lbl)
	else:
		for h_txt in _highlights:
			var hl := Label.new()
			hl.text = "★  %s" % h_txt
			hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hl.add_theme_font_override("font", UIStyle.FONT_INDER)
			hl.add_theme_font_size_override("font_size", 14)
			hl.add_theme_color_override("font_color", COL_CREAM)
			hl_vb.add_child(hl)

	return row

func _make_condition_pill(title: String, pal: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	var acc: Color = pal["accent"]
	var brt: Color = pal["bright"]
	var st := UIStyle.create_flat_stylebox(Color(acc.r * 0.22, acc.g * 0.20, acc.b * 0.18, 0.92), 5, 8, 3)
	st.border_color = Color(acc.r, acc.g, acc.b, 0.78)
	st.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", st)
	var l := Label.new()
	l.text = title
	l.add_theme_font_override("font", _bold_font)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", brt)
	p.add_child(l)
	return p

func _format_val(val: float, prefix: String, suffix: String, is_int: bool) -> String:
	if is_int:
		return "%s%d%s" % [prefix, roundi(val), suffix]
	return "%s%.2f%s" % [prefix, val, suffix]

func _run_sequence() -> void:
	_backdrop.modulate.a = 0.0
	_banner.modulate.a = 0.0
	_frame.modulate.a = 0.0
	var intro := create_tween()
	intro.tween_property(_backdrop, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	intro.parallel().tween_property(_banner, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE)
	intro.parallel().tween_property(_frame, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_SINE)
	await intro.finished
	if not is_inside_tree():
		return

	# Roll up each numeric stat sequentially (Papa's Pizzeria style!)
	for entry in _anim_entries:
		var row: Control = entry["row"]
		var lbl: Label = entry["label"]
		var target: float = float(entry["target"])
		var prefix: String = str(entry["prefix"])
		var suffix: String = str(entry["suffix"])
		var is_int: bool = bool(entry["is_int"])

		if _skip_requested:
			row.modulate.a = 1.0
			lbl.text = _format_val(target, prefix, suffix, is_int)
			continue

		row.modulate.a = 1.0
		EventBus.request_sfx.emit("interact")
		var dur := 0.24 if absf(target) > 0.01 else 0.08
		var tw := create_tween()
		tw.tween_method(func(v: float):
			if is_instance_valid(lbl):
				lbl.text = _format_val(v, prefix, suffix, is_int)
		, 0.0, target, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await tw.finished
		if not is_inside_tree():
			return

	# Animate mini XP bar fill
	var needed := maxi(1, StoryManager.get_xp_for_next_level())
	var xp_ratio := 1.0 if StoryManager.player_level >= StoryManager.MAX_PLAYER_LEVEL else clampf(float(StoryManager.player_xp) / float(needed), 0.0, 1.0)
	if is_instance_valid(_xp_bar_fill):
		if _skip_requested:
			_xp_bar_fill.anchor_right = xp_ratio
		else:
			var xtw := create_tween()
			xtw.tween_property(_xp_bar_fill, "anchor_right", xp_ratio, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			await xtw.finished
			if not is_inside_tree():
				return

	# Slam down the Daily Rank Stamp!
	if is_instance_valid(_stamp_panel):
		_stamp_panel.visible = true
		_stamp_panel.pivot_offset = _stamp_panel.size * 0.5
		if _skip_requested:
			_stamp_panel.scale = Vector2.ONE
			_stamp_panel.modulate.a = 1.0
		else:
			_stamp_panel.scale = Vector2(2.3, 2.3)
			_stamp_panel.modulate.a = 0.0
			EventBus.request_sfx.emit("purchase")
			var stw := create_tween()
			stw.tween_property(_stamp_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			stw.parallel().tween_property(_stamp_panel, "modulate:a", 1.0, 0.14)
			await stw.finished
			if not is_inside_tree():
				return

	_tally_finished = true
	if is_instance_valid(_close_btn):
		_close_btn.disabled = false

func _input(event: InputEvent) -> void:
	if _closing:
		return
	var is_skip := false
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		is_skip = true
	elif event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_SPACE or event.keycode == KEY_SPACE or event.is_action_pressed("ui_accept")):
		is_skip = true
	if is_skip and not _tally_finished:
		_skip_requested = true
		get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	if _closing or not _tally_finished:
		return
	_closing = true
	_close_btn.disabled = true
	EventBus.request_sfx.emit("drop")
	var fade := create_tween()
	fade.tween_property(_root, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
	await fade.finished
	completed.emit(_grade, _quip)
	queue_free()
