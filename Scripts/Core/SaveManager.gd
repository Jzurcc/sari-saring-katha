extends Node

## SaveManager — Slotted persistence & smart checkpoint orchestrator.
##
## Architecture:
##   - 3 independent save slots stored in `user://saves/slot_<1..3>/`:
##       - `latest.json`   -> active progress for this slot
##       - `backups/`      -> up to MAX_BACKUPS_PER_SLOT rolling checkpoints (Start of Day, Manual Save, Milestone)
##   - `user://saves/active_slot.json` tracks the most recently played slot (1..3).
##   - Automatically migrates legacy `user://save_game.json` into Slot 1 on first boot.
##
## Smart Save Cadence (no per-XP or per-2-customer spam):
##   - Start of new Day (day > 1) -> saves latest + creates rolling "Start of Day" backup
##   - End of Day (after Mayari tally) -> saves latest (+ backup on Day 1 or Ledger Milestone)
##   - Tier Advance -> saves latest (debounced)
##   - Manual Save (Pause Menu) -> saves latest + creates "Manual Save" backup
##   - Return to Menu / Quit -> saves latest

const MAX_SLOTS := 3
const MAX_BACKUPS_PER_SLOT := 5
const MAX_MANUAL_SAVES_PER_SLOT := 10
const SAVE_ROOT_DIR := "user://saves"
const ACTIVE_SLOT_META := "user://saves/active_slot.json"

const LEGACY_SAVE_PATH := "user://save_game.json"
const LEGACY_BACKUP_PATH := "user://save_game_backup.json"
const LEGACY_TMP_PATH := "user://save_game.tmp"

const AUTO_SAVE_COOLDOWN_SEC := 12.0

signal save_started
signal save_finished
signal active_slot_changed(slot_id: int)

var active_slot: int = 1
var _pending_backup_load_path: String = ""
var _is_saving: bool = false
var _is_dirty: bool = false
var _last_auto_save_msec: int = -100000

## Debug flag: If true, force_save() will return early without writing.
## Toggled via secret debug keybind (CTRL + P).
var debug_skip_save: bool = false

## System flag: Set to true when the player is returning to the Main Menu.
## Used to suppress dismissal animations in the spawner.
var is_quitting: bool = false


func _ready() -> void:
	_ensure_save_dirs()
	_migrate_legacy_save_if_needed()
	_load_active_slot_meta()

	# --- Smart Save Checkpoints (deferred so managers finish mutating state first) ---
	EventBus.day_ended.connect(_on_day_ended, CONNECT_DEFERRED)
	EventBus.day_started.connect(_on_day_started, CONNECT_DEFERRED)
	EventBus.tier_advanced.connect(_on_tier_advanced, CONNECT_DEFERRED)


func _input(event: InputEvent) -> void:
	if OS.has_feature("editor") or OS.has_feature("debug"):
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_P and event.ctrl_pressed:
				debug_skip_save = !debug_skip_save
				LogManager.debug("SaveManager", "DEBUG_SKIP_SAVE: %s" % ("ON (Saves disabled)" if debug_skip_save else "OFF (Saves enabled)"))


# ── Slot Paths & Directory Helpers ────────────────────────────────────────

func _ensure_save_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_ROOT_DIR))
	for s in range(1, MAX_SLOTS + 1):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_get_slot_backups_dir(s)))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_get_slot_manual_dir(s)))


func _get_slot_dir(slot_id: int) -> String:
	return "%s/slot_%d" % [SAVE_ROOT_DIR, clampi(slot_id, 1, MAX_SLOTS)]


func _get_slot_latest_path(slot_id: int) -> String:
	return "%s/latest.json" % _get_slot_dir(slot_id)


func _get_slot_tmp_path(slot_id: int) -> String:
	return "%s/latest.tmp" % _get_slot_dir(slot_id)


func _get_slot_backups_dir(slot_id: int) -> String:
	return "%s/backups" % _get_slot_dir(slot_id)


func _get_slot_manual_dir(slot_id: int) -> String:
	return "%s/manual" % _get_slot_dir(slot_id)


