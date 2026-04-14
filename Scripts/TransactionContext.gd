class_name TransactionContext
extends RefCounted

enum Type { STORY, PURCHASE, VISIT }

var transaction_type: Type = Type.VISIT
var character_id: String = ""
## List of valid items that the customer would accept. Can be empty for visit only.
var desired_items: Array[ItemData] = []

## Ticks from 0 (5 AM) to 15 (8 PM, moving towards 9 PM).
var event_hour: int = 0

## The unified timeline to play for this transaction. 
## Can be a DialogicTimeline resource or a string path.
var timeline: Variant
var is_placeholder: bool = false
var is_riddle: bool = false
var wants_debt: bool = false
var rumor_active: bool = false
var rumor_type: float = 0.0

func is_item_desired(item: ItemData) -> bool:
	if desired_items.is_empty():
		return false
	
	# Fallback key matching using resource path
	var drop_key = item.id if item.id not in ["", "unset"] else item.resource_path
	
	for desired in desired_items:
		var target_key = desired.id if desired.id not in ["", "unset"] else desired.resource_path
		if drop_key == target_key:
			return true
	return false
