extends ColorRect

signal closed

enum View { CHARACTERS, ARCS, CHAPTERS }

@onready var char_list_view: Control = %CharacterList
@onready var details_view: Control = %DetailsView
@onready var card_container: HBoxContainer = %CardContainer
@onready var details_container: VBoxContainer = %DetailsContainer
@onready var back_button: TextureButton = %BackButton
@onready var subtitle_label: Label = %Subtitle

@onready var character_card_scene = preload("res://Scenes/UI/CharacterStoryCard.tscn")
@onready var list_button_scene = preload("res://Scenes/UI/ProgressListButton.tscn")

var _current_view: View = View.CHARACTERS
var _selected_character: CustomerData = null
var _selected_arc: int = -1
var _history: Array[View] = []

func _ready() -> void:
	hide()

func open() -> void:
	show()
	_current_view = View.CHARACTERS
	_history.clear()
	_populate_characters()
	_update_ui()

func close() -> void:
	hide()
	closed.emit()

func _update_ui() -> void:
	char_list_view.visible = (_current_view == View.CHARACTERS)
	details_view.visible = (_current_view != View.CHARACTERS)
	back_button.visible = (_current_view != View.CHARACTERS)
	
	match _current_view:
		View.CHARACTERS:
			subtitle_label.text = "Select a character to view their story"
		View.ARCS:
			subtitle_label.text = _selected_character.character_name.to_upper() + " / CHAPTERS"
		View.CHAPTERS:
			subtitle_label.text = _selected_character.character_name.to_upper() + " / ARC " + str(_selected_arc + 1)

func _populate_characters() -> void:
	for child in card_container.get_children():
		child.queue_free()
	
	if not StoryManager: return
	
	var characters = StoryManager.available_characters.duplicate()
	characters.sort_custom(func(a,b): return a.unlock_tier < b.unlock_tier)
	
	var _current_tier = StoryManager.current_tier
	
	for data in characters:
		if not data: continue
		var card = character_card_scene.instantiate()
		card_container.add_child(card)
		
		var is_locked = not StoryManager.encountered_characters.has(data.resource_path)
		card.setup(data, is_locked)
		
		if not card.disabled:
			card.pressed.connect(_on_character_selected.bind(data))

func _on_character_selected(data: CustomerData) -> void:
	_selected_character = data
	_navigate_to(View.ARCS)
	_populate_arcs()

func _populate_arcs() -> void:
	_clear_details()
	
	var story_states = StoryManager.character_story_states
	var current_progress = story_states.get(_selected_character.resource_path, 0)
	
	var arc_count = ceil(_selected_character.max_story_chapters / 3.0)
	if arc_count == 0: arc_count = 3 # Default minimum arcs if story exists
	
	for i in range(arc_count):
		var btn = list_button_scene.instantiate()
		details_container.add_child(btn)
		
		var is_locked = floori(current_progress / 3.0) < i
		var is_completed = floori(current_progress / 3.0) > i
		
		var arc_display_name = "ARC " + str(i + 1)
		if is_locked:
			arc_display_name = "???"
		elif i < _selected_character.arc_names.size() and _selected_character.arc_names[i] != "":
			arc_display_name = _selected_character.arc_names[i]
		
		btn.setup(arc_display_name, is_locked, is_completed)
		btn.pressed.connect(_on_arc_selected.bind(i))

func _on_arc_selected(arc_idx: int) -> void:
	_selected_arc = arc_idx
	_navigate_to(View.CHAPTERS)
	_populate_chapters()

func _populate_chapters() -> void:
	_clear_details()
	
	var story_states = StoryManager.character_story_states
	var current_progress = story_states.get(_selected_character.resource_path, 0)
	
	# Calculate how many chapters in this arc
	# Usually 3, but the last arc might have fewer (or use max_story_chapters)
	var chapters_in_arc = 3
	
	for i in range(chapters_in_arc):
		var chapter_idx = (_selected_arc * 3) + i
		if chapter_idx >= _selected_character.max_story_chapters:
			break
			
		var btn = list_button_scene.instantiate()
		details_container.add_child(btn)
		
		var is_locked = current_progress < chapter_idx
		var is_completed = current_progress > chapter_idx
		
		var chapter_display_name = "Chapter " + str(chapter_idx + 1)
		if is_locked:
			chapter_display_name = "???"
		elif chapter_idx < _selected_character.chapter_names.size() and _selected_character.chapter_names[chapter_idx] != "":
			chapter_display_name = _selected_character.chapter_names[chapter_idx]
		
		btn.setup(chapter_display_name, is_locked, is_completed)

func _navigate_to(new_view: View) -> void:
	_history.append(_current_view)
	_current_view = new_view
	_update_ui()

func _on_back_button_pressed() -> void:
	if _history.is_empty():
		_current_view = View.CHARACTERS
	else:
		_current_view = _history.pop_back()
	
	if _current_view == View.CHARACTERS:
		_populate_characters()
	elif _current_view == View.ARCS:
		_populate_arcs()
	elif _current_view == View.CHAPTERS:
		_populate_chapters()
	_update_ui()

func _clear_details() -> void:
	for child in details_container.get_children():
		child.queue_free()

func _on_close_button_pressed() -> void:
	close()
