extends Node

signal pending_debts_changed

## StoryManager — manages story progression and builds customer transactions.
## The clock runs freely from DAY_START_HOUR to CLOSING_HOUR with no event slots.

const DAY_START_HOUR := 5.0
const MENU_THEME_HOUR := 16.89 ## Golden hour aesthetic for Main Menu
const CLOSING_HOUR := 20.0 ## 8 PM — no new customers after this
const HARD_STOP_HOUR := 24.0 ## Midnight — absolute time limit
## 1 in-game hour = 50 real seconds.
const CLOCK_SPEED_HOURS_PER_SEC := 1.0 / 50.0

var clock: DayClock = DayClock.new()

var day: int = 1
var is_clock_running: bool:
	get: return clock.is_clock_running
	set(value): clock.set_clock_running(value)

var is_customer_present: bool:
	get: return clock.is_customer_present
	set(value): clock.is_customer_present = value

var wait_limit_time: float:
	get: return clock.wait_limit_time
	set(value): clock.wait_limit_time = value

var was_paused_by_limit: bool:
	get: return clock.was_paused_by_limit
	set(value): clock.was_paused_by_limit = value

var _current_display_time: float:
	get: return clock.current_display_time
	set(value): clock.current_display_time = value

var last_character_path: String = ""
var _pending_tier_advance_source: String = ""
var has_mayari_visited: bool = false
var is_mayari_debt_active: bool = true
var is_mayari_met: bool = false
var last_mayari_collection_successful: bool = true

# --- Reyna Mayari Goal-Based Nightly Tally & Moon Cards ---
const TALLY_GOAL := 2000.0
const TALLY_MIN_SCHEDULE: Array[float] = [40.0, 55.0, 70.0, 85.0, 100.0, 115.0, 130.0]
const TALLY_GEN_SCHEDULE: Array[float] = [95.0, 125.0, 155.0, 190.0, 225.0, 260.0, 295.0]

const LEDGER_MILESTONES: Array[Dictionary] = [
	{"id": "reroll_1", "ratio": 0.15, "amount": 300.0, "title": "Moon's Grace", "desc": "+1 Reroll on Reyna Mayari's nightly card draft."},
	{"id": "daytime_mayari", "ratio": 0.30, "amount": 600.0, "title": "Daylight Audience", "desc": "Reyna Mayari can now visit and shop during the day like a regular neighbor."},
	{"id": "shifted_odds_reroll_2", "ratio": 0.50, "amount": 1000.0, "title": "Silver Favor", "desc": "Fair odds shift to 50% Favor / 50% Omen (Meager 25% Favor) + 1 extra Reroll (2 total)."},
	{"id": "twin_moons", "ratio": 0.75, "amount": 1500.0, "title": "Twin Moons", "desc": "Draft up to 2 Moon Cards per night (choose 1 or 2)."},
	{"id": "sealed_ledger", "ratio": 1.00, "amount": 2000.0, "title": "Patron of the Moon", "desc": "Permanently seals the Silver Ledger."},
]

var tally_total_paid: float = 0.0
var tally_sufficient_nights: int = 0
var active_mayari_card: String = ""
var pending_mayari_card: String = ""
var active_mayari_cards: Array[String] = []
var pending_mayari_cards: Array[String] = []
var last_tally_tier: String = "balanced"
var daily_stats: Dictionary = {}
var pending_favorite_discovered_cat: String = ""

func _make_empty_daily_stats() -> Dictionary:
	return {
		"cash_sales": 0.0,
		"utang_repaid": 0.0,
		"tips_earned": 0.0,
		"spent_restock": 0.0,
		"mayari_tribute": 0.0,
		"buyers_served": 0,
		"visits_served": 0,
		"items_sold": 0,
		"items_sold_counts": {},
		"xp_earned": 0,
		"level_ups": 0,
		"story_chapters": [],
		"arcs_completed": [],
		"upgrades_bought": 0,
		"utang_granted": 0,
		"smalltalks_done": 0,
		"returning_buyers": 0,
		"sto_nino_taps": 0,
		"milestones_unlocked": [],
		"blessings_used": [],
	}

func reset_daily_stats() -> void:
	daily_stats = _make_empty_daily_stats()

func ensure_daily_stats() -> Dictionary:
	if daily_stats.is_empty():
		daily_stats = _make_empty_daily_stats()
	else:
		var defaults := _make_empty_daily_stats()
		for k in defaults.keys():
			if not daily_stats.has(k):
				daily_stats[k] = defaults[k]
	return daily_stats

func record_daily_stat_add(key: String, delta: float) -> void:
	var ds := ensure_daily_stats()
	ds[key] = float(ds.get(key, 0.0)) + delta

func record_daily_stat_int(key: String, delta: int = 1) -> void:
	var ds := ensure_daily_stats()
	ds[key] = int(ds.get(key, 0)) + delta

func record_daily_item_sold(item_name: String) -> void:
	var ds := ensure_daily_stats()
	ds["items_sold"] = int(ds.get("items_sold", 0)) + 1
	var counts: Dictionary = ds["items_sold_counts"]
	counts[item_name] = int(counts.get(item_name, 0)) + 1

func record_daily_list_entry(key: String, value: String, allow_duplicates: bool = true) -> void:
	if value == "":
		return
	var ds := ensure_daily_stats()
	var arr: Array = ds[key]
	if allow_duplicates or not (value in arr):
		arr.append(value)

func get_tally_remaining() -> float:
	return maxf(0.0, TALLY_GOAL - tally_total_paid)

func is_tally_cleared() -> bool:
	return (not is_mayari_debt_active) or tally_total_paid >= TALLY_GOAL - 0.01

func is_ledger_milestone_unlocked(milestone_id: String, paid_override: float = -1.0) -> bool:
	var paid := tally_total_paid if paid_override < 0.0 else paid_override
	for m in LEDGER_MILESTONES:
		if str(m["id"]) == milestone_id:
			return paid >= float(m["amount"]) - 0.01
	return false

func get_nightly_reroll_count(paid_override: float = -1.0) -> int:
	var rerolls := 0
	if is_ledger_milestone_unlocked("reroll_1", paid_override):
		rerolls += 1
	if is_ledger_milestone_unlocked("shifted_odds_reroll_2", paid_override):
		rerolls += 1
	return rerolls

func has_shifted_mayari_odds(paid_override: float = -1.0) -> bool:
	return is_ledger_milestone_unlocked("shifted_odds_reroll_2", paid_override)

func get_max_mayari_card_picks(paid_override: float = -1.0) -> int:
	return 2 if is_ledger_milestone_unlocked("twin_moons", paid_override) else 1

func is_daytime_mayari_unlocked() -> bool:
	return is_ledger_milestone_unlocked("daytime_mayari")

func get_nightly_min_tally() -> float:
	var rem := get_tally_remaining()
	if rem <= 0.01:
		return 0.0
	var idx := clampi(tally_sufficient_nights, 0, TALLY_MIN_SCHEDULE.size() - 1)
	return minf(TALLY_MIN_SCHEDULE[idx], rem)

func get_nightly_generous_tally() -> float:
	var rem := get_tally_remaining()
	if rem <= 0.01:
		return 0.0
	var idx := clampi(tally_sufficient_nights, 0, TALLY_GEN_SCHEDULE.size() - 1)
	return minf(TALLY_GEN_SCHEDULE[idx], rem)

func evaluate_tally_tier(offer: float) -> String:
	if tally_total_paid + offer >= TALLY_GOAL - 0.01:
		return "cleared"
	if offer >= get_nightly_generous_tally() - 0.01:
		return "generous"
	if offer >= get_nightly_min_tally() - 0.01:
		return "balanced"
	return "shortfall"

func has_mayari_card(card_id: String) -> bool:
	if card_id == "":
		return false
	return active_mayari_card == card_id or (card_id in active_mayari_cards) or (card_id in active_blessing_cards)

## Scales percentage-based tips/bonuses for late-game balance with generous hidden floor & cap.
func calc_scaled_tip(sale_price: float, pct: float, min_tip: float, max_tip: float) -> float:
	if sale_price <= 0.0 or pct <= 0.0:
		return 0.0
	return clampf(snapped(sale_price * pct, 0.5), min_tip, max_tip)


## Guaranteed extra cash value added to an item's sale without raising its price step or refusal risk.
## Shared by GameManager (payout) and PricingOverlay (live "+₱X Bonus" preview).
func get_item_sale_bonus(item: ItemData, base_sale: float, revealed_events_only: bool = false) -> float:
	if item == null or base_sale <= 0.0:
		return 0.0
	var bonus := 0.0
	if has_mayari_card(MayariCardRegistry.CARD_DISEMBODIED_WIND):
		if (item.category == "bottle" or item.category == "frozen") and not is_fridge_warm:
			bonus += calc_scaled_tip(base_sale, 0.12, 2.0, 15.0)
	if has_mayari_card(MayariCardRegistry.CARD_RESTLESS_CROWD) and item.current_step <= 1:
		bonus += calc_scaled_tip(base_sale, 0.15, 3.0, 16.0)
	if has_mayari_card(MayariCardRegistry.CARD_STATIC_AIRWAVES) and is_instance_valid(StoreEventManager):
		var ev_cnt := StoreEventManager.get_active_events().size() if revealed_events_only else StoreEventManager.get_all_active_events().size()
		if ev_cnt > 0:
			bonus += calc_scaled_tip(base_sale, 0.10 * float(ev_cnt), 2.0 * float(ev_cnt), 18.0 * float(ev_cnt))
	if is_instance_valid(StoreEventManager):
		var ev_pct := StoreEventManager.get_cash_tip_bonus_pct()
		if ev_pct > 0.0:
			bonus += calc_scaled_tip(base_sale, ev_pct, 2.0, 20.0)
	var feat_boosts := get_featured_category_boost_count(item.category)
	if feat_boosts > 0:
		bonus += 3.0 * float(feat_boosts)
		if has_mayari_card(MayariCardRegistry.CARD_CURBSIDE_GLOW):
			bonus += calc_scaled_tip(base_sale, 0.15, 3.0, 20.0)
	return bonus

func get_mayari_card_stack_count(card_id: String) -> int:
	if card_id.is_empty():
		return 0
	var count := 0
	if active_mayari_card == card_id or (card_id in active_mayari_cards):
		count += 1
	if card_id in active_blessing_cards:
		count += 1
	return count

func get_mayari_tolerance_offset() -> int:
	var offset := 0
	offset += get_mayari_card_stack_count(MayariCardRegistry.CARD_SILVER_TOLERANCE)
	if has_mayari_card(MayariCardRegistry.CARD_EERIE_MIST_RUSH):
		offset -= 1
	if has_mayari_card(MayariCardRegistry.CARD_RELUCTANT_CARE):
		offset -= 1
	if has_mayari_card(MayariCardRegistry.CARD_RESTLESS_CROWD):
		offset -= 1
	return offset

func get_restock_discount_multiplier() -> float:
	var mult := 1.0
	if has_mayari_card(MayariCardRegistry.CARD_RELUCTANT_CARE):
		mult *= 0.85
	if has_mayari_card(MayariCardRegistry.CARD_CLEAR_ROAD):
		mult *= 0.90
	if has_mayari_card(MayariCardRegistry.CARD_TIGHT_WHOLESALE):
		mult *= 1.20
	if is_instance_valid(StoreEventManager):
		mult *= StoreEventManager.get_restock_cost_multiplier()
	return mult

func get_item_restock_discount_multiplier(item: ItemData) -> float:
	var mult := get_restock_discount_multiplier()
	if item and is_item_on_sulit_deal(item):
		var blessed := has_mario_deals and has_mayari_card(MayariCardRegistry.CARD_WHOLESALE_BLESSING)
		var spec: Dictionary = MARIO_DEALS_SPECS[clampi(mario_deals_level, 1, MARIO_DEALS_SPECS.size() - 1)]
		mult *= float(spec["blessed_mult"]) if blessed else float(spec["mult"])
	return mult

func get_foot_traffic_time_scale() -> float:
	var scale := 1.0
	if has_mayari_card(MayariCardRegistry.CARD_EERIE_MIST_RUSH):
		scale *= 0.80
	if has_mayari_card(MayariCardRegistry.CARD_EARLY_DUSK):
		scale *= 0.75
	if has_mayari_card(MayariCardRegistry.CARD_CROWDED_STOOP):
		scale *= 0.85
	if is_instance_valid(StoreEventManager):
		scale *= StoreEventManager.get_foot_traffic_time_scale()
	return clampf(scale, 0.45, 1.35)

func get_effective_closing_hour() -> float:
	if has_mayari_card(MayariCardRegistry.CARD_MOON_HOLDS_SKY):
		return 22.0
	if has_mayari_card(MayariCardRegistry.CARD_EARLY_DUSK):
		return 18.5
	return CLOSING_HOUR
var customer_debts: Dictionary = {}
var pending_debts: Array[Dictionary] = [] # [{ "customer_path": String, "amount": float }]
var pending_repayments: Array[Dictionary] = [] # [{ "customer_path": String, "amount": float, "day": int }]
var settled_debts_log: Array[Dictionary] = [] # [{ "customer_path": String, "customer_name": String, "amount": float, "day": int }]
var _save_requested: bool = false

# --- Story Progression ---
var _char_lookup: Dictionary = {} # resource_path -> CustomerData
var _game_manager: GameManager = null

# --- Player Level, XP & Tier Progression ---
const MAX_UNLOCKABLE_TIER := 10
const MAX_PLAYER_LEVEL := 999
const PLAYER_XP_THRESHOLDS: Array[int] = [0, 100, 150, 210, 280, 360, 450, 550, 670, 800]

var player_level: int = 1
var player_xp: int = 0
var current_tier: int = 1
var max_unlocked_tier: int = 1
var _last_tier_unlocked_notification: int = 0
var _last_notified_tier: int = 0
var purchase_counter: int = 0 # Legacy save field kept for backward compatibility

func get_xp_for_next_level(lvl: int = player_level) -> int:
	if lvl < 1:
		return PLAYER_XP_THRESHOLDS[1]
	if lvl < PLAYER_XP_THRESHOLDS.size():
		return PLAYER_XP_THRESHOLDS[lvl]
	return PLAYER_XP_THRESHOLDS[PLAYER_XP_THRESHOLDS.size() - 1] + (lvl - (PLAYER_XP_THRESHOLDS.size() - 1)) * 140

## Scaling anti-softlock cash bonus awarded on every player level-up (Lv. 2 = ₱60, scales progressively & indefinitely).
func get_level_up_money_reward(new_level: int) -> float:
	var step := float(maxi(0, new_level - 2))
	var raw := (60.0 + step * 15.0) * (1.0 + 0.04 * step)
	return snapped(raw, 5.0)

func get_xp_multiplier() -> float:
	var mult := get_permit_xp_multiplier()
	if has_mayari_card(MayariCardRegistry.CARD_SILVER_RENOWN):
		mult *= 1.50
	if has_mayari_card(MayariCardRegistry.CARD_QUIET_ECLIPSE):
		mult *= 1.35
	if has_mayari_card(MayariCardRegistry.CARD_TIGHT_WHOLESALE):
		mult *= 1.30
	if has_mayari_card(MayariCardRegistry.CARD_FADING_MEMORY):
		mult *= 0.65
	if is_instance_valid(StoreEventManager):
		mult *= StoreEventManager.get_xp_multiplier()
	return mult