func _migrate_legacy_save_if_needed() -> void:
	var slot1_path := _get_slot_latest_path(1)
	if FileAccess.file_exists(slot1_path):
		return
	var legacy_data := _attempt_read(LEGACY_SAVE_PATH)
	if legacy_data.is_empty():
		legacy_data = _attempt_read(LEGACY_BACKUP_PATH)
	if legacy_data.is_empty():
		return

	var meta: Dictionary = legacy_data.get("_meta", {})
	meta["slot_id"] = 1
	meta["save_label"] = str(meta.get("save_label", "Migrated Save"))
	legacy_data["_meta"] = meta
	_populate_summary_meta(legacy_data, 1, str(meta["save_label"]))

	if _write_json_atomic(slot1_path, _get_slot_tmp_path(1), legacy_data):
		_create_slot_backup(1, legacy_data, "Migrated Backup")
		active_slot = 1
		_save_active_slot_meta()
		LogManager.info("SaveManager", "Migrated legacy save_game.json into Slot 1.")


func _load_active_slot_meta() -> void:
	var data := _attempt_read(ACTIVE_SLOT_META)
	if data.has("active_slot"):
		active_slot = clampi(int(data["active_slot"]), 1, MAX_SLOTS)
	elif has_slot_save(1):
		active_slot = 1
	else:
		for s in range(1, MAX_SLOTS + 1):
			if has_slot_save(s):
				active_slot = s
				break


func _save_active_slot_meta() -> void:
	var data := {"active_slot": active_slot}
	_write_json_atomic(ACTIVE_SLOT_META, SAVE_ROOT_DIR + "/active_slot.tmp", data)


# ── Slot Selection API ────────────────────────────────────────────────────

func set_active_slot(slot_id: int) -> void:
	var clamped := clampi(slot_id, 1, MAX_SLOTS)
	active_slot = clamped
	_pending_backup_load_path = ""
	_save_active_slot_meta()
	active_slot_changed.emit(active_slot)


func get_active_slot() -> int:
	return active_slot


func set_pending_backup_load(slot_id: int, backup_path: String) -> void:
	set_active_slot(slot_id)
	_pending_backup_load_path = backup_path


func get_first_empty_slot() -> int:
	for s in range(1, MAX_SLOTS + 1):
		if not has_slot_save(s):
			return s
	return 1


## Marks live state as having unsaved changes without immediately hammering disk.
func mark_dirty() -> void:
	_is_dirty = true


# ── Smart Checkpoint Trigger Handlers ─────────────────────────────────────

func _is_in_game() -> bool:
	return not get_tree().get_nodes_in_group("game_manager").is_empty()


func _on_day_ended(day_number: int) -> void:
	if not _is_in_game():
		return
	var make_backup := (day_number == 1)
	save_checkpoint("Day %d · End of Shift" % day_number, make_backup, true)


func _on_day_started(day_number: int) -> void:
	if _is_in_game() and day_number > 1:
		save_checkpoint("Day %d · Start of Shift" % day_number, true, true)


func _on_tier_advanced(new_tier: int = 0, _source: String = "") -> void:
	if _is_in_game():
		save_checkpoint("Tier %d Unlocked" % new_tier, true, false)


# ── Public Save / Load API ────────────────────────────────────────────────

func _get_node_save_id(node: Node) -> String:
	if node.has_method("get_save_id"):
		return node.call("get_save_id")
	elif "save_id" in node:
		return node.get("save_id")
	else:
		return node.name


