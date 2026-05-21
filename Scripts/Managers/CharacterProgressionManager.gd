extends Node

## CharacterProgressionManager — Autoload
##
## Owns all character story-state data and progression logic that was previously
## embedded in StoryManager. Separating this responsibility makes each manager
## focused and independently testable.
##
## Responsibilities:
##   - character_story_states  (chapter per character)
##   - encountered_characters  (first-encounter tracking)
##   - customer_story_branches (Dialogic branch saves)
##   - todays_story_counts     (daily story cap)
##   - todays_focus_character_path
##   - global_story_cooldown
##   - last_story_advancer_path
##   - Story chapter advancement + cooldown logic
##   - Character unlock filtering
##   - Weighted character picking
##
## Save/Load: registered in the "persist" group; SaveManager calls get/load on us.

signal story_advanced(character_path: String, new_chapter: int)

# ---------------------------------------------------------------------------
# Persistent State
# ---------------------------------------------------------------------------

var character_story_states: Dictionary = {}
var encountered_characters: Dictionary = {}
var customer_story_branches: Dictionary = {}
var todays_story_counts: Dictionary = {}
var todays_focus_character_path: String = ""
var global_story_cooldown: int = 0
var last_story_advancer_path: String = ""

# ---------------------------------------------------------------------------
# Ready
# ---------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("persist")
	EventBus.day_started.connect(_on_day_started)
	LogManager.info("CharacterProgressionManager", "Ready.")


func _on_day_started(_day: int) -> void:
	todays_story_counts.clear()

# ---------------------------------------------------------------------------
# Chapter Accessors
# ---------------------------------------------------------------------------

## Returns the current story chapter index for a character (0-based).
func get_chapter(character_path: String) -> int:
	return character_story_states.get(character_path, 0)


## Returns the story branch index saved for a character.
func get_branch(character_path: String) -> float:
	return customer_story_branches.get(character_path, 0.0)


## Records that a character has been encountered (removes from forced-first list).
func record_encounter(character_path: String) -> void:
	if not encountered_characters.has(character_path):
		encountered_characters[character_path] = true
		LogManager.info("CharacterProgressionManager", "Encountered: %s" % character_path.get_file())


## Returns true if this character has been encountered before.
func has_encountered(character_path: String) -> bool:
	return encountered_characters.has(character_path)


## Saves the Dialogic branch value for a character.
func save_branch(character_path: String, branch_value: float) -> void:
	customer_story_branches[character_path] = branch_value
	LogManager.debug("CharacterProgressionManager", "Branch saved: %s -> %.1f" % [character_path.get_file(), branch_value])

# ---------------------------------------------------------------------------
# Story Advancement
# ---------------------------------------------------------------------------

## Processes story cooldown and optionally advances the chapter for a customer.
## Call after a customer transaction completes.
func process_story_cooldown(customer: Node, last_mayari_collection_successful: bool = true) -> void:
	if customer == null or not customer.transaction_context:
		return

	var transaction = customer.transaction_context
	if transaction.story_advanced:
		return  # Already advanced this visit

	if transaction.transaction_type == TransactionContext.Type.STORY or transaction.is_visit_story:
		var path = transaction.customer_data.resource_path

		# EXCEPTION: Reyna Mayari only advances if the collection was successful.
		if path.contains("ReynaMayari"):
			if not last_mayari_collection_successful:
				LogManager.info("CharacterProgressionManager", "Mayari collection FAILED. Chapter remains unchanged.")
				return

		var chapter = character_story_states.get(path, 0)
		character_story_states[path] = chapter + 1
		LogManager.info("CharacterProgressionManager", "STORY ADVANCE: %s | %d -> %d" % [path.get_file(), chapter, chapter + 1])

		# Track daily story count
		var current_count = todays_story_counts.get(path, 0)
		todays_story_counts[path] = current_count + 1
		LogManager.info("CharacterProgressionManager", "%s now at %d story interactions today." % [path.get_file().get_basename(), todays_story_counts[path]])

		# If the focus character reaches 3 interactions, rotate focus
		if todays_story_counts[path] >= 3 and path == todays_focus_character_path:
			LogManager.info("CharacterProgressionManager", "Focus character reached 3 interactions. Rotating focus.")
			_rotate_focus_character(_get_story_manager().available_characters, path)

		# Mark as advanced, set cooldown
		transaction.story_advanced = true
		last_story_advancer_path = path
		global_story_cooldown = randi_range(1, 3)

		story_advanced.emit(path, character_story_states.get(path, 0))
		_get_story_manager()._save_progression()
	else:
		if global_story_cooldown > 0:
			global_story_cooldown -= 1
			LogManager.debug("CharacterProgressionManager", "Generic transaction completed. Cooldown now: %d" % global_story_cooldown)


func _rotate_focus_character(all_characters: Array, current_path: String) -> void:
	var unlocked := _get_unlocked_characters_from(all_characters, _get_story_manager().current_tier, _get_story_manager().day)
	var possible := unlocked.filter(func(c): return c.resource_path != current_path)
	if possible.is_empty():
		possible = unlocked
	if not possible.is_empty():
		todays_focus_character_path = possible.pick_random().resource_path
		LogManager.info("CharacterProgressionManager", "New focus character: %s" % todays_focus_character_path.get_file().get_basename())