func add_player_xp(base_amount: int, reason: String = "") -> int:
	if base_amount <= 0:
		return 0
	var gained := maxi(1, roundi(float(base_amount) * get_xp_multiplier()))

	player_xp += gained
	var leveled_up := false
	while true:
		var needed := get_xp_for_next_level(player_level)
		if needed <= 0 or player_xp < needed:
			break
		player_xp -= needed
		player_level += 1
		leveled_up = true
		var tier_cap := mini(player_level, MAX_UNLOCKABLE_TIER)
		if tier_cap > max_unlocked_tier:
			max_unlocked_tier = tier_cap
			_pending_tier_advance_source = "LevelUp"
			_last_tier_unlocked_notification = max_unlocked_tier

		var level_bonus := get_level_up_money_reward(player_level)
		var will_show_tier_banner := (tier_cap > _last_notified_tier and _pending_tier_advance_source == "LevelUp")
		if will_show_tier_banner:
			_pending_level_up_bonus += level_bonus
		elif level_bonus > 0.0:
			_grant_level_up_money(level_bonus)

		LogManager.info("StoryManager", "PLAYER LEVEL UP -> Lv. %d! (+₱%.0f bonus, Max Tier %d)" % [player_level, level_bonus, max_unlocked_tier])
		EventBus.player_leveled_up.emit(player_level)
		# Tier-unlocking levels (Lv. 2..MAX_UNLOCKABLE_TIER) already show TierAdvanceOverlay with item previews;
		# only show the toast for post-max-tier bonus levels where no overlay pops up.
		if not will_show_tier_banner:
			EventBus.show_notification.emit("Player Level %d!" % player_level, "+₱%.0f Level-Up Bonus!" % level_bonus, "purchase")

	LogManager.info("StoryManager", "Player XP +%d (%s) -> Lv. %d (%d/%d)" % [gained, reason, player_level, player_xp, get_xp_for_next_level()])
	record_daily_stat_int("xp_earned", gained)
	if leveled_up:
		record_daily_stat_int("level_ups", 1)
	EventBus.player_xp_changed.emit(player_level, player_xp, get_xp_for_next_level(), gained, leveled_up)
	_save_progression()
	return gained

func get_required_purchases_for_next_tier() -> int:
	var base = 5 + floori(current_tier / 2.0)
	if current_tier >= 7:
		base += (current_tier - 6) * 2
	return clampi(base, 5, 15)

var pending_upgrade_tier: int = 0
var pending_upgrade_cost: float = 0.0
var _upgrade_item_cache: Dictionary = {}

# --- Refrigerator Coldness & Upgrades ---
## Level 0 = stock fridge; Levels 1..3 = Magnetic Door Gasket, Heavy-Duty Insulation, Inverter Frost Compressor.
const FRIDGE_UPGRADE_SPECS: Array[Dictionary] = [
	{"level": 0, "req_level": 1, "name": "Stock Refrigerator", "cost": 0.0, "drain_sec": 3.5, "regen_sec": 7.0, "desc": "Standard sari-sari fridge."},
	{"level": 1, "req_level": 2, "name": "Magnetic Door Gasket", "cost": 65.0, "drain_sec": 7.0, "regen_sec": 5.5, "desc": "Seals cold leaks when the door swings open."},
	{"level": 2, "req_level": 5, "name": "Heavy-Duty Insulation", "cost": 120.0, "drain_sec": 12.0, "regen_sec": 4.25, "desc": "Thick thermal lining keeps chilled stock frosty longer."},
	{"level": 3, "req_level": 9, "name": "Inverter Frost Compressor", "cost": 195.0, "drain_sec": 18.0, "regen_sec": 3.25, "desc": "Commercial inverter cooling snaps back to ice-cold fast."},
]
const FRIDGE_WARM_VALUE_MULTIPLIER := 0.75
const FRIDGE_WARM_RECOVER_THRESHOLD := 50.0

var fridge_upgrade_level: int = 0
var fridge_coldness: float = 100.0
var is_fridge_warm: bool = false
var _fridge_upgrade_item_cache: Dictionary = {}

func get_fridge_drain_rate() -> float:
	var lvl := clampi(fridge_upgrade_level, 0, FRIDGE_UPGRADE_SPECS.size() - 1)
	var rate := 100.0 / float(FRIDGE_UPGRADE_SPECS[lvl]["drain_sec"])
	if has_mayari_card(MayariCardRegistry.CARD_FROST_OF_BIRINGAN):
		rate *= 0.60
	if has_mayari_card(MayariCardRegistry.CARD_WARM_TRADE_WINDS):
		rate *= 1.60
	if is_instance_valid(StoreEventManager):
		rate *= StoreEventManager.get_fridge_drain_multiplier()
	return rate

func get_fridge_regen_rate() -> float:
	var lvl := clampi(fridge_upgrade_level, 0, FRIDGE_UPGRADE_SPECS.size() - 1)
	var rate := 100.0 / float(FRIDGE_UPGRADE_SPECS[lvl]["regen_sec"])
	if has_mayari_card(MayariCardRegistry.CARD_FROST_OF_BIRINGAN):
		rate *= 1.40
	return rate

func get_fridge_upgrade_item(level: int) -> ItemData:
	var lvl := clampi(level, 1, FRIDGE_UPGRADE_SPECS.size() - 1)
	if _fridge_upgrade_item_cache.has(lvl):
		return _fridge_upgrade_item_cache[lvl]
	var spec: Dictionary = FRIDGE_UPGRADE_SPECS[lvl]
	var item := ItemData.new()
	item.item_name = str(spec["name"])
	item.price = float(spec["cost"])
	item.can_be_sold = false
	item.tier = 1
	item.category = "fridge_upgrade"
	if ResourceLoader.exists("res://Assets/ui/fridge.png"):
		item.texture = load("res://Assets/ui/fridge.png")
	elif ResourceLoader.exists("res://Assets/items/icons/2_bottle_water.png"):
		item.texture = load("res://Assets/items/icons/2_bottle_water.png")
	item.set_meta("is_fridge_upgrade", true)
	item.set_meta("fridge_level", lvl)
	item.set_meta("req_level", int(spec["req_level"]))
	item.set_meta("upgrade_desc", str(spec["desc"]))
	item.set_meta("drain_sec", float(spec["drain_sec"]))
	item.set_meta("regen_sec", float(spec["regen_sec"]))
	_fridge_upgrade_item_cache[lvl] = item
	return item

func purchase_fridge_upgrade(level: int) -> void:
	var target := clampi(level, 1, FRIDGE_UPGRADE_SPECS.size() - 1)
	if target <= fridge_upgrade_level:
		return
	fridge_upgrade_level = target
	LogManager.info("StoryManager", "Fridge upgraded to Level %d (%s)" % [fridge_upgrade_level, FRIDGE_UPGRADE_SPECS[fridge_upgrade_level]["name"]])
	EventBus.fridge_upgraded.emit(fridge_upgrade_level)
	_save_progression()

# --- Store Cats (Counter Slots 1 -> 2 -> 3) ---
const CAT_UPGRADE_SPECS: Array[Dictionary] = [
	{"level": 0, "req_level": 1, "name": "No Store Cat", "cost": 0.0, "slots": 1, "desc": "One neighbor at the counter at a time."},
	{"level": 1, "req_level": 2, "name": "Mingming", "cost": 75.0, "slots": 2, "desc": "Adopt Mingming the sleepy orange tabby! Unlocks a 2nd counter slot so 2 neighbors can visit at once."},
	{"level": 2, "req_level": 6, "name": "Cat Food", "cost": 150.0, "slots": 3, "desc": "Keep Mingming happy and well-fed! Neighbors flock to see your pampered store cat — unlocks all 3 counter slots."},
]
var cat_upgrade_level: int = 0
var _cat_upgrade_item_cache: Dictionary = {}

func get_max_counter_slots() -> int:
	var bonus := 1 if has_mayari_card(MayariCardRegistry.CARD_CROWDED_STOOP) else 0
	if is_instance_valid(StoreEventManager):
		bonus += StoreEventManager.get_extra_counter_slots()
	return clampi(1 + cat_upgrade_level + bonus, 1, 3)

func get_cat_upgrade_item(level: int) -> ItemData:
	var lvl := clampi(level, 1, CAT_UPGRADE_SPECS.size() - 1)
	if _cat_upgrade_item_cache.has(lvl):
		return _cat_upgrade_item_cache[lvl]
	var spec: Dictionary = CAT_UPGRADE_SPECS[lvl]
	var item := ItemData.new()
	item.item_name = str(spec["name"])
	item.price = float(spec["cost"])
	item.can_be_sold = false
	item.tier = 1
	item.category = "cat_upgrade"
	if ResourceLoader.exists("res://Assets/ui/cat.png"):
		item.texture = load("res://Assets/ui/cat.png")
	item.set_meta("is_cat_upgrade", true)
	item.set_meta("is_store_prop_upgrade", true)
	item.set_meta("cat_level", lvl)
	item.set_meta("req_level", int(spec["req_level"]))
	item.set_meta("upgrade_desc", str(spec["desc"]))
	item.set_meta("slots", int(spec["slots"]))
	item.set_meta("delivery_dialogue_label", "CatUpgradeDelivery%d" % lvl)
	_cat_upgrade_item_cache[lvl] = item
	return item

func purchase_cat_upgrade(level: int) -> void:
	var target := clampi(level, 1, CAT_UPGRADE_SPECS.size() - 1)
	if target <= cat_upgrade_level:
		return
	cat_upgrade_level = target
	LogManager.info("StoryManager", "Store Cat upgraded to Level %d (%s, %d counter slots)" % [cat_upgrade_level, CAT_UPGRADE_SPECS[cat_upgrade_level]["name"], get_max_counter_slots()])
	EventBus.cat_upgraded.emit(cat_upgrade_level)
	if get_tree():
		get_tree().call_group("store_cats", "refresh_visibility", true)
	_save_progression()

# --- Store Props (Trash Can) ---
const TRASH_CAN_COST := 40.0
var has_trash_can: bool = false
var _trash_can_upgrade_item: ItemData = null

func get_trash_can_upgrade_item() -> ItemData:
	if _trash_can_upgrade_item != null:
		return _trash_can_upgrade_item
	var item := ItemData.new()
	item.item_name = "Store Trash Can"
	item.price = TRASH_CAN_COST
	item.can_be_sold = false
	item.tier = 1
	item.category = "store_prop"
	if ResourceLoader.exists("res://Assets/ui/trash.png"):
		item.texture = load("res://Assets/ui/trash.png")
	item.set_meta("is_trash_upgrade", true)
	item.set_meta("is_store_prop_upgrade", true)
	item.set_meta("req_level", 1)
	item.set_meta("upgrade_desc", "A sturdy bin in the corner for tossing unwanted or extra stock.")
	item.set_meta("delivery_dialogue_label", "TrashCanUpgradeDelivery")
	_trash_can_upgrade_item = item
	return item

func purchase_trash_can_upgrade() -> void:
	if has_trash_can:
		return
	has_trash_can = true
	LogManager.info("StoryManager", "Store Trash Can unlocked.")
	EventBus.trash_can_unlocked.emit()
	if get_tree():
		get_tree().call_group("trash", "refresh_visibility", true)
	_save_progression()

# --- Recycling Program (Trash Can II): trashed stock refunds a share of its original value ---
const RECYCLING_COST := 90.0
const RECYCLING_REFUND_PCT := 0.5
var has_recycling: bool = false
var _recycling_upgrade_item: ItemData = null

func get_recycling_upgrade_item() -> ItemData:
	if _recycling_upgrade_item != null:
		return _recycling_upgrade_item
	var item := ItemData.new()
	item.item_name = "Recycling Program"
	item.price = RECYCLING_COST
	item.can_be_sold = false
	item.tier = 1
	item.category = "store_prop"
	if ResourceLoader.exists("res://Assets/ui/trash.png"):
		item.texture = load("res://Assets/ui/trash.png")
	item.set_meta("is_recycling_upgrade", true)
	item.set_meta("is_store_prop_upgrade", true)
	item.set_meta("req_level", 4)
	item.set_meta("upgrade_desc", "Sort the junk! Trashing an item refunds 50% of its original value.")
	item.set_meta("delivery_dialogue_label", "RecyclingUpgradeDelivery")
	_recycling_upgrade_item = item
	return item

func purchase_recycling_upgrade() -> void:
	if has_recycling:
		return
	has_recycling = true
	LogManager.info("StoryManager", "Recycling Program unlocked.")
	_save_progression()

## Pesos refunded for trashing one unit of this item (0 until Recycling is owned).
func get_recycling_refund(item: ItemData) -> float:
	if not has_recycling or item == null or not item.can_be_sold:
		return 0.0
	return snappedf(item.price * RECYCLING_REFUND_PCT, 0.01)

# --- Lucky Waving Cat: Maneki-Neko (Brings Wealth -> Cash Sale Tip Bonus) ---
const MANEKI_UPGRADE_SPECS: Array[Dictionary] = [
	{"level": 0, "req_level": 1, "name": "No Waving Cat", "cost": 0.0, "customer_hours": 4.0, "visit_hours": 2.0, "tip_bonus_pct": 0.0, "desc": "Standard neighbor tips on cash sales."},
	{"level": 1, "req_level": 3, "name": "Lucky Waving Cat (Maneki-Neko)", "cost": 80.0, "customer_hours": 4.0, "visit_hours": 2.0, "tip_bonus_pct": 0.10, "desc": "A beckoning porcelain cat on your counter! Brings good fortune with +10% bonus tips on every cash sale."},
	{"level": 2, "req_level": 8, "name": "Fresh Batteries (Maneki-Neko)", "cost": 165.0, "customer_hours": 4.0, "visit_hours": 2.0, "tip_bonus_pct": 0.22, "desc": "Fresh batteries keep the paw waving briskly all day! Attracts abundant wealth with +22% bonus tips on every cash sale."},
]
var maneki_upgrade_level: int = 0
var _maneki_upgrade_item_cache: Dictionary = {}

func get_customer_time_window_hours() -> float:
	var lvl := clampi(maneki_upgrade_level, 0, MANEKI_UPGRADE_SPECS.size() - 1)
	return float(MANEKI_UPGRADE_SPECS[lvl]["customer_hours"])

func get_maneki_tip_bonus_pct() -> float:
	var lvl := clampi(maneki_upgrade_level, 0, MANEKI_UPGRADE_SPECS.size() - 1)
	return float(MANEKI_UPGRADE_SPECS[lvl].get("tip_bonus_pct", 0.0))

func get_visit_time_window_hours() -> float:
	var lvl := clampi(maneki_upgrade_level, 0, MANEKI_UPGRADE_SPECS.size() - 1)
	return float(MANEKI_UPGRADE_SPECS[lvl]["visit_hours"])

