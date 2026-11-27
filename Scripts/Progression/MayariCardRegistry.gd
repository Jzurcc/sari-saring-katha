class_name MayariCardRegistry
extends RefCounted

## Catalog and roguelike 3-card draft logic for Reyna Mayari's Nightly Tally.
## After choosing a nightly contribution, the player drafts 1–2 of 3 Moon Cards
## whose effect applies throughout the following day.
## Favors grant pure scalable advantages; Omens are mostly double-edged swords
## with a real downside paired with a strategic comeback angle.

const KIND_FAVOR := "favor"
const KIND_CHILL := "chill"

## Card IDs — Favor (14 Buffs)
const CARD_SILVER_TOLERANCE := "silver_tolerance"
const CARD_FROST_OF_BIRINGAN := "frost_of_biringan"
const CARD_MOONLIGHT_TIPS := "moonlight_tips"
const CARD_CLEAR_ROAD := "clear_road"
const CARD_SILVER_TOUCHED_BAG := "silver_touched_bag"
const CARD_MOON_HOLDS_SKY := "moon_holds_sky"
const CARD_GENEROUS_BASKETS := "generous_baskets"
const CARD_SILVER_RENOWN := "silver_renown"
const CARD_CROWDED_STOOP := "crowded_stoop"
const CARD_TAMBAYAN_WARMTH := "tambayan_warmth"
const CARD_ECHOES_ON_THE_DIAL := "echoes_on_the_dial"
const CARD_WHOLESALE_BLESSING := "wholesale_blessing"
const CARD_CURBSIDE_GLOW := "curbside_glow"
const CARD_UNRUSHED_HOUR := "unrushed_hour"

## Card IDs — Omen (12 Double-Edged Debuffs / Quirks)
const CARD_DISEMBODIED_WIND := "disembodied_wind"
const CARD_EERIE_MIST_RUSH := "eerie_mist_rush"
const CARD_RELUCTANT_CARE := "reluctant_care_package"
const CARD_EARLY_DUSK := "early_dusk"
const CARD_QUIET_ECLIPSE := "quiet_eclipse"
const CARD_FADING_MEMORY := "fading_memory"
const CARD_FOGGY_HIGHWAY := "foggy_highway"
const CARD_WARM_TRADE_WINDS := "warm_trade_winds"
const CARD_RESTLESS_CROWD := "restless_crowd"
const CARD_STATIC_AIRWAVES := "static_airwaves"
const CARD_TIGHT_WHOLESALE := "tight_wholesale"
const CARD_PICKY_CRAVINGS := "picky_cravings"

