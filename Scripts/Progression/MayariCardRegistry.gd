class_name MayariCardRegistry
extends RefCounted

## Catalog and roguelike 3-card draft logic for Reyna Mayari's Nightly Tally.
## After choosing a nightly contribution, the player drafts 1 of 3 Moon Cards
## whose effect applies throughout the following day.

const KIND_FAVOR := "favor"
const KIND_CHILL := "chill"

## Card IDs — Favor (Buffs)
const CARD_SILVER_TOLERANCE := "silver_tolerance"
const CARD_FROST_OF_BIRINGAN := "frost_of_biringan"
const CARD_MOONLIGHT_TIPS := "moonlight_tips"
const CARD_CLEAR_ROAD := "clear_road"
const CARD_SILVER_TOUCHED_BAG := "silver_touched_bag"
const CARD_MOON_HOLDS_SKY := "moon_holds_sky"
const CARD_GENEROUS_BASKETS := "generous_baskets"
const CARD_SILVER_RENOWN := "silver_renown"

## Card IDs — Chill (Debuffs / Quirks)
const CARD_DISEMBODIED_WIND := "disembodied_wind"
const CARD_EERIE_MIST_RUSH := "eerie_mist_rush"
const CARD_RELUCTANT_CARE := "reluctant_care_package"
const CARD_EARLY_DUSK := "early_dusk"
const CARD_QUIET_ECLIPSE := "quiet_eclipse"
const CARD_FADING_MEMORY := "fading_memory"

## Core mechanical vocabulary for Hades-style hover side callouts.
const KEYWORDS: Dictionary = {
	"price_tolerance": {
		"title": "PRICE TOLERANCE",
		"desc": "How many price steps above base cost neighbors accept before refusing to buy.",
	},
	"fridge_coldness": {
		"title": "FRIDGE COLDNESS",
		"desc": "Keeps cold drinks & frozen stock fresh. If depleted, fridge items sell for 25% less.",
	},
	"cash_sale": {
		"title": "CASH SALE",
		"desc": "A purchase paid upfront in pesos — excludes Utang (credit) sales.",
	},
	"restock": {
		"title": "RESTOCK",
		"desc": "Wholesale stock ordered by calling Uncle Mario on the store phone.",
	},
	"bonus_stock": {
		"title": "BONUS STOCK",
		"desc": "Extra free items tucked into Uncle Mario's delivery bag, up to shelf capacity.",
	},
	"store_hours": {
		"title": "STORE HOURS",
		"desc": "Normally closes at 8:00 PM, after which Reyna Mayari arrives to collect.",
	},
	"multi_item_order": {
		"title": "MULTI-ITEM ORDER",
		"desc": "A neighbor requesting 2–3 items at once — grants +5 bonus Player XP per extra item.",
	},
	"player_xp": {
		"title": "PLAYER XP",
		"desc": "Earned from sales, visits, and stories to level up and unlock higher product tiers & upgrades.",
	},
	"neighborhood_events": {
		"title": "NEIGHBORHOOD EVENTS",
		"desc": "Daily Karimlan conditions that boost demand and Price Tolerance for specific categories.",
	},
}

static func get_keyword(key: String) -> Dictionary:
	return KEYWORDS.get(key, {})