func get_maneki_upgrade_item(level: int) -> ItemData:
	var lvl := clampi(level, 1, MANEKI_UPGRADE_SPECS.size() - 1)
	if _maneki_upgrade_item_cache.has(lvl):
		return _maneki_upgrade_item_cache[lvl]
	var spec: Dictionary = MANEKI_UPGRADE_SPECS[lvl]
	var item := ItemData.new()
	item.item_name = str(spec["name"])
	item.price = float(spec["cost"])
	item.can_be_sold = false
	item.tier = 1
	item.category = "maneki_upgrade"
	if ResourceLoader.exists("res://Assets/ui/manekineko.png"):
		item.texture = load("res://Assets/ui/manekineko.png")
	elif ResourceLoader.exists("res://Assets/ui/cat.png"):
		item.texture = load("res://Assets/ui/cat.png")
	item.set_meta("is_maneki_upgrade", true)
	item.set_meta("is_store_prop_upgrade", true)
	item.set_meta("maneki_level", lvl)
	item.set_meta("req_level", int(spec["req_level"]))
	item.set_meta("customer_hours", float(spec["customer_hours"]))
	item.set_meta("visit_hours", float(spec["visit_hours"]))
	item.set_meta("upgrade_desc", str(spec["desc"]))
	_maneki_upgrade_item_cache[lvl] = item
	return item

func purchase_maneki_upgrade(level: int) -> void:
	var target := clampi(level, 1, MANEKI_UPGRADE_SPECS.size() - 1)
	if target <= maneki_upgrade_level:
		return
	maneki_upgrade_level = target
	LogManager.info("StoryManager", "Maneki-Neko upgraded to Level %d (%s: %.1fh customer / %.1fh visit)" % [
		maneki_upgrade_level,
		MANEKI_UPGRADE_SPECS[maneki_upgrade_level]["name"],
		get_customer_time_window_hours(),
		get_visit_time_window_hours()
	])
	if get_tree():
		get_tree().call_group("store_maneki", "refresh_visibility", true)
	_save_progression()

# --- Barangay Transistor Radio (Papa Ulap Broadcasts, Daily Events & Today's Visitors) ---
const RADIO_UPGRADE_SPECS: Array[Dictionary] = [
	{"level": 0, "req_level": 1, "name": "No Radio", "cost": 0.0, "reveals": 0, "max_events": 1, "desc": "Daily Market Events and Today's Visitors stay hidden."},
	{"level": 1, "req_level": 1, "name": "Counter Transistor Radio", "cost": 50.0, "reveals": 1, "max_events": 1, "desc": "Places a Counter Radio tuned to Papa Ulap! Tune in every 1.5h to reveal today's Market Event or a Daily Visitor."},
	{"level": 2, "req_level": 4, "name": "Copper Tuning Coil", "cost": 95.0, "reveals": 2, "max_events": 2, "desc": "Stronger reception — unlocks +1 possible Market Event daily and up to 2 Daily Visitor sightings on the radio."},
	{"level": 3, "req_level": 7, "name": "High-Gain Signal Amplifier", "cost": 155.0, "reveals": 4, "max_events": 3, "desc": "Crystal-clear airwaves! Unlocks up to 3 Market Events daily and reveals all of Today's Visitors via Papa Ulap."},
]
var radio_upgrade_level: int = 0
var _radio_upgrade_item_cache: Dictionary = {}

func get_revealed_regular_count() -> int:
	if has_mayari_card(MayariCardRegistry.CARD_STATIC_AIRWAVES):
		return 0
	var lvl := clampi(radio_upgrade_level, 0, RADIO_UPGRADE_SPECS.size() - 1)
	return int(RADIO_UPGRADE_SPECS[lvl]["reveals"])

func get_max_daily_events() -> int:
	if has_mayari_card(MayariCardRegistry.CARD_QUIET_ECLIPSE):
		return 0
	var lvl := clampi(radio_upgrade_level, 0, RADIO_UPGRADE_SPECS.size() - 1)
	var base := int(RADIO_UPGRADE_SPECS[lvl].get("max_events", 1))
	if has_mayari_card(MayariCardRegistry.CARD_ECHOES_ON_THE_DIAL):
		base += 1
	return base

func get_radio_upgrade_item(level: int) -> ItemData:
	var lvl := clampi(level, 1, RADIO_UPGRADE_SPECS.size() - 1)
	if _radio_upgrade_item_cache.has(lvl):
		return _radio_upgrade_item_cache[lvl]
	var spec: Dictionary = RADIO_UPGRADE_SPECS[lvl]
	var item := ItemData.new()
	item.item_name = str(spec["name"])
	item.price = float(spec["cost"])
	item.can_be_sold = false
	item.tier = 1
	item.category = "radio_upgrade"
	if ResourceLoader.exists("res://Assets/ui/Radio.png"):
		item.texture = load("res://Assets/ui/Radio.png")
	elif ResourceLoader.exists("res://Assets/ui/nokia2d.png"):
		item.texture = load("res://Assets/ui/nokia2d.png")
	item.set_meta("is_radio_upgrade", true)
	item.set_meta("is_store_prop_upgrade", true)
	item.set_meta("radio_level", lvl)
	item.set_meta("req_level", int(spec["req_level"]))
	item.set_meta("reveals", int(spec["reveals"]))
	item.set_meta("max_events", int(spec.get("max_events", 1)))
	item.set_meta("upgrade_desc", str(spec["desc"]))
	_radio_upgrade_item_cache[lvl] = item
	return item

func purchase_radio_upgrade(level: int) -> void:
	var target := clampi(level, 1, RADIO_UPGRADE_SPECS.size() - 1)
	if target <= radio_upgrade_level:
		return
	radio_upgrade_level = target
	ensure_daily_demand_rolled()
	if is_instance_valid(StoreEventManager) and StoreEventManager.has_method("roll_bonus_slots_for_radio_upgrade"):
		StoreEventManager.roll_bonus_slots_for_radio_upgrade()
	LogManager.info("StoryManager", "Barangay Radio upgraded to Level %d (%s, max_events=%d, reveals=%d regulars)" % [
		radio_upgrade_level,
		RADIO_UPGRADE_SPECS[radio_upgrade_level]["name"],
		get_max_daily_events(),
		get_revealed_regular_count()
	])
	EventBus.radio_upgraded.emit(radio_upgrade_level)
	EventBus.restock_catalog_refresh.emit()
	_save_progression()

# --- Uncle Mario's Wholesale Pass I → II (Daily Sulit Deals) ---
const MARIO_DEALS_COST := 75.0
## "items" = deals rolled per day, "mult" = restock price multiplier on deal items.
const MARIO_DEALS_SPECS: Array[Dictionary] = [
	{"level": 0, "cost": 0.0, "req_level": 1, "items": 0, "mult": 1.0, "blessed_mult": 1.0},
	{"level": 1, "cost": 75.0, "req_level": 3, "items": 2, "mult": 0.80, "blessed_mult": 0.65},
	{"level": 2, "cost": 150.0, "req_level": 6, "items": 5, "mult": 0.70, "blessed_mult": 0.55},
]
var mario_deals_level: int = 0
var has_mario_deals: bool = false # true once Pass I is owned
var _mario_deals_upgrade_items: Dictionary = {}

func get_sulit_deal_count() -> int:
	return int(MARIO_DEALS_SPECS[clampi(mario_deals_level, 0, MARIO_DEALS_SPECS.size() - 1)]["items"])

func get_mario_deals_upgrade_item(level: int = 1) -> ItemData:
	var lvl := clampi(level, 1, MARIO_DEALS_SPECS.size() - 1)
	if _mario_deals_upgrade_items.has(lvl):
		return _mario_deals_upgrade_items[lvl]
	var spec: Dictionary = MARIO_DEALS_SPECS[lvl]
	var item := ItemData.new()
	item.item_name = "Uncle Mario's Wholesale Pass" if lvl == 1 else "Wholesale Pass II: Bulk Contract"
	item.price = float(spec["cost"])
	item.can_be_sold = false
	item.tier = 1
	item.category = "mario_deals_upgrade"
	if ResourceLoader.exists("res://Assets/ui/wholesale_pass.png"):
		item.texture = load("res://Assets/ui/wholesale_pass.png")
	elif ResourceLoader.exists("res://Assets/ui/mario_tricycle.png"):
		item.texture = load("res://Assets/ui/mario_tricycle.png")
	item.set_meta("is_mario_deals_upgrade", true)
	item.set_meta("is_store_prop_upgrade", true)
	item.set_meta("mario_deals_level", lvl)
	item.set_meta("req_level", int(spec["req_level"]))
	if lvl == 1:
		item.set_meta("upgrade_desc", "Unlocks Uncle Mario's Daily Sulit Deals (+2 items at 20% off wholesale) and cuts his restock cooldown by 30% (5h → 3.5h).")
	else:
		item.set_meta("upgrade_desc", "Mario brings bulk contracts: +3 more Daily Sulit Deals (5 total) and a deeper wholesale discount (30% off).")
	_mario_deals_upgrade_items[lvl] = item
	return item

func purchase_mario_deals_upgrade(level: int = 1) -> void:
	var target := clampi(level, 1, MARIO_DEALS_SPECS.size() - 1)
	if target <= mario_deals_level:
		return
	mario_deals_level = target
	has_mario_deals = true
	_roll_daily_sulit_deals()
	LogManager.info("StoryManager", "Uncle Mario's Wholesale Pass level %d unlocked (%d Sulit Deals active today)." % [mario_deals_level, todays_sulit_deals.size()])
	EventBus.restock_catalog_refresh.emit()
	_save_progression()

# --- Sto. Niño Altar Blessings (Random Favors on Tap) ---
const STO_NINO_UPGRADE_SPECS: Array[Dictionary] = [
	{"level": 0, "req_level": 1, "name": "No Sto. Niño Altar", "cost": 0.0, "duration_hours": 0.0, "favor_count": 0, "all_day": false, "desc": "Purchase the Sto. Niño Altar upgrade to pray for daily Favors."},
	{"level": 1, "req_level": 2, "name": "Sto. Niño Altar", "cost": 75.0, "duration_hours": 8.0, "favor_count": 1, "all_day": false, "desc": "Places a blessed Sto. Niño statue on your altar! Tap Sto. Niño for 1 random Favor lasting 8 hours (only 2 taps for the whole day)."},
	{"level": 2, "req_level": 5, "name": "Double Devotion", "cost": 140.0, "duration_hours": 8.0, "favor_count": 2, "all_day": false, "desc": "Earn Sto. Niño's abundant grace. Grants 2 distinct random Favors at once for 8 hours!"},
	{"level": 3, "req_level": 9, "name": "Perpetual Benediction", "cost": 225.0, "duration_hours": 0.0, "favor_count": 2, "all_day": true, "desc": "Unbroken protection over your tindahan. Sto. Niño's 2 Blessings last for the entire rest of the day — no re-tapping needed!"},
]
const STO_NINO_COOLDOWN_HOURS := 1.0
var sto_nino_upgrade_level: int = 0
var active_blessing_cards: Array[String] = []
var sto_nino_daily_blessings: Array[String] = [] # Pre-rolled for the day; re-tapping after cooldown grants the same blessing(s)
var sto_nino_blessing_start_hour: float = -1.0
var sto_nino_blessing_end_hour: float = -1.0
var sto_nino_cooldown_end_hour: float = -1.0
var sto_nino_blessing_all_day: bool = false
var _sto_nino_upgrade_item_cache: Dictionary = {}

func get_sto_nino_spec(level: int = -1) -> Dictionary:
	var lvl := sto_nino_upgrade_level if level < 0 else level
	lvl = clampi(lvl, 0, STO_NINO_UPGRADE_SPECS.size() - 1)
	return STO_NINO_UPGRADE_SPECS[lvl]

func get_sto_nino_upgrade_item(level: int) -> ItemData:
	var lvl := clampi(level, 1, STO_NINO_UPGRADE_SPECS.size() - 1)
	if _sto_nino_upgrade_item_cache.has(lvl):
		return _sto_nino_upgrade_item_cache[lvl]
	var spec: Dictionary = STO_NINO_UPGRADE_SPECS[lvl]
	var item := ItemData.new()
	item.item_name = str(spec["name"])
	item.price = float(spec["cost"])
	item.can_be_sold = false
	item.tier = 1
	item.category = "sto_nino_upgrade"
	if ResourceLoader.exists("res://Assets/ui/sto_nino2.png"):
		item.texture = load("res://Assets/ui/sto_nino2.png")
	item.set_meta("is_sto_nino_upgrade", true)
	item.set_meta("is_store_prop_upgrade", true)
	item.set_meta("sto_nino_level", lvl)
	item.set_meta("req_level", int(spec["req_level"]))
	item.set_meta("duration_hours", float(spec["duration_hours"]))
	item.set_meta("favor_count", int(spec["favor_count"]))
	item.set_meta("all_day", bool(spec["all_day"]))
	item.set_meta("upgrade_desc", str(spec["desc"]))
	_sto_nino_upgrade_item_cache[lvl] = item
	return item

func purchase_sto_nino_upgrade(level: int) -> void:
	var target := clampi(level, 1, STO_NINO_UPGRADE_SPECS.size() - 1)
	if target <= sto_nino_upgrade_level:
		return
	sto_nino_upgrade_level = target
	var spec := get_sto_nino_spec()
	if bool(spec["all_day"]) and not active_blessing_cards.is_empty():
		sto_nino_blessing_all_day = true
		sto_nino_blessing_end_hour = -1.0
		EventBus.sto_nino_blessing_changed.emit()
	LogManager.info("StoryManager", "Sto. Niño upgraded to Level %d (%s)" % [sto_nino_upgrade_level, str(spec["name"])])
	EventBus.sto_nino_upgraded.emit(sto_nino_upgrade_level)
	_save_progression()

func has_active_sto_nino_blessing() -> bool:
	check_sto_nino_blessing_expiry()
	return not active_blessing_cards.is_empty()

func get_sto_nino_blessing_progress() -> float:
	if active_blessing_cards.is_empty() or sto_nino_blessing_all_day:
		return 0.0
	if sto_nino_blessing_start_hour < 0.0 or sto_nino_blessing_end_hour <= sto_nino_blessing_start_hour:
		return 0.0
	var span := sto_nino_blessing_end_hour - sto_nino_blessing_start_hour
	return clampf((clock.current_display_time - sto_nino_blessing_start_hour) / span, 0.0, 1.0)

func get_sto_nino_blessing_remaining_hours() -> float:
	if active_blessing_cards.is_empty() or sto_nino_blessing_all_day or sto_nino_blessing_end_hour < 0.0:
		return 0.0
	return maxf(0.0, sto_nino_blessing_end_hour - clock.current_display_time)

func get_sto_nino_cooldown_remaining_hours() -> float:
	if sto_nino_cooldown_end_hour < 0.0:
		return 0.0
	var rem := sto_nino_cooldown_end_hour - clock.current_display_time
	if rem <= 0.01:
		sto_nino_cooldown_end_hour = -1.0
		return 0.0
	return rem

func is_sto_nino_on_cooldown() -> bool:
	return get_sto_nino_cooldown_remaining_hours() > 0.0

func _ensure_daily_sto_nino_blessings(want_count: int, is_all_day: bool) -> Array[String]:
	if sto_nino_daily_blessings.size() >= want_count:
		return sto_nino_daily_blessings.slice(0, want_count)
	var pool: Array[String] = []
	for card_id in MayariCardRegistry.CARDS.keys():
		if not MayariCardRegistry.is_favor(card_id):
			continue
		if not is_all_day and card_id == MayariCardRegistry.CARD_MOON_HOLDS_SKY:
			continue
		if card_id in sto_nino_daily_blessings:
			continue
		pool.append(card_id)
	pool.shuffle()
	while sto_nino_daily_blessings.size() < want_count and not pool.is_empty():
		sto_nino_daily_blessings.append(pool.pop_back())
	return sto_nino_daily_blessings.duplicate()