## Directly advances story for a character by path (used by dialogic_signal story_success).
func advance_story_direct(character_path: String) -> void:
	var chapter = character_story_states.get(character_path, 0)
	character_story_states[character_path] = chapter + 1
	LogManager.info("CharacterProgressionManager", "Direct Advance: '%s' -> Chapter %d" % [character_path.get_file(), chapter + 1])
	_get_story_manager()._save_progression()

# ---------------------------------------------------------------------------
# Character Filtering & Selection
# ---------------------------------------------------------------------------

## Returns all characters unlocked for the current tier & day.
func get_unlocked_characters(current_tier: int, current_day: int) -> Array[CustomerData]:
	return _get_unlocked_characters_from(_get_story_manager().available_characters, current_tier, current_day)


func _get_unlocked_characters_from(all_chars: Array, current_tier: int, current_day: int) -> Array[CustomerData]:
	var unlocked: Array[CustomerData] = []

	var current_quota_day: int = 1
	if is_instance_valid(_get_story_manager()._game_manager):
		current_quota_day = _get_story_manager()._game_manager.quota_day

	for c in all_chars:
		if not c:
			continue
		# Day 1 special rule: Mario is the tutorial, not a regular customer
		if current_day == 1 and c.get_clean_id() == "unclemario":
			continue
		# Reyna Mayari only appears after day 2
		if c.get_clean_id() == "reynamayari":
			if current_quota_day > 2:
				unlocked.append(c)
		elif c.unlock_tier <= current_tier:
			unlocked.append(c)

	return unlocked


## Picks a character from candidates using focus-character weighting.
## Focus character has 30% chance; others split the remaining 70%.
func pick_character_weighted(candidates: Array[CustomerData]) -> CustomerData:
	if candidates.is_empty():
		return null

	var focus_char: CustomerData = null
	for c in candidates:
		if c.resource_path == todays_focus_character_path:
			focus_char = c
			break

	if focus_char and candidates.size() > 1:
		if randf() < 0.3:
			return focus_char
		else:
			var others := candidates.filter(func(c): return c != focus_char)
			return others.pick_random()

	return candidates.pick_random()


## Returns true if the given chapter's prerequisites are met.
func is_story_chapter_available(customer: CustomerData, chapter: int) -> bool:
	if chapter >= customer.story_prerequisites.size() or customer.story_prerequisites[chapter] == null:
		return true
	return customer.story_prerequisites[chapter].is_met(_get_story_manager())

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func get_save_id() -> String:
	return "CharacterProgressionManager"


func get_save_data() -> Dictionary:
	return {
		"character_story_states": character_story_states.duplicate(),
		"customer_story_branches": customer_story_branches.duplicate(),
		"encountered_characters": encountered_characters.duplicate(),
		"todays_story_counts": todays_story_counts.duplicate(),
		"todays_focus_character_path": todays_focus_character_path,
		"global_story_cooldown": global_story_cooldown,
		"last_story_advancer_path": last_story_advancer_path,
	}


func load_save_data(data: Dictionary) -> void:
	var new_states = data.get("character_story_states", {})
	if not new_states.is_empty():
		character_story_states = new_states

	var new_branches = data.get("customer_story_branches", {})
	if not new_branches.is_empty():
		customer_story_branches = new_branches

	encountered_characters = data.get("encountered_characters", {})

	# Migration/Reliability: Anyone with story progress is also marked as encountered
	for path in character_story_states.keys():
		if path.begins_with("res://"):
			encountered_characters[path] = true

	todays_story_counts = data.get("todays_story_counts", {})
	todays_focus_character_path = data.get("todays_focus_character_path", "")
	global_story_cooldown = data.get("global_story_cooldown", 0)
	last_story_advancer_path = data.get("last_story_advancer_path", "")

	LogManager.info("CharacterProgressionManager",
		"Loaded. Characters progressed: %d, Cooldown: %d" % [character_story_states.size(), global_story_cooldown])


## Backward-compatibility: StoryManager's save_data may contain these keys.
## Call this during StoryManager.load_save_data() to migrate old saves.
func migrate_from_story_manager_save(story_data: Dictionary) -> void:
	if story_data.has("character_story_states") and character_story_states.is_empty():
		character_story_states = story_data.get("character_story_states", {})
	if story_data.has("customer_story_branches") and customer_story_branches.is_empty():
		customer_story_branches = story_data.get("customer_story_branches", {})
	if story_data.has("encountered_characters") and encountered_characters.is_empty():
		encountered_characters = story_data.get("encountered_characters", {})
	if story_data.has("global_story_cooldown"):
		global_story_cooldown = story_data["global_story_cooldown"]
	if story_data.has("last_story_advancer_path"):
		last_story_advancer_path = story_data["last_story_advancer_path"]
	if story_data.has("todays_focus_character_path"):
		todays_focus_character_path = story_data["todays_focus_character_path"]


func reset_state() -> void:
	character_story_states.clear()
	customer_story_branches.clear()
	encountered_characters.clear()
	todays_story_counts.clear()
	todays_focus_character_path = ""
	global_story_cooldown = 0
	last_story_advancer_path = ""
	LogManager.info("CharacterProgressionManager", "State reset for New Game.")

func _get_story_manager() -> Node:
	return get_node("/root/StoryManager")
