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

const SAVE_FILE   := "save_game.json"
const BACKUP_FILE := "save_game_backup.json"
const TMP_FILE    := "save_game.tmp"

const SAVE_PATH   := "user://" + SAVE_FILE
const BACKUP_PATH := "user://" + BACKUP_FILE
const TMP_PATH    := "user://" + TMP_FILE

## How many customer departures between auto-saves.
const CUSTOMERS_PER_SAVE := 2

signal save_started
signal save_finished

var _customer_leave_counter: int = 0
var _is_saving: bool = false

## Debug flag: If true, force_save() will return early without writing.
## Toggled via secret debug keybind (CTRL + P).
var debug_skip_save: bool = false

## System flag: Set to true when the player is returning to the Main Menu.
## Used to suppress dismissal animations in the spawner.
var is_quitting: bool = false

func _ready() -> void:
	# --- Save Triggers ---
	# A) End of day
	EventBus.day_ended.connect(_on_day_ended)
	# C) Tier advance
	EventBus.tier_advanced.connect(_on_tier_advanced)
	# B) Customer departures (any outcome)
	EventBus.customer_satisfied.connect(_on_customer_left)
	EventBus.customer_dismissed.connect(_on_customer_left)


func _notification(_what: int) -> void:
	# Saving on exit is now handled explicitly by PauseMenu (unless in debug mode).
	# Auto-save on window close removed per user request.
	pass


func _input(event: InputEvent) -> void:
	# Secret Debug Toggle: CTRL + P
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P and event.ctrl_pressed:
			debug_skip_save = !debug_skip_save
			LogManager.debug("SaveManager", "DEBUG_SKIP_SAVE: %s" % ("ON (Saves disabled)" if debug_skip_save else "OFF (Saves enabled)"))
			# Optional: Visual indicator could go here.


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
	
	if debug_skip_save:
		LogManager.info("SaveManager", "Save BLOCKED (Debug Skip Save is ON).")
		return

	_is_saving = true
	_customer_leave_counter = 0

	save_started.emit()

	# 1. Start with existing data from disk to support merging
	var master_save := _read_from_disk()
	var new_keys := []

	# 2. Add metadata
	var meta = master_save.get("_meta", {})
	meta["last_save_time"] = Time.get_datetime_string_from_system()
	meta["version"] = ProjectSettings.get_setting("application/config/version", "0.9")
	master_save["_meta"] = meta

	# 3. Gather data from all persist-group nodes in current scene
	var persist_nodes = get_tree().get_nodes_in_group("persist")
	LogManager.info("SaveManager", "Saving... Merging data from %d active 'persist' nodes." % persist_nodes.size())
	
	for node in persist_nodes:
		if node.has_method("get_save_data"):
			var sid: String
			if node.has_method("get_save_id"):
				sid = node.call("get_save_id")
			else:
				sid = node.name
			
			if sid == "":
				LogManager.error("SaveManager", "Node '%s' (path: %s) has an empty save_id! Skipping." % [node.name, node.get_path()])
				continue
			
			master_save[sid] = node.get_save_data()
			new_keys.append(sid)
		else:
			LogManager.debug("SaveManager", "Skipped (no get_save_data): %s" % node.name)

	# 4. Write back the combined dictionary
	var success := _write_to_disk(master_save)

	_is_saving = false
	save_finished.emit()

	if success:
		LogManager.info("SaveManager", "Game saved. Updated keys: %s" % str(new_keys))
		LogManager.debug("SaveManager", "Total file keys: %s" % str(master_save.keys()))
	else:
		LogManager.error("SaveManager", "Save failed — disk write error!")


## Deletes all save-related files from disk. Primarily used for New Game / Resets.
func delete_save() -> void:
	var files_to_nuke = [SAVE_PATH, BACKUP_PATH, TMP_PATH]
	
	for path in files_to_nuke:
		if FileAccess.file_exists(path):
			var err = DirAccess.remove_absolute(path)
			if err == OK:
				LogManager.info("SaveManager", "Deleted: %s" % path)
			else:
				LogManager.error("SaveManager", "Failed to delete %s: error %d" % [path, err])
	
	_customer_leave_counter = 0
	LogManager.info("SaveManager", "All save data cleared.")


