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
	# ── BOTTOM HORIZONTAL ROW: Store Tiers 2 → 10 (x = 0..8, y = 0) ──
	{"id": "tier_2", "title": "Store Tier 2", "pos": Vector2(0.0, 0.0), "max_level": 1, "target_level": 1, "prereqs": [], "kind": "tier", "tier": 2},
	{"id": "tier_3", "title": "Store Tier 3", "pos": Vector2(1.0, 0.0), "max_level": 1, "target_level": 1, "prereqs": ["tier_2"], "kind": "tier", "tier": 3},
	{"id": "tier_4", "title": "Store Tier 4", "pos": Vector2(2.0, 0.0), "max_level": 1, "target_level": 1, "prereqs": ["tier_3"], "kind": "tier", "tier": 4},
	{"id": "tier_5", "title": "Store Tier 5", "pos": Vector2(3.0, 0.0), "max_level": 1, "target_level": 1, "prereqs": ["tier_4"], "kind": "tier", "tier": 5},
	{"id": "tier_6", "title": "Store Tier 6", "pos": Vector2(4.0, 0.0), "max_level": 1, "target_level": 1, "prereqs": ["tier_5"], "kind": "tier", "tier": 6},
	{"id": "tier_7", "title": "Store Tier 7", "pos": Vector2(5.0, 0.0), "max_level": 1, "target_level": 1, "prereqs": ["tier_6"], "kind": "tier", "tier": 7},
	{"id": "tier_8", "title": "Store Tier 8", "pos": Vector2(6.0, 0.0), "max_level": 1, "target_level": 1, "prereqs": ["tier_7"], "kind": "tier", "tier": 8},
	{"id": "tier_9", "title": "Store Tier 9", "pos": Vector2(7.0, 0.0), "max_level": 1, "target_level": 1, "prereqs": ["tier_8"], "kind": "tier", "tier": 9},
	{"id": "tier_10", "title": "Store Tier 10", "pos": Vector2(8.0, 0.0), "max_level": 1, "target_level": 1, "prereqs": ["tier_9"], "kind": "tier", "tier": 10},

	# ── BRANCH 1 (Tier 2): Business Permit I → II → III (x = 0.0) ──
	{"id": "permit_1", "title": "Business Permit I", "pos": Vector2(0.0, 1.0), "max_level": 1, "target_level": 1, "prereqs": ["tier_2"], "kind": "permit"},
	{"id": "permit_2", "title": "Business Permit II", "pos": Vector2(0.0, 2.0), "max_level": 1, "target_level": 2, "prereqs": ["permit_1"], "kind": "permit"},
	{"id": "permit_3", "title": "Business Permit III", "pos": Vector2(0.0, 3.0), "max_level": 1, "target_level": 3, "prereqs": ["permit_2"], "kind": "permit"},

	# ── BRANCH 2 (Tier 2): Refrigerator I → II → III, and Wholesale Pass from Fridge I ──
	{"id": "fridge_1", "title": "Fridge Gasket", "pos": Vector2(1.0, 1.0), "max_level": 1, "target_level": 1, "prereqs": ["tier_2"], "kind": "fridge"},
	{"id": "fridge_2", "title": "Fridge Insulation", "pos": Vector2(1.0, 2.0), "max_level": 1, "target_level": 2, "prereqs": ["fridge_1"], "kind": "fridge"},
	{"id": "fridge_3", "title": "Inverter Compressor", "pos": Vector2(1.0, 3.0), "max_level": 1, "target_level": 3, "prereqs": ["fridge_2"], "kind": "fridge"},
	{"id": "wholesale_pass", "title": "Wholesale Pass", "pos": Vector2(1.7, 2.5), "max_level": 1, "target_level": 1, "prereqs": ["fridge_1"], "kind": "mario_deals"},

	# ── BRANCH 3 (Tier 3): Tambayan Bench I → II → III (x = 2.45) ──
	{"id": "bench_1", "title": "Tambayan Bench I", "pos": Vector2(2.45, 1.0), "max_level": 1, "target_level": 1, "prereqs": ["tier_3"], "kind": "bench"},
	{"id": "bench_2", "title": "Tambayan Bench II", "pos": Vector2(2.45, 2.0), "max_level": 1, "target_level": 2, "prereqs": ["bench_1"], "kind": "bench"},
	{"id": "bench_3", "title": "Tambayan Bench III", "pos": Vector2(2.45, 3.0), "max_level": 1, "target_level": 3, "prereqs": ["bench_2"], "kind": "bench"},

	# ── BRANCH 4 (Tier 3): Barangay Radio I → II → III, and Trash Can from Radio I ──
	{"id": "radio_1", "title": "Barangay Radio I", "pos": Vector2(3.45, 1.0), "max_level": 1, "target_level": 1, "prereqs": ["tier_3"], "kind": "radio"},
	{"id": "radio_2", "title": "Barangay Radio II", "pos": Vector2(3.45, 2.0), "max_level": 1, "target_level": 2, "prereqs": ["radio_1"], "kind": "radio"},
	{"id": "radio_3", "title": "Barangay Radio III", "pos": Vector2(3.45, 3.0), "max_level": 1, "target_level": 3, "prereqs": ["radio_2"], "kind": "radio"},
	{"id": "trash_can", "title": "Store Trash Can", "pos": Vector2(4.15, 2.5), "max_level": 1, "target_level": 1, "prereqs": ["radio_1"], "kind": "trash"},

	# ── BRANCH 5 (Tier 4): Barangay Cat I → II (x = 4.9) ──
	{"id": "cat_1", "title": "Barangay Cat I", "pos": Vector2(4.9, 1.0), "max_level": 1, "target_level": 1, "prereqs": ["tier_4"], "kind": "cat"},
	{"id": "cat_2", "title": "Barangay Cat II", "pos": Vector2(4.9, 2.0), "max_level": 1, "target_level": 2, "prereqs": ["cat_1"], "kind": "cat"},

	# ── BRANCH 6 (Tier 5): Sto. Niño Altar I → II → III (x = 5.9) ──
	{"id": "sto_nino_1", "title": "Sto. Niño Altar I", "pos": Vector2(5.9, 1.0), "max_level": 1, "target_level": 1, "prereqs": ["tier_5"], "kind": "sto_nino"},
	{"id": "sto_nino_2", "title": "Sto. Niño Altar II", "pos": Vector2(5.9, 2.0), "max_level": 1, "target_level": 2, "prereqs": ["sto_nino_1"], "kind": "sto_nino"},
	{"id": "sto_nino_3", "title": "Sto. Niño Altar III", "pos": Vector2(5.9, 3.0), "max_level": 1, "target_level": 3, "prereqs": ["sto_nino_2"], "kind": "sto_nino"},

	# ── BRANCH 7 (Tier 6): Maneki-Neko I → II (x = 6.95) ──
	{"id": "maneki_1", "title": "Maneki-Neko I", "pos": Vector2(6.95, 1.0), "max_level": 1, "target_level": 1, "prereqs": ["tier_6"], "kind": "maneki"},
	{"id": "maneki_2", "title": "Golden Maneki-Neko", "pos": Vector2(6.95, 2.0), "max_level": 1, "target_level": 2, "prereqs": ["maneki_1"], "kind": "maneki"},

	# ── BRANCH 8 (Tier 2): Storefront Signage → Poster (x = 8.0) ──
	{"id": "signage", "title": "Roof Signage", "pos": Vector2(8.0, 1.0), "max_level": 1, "target_level": 1, "prereqs": ["tier_2"], "kind": "storefront_step", "storefront_level": 1},
	{"id": "poster", "title": "Promo Poster", "pos": Vector2(8.0, 2.2), "max_level": 1, "target_level": 2, "prereqs": ["signage"], "kind": "storefront_step", "storefront_level": 2},

	# ── CAPSTONE: Open the Door (Top-Center, requires only Lv. 1 of each branch lead) ──
	{"id": "open_door", "title": "Open the Door", "pos": Vector2(4.0, 4.0), "max_level": 1, "target_level": 3, "prereqs": ["wholesale_pass", "trash_can", "maneki_1", "poster"], "kind": "storefront_step", "storefront_level": 3},
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
		return mini(1, pending)
	var req_lvl := int(def.get("target_level", 1))
	var owned := false
	match str(def["kind"]):
		"tier":
			owned = StoryManager.current_tier >= int(def["tier"])
		"permit":
			owned = StoryManager.permit_upgrade_level >= req_lvl
		"fridge":
			owned = StoryManager.fridge_upgrade_level >= req_lvl
		"mario_deals":
			owned = StoryManager.has_mario_deals
		"bench":
			owned = StoryManager.bench_upgrade_level >= req_lvl
		"radio":
			owned = StoryManager.radio_upgrade_level >= req_lvl
		"trash":
			owned = StoryManager.has_trash_can
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
		"tier":
			return StoryManager.get_tier_upgrade_item(int(def["tier"]))
		"permit":
			return StoryManager.get_permit_upgrade_item(lvl)
		"fridge":
			return StoryManager.get_fridge_upgrade_item(lvl)
		"mario_deals":
			return StoryManager.get_mario_deals_upgrade_item()
		"bench":
			return StoryManager.get_bench_upgrade_item(lvl)
		"radio":
			return StoryManager.get_radio_upgrade_item(lvl)
		"trash":
			return StoryManager.get_trash_can_upgrade_item()
		"cat":
			return StoryManager.get_cat_upgrade_item(lvl)
		"sto_nino":
			return StoryManager.get_sto_nino_upgrade_item(lvl)
		"maneki":
			return StoryManager.get_maneki_upgrade_item(lvl)
		"storefront_step":
			return StoryManager.get_storefront_upgrade_item(int(def["storefront_level"]))
	return null


