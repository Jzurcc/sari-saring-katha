class_name UpgradeTreeRegistry
extends RefCounted

## Modular, data-driven Skill Tree definition for Store Upgrades.
## Layout:
##   Row 0 (y=0, x=0..8): Horizontal Store Tiers 2 -> 10 along the bottom
##   Rows 1..3: 4 vertical branches rising upward (Permit, Bench, Cat, Roof Signage)
##   Row 4 (y=4, x=4): Capstone [Open the Door]
##
## No player_level or tier_level gates: unlocking Lv. 1 of a prerequisite node
## unlocks its children; the player decides what to prioritize with Pesos.

const NODES: Array[Dictionary] = [
	# ── BOTTOM HORIZONTAL ROW: Store Tiers 2 → 10 (x = 0..8, y = 0) ──
	{"id": "tier_2", "title": "Store Tier 2", "pos": Vector2(0.0, 0.0), "max_level": 1, "prereqs": [], "kind": "tier", "tier": 2},
	{"id": "tier_3", "title": "Store Tier 3", "pos": Vector2(1.0, 0.0), "max_level": 1, "prereqs": ["tier_2"], "kind": "tier", "tier": 3},
	{"id": "tier_4", "title": "Store Tier 4", "pos": Vector2(2.0, 0.0), "max_level": 1, "prereqs": ["tier_3"], "kind": "tier", "tier": 4},
	{"id": "tier_5", "title": "Store Tier 5", "pos": Vector2(3.0, 0.0), "max_level": 1, "prereqs": ["tier_4"], "kind": "tier", "tier": 5},
	{"id": "tier_6", "title": "Store Tier 6", "pos": Vector2(4.0, 0.0), "max_level": 1, "prereqs": ["tier_5"], "kind": "tier", "tier": 6},
	{"id": "tier_7", "title": "Store Tier 7", "pos": Vector2(5.0, 0.0), "max_level": 1, "prereqs": ["tier_6"], "kind": "tier", "tier": 7},
	{"id": "tier_8", "title": "Store Tier 8", "pos": Vector2(6.0, 0.0), "max_level": 1, "prereqs": ["tier_7"], "kind": "tier", "tier": 8},
	{"id": "tier_9", "title": "Store Tier 9", "pos": Vector2(7.0, 0.0), "max_level": 1, "prereqs": ["tier_8"], "kind": "tier", "tier": 9},
	{"id": "tier_10", "title": "Store Tier 10", "pos": Vector2(8.0, 0.0), "max_level": 1, "prereqs": ["tier_9"], "kind": "tier", "tier": 10},

	# ── BRANCH A: Permit -> Fridge -> Wholesale Pass (x = 1.0) ──
	{"id": "permit", "title": "Business Permit", "pos": Vector2(1.0, 1.0), "max_level": 3, "prereqs": ["tier_2"], "kind": "permit"},
	{"id": "fridge", "title": "Refrigerator", "pos": Vector2(1.0, 2.0), "max_level": 3, "prereqs": ["permit"], "kind": "fridge"},
	{"id": "wholesale_pass", "title": "Wholesale Pass", "pos": Vector2(1.0, 3.0), "max_level": 1, "prereqs": ["fridge"], "kind": "mario_deals"},

	# ── BRANCH B: Bench -> Radio -> Trash Can (x = 3.0) ──
	{"id": "bench", "title": "Tambayan Bench", "pos": Vector2(3.0, 1.0), "max_level": 3, "prereqs": ["tier_3"], "kind": "bench"},
	{"id": "radio", "title": "Barangay Radio", "pos": Vector2(3.0, 2.0), "max_level": 3, "prereqs": ["bench"], "kind": "radio"},
	{"id": "trash_can", "title": "Store Trash Can", "pos": Vector2(3.0, 3.0), "max_level": 1, "prereqs": ["radio"], "kind": "trash"},

	# ── BRANCH C: Barangay Cat -> Sto. Niño -> Maneki-neko (x = 5.0) ──
	{"id": "cat", "title": "Barangay Cat", "pos": Vector2(5.0, 1.0), "max_level": 2, "prereqs": ["tier_4"], "kind": "cat"},
	{"id": "sto_nino", "title": "Sto. Niño Altar", "pos": Vector2(5.0, 2.0), "max_level": 3, "prereqs": ["cat"], "kind": "sto_nino"},
	{"id": "maneki", "title": "Maneki-neko", "pos": Vector2(5.0, 3.0), "max_level": 2, "prereqs": ["sto_nino"], "kind": "maneki"},

	# ── BRANCH D: Roof Signage -> Promo Poster (x = 7.0, early from Tier 2) ──
	{"id": "signage", "title": "Roof Signage", "pos": Vector2(7.0, 1.0), "max_level": 1, "prereqs": ["tier_2"], "kind": "storefront_step", "storefront_level": 1},
	{"id": "poster", "title": "Promo Poster", "pos": Vector2(7.0, 2.5), "max_level": 1, "prereqs": ["signage"], "kind": "storefront_step", "storefront_level": 2},

	# ── CAPSTONE: Open the Door (x = 4.0, y = 4.0) ──
	{"id": "open_door", "title": "Open the Door", "pos": Vector2(4.0, 4.0), "max_level": 1, "prereqs": ["wholesale_pass", "trash_can", "maneki", "poster"], "kind": "storefront_step", "storefront_level": 3},
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
	var base_lvl := 0
	match str(def["kind"]):
		"tier":
			base_lvl = 1 if StoryManager.current_tier >= int(def["tier"]) else 0
		"permit":
			base_lvl = StoryManager.permit_upgrade_level
		"fridge":
			base_lvl = StoryManager.fridge_upgrade_level
		"mario_deals":
			base_lvl = 1 if StoryManager.has_mario_deals else 0
		"bench":
			base_lvl = StoryManager.bench_upgrade_level
		"radio":
			base_lvl = StoryManager.radio_upgrade_level
		"trash":
			base_lvl = 1 if StoryManager.has_trash_can else 0
		"cat":
			base_lvl = StoryManager.cat_upgrade_level
		"sto_nino":
			base_lvl = StoryManager.sto_nino_upgrade_level
		"maneki":
			base_lvl = StoryManager.maneki_upgrade_level
		"storefront_step":
			base_lvl = 1 if StoryManager.storefront_upgrade_level >= int(def["storefront_level"]) else 0
	return mini(int(def["max_level"]), base_lvl + pending)


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


static func get_node_item(node_id: String, target_level: int) -> ItemData:
	var def := get_node_def(node_id)
	if def.is_empty() or not is_instance_valid(StoryManager):
		return null
	match str(def["kind"]):
		"tier":
			return StoryManager.get_tier_upgrade_item(int(def["tier"]))
		"permit":
			return StoryManager.get_permit_upgrade_item(target_level)
		"fridge":
			return StoryManager.get_fridge_upgrade_item(target_level)
		"mario_deals":
			return StoryManager.get_mario_deals_upgrade_item()
		"bench":
			return StoryManager.get_bench_upgrade_item(target_level)
		"radio":
			return StoryManager.get_radio_upgrade_item(target_level)
		"trash":
			return StoryManager.get_trash_can_upgrade_item()
		"cat":
			return StoryManager.get_cat_upgrade_item(target_level)
		"sto_nino":
			return StoryManager.get_sto_nino_upgrade_item(target_level)
		"maneki":
			return StoryManager.get_maneki_upgrade_item(target_level)
		"storefront_step":
			return StoryManager.get_storefront_upgrade_item(int(def["storefront_level"]))
	return null


## Returns Event-Card style stat dictionaries: {"label": String, "value": String, "tone": "pos"|"neg"|"neu"}
static func get_node_stats(node_id: String, target_level: int) -> Array[Dictionary]:
	var def := get_node_def(node_id)
	if def.is_empty():
		return []
	var stats: Array[Dictionary] = []
	var lvl := maxi(1, target_level)

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

	var max_lvl := int(def["max_level"])
	var cur_lvl := get_node_level(node_id, pending_levels)
	if cur_lvl >= max_lvl:
		var owned_item := get_node_item(node_id, max_lvl)
		return {
			"state": "maxed",
			"can_buy": false,
			"reason": "Maxed Out" if max_lvl > 1 else "Owned",
			"cur_level": cur_lvl,
			"max_level": max_lvl,
			"target_level": max_lvl,
			"cost": 0.0,
			"item": owned_item,
		}

	var target_lvl := cur_lvl + 1
	var item := get_node_item(node_id, target_lvl)
	var cost := item.price if item else 0.0
	if not are_prerequisites_met(node_id, pending_levels):
		return {
			"state": "locked",
			"can_buy": false,
			"reason": "Unlock prerequisite first",
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
