class_name StoreEventData
extends Resource

## Data container defining a daily neighborhood event, Papa Ulap's radio rumor,
## category demand/tolerance shifts, and optional strategic gameplay modifiers.

@export var event_id: String = ""
@export var event_name: String = ""
@export_multiline var description: String = ""
@export_multiline var rumor_text: String = ""
@export var icon_path: String = ""

@export_group("Category Demand & Tolerance")
@export var affected_categories: Array[String] = []
@export var affected_items: Array[ItemData] = []
@export var demand_multiplier: float = 1.0
@export var tolerance_offset: int = 0

@export_group("Strategic Gameplay Modifiers")
## Scales half-skip & wave delay (< 1.0 = faster foot traffic, e.g. 0.80 = +20% traffic).
@export var foot_traffic_scale: float = 1.0
## Extra chance (0.0-1.0) for customers to request 2+ items in one basket.
@export var multi_item_chance_bonus: float = 0.0
## Scaling percentage cash tip bonus on sales (e.g. 0.10 = +10% scaled tip).
@export var tip_bonus_pct: float = 0.0
## Multiplier on Player XP earned from sales and visits (e.g. 1.25 = +25% XP).
@export var xp_multiplier: float = 1.0
## Multiplier on Uncle Mario wholesale restock cost (e.g. 0.85 = -15% cost, 1.10 = +10% cost).
@export var restock_cost_multiplier: float = 1.0
## Multiplier on Uncle Mario delivery cooldown (e.g. 0.75 = -25% CD, 1.35 = +35% CD).
@export var delivery_cooldown_multiplier: float = 1.0
## Multiplier on Fridge coldness drain rate (e.g. 1.30 = +30% drain).
@export var fridge_drain_multiplier: float = 1.0
## Temporary extra simultaneous counter customer slot(s).
@export var extra_counter_slots: int = 0
## Bonus chance for customers to linger outside at the tambayan.
@export var linger_chance_bonus: float = 0.0
## Global price tolerance offset applied to ALL items (e.g. -1 during Mosquito Swarm).
@export var global_tolerance_offset: int = 0
## If true, excluded from random morning daily rolls (triggered by special encounters only).
@export var excluded_from_daily_roll: bool = false
## Relative daily roll weight (1.0 = common, 0.65 = uncommon, 0.45 = rare).
@export_range(0.1, 3.0, 0.05) var roll_weight: float = 1.0

func has_target_items() -> bool:
	return not affected_categories.is_empty() or not affected_items.is_empty()

## Returns true if the given item matches this event's target criteria.
func affects_item(item: ItemData) -> bool:
	if not item:
		return false
	if affected_items.has(item):
		return true
	if not affected_categories.is_empty() and affected_categories.has(item.category):
		return true
	return false

func get_icon_path() -> String:
	return icon_path if not icon_path.is_empty() else "res://Assets/ui/icons/zap.png"

## Builds standardized Hades-style stat rows for EventsOverlay, DaySummaryOverlay, and PriceLedgerOverlay.
func build_stat_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if has_target_items():
		var demand_pct := int(roundf((demand_multiplier - 1.0) * 100.0))
		if demand_pct != 0:
			rows.append({
				"label": "Highlighted Demand:",
				"value": ("%+d%%" % demand_pct),
				"tone": "pos" if demand_pct > 0 else "neg",
			})
		if tolerance_offset != 0:
			rows.append({
				"label": "Highlighted Price Tolerance:",
				"value": ("%+d" % tolerance_offset),
				"tone": "pos" if tolerance_offset > 0 else "neg",
			})
	if not is_equal_approx(foot_traffic_scale, 1.0):
		var traffic_pct := int(roundf((1.0 - foot_traffic_scale) * 100.0))
		rows.append({
			"label": "Customer Foot Traffic:",
			"value": ("%+d%%" % traffic_pct),
			"tone": "pos" if traffic_pct > 0 else "neg",
		})
	if extra_counter_slots != 0:
		rows.append({
			"label": "Counter Slots:",
			"value": ("%+d" % extra_counter_slots),
			"tone": "pos" if extra_counter_slots > 0 else "neg",
		})
	if multi_item_chance_bonus > 0.001:
		rows.append({
			"label": "Multi-Item Order Chance:",
			"value": ("+%d%%" % int(roundf(multi_item_chance_bonus * 100.0))),
			"tone": "pos",
		})
	if tip_bonus_pct > 0.001:
		rows.append({
			"label": "Cash Tip Bonus:",
			"value": ("+%d%%" % int(roundf(tip_bonus_pct * 100.0))),
			"tone": "pos",
		})
	if not is_equal_approx(xp_multiplier, 1.0):
		var xp_pct := int(roundf((xp_multiplier - 1.0) * 100.0))
		rows.append({
			"label": "Player XP Gain:",
			"value": ("%+d%%" % xp_pct),
			"tone": "pos" if xp_pct > 0 else "neg",
		})
	if not is_equal_approx(restock_cost_multiplier, 1.0):
		var cost_pct := int(roundf((restock_cost_multiplier - 1.0) * 100.0))
		rows.append({
			"label": "Restock Cost:",
			"value": ("%+d%%" % cost_pct),
			"tone": "pos" if cost_pct < 0 else "neg",
		})
	if not is_equal_approx(delivery_cooldown_multiplier, 1.0):
		var cd_pct := int(roundf((delivery_cooldown_multiplier - 1.0) * 100.0))
		rows.append({
			"label": "Delivery Cooldown:",
			"value": ("%+d%%" % cd_pct),
			"tone": "pos" if cd_pct < 0 else "neg",
		})
	if not is_equal_approx(fridge_drain_multiplier, 1.0):
		var drain_pct := int(roundf((fridge_drain_multiplier - 1.0) * 100.0))
		rows.append({
			"label": "Coldness Drain:",
			"value": ("%+d%%" % drain_pct),
			"tone": "pos" if drain_pct < 0 else "neg",
		})
	if linger_chance_bonus > 0.001:
		rows.append({
			"label": "Tambayan Linger Chance:",
			"value": ("+%d%%" % int(roundf(linger_chance_bonus * 100.0))),
			"tone": "pos",
		})
	if global_tolerance_offset != 0:
		rows.append({
			"label": "All-Item Price Tolerance:",
			"value": ("%+d" % global_tolerance_offset),
			"tone": "pos" if global_tolerance_offset > 0 else "neg",
		})
	return rows

func get_keywords() -> Array[String]:
	var kws: Array[String] = []
	if (has_target_items() and tolerance_offset != 0) or global_tolerance_offset != 0:
		kws.append("price_tolerance")
	if not is_equal_approx(foot_traffic_scale, 1.0):
		kws.append("foot_traffic")
	if extra_counter_slots != 0:
		kws.append("counter_slots")
	if multi_item_chance_bonus > 0.001:
		kws.append("multi_item_order")
	if tip_bonus_pct > 0.001:
		kws.append("cash_tip_bonus")
	if not is_equal_approx(xp_multiplier, 1.0):
		kws.append("player_xp")
	if linger_chance_bonus > 0.001:
		kws.append("tambayan")
	if not is_equal_approx(fridge_drain_multiplier, 1.0):
		kws.append("coldness_drain")
	if not is_equal_approx(restock_cost_multiplier, 1.0):
		kws.append("restock")
	if not is_equal_approx(delivery_cooldown_multiplier, 1.0):
		kws.append("delivery_cooldown")
	return kws
