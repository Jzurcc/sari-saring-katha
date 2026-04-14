class_name StoryPrerequisiteGroup
extends Resource

## A collection of prerequisites for a single story chapter.
## All prerequisites in the list must be met (AND logic).

@export var prerequisites: Array[StoryPrerequisite] = []

func is_met(story_manager: Node) -> bool:
	for p in prerequisites:
		if p and not p.is_met(story_manager):
			return false
	return true