## Saves to the active slot.
## `create_backup`: when true, also stores a rolling backup inside `slot_N/backups/`.
## `bypass_cooldown`: set true for manual saves, quit saves, and day transitions.
func save_checkpoint(label: String = "Auto-Save", create_backup: bool = false, bypass_cooldown: bool = false) -> void:
	if _is_saving:
		return
	if debug_skip_save:
		LogManager.info("SaveManager", "Save BLOCKED (Debug Skip Save is ON).")
		return
	if not bypass_cooldown:
		var elapsed_sec := float(Time.get_ticks_msec() - _last_auto_save_msec) / 1000.0
		if elapsed_sec < AUTO_SAVE_COOLDOWN_SEC:
			_is_dirty = true
			return

	_is_saving = true
	_is_dirty = false
	_last_auto_save_msec = Time.get_ticks_msec()
	_ensure_save_dirs()

	save_started.emit()

	var latest_path := _get_slot_latest_path(active_slot)
	var tmp_path := _get_slot_tmp_path(active_slot)

	# 1. Start with existing data from this slot to support merging
	var master_save := _attempt_read(latest_path)
	var new_keys: Array[String] = []

	# 2. Flush any in-flight paid orders before gathering persist-group data
	if is_instance_valid(MarioManager) and MarioManager.has_method("flush_pending_delivery"):
		MarioManager.flush_pending_delivery()

	# 3. Gather data from all persist-group nodes in current scene
	var persist_nodes = get_tree().get_nodes_in_group("persist")
	for node in persist_nodes:
		if not node.has_method("get_save_data"):
			continue
		var sid: String = _get_node_save_id(node)
		if sid == "":
			LogManager.error("SaveManager", "Node '%s' (path: %s) has an empty save_id! Skipping." % [node.name, node.get_path()])
			continue
		master_save[sid] = node.get_save_data()
		new_keys.append(sid)

	# 4. Populate rich metadata for Load Slots UI
	_populate_summary_meta(master_save, active_slot, label)

	# 5. Atomic write to slot's latest.json
	var success := _write_json_atomic(latest_path, tmp_path, master_save)
	if success:
		_save_active_slot_meta()
		if create_backup:
			_create_slot_backup(active_slot, master_save, label)

	_is_saving = false
	save_finished.emit()

	if success:
		LogManager.info("SaveManager", "Saved Slot %d (%d systems, %s%s)." % [
			active_slot, new_keys.size(), label, ", +backup" if create_backup else ""
		])
	else:
		LogManager.error("SaveManager", "Save failed for Slot %d — disk write error!" % active_slot)


## Backward-compatible immediate save (Quit / Menu / Checkpoint).
func force_save(label: String = "Checkpoint", create_backup: bool = false) -> void:
	save_checkpoint(label, create_backup, true)


## Creates an intentional, pinned manual save inside `slot_N/manual/` that is never
## overwritten by rolling auto-backups, and also updates `latest.json`.
func create_manual_save(custom_label: String = "") -> bool:
	var day_num := StoryManager.day if is_instance_valid(StoryManager) else 1
	var label := custom_label if custom_label != "" else ("Manual Save · Day %d" % day_num)
	save_checkpoint(label, false, true)
	var data := _attempt_read(_get_slot_latest_path(active_slot))
	if data.is_empty():
		return false
	var mdir := _get_slot_manual_dir(active_slot)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(mdir))
	var ts := int(Time.get_unix_time_from_system())
	var fname := "man_%d_d%d.json" % [ts, day_num]
	var full_path := "%s/%s" % [mdir, fname]
	var tmp_path := "%s/%s.tmp" % [mdir, fname]
	var ok := _write_json_atomic(full_path, tmp_path, data)
	if ok:
		_prune_slot_manual_saves(active_slot)
		LogManager.info("SaveManager", "Created intentional manual save '%s' in Slot %d." % [fname, active_slot])
	return ok


func _prune_slot_manual_saves(slot_id: int) -> void:
	var manuals := list_slot_manual_saves(slot_id)
	if manuals.size() <= MAX_MANUAL_SAVES_PER_SLOT:
		return
	for i in range(MAX_MANUAL_SAVES_PER_SLOT, manuals.size()):
		var mpath := str(manuals[i].get("path", ""))
		if mpath != "" and FileAccess.file_exists(mpath):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(mpath))


func delete_snapshot_file(file_path: String) -> bool:
	if file_path.is_empty() or not FileAccess.file_exists(file_path):
		return false
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	return err == OK


