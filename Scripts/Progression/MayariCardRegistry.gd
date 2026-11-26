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
		"desc": "A neighbor requesting 2+ items at once — grants +5 bonus Player XP per extra item.",
	},
	"player_xp": {
		"title": "PLAYER XP",
		"desc": "Earned from sales, visits, and stories to level up and unlock higher product tiers & upgrades.",
	},
	"neighborhood_events": {
		"title": "NEIGHBORHOOD EVENTS",
		"desc": "Daily Karimlan conditions revealed via Papa Ulap's Radio that boost demand and Price Tolerance.",
	},
	"foot_traffic": {
		"title": "FOOT TRAFFIC",
		"desc": "Speeds up customer arrivals and shortens time skips between waves so more neighbors visit each day.",
	},
	"sulit_deals": {
		"title": "SULIT DEALS",
		"desc": "Daily discounted wholesale picks from Uncle Mario in the Restock Menu.",
	},
	"featured_category": {
		"title": "FEATURED CATEGORY",
		"desc": "Activated by placing 3/3 stickers of one category on your Roof Signage or Promo Poster.",
	},
	"tambayan": {
		"title": "TAMBAYAN",
		"desc": "Lingering neighbors who hang out around the store, granting passive XP and occasional extra purchases.",
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
		"icon": "res://Assets/ui/icons/sparkles.png",
		"tagline": "+12% Tip Per Cash Sale",
		"description": "Gratitude shines bright under the silver spires. Earn a +12% Moonlight Tip on every satisfied cash sale tomorrow.",
		"description_rich": "Gratitude shines under the silver spires. Earn a scaling bonus tip on every satisfied [b]Cash Sale[/b].",
		"keywords": ["cash_sale"],
		"stats": [
			{"label": "Tip Per Cash Sale:", "value": "+12%", "tone": "pos"},
		],
		"hud_short": "+12% Moonlight Tips",
	},
	CARD_CLEAR_ROAD: {
		"id": CARD_CLEAR_ROAD,
		"kind": KIND_FAVOR,
		"title": "Clear Road",
		"sigil": "»",
		"icon": "res://Assets/ui/icons/route.png",
		"tagline": "35% Faster Mario & 10% Off",
		"description": "The moonlight clears the road for Uncle Mario: 10% off restock orders and 35% shorter delivery cooldown.",
		"description_rich": "Moonlight clears the road for Uncle Mario, lowering [b]Restock[/b] costs and cutting delivery cooldown time.",
		"keywords": ["restock"],
		"stats": [
			{"label": "Restock Cost:", "value": "-10%", "tone": "pos"},
			{"label": "Delivery Cooldown:", "value": "-35%", "tone": "pos"},
		],
		"hud_short": "10% Off Restock & -35% Mario CD",
	},
	CARD_SILVER_TOUCHED_BAG: {
		"id": CARD_SILVER_TOUCHED_BAG,
		"kind": KIND_FAVOR,
		"title": "Silver-Touched Bag",
		"sigil": "✧",
		"icon": "res://Assets/ui/icons/package.png",
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
		"tagline": "+20% Haggle · -20% Refusal",
		"description": "Easy conversation flows at your counter. Neighbors are 20% less likely to refuse markups and 20% more likely to accept a Haggle.",
		"description_rich": "Easy conversation flows at your counter, softening [b]Price Tolerance[/b] pushback and boosting Haggle odds.",
		"keywords": ["price_tolerance"],
		"stats": [
			{"label": "Haggle Accept Chance:", "value": "+20%", "tone": "pos"},
			{"label": "Markup Refusal Chance:", "value": "-20%", "tone": "pos"},
		],
		"hud_short": "+20% Haggle · -20% Refusal",
	},

	# ── Omen (12 Double-Edged Debuffs / Quirks) ──────────────────────────
	CARD_DISEMBODIED_WIND: {
		"id": CARD_DISEMBODIED_WIND,
		"kind": KIND_CHILL,
		"title": "Disembodied Wind",
		"sigil": "〰",
		"icon": "res://Assets/ui/icons/wind.png",
		"tagline": "Fridge Gusts · +12% Cold Bonus",
		"description": "Eerie gusts swing your fridge door open 1–2× tomorrow — shut it fast! Cold Drinks & Frozen Treats sold cold earn a +12% Chilled Bonus.",
		"description_rich": "Eerie gusts swing your fridge door open — guard [b]Fridge Coldness[/b] to earn a bonus on cold [b]Cash Sales[/b]!",
		"keywords": ["fridge_coldness", "cash_sale"],
		"stats": [
			{"label": "Refrigerator Door Gusts:", "value": "1–2", "tone": "neg"},
			{"label": "Chilled Fridge Sale Bonus:", "value": "+12%", "tone": "pos"},
		],
		"hud_short": "Fridge Gusts · +12% Cold",
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
		"tagline": "-1 Tol & Walkouts · +15% Fair Tip",
		"description": "Impatient shoppers have -1 Tolerance and +20% markup walkout chance, but fair-priced cash sales (Step 0 or +1) earn a +15% Fair-Trade Tip.",
		"description_rich": "Harsher [b]Price Tolerance[/b] and walkouts on markups, yet fair [b]Cash Sales[/b] pay a generous tip.",
		"keywords": ["price_tolerance", "cash_sale"],
		"stats": [
			{"label": "Price Tolerance / Walkouts:", "value": "-1 / +20%", "tone": "neg"},
			{"label": "Fair Price (0/+1) Tip:", "value": "+15%", "tone": "pos"},
		],
		"hud_short": "Strict Prices · +15% Fair Tip",
	},
	CARD_STATIC_AIRWAVES: {
		"id": CARD_STATIC_AIRWAVES,
		"kind": KIND_CHILL,
		"title": "Static on the Airwaves",
		"sigil": "⌁",
		"icon": "res://Assets/ui/icons/radio-tower.png",
		"tagline": "+50% Radio CD · +10% Sale / Event",
		"description": "Crackling static stretches Radio reveal cooldown by +50% (6h) and hides Expected Regulars, but every active Neighborhood Event adds +10% to cash sales!",
		"description_rich": "Static delays Papa Ulap's tuning, yet each active [b]Neighborhood Event[/b] boosts all [b]Cash Sales[/b].",
		"keywords": ["neighborhood_events", "cash_sale"],
		"stats": [
			{"label": "Radio Cooldown / Regulars:", "value": "+50% / Hidden", "tone": "neg"},
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

## Draws 3 unique cards for the post-tally roguelike draft:
## - "generous" / "cleared": 3 guaranteed Favor cards
## - "shortfall": 100% Omen normally; 75% Omen / 25% Favor with 50% Silver Favor milestone
## - "balanced": 55% Omen / 45% Favor normally; 35% Omen / 65% Favor with 50% Silver Favor milestone
static func draw_three_cards(tally_tier: String, shifted_odds: bool = false) -> Array[Dictionary]:
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
			if shifted_odds:
				for _i in range(3):
					if randf() < 0.25 and not favor_pool.is_empty():
						picked.append(favor_pool.pop_back())
					elif not chill_pool.is_empty():
						picked.append(chill_pool.pop_back())
			else:
				for i in range(mini(3, chill_pool.size())):
					picked.append(chill_pool[i])
		_:
			# "balanced" (sufficient): 55% Omen / 45% Favor normally, or 65% Favor / 35% Omen when shifted
			var favor_prob := 0.65 if shifted_odds else 0.45
			for _i in range(3):
				if randf() < favor_prob and not favor_pool.is_empty():
					picked.append(favor_pool.pop_back())
				elif not chill_pool.is_empty():
					picked.append(chill_pool.pop_back())
				elif not favor_pool.is_empty():
					picked.append(favor_pool.pop_back())

	return picked

## Returns the slot preview metadata ("favor", "omen", or "mystery") for Beat 1's 3 shadowed slots.
static func get_slot_preview_kinds(tally_tier: String, shifted_odds: bool = false) -> Array[String]:
	match tally_tier:
		"generous", "cleared":
			return ["favor", "favor", "favor"]
		"shortfall":
			if shifted_odds:
				return ["mystery", "mystery", "mystery"]
			return ["omen", "omen", "omen"]
		_:
			return ["mystery", "mystery", "mystery"]
