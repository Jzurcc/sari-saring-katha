extends Node

## SaveManager — Central orchestrator for game persistence.
##
## Uses a group-based pull architecture: any node in the "persist" group
## that implements get_save_data() -> Dictionary and load_save_data(Dictionary)
## will be automatically included in save/load operations.
##
## Save triggers:
##   A) End of day (EventBus.day_ended)
##   B) Every 2 customers that leave (satisfied OR dismissed)
##   C) Tier advance (EventBus.tier_advanced)
##   E) Story chapter completed (called from StoryManager)
##   G) Manual Pause Menu button

const SAVE_PATH := "user://save_game.json"
const TMP_PATH  := "user://save_game.tmp"

## How many customer departures between auto-saves.
const CUSTOMERS_PER_SAVE := 2

signal save_started
signal save_finished

var _customer_leave_counter: int = 0
var _is_saving: bool = false

func _ready() -> void:
	# --- Save Triggers ---
	# A) End of day
	EventBus.day_ended.connect(_on_day_ended)
	# C) Tier advance
	EventBus.tier_advanced.connect(_on_tier_advanced)
	# B) Customer departures (any outcome)
	EventBus.customer_satisfied.connect(_on_customer_left)
	EventBus.customer_dismissed.connect(_on_customer_left)


# ── Trigger Handlers ──────────────────────────────────────────────────────

## Returns true only when MainGame is the active scene (GameManager is present).
## Used by auto-triggers to prevent orphan saves during Main Menu / intro scenes.
func _is_in_game() -> bool:
	return not get_tree().get_nodes_in_group("game_manager").is_empty()

func _on_day_ended(_day_number: int) -> void:
	if _is_in_game():
		force_save()

func _on_tier_advanced(_new_tier: int = 0, _source: String = "") -> void:
	if _is_in_game():
		force_save()

func _on_customer_left(_customer = null) -> void:
	if not _is_in_game():
		return
	_customer_leave_counter += 1
	if _customer_leave_counter >= CUSTOMERS_PER_SAVE:
		force_save()


# ── Public API ────────────────────────────────────────────────────────────

## Immediately saves the full game state to disk.
## Safe to call directly from PauseMenu, StoryManager, etc.
##
## MERGING: This function reads the existing save file first and overwrites 
## only the keys found in the current scene tree. This preserves data for
## nodes not Currently in the tree (like shelves when in the Main Menu).
func force_save() -> void:
	if _is_saving:
		return
	_is_saving = true
	_customer_leave_counter = 0

	save_started.emit()

	# 1. Start with existing data from disk to support merging
	var master_save := _read_from_disk()
	var new_keys := []

	# 2. Gather data from all persist-group nodes in current scene
	var persist_nodes = get_tree().get_nodes_in_group("persist")
	print("[SaveManager] Saving... Merging data from %d active 'persist' nodes." % persist_nodes.size())
	
	for node in persist_nodes:
		if node.has_method("get_save_data"):
			var sid: String
			if node.has_method("get_save_id"):
				sid = node.call("get_save_id")
			else:
				sid = node.name
			
			if sid == "":
				push_error("[SaveManager] Node '%s' (path: %s) has an empty save_id! Skipping." % [node.name, node.get_path()])
				continue
				
			master_save[sid] = node.get_save_data()
			new_keys.append(sid)
		else:
			print("  [SaveManager] Skipped (no get_save_data): ", node.name)

	# 3. Write back the combined dictionary
	var success := _write_to_disk(master_save)

	_is_saving = false
	save_finished.emit()

	if success:
		print("[SaveManager] Game saved. Updated keys: ", new_keys)
		print("[SaveManager] Total file keys: ", master_save.keys())
	else:
		push_error("[SaveManager] Save failed — disk write error!")


## Deletes the save file from disk. Used for New Game resets.
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var err = DirAccess.remove_absolute(SAVE_PATH)
		if err == OK:
			print("[SaveManager] Save file deleted successfully.")
		else:
			push_error("[SaveManager] Failed to delete save file: ", err)
	
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(TMP_PATH)


## Loads save data and distributes it to all persist-group nodes.
## Call this AFTER the scene tree is fully ready (waits 2 frames internally).
func request_load() -> void:
	# Note: Caller should ensure tree is ready before calling this.

	if not has_save():
		print("[SaveManager] No save file found. Starting fresh.")
		return

	var master_save := _read_from_disk()
	if master_save.is_empty():
		push_warning("[SaveManager] Save file was empty or corrupt. Starting fresh.")
		return

	# Distribute data to persist-group nodes
	var persist_nodes = get_tree().get_nodes_in_group("persist")
	print("[SaveManager] Loading... Found %d nodes in 'persist' group." % persist_nodes.size())
	
	for node in persist_nodes:
		if node.has_method("load_save_data"):
			var sid: String
			if node.has_method("get_save_id"):
				sid = node.call("get_save_id")
			else:
				sid = node.name
			
			if master_save.has(sid):
				print("  [SaveManager] Distributing to: ", sid)
				node.load_save_data(master_save[sid])
			else:
				print("  [SaveManager] No data found for: ", sid)

	print("[SaveManager] Game loaded successfully. Keys: ", master_save.keys())


## Returns true if a save file exists on disk.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Deletes the save file (used by "New Game").
func clear_save() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		if dir.file_exists("save_game.json"):
			dir.remove("save_game.json")
		if dir.file_exists("save_game.tmp"):
			dir.remove("save_game.tmp")
	_customer_leave_counter = 0
	print("[SaveManager] Save file cleared.")


# ── Disk I/O ──────────────────────────────────────────────────────────────

## Writes the master dictionary to disk using atomic tmp-swap.
## Returns true on success.
func _write_to_disk(data: Dictionary) -> bool:
	var json_string := JSON.stringify(data, "\t")

	# Step 1: Write to temporary file
	var file := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] Cannot open tmp file for writing: %s" % FileAccess.get_open_error())
		return false

	file.store_string(json_string)
	file.close()

	# Step 2: Atomic rename via DirAccess with relative paths
	# NOTE: DirAccess.rename_absolute() does NOT work with user:// virtual paths.
	# We must open the directory and use relative filenames instead.
	var dir := DirAccess.open("user://")
	if not dir:
		push_error("[SaveManager] Cannot open user:// directory for rename.")
		return false

	var err := dir.rename("save_game.tmp", "save_game.json")
	if err != OK:
		push_error("[SaveManager] Failed to rename tmp to save: error %d" % err)
		return false

	return true


## Reads and parses the save file from disk.
## Returns an empty Dictionary on failure.
func _read_from_disk() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[SaveManager] Cannot open save file for reading: %s" % FileAccess.get_open_error())
		return {}

	var json_string := file.get_as_text()
	file.close()

	if json_string.strip_edges().is_empty():
		push_warning("[SaveManager] Save file is empty.")
		return {}

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("[SaveManager] JSON parse failed at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return {}

	if json.data is Dictionary:
		return json.data
	else:
		push_error("[SaveManager] Save file root is not a Dictionary.")
		return {}
