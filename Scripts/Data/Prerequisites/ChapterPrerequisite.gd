class_name ChapterPrerequisite
extends StoryPrerequisite

## Requires another character to have completed at least `min_chapter` story chapters
## (0-based progression index: min_chapter = 1 means Ch. 1 finished; min_chapter = 4 means Ch. 1-4 finished).

## Optional direct CustomerData reference (use target_character_id instead when two characters cross-reference each other).
@export var target_character: CustomerData
## Clean character ID (e.g. "brahim", "danilo", "rosalyn") — avoids circular .tres preload deadlocks.
@export var target_character_id: String = ""
## Minimum completed chapter index required in CharacterProgressionManager.
@export var min_chapter: int = 0


func is_met(story_manager: Node) -> bool:
	if not is_instance_valid(CharacterProgressionManager):
		return true

	var path: String = ""
	if target_character != null:
		path = target_character.resource_path
	elif target_character_id.strip_edges() != "" and is_instance_valid(story_manager) and story_manager.has_method("_get_character_data"):
		var c_data: CustomerData = story_manager._get_character_data(target_character_id.strip_edges())
		if c_data != null:
			path = c_data.resource_path

	if path == "":
		return true

	return CharacterProgressionManager.get_chapter(path) >= min_chapter
