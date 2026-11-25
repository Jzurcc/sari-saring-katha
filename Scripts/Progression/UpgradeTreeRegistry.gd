class_name UpgradeTreeRegistry
extends RefCounted

## Modular, data-driven Skill Tree definition for Store Upgrades & Evolution.
## Adding a new upgrade or branch requires adding one node dictionary to NODES
## and wiring its ItemData getter / level reader in the helpers below.
##
## Coordinates (`pos`) are in logical tree units (bottom-up: y=0 at bottom -> y=9.4 at top).
## Branch progression rule: unlocking Level 1 of a prerequisite node unlocks its children;
## multi-level nodes (Lv. 2 / Lv. 3) can be upgraded anytime on the same node.

const BRANCH_COLORS := {
	"core": Color(0.95, 0.76, 0.34, 1.0),       # Warm Amber / Gold
	"supply": Color(0.24, 0.85, 0.96, 1.0),     # Cyber Cyan
	"curbside": Color(0.32, 0.88, 0.58, 1.0),   # Neon Emerald
	"spirit": Color(0.76, 0.56, 0.98, 1.0),     # Astral Violet
	"storefront": Color(0.98, 0.56, 0.28, 1.0), # Storefront Orange
	"capstone": Color(1.0, 0.90, 0.54, 1.0),    # Radiant Capstone Gold
}

const BRANCH_LABELS := {
	"core": "STORE EXPANSION",
	"supply": "BRANCH A · HUSTLE & SUPPLY",
	"curbside": "BRANCH B · CURBSIDE & WORD",
	"spirit": "BRANCH C · SPIRIT & FORTUNE",
	"storefront": "BRANCH D · STOREFRONT",
	"capstone": "CAPSTONE · FREEDOM",
}

const NODES: Array[Dictionary] = [
	# ── CENTRAL SPINE: Store Tiers 2 → 10 (Bottom-up) ──
	{"id": "tier_2", "title": "Store Tier 2", "branch": "core", "pos": Vector2(0.0, 0.0), "max_level": 1, "prereqs": [], "kind": "tier", "tier": 2, "mario_delivery": true},
	{"id": "tier_3", "title": "Store Tier 3", "branch": "core", "pos": Vector2(0.0, 1.0), "max_level": 1, "prereqs": ["tier_2"], "kind": "tier", "tier": 3, "mario_delivery": true},
	{"id": "tier_4", "title": "Store Tier 4", "branch": "core", "pos": Vector2(0.0, 2.0), "max_level": 1, "prereqs": ["tier_3"], "kind": "tier", "tier": 4, "mario_delivery": true},
	{"id": "tier_5", "title": "Store Tier 5", "branch": "core", "pos": Vector2(0.0, 3.0), "max_level": 1, "prereqs": ["tier_4"], "kind": "tier", "tier": 5, "mario_delivery": true},
	{"id": "tier_6", "title": "Store Tier 6", "branch": "core", "pos": Vector2(0.0, 4.0), "max_level": 1, "prereqs": ["tier_5"], "kind": "tier", "tier": 6, "mario_delivery": true},
	{"id": "tier_7", "title": "Store Tier 7", "branch": "core", "pos": Vector2(0.0, 5.0), "max_level": 1, "prereqs": ["tier_6"], "kind": "tier", "tier": 7, "mario_delivery": true},
	{"id": "tier_8", "title": "Store Tier 8", "branch": "core", "pos": Vector2(0.0, 6.0), "max_level": 1, "prereqs": ["tier_7"], "kind": "tier", "tier": 8, "mario_delivery": true},
	{"id": "tier_9", "title": "Store Tier 9", "branch": "core", "pos": Vector2(0.0, 7.0), "max_level": 1, "prereqs": ["tier_8"], "kind": "tier", "tier": 9, "mario_delivery": true},
	{"id": "tier_10", "title": "Store Tier 10", "branch": "core", "pos": Vector2(0.0, 8.0), "max_level": 1, "prereqs": ["tier_9"], "kind": "tier", "tier": 10, "mario_delivery": true},

	# ── BRANCH A: Permit -> Fridge -> Wholesale Pass (Left Inner) ──
	{"id": "permit", "title": "Business Permit", "branch": "supply", "pos": Vector2(-1.45, 1.5), "max_level": 3, "prereqs": ["tier_2"], "kind": "permit", "mario_delivery": true},
	{"id": "fridge", "title": "Refrigerator", "branch": "supply", "pos": Vector2(-1.45, 4.0), "max_level": 3, "prereqs": ["permit"], "kind": "fridge", "mario_delivery": true},
	{"id": "wholesale_pass", "title": "Wholesale Pass", "branch": "supply", "pos": Vector2(-1.45, 6.6), "max_level": 1, "prereqs": ["fridge"], "kind": "mario_deals", "mario_delivery": true},

	# ── BRANCH B: Bench -> Radio -> Trash Can (Left Outer) ──
	{"id": "bench", "title": "Tambayan Bench", "branch": "curbside", "pos": Vector2(-2.85, 2.3), "max_level": 3, "prereqs": ["tier_3"], "kind": "bench", "mario_delivery": true},
	{"id": "radio", "title": "Barangay Radio", "branch": "curbside", "pos": Vector2(-2.85, 4.8), "max_level": 3, "prereqs": ["bench"], "kind": "radio", "mario_delivery": true},
	{"id": "trash_can", "title": "Store Trash Can", "branch": "curbside", "pos": Vector2(-2.85, 7.2), "max_level": 1, "prereqs": ["radio"], "kind": "trash", "mario_delivery": true},

	# ── BRANCH C: Barangay Cat -> Sto. Niño -> Maneki-neko (Right Inner) ──
	{"id": "cat", "title": "Barangay Cat", "branch": "spirit", "pos": Vector2(1.45, 2.7), "max_level": 2, "prereqs": ["tier_4"], "kind": "cat", "mario_delivery": true},
	{"id": "sto_nino", "title": "Sto. Niño Altar", "branch": "spirit", "pos": Vector2(1.45, 5.1), "max_level": 3, "prereqs": ["cat"], "kind": "sto_nino", "mario_delivery": true},
	{"id": "maneki", "title": "Maneki-neko", "branch": "spirit", "pos": Vector2(1.45, 7.4), "max_level": 2, "prereqs": ["sto_nino"], "kind": "maneki", "mario_delivery": true},

	# ── BRANCH D: Roof Signage -> Promo Poster (Right Outer, starts early at Tier 2!) ──
	{"id": "signage", "title": "Roof Signage", "branch": "storefront", "pos": Vector2(2.85, 1.7), "max_level": 1, "prereqs": ["tier_2"], "kind": "storefront_step", "storefront_level": 1, "mario_delivery": true},
	{"id": "poster", "title": "Promo Poster", "branch": "storefront", "pos": Vector2(2.85, 5.5), "max_level": 1, "prereqs": ["signage", "tier_5"], "kind": "storefront_step", "storefront_level": 2, "mario_delivery": true},

	# ── CAPSTONE: Open the Door (Top Apex) ──
	{"id": "open_door", "title": "Open the Door", "branch": "capstone", "pos": Vector2(0.0, 9.4), "max_level": 1, "prereqs": ["tier_10", "wholesale_pass", "trash_can", "maneki", "poster"], "kind": "storefront_step", "storefront_level": 3, "mario_delivery": true},
]


