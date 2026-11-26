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
# Reputation (6 Ranks = 3 Story Arcs x 2 Chapters)
# ---------------------------------------------------------------------------
const MAX_REP_RANK := 6
const REP_RANK_THRESHOLDS: Array[int] = [0, 0, 35, 85, 150, 230, 330]
const REP_RANK_TITLES: Array[String] = [
	"Stranger",
	"Passerby",
	"Acquaintance",
	"Regular",
	"Neighbor",
	"Trusted Friend",
	"Confidant"
]

# ---------------------------------------------------------------------------
# Persistent State
# ---------------------------------------------------------------------------

var character_story_states: Dictionary = {}
var encountered_characters: Dictionary = {}
var customer_story_branches: Dictionary = {}
var character_reputations: Dictionary = {} # char_path -> int
var discovered_favorites: Dictionary = {}  # char_path -> Array[String]
var world_flags: Dictionary = {}           # flag_name -> Variant
var unread_journal_paths: Dictionary = {}  # char_path -> bool
var todays_rep_deltas: Dictionary = {}     # char_path -> {delta, rank, ranked_up}
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
	todays_rep_deltas.clear()

# ---------------------------------------------------------------------------
# Reputation, Discovered Favorites & World Flags
# ---------------------------------------------------------------------------

func get_rep(character_path: String) -> int:
	return int(character_reputations.get(character_path, 0))


func get_rep_rank(character_path: String) -> int:
	if not has_encountered(character_path) and get_rep(character_path) <= 0:
		return 0
	var rep := get_rep(character_path)
	var rank := 1
	for r in range(2, MAX_REP_RANK + 1):
		if rep >= REP_RANK_THRESHOLDS[r]:
			rank = r
	return rank


static func get_rep_rank_title(rank: int) -> String:
	return REP_RANK_TITLES[clampi(rank, 0, MAX_REP_RANK)]


static func get_rep_rank_perk_summary(rank: int) -> String:
	match rank:
		1: return "Profile & Origin Unlocked"
		2: return "Beliefs & Taboos Unlocked"
		3: return "+1 Fav Price Tolerance"
		4: return "Historical Roots Unlocked"
		5: return "+10% Cash Tip Bonus"
		6: return "+1 Global Price Tolerance"
		_: return "Meet this neighbor to begin"


func get_rep_rank_progress(character_path: String) -> Dictionary:
	var rank := get_rep_rank(character_path)
	var rep := get_rep(character_path)
	if rank == 0:
		return {"rank": 0, "current": 0, "needed": REP_RANK_THRESHOLDS[2], "ratio": 0.0, "is_max": false}
	if rank >= MAX_REP_RANK:
		return {"rank": MAX_REP_RANK, "current": rep, "needed": REP_RANK_THRESHOLDS[MAX_REP_RANK], "ratio": 1.0, "is_max": true}
	var lo := REP_RANK_THRESHOLDS[rank]
	var hi := REP_RANK_THRESHOLDS[rank + 1]
	var span := maxi(1, hi - lo)
	return {
		"rank": rank,
		"current": rep - lo,
		"needed": span,
		"ratio": clampf(float(rep - lo) / float(span), 0.0, 1.0),
		"is_max": false,
	}


func add_reputation(character_path: String, delta: int, reason: String = "") -> Dictionary:
	if character_path.is_empty() or delta == 0:
		return {"new_rep": get_rep(character_path), "delta": 0, "new_rank": get_rep_rank(character_path), "ranked_up": false}
	record_encounter(character_path)
	var old_rank := get_rep_rank(character_path)
	var old_rep := get_rep(character_path)
	var new_rep := maxi(0, old_rep + delta)
	character_reputations[character_path] = new_rep
	var new_rank := get_rep_rank(character_path)
	var ranked_up := new_rank > old_rank
	if ranked_up:
		unread_journal_paths[character_path] = true

	var day_entry: Dictionary = todays_rep_deltas.get(character_path, {"delta": 0, "rank": new_rank, "ranked_up": false})
	day_entry["delta"] = int(day_entry.get("delta", 0)) + delta
	day_entry["rank"] = new_rank
	day_entry["ranked_up"] = bool(day_entry.get("ranked_up", false)) or ranked_up
	todays_rep_deltas[character_path] = day_entry

	LogManager.info("CharacterProgressionManager", "Rep %+d (%s) for %s -> %d (Rank %d: %s%s)" % [
		delta, reason, character_path.get_file(), new_rep, new_rank, get_rep_rank_title(new_rank),
		" RANK UP!" if ranked_up else ""
	])
	EventBus.reputation_changed.emit(character_path, new_rep, delta, new_rank, ranked_up)
	var sm := _get_story_manager()
	if sm and sm.has_method("_save_progression"):
		sm._save_progression()
	return {"new_rep": new_rep, "delta": delta, "new_rank": new_rank, "ranked_up": ranked_up}


func discover_favorite_category(character_path: String, category: String) -> bool:
	if character_path.is_empty() or category.is_empty():
		return false
	var cat := category.to_lower()
	var arr: Array = discovered_favorites.get(character_path, [])
	if cat in arr:
		return false
	arr.append(cat)
	discovered_favorites[character_path] = arr
	unread_journal_paths[character_path] = true
	EventBus.favorite_category_discovered.emit(character_path, cat)
	LogManager.info("CharacterProgressionManager", "Favorite discovered for %s: %s" % [character_path.get_file(), cat])
	return true