func _populate_summary_meta(master_save: Dictionary, slot_id: int, label: String) -> void:
	var meta: Dictionary = master_save.get("_meta", {})
	meta["slot_id"] = slot_id
	meta["save_label"] = label
	meta["last_save_time"] = Time.get_datetime_string_from_system()
	meta["unix_time"] = int(Time.get_unix_time_from_system())
	meta["version"] = str(ProjectSettings.get_setting("application/config/version", "0.9"))

	var story: Dictionary = master_save.get("StoryManager", master_save.get("progression", {}))
	var mgr: Dictionary = master_save.get("manager", {})
	var cpm: Dictionary = master_save.get("CharacterProgressionManager", {})

	meta["day"] = int(story.get("day", StoryManager.day if is_instance_valid(StoryManager) else 1))
	meta["player_level"] = int(story.get("player_level", StoryManager.player_level if is_instance_valid(StoryManager) else 1))
	meta["current_tier"] = int(story.get("current_tier", StoryManager.current_tier if is_instance_valid(StoryManager) else 1))
	meta["tally_paid"] = float(story.get("tally_total_paid", StoryManager.tally_total_paid if is_instance_valid(StoryManager) else 0.0))
	meta["tally_goal"] = float(StoryManager.TALLY_GOAL if is_instance_valid(StoryManager) else 3000.0)
	meta["money"] = float(mgr.get("money", 0.0))

	var outcomes: Dictionary = cpm.get("character_outcomes", {})
	var done_arcs := 0
	for k in outcomes.keys():
		if str(outcomes[k]) != "":
			done_arcs += 1
	meta["completed_arcs"] = done_arcs
	master_save["_meta"] = meta


func _create_slot_backup(slot_id: int, data: Dictionary, label: String) -> void:
	var bdir := _get_slot_backups_dir(slot_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(bdir))

	var ts := int(Time.get_unix_time_from_system())
	var day_num := int(data.get("_meta", {}).get("day", 1))
	var safe_tag := label.to_lower().replace(" ", "_").replace("·", "").replace(":", "").replace("/", "")
	safe_tag = safe_tag.substr(0, mini(24, safe_tag.length()))
	var filename := "bak_%d_d%d_%s.json" % [ts, day_num, safe_tag]
	var full_path := "%s/%s" % [bdir, filename]
	var tmp_path := "%s/%s.tmp" % [bdir, filename]

	if _write_json_atomic(full_path, tmp_path, data):
		_prune_slot_backups(slot_id)


func _prune_slot_backups(slot_id: int) -> void:
	var backups := list_slot_backups(slot_id)
	if backups.size() <= MAX_BACKUPS_PER_SLOT:
		return
	for i in range(MAX_BACKUPS_PER_SLOT, backups.size()):
		var bpath := str(backups[i].get("path", ""))
		if bpath != "" and FileAccess.file_exists(bpath):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(bpath))


