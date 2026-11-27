class_name ChapterData
extends Resource

const MotionProfileScript = preload("res://Scripts/Data/CustomerMotionProfile.gd")

## Unified data container for a single story chapter on a CustomerData resource.
## Replaces the legacy parallel arrays (chapter_names, chapter_categories,
## visit_story_chapters, story_prerequisites, chapter_request_items).

## Display name of this chapter in the Story Progress UI.
@export var chapter_name: String = ""

## If true, this story chapter is a visit-only conversation (no item purchase).
@export var is_visit_only: bool = false

## Category preferences and "!category" exclusions for this chapter
## (e.g. ["snack", "bottle", "!candy"]).
## Leave empty ([]) to use the standard random selection with no exclusions.
@export var categories: PackedStringArray = PackedStringArray()

## Optional prerequisites that must be met before this chapter can trigger.
@export var prerequisites: StoryPrerequisiteGroup = null

@export_group("Pinned Request Override")
## If true, all pinned items automatically upgrade to the highest unlocked tier in their category.
@export var upgrade_all_pinned: bool = false

## Specific items the customer will request during this chapter.
## Leave empty to use category preferences / random selection.
@export var pinned_items: Array[ChapterItemEntry] = []

@export_group("Signature Substitution (VA-11 HALL-A)")
## Optional alternate item IDs (e.g. "bubblegum") that trigger label SubstituteItem instead of WrongItem.
@export var substitute_item_ids: PackedStringArray = PackedStringArray()
## Optional alternate item categories (e.g. "candy", "cold") that trigger label SubstituteItem instead of WrongItem.
@export var substitute_categories: PackedStringArray = PackedStringArray()

@export_group("Motion Override")
## Optional motion profile override for this story chapter (e.g. ghost counter phase-through).
## Leave null to use the character's default/alternate motion profiles.
@export var motion_override: MotionProfileScript = null