func activate_sto_nino_blessing() -> Array[String]:
	if sto_nino_upgrade_level < 1:
		return []
	check_sto_nino_blessing_expiry()
	if not active_blessing_cards.is_empty() or is_sto_nino_on_cooldown():
		return []
	var spec := get_sto_nino_spec()
	var want_count: int = int(spec["favor_count"])
	var duration_h: float = float(spec["duration_hours"])
	var is_all_day: bool = bool(spec["all_day"])

	var granted := _ensure_daily_sto_nino_blessings(want_count, is_all_day)
	if granted.is_empty():
		return []

	active_blessing_cards = granted
	sto_nino_blessing_all_day = is_all_day
	sto_nino_blessing_start_hour = clock.current_display_time
	sto_nino_blessing_end_hour = -1.0 if is_all_day else (clock.current_display_time + duration_h)
	sto_nino_cooldown_end_hour = -1.0
	record_daily_stat_int("sto_nino_taps", 1)
	for g_id in granted:
		record_daily_list_entry("blessings_used", g_id, false)
	LogManager.info("StoryManager", "Sto. Niño Blessing granted: %s (all_day=%s, start=%.2f, end=%.2f)" % [
		str(granted), str(is_all_day), sto_nino_blessing_start_hour, sto_nino_blessing_end_hour
	])
	EventBus.sto_nino_blessing_changed.emit()
	_save_progression()
	return granted

func check_sto_nino_blessing_expiry() -> void:
	if sto_nino_cooldown_end_hour >= 0.0 and clock.current_display_time >= sto_nino_cooldown_end_hour - 0.01:
		sto_nino_cooldown_end_hour = -1.0
		if sto_nino_upgrade_level >= 1 and not is_past_closing_time():
			EventBus.show_notification.emit("Sto. Niño Ready", "Tap Sto. Niño again to renew today's blessing.", "interact")
	if active_blessing_cards.is_empty() or sto_nino_blessing_all_day or sto_nino_blessing_end_hour < 0.0:
		return
	if clock.current_display_time >= sto_nino_blessing_end_hour:
		active_blessing_cards.clear()
		sto_nino_blessing_start_hour = -1.0
		sto_nino_blessing_end_hour = -1.0
		sto_nino_cooldown_end_hour = clock.current_display_time + STO_NINO_COOLDOWN_HOURS
		LogManager.info("StoryManager", "Sto. Niño Blessing expired at %.2fh (cooldown until %.2fh)." % [clock.current_display_time, sto_nino_cooldown_end_hour])
		EventBus.sto_nino_blessing_changed.emit()
		EventBus.show_notification.emit("Sto. Niño's Blessing Faded", "Rest a moment — Sto. Niño will be ready again in 1 hour.", "interact")
		_save_progression()

func _clear_sto_nino_blessing() -> void:
	active_blessing_cards.clear()
	sto_nino_daily_blessings.clear()
	sto_nino_blessing_start_hour = -1.0
	sto_nino_blessing_end_hour = -1.0
	sto_nino_cooldown_end_hour = -1.0
	sto_nino_blessing_all_day = false
	EventBus.sto_nino_blessing_changed.emit()

# --- Framed Business Permit (Permanent Player XP Multiplier) ---
const PERMIT_UPGRADE_SPECS: Array[Dictionary] = [
	{"level": 0, "req_level": 1, "name": "No Business Permit", "cost": 0.0, "xp_mult": 1.0, "desc": "Standard Player XP gain."},
	{"level": 1, "req_level": 2, "name": "Barangay Business Permit", "cost": 70.0, "xp_mult": 1.15, "desc": "Official framed permit displayed in your shop. Permanently grants +15% Player XP from all sales, visits, and stories."},
	{"level": 2, "req_level": 5, "name": "Municipal Store Accreditation", "cost": 140.0, "xp_mult": 1.30, "desc": "Recognized across the town of Karimlan. Permanently boosts Player XP gain to +30%."},
	{"level": 3, "req_level": 9, "name": "Karimlan Heritage Recognition", "cost": 230.0, "xp_mult": 1.50, "desc": "Honored as a beloved neighborhood landmark. Permanently boosts Player XP gain to +50%."},
]
var permit_upgrade_level: int = 0
var _permit_upgrade_item_cache: Dictionary = {}

func get_permit_xp_multiplier() -> float:
	var lvl := clampi(permit_upgrade_level, 0, PERMIT_UPGRADE_SPECS.size() - 1)
	return float(PERMIT_UPGRADE_SPECS[lvl]["xp_mult"])

func get_permit_upgrade_item(level: int) -> ItemData:
	var lvl := clampi(level, 1, PERMIT_UPGRADE_SPECS.size() - 1)
	if _permit_upgrade_item_cache.has(lvl):
		return _permit_upgrade_item_cache[lvl]
	var spec: Dictionary = PERMIT_UPGRADE_SPECS[lvl]
	var item := ItemData.new()
	item.item_name = str(spec["name"])
	item.price = float(spec["cost"])
	item.can_be_sold = false
	item.tier = 1
	item.category = "permit_upgrade"
	if ResourceLoader.exists("res://Assets/ui/picture_frame_stand.png"):
		item.texture = load("res://Assets/ui/picture_frame_stand.png")
	item.set_meta("is_permit_upgrade", true)
	item.set_meta("is_store_prop_upgrade", true)
	item.set_meta("permit_level", lvl)
	item.set_meta("req_level", int(spec["req_level"]))
	item.set_meta("xp_mult", float(spec["xp_mult"]))
	item.set_meta("upgrade_desc", str(spec["desc"]))
	_permit_upgrade_item_cache[lvl] = item
	return item

func purchase_permit_upgrade(level: int) -> void:
	var target := clampi(level, 1, PERMIT_UPGRADE_SPECS.size() - 1)
	if target <= permit_upgrade_level:
		return
	permit_upgrade_level = target
	LogManager.info("StoryManager", "Business Permit upgraded to Level %d (%s, %.0f%% XP)" % [
		permit_upgrade_level,
		str(PERMIT_UPGRADE_SPECS[permit_upgrade_level]["name"]),
		get_permit_xp_multiplier() * 100.0
	])
	EventBus.permit_upgraded.emit(permit_upgrade_level)
	_save_progression()

# --- Sari-Sari Tambayan Bench (Lingering Visitors, Passive XP & Return-to-Buy) ---
const BENCH_UPGRADE_SPECS: Array[Dictionary] = [
	{"level": 0, "req_level": 1, "name": "No Store Bench", "cost": 0.0, "linger_chance": 0.60, "max_lingering": 2, "passive_xp": 1, "smalltalk_xp": 0, "return_to_buy": false, "desc": "Up to 2 visitors may linger outside (60% chance), granting +1 passive Player XP every 2s per lingering visitor."},
	{"level": 1, "req_level": 2, "name": "Sari-Sari Tambayan Bench", "cost": 75.0, "linger_chance": 0.75, "max_lingering": 3, "passive_xp": 1, "smalltalk_xp": 0, "return_to_buy": false, "desc": "Places a cozy wooden bench outside your tindahan! Boosts lingering chance (60% → 75%) and lets up to 3 neighbors hang out at once (+1 passive XP / 2s each)."},
	{"level": 2, "req_level": 5, "name": "Tambayan Hospitality", "cost": 145.0, "linger_chance": 0.75, "max_lingering": 3, "passive_xp": 2, "smalltalk_xp": 8, "return_to_buy": false, "desc": "Neighbors love chatting by your bench! Doubles passive Player XP from lingering visitors (+1 → +2 XP every 2s each), plus +8 bonus XP when they return for smalltalk."},
	{"level": 3, "req_level": 8, "name": "Craving Comebacks", "cost": 215.0, "linger_chance": 0.75, "max_lingering": 3, "passive_xp": 2, "smalltalk_xp": 8, "return_to_buy": true, "desc": "Hanging out works up an appetite! Returning tambayan visitors now have a chance to step back up and place a real purchase order before heading home."},
]
var bench_upgrade_level: int = 0
var _bench_upgrade_item_cache: Dictionary = {}

func get_bench_spec(level: int = -1) -> Dictionary:
	var lvl := bench_upgrade_level if level < 0 else level
	lvl = clampi(lvl, 0, BENCH_UPGRADE_SPECS.size() - 1)
	return BENCH_UPGRADE_SPECS[lvl]

func get_bench_linger_chance() -> float:
	var ch := float(get_bench_spec()["linger_chance"])
	if has_mayari_card(MayariCardRegistry.CARD_TAMBAYAN_WARMTH):
		ch += 0.25
	if is_instance_valid(StoreEventManager):
		ch += StoreEventManager.get_linger_chance_bonus()
	return minf(0.95, ch)

func get_bench_max_lingering() -> int:
	var mx := int(get_bench_spec()["max_lingering"])
	if has_mayari_card(MayariCardRegistry.CARD_TAMBAYAN_WARMTH):
		mx += 1
	return mx

func get_bench_passive_xp() -> int:
	var pxp := int(get_bench_spec()["passive_xp"])
	if has_mayari_card(MayariCardRegistry.CARD_TAMBAYAN_WARMTH):
		pxp = maxi(2, pxp * 2)
	return pxp

func get_bench_smalltalk_xp() -> int:
	return int(get_bench_spec()["smalltalk_xp"])

func can_bench_return_to_buy() -> bool:
	return bool(get_bench_spec()["return_to_buy"]) or has_mayari_card(MayariCardRegistry.CARD_TAMBAYAN_WARMTH)

func get_bench_upgrade_item(level: int) -> ItemData:
	var lvl := clampi(level, 1, BENCH_UPGRADE_SPECS.size() - 1)
	if _bench_upgrade_item_cache.has(lvl):
		return _bench_upgrade_item_cache[lvl]
	var spec: Dictionary = BENCH_UPGRADE_SPECS[lvl]
	var item := ItemData.new()
	item.item_name = str(spec["name"])
	item.price = float(spec["cost"])
	item.can_be_sold = false
	item.tier = 1
	item.category = "bench_upgrade"
	if ResourceLoader.exists("res://Assets/ui/bench.png"):
		item.texture = load("res://Assets/ui/bench.png")
	elif ResourceLoader.exists("res://Assets/ui/trophy.png"):
		item.texture = load("res://Assets/ui/trophy.png")
	item.set_meta("is_bench_upgrade", true)
	item.set_meta("is_store_prop_upgrade", true)
	item.set_meta("bench_level", lvl)
	item.set_meta("req_level", int(spec["req_level"]))
	item.set_meta("linger_chance", float(spec["linger_chance"]))
	item.set_meta("max_lingering", int(spec["max_lingering"]))
	item.set_meta("passive_xp", int(spec["passive_xp"]))
	item.set_meta("smalltalk_xp", int(spec["smalltalk_xp"]))
	item.set_meta("return_to_buy", bool(spec["return_to_buy"]))
	item.set_meta("upgrade_desc", str(spec["desc"]))
	_bench_upgrade_item_cache[lvl] = item
	return item

func purchase_bench_upgrade(level: int) -> void:
	var target := clampi(level, 1, BENCH_UPGRADE_SPECS.size() - 1)
	if target <= bench_upgrade_level:
		return
	bench_upgrade_level = target
	LogManager.info("StoryManager", "Store Bench upgraded to Level %d (%s)" % [
		bench_upgrade_level,
		str(BENCH_UPGRADE_SPECS[bench_upgrade_level]["name"])
	])
	EventBus.bench_upgraded.emit(bench_upgrade_level)
	if get_tree():
		get_tree().call_group("store_bench", "refresh_visibility", true)
	_save_progression()

# --- Storefront Customization (Lv.1 Signage -> Lv.2 Promo Poster -> Lv.3 Open Door) ---
const SIGNAGE_IMAGE_PATH := "user://custom_signage.png"
const SIGNAGE_PAINT_PATH := "user://custom_signage_paint.png"
const POSTER_IMAGE_PATH := "user://custom_poster.png"
const POSTER_PAINT_PATH := "user://custom_poster_paint.png"

const STOREFRONT_UPGRADE_SPECS: Array[Dictionary] = [
	{"level": 0, "req_level": 1, "name": "Standard Storefront", "cost": 0.0, "tip_chance": 0.0, "price_relief": 0.0, "desc": "Classic neighborhood sari-sari storefront."},
	{"level": 1, "req_level": 2, "name": "Hand-Drawn Roof Signage", "cost": 70.0, "tip_chance": 0.15, "price_relief": 0.15, "desc": "Paint your own giant roof signboard! Grants +15% Appreciation Tip chance (₱3–₱6) on cash sales, softens markup pushback, and displays on the Main Menu."},
	{"level": 2, "req_level": 5, "name": "Storefront Promo Poster", "cost": 135.0, "tip_chance": 0.25, "price_relief": 0.25, "desc": "Mount a custom portrait poster in front of the store! Add 3+ product stickers of one category to activate a Featured Category (+demand & +₱3 promo bonus)."},
	{"level": 3, "req_level": 10, "name": "Open Door", "cost": 290.0, "tip_chance": 0.30, "price_relief": 0.30, "desc": "A tarnished brass key hangs quietly behind the counter... Unlocks the store door so you can finally step outside and wander Karimlan."},
]

var storefront_upgrade_level: int = 0
var has_custom_signage: bool = false
var has_custom_poster: bool = false
var signage_featured_category: String = ""
var signage_last_edited_day: int = -1
var poster_featured_category: String = ""
var custom_signage_stickers: Array[Dictionary] = []
var custom_poster_stickers: Array[Dictionary] = []
var custom_recent_colors: Array[String] = []
var _storefront_upgrade_item_cache: Dictionary = {}

func get_storefront_tip_chance() -> float:
	var lvl := clampi(storefront_upgrade_level, 0, STOREFRONT_UPGRADE_SPECS.size() - 1)
	var ch := float(STOREFRONT_UPGRADE_SPECS[lvl]["tip_chance"])
	if has_mayari_card(MayariCardRegistry.CARD_CURBSIDE_GLOW):
		ch += 0.15
	return clampf(ch, 0.0, 0.90)

func get_storefront_price_relief() -> float:
	var lvl := clampi(storefront_upgrade_level, 0, STOREFRONT_UPGRADE_SPECS.size() - 1)
	return float(STOREFRONT_UPGRADE_SPECS[lvl]["price_relief"])

func get_signage_featured_category() -> String:
	return ""

func get_poster_featured_category() -> String:
	if storefront_upgrade_level >= 2 and has_custom_poster:
		return poster_featured_category
	return ""

func get_active_featured_categories() -> Array[String]:
	var cats: Array[String] = []
	var sc := get_signage_featured_category()
	if sc != "" and not cats.has(sc):
		cats.append(sc)
	var pc := get_poster_featured_category()
	if pc != "" and not cats.has(pc):
		cats.append(pc)
	return cats

