import sys
import re

def replace_func(lines, func_name, new_code):
    start = -1
    for i, line in enumerate(lines):
        if line.startswith(f"func {func_name}("):
            start = i
            break
    if start == -1: return lines
    end = start + 1
    while end < len(lines):
        if lines[end].startswith("func "):
            break
        end += 1
    
    new_lines = new_code.split('\n')
    return lines[:start] + new_lines + lines[end:]

def main():
    path = r'c:\Users\John Reniel\sari-saring-katha\Scripts\Managers\StoryManager.gd'
    with open(path, 'r', encoding='utf-8') as f:
        code = f.read()

    # 1. Phase 1: logging
    code = re.sub(r'print\(\s*"\[StoryManager\]\s+(.*?)"\s*\)', r'LogManager.info("StoryManager", "\1")', code)
    code = re.sub(r'print\(\s*"\[STORY\]\s+(.*?)"\s*\)', r'LogManager.info("STORY", "\1")', code)
    code = re.sub(r'print\(\s*"\[Customer\]\s+(.*?)"\s*\)', r'LogManager.info("Customer", "\1")', code)
    # Fix other bare prints
    code = re.sub(r'print\(\s*"(.*?)"\s*\)', r'LogManager.info("StoryManager", "\1")', code)

    # 2. Phase 1: save requested debounce
    old_save = """func _save_progression() -> void:
	SaveManager.force_save()"""
    new_save = """var _save_requested: bool = false

func _save_progression() -> void:
	if not _save_requested:
		_save_requested = true
		call_deferred("_flush_save")

func _flush_save() -> void:
	_save_requested = false
	SaveManager.force_save()"""
    if old_save in code:
        code = code.replace(old_save, new_save)

    # 3. Phase 1: remove unused _daily_count
    code = re.sub(r'[ \t]*var _daily_count = todays_story_counts\.get\(c\.resource_path, 0\)\n', '', code)

    # 4. Remove variables from StoryManager that moved to CharacterProgressionManager
    vars_to_remove = [
        "var todays_story_counts: Dictionary = {}",
        "var character_story_states: Dictionary = {}",
        "var customer_story_branches: Dictionary = {}",
        "var encountered_characters: Dictionary = {}",
        "var todays_focus_character_path: String = \"\"",
        "var _last_focus_character_path: String = \"\"",
        "var global_story_cooldown: int = 0",
        "var last_story_advancer_path: String = \"\""
    ]
    for v in vars_to_remove:
        code = code.replace(v + "\n", "")

    # 5. Remove Transaction_* variables
    transaction_vars = [
        "var Transaction_CustomerName: String = \"\"",
        "var Transaction_ItemWants: String = \"\"",
        "var Transaction_ItemWantsID: String = \"\"",
        "var Transaction_ItemWantsBest: String = \"\"",
        "var Transaction_HighestItemWants: String = \"\"",
        "var Transaction_ItemAnyWants: String = \"\"",
        "var Transaction_ItemHint: String = \"\"",
        "var Transaction_WantsDebt: bool = false",
        "var Transaction_IsRepaying: bool = false",
        "var Transaction_IsNextTier: bool = false",
        "var Transaction_RepaymentAmount: float = 0.0",
        "var Transaction_IsRiddle: bool = false",
        "var Transaction_CurrentArc: float = 0.0",
        "var Transaction_Chapter: float = 0.0",
        "var Transaction_Branch: float = 0.0",
        "var Transaction_DeliveredCount: float = 0.0",
        "var Transaction_RemainingCount: float = 0.0",
        "var Transaction_GreetingVar: float = 0.0",
        "var Transaction_TalkVar: float = 0.0",
        "var Transaction_SatisfyVar: float = 0.0",
        "var Transaction_WrongItemVar: float = 0.0",
        "var Transaction_VisitVar: float = 0.0"
    ]
    for v in transaction_vars:
        code = code.replace(v + "\n", "")

    lines = code.split('\n')

    # Add phase 4 methods at the bottom
    add_methods = """
func reset_to_morning() -> void:
	_current_display_time = DAY_START_HOUR
	is_clock_running = true

func is_past_closing_time() -> bool:
	return _current_display_time >= CLOSING_HOUR

func has_pending_tier_advance() -> bool:
	return _pending_tier_advance_source != ""
"""
    if "func reset_to_morning()" not in code:
        lines.extend(add_methods.split('\n'))

    new_get_next_transaction = """func get_next_transaction() -> TransactionContext:
	# 1. Special Encounters (Tutorial / Kuya Kap injection)
	var special_transaction = _inject_special_customer()
	if special_transaction: return special_transaction

	if available_characters.is_empty():
		return null

	var char_data: CustomerData = null
	var force_story = false
	
	# 2. Character Selection via Progression Manager
	var selection = _select_character()
	char_data = selection["customer"]
	force_story = selection["force_story"]

	if not char_data:
		return null

	_last_character_path = char_data.resource_path
	
	var transaction = TransactionContext.new()
	transaction.customer_data = char_data
	
	# 3. Build context & choose timeline
	_build_transaction_context(transaction, char_data, force_story)
	
	if not force_story:
		_first_customer_of_day = false
	
	# 4. Independent Feature Rolls (Awareness, Riddle, Price, Debt)
	_apply_feature_rolls(transaction)
	
	# Track the initial count for progress UI
	transaction.original_count = transaction.desired_items.size()
	
	# Record first encounter
	if not CharacterProgressionManager.has_encountered(char_data.resource_path):
		CharacterProgressionManager.record_encounter(char_data.resource_path)
		_save_progression()
		
	var chapter = CharacterProgressionManager.get_chapter(char_data.resource_path)
	var branch_value = CharacterProgressionManager.get_branch(char_data.resource_path)
	var current_arc = float(char_data.get_arc_index(chapter) + 1)
	
	# 5. Sync to Dialogic
	DialogicBridge.sync_transaction(transaction, chapter, branch_value, current_arc)
	
	return transaction

func _inject_special_customer() -> TransactionContext:
	var tutorial_path := "res://Resources/customers/UncleMario.tres"
	var tutorial_chapter = CharacterProgressionManager.get_chapter(tutorial_path)
	if day == 1 and tutorial_chapter == 0:
		var tutorial_char_data = preload("res://Resources/customers/UncleMario.tres")
		var tutorial_t = TransactionContext.new()
		tutorial_t.customer_data = tutorial_char_data
		tutorial_t.transaction_type = TransactionContext.Type.VISIT
		tutorial_t.timeline = tutorial_char_data.story_timeline
		var anoba = preload("res://Resources/items/snack/Anoba.tres")
		tutorial_t.desired_items.append(anoba)
		LogManager.info("STORY", "Spawning Uncle Mario Tutorial")
		return tutorial_t

	var kuyakap_tut_path := "kuyakap_day1_spawned"
	var kuyakap_spawned = CharacterProgressionManager.get_chapter(kuyakap_tut_path)
	if day == 1 and tutorial_chapter >= 1 and kuyakap_spawned == 0:
		var kuyakap_data = preload("res://Resources/customers/KuyaKap.tres")
		var kuyakap_t = TransactionContext.new()
		kuyakap_t.customer_data = kuyakap_data
		_build_transaction_context(kuyakap_t, kuyakap_data, true)
		CharacterProgressionManager.advance_story_direct(kuyakap_tut_path)
		CharacterProgressionManager.record_encounter(kuyakap_data.resource_path)
		_first_customer_of_day = false
		LogManager.info("STORY", "Spawning Kuya Kap after Tutorial (Story Chapter 0)")
		return kuyakap_t
		
	return null

func _select_character() -> Dictionary:
	var char_data: CustomerData = null
	var force_story = false
	
	var unlocked = CharacterProgressionManager.get_unlocked_characters(current_tier, day)
	
	# Priority 0: Forced First-Time Encounters (Ignores Cooldown)
	var new_characters = unlocked.filter(func(c): 
		var c_ch = CharacterProgressionManager.get_chapter(c.resource_path)
		return (not CharacterProgressionManager.has_encountered(c.resource_path) or c_ch == 0) \
			and c_ch < c.max_story_chapters and c.story_timeline != null \
			and CharacterProgressionManager.is_story_chapter_available(c, c_ch) \
			and c.get_clean_id() != "reynamayari"
	)
	
	if not new_characters.is_empty():
		char_data = new_characters.pick_random()
		force_story = true
		LogManager.info("StoryManager", "FIRST ENCOUNTER: Forcing story for new character: %s" % char_data.get_clean_id())
		return {"customer": char_data, "force_story": force_story}
		
	# Priority 1: Cooldown is 0, check for available story chapters
	if CharacterProgressionManager.global_story_cooldown <= 0:
		var story_candidates = unlocked.filter(func(c):
			if c.resource_path == CharacterProgressionManager.last_story_advancer_path: return false
			if c.resource_path == _last_character_path: return false
			if c.get_clean_id() == "reynamayari": return false
			var c_chapter = CharacterProgressionManager.get_chapter(c.resource_path)
			return c_chapter < c.max_story_chapters and c.story_timeline != null and CharacterProgressionManager.is_story_chapter_available(c, c_chapter)
		)
		
		if not story_candidates.is_empty():
			char_data = CharacterProgressionManager.pick_character_weighted(story_candidates)
			force_story = true
			LogManager.info("StoryManager", "Cooldown 0: Forcing chapter %d for: %s" % [CharacterProgressionManager.get_chapter(char_data.resource_path), char_data.get_clean_id()])
		else:
			# Soft Lock override
			var fallback = unlocked.filter(func(c):
				if c.resource_path == _last_character_path: return false
				var c_chapter = CharacterProgressionManager.get_chapter(c.resource_path)
				return c_chapter < c.max_story_chapters and c.story_timeline != null and CharacterProgressionManager.is_story_chapter_available(c, c_chapter)
			)
			if not fallback.is_empty():
				char_data = fallback.pick_random()
				force_story = true
				LogManager.info("StoryManager", "Cooldown 0: Soft-lock override. Forcing story for: %s" % char_data.get_clean_id())

	# Priority 2: Generic flow if no story is forced
	if not char_data:
		var possible_chars = unlocked.filter(func(c): return c.resource_path != _last_character_path)
		if possible_chars.is_empty(): possible_chars = unlocked
		char_data = CharacterProgressionManager.pick_character_weighted(possible_chars)
		
	return {"customer": char_data, "force_story": force_story}

func _apply_feature_rolls(transaction: TransactionContext) -> void:
	# Awareness
	var awareness_active = randf() < 0.4
	
	# Price Sensitivity
	var any_item_at_max = false
	for item in transaction.desired_items:
		if item.get_final_price() >= item.get_max_selling_price():
			any_item_at_max = true
			break
	var high_price_active = any_item_at_max and randf() < 0.5
	
	# Stock Status
	var total_stock = InventoryManager.get_total_owned_count(ItemData.ItemType.SHELF) + \
		InventoryManager.get_total_owned_count(ItemData.ItemType.FRIDGE) + \
		InventoryManager.get_total_owned_count(ItemData.ItemType.CANDY_CONTAINER) + \
		InventoryManager.get_total_owned_count(ItemData.ItemType.SACHET_CONTAINER)
	var stock_status = "Normal"
	if total_stock == 0: stock_status = "Empty"
	elif total_stock < 10: stock_status = "Low"
	
	Dialogic.VAR.set_variable("Global_AwarenessActive", 1.0 if awareness_active else 0.0)
	Dialogic.VAR.set_variable("Global_HighPriceActive", 1.0 if high_price_active else 0.0)
	Dialogic.VAR.set_variable("Global_StockStatus", stock_status)
	
	# Rumor Mill (Danilo)
	var last_cust = Dialogic.VAR.get_variable("Global_LastCustomer")
	if transaction.customer_data.get_clean_id() == "danilo" and last_cust != "" and last_cust != "Danilo" and randf() < rumor_chance:
		transaction.rumor_active = true
		transaction.rumor_type = 1.0 if randf() < 0.5 else 0.0
	
	# Utang (Debt) - Manang Ana only
	if transaction.transaction_type == TransactionContext.Type.PURCHASE and transaction.customer_data.resource_path.contains("ManangAna"):
		transaction.wants_debt = true
		
	# Repayment
	var current_debt = customer_debts.get(transaction.customer_data.resource_path, 0.0)
	if current_debt > 0 and randf() < 0.30:
		transaction.is_repaying = true
		transaction.repayment_amount = current_debt
		
	# Riddle (Buboy / random chance)
	if not transaction.desired_items.is_empty() and transaction.transaction_type != TransactionContext.Type.VISIT:
		var main_item = transaction.desired_items[0]
		var final_riddle_chance = 1.0 if transaction.customer_data.get_clean_id() == "buboy" else riddle_chance
		if main_item.item_hint != "" and randf() < final_riddle_chance:
			transaction.is_riddle = true
			transaction.riddle_item = main_item
			# Trim to 1 item
			if transaction.desired_items.size() > 1:
				transaction.desired_items.assign([main_item])
"""

    lines = replace_func(lines, "get_next_transaction", new_get_next_transaction)

    new_build_transaction_context = """func _build_transaction_context(transaction: TransactionContext, data: CustomerData, force_story: bool = false) -> void:
	transaction.is_riddle = false
	transaction.wants_debt = false
	
	var chapter = CharacterProgressionManager.get_chapter(data.resource_path)
	var story_pending = chapter < data.max_story_chapters and data.story_timeline != null
	var is_mayari = data.get_clean_id() == "reynamayari"
	var story_available = story_pending and CharacterProgressionManager.is_story_chapter_available(data, chapter)
	
	if (chapter == 0 or force_story) and story_available and not is_mayari:
		transaction.transaction_type = TransactionContext.Type.STORY
		transaction.timeline = data.story_timeline
	elif story_available and CharacterProgressionManager.global_story_cooldown <= 0 and not is_mayari:
		if randf() < 0.25:
			transaction.transaction_type = TransactionContext.Type.STORY
			transaction.timeline = data.story_timeline
		else:
			_build_generic_transaction(transaction, data, chapter)
	else:
		_build_generic_transaction(transaction, data, chapter)
		
	# Assign Desired Items
	if transaction.transaction_type != TransactionContext.Type.VISIT and not transaction.is_visit_story:
		var pinned_request = data.get_chapter_request(chapter)
		if pinned_request != null:
			for entry in pinned_request.items:
				var item = entry.item if "item" in entry else entry
				var item_auto_upgrade = entry.auto_upgrade if "auto_upgrade" in entry else false
				
				if item:
					if item_auto_upgrade or pinned_request.upgrade_all or item.tier > current_tier:
						var best_in_cat = get_best_item_for_category(item.category, item)
						item = best_in_cat if best_in_cat else _pick_random_orderable_item()
					if item: transaction.desired_items.append(item)
		else:
			# Dynamic category requests via CustomerData.chapter_categories
			var dynamic_cat = data.get_chapter_category(chapter)
			if dynamic_cat != "":
				transaction.requested_category = dynamic_cat

			if transaction.transaction_type == TransactionContext.Type.PURCHASE and transaction.requested_category != "":
				if randf() > 0.5: transaction.requested_category = ""
				
			var target_item_count = _get_item_count_for_tier(current_tier) if transaction.transaction_type == TransactionContext.Type.PURCHASE else 1
			
			if transaction.requested_category != "":
				var prefer_hint = (data.get_clean_id() == "buboy")
				var item = get_any_item_for_category(transaction.requested_category, prefer_hint)
				if item:
					transaction.desired_items.append(item)
					transaction.best_item_name = item.item_name
				else:
					transaction.requested_category = ""
					
			var pool: Array[ItemData] = []
			var selection_roll = randf()
			if selection_roll < 0.6:
				var display_pool = InventoryManager.get_items_available_on_display()
				for item in display_pool:
					if is_item_unlocked(item) and item.can_be_sold: pool.append(item)
			
			if selection_roll >= 0.6 or pool.is_empty():
				for item in InventoryManager.get_all_items():
					if item.tier <= current_tier + 1 and item.can_be_sold: pool.append(item)
				
				if data.get_clean_id() == "buboy":
					var hint_pool = pool.filter(func(i): return i.item_hint != "")
					if not hint_pool.is_empty(): pool = hint_pool
					
				var pool_max_tiers = _get_max_tier_per_category()
				for i in range(target_item_count - transaction.desired_items.size()):
					var picked = _pick_weighted_item(pool, pool_max_tiers)
					if picked: transaction.desired_items.append(picked)
					
			var remaining_items = target_item_count - transaction.desired_items.size()
			var current_max_tiers = _get_max_tier_per_category()
			for i in range(remaining_items):
				if not pool.is_empty():
					var item = _pick_weighted_item(pool, current_max_tiers)
					if transaction.upgrade_to_best_tier:
						var best = get_best_item_for_category(item.category, item)
						if best: item = best
					transaction.desired_items.append(item)
				else:
					var fallback = _pick_random_orderable_item()
					if fallback: transaction.desired_items.append(fallback)
					
			if transaction.desired_items.is_empty() and transaction.transaction_type != TransactionContext.Type.VISIT:
				var fallback = _pick_random_orderable_item()
				if fallback: transaction.desired_items.append(fallback)

			if transaction.desired_items.is_empty():
				if transaction.transaction_type == TransactionContext.Type.PURCHASE:
					transaction.transaction_type = TransactionContext.Type.VISIT
					transaction.timeline = "res://Dialogue/Timelines/Generic/Visit.dtl"

			for item in transaction.desired_items:
				if item.tier > current_tier:
					transaction.is_next_tier_request = true
					break
"""
    lines = replace_func(lines, "_build_transaction_context", new_build_transaction_context)

    new_build_generic_transaction = """func _build_generic_transaction(transaction: TransactionContext, data: CustomerData, chapter: int) -> void:
	var is_purchase = randf() < (1.0 - visit_chance)

	if is_purchase and data.get_clean_id() == "danilo" and chapter < data.max_story_chapters - 1:
		is_purchase = false

	var purchase_pool = data.get_purchase_timelines(chapter)
	var visit_pool = data.get_visit_timelines(chapter)
	
	if is_purchase and not purchase_pool.is_empty():
		transaction.transaction_type = TransactionContext.Type.PURCHASE
		transaction.timeline = purchase_pool.pick_random()
	elif not visit_pool.is_empty():
		transaction.transaction_type = TransactionContext.Type.VISIT
		transaction.timeline = visit_pool.pick_random()
	elif is_purchase:
		transaction.transaction_type = TransactionContext.Type.PURCHASE
		transaction.timeline = "res://Dialogue/Timelines/Generic/Purchase.dtl"
	else:
		transaction.transaction_type = TransactionContext.Type.VISIT
		transaction.timeline = "res://Dialogue/Timelines/Generic/Visit.dtl"

	if transaction.transaction_type == TransactionContext.Type.STORY:
		if data.is_visit_story_chapter(chapter):
			transaction.is_visit_story = true
"""
    lines = replace_func(lines, "_build_generic_transaction", new_build_generic_transaction)

    # 7. Modify refresh_desires, set_desire, upgrade_desires to use DialogicBridge
    lines = [l.replace("Transaction_ItemWants", "Dialogic.VAR.get_variable(\"Transaction_ItemWants\", \"\")") if "Transaction_ItemWants =" not in l else l for l in lines]
    
    # 8. Modify _process_story_cooldown to delegate
    new_process_story = """func _process_story_cooldown(customer) -> void:
	CharacterProgressionManager.process_story_cooldown(customer, last_mayari_collection_successful)"""
    lines = replace_func(lines, "_process_story_cooldown", new_process_story)

    # Remove get_save_data and load_save_data logic related to removed vars
    new_get_save_data = """func get_save_data() -> Dictionary:
	_ensure_tod_node()
	if is_instance_valid(_time_of_day_node) and _time_of_day_node.has_method("get"):
		var tod_time = _time_of_day_node.get("current_time")
		if tod_time != null: _current_display_time = tod_time
	return {
		"day": day,
		"current_tier": current_tier,
		"max_unlocked_tier": max_unlocked_tier,
		"purchase_counter": purchase_counter,
		"customer_debts": customer_debts.duplicate(),
		"pending_upgrade_tier": pending_upgrade_tier,
		"pending_upgrade_cost": pending_upgrade_cost,
		"has_mayari_visited": has_mayari_visited,
		"is_mayari_debt_active": is_mayari_debt_active,
		"is_mayari_met": is_mayari_met,
		"last_mayari_collection_successful": last_mayari_collection_successful,
		"current_display_time": _current_display_time,
		"is_clock_running": is_clock_running,
		"wait_limit_time": wait_limit_time,
		"was_paused_by_limit": was_paused_by_limit,
		"is_customer_present": is_customer_present,
		"_last_notified_tier": _last_notified_tier,
	}"""
    lines = replace_func(lines, "get_save_data", new_get_save_data)

    new_load_save_data = """func load_save_data(data: Dictionary) -> void:
	day = data.get("day", day)
	current_tier = data.get("current_tier", current_tier)
	max_unlocked_tier = data.get("max_unlocked_tier", max_unlocked_tier)
	purchase_counter = data.get("purchase_counter", purchase_counter)
	customer_debts = data.get("customer_debts", {})
	pending_upgrade_tier = data.get("pending_upgrade_tier", 0)
	pending_upgrade_cost = data.get("pending_upgrade_cost", 0.0)
	has_mayari_visited = data.get("has_mayari_visited", false)
	is_mayari_debt_active = data.get("is_mayari_debt_active", true)
	is_mayari_met = data.get("is_mayari_met", false)
	last_mayari_collection_successful = data.get("last_mayari_collection_successful", true)
	_current_display_time = data.get("current_display_time", DAY_START_HOUR)
	is_clock_running = data.get("is_clock_running", false)
	wait_limit_time = data.get("wait_limit_time", -1.0)
	was_paused_by_limit = data.get("was_paused_by_limit", false)
	is_customer_present = data.get("is_customer_present", false)
	_last_notified_tier = data.get("_last_notified_tier", 0)

	DialogicBridge.sync_global(day, current_tier, max_unlocked_tier, 1)

	_ensure_tod_node()
	if is_instance_valid(_time_of_day_node):
		_apply_display_time(_current_display_time)
		_time_of_day_node.game_time_enabled = is_clock_running
	else:
		get_tree().process_frame.connect(func():
			_ensure_tod_node()
			if is_instance_valid(_time_of_day_node):
				_apply_display_time(_current_display_time)
				_time_of_day_node.game_time_enabled = is_clock_running
		, CONNECT_ONE_SHOT)"""
    lines = replace_func(lines, "load_save_data", new_load_save_data)

    new_reset_state = """func reset_state() -> void:
	day = 1
	current_tier = 1
	max_unlocked_tier = 1
	purchase_counter = 0
	pending_upgrade_tier = 0
	pending_upgrade_cost = 0.0
	customer_debts = {}
	has_mayari_visited = false
	is_mayari_debt_active = true
	is_mayari_met = false
	last_mayari_collection_successful = true
	_current_display_time = DAY_START_HOUR
	wait_limit_time = -1.0
	was_paused_by_limit = false
	is_customer_present = false
	_last_tier_unlocked_notification = 0
	_pending_tier_advance_source = ""
	_last_notified_tier = 0
	SaveManager.delete_save()"""
    lines = replace_func(lines, "reset_state", new_reset_state)

    # Replace update_transaction_item_string with DialogicBridge.sync_item_string
    new_update_string = """func update_transaction_item_string(transaction: TransactionContext) -> void:
	DialogicBridge.sync_item_string(transaction)"""
    lines = replace_func(lines, "update_transaction_item_string", new_update_string)
    
    # Remove _get_unlocked_characters
    lines = replace_func(lines, "_get_unlocked_characters", "func _get_unlocked_characters() -> Array:\n\treturn []")
    lines = replace_func(lines, "_pick_character_weighted", "func _pick_character_weighted(candidates) -> CustomerData:\n\treturn null")

    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))

if __name__ == "__main__":
    main()