## Deletes a specific save slot, its intentional saves, and all of its backups.
func delete_slot(slot_id: int) -> void:
	var clamped := clampi(slot_id, 1, MAX_SLOTS)
	for folder in [_get_slot_backups_dir(clamped), _get_slot_manual_dir(clamped)]:
		var dir := DirAccess.open(folder)
		if dir:
			dir.list_dir_begin()
			var fname := dir.get_next()
			while fname != "":
				if not dir.current_is_dir():
					dir.remove(fname)
				fname = dir.get_next()
			dir.list_dir_end()

	for path in [_get_slot_latest_path(clamped), _get_slot_tmp_path(clamped)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	if clamped == active_slot:
		_pending_backup_load_path = ""
	LogManager.info("SaveManager", "Cleared Save Slot %d, manual saves, and all backups." % clamped)


## Deletes the currently active slot (backward-compatible with New Game / resets).
func delete_save() -> void:
	delete_slot(active_slot)


## Loads save data (either a requested backup or the active slot's latest.json) and distributes it.
func request_load() -> void:
	var master_save: Dictionary = {}
	if _pending_backup_load_path != "" and FileAccess.file_exists(_pending_backup_load_path):
		master_save = _attempt_read(_pending_backup_load_path)
		if not master_save.is_empty():
			# Promote the restored backup to be this slot's active latest.json
			_write_json_atomic(_get_slot_latest_path(active_slot), _get_slot_tmp_path(active_slot), master_save)
			LogManager.info("SaveManager", "Restored backup '%s' into Slot %d." % [_pending_backup_load_path.get_file(), active_slot])
		_pending_backup_load_path = ""

	if master_save.is_empty():
		if not has_slot_save(active_slot):
			LogManager.info("SaveManager", "No save found in Slot %d. Starting fresh." % active_slot)
			return
		master_save = _read_slot_from_disk(active_slot)

	if master_save.is_empty():
		LogManager.warn("SaveManager", "Slot %d save file was empty or corrupt. Starting fresh." % active_slot)
		return

	var persist_nodes = get_tree().get_nodes_in_group("persist")
	var root := get_tree().root
	persist_nodes.sort_custom(func(a: Node, b: Node) -> bool:
		var a_is_autoload := (a.get_parent() == root)
		var b_is_autoload := (b.get_parent() == root)
		if a_is_autoload != b_is_autoload:
			return a_is_autoload
		return false
	)
	LogManager.info("SaveManager", "Loading Slot %d... Found %d nodes in 'persist' group." % [active_slot, persist_nodes.size()])

	for node in persist_nodes:
		if node.has_method("load_save_data"):
			var sid: String = _get_node_save_id(node)
			if master_save.has(sid):
				node.load_save_data(master_save[sid])
			elif (sid == "StoryManager" or node.name == "StoryManager") and master_save.has("progression"):
				node.load_save_data(master_save["progression"])
			elif sid == "progression" and master_save.has("StoryManager"):
				node.load_save_data(master_save["StoryManager"])

	_is_dirty = false
	LogManager.info("SaveManager", "Slot %d loaded successfully." % active_slot)


# ── Query & Summary API (Used by MainMenu, LoadSlotsOverlay, TitleScreen3D) ──

func has_slot_save(slot_id: int) -> bool:
	var clamped := clampi(slot_id, 1, MAX_SLOTS)
	if FileAccess.file_exists(_get_slot_latest_path(clamped)):
		return true
	return not list_slot_backups(clamped).is_empty()


func has_any_save() -> bool:
	for s in range(1, MAX_SLOTS + 1):
		if has_slot_save(s):
			return true
	return false


## Returns true if the active slot has a save (backward-compatible with GameManager & MainMenu).
func has_save() -> bool:
	return has_slot_save(active_slot)


## Read-only peek at a slot's saved dictionary (defaults to active_slot).
func peek_save(slot_id: int = -1) -> Dictionary:
	var target := active_slot if slot_id < 1 else clampi(slot_id, 1, MAX_SLOTS)
	if not has_slot_save(target):
		return {}
	return _read_slot_from_disk(target)


## Returns a lightweight summary dictionary for rendering a Slot Card in LoadSlotsOverlay.
func get_slot_summary(slot_id: int) -> Dictionary:
	var clamped := clampi(slot_id, 1, MAX_SLOTS)
	var data := _read_slot_from_disk(clamped)
	if data.is_empty():
		return {
			"slot_id": clamped,
			"exists": false,
			"backup_count": 0,
		}
	var meta: Dictionary = data.get("_meta", {})
	var story: Dictionary = data.get("StoryManager", data.get("progression", {}))
	var mgr: Dictionary = data.get("manager", {})
	return {
		"slot_id": clamped,
		"exists": true,
		"is_active": clamped == active_slot,
		"save_label": str(meta.get("save_label", "Saved Progress")),
		"last_save_time": str(meta.get("last_save_time", "")),
		"unix_time": int(meta.get("unix_time", 0)),
		"day": int(meta.get("day", story.get("day", 1))),
		"money": float(meta.get("money", mgr.get("money", 0.0))),
		"player_level": int(meta.get("player_level", story.get("player_level", 1))),
		"current_tier": int(meta.get("current_tier", story.get("current_tier", 1))),
		"tally_paid": float(meta.get("tally_paid", story.get("tally_total_paid", 0.0))),
		"tally_goal": float(StoryManager.TALLY_GOAL if is_instance_valid(StoryManager) else 3000.0),
		"completed_arcs": int(meta.get("completed_arcs", 0)),
		"backup_count": list_slot_backups(clamped).size(),
		"manual_count": list_slot_manual_saves(clamped).size(),
	}


## Lists all intentional manual saves inside `slot_id`, sorted newest-first.
func list_slot_manual_saves(slot_id: int) -> Array[Dictionary]:
	return _list_snapshots_in_dir(_get_slot_manual_dir(clampi(slot_id, 1, MAX_SLOTS)), "Manual Save")


## Lists all rolling auto-backups inside `slot_id`, sorted newest-first.
func list_slot_backups(slot_id: int) -> Array[Dictionary]:
	return _list_snapshots_in_dir(_get_slot_backups_dir(clampi(slot_id, 1, MAX_SLOTS)), "Auto-Backup")


func _list_snapshots_in_dir(dir_path: String, fallback_label: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir := DirAccess.open(dir_path)
	if not dir:
		return result

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			var full_path := "%s/%s" % [dir_path, fname]
			var data := _attempt_read(full_path)
			if not data.is_empty():
				var meta: Dictionary = data.get("_meta", {})
				var story: Dictionary = data.get("StoryManager", data.get("progression", {}))
				var mgr: Dictionary = data.get("manager", {})
				result.append({
					"path": full_path,
					"filename": fname,
					"save_label": str(meta.get("save_label", fallback_label)),
					"last_save_time": str(meta.get("last_save_time", "")),
					"unix_time": int(meta.get("unix_time", 0)),
					"day": int(meta.get("day", story.get("day", 1))),
					"money": float(meta.get("money", mgr.get("money", 0.0))),
					"tally_paid": float(meta.get("tally_paid", story.get("tally_total_paid", 0.0))),
					"tally_goal": float(StoryManager.TALLY_GOAL if is_instance_valid(StoryManager) else 3000.0),
					"player_level": int(meta.get("player_level", story.get("player_level", 1))),
				})
		fname = dir.get_next()
	dir.list_dir_end()

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("unix_time", 0)) > int(b.get("unix_time", 0))
	)
	return result


