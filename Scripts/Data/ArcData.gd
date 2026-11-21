class_name ArcData
extends Resource

## One narrative arc's worth of generic character assets.
## Assigned to CustomerData.character_arcs (index 0 = Arc 1, etc.)

## Display name of this narrative arc (e.g. "Arc 1: The Watcher in the Shade").
@export var arc_name: String = ""

## Pool of purchase-oriented timelines (character requests an item).
@export var purchase_timelines: Array[DialogicTimeline] = []

## Pool of social-visit timelines (no purchase, just chatting).
@export var visit_timelines: Array[DialogicTimeline] = []
