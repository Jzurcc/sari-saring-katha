extends Node

signal pending_debts_changed

## StoryManager — manages story progression and builds customer transactions.
## The clock runs freely from DAY_START_HOUR to CLOSING_HOUR with no event slots.

const DAY_START_HOUR := 5.0
const MENU_THEME_HOUR := 16.89 ## Golden hour aesthetic for Main Menu
const CLOSING_HOUR   := 20.0  ## 8 PM — no new customers after this
const HARD_STOP_HOUR := 24.0  ## Midnight — absolute time limit
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
const TALLY_GOAL := 750.0
const TALLY_MIN_SCHEDULE: Array[float] = [40.0, 50.0, 60.0, 75.0, 90.0, 105.0, 120.0]
const TALLY_GEN_SCHEDULE: Array[float] = [65.0, 80.0, 95.0, 115.0, 135.0, 155.0, 175.0]

var tally_total_paid: float = 0.0
var tally_sufficient_nights: int = 0
var active_mayari_card: String = ""
var pending_mayari_card: String = ""
var last_tally_tier: String = "balanced"

func get_tally_remaining() -> float:
	return maxf(0.0, TALLY_GOAL - tally_total_paid)

func is_tally_cleared() -> bool:
	return (not is_mayari_debt_active) or tally_total_paid >= TALLY_GOAL - 0.01

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
	return active_mayari_card != "" and active_mayari_card == card_id

func get_mayari_tolerance_offset() -> int:
	if has_mayari_card(MayariCardRegistry.CARD_SILVER_TOLERANCE):
		return 1
	if has_mayari_card(MayariCardRegistry.CARD_EERIE_MIST_RUSH) or has_mayari_card(MayariCardRegistry.CARD_RELUCTANT_CARE):
		return -1
	return 0

func get_restock_discount_multiplier() -> float:
	if has_mayari_card(MayariCardRegistry.CARD_RELUCTANT_CARE):
		return 0.85
	if has_mayari_card(MayariCardRegistry.CARD_CLEAR_ROAD):
		return 0.90
	return 1.0

func get_effective_closing_hour() -> float:
	if has_mayari_card(MayariCardRegistry.CARD_MOON_HOLDS_SKY):
		return 22.0
	if has_mayari_card(MayariCardRegistry.CARD_EARLY_DUSK):
		return 18.5
	return CLOSING_HOUR
var customer_debts: Dictionary = {}
var pending_debts: Array[Dictionary] = [] # [{ "customer_path": String, "amount": float }]
var _save_requested: bool = false

# --- Story Progression ---
var _char_lookup: Dictionary = {}   # resource_path -> CustomerData
var _game_manager: GameManager = null

# --- Tier Progression ---
var current_tier: int = 1
var max_unlocked_tier: int = 1
var _last_tier_unlocked_notification: int = 0
var _last_notified_tier: int = 0
var purchase_counter: int = 0:
	set(value):
		purchase_counter = value
		var required = get_required_purchases_for_next_tier()
		if purchase_counter >= required:
			if max_unlocked_tier < 10:
				max_unlocked_tier += 1
				_pending_tier_advance_source = "Activity"
				_last_tier_unlocked_notification = max_unlocked_tier
			purchase_counter = 0

func get_required_purchases_for_next_tier() -> int:
	# Formula: 5 + floor(current_tier / 2) with a steeper curve for the end game
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
	{ "level": 0, "name": "Stock Refrigerator", "cost": 0.0, "drain_sec": 7.0, "regen_sec": 14.0, "desc": "Standard sari-sari fridge." },
	{ "level": 1, "name": "Magnetic Door Gasket", "cost": 75.0, "drain_sec": 14.0, "regen_sec": 11.0, "desc": "Seals cold leaks when the door swings open." },
	{ "level": 2, "name": "Heavy-Duty Insulation", "cost": 140.0, "drain_sec": 24.0, "regen_sec": 8.5, "desc": "Thick thermal lining keeps chilled stock frosty longer." },
	{ "level": 3, "name": "Inverter Frost Compressor", "cost": 230.0, "drain_sec": 36.0, "regen_sec": 6.5, "desc": "Commercial inverter cooling snaps back to ice-cold fast." },
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
	if ResourceLoader.exists("res://Assets/items/icons/2_bottle_water.png"):
		item.texture = load("res://Assets/items/icons/2_bottle_water.png")
	item.set_meta("is_fridge_upgrade", true)
	item.set_meta("fridge_level", lvl)
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
	{ "level": 0, "name": "No Store Cat", "cost": 0.0, "slots": 1, "desc": "One neighbor at the counter at a time." },
	{ "level": 1, "name": "Lucky Cat: Mingming", "cost": 85.0, "slots": 2, "desc": "Adopt Mingming the sleepy orange tabby! Unlocks a 2nd counter slot so 2 neighbors can visit at once." },
	{ "level": 2, "name": "Cat Food", "cost": 180.0, "slots": 3, "desc": "Keep Mingming happy and well-fed! Neighbors flock to see your pampered store cat — unlocks all 3 counter slots." },
]
var cat_upgrade_level: int = 0
var _cat_upgrade_item_cache: Dictionary = {}

func get_max_counter_slots() -> int:
	return clampi(1 + cat_upgrade_level, 1, 3)

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
const TRASH_CAN_COST := 45.0
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
	preload("res://Resources/customers/Rodel.tres")
]

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

