class_name CustomerData
extends Resource

## The display name of the character (can contain spaces).
@export var character_name: String

## Returns a stable ID based on the filename (e.g. "KuyaKap.tres" -> "kuyakap").
func get_clean_id() -> String:
	return resource_path.get_file().get_basename().to_lower()

## The sprite sheet / texture displayed for this customer in the 3D world.
@export var sprite_texture: Texture2D
## The Dialogic Character resource (.dch) for this customer
@export var dialogic_character: DialogicCharacter

## The tier at which this customer starts appearing in the game.
@export var unlock_tier: int = 1

@export_group("Audio")
## Volume offset for dialogue blips (e.g. 5.0 for louder, -5.0 for quieter).
@export var dialogue_blip_volume: float = 0.0

@export_group("Story Progression")
## The single timeline file that handles all story chapters for this character.
@export var story_timeline: DialogicTimeline

## The total number of story chapters (episodes) available in this character's story_timeline. 
## Set to 0 if the character has no main story arc.
@export var max_story_chapters: int = 0

## Optional prerequisites for each story chapter. 
## Index matches story_timelines index. If empty or null at an index, no requirements.
@export var story_prerequisites: Array[StoryPrerequisiteGroup] = []

## Per-chapter item overrides for story visits. Index = chapter number (0–8).
## Each ChapterItems entry holds an Array[ItemData] the customer will request that chapter.
## If the array is shorter than max_story_chapters, or the entry at the current
## chapter index is null/empty, the system falls back to the normal random item shuffle.
@export var chapter_request_items: Array = []

## Returns the pinned ChapterItems for a given story chapter, or null
## if that chapter should use the normal random shuffle.
func get_chapter_request(chapter: int) -> ChapterItems:
	if chapter_request_items.is_empty() or chapter >= chapter_request_items.size():
		return null
	var entry = chapter_request_items[chapter]
	if not (entry is ChapterItems) or entry.items.is_empty():
		return null
	return entry




## Per-arc generic assets. Index 0 = Arc 1 (chapters 0-2), 1 = Arc 2 (3-5), 2 = Arc 3 (6-8).
## Add or remove entries here to support any number of arcs — no code changes needed.
@export var character_arcs: Array[ArcData] = []

@export_group("Narrative UI")
## Names for the narrative arcs (e.g. index 0 = ARC 1).
@export var arc_names: Array[String] = []

## Names for the individual story chapters (0-indexed).
@export var chapter_names: Array[String] = []


## Multiplier applied to the 3D sprite scale.
@export var sprite_scale: float = 1.0

## Vertical ratio for the speech bubble position relative to total height (0.0 to 1.0).
## 0.75 is the default standard for most characters.
@export var speech_marker_height_ratio: float = 0.75

## The sound played once per dialogue text bubble (e.g., KuyaKap's blip)
@export var dialogue_blip_sound: AudioStream

# ---------------------------------------------------------------------------
# Arc helpers — all caller code goes through these; never index character_arcs
# directly so fallback logic is always applied.
# ---------------------------------------------------------------------------

## Returns the 0-based arc index for a given story chapter (floor(chapter / 3)).
func get_arc_index(chapter: int) -> int:
	return floori(float(chapter) / 3.0)

## Returns the ArcData that applies to this chapter, falling back toward Arc 0
## if the target arc hasn't been filled in yet.
func _get_arc(chapter: int) -> ArcData:
	if character_arcs.is_empty():
		return null
	var idx: int = mini(get_arc_index(chapter), character_arcs.size() - 1)
	# Walk backward until we find a non-null entry
	while idx >= 0:
		if character_arcs[idx] != null:
			return character_arcs[idx]
		idx -= 1
	return null

func get_filler_items(chapter: int) -> Array[ItemData]:
	var arc := _get_arc(chapter)
	if not arc:
		return [] as Array[ItemData]
	var result: Array[ItemData] = []
	for item in arc.filler_items:
		if item is ItemData:
			result.append(item)
	return result

## Returns an aggregated list of filler items from the current arc and all previous arcs.
func get_cumulative_filler_items(chapter: int) -> Array[ItemData]:
	var result: Array[ItemData] = []
	var max_arc_idx = get_arc_index(chapter)
	
	for i in range(max_arc_idx + 1):
		var arc = _get_arc(i * 3) # Sample arc at the start of its chapter range
		if arc:
			for item in arc.filler_items:
				if item is ItemData and not result.has(item):
					result.append(item)
	return result


func get_purchase_timelines(chapter: int) -> Array[DialogicTimeline]:
	var arc := _get_arc(chapter)
	if not arc:
		return [load("res://Dialogue/Timelines/Generic/Purchase.dtl")] as Array[DialogicTimeline]
	var result: Array[DialogicTimeline] = []
	for tl in arc.purchase_timelines:
		if tl is DialogicTimeline:
			result.append(tl)
	
	if result.is_empty():
		result.append(load("res://Dialogue/Timelines/Generic/Purchase.dtl"))
		
	return result

func get_visit_timelines(chapter: int) -> Array[DialogicTimeline]:
	var arc := _get_arc(chapter)
	if not arc:
		return [load("res://Dialogue/Timelines/Generic/Visit.dtl")] as Array[DialogicTimeline]
	var result: Array[DialogicTimeline] = []
	for tl in arc.visit_timelines:
		if tl != null:
			result.append(tl)
		else:
			LogManager.warn("CustomerData", "Null visit timeline found in arc for %s" % character_name)
			
	if result.is_empty():
		LogManager.info("CustomerData", "No visit timelines for %s chapter %d, falling back to generic." % [character_name, chapter])
		result.append(load("res://Dialogue/Timelines/Generic/Visit.dtl"))
		
	return result
