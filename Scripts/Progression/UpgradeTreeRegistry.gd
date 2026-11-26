class_name UpgradeTreeRegistry
extends RefCounted

## Modular, data-driven Skill Tree definition for Store Upgrades.
## Layout (logical x in [0..8], y in [0..4] bottom-up):
##   Row 0 (y=0, x=0..8): Horizontal Store Tiers 2 -> 10 along the bottom
##   Rows 1..4: Individual expanded upgrade-level nodes rising in branches correlated to Store Tiers.
##
## No player_level gates: unlocking a prerequisite node unlocks its children;
## the player decides what to prioritize with Pesos.

const NODES: Array[Dictionary] = [
	# ── CENTRAL ROOT NODE: Store Tiers 1 → 10 (Tier 1 unlocked by default; x = 4.5, y = 0.0) ──
	{"id": "store_tier", "title": "Store Tier", "pos": Vector2(4.5, 0.0), "max_level": 10, "prereqs": [], "kind": "tier_hub"},

	# ── COL 0 (Tier 2): Business Permit I → II → III ──
	{"id": "permit_1", "title": "Business Permit I", "pos": Vector2(0.0, 1.0), "max_level": 1, "target_level": 1, "req_tier": 2, "prereqs": ["store_tier"], "kind": "permit"},
	{"id": "permit_2", "title": "Business Permit II", "pos": Vector2(0.0, 2.0), "max_level": 1, "target_level": 2, "prereqs": ["permit_1"], "kind": "permit"},
	{"id": "permit_3", "title": "Business Permit III", "pos": Vector2(0.0, 3.0), "max_level": 1, "target_level": 3, "prereqs": ["permit_2"], "kind": "permit"},

	# ── COL 1 (Tier 2): Refrigerator I → II → III ──
	{"id": "fridge_1", "title": "Fridge Gasket", "pos": Vector2(1.0, 1.0), "max_level": 1, "target_level": 1, "req_tier": 2, "prereqs": ["store_tier"], "kind": "fridge"},
	{"id": "fridge_2", "title": "Fridge Insulation", "pos": Vector2(1.0, 2.0), "max_level": 1, "target_level": 2, "prereqs": ["fridge_1"], "kind": "fridge"},
	{"id": "fridge_3", "title": "Inverter Compressor", "pos": Vector2(1.0, 3.0), "max_level": 1, "target_level": 3, "prereqs": ["fridge_2"], "kind": "fridge"},

	# ── COL 2: Wholesale Pass I → II (branches cleanly from Fridge I onto strict Rows 2 & 3) ──
	{"id": "wholesale_pass", "title": "Wholesale Pass", "pos": Vector2(2.0, 2.0), "max_level": 1, "target_level": 1, "prereqs": ["fridge_1"], "kind": "mario_deals"},
	{"id": "wholesale_pass_2", "title": "Wholesale Pass II", "pos": Vector2(2.0, 3.0), "max_level": 1, "target_level": 2, "prereqs": ["wholesale_pass"], "kind": "mario_deals"},

	# ── COL 3 (Tier 3): Tambayan Bench I → II → III ──
	{"id": "bench_1", "title": "Tambayan Bench I", "pos": Vector2(3.0, 1.0), "max_level": 1, "target_level": 1, "req_tier": 3, "prereqs": ["store_tier"], "kind": "bench"},
	{"id": "bench_2", "title": "Tambayan Bench II", "pos": Vector2(3.0, 2.0), "max_level": 1, "target_level": 2, "prereqs": ["bench_1"], "kind": "bench"},
	{"id": "bench_3", "title": "Tambayan Bench III", "pos": Vector2(3.0, 3.0), "max_level": 1, "target_level": 3, "prereqs": ["bench_2"], "kind": "bench"},

	# ── COL 4 (Tier 3): Barangay Radio I → II → III ──
	{"id": "radio_1", "title": "Barangay Radio I", "pos": Vector2(4.0, 1.0), "max_level": 1, "target_level": 1, "req_tier": 3, "prereqs": ["store_tier"], "kind": "radio"},
	{"id": "radio_2", "title": "Barangay Radio II", "pos": Vector2(4.0, 2.0), "max_level": 1, "target_level": 2, "prereqs": ["radio_1"], "kind": "radio"},
	{"id": "radio_3", "title": "Barangay Radio III", "pos": Vector2(4.0, 3.0), "max_level": 1, "target_level": 3, "prereqs": ["radio_2"], "kind": "radio"},

	# ── COL 5: Store Trash Can → Recycling Program (branches cleanly from Radio I onto strict Rows 2 & 3) ──
	{"id": "trash_can", "title": "Store Trash Can", "pos": Vector2(5.0, 2.0), "max_level": 1, "target_level": 1, "prereqs": ["radio_1"], "kind": "trash"},
	{"id": "recycling", "title": "Recycling Program", "pos": Vector2(5.0, 3.0), "max_level": 1, "target_level": 1, "prereqs": ["trash_can"], "kind": "recycling"},

	# ── COL 6 (Tier 4): Barangay Cat I → II ──
	{"id": "cat_1", "title": "Barangay Cat I", "pos": Vector2(6.0, 1.0), "max_level": 1, "target_level": 1, "req_tier": 4, "prereqs": ["store_tier"], "kind": "cat"},
	{"id": "cat_2", "title": "Barangay Cat II", "pos": Vector2(6.0, 2.0), "max_level": 1, "target_level": 2, "prereqs": ["cat_1"], "kind": "cat"},

	# ── COL 7 (Tier 5): Sto. Niño Altar I → II → III ──
	{"id": "sto_nino_1", "title": "Sto. Niño Altar I", "pos": Vector2(7.0, 1.0), "max_level": 1, "target_level": 1, "req_tier": 5, "prereqs": ["store_tier"], "kind": "sto_nino"},
	{"id": "sto_nino_2", "title": "Sto. Niño Altar II", "pos": Vector2(7.0, 2.0), "max_level": 1, "target_level": 2, "prereqs": ["sto_nino_1"], "kind": "sto_nino"},
	{"id": "sto_nino_3", "title": "Sto. Niño Altar III", "pos": Vector2(7.0, 3.0), "max_level": 1, "target_level": 3, "prereqs": ["sto_nino_2"], "kind": "sto_nino"},

	# ── COL 8 (Tier 6): Maneki-Neko I → II ──
	{"id": "maneki_1", "title": "Maneki-Neko", "pos": Vector2(8.0, 1.0), "max_level": 1, "target_level": 1, "req_tier": 6, "prereqs": ["store_tier"], "kind": "maneki"},
	{"id": "maneki_2", "title": "Fresh Batteries", "pos": Vector2(8.0, 2.0), "max_level": 1, "target_level": 2, "prereqs": ["maneki_1"], "kind": "maneki"},

	# ── COL 9 (Tier 2): Storefront Signage → Poster ──
	{"id": "signage", "title": "Roof Signage", "pos": Vector2(9.0, 1.0), "max_level": 1, "target_level": 1, "req_tier": 2, "prereqs": ["store_tier"], "kind": "storefront_step", "storefront_level": 1},
	{"id": "poster", "title": "Promo Poster", "pos": Vector2(9.0, 2.0), "max_level": 1, "target_level": 2, "prereqs": ["signage"], "kind": "storefront_step", "storefront_level": 2},

	# ── CAPSTONE: Open the Door (Top-Center at x = 4.5, y = 4.0) ──
	{"id": "open_door", "title": "Open the Door", "pos": Vector2(4.5, 4.0), "max_level": 1, "target_level": 3, "prereqs": ["permit_3", "fridge_3", "wholesale_pass", "bench_3", "radio_3", "trash_can", "sto_nino_3", "maneki_2", "poster"], "kind": "storefront_step", "storefront_level": 3},
]


