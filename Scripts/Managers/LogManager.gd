extends Node

## Singleton manager for persistent debug logging.
## Writes to user://debug.log and backups the previous session to user://debug.log.old.

const LOG_PATH = "user://debug.log"
const OLD_LOG_PATH = "user://debug.log.old"

enum Level { DEBUG, INFO, WARN, ERROR }

func _enter_tree() -> void:
	_rotate_logs()
	_log_session_start()

func _rotate_logs() -> void:
	if FileAccess.file_exists(LOG_PATH):
		var dir = DirAccess.open("user://")
		if dir:
			if FileAccess.file_exists(OLD_LOG_PATH):
				dir.remove(OLD_LOG_PATH)
			dir.rename(LOG_PATH, OLD_LOG_PATH)

func _log_session_start() -> void:
	var file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file:
		var timestamp = _get_timestamp()
		file.store_line("================================================================================")
		file.store_line("--- SESSION START: %s ---" % timestamp)
		file.store_line("================================================================================")
		file.close()
	else:
		printerr("[LogManager] CRITICAL: Could not create log file at: ", LOG_PATH)

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
	var file = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
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
