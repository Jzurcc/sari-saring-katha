class_name TransactionContext
extends RefCounted

enum Type { STORY, PURCHASE, VISIT }

var transaction_type: Type = Type.VISIT
var character_id: String = ""
## List of valid items that the customer would accept. Can be empty for visit only.
var desired_items: Array[ItemData] = []

## Ticks from 0 (5 AM) to 15 (8 PM, moving towards 9 PM).
var event_hour: int = 0

## Called when they arrive
var timeline_greeting: String = ""
## Called when clicked again to confirm their requests
var timeline_talk: String = ""
## Called when correct item is dropped into tray
var timeline_satisfied: String = ""
## Called when the wrong item is dropped — customer reacts but STAYS waiting
var timeline_wrong_item: String = ""
## Called when the player explicitly refuses service — customer leaves
var timeline_rejected: String = ""
## Called instead of greeting/talk if it's a social "no purchase" visit
var timeline_visit: String = ""

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