static func get_all_nodes() -> Array[Dictionary]:
	return NODES


static func get_node_def(node_id: String) -> Dictionary:
	for n in NODES:
		if str(n["id"]) == node_id:
			return n
	return {}


static func get_node_level(node_id: String, pending_levels: Dictionary = {}) -> int:
	var pending := int(pending_levels.get(node_id, 0))
	var def := get_node_def(node_id)
	if def.is_empty() or not is_instance_valid(StoryManager):
		return pending
	if str(def["kind"]) == "tier_hub":
		var base_t := maxi(1, StoryManager.current_tier)
		return mini(int(def["max_level"]), base_t + pending)
	var req_lvl := int(def.get("target_level", 1))
	var owned := false
	match str(def["kind"]):
		"permit":
			owned = StoryManager.permit_upgrade_level >= req_lvl
		"fridge":
			owned = StoryManager.fridge_upgrade_level >= req_lvl
		"mario_deals":
			owned = StoryManager.mario_deals_level >= req_lvl
		"bench":
			owned = StoryManager.bench_upgrade_level >= req_lvl
		"radio":
			owned = StoryManager.radio_upgrade_level >= req_lvl
		"trash":
			owned = StoryManager.has_trash_can
		"recycling":
			owned = StoryManager.has_recycling
		"cat":
			owned = StoryManager.cat_upgrade_level >= req_lvl
		"sto_nino":
			owned = StoryManager.sto_nino_upgrade_level >= req_lvl
		"maneki":
			owned = StoryManager.maneki_upgrade_level >= req_lvl
		"storefront_step":
			owned = StoryManager.storefront_upgrade_level >= int(def["storefront_level"])
	return 1 if (owned or pending >= 1) else 0