func _on_day_started(new_day: int) -> void:
	LogManager.info("StoryManager", "StoryManager._on_day_started(%d) CALLED" % new_day)
	_cache_node_refs()
	day = new_day
	has_mayari_visited = false
	# Promote last night's drafted Moon Card to active for today (or clear if none)
	active_mayari_card = pending_mayari_card
	pending_mayari_card = ""
	EventBus.mayari_card_changed.emit(active_mayari_card)
	if active_mayari_card != "":
		var card := MayariCardRegistry.get_card(active_mayari_card)
		if not card.is_empty():
			var prefix := "Biringan's Favor" if MayariCardRegistry.is_favor(active_mayari_card) else "Biringan's Chill"
			LogManager.info("StoryManager", "Active Moon Card for Day %d: %s (%s)" % [day, str(card["title"]), prefix])
			call_deferred("_announce_active_mayari_card", prefix, str(card["title"]), str(card["tagline"]))
	LogManager.info("StoryManager", "Day %d starts." % day)
	clock.on_day_started()

func _announce_active_mayari_card(prefix: String, title: String, tagline: String) -> void:
	await get_tree().create_timer(1.2).timeout
	if active_mayari_card != "":
		EventBus.show_notification.emit("%s: %s" % [prefix, title], tagline, "interact")


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
	var linear_base := 80.0 + step * 20.0
	var scaled := linear_base * (1.0 + 0.05 * step)
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

func process_pending_unlock() -> void:
	if _pending_tier_advance_source == "":
		return

	# Safety Guard: Never notify for the same tier twice
	if max_unlocked_tier <= _last_notified_tier:
		LogManager.info("StoryManager", "Skip redundant notification for Tier %d" % max_unlocked_tier)
		_pending_tier_advance_source = ""
		return
		
	# Always offer the NEXT sequential upgrade for purchase
	pending_upgrade_tier = current_tier + 1
	pending_upgrade_cost = get_upgrade_cost(pending_upgrade_tier)

	# Refresh Uncle Mario's delivery cooldown so he is immediately ready
	InventoryManager.customers_needed_for_delivery = 0
	
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
		"current_tier": current_tier,
		"max_unlocked_tier": max_unlocked_tier,
		"purchase_counter": purchase_counter,
		"customer_debts": customer_debts.duplicate(),
		"pending_debts": pending_debts.duplicate(true),
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
	}
func load_save_data(data: Dictionary) -> void:
	day = data.get("day", day)
	current_tier = data.get("current_tier", current_tier)
	max_unlocked_tier = data.get("max_unlocked_tier", max_unlocked_tier)
	purchase_counter = data.get("purchase_counter", purchase_counter)
	customer_debts = data.get("customer_debts", {})
	pending_debts.clear()
	for entry in data.get("pending_debts", []):
		if entry is Dictionary and entry.has("customer_path") and float(entry.get("amount", 0.0)) > 0.0:
			pending_debts.append({
				"customer_path": str(entry["customer_path"]),
				"amount": float(entry["amount"])
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
	last_tally_tier = str(data.get("last_tally_tier", "balanced"))
	EventBus.mayari_card_changed.emit(active_mayari_card)
	_current_display_time = data.get("current_display_time", DAY_START_HOUR)
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

	# Refresh all 3D dispenser containers immediately and deferred so save loads on fresh startup
	# always update container visibility after _ready() has already run with default tier=1 state.
	if get_tree():
		get_tree().call_group("dispenser_containers", "refresh_stock")
		get_tree().call_group("store_cats", "refresh_visibility", false)
		get_tree().call_group("trash", "refresh_visibility", false)
		get_tree().process_frame.connect(func():
			if get_tree():
				get_tree().call_group("dispenser_containers", "refresh_stock")
				get_tree().call_group("store_cats", "refresh_visibility", false)
				get_tree().call_group("trash", "refresh_visibility", false)
		, CONNECT_ONE_SHOT)

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

func reset_state() -> void:
	day = 1
	current_tier = 1
	max_unlocked_tier = 1
	purchase_counter = 0
	pending_upgrade_tier = 0
	pending_upgrade_cost = 0.0
	customer_debts = {}
	pending_debts.clear()
	pending_debts_changed.emit()
	has_mayari_visited = false
	is_mayari_debt_active = true
	is_mayari_met = false
	last_mayari_collection_successful = true
	tally_total_paid = 0.0
	tally_sufficient_nights = 0
	active_mayari_card = ""
	pending_mayari_card = ""
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
	clock.reset_state()
	SaveManager.delete_save()

func get_next_transaction(exclude_paths: Array[String] = [], is_wave_joiner: bool = false) -> TransactionContext:
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
	
	# Increment purchase counter for activity-based progression
	if customer.transaction_context and customer.transaction_context.transaction_type != TransactionContext.Type.VISIT:
		purchase_counter += 1
		
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
	elif not is_visit and clock.active_time_window_hours < DayClock.CUSTOMER_TIME_WINDOW_HOURS:
		# A buyer joined a visit wave: widen the wave patience window to standard 4h
		clock.active_time_window_hours = DayClock.CUSTOMER_TIME_WINDOW_HOURS

func _on_customer_dismissed(customer: Customer) -> void:
	if customer != null and customer.is_lingering_departure:
		return
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
			LogManager.info("StoryManager", "Captured Transaction_Branch change for %s -> %s" % [customer.customer_data.character_name, str(new_val)])
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