static func get_all_nodes() -> Array[Dictionary]:
	return NODES


static func get_node_def(node_id: String) -> Dictionary:
	for n in NODES:
		if str(n["id"]) == node_id:
			return n
	return {}


static func get_branch_color(branch: String) -> Color:
	return BRANCH_COLORS.get(branch, Color(0.85, 0.78, 0.62, 1.0))


static func get_branch_label(branch: String) -> String:
	return str(BRANCH_LABELS.get(branch, branch.to_upper()))


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
	var prereqs_ok := are_prerequisites_met(node_id, pending_levels)
	if not prereqs_ok:
		return {
			"state": "locked",
			"can_buy": false,
			"reason": "Unlock prerequisite nodes first",
			"cur_level": cur_lvl,
			"max_level": max_lvl,
			"target_level": target_lvl,
			"cost": cost,
			"item": item,
		}

	# Tier nodes still respect StoryManager.max_unlocked_tier (earned via Player Level)
	if str(def["kind"]) == "tier":
		var t := int(def["tier"])
		if t > StoryManager.max_unlocked_tier:
			var req_lvl := int(item.get_meta("req_level", t)) if item else t
			return {
				"state": "locked",
				"can_buy": false,
				"reason": "Requires Player Lv. %d" % req_lvl,
				"cur_level": cur_lvl,
				"max_level": max_lvl,
				"target_level": target_lvl,
				"cost": cost,
				"item": item,
			}
	elif target_lvl >= 2 and item != null:
		# Higher levels (Lv. 2 / Lv. 3) of multi-level nodes respect player_level gate
		var req_pl := int(item.get_meta("req_level", 1))
		if StoryManager.player_level < req_pl:
			return {
				"state": "locked_level",
				"can_buy": false,
				"reason": "Lv. %d requires Player Lv. %d" % [target_lvl, req_pl],
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
			"reason": "Need ₱%.0f (have ₱%.0f)" % [cost, available_money],
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
