class_name TransactionBuilder
extends RefCounted

## Pure pipeline helper that selects characters, builds TransactionContext instances,
## resolves timelines and desired item pools, and applies independent feature rolls
## (riddles, rumors, utang/debt, price sensitivity, and stock awareness).

const TUTORIAL_CUSTOMER_PATH := "res://Resources/customers/UncleMario.tres"
const KUYAKAP_CUSTOMER_PATH := "res://Resources/customers/KuyaKap.tres"
const ANOBA_ITEM_PATH := "res://Resources/items/snack/Anoba.tres"
const MAYARI_COLLECT_TIMELINE := "res://Dialogue/Timelines/mayari_collect.dtl"
const GENERIC_PURCHASE_TIMELINE := "res://Dialogue/Timelines/Generic/Purchase.dtl"
const GENERIC_VISIT_TIMELINE := "res://Dialogue/Timelines/Generic/Visit.dtl"

const AWARENESS_CHANCE := 0.4
const HIGH_PRICE_DESIRED_EXTREME_CHANCE := 0.70 # Desired item at effective step >= +3
const HIGH_PRICE_STORE_CHANCE := 0.65 # Any stocked store item at effective step >= +3
const REPAYMENT_CHANCE := 0.30
const DISPLAY_POOL_CHANCE := 0.60
const FAVORITE_CATEGORY_CHANCE := 0.70
const STOCKED_ITEM_BIAS := 0.60
const STORY_ROLL_CHANCE := 0.25
const LOW_STOCK_THRESHOLD := 10

static func build_next_transaction(sm: Node, exclude_paths: Array[String] = [], is_wave_joiner: bool = false) -> TransactionContext:
	# 1. Special Encounters (Tutorial / Kuya Kap Day 1 injection) — primary wave slot only
	if not is_wave_joiner:
		var special_transaction := inject_special_customer(sm)
		if special_transaction:
			return special_transaction

	if sm.available_characters.is_empty():
		return null

	# 2. Character Selection via Progression Manager
	var selection := select_character(sm, exclude_paths, is_wave_joiner)
	var char_data: CustomerData = selection["customer"]
	var force_story: bool = selection["force_story"]

	if not char_data:
		return null

	sm.last_character_path = char_data.resource_path

	var transaction := TransactionContext.new()
	transaction.customer_data = char_data

	# 3. Build context & choose timeline
	build_transaction_context(sm, transaction, char_data, force_story, not is_wave_joiner)
	if is_wave_joiner:
		# Wave joiners never drag in a second guest
		transaction.secondary_customer_data = null

	# 4. Independent Feature Rolls (Awareness, Riddle, Price, Debt)
	apply_feature_rolls(sm, transaction)

	# Track the initial count for progress UI
	transaction.original_count = transaction.desired_items.size()

	# Record first encounter
	if not CharacterProgressionManager.has_encountered(char_data.resource_path):
		CharacterProgressionManager.record_encounter(char_data.resource_path)
		sm._save_progression()

	var chapter: int = CharacterProgressionManager.get_chapter(char_data.resource_path)
	var branch_value: float = CharacterProgressionManager.get_branch(char_data.resource_path)
	var current_arc: float = float(char_data.get_arc_index(chapter) + 1)
	var is_story: bool = (transaction.transaction_type == TransactionContext.Type.STORY)
	transaction.motion_profile = char_data.pick_motion_profile(chapter, is_story)

	# 5. Sync to Dialogic only for the primary customer (joiners sync on click)
	if not is_wave_joiner:
		DialogicBridge.sync_transaction(transaction, chapter, branch_value, current_arc)

	return transaction