## Loads save data and distributes it to all persist-group nodes.
## Call this AFTER the scene tree is fully ready (waits 2 frames internally).
func request_load() -> void:
	# Note: Caller should ensure tree is ready before calling this.

	if not has_save():
		LogManager.info("SaveManager", "No save file found. Starting fresh.")
		return

	var master_save := _read_from_disk()
	if master_save.is_empty():
		LogManager.warn("SaveManager", "Save file was empty or corrupt. Starting fresh.")
		return

	# Distribute data to persist-group nodes
	var persist_nodes = get_tree().get_nodes_in_group("persist")
	LogManager.info("SaveManager", "Loading... Found %d nodes in 'persist' group." % persist_nodes.size())
	
	for node in persist_nodes:
		if node.has_method("load_save_data"):
			var sid: String
			if node.has_method("get_save_id"):
				sid = node.call("get_save_id")
			else:
				sid = node.name
			
			if master_save.has(sid):
				LogManager.debug("SaveManager", "Distributing to: %s" % sid)
				node.load_save_data(master_save[sid])
			else:
				LogManager.debug("SaveManager", "No data found for: %s" % sid)

	LogManager.info("SaveManager", "Game loaded successfully. Keys: %s" % str(master_save.keys()))


## Returns true if a save file or backup exists on disk.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


## Alias for delete_save to maintain compatibility with legacy triggers.
func clear_save() -> void:
	delete_save()


# ── Disk I/O ──────────────────────────────────────────────────────────────

## Writes the master dictionary to disk using a strict Verified Atomic Swap pattern.
## Logic: Write TMP -> Verify TMP -> Rotate Old to Backup -> Swap TMP to Main.
func _write_to_disk(data: Dictionary) -> bool:
	var json_string := JSON.stringify(data, "\t")
	if json_string.is_empty():
		LogManager.error("SaveManager", "Serialization failed! Refusing to write empty data.")
		return false

	# Step 1: Write to temporary file
	var file := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if not file:
		LogManager.error("SaveManager", "Cannot open TMP for writing: %s (Error: %s)" % [TMP_PATH, error_string(FileAccess.get_open_error())])
		return false

	file.store_string(json_string)
	file.flush()
	file.close()

	# Step 2: VERIFICATION - Ensure the TMP file is valid before we touch the real save
	var verify_data = _attempt_read(TMP_PATH)
	if verify_data.is_empty():
		LogManager.error("SaveManager", "VERIFICATION FAILED! The written TMP file is unreadable. Aborting save swap to protect existing data.")
		return false

	# Step 3: Atomic Swap / Rotation
	var dir := DirAccess.open("user://")
	if not dir:
		LogManager.error("SaveManager", "Internal Error: Could not access user:// directory.")
		return false
	
	# a) Move current save to backup (if it exists)
	if dir.file_exists(SAVE_FILE):
		# Remove old backup first if it exists (required on some OS for rename)
		if dir.file_exists(BACKUP_FILE):
			dir.remove(BACKUP_FILE)
		
		var err_bak = dir.rename(SAVE_FILE, BACKUP_FILE)
		if err_bak != OK:
			LogManager.warn("SaveManager", "Could not rotate Main to Backup (Error: %s). Proceeding anyway..." % error_string(err_bak))

	# b) Rename TMP to Main
	var err_final = dir.rename(TMP_FILE, SAVE_FILE)
	if err_final != OK:
		LogManager.error("SaveManager", "FATAL: Failed to swap TMP to Main (Error: %s). Your save might be stuck as .tmp!" % error_string(err_final))
		return false

	return true


## Reads and parses the save file from disk.
## Automatically attempts backup recovery if the main file fails.
## Returns an empty Dictionary on failure.
func _read_from_disk() -> Dictionary:
	var data := _attempt_read(SAVE_PATH)
	if not data.is_empty():
		return data
		
	# Fallback to backup
	LogManager.info("SaveManager", "Main save failed or missing. Attempting backup recovery...")
	data = _attempt_read(BACKUP_PATH)
	if not data.is_empty():
		LogManager.info("SaveManager", "BACKUP RECOVERY SUCCESSFUL.")
		return data
		
	return {}

func _attempt_read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		LogManager.error("SaveManager", "Cannot open file at %s: %s" % [path, FileAccess.get_open_error()])
		return {}

	var json_string := file.get_as_text()
	file.close()

	if json_string.strip_edges().is_empty():
		LogManager.warn("SaveManager", "File at %s is empty." % path)
		return {}

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		LogManager.error("SaveManager", "JSON parse failed for %s: %s" % [path, json.get_error_message()])
		return {}

	if json.data is Dictionary:
		return json.data
	else:
		LogManager.error("SaveManager", "Save file root is not a Dictionary.")
		return {}
