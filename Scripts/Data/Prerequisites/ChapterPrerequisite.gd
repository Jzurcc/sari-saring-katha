class_name ChapterPrerequisite
extends StoryPrerequisite

## Requires another character to be at or beyond a specific story chapter.

## The character to check.
@export var target_character: CustomerData
## The required story chapter (0-8).
@export var min_chapter: int = 0

func is_met(story_manager: Node) -> bool:
	if not target_character:
		return true
	
	var states: Dictionary = story_manager.get("character_story_states")
	var current_chapter = states.get(target_character.resource_path, 0)
	
	return current_chapter >= min_chapter