static func inject_special_customer(sm: Node) -> TransactionContext:
	var tutorial_chapter: int = CharacterProgressionManager.get_chapter(TUTORIAL_CUSTOMER_PATH)
	if sm.day == 1 and tutorial_chapter == 0:
		var tutorial_char_data: CustomerData = load(TUTORIAL_CUSTOMER_PATH)
		var tutorial_t := TransactionContext.new()
		tutorial_t.customer_data = tutorial_char_data
		tutorial_t.transaction_type = TransactionContext.Type.VISIT
		tutorial_t.timeline = tutorial_char_data.story_timeline
		tutorial_t.is_guided_tutorial = true
		tutorial_t.blocks_phone_call = true
		var anoba: ItemData = load(ANOBA_ITEM_PATH)
		tutorial_t.desired_items.append(anoba)
		LogManager.info("STORY", "Spawning Uncle Mario Tutorial")
		return tutorial_t

	var kuyakap_tut_path := "kuyakap_day1_spawned"
	var kuyakap_spawned: int = CharacterProgressionManager.get_chapter(kuyakap_tut_path)
	if sm.day == 1 and tutorial_chapter >= 1 and kuyakap_spawned == 0:
		var kuyakap_data: CustomerData = load(KUYAKAP_CUSTOMER_PATH)
		var kuyakap_t := TransactionContext.new()
		kuyakap_t.customer_data = kuyakap_data
		build_transaction_context(sm, kuyakap_t, kuyakap_data, true)
		CharacterProgressionManager.advance_story_direct(kuyakap_tut_path)
		CharacterProgressionManager.record_encounter(kuyakap_data.resource_path)
		LogManager.info("STORY", "Spawning Kuya Kap after Tutorial (Story Chapter 0)")
		return kuyakap_t

	return null

static func _has_available_story_chapter(c: CustomerData) -> bool:
	var chapter: int = CharacterProgressionManager.get_chapter(c.resource_path)
	return chapter < c.max_story_chapters and c.story_timeline != null and CharacterProgressionManager.is_story_chapter_available(c, chapter)

static func select_character(sm: Node, exclude_paths: Array[String] = [], is_wave_joiner: bool = false) -> Dictionary:
	if not is_wave_joiner and is_instance_valid(StoreEventManager):
		StoreEventManager.record_encounter()

	var char_data: CustomerData = null
	var force_story: bool = false

	var unlocked: Array[CustomerData] = CharacterProgressionManager.get_unlocked_characters(sm.current_tier, sm.day)
	# Collectors (Reyna Mayari) only join daytime waves once the 30% (₱450) Daylight Audience ledger milestone is unlocked.
	var allow_daytime_collector: bool = sm.is_daytime_mayari_unlocked()
	unlocked = unlocked.filter(func(c: CustomerData) -> bool:
		return c != null and (not c.is_collector() or allow_daytime_collector) and not (c.resource_path in exclude_paths)
	)
	if unlocked.is_empty():
		return {"customer": null, "force_story": false}

	# Wave joiners pick directly from unlocked neighbors for organic side bustle
	if is_wave_joiner:
		var joiner_pool := unlocked.filter(func(c: CustomerData) -> bool:
			return c.resource_path != sm.last_character_path
		)
		if joiner_pool.is_empty():
			joiner_pool = unlocked
		char_data = CharacterProgressionManager.pick_character_weighted(joiner_pool)
		return {"customer": char_data, "force_story": false}

	# Priority 0: Forced First-Time Encounters (Ignores Cooldown, avoids consecutive repeat)
	var new_characters := unlocked.filter(func(c: CustomerData) -> bool:
		var c_ch: int = CharacterProgressionManager.get_chapter(c.resource_path)
		var is_new: bool = not CharacterProgressionManager.has_encountered(c.resource_path) or c_ch == 0
		return is_new and not c.is_collector() and c.resource_path != sm.last_character_path and _has_available_story_chapter(c)
	)

	if not new_characters.is_empty():
		char_data = new_characters.pick_random()
		force_story = true
		LogManager.info("StoryManager", "FIRST ENCOUNTER: Forcing story for new character: %s" % char_data.get_clean_id())
		return {"customer": char_data, "force_story": force_story}

	# Priority 1: Cooldown is 0, check for available story chapters
	if CharacterProgressionManager.global_story_cooldown <= 0:
		var story_candidates := unlocked.filter(func(c: CustomerData) -> bool:
			if c.resource_path == CharacterProgressionManager.last_story_advancer_path or c.resource_path == sm.last_character_path or c.is_collector():
				return false
			return _has_available_story_chapter(c)
		)

		if not story_candidates.is_empty():
			char_data = CharacterProgressionManager.pick_character_weighted(story_candidates)
			force_story = true
			LogManager.info("StoryManager", "Cooldown 0: Forcing chapter %d for: %s" % [CharacterProgressionManager.get_chapter(char_data.resource_path), char_data.get_clean_id()])
		else:
			# Soft-lock override (never pull collectors into daytime story chapters)
			var fallback := unlocked.filter(func(c: CustomerData) -> bool:
				return not c.is_collector() and c.resource_path != sm.last_character_path and _has_available_story_chapter(c)
			)
			if not fallback.is_empty():
				char_data = fallback.pick_random()
				force_story = true
				LogManager.info("StoryManager", "Cooldown 0: Soft-lock override. Forcing story for: %s" % char_data.get_clean_id())

	# Priority 2: Generic flow if no story is forced
	if not char_data:
		var possible_chars := unlocked.filter(func(c: CustomerData) -> bool: return c.resource_path != sm.last_character_path)
		if possible_chars.is_empty():
			possible_chars = unlocked
		char_data = CharacterProgressionManager.pick_character_weighted(possible_chars)

	return {"customer": char_data, "force_story": force_story}