## Returns Event-Card style stat dictionaries: {"label": String, "value": String, "tone": "pos"|"neg"|"neu"}
static func get_node_stats(node_id: String, target_level: int = -1) -> Array[Dictionary]:
	var def := get_node_def(node_id)
	if def.is_empty():
		return []
	var stats: Array[Dictionary] = []
	var lvl := maxi(1, int(def.get("target_level", 1)) if target_level <= 0 else target_level)

	match str(def["kind"]):
		"tier":
			var t := int(def["tier"])
			stats.append({"label": "Catalog Tier:", "value": "Tier %d" % t, "tone": "neu"})
			stats.append({"label": "Starter Samples:", "value": "+2x Each", "tone": "pos"})
		"permit":
			var spec: Dictionary = StoryManager.PERMIT_UPGRADE_SPECS[clampi(lvl, 0, StoryManager.PERMIT_UPGRADE_SPECS.size() - 1)]
			var pct := int(roundf((float(spec["xp_mult"]) - 1.0) * 100.0))
			stats.append({"label": "XP Multiplier:", "value": "+%d%%" % pct, "tone": "pos"})
		"fridge":
			var spec: Dictionary = StoryManager.FRIDGE_UPGRADE_SPECS[clampi(lvl, 0, StoryManager.FRIDGE_UPGRADE_SPECS.size() - 1)]
			stats.append({"label": "Cold Duration:", "value": "%.0fs" % float(spec["drain_sec"]), "tone": "pos"})
			stats.append({"label": "Re-Chill Time:", "value": "%.0fs" % float(spec["regen_sec"]), "tone": "pos"})
		"mario_deals":
			stats.append({"label": "Daily Deals:", "value": "2–3 Items", "tone": "neu"})
			stats.append({"label": "Wholesale Discount:", "value": "-20%", "tone": "pos"})
		"bench":
			var spec: Dictionary = StoryManager.BENCH_UPGRADE_SPECS[clampi(lvl, 0, StoryManager.BENCH_UPGRADE_SPECS.size() - 1)]
			var ch := int(roundf(float(spec["linger_chance"]) * 100.0))
			stats.append({"label": "Linger Chance:", "value": "%d%%" % ch, "tone": "pos"})
			stats.append({"label": "Max Lingering:", "value": "%d" % int(spec["max_lingering"]), "tone": "pos"})
		"radio":
			var spec: Dictionary = StoryManager.RADIO_UPGRADE_SPECS[clampi(lvl, 0, StoryManager.RADIO_UPGRADE_SPECS.size() - 1)]
			stats.append({"label": "Regulars Revealed:", "value": "%d" % int(spec["reveals"]), "tone": "pos"})
			stats.append({"label": "Max Events:", "value": "%d" % int(spec["max_events"]), "tone": "pos"})
		"trash":
			stats.append({"label": "Stock Disposal:", "value": "Unlocked", "tone": "pos"})
		"cat":
			var spec: Dictionary = StoryManager.CAT_UPGRADE_SPECS[clampi(lvl, 0, StoryManager.CAT_UPGRADE_SPECS.size() - 1)]
			stats.append({"label": "Counter Slots:", "value": "%d" % int(spec["slots"]), "tone": "pos"})
		"sto_nino":
			var spec: Dictionary = StoryManager.STO_NINO_UPGRADE_SPECS[clampi(lvl, 0, StoryManager.STO_NINO_UPGRADE_SPECS.size() - 1)]
			var dur := float(spec["duration_hours"])
			stats.append({"label": "Blessing Duration:", "value": "All Day" if dur <= 0.0 else ("%.0fh" % dur), "tone": "pos"})
			stats.append({"label": "Favor Choices:", "value": "%d" % int(spec["favor_count"]), "tone": "pos"})
		"maneki":
			var spec: Dictionary = StoryManager.MANEKI_UPGRADE_SPECS[clampi(lvl, 0, StoryManager.MANEKI_UPGRADE_SPECS.size() - 1)]
			var tip_pct := int(roundf(float(spec.get("tip_bonus_pct", 0.0)) * 100.0))
			stats.append({"label": "Cash Sale Tip Bonus:", "value": "+%d%%" % tip_pct, "tone": "pos"})
		"storefront_step":
			var sf_lvl := int(def["storefront_level"])
			var spec: Dictionary = StoryManager.STOREFRONT_UPGRADE_SPECS[clampi(sf_lvl, 0, StoryManager.STOREFRONT_UPGRADE_SPECS.size() - 1)]
			var tip_pct := int(roundf(float(spec["tip_chance"]) * 100.0))
			var rel_pct := int(roundf(float(spec["price_relief"]) * 100.0))
			stats.append({"label": "Tip Chance:", "value": "+%d%%" % tip_pct, "tone": "pos"})
			stats.append({"label": "Price Relief:", "value": "+%d%%" % rel_pct, "tone": "pos"})
			if sf_lvl == 2:
				stats.append({"label": "Promo Bonus:", "value": "+₱3", "tone": "pos"})
			elif sf_lvl == 3:
				stats.append({"label": "Street Access:", "value": "Unlocked", "tone": "pos"})
	return stats