## Core mechanical vocabulary for Hades-style hover side callouts.
const KEYWORDS: Dictionary = {
	# ── Pricing, Sales & Tips ──
	"price_tolerance": {
		"title": "PRICE TOLERANCE",
		"desc": "How many price steps above base cost neighbors accept before pushing back.",
	},
	"haggle": {
		"title": "HAGGLE",
		"desc": "Counter-offer chance to talk a hesitant shopper into accepting a marked-up price.",
	},
	"cash_sale": {
		"title": "CASH SALE",
		"desc": "A purchase paid upfront in pesos, excluding Utang (credit) sales.",
	},
	"cash_tip_bonus": {
		"title": "CASH TIP BONUS",
		"desc": "Extra percentage of pesos added on top of satisfied Cash Sales.",
	},
	"tip_chance": {
		"title": "TIP CHANCE",
		"desc": "Probability that a satisfied shopper leaves an Appreciation Tip after a Cash Sale.",
	},
	"featured_category": {
		"title": "FEATURED CATEGORY",
		"desc": "Activated by placing 3/3 stickers of one category on your Promo Poster for extra demand and bonus cash.",
	},
	"cold_sale_bonus": {
		"title": "COLD SALE BONUS",
		"desc": "Extra percentage of pesos earned on chilled Cold Drinks & Frozen sales while the fridge stays cold.",
	},
	# ── Fridge & Inventory ──
	"fridge_coldness": {
		"title": "FRIDGE COLDNESS",
		"desc": "Keeps Cold Drinks & Frozen stock fresh. If depleted, fridge items sell for 25% less.",
	},
	"coldness_drain": {
		"title": "COLDNESS DRAIN",
		"desc": "How fast your fridge loses Coldness over time or when the door swings open.",
	},
	"rechill_speed": {
		"title": "RE-CHILL SPEED",
		"desc": "How fast your fridge recovers Coldness back to ice-cold once the door is shut.",
	},
	"restock": {
		"title": "RESTOCK",
		"desc": "Wholesale stock ordered by calling Uncle Mario on the store phone.",
	},
	"delivery_cooldown": {
		"title": "DELIVERY COOLDOWN",
		"desc": "Wait time before Uncle Mario can run another Restock trip.",
	},
	"bonus_stock": {
		"title": "BONUS STOCK",
		"desc": "Extra free items tucked into Uncle Mario's delivery bag, up to Shelf Capacity.",
	},
	"sulit_deals": {
		"title": "SULIT DEALS",
		"desc": "Daily discounted wholesale picks from Uncle Mario in the Restock Menu.",
	},
	# ── Customers, Traffic & Counter Flow ──
	"foot_traffic": {
		"title": "FOOT TRAFFIC",
		"desc": "Speeds up customer arrivals and shortens time skips between waves so more neighbors visit.",
	},
	"counter_slots": {
		"title": "COUNTER SLOTS",
		"desc": "How many neighbors can stand at your counter at once (up to 3).",
	},
	"multi_item_order": {
		"title": "MULTI-ITEM ORDER",
		"desc": "A neighbor requesting 2+ items at once, granting +5 bonus Player XP per extra item.",
	},
	"tambayan": {
		"title": "TAMBAYAN",
		"desc": "Lingering neighbors who hang out around the store, granting passive XP and occasional extra purchases.",
	},
	"daily_visitors": {
		"title": "DAILY VISITORS",
		"desc": "Specific named neighbors spotted by Papa Ulap who are scheduled to visit today.",
	},
	"store_hours": {
		"title": "STORE HOURS",
		"desc": "Normally closes at 8:00 PM, after which Reyna Mayari arrives to collect.",
	},
	# ── Progression, Credit & Broadcasts ──
	"player_xp": {
		"title": "PLAYER XP",
		"desc": "Earned from sales, visits, and stories to level up and unlock higher product tiers and upgrades.",
	},
	"reputation": {
		"title": "REPUTATION",
		"desc": "Bond earned with each neighbor to unlock Folklore Journal chapters and deeper trust.",
	},
	"utang": {
		"title": "UTANG",
		"desc": "Neighborhood credit recorded on your lista, repaid in full on a future visit.",
	},
	"events": {
		"title": "EVENTS",
		"desc": "Daily Karimlan conditions revealed via Papa Ulap's Radio that shift demand, prices, and store flow.",
	},
	"neighborhood_events": {
		"title": "EVENTS",
		"desc": "Daily Karimlan conditions revealed via Papa Ulap's Radio that shift demand, prices, and store flow.",
	},
	"radio_cooldown": {
		"title": "RADIO COOLDOWN",
		"desc": "Wait time between Papa Ulap's Event and Daily Visitor broadcasts on the Counter Radio.",
	},
	"minigame_rewards": {
		"title": "MINIGAME REWARDS",
		"desc": "Multiplier on pesos and Player XP earned from Sipa, Teks, Talisman, and Mosquito Swat minigames.",
	},
	"story_chance": {
		"title": "STORY CHANCE",
		"desc": "Extra chance for unlocked neighbors to trigger their next Story Chapter instead of a routine purchase.",
	},
}

static func get_keyword(key: String) -> Dictionary:
	return KEYWORDS.get(key, {})