func get_featured_category_boost_count(cat: String) -> int:
	if cat == "":
		return 0
	var count := 0
	if get_signage_featured_category() == cat:
		count += 1
	if get_poster_featured_category() == cat:
		count += 1
	return count

func can_edit_storefront_slot(slot_name: String) -> bool:
	if slot_name == "signage":
		return signage_last_edited_day != day
	return true

func get_category_display_name(cat: String) -> String:
	match cat.to_lower():
		"snack": return "Snacks"
		"can": return "Canned Goods"
		"bottle": return "Cold Drinks"
		"frozen": return "Frozen Treats"
		"candy": return "Candies"
		"sachet": return "Sachets"
		"pack": return "Instant Noodles & Packs"
		"cigarette": return "Cigarettes"
		_: return cat.capitalize()

func get_storefront_upgrade_item(level: int) -> ItemData:
	var lvl := clampi(level, 1, STOREFRONT_UPGRADE_SPECS.size() - 1)
	if _storefront_upgrade_item_cache.has(lvl):
		return _storefront_upgrade_item_cache[lvl]
	var spec: Dictionary = STOREFRONT_UPGRADE_SPECS[lvl]
	var item := ItemData.new()
	item.item_name = str(spec["name"])
	item.price = float(spec["cost"])
	item.can_be_sold = false
	item.tier = 1
	item.category = "storefront_upgrade"
	var icon_path := "res://Assets/3D/final store/textures/signage.png"
	if lvl == 2:
		icon_path = "res://Assets/3D/final store/textures/load_poster.png"
	elif lvl == 3:
		icon_path = "res://Assets/ui/door.png" if ResourceLoader.exists("res://Assets/ui/door.png") else "res://Assets/ui/picture_frame_stand.png"
	if ResourceLoader.exists(icon_path):
		item.texture = load(icon_path)
	item.set_meta("is_storefront_upgrade", true)
	item.set_meta("is_store_prop_upgrade", true)
	item.set_meta("storefront_level", lvl)
	item.set_meta("req_level", int(spec["req_level"]))
	item.set_meta("tip_chance", float(spec["tip_chance"]))
	item.set_meta("price_relief", float(spec["price_relief"]))
	item.set_meta("upgrade_desc", str(spec["desc"]))
	_storefront_upgrade_item_cache[lvl] = item
	return item

func purchase_storefront_upgrade(level: int) -> void:
	var target := clampi(level, 1, STOREFRONT_UPGRADE_SPECS.size() - 1)
	if target <= storefront_upgrade_level:
		return
	storefront_upgrade_level = target
	LogManager.info("StoryManager", "Storefront Customization upgraded to Level %d (%s)" % [
		storefront_upgrade_level,
		str(STOREFRONT_UPGRADE_SPECS[storefront_upgrade_level]["name"])
	])
	EventBus.storefront_upgraded.emit(storefront_upgrade_level)
	if get_tree():
		get_tree().call_group("storefront_custom_display", "refresh_display")
		get_tree().call_group("store_door", "refresh_lock_state")
	_save_progression()

func save_storefront_artwork(slot_name: String, stickers: Array[Dictionary], featured_cat: String, recent_colors: Array[String]) -> void:
	var cloned_stickers: Array[Dictionary] = []
	for s in stickers:
		if s is Dictionary:
			cloned_stickers.append(s.duplicate(true))
	if slot_name == "signage":
		custom_signage_stickers = cloned_stickers
		has_custom_signage = true
		signage_featured_category = ""
		signage_last_edited_day = day
	elif slot_name == "poster":
		custom_poster_stickers = cloned_stickers
		has_custom_poster = true
		poster_featured_category = featured_cat
	var sanitized_colors: Array[String] = []
	for col_hex in recent_colors:
		var s_col := str(col_hex)
		if s_col != "" and not sanitized_colors.has(s_col):
			sanitized_colors.append(s_col)
			if sanitized_colors.size() >= 12:
				break
	custom_recent_colors = sanitized_colors
	EventBus.storefront_artwork_updated.emit(slot_name)
	if get_tree():
		get_tree().call_group("storefront_custom_display", "refresh_display")
	_save_progression()