static func build_transaction_context(
	sm: Node,
	transaction: TransactionContext,
	data: CustomerData,
	force_story: bool = false,
	allow_story: bool = true
) -> void:
	transaction.is_riddle = false
	transaction.wants_debt = false

	var chapter: int = CharacterProgressionManager.get_chapter(data.resource_path)
	var story_pending: bool = chapter < data.max_story_chapters and data.story_timeline != null
	var is_collector: bool = data.is_collector()
	var story_available: bool = allow_story and story_pending and CharacterProgressionManager.is_story_chapter_available(data, chapter)

	if (chapter == 0 or force_story) and story_available and not is_collector:
		transaction.transaction_type = TransactionContext.Type.STORY
		transaction.timeline = data.story_timeline
	elif story_available and CharacterProgressionManager.global_story_cooldown <= 0 and not is_collector:
		if randf() < STORY_ROLL_CHANCE:
			transaction.transaction_type = TransactionContext.Type.STORY
			transaction.timeline = data.story_timeline
		else:
			build_generic_transaction(sm, transaction, data, chapter)
	else:
		build_generic_transaction(sm, transaction, data, chapter)

	# Assign Desired Items
	if transaction.transaction_type != TransactionContext.Type.VISIT and not transaction.is_visit_story:
		var pinned_items := data.get_chapter_pinned_items(chapter)
		if not pinned_items.is_empty():
			var upgrade_all: bool = data.get_chapter_upgrade_all_pinned(chapter)
			for entry in pinned_items:
				var item: ItemData = entry.item if entry else null
				var item_auto_upgrade: bool = entry.auto_upgrade if entry else false

				if item:
					if item_auto_upgrade or upgrade_all or item.tier > sm.current_tier:
						var best_in_cat := OrderItemPicker.best_for_category(item.category, sm.current_tier, item)
						item = best_in_cat if best_in_cat else OrderItemPicker.random_orderable(sm.current_tier)
					if item:
						transaction.desired_items.append(item)
		else:
			var chapter_preferred_cats: Array[String] = data.get_chapter_preferred_categories(chapter)
			var favorite_cats: Array[String] = data.get_favorite_categories()
			var excluded_cats: Array[String] = data.get_chapter_excluded_categories(chapter)
			var prefer_hint: bool = data.has_riddle_preference()
			var target_item_count: int = OrderItemPicker.item_count_for_tier(sm.current_tier) if transaction.transaction_type == TransactionContext.Type.PURCHASE else 1
			if transaction.transaction_type == TransactionContext.Type.PURCHASE and (sm.has_mayari_card(MayariCardRegistry.CARD_GENEROUS_BASKETS) or sm.has_mayari_card(MayariCardRegistry.CARD_PICKY_CRAVINGS)):
				target_item_count = maxi(target_item_count, randi_range(2, 3))

			# Build general store pool (always filtering out excluded categories)
			var pool: Array[ItemData] = []
			var selection_roll := randf()
			if selection_roll < DISPLAY_POOL_CHANCE:
				var display_pool := InventoryManager.get_items_available_on_display()
				for item in display_pool:
					if OrderItemPicker.is_unlocked(item, sm.current_tier) and item.can_be_sold and not (item.category in excluded_cats):
						pool.append(item)

			if selection_roll >= DISPLAY_POOL_CHANCE or pool.is_empty():
				for item in InventoryManager.get_all_items():
					if item.tier <= sm.current_tier + 1 and item.can_be_sold and not (item.category in excluded_cats):
						pool.append(item)

				if prefer_hint:
					var hint_pool := pool.filter(func(i: ItemData) -> bool: return i.item_hint != "")
					if not hint_pool.is_empty():
						pool = hint_pool

			var current_max_tiers := OrderItemPicker.max_tier_per_category(sm.current_tier)
			for _i in range(target_item_count):
				# 1. Story chapter preferred categories take precedence on story transactions
				if not chapter_preferred_cats.is_empty() and transaction.transaction_type != TransactionContext.Type.PURCHASE:
					var pref_item := OrderItemPicker.any_for_categories(chapter_preferred_cats, sm.current_tier, prefer_hint, excluded_cats)
					if pref_item:
						transaction.desired_items.append(pref_item)
						if transaction.requested_category == "":
							transaction.requested_category = pref_item.category
							transaction.best_item_name = pref_item.item_name
						continue

				# 2. Everyday purchase orders: 70% favorite categories, 60% bias toward stocked items
				var active_favs: Array[String] = favorite_cats if not favorite_cats.is_empty() else chapter_preferred_cats
				if not active_favs.is_empty() and randf() < FAVORITE_CATEGORY_CHANCE:
					var fav_item := OrderItemPicker.pick_from_categories_with_stock_bias(
						active_favs,
						sm.current_tier,
						prefer_hint,
						excluded_cats,
						STOCKED_ITEM_BIAS
					)
					if fav_item:
						transaction.desired_items.append(fav_item)
						if transaction.requested_category == "":
							transaction.requested_category = fav_item.category
							transaction.best_item_name = fav_item.item_name
						continue

				# 2.5. Storefront Featured Category promo pull (Signage and/or Poster)
				if transaction.transaction_type == TransactionContext.Type.PURCHASE:
					var featured_cats: Array[String] = sm.get_active_featured_categories()
					var eligible_feat: Array[String] = []
					for fc in featured_cats:
						if not (fc in excluded_cats):
							eligible_feat.append(fc)
					var pull_chance := 0.38 if eligible_feat.size() >= 2 else 0.25
					if not eligible_feat.is_empty() and randf() < pull_chance:
						var feat_item := OrderItemPicker.pick_from_categories_with_stock_bias(
							eligible_feat,
							sm.current_tier,
							prefer_hint,
							excluded_cats,
							0.65
						)
						if feat_item:
							transaction.desired_items.append(feat_item)
							if transaction.requested_category == "":
								transaction.requested_category = feat_item.category
								transaction.best_item_name = feat_item.item_name
							continue

				if not pool.is_empty():
					var item := OrderItemPicker.pick_weighted(pool, sm.current_tier, current_max_tiers)
					if transaction.upgrade_to_best_tier:
						var best := OrderItemPicker.best_for_category(item.category, sm.current_tier, item)
						if best and not (best.category in excluded_cats):
							item = best
					transaction.desired_items.append(item)
				else:
					var fallback := OrderItemPicker.random_orderable(sm.current_tier, excluded_cats)
					if fallback:
						transaction.desired_items.append(fallback)

			# If a purchase order picked a candy, sachet, or tier-scaled cheap item,
			# roll a chance to add +1 (45%) or +2 (20%) bonus items directly from the regular pool.
			if transaction.transaction_type == TransactionContext.Type.PURCHASE and not transaction.desired_items.is_empty():
				var triggers_bonus := false
				for picked in transaction.desired_items:
					if OrderItemPicker.is_cheap_or_small_item(picked, sm.current_tier):
						triggers_bonus = true
						break
				if triggers_bonus:
					var bonus_count := OrderItemPicker.roll_cheap_item_bonus_count()
					for _b in range(bonus_count):
						if transaction.desired_items.size() >= 4:
							break
						if not pool.is_empty():
							var bonus_item := OrderItemPicker.pick_weighted(pool, sm.current_tier, current_max_tiers)
							if bonus_item:
								transaction.desired_items.append(bonus_item)
						else:
							var bonus_fallback := OrderItemPicker.random_orderable(sm.current_tier, excluded_cats)
							if bonus_fallback:
								transaction.desired_items.append(bonus_fallback)

			if transaction.desired_items.is_empty() and transaction.transaction_type != TransactionContext.Type.VISIT:
				var fallback := OrderItemPicker.random_orderable(sm.current_tier, excluded_cats)
				if fallback:
					transaction.desired_items.append(fallback)

			if transaction.desired_items.is_empty():
				if transaction.transaction_type == TransactionContext.Type.PURCHASE:
					transaction.transaction_type = TransactionContext.Type.VISIT
					transaction.timeline = GENERIC_VISIT_TIMELINE

			for item in transaction.desired_items:
				if item.tier > sm.current_tier:
					transaction.is_next_tier_request = true
					break

