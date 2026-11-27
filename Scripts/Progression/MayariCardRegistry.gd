class_name MayariCardRegistry
extends RefCounted

## Catalog and roguelike 3-card draft logic for Reyna Mayari's Nightly Tally.
## After choosing a nightly contribution, the player drafts 1–2 of 3 Moon Cards
## whose effect applies throughout the following day.
## Favors grant pure scalable advantages; Omens are mostly double-edged swords
## with a real downside paired with a strategic comeback angle.

const KIND_FAVOR := "favor"
const KIND_CHILL := "chill"

## Card IDs — Favor (32 Buffs)
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
const CARD_WARM_WELCOME := "warm_welcome"
const CARD_SWIFT_CHILL := "swift_chill"
const CARD_HONORED_LISTA := "honored_lista"
const CARD_OPEN_EARS := "open_ears"
const CARD_LUCKY_WRIST := "lucky_wrist"
const CARD_SILVER_LEDGER_GRACE := "silver_ledger_grace"
const CARD_EXPRESS_RESTOCK := "express_restock"
const CARD_BRIGHT_AWNING := "bright_awning"
const CARD_CLEAR_SIGNAL := "clear_signal"
const CARD_MERIENDA_BENCH := "merienda_bench"
const CARD_MOONLIT_BOUNTY := "moonlit_bounty"
const CARD_GOLDEN_COUNTER := "golden_counter"
const CARD_BARGAIN_CHORUS := "bargain_chorus"
const CARD_COINS_IN_THE_JAR := "coins_in_the_jar"
const CARD_TIKBALANG_SHORTCUT := "tikbalang_shortcut"
const CARD_ALBULARYO_CHARM := "albularyo_charm"
const CARD_SILVER_BELL_COUNTER := "silver_bell_counter"
const CARD_MAYARI_FULL_MOON := "mayari_full_moon"