const CARDS: Dictionary = {
	# ── Favor (14 Buffs) ─────────────────────────────────────────────────
	CARD_SILVER_TOLERANCE: {
		"id": CARD_SILVER_TOLERANCE,
		"kind": KIND_FAVOR,
		"title": "Silver Tolerance",
		"sigil": "☽",
		"icon": "res://Assets/ui/icons/scale.png",
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
		"icon": "res://Assets/ui/icons/snowflake.png",
		"tagline": "-40% Drain · +40% Re-Chill",
		"description": "Cool lunar air lingers in your store. Your refrigerator loses coldness 40% slower and chills back 40% faster.",
		"description_rich": "Cool lunar air lingers in your fridge, slowing [b]Coldness Drain[/b] and speeding up [b]Re-Chill Speed[/b].",
		"keywords": ["coldness_drain", "rechill_speed"],
		"stats": [
			{"label": "Coldness Drain:", "value": "-40%", "tone": "pos"},
			{"label": "Re-Chill Speed:", "value": "+40%", "tone": "pos"},
		],
		"hud_short": "Fridge Frost Blessing",
	},
	CARD_MOONLIGHT_TIPS: {
		"id": CARD_MOONLIGHT_TIPS,
		"kind": KIND_FAVOR,
		"title": "Moonlight Tips",
		"sigil": "✦",
		"icon": "res://Assets/ui/icons/sparkles.png",
		"tagline": "+12% Cash Tip Bonus",
		"description": "Gratitude shines bright under the silver spires. Earn a +12% Cash Tip Bonus on every satisfied cash sale tomorrow.",
		"description_rich": "Gratitude shines under the silver spires. Earn a scaling [b]Cash Tip Bonus[/b] on every satisfied [b]Cash Sale[/b].",
		"keywords": ["cash_tip_bonus", "cash_sale"],
		"stats": [
			{"label": "Cash Tip Bonus:", "value": "+12%", "tone": "pos"},
		],
		"hud_short": "+12% Moonlight Tips",
	},
	CARD_CLEAR_ROAD: {
		"id": CARD_CLEAR_ROAD,
		"kind": KIND_FAVOR,
		"title": "Clear Road",
		"sigil": "»",
		"icon": "res://Assets/ui/icons/route.png",
		"tagline": "-35% Delivery CD · -10% Restock",
		"description": "The moonlight clears the road for Uncle Mario: 10% off restock orders and 35% shorter delivery cooldown.",
		"description_rich": "Moonlight clears the road for Uncle Mario, lowering [b]Restock[/b] costs and cutting [b]Delivery Cooldown[/b].",
		"keywords": ["restock", "delivery_cooldown"],
		"stats": [
			{"label": "Restock Cost:", "value": "-10%", "tone": "pos"},
			{"label": "Delivery Cooldown:", "value": "-35%", "tone": "pos"},
		],
		"hud_short": "-10% Restock · -35% Delivery CD",
	},
	CARD_SILVER_TOUCHED_BAG: {
		"id": CARD_SILVER_TOUCHED_BAG,
		"kind": KIND_FAVOR,
		"title": "Silver-Touched Bag",
		"sigil": "✧",
		"icon": "res://Assets/ui/icons/package.png",
		"tagline": "+2 Free Restock Units",
		"description": "Biringan's abundance slips into your delivery bags. Every restock delivery tomorrow includes +2 free bonus items.",
		"description_rich": "Biringan's abundance slips into your delivery bags, adding free [b]Bonus Stock[/b] to every drop.",
		"keywords": ["bonus_stock"],
		"stats": [
			{"label": "Free Items Per Delivery:", "value": "+2", "tone": "pos"},
		],
		"hud_short": "+2 Bonus Restock Units",
	},
	CARD_MOON_HOLDS_SKY: {
		"id": CARD_MOON_HOLDS_SKY,
		"kind": KIND_FAVOR,
		"title": "Moon Holds the Sky",
		"sigil": "☾",
		"icon": "res://Assets/ui/icons/moon.png",
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
		"icon": "res://Assets/ui/icons/shopping-basket.png",
		"tagline": "2+ Item Orders",
		"description": "Neighbors arrive with bigger cravings. Customers are much more likely to ask for 2+ items per visit tomorrow.",
		"description_rich": "Neighbors arrive with bigger cravings, placing larger [b]Multi-Item Orders[/b] throughout the day.",
		"keywords": ["multi_item_order"],
		"stats": [
			{"label": "Items Per Customer Order:", "value": "2+", "tone": "pos"},
		],
		"hud_short": "Bigger 2+ Item Orders",
	},
	CARD_SILVER_RENOWN: {
		"id": CARD_SILVER_RENOWN,
		"kind": KIND_FAVOR,
		"title": "Silver Renown",
		"sigil": "★",
		"icon": "res://Assets/ui/icons/award.png",
		"tagline": "+50% Player XP",
		"description": "Biringan's whispers carry your tindahan's name across Karimlan. Earn +50% Player XP from every sale, visit, and story tomorrow.",
		"description_rich": "Biringan's whispers carry your tindahan's name across Karimlan. Earn extra [b]Player XP[/b] from every sale, visit, and story.",
		"keywords": ["player_xp"],
		"stats": [
			{"label": "Player XP Earned:", "value": "+50%", "tone": "pos"},
		],
		"hud_short": "+50% Player XP",
	},
	CARD_CROWDED_STOOP: {
		"id": CARD_CROWDED_STOOP,
		"kind": KIND_FAVOR,
		"title": "Crowded Stoop",
		"sigil": "❖",
		"icon": "res://Assets/ui/icons/users.png",
		"tagline": "+1 Counter Slot · +15% Flow",
		"description": "Word spreads down the alley! Temporarily opens +1 extra Counter Slot (up to 3) and increases Customer Foot Traffic by 15%.",
		"description_rich": "Word spreads down the alley, opening an extra Counter Slot and boosting [b]Foot Traffic[/b] all day.",
		"keywords": ["foot_traffic"],
		"stats": [
			{"label": "Counter Slots Today:", "value": "+1 (Max 3)", "tone": "pos"},
			{"label": "Customer Foot Traffic:", "value": "+15%", "tone": "pos"},
		],
		"hud_short": "+1 Slot · +15% Traffic",
	},
	CARD_TAMBAYAN_WARMTH: {
		"id": CARD_TAMBAYAN_WARMTH,
		"kind": KIND_FAVOR,
		"title": "Tambayan Warmth",
		"sigil": "♡",
		"icon": "res://Assets/ui/icons/heart-handshake.png",
		"tagline": "+1 Lingering · 2× Hangout XP",
		"description": "Neighbors love lingering by your store. Allows +1 extra lingering visitor, doubles passive Tambayan XP, and makes visitors more likely to buy before leaving.",
		"description_rich": "Cozy energy fills your [b]Tambayan[/b], welcoming another lingering neighbor and doubling hangout [b]Player XP[/b].",
		"keywords": ["tambayan", "player_xp"],
		"stats": [
			{"label": "Max Lingering Visitors:", "value": "+1", "tone": "pos"},
			{"label": "Tambayan Passive XP:", "value": "2×", "tone": "pos"},
		],
		"hud_short": "+1 Tambay · 2× Hangout XP",
	},
	CARD_ECHOES_ON_THE_DIAL: {
		"id": CARD_ECHOES_ON_THE_DIAL,
		"kind": KIND_FAVOR,
		"title": "Echoes on the Dial",
		"sigil": "◎",
		"icon": "res://Assets/ui/icons/radio.png",
		"tagline": "+1 Event · -50% Radio CD",
		"description": "Papa Ulap's signal rides a silver tailwind! Adds +1 possible Neighborhood Event today and cuts Radio event reveal cooldown in half.",
		"description_rich": "Papa Ulap's broadcast rides a silver tailwind, adding extra [b]Neighborhood Events[/b] and faster tuning.",
		"keywords": ["neighborhood_events"],
		"stats": [
			{"label": "Daily Event Slots:", "value": "+1", "tone": "pos"},
			{"label": "Radio Event Cooldown:", "value": "-50%", "tone": "pos"},
		],
		"hud_short": "+1 Event · -50% Radio CD",
	},
	CARD_WHOLESALE_BLESSING: {
		"id": CARD_WHOLESALE_BLESSING,
		"kind": KIND_FAVOR,
		"title": "Wholesale Blessing",
		"sigil": "%",
		"icon": "res://Assets/ui/icons/percent.png",
		"tagline": "Sulit Deals Unlocked / -35%",
		"description": "Uncle Mario finds a lucky supplier! Unlocks Daily Sulit Deals (-20% off) for today — or deepens your Wholesale Pass deals to -35% OFF.",
		"description_rich": "Uncle Mario scores a lucky supplier, activating or deepening [b]Sulit Deals[/b] on wholesale [b]Restock[/b].",
		"keywords": ["sulit_deals", "restock"],
		"stats": [
			{"label": "Daily Sulit Deals:", "value": "-20% / -35%", "tone": "pos"},
		],
		"hud_short": "Boosted Sulit Deals",
	},
	CARD_CURBSIDE_GLOW: {
		"id": CARD_CURBSIDE_GLOW,
		"kind": KIND_FAVOR,
		"title": "Curbside Glow",
		"sigil": "☀",
		"icon": "res://Assets/ui/icons/sun-medium.png",
		"tagline": "+15% Promo Bonus & Tips",
		"description": "Your storefront catches every eye on the street! Featured Category sales pay an extra +15% cash bonus, and Appreciation Tip chance rises by +15%.",
		"description_rich": "Your storefront glows under the moon, scaling [b]Featured Category[/b] bonuses and [b]Cash Sale[/b] tips.",
		"keywords": ["featured_category", "cash_sale"],
		"stats": [
			{"label": "Featured Category Bonus:", "value": "+15%", "tone": "pos"},
			{"label": "Appreciation Tip Chance:", "value": "+15%", "tone": "pos"},
		],
		"hud_short": "+15% Featured & Tip Chance",
	},
	CARD_UNRUSHED_HOUR: {
		"id": CARD_UNRUSHED_HOUR,
		"kind": KIND_FAVOR,
		"title": "Unrushed Hour",
		"sigil": "◷",
		"icon": "res://Assets/ui/icons/clock.png",
		"tagline": "+25% Haggle · +1 Patience",
		"description": "Easy conversation flows at your counter. Neighbors are 25% more likely to negotiate a Haggle and give you +1 extra Haggle patience.",
		"description_rich": "Easy conversation flows at your counter, boosting [b]Haggle[/b] odds and patience.",
		"keywords": ["haggle"],
		"stats": [
			{"label": "Haggle Trigger Chance:", "value": "+25%", "tone": "pos"},
			{"label": "Haggle Patience:", "value": "+1", "tone": "pos"},
		],
		"hud_short": "+25% Haggle · +1 Patience",
	},

	# ── Omen (12 Double-Edged Debuffs / Quirks) ──────────────────────────
	CARD_DISEMBODIED_WIND: {
		"id": CARD_DISEMBODIED_WIND,
		"kind": KIND_CHILL,
		"title": "Disembodied Wind",
		"sigil": "〰",
		"icon": "res://Assets/ui/icons/wind.png",
		"tagline": "2 Fridge Gusts · +12% Cold Bonus",
		"description": "Eerie gusts swing your fridge door open 2× tomorrow — shut it fast! Cold Drinks & Frozen stock sold cold earn a +12% Cold Sale Bonus.",
		"description_rich": "Eerie gusts swing your fridge door open — guard [b]Fridge Coldness[/b] to earn a [b]Cold Sale Bonus[/b]!",
		"keywords": ["fridge_coldness", "cold_sale_bonus"],
		"stats": [
			{"label": "Fridge Door Gusts:", "value": "2", "tone": "neg"},
			{"label": "Cold Sale Bonus:", "value": "+12%", "tone": "pos"},
		],
		"hud_short": "2 Fridge Gusts · +12% Cold",
	},
	CARD_EERIE_MIST_RUSH: {
		"id": CARD_EERIE_MIST_RUSH,
		"kind": KIND_CHILL,
		"title": "Eerie Mist Rush",
		"sigil": "☁",
		"icon": "res://Assets/ui/icons/cloud-fog.png",
		"tagline": "-1 Tolerance · +20% Traffic",
		"description": "Uneasy neighbors won't accept steep markups (-1 tolerance), but the mist draws customers 20% faster for quick sales.",
		"description_rich": "Uneasy neighbors have lower [b]Price Tolerance[/b], yet the silver mist accelerates [b]Foot Traffic[/b].",
		"keywords": ["price_tolerance", "foot_traffic"],
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
		"icon": "res://Assets/ui/icons/gift.png",
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
		"icon": "res://Assets/ui/icons/sunset.png",
		"tagline": "Closes 6:30 PM · +25% Traffic",
		"description": "Twilight arrives early at 6:30 PM, compressing the day — but neighbors hurry in 25% faster to shop before dark.",
		"description_rich": "Nightfall cuts [b]Store Hours[/b] short, yet hurrying neighbors surge [b]Foot Traffic[/b] before dusk.",
		"keywords": ["store_hours", "foot_traffic"],
		"stats": [
			{"label": "Closing Time:", "value": "6:30 PM", "tone": "neg"},
			{"label": "Customer Foot Traffic:", "value": "+25%", "tone": "pos"},
		],
		"hud_short": "Close 6:30 PM · +25% Traffic",
	},
	CARD_QUIET_ECLIPSE: {
		"id": CARD_QUIET_ECLIPSE,
		"kind": KIND_CHILL,
		"title": "Quiet Eclipse",
		"sigil": "●",
		"icon": "res://Assets/ui/icons/moon-star.png",
		"tagline": "No Events · +35% Player XP",
		"description": "An uncanny hush silences all daily Neighborhood Events tomorrow, yet every quiet sale and story grants +35% Player XP.",
		"description_rich": "An uncanny hush silences [b]Neighborhood Events[/b], turning the calm into extra [b]Player XP[/b].",
		"keywords": ["neighborhood_events", "player_xp"],
		"stats": [
			{"label": "Neighborhood Events:", "value": "None", "tone": "neg"},
			{"label": "Player XP Earned:", "value": "+35%", "tone": "pos"},
		],
		"hud_short": "No Events · +35% XP",
	},
	CARD_FADING_MEMORY: {
		"id": CARD_FADING_MEMORY,
		"kind": KIND_CHILL,
		"title": "Fading Memory",
		"sigil": "◌",
		"icon": "res://Assets/ui/icons/ghost.png",
		"tagline": "-35% XP · +10% Cash Tips",
		"description": "Karimlan's mist dulls word of mouth (-35% Player XP), yet dazed neighbors leave a +10% tip on every cash sale.",
		"description_rich": "Mist dulls [b]Player XP[/b] gains, yet dazed neighbors leave a scaling tip on every [b]Cash Sale[/b].",
		"keywords": ["player_xp", "cash_sale"],
		"stats": [
			{"label": "Player XP Earned:", "value": "-35%", "tone": "neg"},
			{"label": "Tip Per Cash Sale:", "value": "+10%", "tone": "pos"},
		],
		"hud_short": "-35% XP · +10% Tips",
	},
	CARD_FOGGY_HIGHWAY: {
		"id": CARD_FOGGY_HIGHWAY,
		"kind": KIND_CHILL,
		"title": "Foggy Highway",
		"sigil": "≈",
		"icon": "res://Assets/ui/icons/route.png",
		"tagline": "+65% Mario CD · +1 Free Unit",
		"description": "Thick fog slows Uncle Mario's delivery cooldown by +65% (~5h), but he packs +1 free bonus unit into every delivery you plan.",
		"description_rich": "Fog stretches Uncle Mario's [b]Restock[/b] cooldown, yet every delivery carries free [b]Bonus Stock[/b].",
		"keywords": ["restock", "bonus_stock"],
		"stats": [
			{"label": "Delivery Cooldown:", "value": "+65%", "tone": "neg"},
			{"label": "Free Items Per Delivery:", "value": "+1", "tone": "pos"},
		],
		"hud_short": "+65% Mario CD · +1 Bonus",
	},
	CARD_WARM_TRADE_WINDS: {
		"id": CARD_WARM_TRADE_WINDS,
		"kind": KIND_CHILL,
		"title": "Warm Trade Winds",
		"sigil": "♨",
		"icon": "res://Assets/ui/icons/thermometer-sun.png",
		"tagline": "+60% Fridge Drain · +40% Cold Demand",
		"description": "Humid gusts drain refrigerator coldness 60% faster, but thirsty neighbors crave Cold Drinks & Frozen Treats 40% more.",
		"description_rich": "Humid gusts rapidly drain [b]Fridge Coldness[/b], yet thirsty neighbors surge demand for cold stock.",
		"keywords": ["fridge_coldness"],
		"stats": [
			{"label": "Fridge Coldness Drain:", "value": "+60%", "tone": "neg"},
			{"label": "Cold & Frozen Demand:", "value": "+40%", "tone": "pos"},
		],
		"hud_short": "+60% Drain · +40% Cold Demand",
	},
	CARD_RESTLESS_CROWD: {
		"id": CARD_RESTLESS_CROWD,
		"kind": KIND_CHILL,
		"title": "Restless Crowd",
		"sigil": "⚡",
		"icon": "res://Assets/ui/icons/flame.png",
		"tagline": "-1 Tol · -25% Haggle · +15% Fair Tip",
		"description": "Impatient shoppers have -1 Price Tolerance and -25% Haggle chance, but fair-priced cash sales (Step 0 or +1) earn a +15% Fair-Trade Tip.",
		"description_rich": "Harsher [b]Price Tolerance[/b] and impatient [b]Haggle[/b] odds, yet fair [b]Cash Sales[/b] pay a generous tip.",
		"keywords": ["price_tolerance", "haggle", "cash_sale"],
		"stats": [
			{"label": "All Items Price Tolerance:", "value": "-1", "tone": "neg"},
			{"label": "Haggle Trigger Chance:", "value": "-25%", "tone": "neg"},
			{"label": "Fair Price (0/+1) Tip:", "value": "+15%", "tone": "pos"},
		],
		"hud_short": "-1 Tol · +15% Fair Tip",
	},
	CARD_STATIC_AIRWAVES: {
		"id": CARD_STATIC_AIRWAVES,
		"kind": KIND_CHILL,
		"title": "Static on the Airwaves",
		"sigil": "⌁",
		"icon": "res://Assets/ui/icons/radio-tower.png",
		"tagline": "+50% Radio CD · +10% Sale / Event",
		"description": "Crackling static stretches Radio reveal cooldown by +50% (2.25h) and hides Today's Visitors, but every active Neighborhood Event adds +10% to cash sales!",
		"description_rich": "Static delays Papa Ulap's tuning, yet each active [b]Neighborhood Event[/b] boosts all [b]Cash Sales[/b].",
		"keywords": ["neighborhood_events", "cash_sale"],
		"stats": [
			{"label": "Radio Cooldown / Visitors:", "value": "+50% / Hidden", "tone": "neg"},
			{"label": "Cash Sales Per Active Event:", "value": "+10%", "tone": "pos"},
		],
		"hud_short": "Static Radio · +10% / Event",
	},
	CARD_TIGHT_WHOLESALE: {
		"id": CARD_TIGHT_WHOLESALE,
		"kind": KIND_CHILL,
		"title": "Tight Wholesale",
		"sigil": "▲",
		"icon": "res://Assets/ui/icons/trending-up.png",
		"tagline": "+20% Restock Cost · +30% XP",
		"description": "Wholesale suppliers hike prices by +20% today, but every sale, visit, and story grants +30% bonus Player XP.",
		"description_rich": "Steeper wholesale [b]Restock[/b] costs today, rewarded with faster [b]Player XP[/b] growth.",
		"keywords": ["restock", "player_xp"],
		"stats": [
			{"label": "Restock Cost:", "value": "+20%", "tone": "neg"},
			{"label": "Player XP Earned:", "value": "+30%", "tone": "pos"},
		],
		"hud_short": "+20% Restock · +30% XP",
	},
	CARD_PICKY_CRAVINGS: {
		"id": CARD_PICKY_CRAVINGS,
		"kind": KIND_CHILL,
		"title": "Picky Cravings",
		"sigil": "▤",
		"icon": "res://Assets/ui/icons/layers-2.png",
		"tagline": "2+ Item Orders · +18% Bundle Bonus",
		"description": "Neighbors strongly insist on 2+ item baskets (risking missed stock), but completing a full multi-item cash order pays an +18% Bundle Bonus!",
		"description_rich": "Neighbors demand [b]Multi-Item Orders[/b] — fulfill the whole basket for a scaling [b]Cash Sale[/b] bonus.",
		"keywords": ["multi_item_order", "cash_sale"],
		"stats": [
			{"label": "Customer Order Size:", "value": "2+ Items", "tone": "neg"},
			{"label": "Full Multi-Item Cash Bonus:", "value": "+18%", "tone": "pos"},
		],
		"hud_short": "2+ Orders · +18% Bundle",
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

## Relative draft weights by rarity: common = 1.0, uncommon = 0.65, rare = 0.35.
const CARD_WEIGHTS: Dictionary = {
	# Favors
	CARD_SILVER_TOLERANCE: 1.0,
	CARD_MOONLIGHT_TIPS: 1.0,
	CARD_GENEROUS_BASKETS: 1.0,
	CARD_UNRUSHED_HOUR: 1.0,
	CARD_FROST_OF_BIRINGAN: 0.65,
	CARD_CLEAR_ROAD: 0.65,
	CARD_SILVER_RENOWN: 0.65,
	CARD_TAMBAYAN_WARMTH: 0.65,
	CARD_ECHOES_ON_THE_DIAL: 0.65,
	CARD_CURBSIDE_GLOW: 0.65,
	CARD_MOON_HOLDS_SKY: 0.35,
	CARD_SILVER_TOUCHED_BAG: 0.35,
	CARD_CROWDED_STOOP: 0.35,
	CARD_WHOLESALE_BLESSING: 0.35,
	# Omens
	CARD_EERIE_MIST_RUSH: 1.0,
	CARD_RELUCTANT_CARE: 1.0,
	CARD_FADING_MEMORY: 1.0,
	CARD_TIGHT_WHOLESALE: 1.0,
	CARD_DISEMBODIED_WIND: 0.65,
	CARD_FOGGY_HIGHWAY: 0.65,
	CARD_WARM_TRADE_WINDS: 0.65,
	CARD_RESTLESS_CROWD: 0.65,
	CARD_EARLY_DUSK: 0.35,
	CARD_QUIET_ECLIPSE: 0.35,
	CARD_STATIC_AIRWAVES: 0.35,
	CARD_PICKY_CRAVINGS: 0.35,
}

static func get_card_rarity(card_id: String) -> String:
	var w: float = float(CARD_WEIGHTS.get(card_id, 1.0))
	if w <= 0.40:
		return "rare"
	if w <= 0.75:
		return "uncommon"
	return "common"

static func _pop_weighted_card(pool: Array[Dictionary]) -> Dictionary:
	if pool.is_empty():
		return {}
	var total_w: float = 0.0
	for c in pool:
		total_w += float(CARD_WEIGHTS.get(str(c.get("id", "")), 1.0))
	var r: float = randf() * total_w
	var acc: float = 0.0
	for i in range(pool.size()):
		acc += float(CARD_WEIGHTS.get(str(pool[i].get("id", "")), 1.0))
		if r <= acc:
			var picked: Dictionary = pool[i]
			pool.remove_at(i)
			return picked
	return pool.pop_back()

## Draws 3 unique cards for the post-tally roguelike draft using rarity-weighted sampling:
## - "generous" / "cleared": 3 guaranteed Favor cards
## - "shortfall": 100% Omen normally; 75% Omen / 25% Favor with 50% Silver Favor milestone
## - "balanced": 80% Omen / 20% Favor normally; 50% Omen / 50% Favor with 50% Silver Favor milestone
static func draw_three_cards(tally_tier: String, shifted_odds: bool = false) -> Array[Dictionary]:
	var favor_pool := get_cards_by_kind(KIND_FAVOR)
	var chill_pool := get_cards_by_kind(KIND_CHILL)

	var picked: Array[Dictionary] = []
	match tally_tier:
		"include_omens":
			for _i in range(3):
				if randf() < 0.50 and not favor_pool.is_empty():
					picked.append(_pop_weighted_card(favor_pool))
				elif not chill_pool.is_empty():
					picked.append(_pop_weighted_card(chill_pool))
				elif not favor_pool.is_empty():
					picked.append(_pop_weighted_card(favor_pool))
		"omens_only":
			for _i in range(mini(3, chill_pool.size())):
				picked.append(_pop_weighted_card(chill_pool))
		"generous", "cleared":
			for _i in range(mini(3, favor_pool.size())):
				picked.append(_pop_weighted_card(favor_pool))
		"shortfall":
			if shifted_odds:
				for _i in range(3):
					if randf() < 0.25 and not favor_pool.is_empty():
						picked.append(_pop_weighted_card(favor_pool))
					elif not chill_pool.is_empty():
						picked.append(_pop_weighted_card(chill_pool))
			else:
				for _i in range(mini(3, chill_pool.size())):
					picked.append(_pop_weighted_card(chill_pool))
		_:
			# "balanced" (sufficient): 80% Omen / 20% Favor normally, or 50% Favor / 50% Omen when shifted
			var favor_prob := 0.50 if shifted_odds else 0.20
			for _i in range(3):
				if randf() < favor_prob and not favor_pool.is_empty():
					picked.append(_pop_weighted_card(favor_pool))
				elif not chill_pool.is_empty():
					picked.append(_pop_weighted_card(chill_pool))
				elif not favor_pool.is_empty():
					picked.append(_pop_weighted_card(favor_pool))

	return picked

## Returns the slot preview metadata ("favor", "omen", or "mystery") for Beat 1's 3 shadowed slots.
static func get_slot_preview_kinds(tally_tier: String, shifted_odds: bool = false) -> Array[String]:
	match tally_tier:
		"omens_only":
			return ["omen", "omen", "omen"]
		"generous", "cleared":
			return ["favor", "favor", "favor"]
		"shortfall":
			if shifted_odds:
				return ["mystery", "mystery", "mystery"]
			return ["omen", "omen", "omen"]
		_:
			return ["mystery", "mystery", "mystery"]