func is_favorite_discovered(character_path: String, category: String) -> bool:
	var arr: Array = discovered_favorites.get(character_path, [])
	return category.to_lower() in arr


func get_reputation_tolerance_bonus(customer_data: CustomerData, item: ItemData) -> int:
	if customer_data == null:
		return 0
	var rank := get_rep_rank(customer_data.resource_path)
	var bonus := 0
	if rank >= 3 and item and (item.category in customer_data.get_favorite_categories()):
		bonus += 1
	if rank >= 6:
		bonus += 1
	return bonus


func get_reputation_tip_bonus_pct(character_path: String) -> float:
	return 0.10 if get_rep_rank(character_path) >= 5 else 0.0


func set_world_flag(flag_name: String, value: Variant = true) -> void:
	if flag_name.is_empty():
		return
	world_flags[flag_name] = value
	EventBus.world_flag_changed.emit(flag_name, value)
	LogManager.info("CharacterProgressionManager", "World flag set: %s = %s" % [flag_name, str(value)])
	var sm := _get_story_manager()
	if sm and sm.has_method("_save_progression"):
		sm._save_progression()


func get_world_flag(flag_name: String, default_val: Variant = false) -> Variant:
	return world_flags.get(flag_name, default_val)


func mark_journal_read(character_path: String) -> void:
	unread_journal_paths.erase(character_path)


func has_unread_journal(character_path: String) -> bool:
	return bool(unread_journal_paths.get(character_path, false))


func has_any_unread_journal() -> bool:
	return not unread_journal_paths.is_empty()

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

	if transaction.transaction_type != TransactionContext.Type.STORY and not transaction.is_visit_story:
		if global_story_cooldown > 0:
			global_story_cooldown -= 1
			LogManager.debug("CharacterProgressionManager", "Generic transaction completed. Cooldown now: %d" % global_story_cooldown)
		return

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
		if c.is_collector():
			if current_quota_day > 2:
				unlocked.append(c)
		elif c.unlock_tier <= current_tier:
			unlocked.append(c)

	return unlocked


## Picks a character from candidates using focus-character and per-character spawn_weight weighting.
## Focus character has 30% chance; others split the remaining 70% proportional to spawn_weight.
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
			var others: Array[CustomerData] = []
			for c in candidates:
				if c != focus_char:
					others.append(c)
			return _pick_by_spawn_weight(others)

	return _pick_by_spawn_weight(candidates)

func _pick_by_spawn_weight(pool: Array[CustomerData]) -> CustomerData:
	if pool.is_empty():
		return null
	var sm := _get_story_manager()
	var expected: Array[String] = []
	if sm and "todays_expected_regulars" in sm:
		expected = sm.todays_expected_regulars
	var total_weight: float = 0.0
	for c in pool:
		var w := maxf(0.05, c.spawn_weight)
		if c.resource_path in expected:
			w *= 2.2
		total_weight += w
	var roll: float = randf() * total_weight
	var acc: float = 0.0
	for c in pool:
		var w := maxf(0.05, c.spawn_weight)
		if c.resource_path in expected:
			w *= 2.2
		acc += w
		if roll <= acc:
			return c
	return pool[-1]


## Returns true if the given chapter's prerequisites are met.
func is_story_chapter_available(customer: CustomerData, chapter: int) -> bool:
	var prereq := customer.get_chapter_prerequisites(chapter)
	if prereq == null:
		return true
	return prereq.is_met(_get_story_manager())

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
		"character_reputations": character_reputations.duplicate(),
		"discovered_favorites": discovered_favorites.duplicate(true),
		"world_flags": world_flags.duplicate(true),
		"unread_journal_paths": unread_journal_paths.duplicate(),
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
	character_reputations = data.get("character_reputations", {})
	discovered_favorites = data.get("discovered_favorites", {})
	world_flags = data.get("world_flags", {})
	unread_journal_paths = data.get("unread_journal_paths", {})

	# Migration/Reliability: Anyone with story progress is also marked as encountered
	for path in character_story_states.keys():
		if path.begins_with("res://"):
			encountered_characters[path] = true

	todays_story_counts = data.get("todays_story_counts", {})
	todays_focus_character_path = data.get("todays_focus_character_path", "")
	global_story_cooldown = data.get("global_story_cooldown", 0)
	last_story_advancer_path = data.get("last_story_advancer_path", "")

	LogManager.info("CharacterProgressionManager",
		"Loaded. Characters progressed: %d, Rep tracked: %d, Flags: %d" % [
			character_story_states.size(), character_reputations.size(), world_flags.size()
		])


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
	character_reputations.clear()
	discovered_favorites.clear()
	world_flags.clear()
	unread_journal_paths.clear()
	todays_rep_deltas.clear()
	todays_story_counts.clear()
	todays_focus_character_path = ""
	global_story_cooldown = 0
	last_story_advancer_path = ""
	LogManager.info("CharacterProgressionManager", "State reset for New Game.")

func _get_story_manager() -> Node:
	return get_node("/root/StoryManager")