static func is_node_unlocked_in_tree(node_id: String, pending_levels: Dictionary = {}) -> bool:
	return get_node_level(node_id, pending_levels) >= 1


static func are_prerequisites_met(node_id: String, pending_levels: Dictionary = {}) -> bool:
	var def := get_node_def(node_id)
	if def.is_empty():
		return false
	var req_tier := int(def.get("req_tier", 0))
	if req_tier > 1:
		var eff_tier := get_node_level("store_tier", pending_levels)
		if eff_tier < req_tier:
			return false
	for pre_id in def.get("prereqs", []):
		if not is_node_unlocked_in_tree(str(pre_id), pending_levels):
			return false
	return true


static func get_node_item(node_id: String, target_level: int = -1) -> ItemData:
	var def := get_node_def(node_id)
	if def.is_empty() or not is_instance_valid(StoryManager):
		return null
	var lvl := int(def.get("target_level", 1)) if target_level <= 0 else target_level
	match str(def["kind"]):
		"tier_hub":
			return StoryManager.get_tier_upgrade_item(clampi(lvl, 2, 10))
		"permit":
			return StoryManager.get_permit_upgrade_item(lvl)
		"fridge":
			return StoryManager.get_fridge_upgrade_item(lvl)
		"mario_deals":
			return StoryManager.get_mario_deals_upgrade_item(lvl)
		"bench":
			return StoryManager.get_bench_upgrade_item(lvl)
		"radio":
			return StoryManager.get_radio_upgrade_item(lvl)
		"trash":
			return StoryManager.get_trash_can_upgrade_item()
		"recycling":
			return StoryManager.get_recycling_upgrade_item()
		"cat":
			return StoryManager.get_cat_upgrade_item(lvl)
		"sto_nino":
			return StoryManager.get_sto_nino_upgrade_item(lvl)
		"maneki":
			return StoryManager.get_maneki_upgrade_item(lvl)
		"storefront_step":
			return StoryManager.get_storefront_upgrade_item(int(def["storefront_level"]))
	return null


