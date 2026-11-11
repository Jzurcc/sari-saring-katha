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

static func build_next_transaction(sm: Node) -> TransactionContext:
	# 1. Special Encounters (Tutorial / Kuya Kap Day 1 injection)
	var special_transaction := inject_special_customer(sm)
	if special_transaction:
		return special_transaction

	if sm.available_characters.is_empty():
		return null

	# 2. Character Selection via Progression Manager
	var selection := select_character(sm)
	var char_data: CustomerData = selection["customer"]
	var force_story: bool = selection["force_story"]

	if not char_data:
		return null

	sm._last_character_path = char_data.resource_path

	var transaction := TransactionContext.new()
	transaction.customer_data = char_data

	# 3. Build context & choose timeline
	build_transaction_context(sm, transaction, char_data, force_story)

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

	# 5. Sync to Dialogic
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

static func select_character(sm: Node) -> Dictionary:
	var char_data: CustomerData = null
	var force_story: bool = false

	var unlocked: Array[CustomerData] = CharacterProgressionManager.get_unlocked_characters(sm.current_tier, sm.day)

	# Priority 0: Forced First-Time Encounters (Ignores Cooldown)
	var new_characters := unlocked.filter(func(c: CustomerData) -> bool:
		var c_ch: int = CharacterProgressionManager.get_chapter(c.resource_path)
		var is_new_or_chapter_zero: bool = not CharacterProgressionManager.has_encountered(c.resource_path) or c_ch == 0
		var has_story: bool = c_ch < c.max_story_chapters and c.story_timeline != null
		var prereqs_met: bool = CharacterProgressionManager.is_story_chapter_available(c, c_ch)
		return is_new_or_chapter_zero and has_story and prereqs_met and not c.is_collector()
	)

	if not new_characters.is_empty():
		char_data = new_characters.pick_random()
		force_story = true
		LogManager.info("StoryManager", "FIRST ENCOUNTER: Forcing story for new character: %s" % char_data.get_clean_id())
		return {"customer": char_data, "force_story": force_story}

	# Priority 1: Cooldown is 0, check for available story chapters
	if CharacterProgressionManager.global_story_cooldown <= 0:
		var story_candidates := unlocked.filter(func(c: CustomerData) -> bool:
			if c.resource_path == CharacterProgressionManager.last_story_advancer_path:
				return false
			if c.resource_path == sm._last_character_path:
				return false
			if c.is_collector():
				return false
			var c_chapter: int = CharacterProgressionManager.get_chapter(c.resource_path)
			return c_chapter < c.max_story_chapters and c.story_timeline != null and CharacterProgressionManager.is_story_chapter_available(c, c_chapter)
		)

		if not story_candidates.is_empty():
			char_data = CharacterProgressionManager.pick_character_weighted(story_candidates)
			force_story = true
			LogManager.info("StoryManager", "Cooldown 0: Forcing chapter %d for: %s" % [CharacterProgressionManager.get_chapter(char_data.resource_path), char_data.get_clean_id()])
		else:
			# Soft-lock override
			var fallback := unlocked.filter(func(c: CustomerData) -> bool:
				if c.resource_path == sm._last_character_path:
					return false
				var c_chapter: int = CharacterProgressionManager.get_chapter(c.resource_path)
				return c_chapter < c.max_story_chapters and c.story_timeline != null and CharacterProgressionManager.is_story_chapter_available(c, c_chapter)
			)
			if not fallback.is_empty():
				char_data = fallback.pick_random()
				force_story = true
				LogManager.info("StoryManager", "Cooldown 0: Soft-lock override. Forcing story for: %s" % char_data.get_clean_id())

	# Priority 2: Generic flow if no story is forced
	if not char_data:
		var possible_chars := unlocked.filter(func(c: CustomerData) -> bool: return c.resource_path != sm._last_character_path)
		if possible_chars.is_empty():
			possible_chars = unlocked
		char_data = CharacterProgressionManager.pick_character_weighted(possible_chars)

	return {"customer": char_data, "force_story": force_story}

