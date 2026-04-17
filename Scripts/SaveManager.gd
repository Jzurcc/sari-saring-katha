extends Node

## Centralized, buffered save system to handle game state persistence efficiently.
##
## This manager prevents redundant disk I/O by debouncing save requests.
## Multiple systems can call [method save_game] in the same frame without
## causing performance spikes.
##
## [b]Merge behaviour:[/b] Calling [method save_game] performs a SHALLOW merge
## at the top level. Each key in the incoming dictionary FULLY REPLACES the
## corresponding key in the cache, rather than recursively merging sub-keys.
## This prevents "ghost data" where removed shelf items would persist because
## the old slot array was merged with rather than replaced.

const SAVE_PATH = "user://save_game.json"

## The internal cache of the current save state.
var _save_cache: Dictionary = {}
var _is_dirty: bool = false
var _has_loaded: bool = false
var _save_timer: Timer

func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.wait_time = 0.5 # Wait half a second of inactivity before committing to disk
	_save_timer.one_shot = true
	_save_timer.timeout.connect(_commit_to_disk)
	add_child(_save_timer)
	
	if not _has_loaded:
		_load_from_disk()

func _notification(what: int) -> void:
	# Handle both graceful window close and engine shutdown/predelete
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _is_dirty:
			print("[SaveManager] Shutdown detected. Forcing immediate save...")
			force_save()


signal save_started
signal save_finished

## Merges new data into the save cache and schedules a disk write.
##
## Merge strategy: one level deep.
## [br]- For each key in [param new_data]:
## [br]  - If both the cached value AND the incoming value are [Dictionary], their
##       sub-keys are merged individually (so ShelfSurface A can update only its
##       own slot without wiping ShelfSurface B's data).
## [br]  - Otherwise (Array, String, int, float, bool, null): the cached value is
##       fully replaced by the incoming value.
##
## This is deliberately NOT infinitely recursive to prevent the ghost-data bug
## where a cleared shelf slot array would be merged INTO rather than replaced.
func save_game(new_data: Dictionary) -> void:
	for key in new_data:
		if new_data[key] is Dictionary and _save_cache.has(key) and _save_cache[key] is Dictionary:
			# One level deeper: replace sub-keys individually
			for sub_key in new_data[key]:
				_save_cache[key][sub_key] = new_data[key][sub_key]
		else:
			# Scalars, Arrays, or new top-level keys: replace entirely
			_save_cache[key] = new_data[key]
	
	_is_dirty = true
	
	# Start a debounce timer to batch rapid saves into a single disk write.
	# If the timer is already running with significant time left, let it finish.
	# If it has almost expired, nudge it.
	if _save_timer.is_stopped():
		_save_timer.start()
	elif _save_timer.time_left < 0.1:
		_save_timer.start()

## Immediately commits the cache to disk. Useful for quitting or critical moments.
func force_save() -> void:
	if _is_dirty:
		_save_timer.stop()
		_commit_to_disk()

## Returns a COPY of the current save state so callers cannot accidentally
## mutate the internal cache by reference.
## [b]Note:[/b] This triggers a disk load only once; subsequent calls return the cache.
func load_game() -> Dictionary:
	if not _has_loaded:
		_load_from_disk()
	return _save_cache.duplicate(true)

## Deletes the save file and clears the cache.
func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_save_cache = {}
	_is_dirty = false
	_has_loaded = false
	_save_timer.stop()

# --- Internal ---

## Loads the save file from disk into the internal cache.
## Called once at startup; do not call directly — use [method load_game].
func _load_from_disk() -> void:
	_has_loaded = true
	
	if not FileAccess.file_exists(SAVE_PATH):
		_save_cache = {}
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[SaveManager] Could not open save file for reading: ", SAVE_PATH)
		_save_cache = {}
		return

	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error == OK:
		var data = json.data
		if data is Dictionary:
			_save_cache = data
			print("[SaveManager] Save file loaded from disk.")
		else:
			push_error("[SaveManager] Save file format invalid (expected Dictionary, got: ", typeof(data), ")")
			_save_cache = {}
	else:
		push_error("[SaveManager] JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
		_save_cache = {}

func _commit_to_disk() -> void:
	if not _is_dirty:
		return
		
	save_started.emit()
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(_save_cache, "\t")
		file.store_string(json_string)
		file.close()
		_is_dirty = false
		print("[SaveManager] State committed to disk.")
	else:
		push_error("[SaveManager] Could not open save file for writing: ", SAVE_PATH)
		
	save_finished.emit()