static func get_short_description(node_id: String) -> String:
	match node_id:
		"permit_1":
			return "A fresh barangay clearance stamped in blue ink and taped beside the counter. Word gets around fast that your tindahan is officially open for business."
		"permit_2":
			return "Your municipal registration hangs neatly in a proper frame. Even the stricter elders in Karimlan nod with newfound respect when they stop by."
		"permit_3":
			return "The barangay's prized gold-sealed license—proof that this little corner store has grown into a true neighborhood institution."
		"fridge_1":
			return "A fresh rubber seal snaps the fridge door shut with a satisfying thump. No more cold air leaking out into the humid afternoon."
		"fridge_2":
			return "Thick thermal lining wraps the old cabinet's walls. Even when the sun beats down on the tin roof, the drinks inside stay frosty."
		"fridge_3":
			return "A whisper-quiet commercial compressor hums behind the bottles. It chills warm stock back to ice-cold before the next rush even starts."
		"wholesale_pass":
			return "Uncle Mario slips you a laminated market pass with his signature on the back. Now you get first pick of the morning's discounted crates."
		"wholesale_pass_2":
			return "Direct bodega contracts under your store's name. Mario's suppliers set aside their best bulk deals before anyone else in town can claim them."
		"bench_1":
			return "A sturdy wooden bench set out beneath the eaves. Neighbors finally have a shady spot to sit, sip, and trade stories."
		"bench_2":
			return "Smooth varnished planks and a wider backrest turn your stoop into the block's favorite hangout. One quick errand easily turns into an afternoon chat."
		"bench_3":
			return "Cushioned, well-worn, and always lively—the unofficial barangay plaza right outside your window. Everyone in Karimlan knows where to find good company."
		"radio_1":
			return "A trusty battery-powered transistor tuned straight to Papa Ulap's station. Between classic ballads, you catch wind of who's heading down the street."
		"radio_2":
			return "A hand-wound copper coil sharpens the static into crystal-clear reception. Even the quieter barangay bulletins now reach your counter."
		"radio_3":
			return "A high-gain signal amplifier picks up every whisper on the airwaves. Nothing happens in Karimlan without your radio calling it first."
		"trash_can":
			return "A battered galvanized bin tucked neatly in the corner. Keeps the counter tidy and gives expired or unwanted stock a clean place to go."
		"recycling":
			return "Separate bottles, tins, and cartons for the local junk shop cart. Even tossed stock finds a second life—and puts a few pesos back in your drawer."
		"cat_1":
			return "A sleepy orange tabby has officially claimed the warm spot beside your counter. Neighbors can't resist stopping just to scratch behind Mingming's ears."
		"cat_2":
			return "Well-fed and glossy-coated, Mingming now greets every passerby like royalty. Half the street lines up just to see the neighborhood's favorite storekeeper."
		"sto_nino_1":
			return "A small wooden shelf dressed with lace and a flickering candle. Tap the altar each morning to ask for a quiet blessing over the day's work."
		"sto_nino_2":
			return "Fresh sampaguita garlands and a polished red velvet cape adorn the little shrine. Its warm candlelight steadies the shop through busier hours."
		"sto_nino_3":
			return "Carved narra wood and an ever-burning vigil lamp watch over the entire tindahan. The altar's grace lingers gently from sunrise until the shutters close."
		"maneki_1":
			return "A glossy porcelain waving cat perched right by the coin tray. Its steady paw seems to beckon both good fortune and generous change."
		"maneki_2":
			return "Brand-new AA batteries put a brisk, cheerful rhythm back into that waving paw. Shoppers smile at the tireless little cat—and leave a little extra behind."
		"signage":
			return "A freshly primed signboard mounted above the awning, waiting for your own hand-painted lettering. Make your tindahan unmistakable from down the road."
		"poster":
			return "A bright display board hung right beside the window for your custom specials. Catch passing eyes and spotlight whatever you want to move today."
		"open_door":
			return "Unbolt the heavy wooden door and welcome Karimlan inside. After all these nights of hard work, your family's sari-sari store is finally whole again."
	return ""