const CARDS: Dictionary = {
	# ── Favor (Buffs) ────────────────────────────────────────────────────
	CARD_SILVER_TOLERANCE: {
		"id": CARD_SILVER_TOLERANCE,
		"kind": KIND_FAVOR,
		"title": "Silver Tolerance",
		"sigil": "☽",
		"tagline": "+1 Price Tolerance",
		"description": "Moonlit goodwill softens every haggle. Customers tolerate +1 higher price step on all items tomorrow.",
		"description_rich": "Moonlit goodwill softens every haggle. Neighbors accept higher [b]Price Tolerance[/b] on all items tomorrow.",
		"keywords": ["price_tolerance"],
		"stats": [
			{"label": "All Items Price Tolerance:", "value": "+1", "tone": "pos"},
		],
		"hud_short": "+1 Price Tolerance",
	},
	CARD_FROST_OF_BIRINGAN: {
		"id": CARD_FROST_OF_BIRINGAN,
		"kind": KIND_FAVOR,
		"title": "Frost of Biringan",
		"sigil": "❄",
		"tagline": "40% Slower Fridge Drain",
		"description": "Cool lunar air lingers in your store. Your refrigerator loses coldness 40% slower and chills back 40% faster.",
		"description_rich": "Cool lunar air lingers in your fridge, preserving [b]Fridge Coldness[/b] far longer.",
		"keywords": ["fridge_coldness"],
		"stats": [
			{"label": "Fridge Coldness Drain:", "value": "-40%", "tone": "pos"},
			{"label": "Fridge Re-Chill Speed:", "value": "+40%", "tone": "pos"},
		],
		"hud_short": "Fridge Frost Blessing",
	},
	CARD_MOONLIGHT_TIPS: {
		"id": CARD_MOONLIGHT_TIPS,
		"kind": KIND_FAVOR,
		"title": "Moonlight Tips",
		"sigil": "✦",
		"tagline": "+₱3 Tip Per Cash Sale",
		"description": "Gratitude shines bright under the silver spires. Earn a +₱3 Moonlight Tip on every satisfied cash sale tomorrow.",
		"description_rich": "Gratitude shines under the silver spires. Earn a bonus tip on every satisfied [b]Cash Sale[/b].",
		"keywords": ["cash_sale"],
		"stats": [
			{"label": "Tip Per Cash Sale:", "value": "+₱3", "tone": "pos"},
		],
		"hud_short": "+₱3 Moonlight Tips",
	},
	CARD_CLEAR_ROAD: {
		"id": CARD_CLEAR_ROAD,
		"kind": KIND_FAVOR,
		"title": "Clear Road",
		"sigil": "»",
		"tagline": "Faster Mario & 10% Off",
		"description": "The moonlight clears the road for Uncle Mario: 10% off restock orders and deliveries arrive 1 customer sooner.",
		"description_rich": "Moonlight clears the road for Uncle Mario, lowering [b]Restock[/b] costs and speeding up deliveries.",
		"keywords": ["restock"],
		"stats": [
			{"label": "Restock Cost:", "value": "-10%", "tone": "pos"},
			{"label": "Delivery Waiting Time:", "value": "-1 Customer", "tone": "pos"},
		],
		"hud_short": "10% Off Restock & Fast Mario",
	},
	CARD_SILVER_TOUCHED_BAG: {
		"id": CARD_SILVER_TOUCHED_BAG,
		"kind": KIND_FAVOR,
		"title": "Silver-Touched Bag",
		"sigil": "✧",
		"tagline": "+1–2 Free Restock Units",
		"description": "Biringan's abundance slips into your delivery bags. Every restock delivery tomorrow includes 1–2 free bonus items.",
		"description_rich": "Biringan's abundance slips into your delivery bags, adding free [b]Bonus Stock[/b] to every drop.",
		"keywords": ["bonus_stock"],
		"stats": [
			{"label": "Free Items Per Delivery:", "value": "+1–2", "tone": "pos"},
		],
		"hud_short": "Bonus Restock Items",
	},
	CARD_MOON_HOLDS_SKY: {
		"id": CARD_MOON_HOLDS_SKY,
		"kind": KIND_FAVOR,
		"title": "Moon Holds the Sky",
		"sigil": "☾",
		"tagline": "Open Until 10:00 PM",
		"description": "Mayari holds nightfall at bay. Your sari-sari store stays open until 10:00 PM tomorrow for extra customer waves.",
		"description_rich": "Mayari holds nightfall at bay, extending your [b]Store Hours[/b] for extra customer waves.",
		"keywords": ["store_hours"],
		"stats": [
			{"label": "Closing Time:", "value": "10:00 PM", "tone": "pos"},
		],
		"hud_short": "Open Until 10:00 PM",
	},
	CARD_GENEROUS_BASKETS: {
		"id": CARD_GENEROUS_BASKETS,
		"kind": KIND_FAVOR,
		"title": "Generous Baskets",
		"sigil": "◈",
		"tagline": "2–3 Item Orders",
		"description": "Neighbors arrive with bigger cravings. Customers are much more likely to ask for 2–3 items per visit tomorrow.",
		"description_rich": "Neighbors arrive with bigger cravings, placing larger [b]Multi-Item Orders[/b] throughout the day.",
		"keywords": ["multi_item_order"],
		"stats": [
			{"label": "Items Per Customer Order:", "value": "2–3", "tone": "pos"},
		],
		"hud_short": "Bigger Customer Orders",
	},
	CARD_SILVER_RENOWN: {
		"id": CARD_SILVER_RENOWN,
		"kind": KIND_FAVOR,
		"title": "Silver Renown",
		"sigil": "★",
		"tagline": "+50% Player XP",
		"description": "Biringan's whispers carry your tindahan's name across Karimlan. Earn +50% Player XP from every sale, visit, and story tomorrow.",
		"description_rich": "Biringan's whispers carry your tindahan's name across Karimlan. Earn extra [b]Player XP[/b] from every sale, visit, and story.",
		"keywords": ["player_xp"],
		"stats": [
			{"label": "Player XP Earned:", "value": "+50%", "tone": "pos"},
		],
		"hud_short": "+50% Player XP",
	},

	# ── Omen (Debuffs / Quirks) ──────────────────────────────────────────
	CARD_DISEMBODIED_WIND: {
		"id": CARD_DISEMBODIED_WIND,
		"kind": KIND_CHILL,
		"title": "Disembodied Wind",
		"sigil": "〰",
		"tagline": "Haunted Fridge Gusts",
		"description": "A tasteful haunting. Eerie gusts swing your refrigerator door open 1–2 times tomorrow — shut it before stock warms!",
		"description_rich": "A tasteful haunting. Eerie gusts swing your fridge door open — shut it before [b]Fridge Coldness[/b] drains!",
		"keywords": ["fridge_coldness"],
		"stats": [
			{"label": "Refrigerator Door Gusts:", "value": "1–2", "tone": "neg"},
		],
		"hud_short": "Haunted Fridge Gusts",
	},
	CARD_EERIE_MIST_RUSH: {
		"id": CARD_EERIE_MIST_RUSH,
		"kind": KIND_CHILL,
		"title": "Eerie Mist Rush",
		"sigil": "☁",
		"tagline": "-1 Tolerance · 20% Faster Flow",
		"description": "Uneasy neighbors won't accept steep markups (-1 tolerance), but the mist draws customers 20% faster for quick sales.",
		"description_rich": "Uneasy neighbors have lower [b]Price Tolerance[/b], yet the silver mist draws customers in faster.",
		"keywords": ["price_tolerance"],
		"stats": [
			{"label": "All Items Price Tolerance:", "value": "-1", "tone": "neg"},
			{"label": "Customer Foot Traffic:", "value": "+20%", "tone": "pos"},
		],
		"hud_short": "-1 Tol · +20% Foot Traffic",
	},
	CARD_RELUCTANT_CARE: {
		"id": CARD_RELUCTANT_CARE,
		"kind": KIND_CHILL,
		"title": "Reluctant Care Package",
		"sigil": "❖",
		"tagline": "-1 Tolerance · 15% Off Restock",
		"description": "Customers are pickier on markups (-1 tolerance), yet Mario knocks 15% off wholesale stock. \"Bare shelves embarrass my ledger.\"",
		"description_rich": "Neighbors have lower [b]Price Tolerance[/b], yet Uncle Mario knocks down wholesale [b]Restock[/b] prices.",
		"keywords": ["price_tolerance", "restock"],
		"stats": [
			{"label": "All Items Price Tolerance:", "value": "-1", "tone": "neg"},
			{"label": "Restock Cost:", "value": "-15%", "tone": "pos"},
		],
		"hud_short": "-1 Tol · 15% Off Restock",
	},
	CARD_EARLY_DUSK: {
		"id": CARD_EARLY_DUSK,
		"kind": KIND_CHILL,
		"title": "Early Dusk",
		"sigil": "◐",
		"tagline": "Closes Early at 6:30 PM",
		"description": "The Pale Queen summons twilight ahead of schedule. Your store closes at 6:30 PM tomorrow instead of 8:00 PM.",
		"description_rich": "The Pale Queen summons twilight ahead of schedule, cutting your [b]Store Hours[/b] short.",
		"keywords": ["store_hours"],
		"stats": [
			{"label": "Closing Time:", "value": "6:30 PM", "tone": "neg"},
		],
		"hud_short": "Early Close (6:30 PM)",
	},
	CARD_QUIET_ECLIPSE: {
		"id": CARD_QUIET_ECLIPSE,
		"kind": KIND_CHILL,
		"title": "Quiet Eclipse",
		"sigil": "●",
		"tagline": "No Neighborhood Events Today",
		"description": "An uncanny hush blankets Karimlan. No daily Neighborhood Events or demand surges will occur tomorrow.",
		"description_rich": "An uncanny hush blankets Karimlan. All daily [b]Neighborhood Events[/b] are silenced.",
		"keywords": ["neighborhood_events"],
		"stats": [
			{"label": "Neighborhood Events:", "value": "None", "tone": "neg"},
		],
		"hud_short": "No Events Today",
	},
	CARD_FADING_MEMORY: {
		"id": CARD_FADING_MEMORY,
		"kind": KIND_CHILL,
		"title": "Fading Memory",
		"sigil": "◌",
		"tagline": "-35% Player XP",
		"description": "Karimlan's mist dulls word of mouth. Earn 35% less Player XP from sales, visits, and stories tomorrow.",
		"description_rich": "Karimlan's mist dulls word of mouth. Earn less [b]Player XP[/b] from every sale, visit, and story tomorrow.",
		"keywords": ["player_xp"],
		"stats": [
			{"label": "Player XP Earned:", "value": "-35%", "tone": "neg"},
		],
		"hud_short": "-35% Player XP",
	},
}