static func build_generic_transaction(
	sm: Node,
	transaction: TransactionContext,
	data: CustomerData,
	chapter: int
) -> void:
	var is_purchase: bool = randf() < (1.0 - sm.visit_chance)

	if is_purchase and data.is_visit_only_until_final_chapter() and chapter < data.max_story_chapters - 1:
		is_purchase = false

	var purchase_pool := data.get_purchase_timelines(chapter)
	var visit_pool := data.get_visit_timelines(chapter)

	if is_purchase and not purchase_pool.is_empty():
		transaction.transaction_type = TransactionContext.Type.PURCHASE
		transaction.timeline = purchase_pool.pick_random()
	elif not visit_pool.is_empty():
		transaction.transaction_type = TransactionContext.Type.VISIT
		transaction.timeline = visit_pool.pick_random()
	elif is_purchase:
		transaction.transaction_type = TransactionContext.Type.PURCHASE
		transaction.timeline = GENERIC_PURCHASE_TIMELINE
	else:
		transaction.transaction_type = TransactionContext.Type.VISIT
		transaction.timeline = GENERIC_VISIT_TIMELINE

	if transaction.transaction_type == TransactionContext.Type.STORY:
		if data.is_visit_story_chapter(chapter):
			transaction.is_visit_story = true

static func apply_feature_rolls(sm: Node, transaction: TransactionContext) -> void:
	# Awareness
	var awareness_active: bool = randf() < AWARENESS_CHANCE

	# Price Sensitivity & Market Tolerance Evaluation
	# 1) Check the customer's own desired items
	var max_desired_effective_step: int = -99
	for item in transaction.desired_items:
		var tolerance: int = 0
		if is_instance_valid(StoreEventManager):
			tolerance = StoreEventManager.get_item_tolerance_offset(item)
		tolerance += sm.get_mayari_tolerance_offset()
		var effective_step: int = item.current_step - tolerance
		if effective_step > max_desired_effective_step:
			max_desired_effective_step = effective_step

	# 2) Check general store-wide stocked prices for extreme markups (>= +3)
	var has_store_extreme: bool = false
	for item in InventoryManager.get_all_items():
		if not item or not item.can_be_sold or InventoryManager.get_total_item_stock(item) <= 0:
			continue
		var tol: int = 0
		if is_instance_valid(StoreEventManager):
			tol = StoreEventManager.get_item_tolerance_offset(item)
		tol += sm.get_mayari_tolerance_offset()
		if (item.current_step - tol) >= 3:
			has_store_extreme = true
			break

	var high_price_chance := 0.0
	if max_desired_effective_step >= 3:
		high_price_chance = HIGH_PRICE_DESIRED_EXTREME_CHANCE
	if has_store_extreme:
		high_price_chance = maxf(high_price_chance, HIGH_PRICE_STORE_CHANCE)
	var relief: float = sm.get_storefront_price_relief()
	if high_price_chance > 0.0 and relief > 0.0:
		high_price_chance = maxf(0.0, high_price_chance - relief)

	var high_price_active: bool = high_price_chance > 0.0 and (randf() < high_price_chance)

	# Stock Status
	var total_stock: int = (
		InventoryManager.get_total_owned_count(ItemData.ItemType.SHELF) +
		InventoryManager.get_total_owned_count(ItemData.ItemType.FRIDGE) +
		InventoryManager.get_total_owned_count(ItemData.ItemType.CANDY_CONTAINER) +
		InventoryManager.get_total_owned_count(ItemData.ItemType.SACHET_CONTAINER)
	)
	var stock_status := "Normal"
	if total_stock == 0:
		stock_status = "Empty"
	elif total_stock < LOW_STOCK_THRESHOLD:
		stock_status = "Low"

	transaction.awareness_active = awareness_active
	transaction.high_price_active = high_price_active
	transaction.stock_status = stock_status

	Dialogic.VAR.set_variable("Global_AwarenessActive", 1.0 if awareness_active else 0.0)
	Dialogic.VAR.set_variable("Global_HighPriceActive", 1.0 if high_price_active else 0.0)
	Dialogic.VAR.set_variable("Global_StockStatus", stock_status)

	# Rumor Mill
	var last_cust: String = str(Dialogic.VAR.get_variable("Global_LastCustomer"))
	if transaction.customer_data.can_spread_rumors() and last_cust != "" and last_cust != transaction.customer_data.character_name and randf() < sm.rumor_chance:
		transaction.rumor_active = true
		transaction.rumor_type = 1.0 if randf() < 0.5 else 0.0

	# Utang (Debt)
	if transaction.transaction_type == TransactionContext.Type.PURCHASE and transaction.customer_data.can_request_utang():
		transaction.wants_debt = true

	# Repayment
	var current_debt: float = sm.customer_debts.get(transaction.customer_data.resource_path, 0.0)
	if current_debt > 0 and randf() < REPAYMENT_CHANCE:
		transaction.is_repaying = true
		transaction.repayment_amount = current_debt

	# Riddle (strictly for characters who speak in riddles/hints, e.g. Buboy)
	if transaction.customer_data.has_riddle_preference() and not transaction.desired_items.is_empty() and transaction.transaction_type != TransactionContext.Type.VISIT:
		var main_item: ItemData = transaction.desired_items[0]
		var final_riddle_chance: float = 1.0 if transaction.customer_data.get_clean_id() == "buboy" else sm.riddle_chance
		if main_item.item_hint != "" and randf() < final_riddle_chance:
			transaction.is_riddle = true
			transaction.riddle_item = main_item
			if transaction.desired_items.size() > 1:
				transaction.desired_items.assign([main_item])

