class_name CustomerData
extends Resource

const DEFAULT_PURCHASE_TIMELINE = preload("res://Dialogue/Timelines/Generic/Purchase.dtl")
const DEFAULT_VISIT_TIMELINE = preload("res://Dialogue/Timelines/Generic/Visit.dtl")
const MotionProfileScript = preload("res://Scripts/Data/CustomerMotionProfile.gd")

## The display name of the character (can contain spaces).
@export var character_name: String

## The tier at which this customer starts appearing in the game.
@export var unlock_tier: int = 1

## The Dialogic Character resource (.dch) for this customer.
@export var dialogic_character: DialogicCharacter

@export_group("Visuals")
## The sprite sheet / texture displayed for this customer in the 3D world.
@export var sprite_texture: Texture2D
## Multiplier applied to the 3D sprite scale.
@export var sprite_scale: float = 1.0
## Vertical ratio for the speech bubble position relative to total height (0.0 to 1.0).
## 0.75 is the default standard for most characters.
@export var speech_marker_height_ratio: float = 0.75

@export_group("Audio")
## The sound played once per dialogue text bubble (e.g., KuyaKap's blip).
@export var dialogue_blip_sound: AudioStream
## Volume offset for dialogue blips (e.g. 5.0 for louder, -5.0 for quieter).
@export var dialogue_blip_volume: float = 0.0

@export_group("Behavior Traits")
## If true, this customer prefers items with riddles/hints (e.g. Buboy).
@export var prefers_riddles: bool = false
## If true, this customer requests to pay via Utang/debt on purchases (e.g. Manang Ana).
@export var requests_utang: bool = false
## If true, this customer spreads rumors about previous customers (e.g. Danilo).
@export var spreads_rumors: bool = false
## If true, generic transactions stay visit-only until reaching the final story chapter (e.g. Danilo).
@export var purchase_only_on_final_chapter: bool = false
## If true, this character only appears as the nightly quota collector, bypassing day spawns (e.g. Reyna Mayari).
@export var is_nightly_collector: bool = false
## Relative spawn weight for regular visits and story selection (1.0 = normal, <1.0 = less common).
@export_range(0.05, 5.0, 0.05) var spawn_weight: float = 1.0

@export_group("Story & Arcs")
## The single timeline file that handles all story chapters for this character.
@export var story_timeline: DialogicTimeline

## Ordered list of story chapters (0-indexed).
## Each ChapterData holds its name, visit-only flag, category preferences/exclusions,
## prerequisites, and optional pinned items.
## After finishing all chapters, the customer retains the last chapter's category preferences/exclusions.
@export var chapters: Array[ChapterData] = []

## Per-arc generic assets. Index 0 = Arc 1 (chapters 0-2), 1 = Arc 2 (3-5), 2 = Arc 3 (6-8).
## Add or remove entries here to support any number of arcs — no code changes needed.
@export var character_arcs: Array[ArcData] = []

@export_group("Motion & Animations")
## Default enter/idle/locomotion/exit motion profile for this customer.
@export var default_motion: MotionProfileScript = null
## Optional alternate motion variants randomly mixed in with default_motion on regular visits/purchases.
@export var alternate_motions: Array[MotionProfileScript] = []
## Non-interactive pass-by / fly-by cameo animations played occasionally in the street/sky in front of the store.
@export var ambient_cameo_motions: Array[MotionProfileScript] = []

## Total number of story chapters for this character (derived from chapters.size()).
var max_story_chapters: int:
	get:
		return chapters.size()

## Returns a stable ID based on the filename (e.g. "KuyaKap.tres" -> "kuyakap").
func get_clean_id() -> String:
	return resource_path.get_file().get_basename().to_lower()

# ---------------------------------------------------------------------------
# Behavior Trait Queries
# ---------------------------------------------------------------------------

func has_riddle_preference() -> bool:
	return prefers_riddles

func can_request_utang() -> bool:
	return requests_utang

func can_spread_rumors() -> bool:
	return spreads_rumors

func is_visit_only_until_final_chapter() -> bool:
	return purchase_only_on_final_chapter

func is_collector() -> bool:
	return is_nightly_collector

# ---------------------------------------------------------------------------
# Chapter Helpers
# ---------------------------------------------------------------------------

## Returns the ChapterData at `chapter` (strict bounds; returns null if out of range).
func get_chapter(chapter: int) -> ChapterData:
	if chapter < 0 or chapter >= chapters.size():
		return null
	return chapters[chapter]

## Returns the ChapterData at `chapter`, clamping to the last entry so customers
## retain their final preferences/exclusions after finishing their story.
func get_chapter_clamped(chapter: int) -> ChapterData:
	if chapters.is_empty():
		return null
	return chapters[clampi(chapter, 0, chapters.size() - 1)]

func get_chapter_name(chapter: int) -> String:
	var ch := get_chapter(chapter)
	return ch.chapter_name if ch else ""

func is_visit_story_chapter(chapter: int) -> bool:
	var ch := get_chapter(chapter)
	return ch.is_visit_only if ch else false

