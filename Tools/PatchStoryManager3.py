import sys

def replace_block(lines, start_str, end_str, new_code):
    start = -1
    for i, line in enumerate(lines):
        if line.strip().startswith(start_str):
            start = i
            break
    if start == -1: return lines
    
    end = start + 1
    while end < len(lines):
        if lines[end].strip().startswith(end_str):
            break
        end += 1
    
    new_lines = new_code.split('\n')
    return lines[:start] + new_lines + lines[end:]

def main():
    path = r'c:\Users\John Reniel\sari-saring-katha\Scripts\Managers\StoryManager.gd'
    with open(path, 'r', encoding='utf-8') as f:
        code = f.read()

    lines = code.split('\n')

    # 1. Fix _on_day_started
    new_day_started = """func _on_day_started(new_day: int) -> void:
	LogManager.info("StoryManager", "StoryManager._on_day_started(%d) CALLED" % new_day)
	day = new_day
	has_mayari_visited = false
	_first_customer_of_day = true
	LogManager.info("StoryManager", "Day %d starts." % day)
	is_customer_present = false
	wait_limit_time = -1.0
	was_paused_by_limit = false"""
    lines = replace_block(lines, "func _on_day_started(new_day: int) -> void:", "func _setup_daily_focus() -> void:", new_day_started + "\n")
    
    # Remove _setup_daily_focus
    lines = replace_block(lines, "func _setup_daily_focus() -> void:", "func advance_tier(source: String = \"Manual\") -> void:", "")

    # 2. Fix get_collection_transaction
    new_get_collection = """func get_collection_transaction() -> TransactionContext:
	if has_mayari_visited:
		return null
		
	var data = _get_character_data("res://Resources/customers/ReynaMayari.tres")
	if not data: data = _get_character_data("reynamayari")
	if not data:
		push_error("[StoryManager] Could not find Reyna Mayari data for collection!")
		return null
		
	var transaction = TransactionContext.new()
	transaction.customer_data = data
	
	var path = data.resource_path
	var chapter = CharacterProgressionManager.get_chapter(path)
	
	var should_play_story = false
	if not is_mayari_met:
		should_play_story = true
		is_mayari_met = true
		LogManager.info("StoryManager", "Mayari DEBUT nightly visit.")
	elif last_mayari_collection_successful and chapter < data.max_story_chapters:
		should_play_story = true
		LogManager.info("StoryManager", "Mayari STORY nightly visit (Chapter %d)." % chapter)
	
	if should_play_story:
		transaction.transaction_type = TransactionContext.Type.STORY
		transaction.timeline = data.story_timeline
	else:
		transaction.transaction_type = TransactionContext.Type.VISIT
		transaction.timeline = "res://Dialogue/Timelines/mayari_collect.dtl"
		if not last_mayari_collection_successful:
			LogManager.info("StoryManager", "Mayari RECOVERY nightly visit (Generic).")
	
	DialogicBridge.sync_transaction(transaction, chapter, 0, 0)
	
	has_mayari_visited = true
	CharacterProgressionManager.record_encounter(path)
	return transaction"""
    lines = replace_block(lines, "func get_collection_transaction() -> TransactionContext:", "func _on_debt_quota_met(", new_get_collection + "\n")

    # 3. Fix complete_tutorial
    new_complete_tutorial = """func complete_tutorial() -> void:
	var tutorial_path := "res://Resources/customers/UncleMario.tres"
	CharacterProgressionManager.advance_story_direct(tutorial_path)
	LogManager.info("StoryManager", "Uncle Mario tutorial marked as complete (Manually).")"""
    lines = replace_block(lines, "func complete_tutorial() -> void:", "func _get_character_data(", new_complete_tutorial + "\n")

    # 4. Fix _set_last_customer_info
    new_set_last = """func _set_last_customer_info(customer: Customer) -> void:
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
			Dialogic.VAR.set_variable("Global_LastItem", "")"""
    lines = replace_block(lines, "func _set_last_customer_info(customer: Customer) -> void:", "func _process_story_cooldown(customer) -> void:", new_set_last + "\n")

    # 5. Fix _on_dialogic_signal (story_success)
    # Since this is deep inside _on_dialogic_signal, let's just rewrite the whole _on_dialogic_signal
    new_dialogic_signal = """func _on_dialogic_signal(argument: String) -> void:
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
			push_error("[StoryManager] Direct Advance FAILED: 'story_success' signal received with no active customer and no explicit path.")"""
    lines = replace_block(lines, "func _on_dialogic_signal(argument: String) -> void:", "func refresh_desires() -> void:", new_dialogic_signal + "\n")
    
    # 6. Remove _is_story_chapter_available entirely
    lines = replace_block(lines, "func _is_story_chapter_available(", "func _get_unlocked_characters(", "")
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))
    print("Done patching.")

if __name__ == "__main__":
    main()