## Card IDs — Omen (30 Double-Edged Debuffs / Quirks)
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
const CARD_SHY_NEIGHBORS := "shy_neighbors"
const CARD_OVERDUE_LISTA := "overdue_lista"
const CARD_FROSTBITTEN_COILS := "frostbitten_coils"
const CARD_BRISK_COUNTER := "brisk_counter"
const CARD_SILENT_STORIES := "silent_stories"
const CARD_SHARP_BARGAINERS := "sharp_bargainers"
const CARD_LOOSE_TAB := "loose_tab"
const CARD_SLOW_DIAL := "slow_dial"
const CARD_HEAVY_BAGS := "heavy_bags"
const CARD_RESTLESS_BENCH := "restless_bench"
const CARD_STUBBORN_HAGGLERS := "stubborn_hagglers"
const CARD_THIRSTY_NIGHT := "thirsty_night"
const CARD_SOUR_CHANGE := "sour_change"
const CARD_SLAMMING_DRAFT := "slamming_draft"
const CARD_DUWENDE_MISCHIEF := "duwende_mischief"
const CARD_BORROWED_HOUR := "borrowed_hour"
const CARD_BLOOD_MOON_BARGAIN := "blood_moon_bargain"
const CARD_PHANTOM_QUEUE := "phantom_queue"

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
	CARD_WARM_WELCOME: {
		"id": CARD_WARM_WELCOME,
		"kind": KIND_FAVOR,
		"title": "Warm Welcome",
		"sigil": "♡",
		"icon": "res://Assets/ui/icons/heart-handshake.png",
		"tagline": "+25% Neighbor Reputation",
		"description": "Every neighbor leaves feeling like family. All positive Neighbor Reputation gains are increased by +25% today.",
		"description_rich": "Your counter radiates warmth, increasing all positive [b]Neighbor Reputation[/b] gains today.",
		"keywords": ["reputation"],
		"stats": [
			{"label": "Neighbor Reputation:", "value": "+25%", "tone": "pos"},
		],
		"hud_short": "+25% Reputation",
	},
	CARD_SWIFT_CHILL: {
		"id": CARD_SWIFT_CHILL,
		"kind": KIND_FAVOR,
		"title": "Swift Chill",
		"sigil": "❄",
		"icon": "res://Assets/ui/icons/snowflake.png",
		"tagline": "+50% Re-Chill · +8% Cold Sale Bonus",
		"description": "The fridge compressor hums with lunar frost. Re-Chill Speed increases by +50% and Cold Sale Bonus rises by +8%.",
		"description_rich": "Faster [b]Re-Chill Speed[/b] keeps your fridge crisp and adds a steady [b]Cold Sale Bonus[/b].",
		"keywords": ["rechill_speed", "cold_sale_bonus"],
		"stats": [
			{"label": "Re-Chill Speed:", "value": "+50%", "tone": "pos"},
			{"label": "Cold Sale Bonus:", "value": "+8%", "tone": "pos"},
		],
		"hud_short": "+50% Re-Chill · +8% Cold Bonus",
	},
	CARD_HONORED_LISTA: {
		"id": CARD_HONORED_LISTA,
		"kind": KIND_FAVOR,
		"title": "Honored Lista",
		"sigil": "▤",
		"icon": "res://Assets/ui/icons/book-bookmark.png",
		"tagline": "+30% Utang Repay Chance · +20% Repay Bonus",
		"description": "Neighbors remember every kindness in your notebook. Utang repayment chance increases by +30% and repayments pay +20% extra cash.",
		"description_rich": "Neighbors honor their [b]Utang[/b] tab faster and add a generous gratitude bonus when settling up.",
		"keywords": ["utang"],
		"stats": [
			{"label": "Utang Repay Chance:", "value": "+30%", "tone": "pos"},
			{"label": "Utang Repay Bonus:", "value": "+20%", "tone": "pos"},
		],
		"hud_short": "+30% Repay · +20% Bonus",
	},
	CARD_OPEN_EARS: {
		"id": CARD_OPEN_EARS,
		"kind": KIND_FAVOR,
		"title": "Open Ears",
		"sigil": "✦",
		"icon": "res://Assets/ui/icons/book-plus.png",
		"tagline": "+25% Story Chance · +15% Reputation",
		"description": "The street feels chatty and unhurried. Story Chance increases by +25% and Neighbor Reputation gains rise by +15%.",
		"description_rich": "Regulars open up more readily today, lifting [b]Story Chance[/b] and [b]Neighbor Reputation[/b].",
		"keywords": ["story_chance", "reputation"],
		"stats": [
			{"label": "Story Chance:", "value": "+25%", "tone": "pos"},
			{"label": "Neighbor Reputation:", "value": "+15%", "tone": "pos"},
		],
		"hud_short": "+25% Story · +15% Rep",
	},
	CARD_LUCKY_WRIST: {
		"id": CARD_LUCKY_WRIST,
		"kind": KIND_FAVOR,
		"title": "Lucky Wrist",
		"sigil": "★",
		"icon": "res://Assets/ui/icons/trophy.png",
		"tagline": "+50% Minigame Rewards · +20% Tip Chance",
		"description": "Sharp reflexes and bright charm! Minigame cash and XP rewards increase by +50%, and Appreciation Tip Chance rises by +20%.",
		"description_rich": "Sharp focus boosts [b]Minigame Rewards[/b] and raises your [b]Tip Chance[/b] at the counter.",
		"keywords": ["minigame_rewards", "tip_chance"],
		"stats": [
			{"label": "Minigame Rewards:", "value": "+50%", "tone": "pos"},
			{"label": "Tip Chance:", "value": "+20%", "tone": "pos"},
		],
		"hud_short": "+50% Minigames · +20% Tip Chance",
	},
	CARD_SILVER_LEDGER_GRACE: {
		"id": CARD_SILVER_LEDGER_GRACE,
		"kind": KIND_FAVOR,
		"title": "Silver Ledger Grace",
		"sigil": "✧",
		"icon": "res://Assets/ui/icons/sparkles.png",
		"tagline": "+1 Price Tolerance · +10% Tips · +20% Rep",
		"description": "Reyna Mayari's rarest seal blesses your ledger: +1 Price Tolerance on all items, +10% Cash Tip Bonus, and +20% Neighbor Reputation.",
		"description_rich": "A rare silver seal grants extra [b]Price Tolerance[/b], [b]Cash Tip Bonus[/b], and [b]Neighbor Reputation[/b].",
		"keywords": ["price_tolerance", "cash_tip_bonus", "reputation"],
		"stats": [
			{"label": "All Items Price Tolerance:", "value": "+1", "tone": "pos"},
			{"label": "Cash Tip Bonus:", "value": "+10%", "tone": "pos"},
			{"label": "Neighbor Reputation:", "value": "+20%", "tone": "pos"},
		],
		"hud_short": "+1 Tol · +10% Tips · +20% Rep",
	},
	CARD_EXPRESS_RESTOCK: {
		"id": CARD_EXPRESS_RESTOCK,
		"kind": KIND_FAVOR,
		"title": "Express Restock",
		"sigil": "⇒",
		"icon": "res://Assets/ui/icons/truck.png",
		"tagline": "-25% Delivery Cooldown · -8% Restock Cost",
		"description": "Uncle Mario hits every green light! Delivery Cooldown drops by 25% and wholesale Restock costs drop by 8%.",
		"description_rich": "Faster [b]Delivery Cooldown[/b] and lighter wholesale [b]Restock[/b] costs keep your shelves full.",
		"keywords": ["delivery_cooldown", "restock"],
		"stats": [
			{"label": "Delivery Cooldown:", "value": "-25%", "tone": "pos"},
			{"label": "Restock Cost:", "value": "-8%", "tone": "pos"},
		],
		"hud_short": "-25% Delivery CD · -8% Restock",
	},
	CARD_BRIGHT_AWNING: {
		"id": CARD_BRIGHT_AWNING,
		"kind": KIND_FAVOR,
		"title": "Bright Awning",
		"sigil": "☀",
		"icon": "res://Assets/ui/icons/sun.png",
		"tagline": "+15% Foot Traffic · +12% Tip Chance",
		"description": "Sunlight catches your storefront awning, drawing +15% more Customer Foot Traffic and lifting Tip Chance by +12%.",
		"description_rich": "A welcoming storefront boosts [b]Customer Foot Traffic[/b] and raises your [b]Tip Chance[/b].",
		"keywords": ["foot_traffic", "tip_chance"],
		"stats": [
			{"label": "Customer Foot Traffic:", "value": "+15%", "tone": "pos"},
			{"label": "Tip Chance:", "value": "+12%", "tone": "pos"},
		],
		"hud_short": "+15% Traffic · +12% Tip Chance",
	},
	CARD_CLEAR_SIGNAL: {
		"id": CARD_CLEAR_SIGNAL,
		"kind": KIND_FAVOR,
		"title": "Clear Signal",
		"sigil": "◉",
		"icon": "res://Assets/ui/icons/radio.png",
		"tagline": "-50% Radio Cooldown · +20% Player XP",
		"description": "Crystal-clear reception from Papa Ulap's booth! Radio Cooldown is halved (-50%) and all Player XP earned rises by +20%.",
		"description_rich": "Halves [b]Radio Cooldown[/b] between broadcasts and boosts all [b]Player XP[/b] earned today.",
		"keywords": ["radio_cooldown", "player_xp"],
		"stats": [
			{"label": "Radio Cooldown:", "value": "-50%", "tone": "pos"},
			{"label": "Player XP Earned:", "value": "+20%", "tone": "pos"},
		],
		"hud_short": "-50% Radio CD · +20% XP",
	},
	CARD_MERIENDA_BENCH: {
		"id": CARD_MERIENDA_BENCH,
		"kind": KIND_FAVOR,
		"title": "Merienda Bench",
		"sigil": "☕",
		"icon": "res://Assets/ui/icons/coffee.png",
		"tagline": "+20% Tambayan Linger · +20% Reputation",
		"description": "Neighbors linger over merienda and stories. Tambayan Linger Chance rises by +20% and Neighbor Reputation gains increase by +20%.",
		"description_rich": "Cozy chats at the [b]Tambayan[/b] lift linger odds and deepen [b]Neighbor Reputation[/b].",
		"keywords": ["tambayan", "reputation"],
		"stats": [
			{"label": "Tambayan Linger Chance:", "value": "+20%", "tone": "pos"},
			{"label": "Neighbor Reputation:", "value": "+20%", "tone": "pos"},
		],
		"hud_short": "+20% Linger · +20% Rep",
	},
	CARD_MOONLIT_BOUNTY: {
		"id": CARD_MOONLIT_BOUNTY,
		"kind": KIND_FAVOR,
		"title": "Moonlit Bounty",
		"sigil": "✦",
		"icon": "res://Assets/ui/icons/gift.png",
		"tagline": "+1 Bonus Stock · -15% Restock · -30% Delivery CD",
		"description": "Every wholesale trip arrives overflowing: +1 free Bonus Stock per delivery, -15% Restock Cost, and -30% Delivery Cooldown.",
		"description_rich": "A rare supply blessing granting [b]Bonus Stock[/b], cheaper [b]Restock[/b], and faster [b]Delivery Cooldown[/b].",
		"keywords": ["bonus_stock", "restock", "delivery_cooldown"],
		"stats": [
			{"label": "Free Bonus Stock per Delivery:", "value": "+1", "tone": "pos"},
			{"label": "Restock Cost:", "value": "-15%", "tone": "pos"},
			{"label": "Delivery Cooldown:", "value": "-30%", "tone": "pos"},
		],
		"hud_short": "+1 Bonus Stock · -15% Cost · -30% CD",
	},
	CARD_GOLDEN_COUNTER: {
		"id": CARD_GOLDEN_COUNTER,
		"kind": KIND_FAVOR,
		"title": "Golden Counter",
		"sigil": "₱",
		"icon": "res://Assets/ui/icons/banknote.png",
		"tagline": "+15% Cash Tips · +20% Tip Chance · +25% XP",
		"description": "Coins ring bright across your counter: +15% Cash Tip Bonus, +20% Tip Chance, and +25% Player XP all day.",
		"description_rich": "A rare prosperity blessing scaling [b]Cash Tip Bonus[/b], [b]Tip Chance[/b], and [b]Player XP[/b].",
		"keywords": ["cash_tip_bonus", "tip_chance", "player_xp"],
		"stats": [
			{"label": "Cash Tip Bonus:", "value": "+15%", "tone": "pos"},
			{"label": "Tip Chance:", "value": "+20%", "tone": "pos"},
			{"label": "Player XP Earned:", "value": "+25%", "tone": "pos"},
		],
		"hud_short": "+15% Tips · +20% Tip Chance · +25% XP",
	},
	CARD_BARGAIN_CHORUS: {
		"id": CARD_BARGAIN_CHORUS,
		"kind": KIND_FAVOR,
		"title": "Bargain Chorus",
		"sigil": "♪",
		"icon": "res://Assets/ui/icons/mic-vocal.png",
		"tagline": "+₱15 Haggle Win Bonus · +25% Haggle Chance",
		"description": "Playful banter wins over the crowd! Winning a Haggle Duel pays a flat +₱15 bonus, and Haggle Trigger Chance rises by +25%.",
		"description_rich": "Winning any [b]Haggle[/b] duel pays a flat +₱15 bonus and raises [b]Haggle[/b] trigger odds.",
		"keywords": ["haggle", "cash_sale"],
		"stats": [
			{"label": "Haggle Win Bonus:", "value": "+₱15", "tone": "pos"},
			{"label": "Haggle Trigger Chance:", "value": "+25%", "tone": "pos"},
		],
		"hud_short": "+₱15 Haggle Win · +25% Haggle",
	},
	CARD_COINS_IN_THE_JAR: {
		"id": CARD_COINS_IN_THE_JAR,
		"kind": KIND_FAVOR,
		"title": "Coins in the Jar",
		"sigil": "₱",
		"icon": "res://Assets/ui/icons/banknote.png",
		"tagline": "+12% Fair-Price Sale Bonus · +15% Tip Chance",
		"description": "Fair prices bring loyal change! Every Cash Sale at Price Step 0 or lower earns a +12% Cash Bonus, and Tip Chance rises by +15%.",
		"description_rich": "Fair-priced [b]Cash Sales[/b] (step ≤ 0) earn a scaling bonus and raise [b]Tip Chance[/b].",
		"keywords": ["cash_sale", "tip_chance"],
		"stats": [
			{"label": "Cash Sale Bonus (Step ≤ 0):", "value": "+12%", "tone": "pos"},
			{"label": "Tip Chance:", "value": "+15%", "tone": "pos"},
		],
		"hud_short": "+12% Fair-Price Bonus · +15% Tip Chance",
	},
	CARD_TIKBALANG_SHORTCUT: {
		"id": CARD_TIKBALANG_SHORTCUT,
		"kind": KIND_FAVOR,
		"title": "Tikbalang's Shortcut",
		"sigil": "⇶",
		"icon": "res://Assets/ui/icons/route.png",
		"tagline": "-40% Delivery CD · +1 Bonus Stock",
		"description": "Hidden back-alley paths speed Uncle Mario's van! Delivery Cooldown drops by 40% and every delivery includes +1 Free Bonus Stock.",
		"description_rich": "Cuts [b]Delivery Cooldown[/b] sharply and tucks +1 free [b]Bonus Stock[/b] into every delivery.",
		"keywords": ["delivery_cooldown", "bonus_stock"],
		"stats": [
			{"label": "Delivery Cooldown:", "value": "-40%", "tone": "pos"},
			{"label": "Free Bonus Stock per Delivery:", "value": "+1", "tone": "pos"},
		],
		"hud_short": "-40% Delivery CD · +1 Bonus Stock",
	},
	CARD_ALBULARYO_CHARM: {
		"id": CARD_ALBULARYO_CHARM,
		"kind": KIND_FAVOR,
		"title": "Albularyo's Charm",
		"sigil": "✚",
		"icon": "res://Assets/ui/icons/heart-pulse.png",
		"tagline": "-40% Coldness Drain · +40% Re-Chill · +10% Cold Bonus",
		"description": "A blessed ginger pouch cools your fridge: Coldness Drain drops 40%, Re-Chill Speed rises +40%, and Cold Sale Bonus rises +10%.",
		"description_rich": "Slows [b]Coldness Drain[/b], speeds [b]Re-Chill Speed[/b], and lifts [b]Cold Sale Bonus[/b].",
		"keywords": ["coldness_drain", "rechill_speed", "cold_sale_bonus"],
		"stats": [
			{"label": "Fridge Coldness Drain:", "value": "-40%", "tone": "pos"},
			{"label": "Re-Chill Speed:", "value": "+40%", "tone": "pos"},
			{"label": "Cold Sale Bonus:", "value": "+10%", "tone": "pos"},
		],
		"hud_short": "-40% Drain · +40% Re-Chill · +10% Cold",
	},
	CARD_SILVER_BELL_COUNTER: {
		"id": CARD_SILVER_BELL_COUNTER,
		"kind": KIND_FAVOR,
		"title": "Silver Bell Counter",
		"sigil": "✦",
		"icon": "res://Assets/ui/icons/sparkles.png",
		"tagline": "+25% Multi-Item Chance · +20% Full Bundle Bonus",
		"description": "A silver bell chimes for big baskets! Multi-Item Order chance rises by +25% and completing a full 2+ item Cash Order pays a +20% Bundle Bonus.",
		"description_rich": "Encourages [b]Multi-Item Orders[/b] and rewards every full basket with a +20% [b]Cash Sale[/b] bonus.",
		"keywords": ["multi_item_order", "cash_sale"],
		"stats": [
			{"label": "Multi-Item Order Chance:", "value": "+25%", "tone": "pos"},
			{"label": "Full Multi-Item Cash Bonus:", "value": "+20%", "tone": "pos"},
		],
		"hud_short": "+25% Multi-Item · +20% Bundle",
	},
	CARD_MAYARI_FULL_MOON: {
		"id": CARD_MAYARI_FULL_MOON,
		"kind": KIND_FAVOR,
		"title": "Blessing of the Full Moon",
		"sigil": "🌕",
		"icon": "res://Assets/ui/icons/moon-star.png",
		"tagline": "Open until 9:00 PM · +1 Tol · +20% Reputation",
		"description": "Mayari's full light lingers over Karimlan: Store Hours extend to 9:00 PM, all items gain +1 Price Tolerance, and Reputation gains rise +20%.",
		"description_rich": "Extends [b]Store Hours[/b] to 9:00 PM while boosting [b]Price Tolerance[/b] and [b]Neighbor Reputation[/b].",
		"keywords": ["store_hours", "price_tolerance", "reputation"],
		"stats": [
			{"label": "Store Closing Time:", "value": "9:00 PM", "tone": "pos"},
			{"label": "All Items Price Tolerance:", "value": "+1", "tone": "pos"},
			{"label": "Neighbor Reputation:", "value": "+20%", "tone": "pos"},
		],
		"hud_short": "9:00 PM Close · +1 Tol · +20% Rep",
	},

	# ── Omen (30 Double-Edged Debuffs / Quirks) ──────────────────────────
	CARD_DISEMBODIED_WIND: {
		"id": CARD_DISEMBODIED_WIND,
		"kind": KIND_CHILL,
		"title": "Disembodied Wind",
		"sigil": "〰",
		"icon": "res://Assets/ui/icons/wind.png",
		"tagline": "25% Hourly Gust · +12% Cold Bonus",
		"description": "Eerie gusts have a 25% chance each hour to swing your fridge door open — shut it fast! Cold Drinks & Frozen stock sold cold earn a +12% Cold Sale Bonus.",
		"description_rich": "Eerie gusts have a 25% hourly chance to pop your fridge — guard [b]Fridge Coldness[/b] to earn a [b]Cold Sale Bonus[/b]!",
		"keywords": ["fridge_coldness", "cold_sale_bonus"],
		"stats": [
			{"label": "Hourly Fridge Gust Chance:", "value": "25%", "tone": "neg"},
			{"label": "Cold Sale Bonus:", "value": "+12%", "tone": "pos"},
		],
		"hud_short": "25% Gust/hr · +12% Cold",
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
	CARD_SHY_NEIGHBORS: {
		"id": CARD_SHY_NEIGHBORS,
		"kind": KIND_CHILL,
		"title": "Shy Neighbors",
		"sigil": "◡",
		"icon": "res://Assets/ui/icons/users.png",
		"tagline": "-25% Reputation · +12% Cash Tip Bonus",
		"description": "Shoppers keep conversation brief today (-25% Neighbor Reputation), but they leave +12% extra Cash Tip Bonus on satisfied sales.",
		"description_rich": "Quiet shoppers build [b]Neighbor Reputation[/b] slower, yet leave a bigger [b]Cash Tip Bonus[/b].",
		"keywords": ["reputation", "cash_tip_bonus"],
		"stats": [
			{"label": "Neighbor Reputation:", "value": "-25%", "tone": "neg"},
			{"label": "Cash Tip Bonus:", "value": "+12%", "tone": "pos"},
		],
		"hud_short": "-25% Rep · +12% Tips",
	},
	CARD_OVERDUE_LISTA: {
		"id": CARD_OVERDUE_LISTA,
		"kind": KIND_CHILL,
		"title": "Overdue Lista",
		"sigil": "▤",
		"icon": "res://Assets/ui/icons/book-bookmark.png",
		"tagline": "-25% Repay Chance · +35% Repay Bonus",
		"description": "Debtors stall on their tabs (-25% Utang Repay Chance), yet anyone who settles today adds a +35% gratitude bonus.",
		"description_rich": "Fewer neighbors settle [b]Utang[/b] today, but each repayment pays a hefty bonus.",
		"keywords": ["utang"],
		"stats": [
			{"label": "Utang Repay Chance:", "value": "-25%", "tone": "neg"},
			{"label": "Utang Repay Bonus:", "value": "+35%", "tone": "pos"},
		],
		"hud_short": "-25% Repay · +35% Bonus",
	},
	CARD_FROSTBITTEN_COILS: {
		"id": CARD_FROSTBITTEN_COILS,
		"kind": KIND_CHILL,
		"title": "Frostbitten Coils",
		"sigil": "❄",
		"icon": "res://Assets/ui/icons/snowflake.png",
		"tagline": "-35% Re-Chill Speed · +18% Cold Sale Bonus",
		"description": "Thick ice slows your fridge's Re-Chill Speed by -35%, but chilled Drinks & Frozen items earn a hefty +18% Cold Sale Bonus.",
		"description_rich": "Sluggish [b]Re-Chill Speed[/b] punishes open doors, yet boosts [b]Cold Sale Bonus[/b] while kept cold.",
		"keywords": ["rechill_speed", "cold_sale_bonus"],
		"stats": [
			{"label": "Re-Chill Speed:", "value": "-35%", "tone": "neg"},
			{"label": "Cold Sale Bonus:", "value": "+18%", "tone": "pos"},
		],
		"hud_short": "-35% Re-Chill · +18% Cold Bonus",
	},
	CARD_BRISK_COUNTER: {
		"id": CARD_BRISK_COUNTER,
		"kind": KIND_CHILL,
		"title": "Brisk Counter",
		"sigil": "»",
		"icon": "res://Assets/ui/icons/clock.png",
		"tagline": "-35% Tambayan Linger · +25% Foot Traffic",
		"description": "Nobody sits around to chat (-35% Tambayan Linger Chance), but the street moves fast with +25% Customer Foot Traffic.",
		"description_rich": "Far fewer shoppers linger at the [b]Tambayan[/b], traded for brisk [b]Customer Foot Traffic[/b].",
		"keywords": ["tambayan", "foot_traffic"],
		"stats": [
			{"label": "Tambayan Linger Chance:", "value": "-35%", "tone": "neg"},
			{"label": "Customer Foot Traffic:", "value": "+25%", "tone": "pos"},
		],
		"hud_short": "-35% Linger · +25% Traffic",
	},
	CARD_SILENT_STORIES: {
		"id": CARD_SILENT_STORIES,
		"kind": KIND_CHILL,
		"title": "Silent Stories",
		"sigil": "☾",
		"icon": "res://Assets/ui/icons/moon-star.png",
		"tagline": "-30% Story Chance · +60% Minigame Rewards · +10% Tips",
		"description": "Neighbors keep their secrets close (-30% Story Chance), yet Minigame Rewards surge by +60% and Cash Tip Bonus rises by +10%.",
		"description_rich": "Lower [b]Story Chance[/b] today, offset by rich [b]Minigame Rewards[/b] and extra [b]Cash Tip Bonus[/b].",
		"keywords": ["story_chance", "minigame_rewards", "cash_tip_bonus"],
		"stats": [
			{"label": "Story Chance:", "value": "-30%", "tone": "neg"},
			{"label": "Minigame Rewards:", "value": "+60%", "tone": "pos"},
			{"label": "Cash Tip Bonus:", "value": "+10%", "tone": "pos"},
		],
		"hud_short": "-30% Story · +60% Minigames · +10% Tips",
	},
	CARD_SHARP_BARGAINERS: {
		"id": CARD_SHARP_BARGAINERS,
		"kind": KIND_CHILL,
		"title": "Sharp Bargainers",
		"sigil": "⚖",
		"icon": "res://Assets/ui/icons/scale.png",
		"tagline": "-1 Haggle Patience · +2 Price Tolerance",
		"description": "Shoppers have zero patience for long haggling (-1 Haggle Patience), yet they accept +2 higher Price Tolerance across all items.",
		"description_rich": "Tighter [b]Haggle[/b] patience if pushed too far, rewarded with +2 global [b]Price Tolerance[/b].",
		"keywords": ["haggle", "price_tolerance"],
		"stats": [
			{"label": "Haggle Patience:", "value": "-1", "tone": "neg"},
			{"label": "All Items Price Tolerance:", "value": "+2", "tone": "pos"},
		],
		"hud_short": "-1 Haggle Patience · +2 Tol",
	},
	CARD_LOOSE_TAB: {
		"id": CARD_LOOSE_TAB,
		"kind": KIND_CHILL,
		"title": "Loose Tab",
		"sigil": "▤",
		"icon": "res://Assets/ui/icons/book-bookmark.png",
		"tagline": "+25% Utang Requests · +30% Reputation",
		"description": "Neighbors ask to put purchases on credit more often (+25% Utang Request Chance), but every positive Neighbor Reputation gain jumps by +30%.",
		"description_rich": "More neighbors ask for [b]Utang[/b] today, rewarded with much faster [b]Neighbor Reputation[/b].",
		"keywords": ["utang", "reputation"],
		"stats": [
			{"label": "Utang Request Chance:", "value": "+25%", "tone": "neg"},
			{"label": "Neighbor Reputation:", "value": "+30%", "tone": "pos"},
		],
		"hud_short": "+25% Utang · +30% Rep",
	},
	CARD_SLOW_DIAL: {
		"id": CARD_SLOW_DIAL,
		"kind": KIND_CHILL,
		"title": "Slow Dial",
		"sigil": "≋",
		"icon": "res://Assets/ui/icons/radio-tower.png",
		"tagline": "+50% Radio Cooldown · +25% Story Chance",
		"description": "Radio broadcasts take +50% longer to tune in, yet regulars linger at the counter with +25% higher Story Chance.",
		"description_rich": "Longer [b]Radio Cooldown[/b] between broadcasts, traded for +25% [b]Story Chance[/b].",
		"keywords": ["radio_cooldown", "story_chance"],
		"stats": [
			{"label": "Radio Cooldown:", "value": "+50%", "tone": "neg"},
			{"label": "Story Chance:", "value": "+25%", "tone": "pos"},
		],
		"hud_short": "+50% Radio CD · +25% Story",
	},
	CARD_HEAVY_BAGS: {
		"id": CARD_HEAVY_BAGS,
		"kind": KIND_CHILL,
		"title": "Heavy Bags",
		"sigil": "❖",
		"icon": "res://Assets/ui/icons/backpack.png",
		"tagline": "+35% Delivery CD · +2 Bonus Stock",
		"description": "Overstuffed wholesale sacks slow Delivery Cooldown by +35%, but every delivery includes +2 free Bonus Stock items.",
		"description_rich": "Slower [b]Delivery Cooldown[/b] today, offset by +2 free [b]Bonus Stock[/b] on every trip.",
		"keywords": ["delivery_cooldown", "bonus_stock"],
		"stats": [
			{"label": "Delivery Cooldown:", "value": "+35%", "tone": "neg"},
			{"label": "Free Bonus Stock per Delivery:", "value": "+2", "tone": "pos"},
		],
		"hud_short": "+35% Delivery CD · +2 Bonus Stock",
	},
	CARD_RESTLESS_BENCH: {
		"id": CARD_RESTLESS_BENCH,
		"kind": KIND_CHILL,
		"title": "Restless Bench",
		"sigil": "≈",
		"icon": "res://Assets/ui/icons/wind.png",
		"tagline": "-25% Tambayan Linger · +30% Player XP",
		"description": "Chilly drafts clear out the bench (-25% Tambayan Linger Chance), yet brisk counter flow earns +30% more Player XP.",
		"description_rich": "Fewer neighbors linger at the [b]Tambayan[/b], rewarded with +30% faster [b]Player XP[/b].",
		"keywords": ["tambayan", "player_xp"],
		"stats": [
			{"label": "Tambayan Linger Chance:", "value": "-25%", "tone": "neg"},
			{"label": "Player XP Earned:", "value": "+30%", "tone": "pos"},
		],
		"hud_short": "-25% Linger · +30% XP",
	},
	CARD_STUBBORN_HAGGLERS: {
		"id": CARD_STUBBORN_HAGGLERS,
		"kind": KIND_CHILL,
		"title": "Stubborn Hagglers",
		"sigil": "⚔",
		"icon": "res://Assets/ui/icons/flame.png",
		"tagline": "-1 Price Tolerance · +35% Haggle · +1 Patience",
		"description": "Shoppers push back 1 step earlier (-1 Price Tolerance), yet Haggle Trigger Chance surges by +35% with +1 extra Haggle Patience.",
		"description_rich": "Lower [b]Price Tolerance[/b] invites more [b]Haggle[/b] duels — with +1 extra Patience to win them.",
		"keywords": ["price_tolerance", "haggle"],
		"stats": [
			{"label": "All Items Price Tolerance:", "value": "-1", "tone": "neg"},
			{"label": "Haggle Trigger Chance:", "value": "+35%", "tone": "pos"},
			{"label": "Haggle Patience:", "value": "+1", "tone": "pos"},
		],
		"hud_short": "-1 Tol · +35% Haggle · +1 Patience",
	},
	CARD_THIRSTY_NIGHT: {
		"id": CARD_THIRSTY_NIGHT,
		"kind": KIND_CHILL,
		"title": "Thirsty Night",
		"sigil": "☼",
		"icon": "res://Assets/ui/icons/thermometer-sun.png",
		"tagline": "+45% Coldness Drain · +20% Cold Bonus · +20% Traffic",
		"description": "Stifling air drains Fridge Coldness +45% faster, yet chilled Drinks & Frozen sales pay +20% Cold Sale Bonus with +20% Foot Traffic.",
		"description_rich": "Faster [b]Coldness Drain[/b] tests your fridge discipline, paying off in [b]Cold Sale Bonus[/b] and [b]Foot Traffic[/b].",
		"keywords": ["coldness_drain", "cold_sale_bonus", "foot_traffic"],
		"stats": [
			{"label": "Fridge Coldness Drain:", "value": "+45%", "tone": "neg"},
			{"label": "Cold Sale Bonus:", "value": "+20%", "tone": "pos"},
			{"label": "Customer Foot Traffic:", "value": "+20%", "tone": "pos"},
		],
		"hud_short": "+45% Drain · +20% Cold Bonus · +20% Traffic",
	},
	CARD_SOUR_CHANGE: {
		"id": CARD_SOUR_CHANGE,
		"kind": KIND_CHILL,
		"title": "Sour Change",
		"sigil": "%",
		"icon": "res://Assets/ui/icons/percent.png",
		"tagline": "-1 Price Tolerance · +20% Cash Tip Bonus",
		"description": "Shoppers grumble at markups (-1 All Items Price Tolerance), yet leave a generous +20% Cash Tip Bonus whenever you price fairly.",
		"description_rich": "Stricter [b]Price Tolerance[/b] across the store, rewarded with a hefty [b]Cash Tip Bonus[/b].",
		"keywords": ["price_tolerance", "cash_tip_bonus"],
		"stats": [
			{"label": "All Items Price Tolerance:", "value": "-1", "tone": "neg"},
			{"label": "Cash Tip Bonus:", "value": "+20%", "tone": "pos"},
		],
		"hud_short": "-1 Tol · +20% Cash Tips",
	},
	CARD_SLAMMING_DRAFT: {
		"id": CARD_SLAMMING_DRAFT,
		"kind": KIND_CHILL,
		"title": "Slamming Draft",
		"sigil": "≋",
		"icon": "res://Assets/ui/icons/wind.png",
		"tagline": "20%/hr Fridge Gust · +30% XP · +10% Cold Bonus",
		"description": "A restless breeze has a 20% chance each hour (max once per half-skip) to swing your fridge open, but grants +30% Player XP and +10% Cold Sale Bonus.",
		"description_rich": "Hourly gusts try to swing your [b]Fridge[/b] open, rewarding alert keepers with [b]Player XP[/b] and [b]Cold Sale Bonus[/b].",
		"keywords": ["fridge_coldness", "player_xp", "cold_sale_bonus"],
		"stats": [
			{"label": "Hourly Fridge Gust Chance:", "value": "20%", "tone": "neg"},
			{"label": "Player XP Earned:", "value": "+30%", "tone": "pos"},
			{"label": "Cold Sale Bonus:", "value": "+10%", "tone": "pos"},
		],
		"hud_short": "20%/hr Gust · +30% XP · +10% Cold",
	},
	CARD_DUWENDE_MISCHIEF: {
		"id": CARD_DUWENDE_MISCHIEF,
		"kind": KIND_CHILL,
		"title": "Duwende Mischief",
		"sigil": "◈",
		"icon": "res://Assets/ui/icons/ghost.png",
		"tagline": "-1 Tol · -1 Haggle Patience · +2 Bonus Stock · -15% Restock",
		"description": "Playful mound spirits make shoppers touchy (-1 Price Tolerance, -1 Haggle Patience), yet bless your deliveries with +2 Bonus Stock and -15% Restock Cost.",
		"description_rich": "Stricter [b]Price Tolerance[/b] and [b]Haggle[/b] patience, offset by cheaper [b]Restock[/b] and free [b]Bonus Stock[/b].",
		"keywords": ["price_tolerance", "haggle", "bonus_stock", "restock"],
		"stats": [
			{"label": "All Items Price Tolerance:", "value": "-1", "tone": "neg"},
			{"label": "Haggle Patience:", "value": "-1", "tone": "neg"},
			{"label": "Free Bonus Stock per Delivery:", "value": "+2", "tone": "pos"},
			{"label": "Restock Cost:", "value": "-15%", "tone": "pos"},
		],
		"hud_short": "-1 Tol/-1 Pat · +2 Stock · -15% Cost",
	},
	CARD_BORROWED_HOUR: {
		"id": CARD_BORROWED_HOUR,
		"kind": KIND_CHILL,
		"title": "Borrowed Hour",
		"sigil": "◐",
		"icon": "res://Assets/ui/icons/sunset.png",
		"tagline": "Closes 7:00 PM · +30% Traffic · +20% Cash Tips",
		"description": "Dusk arrives an hour early (7:00 PM closing), but the rush packs your street with +30% Foot Traffic and +20% Cash Tip Bonus.",
		"description_rich": "Shorter [b]Store Hours[/b] (7:00 PM close), traded for surging [b]Customer Foot Traffic[/b] and [b]Cash Tip Bonus[/b].",
		"keywords": ["store_hours", "foot_traffic", "cash_tip_bonus"],
		"stats": [
			{"label": "Store Closing Time:", "value": "7:00 PM", "tone": "neg"},
			{"label": "Customer Foot Traffic:", "value": "+30%", "tone": "pos"},
			{"label": "Cash Tip Bonus:", "value": "+20%", "tone": "pos"},
		],
		"hud_short": "7:00 PM Close · +30% Traffic · +20% Tips",
	},
	CARD_BLOOD_MOON_BARGAIN: {
		"id": CARD_BLOOD_MOON_BARGAIN,
		"kind": KIND_CHILL,
		"title": "Blood Moon Bargain",
		"sigil": "♦",
		"icon": "res://Assets/ui/icons/flame.png",
		"tagline": "-2 Price Tolerance · +25% All Cash Sales · +35% XP",
		"description": "Shoppers refuse almost any markup (-2 All Items Price Tolerance), yet every Cash Sale pays a massive +25% Base Sale Bonus and +35% Player XP!",
		"description_rich": "Extreme -2 [b]Price Tolerance[/b] test — sell at base price for a huge [b]Cash Sale[/b] payout and [b]Player XP[/b].",
		"keywords": ["price_tolerance", "cash_sale", "player_xp"],
		"stats": [
			{"label": "All Items Price Tolerance:", "value": "-2", "tone": "neg"},
			{"label": "All Cash Sales Bonus:", "value": "+25%", "tone": "pos"},
			{"label": "Player XP Earned:", "value": "+35%", "tone": "pos"},
		],
		"hud_short": "-2 Tol · +25% Cash Sales · +35% XP",
	},
	CARD_PHANTOM_QUEUE: {
		"id": CARD_PHANTOM_QUEUE,
		"kind": KIND_CHILL,
		"title": "Phantom Queue",
		"sigil": "≡",
		"icon": "res://Assets/ui/icons/users.png",
		"tagline": "-1 Tol · +30% Drain · +1 Counter Slot · +25% Multi-Item",
		"description": "An uncanny crowd presses against the window: -1 Price Tolerance and +30% Coldness Drain, but +1 Counter Slot and +25% Multi-Item Order chance.",
		"description_rich": "Lower [b]Price Tolerance[/b] and faster [b]Coldness Drain[/b], traded for an extra [b]Counter Slot[/b] and bigger [b]Multi-Item Orders[/b].",
		"keywords": ["price_tolerance", "coldness_drain", "counter_slots", "multi_item_order"],
		"stats": [
			{"label": "All Items Price Tolerance:", "value": "-1", "tone": "neg"},
			{"label": "Fridge Coldness Drain:", "value": "+30%", "tone": "neg"},
			{"label": "Counter Slots:", "value": "+1", "tone": "pos"},
			{"label": "Multi-Item Order Chance:", "value": "+25%", "tone": "pos"},
		],
		"hud_short": "-1 Tol/+30% Drain · +1 Slot · +25% Multi",
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
	# Favors (10 Common / 12 Uncommon / 10 Rare)
	CARD_SILVER_TOLERANCE: 1.0,
	CARD_MOONLIGHT_TIPS: 1.0,
	CARD_GENEROUS_BASKETS: 1.0,
	CARD_UNRUSHED_HOUR: 1.0,
	CARD_WARM_WELCOME: 1.0,
	CARD_SWIFT_CHILL: 1.0,
	CARD_EXPRESS_RESTOCK: 1.0,
	CARD_BRIGHT_AWNING: 1.0,
	CARD_BARGAIN_CHORUS: 1.0,
	CARD_COINS_IN_THE_JAR: 1.0,
	CARD_FROST_OF_BIRINGAN: 0.65,
	CARD_CLEAR_ROAD: 0.65,
	CARD_SILVER_RENOWN: 0.65,
	CARD_TAMBAYAN_WARMTH: 0.65,
	CARD_ECHOES_ON_THE_DIAL: 0.65,
	CARD_CURBSIDE_GLOW: 0.65,
	CARD_HONORED_LISTA: 0.65,
	CARD_OPEN_EARS: 0.65,
	CARD_CLEAR_SIGNAL: 0.65,
	CARD_MERIENDA_BENCH: 0.65,
	CARD_TIKBALANG_SHORTCUT: 0.65,
	CARD_ALBULARYO_CHARM: 0.65,
	CARD_MOON_HOLDS_SKY: 0.35,
	CARD_SILVER_TOUCHED_BAG: 0.35,
	CARD_CROWDED_STOOP: 0.35,
	CARD_WHOLESALE_BLESSING: 0.35,
	CARD_LUCKY_WRIST: 0.35,
	CARD_SILVER_LEDGER_GRACE: 0.35,
	CARD_MOONLIT_BOUNTY: 0.35,
	CARD_GOLDEN_COUNTER: 0.35,
	CARD_SILVER_BELL_COUNTER: 0.35,
	CARD_MAYARI_FULL_MOON: 0.35,
	# Omens (10 Common / 10 Uncommon / 10 Rare)
	CARD_EERIE_MIST_RUSH: 1.0,
	CARD_RELUCTANT_CARE: 1.0,
	CARD_FADING_MEMORY: 1.0,
	CARD_TIGHT_WHOLESALE: 1.0,
	CARD_SHY_NEIGHBORS: 1.0,
	CARD_OVERDUE_LISTA: 1.0,
	CARD_LOOSE_TAB: 1.0,
	CARD_SLOW_DIAL: 1.0,
	CARD_SOUR_CHANGE: 1.0,
	CARD_SLAMMING_DRAFT: 1.0,
	CARD_DISEMBODIED_WIND: 0.65,
	CARD_FOGGY_HIGHWAY: 0.65,
	CARD_WARM_TRADE_WINDS: 0.65,
	CARD_RESTLESS_CROWD: 0.65,
	CARD_FROSTBITTEN_COILS: 0.65,
	CARD_BRISK_COUNTER: 0.65,
	CARD_HEAVY_BAGS: 0.65,
	CARD_RESTLESS_BENCH: 0.65,
	CARD_DUWENDE_MISCHIEF: 0.65,
	CARD_BORROWED_HOUR: 0.65,
	CARD_EARLY_DUSK: 0.35,
	CARD_QUIET_ECLIPSE: 0.35,
	CARD_STATIC_AIRWAVES: 0.35,
	CARD_PICKY_CRAVINGS: 0.35,
	CARD_SILENT_STORIES: 0.35,
	CARD_SHARP_BARGAINERS: 0.35,
	CARD_STUBBORN_HAGGLERS: 0.35,
	CARD_THIRSTY_NIGHT: 0.35,
	CARD_BLOOD_MOON_BARGAIN: 0.35,
	CARD_PHANTOM_QUEUE: 0.35,
}

static func get_card_rarity(card_id: String) -> String:
	var w: float = float(CARD_WEIGHTS.get(card_id, 1.0))
	if w <= 0.40:
		return "rare"
	if w <= 0.75:
		return "uncommon"
	return "common"

static func get_rarity_label(rarity: String) -> String:
	match rarity:
		"rare":
			return "Rare"
		"uncommon":
			return "Uncommon"
		_:
			return "Common"

static func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"rare":
			return Color(0.84, 0.58, 1.00, 1.0) # Celestial Amethyst
		"uncommon":
			return Color(0.38, 0.86, 0.56, 1.0) # Emerald Jade
		_:
			return Color(0.76, 0.74, 0.70, 1.0) # Warm Stone

static func _effective_card_weight(card_id: String, rarity_boost: float) -> float:
	var base_w: float = float(CARD_WEIGHTS.get(card_id, 1.0))
	if rarity_boost > 0.0 and base_w < 1.0:
		return base_w + rarity_boost
	return base_w

static func _pop_weighted_card(pool: Array[Dictionary], rarity_boost: float = 0.0) -> Dictionary:
	if pool.is_empty():
		return {}
	var total_w: float = 0.0
	for c in pool:
		total_w += _effective_card_weight(str(c.get("id", "")), rarity_boost)
	var r: float = randf() * total_w
	var acc: float = 0.0
	for i in range(pool.size()):
		acc += _effective_card_weight(str(pool[i].get("id", "")), rarity_boost)
		if r <= acc:
			var picked: Dictionary = pool[i]
			pool.remove_at(i)
			return picked
	return pool.pop_back()

## Draws 3 unique cards for the post-tally roguelike draft using rarity-weighted sampling:
## - "generous" / "cleared": 3 guaranteed Favor cards
## - "shortfall": 100% Omen normally; 75% Omen / 25% Favor with 50% Silver Favor milestone
## - "balanced": 80% Omen / 20% Favor normally; 50% Omen / 50% Favor with 50% Silver Favor milestone
## - rarity_boost (e.g. +0.20 from 66% Gilded Crescent milestone) raises Uncommon & Rare draw weights.
static func draw_three_cards(tally_tier: String, shifted_odds: bool = false, rarity_boost: float = 0.0) -> Array[Dictionary]:
	var favor_pool := get_cards_by_kind(KIND_FAVOR)
	var chill_pool := get_cards_by_kind(KIND_CHILL)

	var picked: Array[Dictionary] = []
	match tally_tier:
		"include_omens":
			for _i in range(3):
				if randf() < 0.50 and not favor_pool.is_empty():
					picked.append(_pop_weighted_card(favor_pool, rarity_boost))
				elif not chill_pool.is_empty():
					picked.append(_pop_weighted_card(chill_pool, rarity_boost))
				elif not favor_pool.is_empty():
					picked.append(_pop_weighted_card(favor_pool, rarity_boost))
		"omens_only":
			for _i in range(mini(3, chill_pool.size())):
				picked.append(_pop_weighted_card(chill_pool, rarity_boost))
		"generous", "cleared":
			for _i in range(mini(3, favor_pool.size())):
				picked.append(_pop_weighted_card(favor_pool, rarity_boost))
		"shortfall":
			if shifted_odds:
				for _i in range(3):
					if randf() < 0.25 and not favor_pool.is_empty():
						picked.append(_pop_weighted_card(favor_pool, rarity_boost))
					elif not chill_pool.is_empty():
						picked.append(_pop_weighted_card(chill_pool, rarity_boost))
			else:
				for _i in range(mini(3, chill_pool.size())):
					picked.append(_pop_weighted_card(chill_pool, rarity_boost))
		_:
			# "balanced" (sufficient): 80% Omen / 20% Favor normally, or 50% Favor / 50% Omen when shifted
			var favor_prob := 0.50 if shifted_odds else 0.20
			for _i in range(3):
				if randf() < favor_prob and not favor_pool.is_empty():
					picked.append(_pop_weighted_card(favor_pool, rarity_boost))
				elif not chill_pool.is_empty():
					picked.append(_pop_weighted_card(chill_pool, rarity_boost))
				elif not favor_pool.is_empty():
					picked.append(_pop_weighted_card(favor_pool, rarity_boost))

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
