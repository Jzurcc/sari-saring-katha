## DayTimeUI — displays the current in-game day and time below the money label.
## For testing: attach to two separate Label nodes in the CanvasLayer.
## The Day label shows the current GameManager day.
## The Time label reads from the first TimeOfDay node in the scene tree.
extends Label

enum DisplayMode { DAY, TIME }

@export var display_mode: DisplayMode = DisplayMode.DAY

var _time_of_day: Node = null

func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	# Find the TimeOfDay node (inside Sky3D)
	await get_tree().process_frame
	_time_of_day = get_tree().root.find_child("TimeOfDay", true, false)
	if _time_of_day == null:
		push_warning("[DayTimeUI] TimeOfDay node not found.")
	_refresh()

func _process(_delta: float) -> void:
	if display_mode == DisplayMode.TIME:
		_refresh()

func _on_day_started(_day: int) -> void:
	if display_mode == DisplayMode.DAY:
		_refresh()

func _refresh() -> void:
	match display_mode:
		DisplayMode.DAY:
			var gm_nodes = get_tree().get_nodes_in_group("game_manager")
			if gm_nodes.size() > 0:
				var gm = gm_nodes[0]
				text = "Day %d" % int(StoryManager.day)
			else:
				text = "Day ?"
		DisplayMode.TIME:
			if _time_of_day == null:
				_time_of_day = get_tree().root.find_child("TimeOfDay", true, false)
			if _time_of_day and "current_time" in _time_of_day:
				var t: float = _time_of_day.current_time
				var hour: int = int(t) % 24
				var raw_minute: int = int(fmod(t, 1.0) * 60.0)
				# Snap to :00 or :30 — sky still moves smoothly underneath
				@warning_ignore("integer_division")
				var minute: int = (raw_minute / 30) * 30
				var suffix := "AM" if hour < 12 else "PM"
				var display_hour := hour % 12
				if display_hour == 0:
					display_hour = 12
				text = "%d:%02d %s" % [display_hour, minute, suffix]
			else:
				text = "--:-- --"