func clear_save() -> void:
	delete_save()


## Centralizes full state reset for New Game in the currently selected active_slot.
func reset_all_state() -> void:
	delete_slot(active_slot)

	if is_instance_valid(DragManager) and DragManager.has_method("force_cancel_drag"):
		DragManager.force_cancel_drag()

	var seen: Dictionary = {}
	var reset_targets: Array[Node] = []
	for node in [StoryManager, CharacterProgressionManager, InventoryManager, MarioManager] + get_tree().get_nodes_in_group("persist"):
		if is_instance_valid(node) and not seen.has(node):
			seen[node] = true
			reset_targets.append(node)

	for node in reset_targets:
		if node.has_method("reset_state"):
			node.reset_state()

	if is_instance_valid(Dialogic) and is_instance_valid(Dialogic.VAR) and Dialogic.VAR.has_method("reset"):
		Dialogic.VAR.reset()

	_is_dirty = false
	LogManager.info("SaveManager", "Slot %d and all persistent state reset for New Game." % active_slot)


# ── Disk I/O ──────────────────────────────────────────────────────────────

func _write_json_atomic(target_path: String, tmp_path: String, data: Dictionary) -> bool:
	var json_string := JSON.stringify(data, "\t")
	if json_string.is_empty():
		return false

	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		LogManager.error("SaveManager", "Cannot open TMP for writing: %s" % tmp_path)
		return false
	file.store_string(json_string)
	file.flush()
	file.close()

	var verify := _attempt_read(tmp_path)
	if verify.is_empty():
		LogManager.error("SaveManager", "Verification failed for TMP file: %s" % tmp_path)
		return false

	var abs_target := ProjectSettings.globalize_path(target_path)
	var abs_tmp := ProjectSettings.globalize_path(tmp_path)
	if FileAccess.file_exists(target_path):
		DirAccess.remove_absolute(abs_target)
	var err := DirAccess.rename_absolute(abs_tmp, abs_target)
	if err != OK:
		LogManager.error("SaveManager", "Failed atomic swap %s -> %s (err %d)" % [tmp_path, target_path, err])
		return false
	return true


func _read_slot_from_disk(slot_id: int) -> Dictionary:
	var data := _attempt_read(_get_slot_latest_path(slot_id))
	if not data.is_empty():
		return data
	var backups := list_slot_backups(slot_id)
	if not backups.is_empty():
		var bpath := str(backups[0].get("path", ""))
		LogManager.info("SaveManager", "Slot %d latest.json missing; recovering from newest backup." % slot_id)
		return _attempt_read(bpath)
	return {}


func _attempt_read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json_string := file.get_as_text()
	file.close()
	if json_string.strip_edges().is_empty():
		return {}
	var json := JSON.new()
	if json.parse(json_string) != OK:
		return {}
	return json.data if json.data is Dictionary else {}
