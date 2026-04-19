class_name TransactionContext
extends RefCounted

enum Type { STORY, PURCHASE, VISIT }

var transaction_type: Type = Type.VISIT
var customer_data: CustomerData = null
var secondary_customer_data: CustomerData = null
var guest_spawns_later: bool = false

## List of valid items that the customer would accept. Can be empty for visit only.
var desired_items: Array[ItemData] = []
var requested_category: String = ""
var best_item_name: String = ""
var original_count: int = 0
var upgrade_to_best_tier: bool = false
var delivered_items: Array[ItemData] = []

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
var is_visit_story: bool = false
var story_advanced: bool = false

func _is_match(item: ItemData, desired: ItemData) -> bool:
	if item == desired:
		return true
	if item.resource_path != "" and item.resource_path == desired.resource_path:
		return true
	if item.item_name == desired.item_name:
		return true
	return false

func is_item_desired(item: ItemData) -> bool:
	if desired_items.is_empty():
		return false
	
	for desired in desired_items:
		if _is_match(item, desired):
			return true
	return false

## Removes the first instance of a matching item from the desired list.
## Useful for multi-item requests. Returns true if an item was removed.
func fulfill_item(item: ItemData) -> bool:
	if desired_items.is_empty():
		return false
	
	for i in range(desired_items.size()):
		if _is_match(item, desired_items[i]):
			var fulfilled = desired_items[i]
			desired_items.remove_at(i)
			delivered_items.append(fulfilled)
			return true
			
	return false
