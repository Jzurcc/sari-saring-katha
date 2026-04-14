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
	
	var drop_id = item.get_clean_id()
	
	for desired in desired_items:
		if drop_id == desired.get_clean_id():
			return true
	return false


## Removes the first instance of a matching item from the desired list.
## Useful for multi-item requests. Returns true if an item was removed.
func fulfill_item(item: ItemData) -> bool:
	if desired_items.is_empty():
		return false
	
	var drop_id = item.get_clean_id()
	
	for i in range(desired_items.size()):
		if drop_id == desired_items[i].get_clean_id():
			desired_items.remove_at(i)
			return true
			
	return false
