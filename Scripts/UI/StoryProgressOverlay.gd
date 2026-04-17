extends ColorRect

signal closed

enum View { CHARACTERS, ARCS, INTERACTIONS }

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
			subtitle_label.text = _selected_character.character_name.to_upper() + " / ARCS"
		View.INTERACTIONS:
			subtitle_label.text = _selected_character.character_name.to_upper() + " / ARC " + str(_selected_arc + 1)

func _populate_characters() -> void:
	for child in card_container.get_children():
		child.queue_free()
	
	if not StoryManager: return
	
	var save_data = SaveManager.load_game()
	var is_no_save = save_data.is_empty()
	
	var characters = StoryManager.available_characters.duplicate()
	characters.sort_custom(func(a,b): return a.unlock_tier < b.unlock_tier)
	
	var current_tier = StoryManager.current_tier
	
	for data in characters:
		if not data: continue
		var card = character_card_scene.instantiate()
		card_container.add_child(card)
		
		var is_locked = is_no_save or (data.unlock_tier > current_tier)
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
	
	# Usually 3 arcs
	for i in range(3):
		var btn = list_button_scene.instantiate()
		details_container.add_child(btn)
		
		var is_locked = floori(current_progress / 3.0) < i
		var is_completed = floori(current_progress / 3.0) > i
		
		btn.setup("ARC " + str(i + 1), is_locked, is_completed)
		btn.pressed.connect(_on_arc_selected.bind(i))

func _on_arc_selected(arc_idx: int) -> void:
	_selected_arc = arc_idx
	_navigate_to(View.INTERACTIONS)
	_populate_interactions()

func _populate_interactions() -> void:
	_clear_details()
	
	var story_states = StoryManager.character_story_states
	var current_progress = story_states.get(_selected_character.resource_path, 0)
	
	# 3 interactions per arc
	for i in range(3):
		var interaction_idx = (_selected_arc * 3) + i
		var btn = list_button_scene.instantiate()
		details_container.add_child(btn)
		
		var is_locked = current_progress < interaction_idx
		var is_completed = current_progress > interaction_idx
		
		var interaction_name = "Interaction " + str(interaction_idx + 1)
		
		# Try to pull actual name from timeline if available
		if interaction_idx < _selected_character.story_timelines.size():
			var timeline = _selected_character.story_timelines[interaction_idx]
			if timeline:
				var raw_name = timeline.resource_path.get_file().get_basename()
				# Clean up names like Story0, Story1 into something nicer or just use them
				if raw_name.begins_with("Story") or raw_name.begins_with("Chapter"):
					interaction_name = raw_name # Or add logic to make it "Story 0"
				else:
					interaction_name = raw_name.capitalize()
		
		btn.setup(interaction_name, is_locked, is_completed)

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
		
	_update_ui()

func _clear_details() -> void:
	for child in details_container.get_children():
		child.queue_free()

func _on_close_button_pressed() -> void:
	close()
