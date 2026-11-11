class_name ArcData
extends Resource

## One narrative arc's worth of generic character assets.
## Assigned to CustomerData.character_arcs (index 0 = Arc 1, etc.)

## The pool of items this character buys during generic purchase interactions.
@export var filler_items: Array[ItemData] = []

## Pool of purchase-oriented timelines (character requests an item).
@export var purchase_timelines: Array[DialogicTimeline] = []

## Pool of social-visit timelines (no purchase, just chatting).
@export var visit_timelines: Array[DialogicTimeline] = []
