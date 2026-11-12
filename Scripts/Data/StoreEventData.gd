class_name StoreEventData
extends Resource

## Data container defining a daily market condition, rumor, and economic modifiers.

@export var event_id: String = ""
@export var event_name: String = ""
@export_multiline var description: String = ""
@export_multiline var rumor_text: String = ""
@export var affected_categories: Array[String] = []
@export var affected_items: Array[ItemData] = []
@export var demand_multiplier: float = 2.5
@export var tolerance_offset: int = 2

## Returns true if the given item matches this event's target criteria.
func affects_item(item: ItemData) -> bool:
	if not item:
		return false
	if affected_items.has(item):
		return true
	if not affected_categories.is_empty() and affected_categories.has(item.category):
		return true
	return false
