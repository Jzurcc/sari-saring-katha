extends Node

## Centralized, buffered save system to handle game state persistence efficiently.
##
## This manager prevents redundant disk I/O by debouncing save requests.
## Multiple systems can call [method save_game] in the same frame without
## causing performance spikes.

const SAVE_PATH = "user://save_game.json"

## The internal cache of the current save state.
var _save_cache: Dictionary = {}
var _is_dirty: bool = false
var _save_timer: Timer

func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.wait_time = 0.5 # Wait half a second of inactivity before committing to disk
	_save_timer.one_shot = true
	_save_timer.timeout.connect(_commit_to_disk)
	add_child(_save_timer)
	
	load_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("[SaveManager] Shutdown detected. Forcing immediate save...")
		force_save()


signal save_started
signal save_finished

## Merges new data into the save cache and schedules a disk write.
func save_game(new_data: Dictionary) -> void:
	# Merge new data into our cache
	_deep_merge(_save_cache, new_data)
	
	_is_dirty = true
	
	# If the timer isn't running, this is a new "burst" of saves
	if _save_timer.is_stopped():
		_save_timer.start()
	else:
		# If it's already running, we only restart it if we haven't reached a max delay.
		# However, a simpler way is to just let it run if it's already close,
		# or restart it but check elapsed time.
		
		# Better approach for Godot: if the timer is already running and has more than 
		# 0.1s left, don't restart it to avoid pushing it forever.
		if _save_timer.time_left < 0.1:
			_save_timer.start()

## Immediately commits the cache to disk. Useful for quitting or critical moments.
func force_save() -> void:
	if _is_dirty:
		_commit_to_disk()

## Returns the current save state. Loads from disk if cache is empty.
func load_game() -> Dictionary:
	if not _save_cache.is_empty():
		return _save_cache
		
	if not FileAccess.file_exists(SAVE_PATH):
		_save_cache = {}
		return _save_cache
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error == OK:
		var data = json.data
		if data is Dictionary:
			_save_cache = data
		else:
			push_error("[SaveManager] Save file format invalid (Expected Dictionary)")
			_save_cache = {}
	else:
		push_error("[SaveManager] JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
		_save_cache = {}
		
	return _save_cache

## Deletes the save file and clears the cache.
func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_save_cache = {}
	_is_dirty = false
	_save_timer.stop()

# --- Internal ---

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

## Performs a recursive merge of two dictionaries.
func _deep_merge(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		if source[key] is Dictionary and target.has(key) and target[key] is Dictionary:
			_deep_merge(target[key], source[key])
		else:
			target[key] = source[key]