func get_chapter_prerequisites(chapter: int) -> StoryPrerequisiteGroup:
	var ch := get_chapter(chapter)
	return ch.prerequisites if ch else null

func get_chapter_pinned_items(chapter: int) -> Array[ChapterItemEntry]:
	var ch := get_chapter(chapter)
	if ch:
		return ch.pinned_items
	var empty: Array[ChapterItemEntry] = []
	return empty

func get_chapter_upgrade_all_pinned(chapter: int) -> bool:
	var ch := get_chapter(chapter)
	return ch.upgrade_all_pinned if ch else false

## Returns all positive (preferred) categories for a given chapter, resolved via OrderItemPicker aliases.
func get_chapter_preferred_categories(chapter: int) -> Array[String]:
	var result: Array[String] = []
	var ch := get_chapter_clamped(chapter)
	if not ch:
		return result
	for raw_token in ch.categories:
		var token := raw_token.strip_edges()
		if token.is_empty() or token.begins_with("!"):
			continue
		for mapped in OrderItemPicker.mapped_categories(token):
			if not result.has(mapped):
				result.append(mapped)
	return result

## Returns all "!category" excluded categories for a given chapter, resolved via OrderItemPicker aliases.
func get_chapter_excluded_categories(chapter: int) -> Array[String]:
	var result: Array[String] = []
	var ch := get_chapter_clamped(chapter)
	if not ch:
		return result
	for raw_token in ch.categories:
		var token := raw_token.strip_edges()
		if not token.begins_with("!"):
			continue
		var cat_name := token.substr(1).strip_edges()
		if cat_name.is_empty():
			continue
		for mapped in OrderItemPicker.mapped_categories(cat_name):
			if not result.has(mapped):
				result.append(mapped)
	return result

## Returns the first preferred category for a given chapter, or "" if none.
func get_chapter_category(chapter: int) -> String:
	var prefs := get_chapter_preferred_categories(chapter)
	return prefs[0] if not prefs.is_empty() else ""

# ---------------------------------------------------------------------------
# Arc Helpers
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
	while idx >= 0:
		if character_arcs[idx] != null:
			return character_arcs[idx]
		idx -= 1
	return null

func get_arc_name(arc_index: int) -> String:
	if arc_index < 0 or arc_index >= character_arcs.size():
		return ""
	var arc := character_arcs[arc_index]
	return arc.arc_name if arc else ""

func get_purchase_timelines(chapter: int) -> Array[DialogicTimeline]:
	var arc := _get_arc(chapter)
	var result: Array[DialogicTimeline] = []
	if not arc:
		result.append(DEFAULT_PURCHASE_TIMELINE)
		return result
	for tl in arc.purchase_timelines:
		if tl is DialogicTimeline:
			result.append(tl)

	if result.is_empty():
		result.append(DEFAULT_PURCHASE_TIMELINE)

	return result

func get_visit_timelines(chapter: int) -> Array[DialogicTimeline]:
	var arc := _get_arc(chapter)
	var result: Array[DialogicTimeline] = []
	if not arc:
		result.append(DEFAULT_VISIT_TIMELINE)
		return result
	for tl in arc.visit_timelines:
		if tl != null:
			result.append(tl)
		else:
			LogManager.warn("CustomerData", "Null visit timeline found in arc for %s" % character_name)

	if result.is_empty():
		LogManager.info("CustomerData", "No visit timelines for %s chapter %d, falling back to generic." % [character_name, chapter])
		result.append(DEFAULT_VISIT_TIMELINE)

	return result

# ---------------------------------------------------------------------------
# Motion Selection Helpers
# ---------------------------------------------------------------------------

## Resolves the active CustomerMotionProfile for an encounter.
## Priority: ChapterData.motion_override (for story encounters) -> weighted pick of default + alternates.
func pick_motion_profile(chapter: int, is_story: bool) -> MotionProfileScript:
	if is_story:
		var ch := get_chapter(chapter)
		if ch and ch.motion_override != null:
			return ch.motion_override

	var pool: Array[MotionProfileScript] = []
	if default_motion != null:
		pool.append(default_motion)
	for alt in alternate_motions:
		if alt != null:
			pool.append(alt)

	return _pick_weighted_motion(pool)

## Picks a weighted random ambient cameo motion (pass-by / fly-by), or null if none are configured.
func pick_ambient_cameo_motion() -> MotionProfileScript:
	var pool: Array[MotionProfileScript] = []
	for cameo in ambient_cameo_motions:
		if cameo != null:
			pool.append(cameo)
	return _pick_weighted_motion(pool)

static func _pick_weighted_motion(pool: Array[MotionProfileScript]) -> MotionProfileScript:
	if pool.is_empty():
		return null
	if pool.size() == 1:
		return pool[0]
	var total_weight := 0.0
	for p in pool:
		total_weight += maxf(p.selection_weight, 0.05)
	var roll := randf() * total_weight
	var acc := 0.0
	for p in pool:
		acc += maxf(p.selection_weight, 0.05)
		if roll <= acc:
			return p
	return pool[-1]