static func build_collection_transaction(sm: Node) -> TransactionContext:
	if sm.has_mayari_visited:
		return null

	var data: CustomerData = sm._get_character_data("res://Resources/customers/ReynaMayari.tres")
	if not data:
		data = sm._get_character_data("reynamayari")
	if not data:
		push_error("[StoryManager] Could not find Reyna Mayari data for collection!")
		return null

	var transaction := TransactionContext.new()
	transaction.customer_data = data
	transaction.is_nightly_collection = true

	var path: String = data.resource_path
	var chapter: int = CharacterProgressionManager.get_chapter(path)

	# Once the ledger is permanently sealed, stop nightly collections
	# (except one final visit for Chapter 9 epilogue if not yet seen).
	if sm.is_tally_cleared():
		if chapter == 8 and chapter < data.max_story_chapters:
			transaction.transaction_type = TransactionContext.Type.STORY
			transaction.is_visit_story = true
			transaction.timeline = data.story_timeline
			DialogicBridge.sync_transaction(transaction, chapter, 0, 0)
			LogManager.info("StoryManager", "Mayari EPILOGUE visit (Chapter 9: Patron of the Moon).")
			return transaction
		return null

	var should_play_story: bool = false
	if not sm.is_mayari_met:
		should_play_story = true
		LogManager.info("StoryManager", "Mayari DEBUT nightly visit.")
	elif sm.last_mayari_collection_successful and chapter < 7 and chapter < data.max_story_chapters:
		should_play_story = true
		LogManager.info("StoryManager", "Mayari STORY nightly visit (Chapter %d)." % chapter)

	if should_play_story:
		transaction.transaction_type = TransactionContext.Type.STORY
		transaction.is_visit_story = true
		transaction.timeline = data.story_timeline
	else:
		transaction.transaction_type = TransactionContext.Type.VISIT
		transaction.timeline = MAYARI_COLLECT_TIMELINE
		if not sm.last_mayari_collection_successful:
			LogManager.info("StoryManager", "Mayari RECOVERY nightly visit (Generic).")

	DialogicBridge.sync_transaction(transaction, chapter, 0, 0)

	return transaction