static func get_card(card_id: String) -> Dictionary:
	return CARDS.get(card_id, {})

static func is_favor(card_id: String) -> bool:
	var c := get_card(card_id)
	return str(c.get("kind", "")) == KIND_FAVOR

static func is_chill(card_id: String) -> bool:
	var c := get_card(card_id)
	return str(c.get("kind", "")) == KIND_CHILL

static func get_cards_by_kind(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in CARDS.keys():
		var c: Dictionary = CARDS[key]
		if str(c.get("kind", "")) == kind:
			result.append(c)
	return result

## Draws 3 unique cards for the post-tally roguelike draft:
## - "generous": 3 guaranteed Favor cards
## - "shortfall": 3 guaranteed Omen cards
## - "balanced": 3 unique cards, each slot rolling 55% Omen / 45% Favor
static func draw_three_cards(tally_tier: String) -> Array[Dictionary]:
	var favor_pool := get_cards_by_kind(KIND_FAVOR)
	var chill_pool := get_cards_by_kind(KIND_CHILL)
	favor_pool.shuffle()
	chill_pool.shuffle()

	var picked: Array[Dictionary] = []
	match tally_tier:
		"generous", "cleared":
			for i in range(mini(3, favor_pool.size())):
				picked.append(favor_pool[i])
		"shortfall":
			for i in range(mini(3, chill_pool.size())):
				picked.append(chill_pool[i])
		_:
			# Fair: 55% Omen / 45% Favor per slot
			var f_idx := 0
			var c_idx := 0
			for _slot in range(3):
				var want_chill := randf() < 0.55
				if want_chill and c_idx < chill_pool.size():
					picked.append(chill_pool[c_idx])
					c_idx += 1
				elif f_idx < favor_pool.size():
					picked.append(favor_pool[f_idx])
					f_idx += 1
				elif c_idx < chill_pool.size():
					picked.append(chill_pool[c_idx])
					c_idx += 1
			picked.shuffle()
	return picked
