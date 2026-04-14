class_name StoryPrerequisite
extends Resource

## Base class for story prerequisites.
## Do not use directly; use one of the subclasses.

## Returns true if the prerequisite is satisfied.
func is_met(_story_manager: Node) -> bool:
	return true