## Returns Event-Card style incremental stat dictionaries for this specific node: {"label", "value", "tone"}
static func get_node_stats(node_id: String, target_level: int = -1) -> Array[Dictionary]:
	var def := get_node_def(node_id)
	if def.is_empty():
		return []
	var stats: Array[Dictionary] = []
	var lvl := maxi(1, int(def.get("target_level", 1)) if target_level <= 0 else target_level)

	match str(def["kind"]):
		"tier_hub":
			var t := clampi(lvl, 2, 10)
			stats.append({"label": "Catalog Tier:", "value": "Tier %d" % t, "tone": "neu"})
			stats.append({"label": "Starter Samples:", "value": "+2x Each", "tone": "pos"})
			if t == 10:
				stats.append({"label": "Candy Containers:", "value": "Separated", "tone": "pos"})
		"permit":
			var prev: Dictionary = StoryManager.PERMIT_UPGRADE_SPECS[clampi(lvl - 1, 0, StoryManager.PERMIT_UPGRADE_SPECS.size() - 1)]
			var spec: Dictionary = StoryManager.PERMIT_UPGRADE_SPECS[clampi(lvl, 0, StoryManager.PERMIT_UPGRADE_SPECS.size() - 1)]
			var d_pct := int(roundf((float(spec["xp_mult"]) - float(prev["xp_mult"])) * 100.0))
			if d_pct != 0:
				stats.append({"label": "XP Multiplier:", "value": "+%d%%" % d_pct, "tone": "pos"})
		"fridge":
			var prev: Dictionary = StoryManager.FRIDGE_UPGRADE_SPECS[clampi(lvl - 1, 0, StoryManager.FRIDGE_UPGRADE_SPECS.size() - 1)]
			var spec: Dictionary = StoryManager.FRIDGE_UPGRADE_SPECS[clampi(lvl, 0, StoryManager.FRIDGE_UPGRADE_SPECS.size() - 1)]
			var d_drain := float(spec["drain_sec"]) - float(prev["drain_sec"])
			var d_regen := float(spec["regen_sec"]) - float(prev["regen_sec"])
			if d_drain > 0.01:
				stats.append({"label": "Cold Duration:", "value": "+%.1fs" % d_drain, "tone": "pos"})
			if d_regen < -0.01:
				stats.append({"label": "Re-Chill Time:", "value": "%.1fs" % d_regen, "tone": "pos"})
		"mario_deals":
			var deals_lvl := clampi(int(def.get("target_level", 1)), 1, StoryManager.MARIO_DEALS_SPECS.size() - 1)
			var d_items: int = int(StoryManager.MARIO_DEALS_SPECS[deals_lvl]["items"]) - int(StoryManager.MARIO_DEALS_SPECS[deals_lvl - 1]["items"])
			var disc := int(roundf((1.0 - float(StoryManager.MARIO_DEALS_SPECS[deals_lvl]["mult"])) * 100.0))
			stats.append({"label": "Daily Deals:", "value": "+%d Items" % d_items, "tone": "pos"})
			stats.append({"label": "Wholesale Discount:", "value": "-%d%%" % disc, "tone": "pos"})
			if deals_lvl == 1:
				stats.append({"label": "Mario Cooldown:", "value": "-30%", "tone": "pos"})
		"recycling":
			stats.append({"label": "Trash Refund:", "value": "+50% Value", "tone": "pos"})
		"bench":
			var prev: Dictionary = StoryManager.BENCH_UPGRADE_SPECS[clampi(lvl - 1, 0, StoryManager.BENCH_UPGRADE_SPECS.size() - 1)]
			var spec: Dictionary = StoryManager.BENCH_UPGRADE_SPECS[clampi(lvl, 0, StoryManager.BENCH_UPGRADE_SPECS.size() - 1)]
			var d_ch := int(roundf((float(spec["linger_chance"]) - float(prev["linger_chance"])) * 100.0))
			var d_max := int(spec["max_lingering"]) - int(prev["max_lingering"])
			if d_ch > 0:
				stats.append({"label": "Linger Chance:", "value": "+%d%%" % d_ch, "tone": "pos"})
			if d_max > 0:
				stats.append({"label": "Max Lingering:", "value": "+%d" % d_max, "tone": "pos"})
		"radio":
			var prev: Dictionary = StoryManager.RADIO_UPGRADE_SPECS[clampi(lvl - 1, 0, StoryManager.RADIO_UPGRADE_SPECS.size() - 1)]
			var spec: Dictionary = StoryManager.RADIO_UPGRADE_SPECS[clampi(lvl, 0, StoryManager.RADIO_UPGRADE_SPECS.size() - 1)]
			var d_rev := int(spec["reveals"]) - int(prev["reveals"])
			var d_ev := int(spec["max_events"]) - int(prev["max_events"])
			if d_rev > 0:
				stats.append({"label": "Daily Visitors:", "value": "+%d" % d_rev, "tone": "pos"})
			if d_ev > 0:
				stats.append({"label": "Daily Events:", "value": "+%d" % d_ev, "tone": "pos"})
		"trash":
			stats.append({"label": "Stock Disposal:", "value": "Unlocked", "tone": "pos"})
		"cat":
			var prev: Dictionary = StoryManager.CAT_UPGRADE_SPECS[clampi(lvl - 1, 0, StoryManager.CAT_UPGRADE_SPECS.size() - 1)]
			var spec: Dictionary = StoryManager.CAT_UPGRADE_SPECS[clampi(lvl, 0, StoryManager.CAT_UPGRADE_SPECS.size() - 1)]
			var d_slots := int(spec["slots"]) - int(prev["slots"])
			if d_slots > 0:
				stats.append({"label": "Counter Slots:", "value": "+%d" % d_slots, "tone": "pos"})
		"sto_nino":
			var prev: Dictionary = StoryManager.STO_NINO_UPGRADE_SPECS[clampi(lvl - 1, 0, StoryManager.STO_NINO_UPGRADE_SPECS.size() - 1)]
			var spec: Dictionary = StoryManager.STO_NINO_UPGRADE_SPECS[clampi(lvl, 0, StoryManager.STO_NINO_UPGRADE_SPECS.size() - 1)]
			var dur := float(spec["duration_hours"])
			var prev_dur := float(prev["duration_hours"])
			if dur <= 0.0:
				stats.append({"label": "Blessing Duration:", "value": "All Day", "tone": "pos"})
			elif dur - prev_dur > 0.01:
				stats.append({"label": "Blessing Duration:", "value": "+%.0fh" % (dur - prev_dur), "tone": "pos"})
			var d_fav := int(spec["favor_count"]) - int(prev["favor_count"])
			if d_fav > 0:
				stats.append({"label": "Favor Choices:", "value": "+%d" % d_fav, "tone": "pos"})
		"maneki":
			var prev: Dictionary = StoryManager.MANEKI_UPGRADE_SPECS[clampi(lvl - 1, 0, StoryManager.MANEKI_UPGRADE_SPECS.size() - 1)]
			var spec: Dictionary = StoryManager.MANEKI_UPGRADE_SPECS[clampi(lvl, 0, StoryManager.MANEKI_UPGRADE_SPECS.size() - 1)]
			var d_tip := int(roundf((float(spec.get("tip_bonus_pct", 0.0)) - float(prev.get("tip_bonus_pct", 0.0))) * 100.0))
			if d_tip > 0:
				stats.append({"label": "Tip Bonus:", "value": "+%d%%" % d_tip, "tone": "pos"})
		"storefront_step":
			var sf_lvl := int(def["storefront_level"])
			var prev: Dictionary = StoryManager.STOREFRONT_UPGRADE_SPECS[clampi(sf_lvl - 1, 0, StoryManager.STOREFRONT_UPGRADE_SPECS.size() - 1)]
			var spec: Dictionary = StoryManager.STOREFRONT_UPGRADE_SPECS[clampi(sf_lvl, 0, StoryManager.STOREFRONT_UPGRADE_SPECS.size() - 1)]
			var d_tip := int(roundf((float(spec["tip_chance"]) - float(prev["tip_chance"])) * 100.0))
			var d_rel := int(roundf((float(spec["price_relief"]) - float(prev["price_relief"])) * 100.0))
			if d_tip > 0:
				stats.append({"label": "Tip Chance:", "value": "+%d%%" % d_tip, "tone": "pos"})
			if d_rel > 0:
				stats.append({"label": "Price Relief:", "value": "+%d%%" % d_rel, "tone": "pos"})
			if sf_lvl == 2:
				stats.append({"label": "Promo Bonus:", "value": "+₱3", "tone": "pos"})
			elif sf_lvl == 3:
				stats.append({"label": "Street Access:", "value": "Unlocked", "tone": "pos"})
	return stats