func delete_custom_artwork_files() -> void:
	for p in [SIGNAGE_IMAGE_PATH, SIGNAGE_PAINT_PATH, POSTER_IMAGE_PATH, POSTER_PAINT_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

func reset_storefront_artwork(slot_name: String) -> void:
	if slot_name == "signage":
		has_custom_signage = false
		custom_signage_stickers.clear()
		signage_featured_category = ""
		for p in [SIGNAGE_IMAGE_PATH, SIGNAGE_PAINT_PATH]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
	elif slot_name == "poster":
		has_custom_poster = false
		custom_poster_stickers.clear()
		poster_featured_category = ""
		for p in [POSTER_IMAGE_PATH, POSTER_PAINT_PATH]:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
	EventBus.storefront_artwork_updated.emit(slot_name)
	if get_tree():
		get_tree().call_group("storefront_custom_display", "refresh_display")
	_save_progression()

# --- Everyday Demand State (Today's Visitors, Daily Sulit Deals, Missed Requests) ---
var todays_expected_regulars: Array[String] = [] # Array of CustomerData.resource_path (3-4 picked daily)
var revealed_daily_visitors: Array[String] = [] # Subset of todays_expected_regulars revealed via Radio today
var todays_sulit_deals: Array[String] = [] # Array of ItemData.resource_path (2-3 at -20% when unlocked)
var todays_missed_items: Dictionary = {} # ItemData.resource_path -> int missed count today

func ensure_daily_demand_rolled() -> void:
	if todays_expected_regulars.is_empty():
		_roll_daily_expected_regulars()
	if (has_mario_deals or has_mayari_card(MayariCardRegistry.CARD_WHOLESALE_BLESSING)) and todays_sulit_deals.is_empty():
		_roll_daily_sulit_deals()

func _roll_daily_expected_regulars() -> void:
	todays_expected_regulars.clear()
	revealed_daily_visitors.clear()
	revealed_daily_visitors.clear()
	var pool: Array[CustomerData] = []
	for c in available_characters:
		if c and not c.is_collector() and c.unlock_tier <= current_tier:
			pool.append(c)
	pool.shuffle()
	var count := mini(pool.size(), randi_range(3, 4))
	for i in range(count):
		todays_expected_regulars.append(pool[i].resource_path)
	LogManager.info("StoryManager", "Rolled %d Daily Visitors for Day %d: %s" % [
		todays_expected_regulars.size(),
		day,
		str(todays_expected_regulars.map(func(p: String): return p.get_file().get_basename()))
	])

func _roll_daily_sulit_deals() -> void:
	todays_sulit_deals.clear()
	if not has_mario_deals:
		return
	var pool: Array[ItemData] = []
	for item in InventoryManager.get_all_items():
		if item and item.can_be_sold and item.tier <= current_tier:
			pool.append(item)
	pool.shuffle()
	var count := mini(pool.size(), get_sulit_deal_count())
	for i in range(count):
		todays_sulit_deals.append(pool[i].resource_path)
	LogManager.info("StoryManager", "Rolled %d Daily Sulit Deals for Day %d." % [todays_sulit_deals.size(), day])

func get_revealed_expected_regulars() -> Array[CustomerData]:
	ensure_daily_demand_rolled()
	var limit := get_revealed_regular_count()
	var result: Array[CustomerData] = []
	if limit <= 0:
		return result
	for path in revealed_daily_visitors:
		if result.size() >= limit:
			break
		var c := _get_character_data(path)
		if c:
			result.append(c)
	return result

func get_unrevealed_daily_visitors() -> Array[CustomerData]:
	ensure_daily_demand_rolled()
	var limit := get_revealed_regular_count()
	var result: Array[CustomerData] = []
	if limit <= 0 or revealed_daily_visitors.size() >= limit:
		return result
	for path in todays_expected_regulars:
		if path in revealed_daily_visitors:
			continue
		var c := _get_character_data(path)
		if c:
			result.append(c)
	return result

func has_unrevealed_daily_visitors() -> bool:
	return not get_unrevealed_daily_visitors().is_empty()

func peek_next_unrevealed_visitor() -> CustomerData:
	var unrev := get_unrevealed_daily_visitors()
	return unrev[0] if not unrev.is_empty() else null

func reveal_daily_visitor(visitor_path: String = "") -> CustomerData:
	ensure_daily_demand_rolled()
	var limit := get_revealed_regular_count()
	if limit <= 0 or revealed_daily_visitors.size() >= limit:
		return null
	var chosen_path := visitor_path
	if chosen_path.is_empty():
		var nxt := peek_next_unrevealed_visitor()
		if nxt == null:
			return null
		chosen_path = nxt.resource_path
	if not (chosen_path in revealed_daily_visitors):
		revealed_daily_visitors.append(chosen_path)
	var c := _get_character_data(chosen_path)
	if c:
		LogManager.info("StoryManager", "Papa Ulap revealed Daily Visitor '%s' (%d/%d)." % [c.character_name, revealed_daily_visitors.size(), mini(limit, todays_expected_regulars.size())])
		EventBus.restock_catalog_refresh.emit()
		_save_progression()
	return c

func is_item_on_sulit_deal(item: ItemData) -> bool:
	if (not has_mario_deals and not has_mayari_card(MayariCardRegistry.CARD_WHOLESALE_BLESSING)) or not item:
		return false
	return item.resource_path in todays_sulit_deals

func record_missed_item(item: ItemData) -> void:
	if not item or not item.can_be_sold:
		return
	var p := item.resource_path
	todays_missed_items[p] = int(todays_missed_items.get(p, 0)) + 1
	LogManager.info("StoryManager", "Logged MISSED demand for %s (today: %d)" % [item.item_name, int(todays_missed_items[p])])

func get_missed_count(item: ItemData) -> int:
	if not item:
		return 0
	return int(todays_missed_items.get(item.resource_path, 0))

func get_regulars_who_like_item(item: ItemData, only_revealed_today: bool = false) -> Array[CustomerData]:
	var result: Array[CustomerData] = []
	if not item:
		return result
	var cat := item.category.to_lower()
	var source: Array[CustomerData] = []
	if only_revealed_today:
		source = get_revealed_expected_regulars()
	else:
		for c in available_characters:
			if c and not c.is_collector() and c.unlock_tier <= current_tier:
				source.append(c)
	for c in source:
		if cat in c.get_favorite_categories():
			result.append(c)
	return result

## Physical container equipment props delivered in plastic bags on tier upgrades.
const CONTAINER_PROP_PATHS: Array[String] = [
	"res://Resources/items/candycontainer/Mix.tres",
	"res://Resources/items/candycontainer/Chubs.tres",
	"res://Resources/items/candycontainer/Mentor.tres",
	"res://Resources/items/candycontainer/Pocha.tres",
	"res://Resources/items/sachetcontainers/KneesToes.tres",
	"res://Resources/items/sachetcontainers/Kopimo.tres",
	"res://Resources/items/sachetcontainers/Aryel.tres",
]
var placed_containers: Array[String] = []

func is_container_placed(resource_path: String) -> bool:
	return resource_path != "" and resource_path in placed_containers

func mark_container_placed(resource_path: String) -> void:
	if resource_path == "":
		return
	if resource_path not in placed_containers:
		placed_containers.append(resource_path)
		_save_progression()

func get_unplaced_containers_for_tier(tier: int) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for path in CONTAINER_PROP_PATHS:
		if not ResourceLoader.exists(path):
			continue
		var res := load(path) as ItemData
		if res and res.tier == tier and not is_container_placed(res.resource_path):
			result.append(res)
	return result

@export_group("Transaction Probabilities")
## Chance (0.0 to 1.0) that a customer will start with a rumor.
@export_range(0, 1) var rumor_chance: float = 0.45
## Chance (0.0 to 1.0) that a customer will just visit without buying.
@export_range(0, 1) var visit_chance: float = 0.35
## Chance (0.0 to 1.0) that a customer's request will be a riddle.
@export_range(0, 1) var riddle_chance: float = 0.35

## Pool of characters that can arrive as regular customers.
## UncleMario is excluded — he is the delivery uncle, not a regular customer.
@export var available_characters: Array[CustomerData] = [
	preload("res://Resources/customers/KuyaKap.tres"),
	preload("res://Resources/customers/ManangAna.tres"),
	preload("res://Resources/customers/ReynaMayari.tres"),
	preload("res://Resources/customers/Rosalyn.tres"),
	preload("res://Resources/customers/TK.tres"),
	preload("res://Resources/customers/Buboy.tres"),
	preload("res://Resources/customers/Sarimanok.tres"),
	preload("res://Resources/customers/Danilo.tres"),
	preload("res://Resources/customers/Brahim.tres"),
	preload("res://Resources/customers/Rodel.tres"),
	preload("res://Resources/customers/LoloPilo.tres")
]

# --- 4PM+ Daily Mosquito Swarm Encounter (Once per day: 65% daily roll, random time 4PM+) ---
const MOSQUITO_START_HOUR := 16.0
const MOSQUITO_DAILY_CHANCE := 0.65
var mosquito_swarm_pending: bool = false
var mosquito_swarm_triggered_today: bool = false
var _mosquito_trigger_hour: float = -1.0 # < 0 means no mosquito swarm today
var debug_force_next_customer_id: String = ""

func _ready() -> void:
	LogManager.info("StoryManager", "StoryManager._ready() START")
	add_to_group("persist")
	clock.setup(self)
	EventBus.day_started.connect(_on_day_started)
	EventBus.customer_satisfied.connect(_on_customer_satisfied)
	EventBus.customer_arrived.connect(_on_customer_arrived)
	EventBus.customer_dismissed.connect(_on_customer_dismissed)
	Dialogic.VAR.variable_changed.connect(_on_dialogic_variable_changed)
	Dialogic.signal_event.connect(_on_dialogic_signal)
	EventBus.debt_quota_met.connect(_on_debt_quota_met)
	if not CharacterProgressionManager.story_advanced.is_connected(_on_story_advanced):
		CharacterProgressionManager.story_advanced.connect(_on_story_advanced)
	
	# Initial child character data into a lookup map for faster retrieval
	for c in available_characters:
		if c:
			_char_lookup[c.resource_path] = c
	
	randomize()
	call_deferred("_cache_node_refs")
	LogManager.info("StoryManager", "StoryManager._ready() END")

func _cache_node_refs() -> void:
	_game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	LogManager.debug("StoryManager", "Cached GameManager: %s" % str(is_instance_valid(_game_manager)))

func _process(_delta: float) -> void:
	if not active_blessing_cards.is_empty() and not sto_nino_blessing_all_day:
		check_sto_nino_blessing_expiry()
	_check_mosquito_swarm_trigger()

func _roll_daily_mosquito_swarm() -> void:
	mosquito_swarm_pending = false
	mosquito_swarm_triggered_today = false
	_mosquito_trigger_hour = -1.0
	if day <= 1:
		return
	if randf() < MOSQUITO_DAILY_CHANCE:
		var max_hour := maxf(MOSQUITO_START_HOUR + 0.25, minf(get_effective_closing_hour() - 0.75, 19.0))
		_mosquito_trigger_hour = randf_range(MOSQUITO_START_HOUR, max_hour)
		LogManager.info("StoryManager", "Mosquito Swarm scheduled for today at %.2fh (65%% daily roll)." % _mosquito_trigger_hour)

func _check_mosquito_swarm_trigger() -> void:
	if day <= 1 or mosquito_swarm_triggered_today or mosquito_swarm_pending or _mosquito_trigger_hour < 0.0:
		return
	if clock == null:
		return
	if clock.get_effective_display_time() >= _mosquito_trigger_hour:
		mosquito_swarm_pending = true
		mosquito_swarm_triggered_today = true
		LogManager.info("StoryManager", "4PM+ Mosquito Swarm flag opened at %.2fh! Next customer will remark on mosquitoes." % clock.get_effective_display_time())

func _on_day_started(new_day: int) -> void:
	LogManager.info("StoryManager", "StoryManager._on_day_started(%d) CALLED" % new_day)
	_roll_daily_mosquito_swarm()
	_cache_node_refs()
	day = new_day
	has_mayari_visited = false
	_clear_sto_nino_blessing()
	# Promote last night's drafted Moon Card(s) to active for today (or clear if none)
	active_mayari_cards.clear()
	for cid in pending_mayari_cards:
		if str(cid) != "" and not (str(cid) in active_mayari_cards):
			active_mayari_cards.append(str(cid))
	if active_mayari_cards.is_empty() and pending_mayari_card != "":
		active_mayari_cards.append(pending_mayari_card)
	pending_mayari_cards.clear()
	pending_mayari_card = ""
	active_mayari_card = active_mayari_cards[0] if not active_mayari_cards.is_empty() else ""
	EventBus.mayari_card_changed.emit(active_mayari_card)
	if not active_mayari_cards.is_empty():
		var titles: Array[String] = []
		var taglines: Array[String] = []
		for cid in active_mayari_cards:
			var card := MayariCardRegistry.get_card(cid)
			if not card.is_empty():
				var prefix := "Favor" if MayariCardRegistry.is_favor(cid) else "Omen"
				titles.append("%s: %s" % [prefix, str(card["title"])])
				taglines.append(str(card["tagline"]))
				LogManager.info("StoryManager", "Active Moon Card for Day %d: %s (%s)" % [day, str(card["title"]), prefix])
		if not titles.is_empty():
			call_deferred("_announce_active_mayari_cards", active_mayari_cards.duplicate())
	LogManager.info("StoryManager", "Day %d starts." % day)
	reset_daily_stats()
	todays_missed_items.clear()
	_roll_daily_expected_regulars()
	_roll_daily_sulit_deals()
	clock.on_day_started()

func _announce_active_mayari_cards(card_ids: Array[String]) -> void:
	await get_tree().create_timer(1.2).timeout
	if not active_mayari_cards.is_empty() and not card_ids.is_empty():
		EventBus.morning_mayari_cards_announced.emit(card_ids)


func advance_tier(source: String = "Manual") -> void:
	if current_tier >= 10:
		return
		
	current_tier += 1
	purchase_counter = 0
	pending_upgrade_tier = 0
	pending_upgrade_cost = 0.0
	LogManager.info("StoryManager", "TIER ADVANCED to %d via %s" % [current_tier, source])
	
	# Save state
	_save_progression()
	
	# Trigger rewards
	EventBus.tier_advanced.emit(current_tier, source)

func get_upgrade_cost(target_tier: int) -> float:
	var step := float(maxi(0, target_tier - 2))
	var linear_base := 70.0 + step * 15.0
	var scaled := linear_base * (1.0 + 0.03 * step)
	return roundf(scaled / 5.0) * 5.0

## Returns a virtual ItemData representating a store upgrade for a specific tier.
func get_tier_upgrade_item(target_tier: int) -> ItemData:
	if _upgrade_item_cache.has(target_tier):
		return _upgrade_item_cache[target_tier]
		
	var item = ItemData.new()
	item.item_name = "Tier %d Upgrade Package" % target_tier
	item.price = get_upgrade_cost(target_tier)
	item.can_be_sold = false
	item.tier = target_tier
	item.category = "upgrades"
	
	var rep = get_representative_item_for_tier(target_tier)
	if rep:
		item.texture = rep.texture
	
	# We use metadata to identify it as an upgrade later
	item.set_meta("is_upgrade", true)
	item.set_meta("target_tier", target_tier)
	
	_upgrade_item_cache[target_tier] = item
	return item

## Finds the first item loaded in the inventory that belongs to a specific tier.
func get_representative_item_for_tier(target_tier: int) -> ItemData:
	for item in InventoryManager.get_all_items():
		if item.tier == target_tier:
			return item
	return null

var _pending_level_up_bonus: float = 0.0
var last_level_up_bonus: float = 0.0

func _grant_level_up_money(amount: float) -> void:
	if amount <= 0.0:
		return
	last_level_up_bonus = amount
	if not is_instance_valid(_game_manager):
		_cache_node_refs()
	if is_instance_valid(_game_manager):
		_game_manager.money += amount
		EventBus.money_changed.emit(_game_manager.money)
		EventBus.request_sfx.emit("money_gain")
		record_daily_stat_add("tips_earned", amount)

func process_pending_unlock() -> void:
	if _pending_tier_advance_source == "":
		if _pending_level_up_bonus > 0.0:
			var leftover := _pending_level_up_bonus
			_pending_level_up_bonus = 0.0
			_grant_level_up_money(leftover)
		return

	# Safety Guard: Never notify for the same tier twice
	if max_unlocked_tier <= _last_notified_tier:
		LogManager.info("StoryManager", "Skip redundant notification for Tier %d" % max_unlocked_tier)
		_pending_tier_advance_source = ""
		if _pending_level_up_bonus > 0.0:
			var leftover := _pending_level_up_bonus
			_pending_level_up_bonus = 0.0
			_grant_level_up_money(leftover)
		return
		
	# Always offer the NEXT sequential upgrade for purchase
	pending_upgrade_tier = current_tier + 1
	pending_upgrade_cost = get_upgrade_cost(pending_upgrade_tier)

	# Refresh Uncle Mario's delivery cooldown so he is immediately ready
	InventoryManager.clear_delivery_cooldown()
	
	# But the notification highlights the specific tier that was JUST unlocked
	var notify_tier = _last_tier_unlocked_notification if _last_tier_unlocked_notification > 0 else pending_upgrade_tier
	
	# Collect items belonging specifically to the newly unlocked tier
	var new_items: Array[ItemData] = []
	for item in InventoryManager.get_all_items():
		if item.tier == notify_tier:
			new_items.append(item)
	
	_pending_tier_advance_source = ""
	_last_tier_unlocked_notification = 0 # Reset after notification
	_last_notified_tier = notify_tier

	# Award deferred level-up prize money right as the notification appears!
	if _pending_level_up_bonus > 0.0:
		var bonus := _pending_level_up_bonus
		_pending_level_up_bonus = 0.0
		_grant_level_up_money(bonus)
	
	# Notify the player. We show the items for notify_tier, 
	# but the cost is for the NEXT purchaseable upgrade (pending_upgrade_tier).
	EventBus.upgrade_available.emit(notify_tier, pending_upgrade_cost, new_items)
	_save_progression()

func _save_progression() -> void:
	if not _save_requested:
		_save_requested = true
		call_deferred("_flush_save")

func _flush_save() -> void:
	_save_requested = false
	SaveManager.force_save()

# ── Persistence ──────────────────────────────────────────────────────────
## Persistence ID
func get_save_id() -> String:
	return "StoryManager"

func get_save_data() -> Dictionary:
	_ensure_tod_node()
	if is_instance_valid(clock._time_of_day_node) and clock._time_of_day_node.has_method("get"):
		var tod_time = clock._time_of_day_node.get("current_time")
		if tod_time != null: _current_display_time = tod_time
	return {
		"day": day,
		"player_level": player_level,
		"player_xp": player_xp,
		"current_tier": current_tier,
		"max_unlocked_tier": max_unlocked_tier,
		"purchase_counter": purchase_counter,
		"customer_debts": customer_debts.duplicate(),
		"pending_debts": pending_debts.duplicate(true),
		"pending_repayments": pending_repayments.duplicate(true),
		"settled_debts_log": settled_debts_log.duplicate(true),
		"pending_upgrade_tier": pending_upgrade_tier,
		"pending_upgrade_cost": pending_upgrade_cost,
		"has_mayari_visited": has_mayari_visited,
		"is_mayari_debt_active": is_mayari_debt_active,
		"is_mayari_met": is_mayari_met,
		"last_mayari_collection_successful": last_mayari_collection_successful,
		"tally_total_paid": tally_total_paid,
		"tally_sufficient_nights": tally_sufficient_nights,
		"active_mayari_card": active_mayari_card,
		"pending_mayari_card": pending_mayari_card,
		"active_mayari_cards": active_mayari_cards.duplicate(),
		"pending_mayari_cards": pending_mayari_cards.duplicate(),
		"last_tally_tier": last_tally_tier,
		"current_display_time": clock.get_effective_display_time(),
		"is_clock_running": is_clock_running or clock._is_fast_forwarding,
		"wait_limit_time": wait_limit_time,
		"active_time_window_hours": clock.active_time_window_hours,
		"was_paused_by_limit": was_paused_by_limit,
		"is_customer_present": is_customer_present,
		"_last_notified_tier": _last_notified_tier,
		"placed_containers": placed_containers.duplicate(),
		"fridge_upgrade_level": fridge_upgrade_level,
		"fridge_coldness": fridge_coldness,
		"is_fridge_warm": is_fridge_warm,
		"cat_upgrade_level": cat_upgrade_level,
		"has_trash_can": has_trash_can,
		"maneki_upgrade_level": maneki_upgrade_level,
		"radio_upgrade_level": radio_upgrade_level,
		"has_mario_deals": has_mario_deals,
		"mario_deals_level": mario_deals_level,
		"has_recycling": has_recycling,
		"sto_nino_upgrade_level": sto_nino_upgrade_level,
		"active_blessing_cards": active_blessing_cards.duplicate(),
		"sto_nino_blessing_start_hour": sto_nino_blessing_start_hour,
		"sto_nino_blessing_end_hour": sto_nino_blessing_end_hour,
		"sto_nino_blessing_all_day": sto_nino_blessing_all_day,
		"permit_upgrade_level": permit_upgrade_level,
		"bench_upgrade_level": bench_upgrade_level,
		"storefront_upgrade_level": storefront_upgrade_level,
		"has_custom_signage": has_custom_signage,
		"has_custom_poster": has_custom_poster,
		"signage_featured_category": signage_featured_category,
		"signage_last_edited_day": signage_last_edited_day,
		"poster_featured_category": poster_featured_category,
		"custom_signage_stickers": custom_signage_stickers.duplicate(true),
		"custom_poster_stickers": custom_poster_stickers.duplicate(true),
		"custom_recent_colors": custom_recent_colors.duplicate(),
		"todays_expected_regulars": todays_expected_regulars.duplicate(),
		"revealed_daily_visitors": revealed_daily_visitors.duplicate(),
		"todays_sulit_deals": todays_sulit_deals.duplicate(),
		"todays_missed_items": todays_missed_items.duplicate(),
		"daily_stats": ensure_daily_stats().duplicate(true),
	}
func load_save_data(data: Dictionary) -> void:
	day = data.get("day", day)
	current_tier = data.get("current_tier", current_tier)
	max_unlocked_tier = data.get("max_unlocked_tier", max_unlocked_tier)
	player_level = maxi(1, int(data.get("player_level", maxi(1, max_unlocked_tier))))
	player_xp = maxi(0, int(data.get("player_xp", 0)))
	max_unlocked_tier = maxi(max_unlocked_tier, player_level)
	EventBus.player_xp_changed.emit(player_level, player_xp, get_xp_for_next_level(), 0, false)
	purchase_counter = data.get("purchase_counter", purchase_counter)
	customer_debts = data.get("customer_debts", {})
	pending_debts.clear()
	for entry in data.get("pending_debts", []):
		if entry is Dictionary and entry.has("customer_path") and float(entry.get("amount", 0.0)) > 0.0:
			pending_debts.append({
				"customer_path": str(entry["customer_path"]),
				"amount": float(entry["amount"])
			})
	pending_repayments.clear()
	for entry in data.get("pending_repayments", []):
		if entry is Dictionary and entry.has("customer_path") and float(entry.get("amount", 0.0)) > 0.0:
			pending_repayments.append({
				"customer_path": str(entry["customer_path"]),
				"amount": float(entry["amount"]),
				"day": int(entry.get("day", day))
			})
	settled_debts_log.clear()
	for entry in data.get("settled_debts_log", []):
		if entry is Dictionary and float(entry.get("amount", 0.0)) > 0.0:
			settled_debts_log.append({
				"customer_path": str(entry.get("customer_path", "")),
				"customer_name": str(entry.get("customer_name", "Neighbor")),
				"amount": float(entry.get("amount", 0.0)),
				"day": int(entry.get("day", 1))
			})
	pending_debts_changed.emit()
	pending_upgrade_tier = data.get("pending_upgrade_tier", 0)
	pending_upgrade_cost = data.get("pending_upgrade_cost", 0.0)
	has_mayari_visited = data.get("has_mayari_visited", false)
	is_mayari_debt_active = data.get("is_mayari_debt_active", true)
	is_mayari_met = data.get("is_mayari_met", false)
	last_mayari_collection_successful = data.get("last_mayari_collection_successful", true)
	tally_total_paid = clampf(float(data.get("tally_total_paid", 0.0)), 0.0, TALLY_GOAL)
	tally_sufficient_nights = maxi(0, int(data.get("tally_sufficient_nights", 0)))
	active_mayari_card = str(data.get("active_mayari_card", ""))
	pending_mayari_card = str(data.get("pending_mayari_card", ""))
	active_mayari_cards.clear()
	for cid in data.get("active_mayari_cards", []):
		if str(cid) != "" and not (str(cid) in active_mayari_cards):
			active_mayari_cards.append(str(cid))
	if active_mayari_cards.is_empty() and active_mayari_card != "":
		active_mayari_cards.append(active_mayari_card)
	active_mayari_card = active_mayari_cards[0] if not active_mayari_cards.is_empty() else ""
	pending_mayari_cards.clear()
	for cid in data.get("pending_mayari_cards", []):
		if str(cid) != "" and not (str(cid) in pending_mayari_cards):
			pending_mayari_cards.append(str(cid))
	if pending_mayari_cards.is_empty() and pending_mayari_card != "":
		pending_mayari_cards.append(pending_mayari_card)
	pending_mayari_card = pending_mayari_cards[0] if not pending_mayari_cards.is_empty() else ""
	last_tally_tier = str(data.get("last_tally_tier", "balanced"))
	EventBus.mayari_card_changed.emit(active_mayari_card)
	_current_display_time = float(data.get("current_display_time", DAY_START_HOUR))
	if _current_display_time < DAY_START_HOUR:
		LogManager.warn("StoryManager", "Self-healed post-midnight wrapped save time (%.2f -> %.2f)." % [_current_display_time, DayClock.HARD_STOP_HOUR])
		_current_display_time = DayClock.HARD_STOP_HOUR
	if has_mayari_visited and _current_display_time < clock.get_closing_hour():
		LogManager.warn("StoryManager", "Self-healed stale has_mayari_visited=true on daytime save (time=%.2f < closing=%.2f)." % [_current_display_time, clock.get_closing_hour()])
		has_mayari_visited = false
	is_clock_running = data.get("is_clock_running", false)
	wait_limit_time = data.get("wait_limit_time", -1.0)
	clock.active_time_window_hours = float(data.get("active_time_window_hours", DayClock.CUSTOMER_TIME_WINDOW_HOURS))
	was_paused_by_limit = data.get("was_paused_by_limit", false)
	is_customer_present = data.get("is_customer_present", false)
	_last_notified_tier = data.get("_last_notified_tier", 0)
	fridge_upgrade_level = clampi(int(data.get("fridge_upgrade_level", 0)), 0, FRIDGE_UPGRADE_SPECS.size() - 1)
	fridge_coldness = clampf(float(data.get("fridge_coldness", 100.0)), 0.0, 100.0)
	is_fridge_warm = bool(data.get("is_fridge_warm", false))
	if fridge_coldness >= FRIDGE_WARM_RECOVER_THRESHOLD:
		is_fridge_warm = false
	cat_upgrade_level = clampi(int(data.get("cat_upgrade_level", 0)), 0, CAT_UPGRADE_SPECS.size() - 1)
	has_trash_can = bool(data.get("has_trash_can", false))
	maneki_upgrade_level = clampi(int(data.get("maneki_upgrade_level", 0)), 0, MANEKI_UPGRADE_SPECS.size() - 1)
	radio_upgrade_level = clampi(int(data.get("radio_upgrade_level", 0)), 0, RADIO_UPGRADE_SPECS.size() - 1)
	has_mario_deals = bool(data.get("has_mario_deals", false))
	mario_deals_level = int(data.get("mario_deals_level", 1 if has_mario_deals else 0))
	has_mario_deals = mario_deals_level >= 1
	has_recycling = bool(data.get("has_recycling", false))
	sto_nino_upgrade_level = clampi(int(data.get("sto_nino_upgrade_level", 0)), 0, STO_NINO_UPGRADE_SPECS.size() - 1)
	active_blessing_cards.clear()
	for cid in data.get("active_blessing_cards", []):
		if str(cid) != "":
			active_blessing_cards.append(str(cid))
	sto_nino_blessing_start_hour = float(data.get("sto_nino_blessing_start_hour", -1.0))
	sto_nino_blessing_end_hour = float(data.get("sto_nino_blessing_end_hour", -1.0))
	sto_nino_blessing_all_day = bool(data.get("sto_nino_blessing_all_day", false))
	EventBus.sto_nino_blessing_changed.emit()
	permit_upgrade_level = clampi(int(data.get("permit_upgrade_level", 0)), 0, PERMIT_UPGRADE_SPECS.size() - 1)
	bench_upgrade_level = clampi(int(data.get("bench_upgrade_level", 0)), 0, BENCH_UPGRADE_SPECS.size() - 1)
	storefront_upgrade_level = clampi(int(data.get("storefront_upgrade_level", 0)), 0, STOREFRONT_UPGRADE_SPECS.size() - 1)
	has_custom_signage = bool(data.get("has_custom_signage", false))
	has_custom_poster = bool(data.get("has_custom_poster", false))
	signage_featured_category = str(data.get("signage_featured_category", ""))
	signage_last_edited_day = int(data.get("signage_last_edited_day", -1))
	poster_featured_category = str(data.get("poster_featured_category", ""))
	custom_signage_stickers.clear()
	var raw_sig = data.get("custom_signage_stickers", [])
	if raw_sig is Array:
		for entry in raw_sig:
			if entry is Dictionary:
				custom_signage_stickers.append(entry.duplicate(true))
	custom_poster_stickers.clear()
	var raw_pos = data.get("custom_poster_stickers", [])
	if raw_pos is Array:
		for entry in raw_pos:
			if entry is Dictionary:
				custom_poster_stickers.append(entry.duplicate(true))
	custom_recent_colors.clear()
	var raw_cols = data.get("custom_recent_colors", [])
	if raw_cols is Array:
		for c_hex in raw_cols:
			var s_hex := str(c_hex)
			if s_hex != "" and custom_recent_colors.size() < 12:
				custom_recent_colors.append(s_hex)
	todays_expected_regulars.clear()
	revealed_daily_visitors.clear()
	for p in data.get("todays_expected_regulars", []):
		todays_expected_regulars.append(str(p))
	revealed_daily_visitors.clear()
	for p in data.get("revealed_daily_visitors", []):
		revealed_daily_visitors.append(str(p))
	todays_sulit_deals.clear()
	for p in data.get("todays_sulit_deals", []):
		todays_sulit_deals.append(str(p))
	todays_missed_items = data.get("todays_missed_items", {}).duplicate()
	var loaded_ds = data.get("daily_stats", {})
	daily_stats = loaded_ds.duplicate(true) if loaded_ds is Dictionary else _make_empty_daily_stats()
	ensure_daily_stats()
	ensure_daily_demand_rolled()

	placed_containers.clear()
	if data.has("placed_containers"):
		for p in data["placed_containers"]:
			var path_str := str(p)
			if ResourceLoader.exists(path_str):
				var res := load(path_str) as ItemData
				if res and res.tier > current_tier:
					continue
			placed_containers.append(path_str)
	else:
		# Backward compatibility for older saves: treat already-unlocked tier containers as placed
		for path in CONTAINER_PROP_PATHS:
			if ResourceLoader.exists(path):
				var res := load(path) as ItemData
				if res and res.tier <= current_tier:
					placed_containers.append(res.resource_path)

	# Refresh all 3D upgrade props immediately and deferred so save loads on fresh startup
	# always update prop visibility after _ready() has already run with default level=0 state.
	_refresh_all_store_props()
	if get_tree():
		get_tree().process_frame.connect(_refresh_all_store_props, CONNECT_ONE_SHOT)

	CharacterProgressionManager.migrate_from_story_manager_save(data)
	DialogicBridge.sync_global(day, current_tier, max_unlocked_tier, 1)

	_ensure_tod_node()
	if is_instance_valid(clock._time_of_day_node):
		_apply_display_time(_current_display_time)
		clock._time_of_day_node.game_time_enabled = is_clock_running
	else:
		get_tree().process_frame.connect(func():
			_ensure_tod_node()
			if is_instance_valid(clock._time_of_day_node):
				_apply_display_time(_current_display_time)
				clock._time_of_day_node.game_time_enabled = is_clock_running
		, CONNECT_ONE_SHOT)

func _refresh_all_store_props() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.call_group("dispenser_containers", "refresh_stock")
	tree.call_group("store_cats", "refresh_visibility", false)
	tree.call_group("store_maneki", "refresh_visibility", false)
	tree.call_group("trash", "refresh_visibility", false)
	tree.call_group("store_radio", "_refresh_visual_state", false)
	tree.call_group("permit_frame", "refresh_visibility", false)
	tree.call_group("store_bench", "refresh_visibility", false)
	tree.call_group("sto_nino_altar", "_refresh_visual_state")
	tree.call_group("store_door", "refresh_lock_state")
	tree.call_group("storefront_custom_display", "refresh_display")


func reset_state() -> void:
	day = 1
	player_level = 1
	player_xp = 0
	current_tier = 1
	max_unlocked_tier = 1
	purchase_counter = 0
	EventBus.player_xp_changed.emit(player_level, player_xp, get_xp_for_next_level(), 0, false)
	pending_upgrade_tier = 0
	pending_upgrade_cost = 0.0
	customer_debts = {}
	pending_debts.clear()
	pending_repayments.clear()
	settled_debts_log.clear()
	pending_debts_changed.emit()
	has_mayari_visited = false
	is_mayari_debt_active = true
	is_mayari_met = false
	last_mayari_collection_successful = true
	tally_total_paid = 0.0
	tally_sufficient_nights = 0
	active_mayari_card = ""
	pending_mayari_card = ""
	active_mayari_cards.clear()
	pending_mayari_cards.clear()
	last_tally_tier = "balanced"
	EventBus.mayari_card_changed.emit("")
	_last_tier_unlocked_notification = 0
	_pending_tier_advance_source = ""
	_last_notified_tier = 0
	placed_containers.clear()
	fridge_upgrade_level = 0
	fridge_coldness = 100.0
	is_fridge_warm = false
	cat_upgrade_level = 0
	has_trash_can = false
	maneki_upgrade_level = 0
	radio_upgrade_level = 0
	has_mario_deals = false
	mario_deals_level = 0
	has_recycling = false
	sto_nino_upgrade_level = 0
	_clear_sto_nino_blessing()
	permit_upgrade_level = 0
	bench_upgrade_level = 0
	storefront_upgrade_level = 0
	has_custom_signage = false
	has_custom_poster = false
	signage_featured_category = ""
	signage_last_edited_day = -1
	poster_featured_category = ""
	custom_signage_stickers.clear()
	custom_poster_stickers.clear()
	custom_recent_colors.clear()
	delete_custom_artwork_files()
	EventBus.storefront_upgraded.emit(0)
	EventBus.storefront_artwork_updated.emit("")
	if get_tree():
		get_tree().call_group("storefront_custom_display", "refresh_display")
		get_tree().call_group("store_door", "refresh_lock_state")
	todays_expected_regulars.clear()
	revealed_daily_visitors.clear()
	todays_sulit_deals.clear()
	todays_missed_items.clear()
	reset_daily_stats()
	clock.reset_state()
	SaveManager.delete_save()

func get_next_transaction(exclude_paths: Array[String] = [], is_wave_joiner: bool = false) -> TransactionContext:
	if debug_force_next_customer_id != "":
		var forced := _get_character_data(debug_force_next_customer_id)
		debug_force_next_customer_id = ""
		if forced and not (forced.resource_path in exclude_paths):
			var tx := TransactionContext.new()
			tx.customer_data = forced
			_build_transaction_context(tx, forced, false)
			return tx
	return TransactionBuilder.build_next_transaction(self, exclude_paths, is_wave_joiner)

func get_collection_transaction() -> TransactionContext:
	return TransactionBuilder.build_collection_transaction(self)

func _on_debt_quota_met(was_successful: bool) -> void:
	last_mayari_collection_successful = was_successful
	_save_progression()

func queue_pending_debt(customer_path: String, amount: float) -> void:
	if customer_path == "" or amount <= 0.0:
		return
	# Combine with an existing unlogged entry for the same customer if present
	for entry in pending_debts:
		if str(entry.get("customer_path", "")) == customer_path:
			entry["amount"] = float(entry.get("amount", 0.0)) + amount
			LogManager.info("StoryManager", "Updated pending utang for %s: +%.2f (Pending: %.2f)" % [customer_path.get_file(), amount, float(entry["amount"])])
			pending_debts_changed.emit()
			_save_progression()
			return
	pending_debts.append({
		"customer_path": customer_path,
		"amount": amount
	})
	LogManager.info("StoryManager", "Queued pending utang for %s: %.2f (awaiting Loan Ledger entry)" % [customer_path.get_file(), amount])
	pending_debts_changed.emit()
	_save_progression()

func has_pending_debts() -> bool:
	return not pending_debts.is_empty()

func has_pending_repayments() -> bool:
	return not pending_repayments.is_empty()

func has_pending_ledger_actions() -> bool:
	return not pending_debts.is_empty() or not pending_repayments.is_empty()

func get_pending_ledger_count() -> int:
	return pending_debts.size() + pending_repayments.size()

func queue_pending_repayment(customer_path: String, amount: float) -> void:
	if customer_path == "" or amount <= 0.0:
		return
	for entry in pending_repayments:
		if str(entry.get("customer_path", "")) == customer_path:
			entry["amount"] = float(entry.get("amount", 0.0)) + amount
			entry["day"] = day
			LogManager.info("StoryManager", "Updated pending utang repayment for %s: +%.2f" % [customer_path.get_file(), amount])
			pending_debts_changed.emit()
			_save_progression()
			return
	pending_repayments.append({
		"customer_path": customer_path,
		"amount": amount,
		"day": day
	})
	LogManager.info("StoryManager", "Queued pending utang repayment for %s: %.2f (awaiting cross-off in Notebook)" % [customer_path.get_file(), amount])
	pending_debts_changed.emit()
	_save_progression()

func commit_pending_repayment(index: int) -> void:
	if index < 0 or index >= pending_repayments.size():
		return
	var entry: Dictionary = pending_repayments[index]
	pending_repayments.remove_at(index)
	var c_path: String = str(entry.get("customer_path", ""))
	var amt: float = float(entry.get("amount", 0.0))
	var c_data := _get_character_data(c_path)
	var c_name: String = c_data.character_name if (c_data and c_data.character_name != "") else c_path.get_file().get_basename()
	settled_debts_log.push_front({
		"customer_path": c_path,
		"customer_name": c_name,
		"amount": amt,
		"day": int(entry.get("day", day))
	})
	if settled_debts_log.size() > 60:
		settled_debts_log.resize(60)
	pending_debts_changed.emit()
	_save_progression()

func commit_pending_debt(index: int) -> void:
	if index < 0 or index >= pending_debts.size():
		return
	var entry: Dictionary = pending_debts[index]
	pending_debts.remove_at(index)
	record_debt(str(entry.get("customer_path", "")), float(entry.get("amount", 0.0)))
	pending_debts_changed.emit()

func record_debt(customer_path: String, amount: float) -> void:
	var current = customer_debts.get(customer_path, 0.0)
	customer_debts[customer_path] = current + amount
	LogManager.info("StoryManager", "Recorded Debt for %s: +%.2f (Total: %.2f)" % [customer_path.get_file(), amount, customer_debts[customer_path]])
	_save_progression()

func reduce_debt(customer_path: String, amount: float) -> void:
	if not customer_debts.has(customer_path) or amount <= 0.0:
		return
	var remaining: float = float(customer_debts[customer_path]) - amount
	if remaining <= 0.01:
		clear_debt(customer_path)
	else:
		customer_debts[customer_path] = remaining
		LogManager.info("StoryManager", "Debt REDUCED for %s: -%.2f (Remaining: %.2f)" % [customer_path.get_file(), amount, remaining])
		_save_progression()

func clear_debt(customer_path: String) -> void:
	if customer_debts.has(customer_path):
		customer_debts.erase(customer_path)
		LogManager.info("StoryManager", "Debt CLEARED for %s" % customer_path.get_file())
		_save_progression()

func _apply_display_time(t: float) -> void:
	clock.apply_display_time(t)

func _ensure_tod_node() -> void:
	clock._ensure_tod_node()

func complete_tutorial() -> void:
	var tutorial_path := "res://Resources/customers/UncleMario.tres"
	CharacterProgressionManager.advance_story_direct(tutorial_path)
	LogManager.info("StoryManager", "Uncle Mario tutorial marked as complete (Manually).")

func _get_character_data(path_or_id: String) -> CustomerData:
	if path_or_id.to_lower() == "unclemariotutorial":
		return preload("res://Resources/customers/UncleMario.tres")

	# Try path lookup first (fix branch style)
	var data = _char_lookup.get(path_or_id)
	if data: return data
	
	# Fallback: search by id (main branch style)
	for c in available_characters:
		if c.get_clean_id() == path_or_id.to_lower():
			return c
	return null


## Build the transaction context by choosing the appropriate timeline.
func _build_transaction_context(transaction: TransactionContext, data: CustomerData, force_story: bool = false) -> void:
	TransactionBuilder.build_transaction_context(self, transaction, data, force_story)

## Helper to check if an item is available based on the current tier.
func is_item_unlocked(item: ItemData) -> bool:
	return OrderItemPicker.is_unlocked(item, current_tier)


var _processed_satisfied_customers: Array[Customer] = []

func award_customer_completion_xp(customer: Customer) -> void:
	if not is_instance_valid(customer) or customer.is_lingering_departure:
		return
	if customer.get_meta("_xp_awarded", false):
		return
	if not customer.transaction_context:
		return
	if customer.customer_data != null and customer.customer_data.is_collector():
		return
	customer.set_meta("_xp_awarded", true)
	var ctx: TransactionContext = customer.transaction_context
	if ctx.transaction_type == TransactionContext.Type.VISIT or ctx.is_visit_story:
		add_player_xp(10, "Visit")
	else:
		var orig := maxi(1, ctx.original_count)
		var delivered := ctx.delivered_items.size()
		if delivered <= 0:
			return
		var full_xp := 15 + maxi(0, orig - 1) * 5
		if ctx.is_riddle and delivered >= orig:
			full_xp += 10
		var xp := full_xp
		var is_partial := delivered < orig
		if is_partial:
			var ratio := float(delivered) / float(orig)
			xp = maxi(3, int(roundf(float(full_xp) * ratio * 0.55)))
		var gained: int = add_player_xp(xp, "Purchase" if not is_partial else "Partial Purchase")
		if is_partial and gained > 0 and is_instance_valid(VisualEffectManager):
			VisualEffectManager.spawn_floating_xp(customer, gained, true)
		purchase_counter += 1

func _on_customer_satisfied(customer) -> void:
	# Double-processing guard: ensure we don't process the same customer twice
	if customer in _processed_satisfied_customers:
		return
	_processed_satisfied_customers.append(customer)
	# Keep the list small — only need to remember recent ones
	if _processed_satisfied_customers.size() > 5:
		_processed_satisfied_customers.pop_front()

	if customer != null and customer.is_lingering_departure:
		return

	_set_last_customer_info(customer)
	Dialogic.VAR.set_variable("Global_LastSatisfaction", "Happy")
	
	_process_story_cooldown(customer)
	
	# Mark nightly collector visited & fallback-award Player XP if not already awarded at last-item handover
	if customer.transaction_context and not customer.transaction_context.is_guided_tutorial:
		var is_nightly_coll: bool = customer.transaction_context.is_nightly_collection
		if is_nightly_coll:
			has_mayari_visited = true
			is_mayari_met = true
		else:
			award_customer_completion_xp(customer)
			if customer.transaction_context.transaction_type == TransactionContext.Type.VISIT or customer.transaction_context.is_visit_story:
				if not customer.get_meta("visit_stat_recorded", false):
					customer.set_meta("visit_stat_recorded", true)
					record_daily_stat_int("visits_served", 1)
			else:
				record_daily_stat_int("buyers_served", 1)
				# Full 2+ Multi-Item Basket Reputation Bonus (+4 Rep) — fallback only if not already awarded at counter departure
				var ctx_done: TransactionContext = customer.transaction_context
				if not customer.get_meta("full_basket_rep_awarded", false) and ctx_done.delivered_items.size() >= 2 and ctx_done.delivered_items.size() >= ctx_done.desired_items.size():
					customer.set_meta("full_basket_rep_awarded", true)
					if customer.customer_data and is_instance_valid(CharacterProgressionManager):
						CharacterProgressionManager.add_reputation(customer.customer_data.resource_path, 4, "full_basket")
				# Picky Cravings Omen upside: +18% Bundle Bonus when completing a full 2+ multi-item cash order!
				if has_mayari_card(MayariCardRegistry.CARD_PICKY_CRAVINGS) and not ctx_done.wants_debt and ctx_done.delivered_items.size() >= 2 and ctx_done.delivered_items.size() >= ctx_done.desired_items.size():
					var basket_total := 0.0
					for dit in ctx_done.delivered_items:
						if dit:
							basket_total += dit.get_final_price()
					var bundle_bonus := calc_scaled_tip(basket_total, 0.18, 5.0, 25.0)
					if bundle_bonus > 0.0 and is_instance_valid(_game_manager):
						_game_manager.money += bundle_bonus
						EventBus.money_changed.emit(_game_manager.money)
						record_daily_stat_add("tips_earned", bundle_bonus)
						EventBus.show_notification.emit("Bundle Bonus!", "+₱%.2f (%d-item order)" % [bundle_bonus, ctx_done.delivered_items.size()], "purchase")
		
	# Tutorial Persistence: If this encounter was the guided tutorial, mark it complete now.
	if customer.transaction_context and customer.transaction_context.is_guided_tutorial:
		complete_tutorial()
		if customer.customer_data:
			CharacterProgressionManager.record_encounter(customer.customer_data.resource_path)
		LogManager.info("StoryManager", "Guided tutorial encounter successfully completed and saved.")

	if customer != null and not _has_other_counter_customers(customer):
		clock.on_customer_dismissed()

func _on_customer_arrived(customer: Customer) -> void:
	if customer == null or customer.is_lingering_visitor or customer.is_returning_for_smalltalk:
		return
	var is_visit := false
	if customer.transaction_context:
		is_visit = customer.transaction_context.transaction_type == TransactionContext.Type.VISIT \
			or customer.transaction_context.is_visit_story
	# Start the wave clock window only when the counter transitions from empty -> occupied.
	if not clock.is_customer_present:
		clock.on_customer_arrived(is_visit)
	elif not is_visit and clock.active_time_window_hours < get_customer_time_window_hours():
		# A buyer joined a visit wave: widen the wave patience window to standard customer window
		clock.active_time_window_hours = get_customer_time_window_hours()

func _on_customer_dismissed(customer: Customer) -> void:
	if customer != null and customer.is_lingering_departure:
		return
	if customer != null and customer.transaction_context and customer.transaction_context.is_nightly_collection:
		has_mayari_visited = true
		is_mayari_met = true
	if customer != null and customer.transaction_context:
		for desired in customer.transaction_context.desired_items:
			if desired and InventoryManager.get_total_item_stock(desired) <= 0:
				record_missed_item(desired)
	if customer != null and not _has_other_counter_customers(customer):
		clock.on_customer_dismissed()
	_set_last_customer_info(customer)
	Dialogic.VAR.set_variable("Global_LastSatisfaction", "Unhappy")
	_process_story_cooldown(customer)

func _has_other_counter_customers(leaving_customer: Customer) -> bool:
	var spawners = get_tree().get_nodes_in_group("customer_spawner")
	if spawners.size() > 0:
		var spawner = spawners[0]
		if spawner and spawner.has_method("has_other_counter_customers"):
			return spawner.has_other_counter_customers(leaving_customer)
	return false

func _set_last_customer_info(customer: Customer) -> void:
	if customer == null:
		Dialogic.VAR.set_variable("Global_LastCustomer", "Uncle Mario")
		Dialogic.VAR.set_variable("Global_LastItem", "Stock Delivery")
		return
		
	if customer.transaction_context:
		var data = customer.transaction_context.customer_data
		var display_name = data.character_name if data.character_name != "" else data.get_clean_id()
			
		Dialogic.VAR.set_variable("Global_LastCustomer", display_name)
		
		# Mark as encountered so they leave the Priority 0 "Forced First Encounter" list
		var path = data.resource_path
		CharacterProgressionManager.record_encounter(path)
		
		# Save specific item for rumors if applicable
		if not customer.transaction_context.desired_items.is_empty():
			Dialogic.VAR.set_variable("Global_LastItem", customer.transaction_context.desired_items[0].item_name)
		else:
			Dialogic.VAR.set_variable("Global_LastItem", "")

func _process_story_cooldown(customer) -> void:
	CharacterProgressionManager.process_story_cooldown(customer, last_mayari_collection_successful)

func _on_story_advanced(character_path: String, new_chapter: int) -> void:
	if character_path.contains("ReynaMayari") or character_path.contains("UncleMario"):
		return
	var char_data := _get_character_data(character_path)
	var char_name := char_data.character_name if char_data and char_data.character_name != "" else character_path.get_file().get_basename()
	record_daily_list_entry("story_chapters", char_name, true)
	if new_chapter > 0 and new_chapter % 3 == 0:
		@warning_ignore("integer_division")
		var arc_idx := (new_chapter / 3) - 1
		var arc_label := ""
		if char_data and arc_idx >= 0 and arc_idx < char_data.character_arcs.size():
			var arc_res = char_data.character_arcs[arc_idx]
			if arc_res and str(arc_res.arc_name).strip_edges() != "":
				arc_label = str(arc_res.arc_name).strip_edges()
		var arc_entry := "%s's %s" % [char_name, arc_label] if arc_label != "" else "%s's Arc %d" % [char_name, arc_idx + 1]
		record_daily_list_entry("arcs_completed", arc_entry, false)
	add_player_xp(20, "Story Chapter")

func get_best_item_for_category(cat: String, current_item: ItemData = null) -> ItemData:
	return OrderItemPicker.best_for_category(cat, current_tier, current_item)

func get_any_item_for_category(cat: String, prefer_hint: bool = false) -> ItemData:
	return OrderItemPicker.any_for_category(cat, current_tier, prefer_hint)

func _get_current_customer() -> Node:
	var spawners = get_tree().get_nodes_in_group("customer_spawner")
	if spawners.size() > 0:
		var spawner = spawners[0] as CustomerSpawner
		if spawner and is_instance_valid(spawner.current_customer):
			return spawner.current_customer
	return null

func _on_dialogic_variable_changed(info: Dictionary) -> void:
	var var_path = str(info.get("variable", ""))
	
	if var_path == "Transaction_Branch":
		var customer = _get_current_customer()
		if is_instance_valid(customer) and customer.customer_data:
			var new_val = float(info.get("new_value", 0.0))
			CharacterProgressionManager.save_branch(customer.customer_data.resource_path, new_val)
			_save_progression()
			
	elif var_path == "Transaction_ItemWants":
		# Manual morphing implemented via upgrade_desires() instead of automatic listeners
		pass

func _on_dialogic_signal(argument: String) -> void:
	if argument == "refresh_desires":
		refresh_desires()
	elif argument == "upgrade_desires":
		upgrade_desires()
	elif argument.begins_with("set_desire:"):
		var item_name := argument.substr(len("set_desire:")).strip_edges()
		set_desire(item_name)
	elif argument.begins_with("story_success"):
		var override_path = ""
		if argument.begins_with("story_success:"):
			override_path = argument.substr(len("story_success:")).strip_edges()
			
		if override_path != "":
			CharacterProgressionManager.advance_story_direct(override_path)
			return

		var customer = _get_current_customer()
		if customer:
			LogManager.info("StoryManager", "Direct Advance: 'story_success' payload matched active spawner: %s" % customer.customer_data.character_name)
			_process_story_cooldown(customer)
			_save_progression()
		else:
			push_error("[StoryManager] Direct Advance FAILED: 'story_success' signal received with no active customer and no explicit path.")

func refresh_desires() -> void:
	var customer = _get_current_customer()
	if not is_instance_valid(customer) or not customer.transaction_context:
		LogManager.warn("StoryManager", "REFRESH FAILED: No active customer or context.")
		return
		
	var transaction = customer.transaction_context
	var old_desires = Dialogic.VAR.get_variable("Transaction_ItemWants", "")
	var old_type = transaction.transaction_type
	var old_timeline = transaction.timeline
	var old_visit_story = transaction.is_visit_story
	var old_items: Array[ItemData] = transaction.desired_items.duplicate()
	
	transaction.desired_items.clear()
	_build_transaction_context(transaction, customer.customer_data, old_type == TransactionContext.Type.STORY)
	
	# Restore critical states so we don't abruptly change timeline midway
	transaction.transaction_type = old_type
	transaction.timeline = old_timeline
	transaction.is_visit_story = old_visit_story

	# Guard: if _build_transaction_context rolled VISIT during a PURCHASE refresh,
	# desired_items would be left empty — restore the previous items so the customer
	# never rejects the exact items they asked for.
	if old_type != TransactionContext.Type.VISIT and not old_visit_story and transaction.desired_items.is_empty():
		if not old_items.is_empty():
			transaction.desired_items.assign(old_items)
		else:
			var fallback := OrderItemPicker.random_orderable(current_tier)
			if fallback:
				transaction.desired_items.append(fallback)
	
	upgrade_desires()
	EventBus.customer_order_updated.emit(customer.customer_data.character_name, transaction.desired_items, transaction.is_riddle)
	LogManager.info("StoryManager", "REFRESH: %s -> %s" % [old_desires, Dialogic.VAR.get_variable("Transaction_ItemWants", "")])
	LogManager.info("StoryManager", "Desires refreshed and upgraded via signal.")

## Force a specific named item as the customer's desire, then upgrade to best tier.
## Usage in Dialogic: [signal arg="set_desire:Kopimo"]
func set_desire(item_name: String) -> void:
	var customer = _get_current_customer()
	if not is_instance_valid(customer) or not customer.transaction_context:
		LogManager.warn("StoryManager", "SET_DESIRE FAILED: No active customer or context.")
		return
	
	var target_item := OrderItemPicker.find_by_name(item_name)
	if not target_item:
		push_warning("[StoryManager] set_desire: No item matching '%s' found in inventory." % item_name)
		return
	
	LogManager.info("StoryManager", "SET_DESIRE: Matched '%s' -> '%s'" % [item_name, target_item.item_name])
	
	var transaction = customer.transaction_context
	var typed_list: Array[ItemData] = [target_item]
	transaction.desired_items.assign(typed_list)
	
	upgrade_desires()
	LogManager.info("StoryManager", "SET_DESIRE: Forced desire to '%s' -> upgraded to '%s'" % [item_name, Dialogic.VAR.get_variable("Transaction_ItemWants", "")])

## Manual command to upgrade current items to their best available tiers.
## Usage in Dialogic: [signal arg="upgrade_desires"] or [do StoryManager.upgrade_desires()]
func upgrade_desires() -> void:
	var customer = _get_current_customer()
	if not is_instance_valid(customer) or not customer.transaction_context:
		return
		
	var transaction = customer.transaction_context
	if transaction.desired_items.is_empty(): return
	
	var new_list: Array[ItemData] = []
	for old_item in transaction.desired_items:
		var best = get_best_item_for_category(old_item.category, old_item)
		if best: new_list.append(best)
		else: new_list.append(old_item)
	
	transaction.desired_items.assign(new_list)
	update_transaction_item_string(transaction)
	LogManager.info("StoryManager", "Manual Upgrade Executed: %s" % Dialogic.VAR.get_variable("Transaction_ItemWants", ""))

func update_transaction_item_string(transaction: TransactionContext) -> void:
	DialogicBridge.sync_item_string(transaction)


## Helper to see if a label exists in a timeline file (.dtl) safely without crashing.
func is_label_in_timeline(path, label_name: String) -> bool:
	return TimelineLabels.has_label(path, label_name)


func is_past_closing_time() -> bool:
	return clock.is_past_closing_time()

func reset_to_morning() -> void:
	clock.reset_to_morning()

func has_pending_tier_advance() -> bool:
	return _pending_tier_advance_source != ""