## Builds a fresh PURCHASE transaction for a lingering tambayan visitor (Bench Lv.3)
## who decides to step back up to the counter and buy something before heading home.
static func build_lingering_purchase_transaction(sm: Node, data: CustomerData) -> TransactionContext:
	if data == null or data.is_collector():
		return null
	var path: String = data.resource_path
	var chapter: int = CharacterProgressionManager.get_chapter(path)
	# Danilo doesn't place purchase orders before his final chapter
	if data.get_clean_id() == "danilo" and chapter < data.max_story_chapters - 1:
		return null

	var tx := TransactionContext.new()
	tx.customer_data = data
	tx.transaction_type = TransactionContext.Type.PURCHASE
	tx.timeline = data.purchase_timeline if data.purchase_timeline != null else "res://Dialogue/Timelines/Generic/Purchase.dtl"

	var favorite_cats: Array[String] = data.get_favorite_categories()
	var excluded_cats: Array[String] = data.get_chapter_excluded_categories(chapter)
	var prefer_hint: bool = data.has_riddle_preference()
	var target_item_count: int = OrderItemPicker.item_count_for_tier(sm.current_tier)
	if sm.has_mayari_card(MayariCardRegistry.CARD_GENEROUS_BASKETS) or sm.has_mayari_card(MayariCardRegistry.CARD_PICKY_CRAVINGS):
		target_item_count = maxi(target_item_count, randi_range(2, 3))

	var pool: Array[ItemData] = []
	for item in InventoryManager.get_items_available_on_display():
		if OrderItemPicker.is_unlocked(item, sm.current_tier) and item.can_be_sold and not (item.category in excluded_cats):
			pool.append(item)
	if pool.is_empty():
		for item in InventoryManager.get_all_items():
			if item.tier <= sm.current_tier and item.can_be_sold and not (item.category in excluded_cats):
				pool.append(item)

	var current_max_tiers := OrderItemPicker.max_tier_per_category(sm.current_tier)
	for _i in range(target_item_count):
		if not favorite_cats.is_empty() and randf() < FAVORITE_CATEGORY_CHANCE:
			var fav_item := OrderItemPicker.pick_from_categories_with_stock_bias(
				favorite_cats, sm.current_tier, prefer_hint, excluded_cats, STOCKED_ITEM_BIAS
			)
			if fav_item:
				tx.desired_items.append(fav_item)
				continue
		if not pool.is_empty():
			tx.desired_items.append(OrderItemPicker.pick_weighted(pool, sm.current_tier, current_max_tiers))
		else:
			var fallback := OrderItemPicker.random_orderable(sm.current_tier, excluded_cats)
			if fallback:
				tx.desired_items.append(fallback)

	if tx.desired_items.is_empty():
		return null

	tx.original_count = tx.desired_items.size()
	if data.can_request_utang():
		tx.wants_debt = true
	if prefer_hint:
		var main_item: ItemData = tx.desired_items[0]
		var final_riddle_chance: float = 1.0 if data.get_clean_id() == "buboy" else sm.riddle_chance
		if main_item.item_hint != "" and randf() < final_riddle_chance:
			tx.is_riddle = true
			tx.riddle_item = main_item
			if tx.desired_items.size() > 1:
				tx.desired_items.assign([main_item])

	sm.update_transaction_item_string(tx)
	return tx