static func evaluate_node(node_id: String, available_money: float, pending_levels: Dictionary = {}) -> Dictionary:
	var def := get_node_def(node_id)
	if def.is_empty():
		return {"state": "locked", "can_buy": false, "reason": "Unknown node", "cur_level": 0, "max_level": 1, "target_level": 1, "cost": 0.0, "item": null}

	var max_lvl := int(def["max_level"])
	var cur_lvl := get_node_level(node_id, pending_levels)
	var target_lvl := (cur_lvl + 1) if max_lvl > 1 else int(def.get("target_level", 1))
	if cur_lvl >= max_lvl:
		var owned_item := get_node_item(node_id, max_lvl if max_lvl > 1 else target_lvl)
		return {
			"state": "maxed",
			"can_buy": false,
			"reason": "Maxed Out" if max_lvl > 1 else "Owned",
			"cur_level": cur_lvl,
			"max_level": max_lvl,
			"target_level": max_lvl if max_lvl > 1 else target_lvl,
			"cost": 0.0,
			"item": owned_item,
		}

	var item := get_node_item(node_id, target_lvl)
	var cost := item.price if item else 0.0
	if not are_prerequisites_met(node_id, pending_levels):
		var req_t := int(def.get("req_tier", 0))
		var reason := ("Requires Store Tier %d" % req_t) if req_t > 1 else "Unlock prerequisite first"
		return {
			"state": "locked",
			"can_buy": false,
			"reason": reason,
			"cur_level": cur_lvl,
			"max_level": max_lvl,
			"target_level": target_lvl,
			"cost": cost,
			"item": item,
		}

	if available_money < cost:
		return {
			"state": "available_poor",
			"can_buy": false,
			"reason": "Need ₱%.0f" % cost,
			"cur_level": cur_lvl,
			"max_level": max_lvl,
			"target_level": target_lvl,
			"cost": cost,
			"item": item,
		}

	return {
		"state": "available",
		"can_buy": true,
		"reason": "",
		"cur_level": cur_lvl,
		"max_level": max_lvl,
		"target_level": target_lvl,
		"cost": cost,
		"item": item,
	}
