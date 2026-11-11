extends Node

## Singleton manager for persistent debug logging.
## Writes to user://debug.log and backups the previous session to user://debug.log.old.

var log_path = "user://debug.log"
var old_log_path = "user://debug.log.old"
var log_dir = "user://"

enum Level { DEBUG, INFO, WARN, ERROR }

func _enter_tree() -> void:
	_initialize_paths()
	_rotate_logs()
	_log_session_start()

func _initialize_paths() -> void:
	# Only attempt to use executable folder in exported builds
	if not OS.has_feature("editor"):
		var exe_dir = OS.get_executable_path().get_base_dir()
		var test_file = exe_dir.path_join("perm_test.tmp")
		
		# Test write permissions
		var f = FileAccess.open(test_file, FileAccess.WRITE)
		if f:
			f.close()
			DirAccess.remove_absolute(test_file)
			# If we reach here, we can write to the exe folder
			log_dir = exe_dir
			log_path = exe_dir.path_join("debug.log")
			old_log_path = exe_dir.path_join("debug.log.old")
		else:
			# Fallback to user:// is already the default, but we can print a note
			print("[LogManager] Exe folder is read-only. Falling back to: ", log_path)
	else:
		# In editor, stay in user:// to avoid cluttering project root
		pass

func _rotate_logs() -> void:
	if FileAccess.file_exists(log_path):
		var dir = DirAccess.open(log_dir)
		if dir:
			if FileAccess.file_exists(old_log_path):
				dir.remove(old_log_path)
			
			# Use path_join or relative names for rename
			if log_dir == "user://":
				dir.rename("debug.log", "debug.log.old")
			else:
				dir.rename(log_path, old_log_path)

func _log_session_start() -> void:
	var file = FileAccess.open(log_path, FileAccess.WRITE)
	if file:
		var timestamp = _get_timestamp()
		file.store_line("================================================================================")
		file.store_line("--- SESSION START: %s ---" % timestamp)
		file.store_line("--- LOG LOCATION: %s ---" % log_path)
		file.store_line("================================================================================")
		file.close()
	else:
		printerr("[LogManager] CRITICAL: Could not create log file at: ", log_path)

func _get_timestamp() -> String:
	var dt = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		dt.year, dt.month, dt.day,
		dt.hour, dt.minute, dt.second
	]

## Core logging function. Formats: YYYY-MM-DD HH:MM:SS [Category] [LEVEL] Message
func log_msg(category: String, level: Level, message: String) -> void:
	var level_str = Level.keys()[level]
	var timestamp = _get_timestamp()
	var formatted = "%s [%s] [%s] %s" % [timestamp, category, level_str, message]
	
	# 1. Output to Engine Console
	match level:
		Level.ERROR:
			printerr(formatted)
		Level.WARN:
			print_rich("[color=yellow]%s[/color]" % formatted)
		Level.DEBUG:
			# Only print debug to console in editor or if requested
			if OS.is_debug_build():
				print(formatted)
		_:
			print(formatted)
			
	# 2. Append to File
	var file = FileAccess.open(log_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_line(formatted)
		file.close()

# --- Convenience Wrappers ---

func info(category: String, message: String) -> void:
	log_msg(category, Level.INFO, message)

func warn(category: String, message: String) -> void:
	log_msg(category, Level.WARN, message)

func error(category: String, message: String) -> void:
	log_msg(category, Level.ERROR, message)

func debug(category: String, message: String) -> void:
	log_msg(category, Level.DEBUG, message)

## Specific helper for Exception/Object logging
func log_object(category: String, message: String, obj: Object) -> void:
	var obj_name = obj.name if "name" in obj else str(obj)
	var final_msg = "%s (Object: %s)" % [message, obj_name]
	info(category, final_msg)
