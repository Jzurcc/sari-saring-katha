class_name TimelineLabels
extends RefCounted

## Cached lookup of `label <name>` declarations inside Dialogic .dtl timeline files.

const MAX_CACHE_ENTRIES := 500

static var _cache: Dictionary = {}


## True if `path` (a .dtl path, extension optional) declares `label <label_name>`.
## `path` is a Variant because transactions may carry a Resource instead of a String path;
## anything that is not a non-empty String simply has no labels.
static func has_label(path, label_name: String) -> bool:
	if typeof(path) != TYPE_STRING or path == "":
		return false

	var full_path: String = path
	if not full_path.ends_with(".dtl"):
		full_path += ".dtl"

	var cache_key := full_path + "::" + label_name
	if _cache.has(cache_key):
		return _cache[cache_key]

	if _cache.size() > MAX_CACHE_ENTRIES:
		_cache.clear()

	var found := _scan_file(full_path, label_name)
	_cache[cache_key] = found
	return found


static func _scan_file(full_path: String, label_name: String) -> bool:
	if not FileAccess.file_exists(full_path):
		if full_path.begins_with("res://"):
			return false
		full_path = "res://" + full_path
		if not FileAccess.file_exists(full_path):
			return false

	var file := FileAccess.open(full_path, FileAccess.READ)
	if not file:
		return false

	# Strip UTF-8 BOM so the line-start anchor matches the first line.
	var content := file.get_as_text().replace("\uFEFF", "")

	var regex := RegEx.new()
	regex.compile("(?m)^\\s*label\\s+" + label_name + "(\\s+|#|$)")
	return regex.search(content) != null