static func evaluate_node(node_id: String, available_money: float, pending_levels: Dictionary = {}) -> Dictionary:
	var def := get_node_def(node_id)
	if def.is_empty():
		return {"state": "locked", "can_buy": false, "reason": "Unknown node", "cur_level": 0, "max_level": 1, "target_level": 1, "cost": 0.0, "item": null}

	var target_lvl := int(def.get("target_level", 1))
	var owned := get_node_level(node_id, pending_levels) >= 1
	var item := get_node_item(node_id, target_lvl)
	var cost := item.price if item else 0.0
	if owned:
		return {
			"state": "maxed",
			"can_buy": false,
			"reason": "Owned",
			"cur_level": 1,
			"max_level": 1,
			"target_level": target_lvl,
			"cost": 0.0,
			"item": item,
		}

	if not are_prerequisites_met(node_id, pending_levels):
		return {
			"state": "locked",
			"can_buy": false,
			"reason": "Unlock prerequisite first",
			"cur_level": 0,
			"max_level": 1,
			"target_level": target_lvl,
			"cost": cost,
			"item": item,
		}

	if available_money < cost:
		return {
			"state": "available_poor",
			"can_buy": false,
			"reason": "Need ₱%.0f" % cost,
			"cur_level": 0,
			"max_level": 1,
			"target_level": target_lvl,
			"cost": cost,
			"item": item,
		}

	return {
		"state": "available",
		"can_buy": true,
		"reason": "",
		"cur_level": 0,
		"max_level": 1,
		"target_level": target_lvl,
		"cost": cost,
		"item": item,
	}
