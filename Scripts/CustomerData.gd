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
## Timelines for unique story progression stages (Chapters 0-8).
## The game plays story_timelines[stage] when forcing a chapter interaction.
@export var story_timelines: Array[DialogicTimeline] = []

## Optional prerequisites for each story stage. 
## Index matches story_timelines index. If empty or null at an index, no requirements.
@export var story_prerequisites: Array[StoryPrerequisiteGroup] = []

## Per-arc generic assets. Index 0 = Arc 1 (chapters 0-2), 1 = Arc 2 (3-5), 2 = Arc 3 (6-8).
## Add or remove entries here to support any number of arcs — no code changes needed.
@export var character_arcs: Array[ArcData] = []

## Multiplier applied to the 3D sprite scale.
@export var sprite_scale: float = 1.0

## The sound played once per dialogue text bubble (e.g., KuyaKap's blip)
@export var dialogue_blip_sound: AudioStream

# ---------------------------------------------------------------------------
# Arc helpers — all caller code goes through these; never index character_arcs
# directly so fallback logic is always applied.
# ---------------------------------------------------------------------------

## Returns the 0-based arc index for a given story stage (floor(stage / 3)).
func get_arc_index(stage: int) -> int:
	return floori(float(stage) / 3.0)

## Returns the ArcData that applies to this stage, falling back toward Arc 0
## if the target arc hasn't been filled in yet.
func _get_arc(stage: int) -> ArcData:
	if character_arcs.is_empty():
		return null
	var idx: int = mini(get_arc_index(stage), character_arcs.size() - 1)
	# Walk backward until we find a non-null entry
	while idx >= 0:
		if character_arcs[idx] != null:
			return character_arcs[idx]
		idx -= 1
	return null

func get_filler_items(stage: int) -> Array[ItemData]:
	var arc := _get_arc(stage)
	if not arc:
		return [] as Array[ItemData]
	var result: Array[ItemData] = []
	for item in arc.filler_items:
		if item is ItemData:
			result.append(item)
	return result

func get_purchase_timelines(stage: int) -> Array[DialogicTimeline]:
	var arc := _get_arc(stage)
	if not arc:
		return [load("res://Dialogue/Timelines/Generic/Purchase.dtl")] as Array[DialogicTimeline]
	var result: Array[DialogicTimeline] = []
	for tl in arc.purchase_timelines:
		if tl is DialogicTimeline:
			result.append(tl)
	
	if result.is_empty():
		result.append(load("res://Dialogue/Timelines/Generic/Purchase.dtl"))
		
	return result

func get_visit_timelines(stage: int) -> Array[DialogicTimeline]:
	var arc := _get_arc(stage)
	if not arc:
		return [load("res://Dialogue/Timelines/Generic/Visit.dtl")] as Array[DialogicTimeline]
	var result: Array[DialogicTimeline] = []
	for tl in arc.visit_timelines:
		if tl is DialogicTimeline:
			result.append(tl)
			
	if result.is_empty():
		result.append(load("res://Dialogue/Timelines/Generic/Visit.dtl"))
		
	return result