static func build_transaction_context(
	sm: Node,
	transaction: TransactionContext,
	data: CustomerData,
	force_story: bool = false
) -> void:
	transaction.is_riddle = false
	transaction.wants_debt = false

	var chapter: int = CharacterProgressionManager.get_chapter(data.resource_path)
	var story_pending: bool = chapter < data.max_story_chapters and data.story_timeline != null
	var is_collector: bool = data.is_collector()
	var story_available: bool = story_pending and CharacterProgressionManager.is_story_chapter_available(data, chapter)

	if (chapter == 0 or force_story) and story_available and not is_collector:
		transaction.transaction_type = TransactionContext.Type.STORY
		transaction.timeline = data.story_timeline
	elif story_available and CharacterProgressionManager.global_story_cooldown <= 0 and not is_collector:
		if randf() < 0.25:
			transaction.transaction_type = TransactionContext.Type.STORY
			transaction.timeline = data.story_timeline
		else:
			build_generic_transaction(sm, transaction, data, chapter)
	else:
		build_generic_transaction(sm, transaction, data, chapter)

	# Assign Desired Items
	if transaction.transaction_type != TransactionContext.Type.VISIT and not transaction.is_visit_story:
		var pinned_request := data.get_chapter_request(chapter)
		if pinned_request != null:
			for entry in pinned_request.items:
				var item: ItemData = entry.item if "item" in entry else entry
				var item_auto_upgrade: bool = entry.auto_upgrade if "auto_upgrade" in entry else false

				if item:
					if item_auto_upgrade or pinned_request.upgrade_all or item.tier > sm.current_tier:
						var best_in_cat := OrderItemPicker.best_for_category(item.category, sm.current_tier, item)
						item = best_in_cat if best_in_cat else OrderItemPicker.random_orderable(sm.current_tier)
					if item:
						transaction.desired_items.append(item)
		else:
			var dynamic_cat := data.get_chapter_category(chapter)
			if dynamic_cat != "":
				transaction.requested_category = dynamic_cat

			if transaction.transaction_type == TransactionContext.Type.PURCHASE and transaction.requested_category != "":
				if randf() > 0.5:
					transaction.requested_category = ""

			var target_item_count: int = OrderItemPicker.item_count_for_tier(sm.current_tier) if transaction.transaction_type == TransactionContext.Type.PURCHASE else 1

			if transaction.requested_category != "":
				var prefer_hint: bool = data.has_riddle_preference()
				var item := OrderItemPicker.any_for_category(transaction.requested_category, sm.current_tier, prefer_hint)
				if item:
					transaction.desired_items.append(item)
					transaction.best_item_name = item.item_name
				else:
					transaction.requested_category = ""

			var pool: Array[ItemData] = []
			var selection_roll := randf()
			if selection_roll < 0.6:
				var display_pool := InventoryManager.get_items_available_on_display()
				for item in display_pool:
					if OrderItemPicker.is_unlocked(item, sm.current_tier) and item.can_be_sold:
						pool.append(item)

			if selection_roll >= 0.6 or pool.is_empty():
				for item in InventoryManager.get_all_items():
					if item.tier <= sm.current_tier + 1 and item.can_be_sold:
						pool.append(item)

				if data.has_riddle_preference():
					var hint_pool := pool.filter(func(i: ItemData) -> bool: return i.item_hint != "")
					if not hint_pool.is_empty():
						pool = hint_pool

			var remaining_items: int = target_item_count - transaction.desired_items.size()
			var current_max_tiers := OrderItemPicker.max_tier_per_category(sm.current_tier)
			for _i in range(remaining_items):
				if not pool.is_empty():
					var item := OrderItemPicker.pick_weighted(pool, sm.current_tier, current_max_tiers)
					if transaction.upgrade_to_best_tier:
						var best := OrderItemPicker.best_for_category(item.category, sm.current_tier, item)
						if best:
							item = best
					transaction.desired_items.append(item)
				else:
					var fallback := OrderItemPicker.random_orderable(sm.current_tier)
					if fallback:
						transaction.desired_items.append(fallback)

			if transaction.desired_items.is_empty() and transaction.transaction_type != TransactionContext.Type.VISIT:
				var fallback := OrderItemPicker.random_orderable(sm.current_tier)
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
	var awareness_active: bool = randf() < 0.4

	# Price Sensitivity
	var any_item_at_max: bool = false
	for item in transaction.desired_items:
		if item.get_final_price() >= item.get_max_selling_price():
			any_item_at_max = true
			break
	var high_price_active: bool = any_item_at_max and randf() < 0.5

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
	elif total_stock < 10:
		stock_status = "Low"

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
	if current_debt > 0 and randf() < 0.30:
		transaction.is_repaying = true
		transaction.repayment_amount = current_debt

	# Riddle
	if not transaction.desired_items.is_empty() and transaction.transaction_type != TransactionContext.Type.VISIT:
		var main_item: ItemData = transaction.desired_items[0]
		var final_riddle_chance: float = 1.0 if transaction.customer_data.has_riddle_preference() else sm.riddle_chance
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

	var path: String = data.resource_path
	var chapter: int = CharacterProgressionManager.get_chapter(path)

	var should_play_story: bool = false
	if not sm.is_mayari_met:
		should_play_story = true
		sm.is_mayari_met = true
		LogManager.info("StoryManager", "Mayari DEBUT nightly visit.")
	elif sm.last_mayari_collection_successful and chapter < data.max_story_chapters:
		should_play_story = true
		LogManager.info("StoryManager", "Mayari STORY nightly visit (Chapter %d)." % chapter)

	if should_play_story:
		transaction.transaction_type = TransactionContext.Type.STORY
		transaction.timeline = data.story_timeline
	else:
		transaction.transaction_type = TransactionContext.Type.VISIT
		transaction.timeline = MAYARI_COLLECT_TIMELINE
		if not sm.last_mayari_collection_successful:
			LogManager.info("StoryManager", "Mayari RECOVERY nightly visit (Generic).")

	DialogicBridge.sync_transaction(transaction, chapter, 0, 0)

	sm.has_mayari_visited = true
	CharacterProgressionManager.record_encounter(path)
	return transaction
