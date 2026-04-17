class_name TransactionContext
extends RefCounted

enum Type { STORY, PURCHASE, VISIT }

var transaction_type: Type = Type.VISIT
var customer_data: CustomerData = null
var secondary_customer_data: CustomerData = null

## List of valid items that the customer would accept. Can be empty for visit only.
var desired_items: Array[ItemData] = []
var original_count: int = 0

## Ticks from 0 (5 AM) to 15 (8 PM, moving towards 9 PM).
var event_hour: int = 0

## The unified timeline to play for this transaction. 
## Can be a DialogicTimeline resource or a string path.
var timeline: Variant
var is_placeholder: bool = false
var is_riddle: bool = false
var riddle_item: ItemData = null
var wants_debt: bool = false
var is_repaying: bool = false
var repayment_amount: float = 0.0
var rumor_active: bool = false
var rumor_type: float = 0.0

func is_item_desired(item: ItemData) -> bool:
	if desired_items.is_empty():
		return false
	
	var drop_path = item.resource_path
	for desired in desired_items:
		if drop_path == desired.resource_path:
			return true
	return false

## Removes the first instance of a matching item from the desired list.
## Useful for multi-item requests. Returns true if an item was removed.
func fulfill_item(item: ItemData) -> bool:
	if desired_items.is_empty():
		return false
	
	var drop_path = item.resource_path
	for i in range(desired_items.size()):
		if drop_path == desired_items[i].resource_path:
			desired_items.remove_at(i)
			return true
			
	return false
