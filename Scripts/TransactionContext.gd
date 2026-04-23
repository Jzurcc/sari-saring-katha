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
var is_next_tier_request: bool = false
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


func to_dict() -> Dictionary:
	var desired_paths := []
	for item in desired_items:
		if item: desired_paths.append(item.resource_path)
	
	var delivered_paths := []
	for item in delivered_items:
		if item: delivered_paths.append(item.resource_path)
		
	return {
		"transaction_type": transaction_type,
		"customer_data_path": customer_data.resource_path if customer_data else "",
		"secondary_customer_data_path": secondary_customer_data.resource_path if secondary_customer_data else "",
		"guest_spawns_later": guest_spawns_later,
		"desired_items": desired_paths,
		"delivered_items": delivered_paths,
		"requested_category": requested_category,
		"best_item_name": best_item_name,
		"original_count": original_count,
		"upgrade_to_best_tier": upgrade_to_best_tier,
		"is_next_tier_request": is_next_tier_request,
		"event_hour": event_hour,
		"timeline_path": timeline.resource_path if timeline is Resource else str(timeline),
		"is_placeholder": is_placeholder,
		"is_riddle": is_riddle,
		"riddle_item_path": riddle_item.resource_path if riddle_item else "",
		"wants_debt": wants_debt,
		"is_repaying": is_repaying,
		"repayment_amount": repayment_amount,
		"rumor_active": rumor_active,
		"rumor_type": rumor_type,
		"is_visit_story": is_visit_story,
		"story_advanced": story_advanced
	}

static func from_dict(data: Dictionary) -> TransactionContext:
	var ctx = TransactionContext.new()
	ctx.transaction_type = data.get("transaction_type", Type.VISIT)
	
	if data.get("customer_data_path", "") != "":
		ctx.customer_data = load(data["customer_data_path"])
	if data.get("secondary_customer_data_path", "") != "":
		ctx.secondary_customer_data = load(data["secondary_customer_data_path"])
		
	ctx.guest_spawns_later = data.get("guest_spawns_later", false)
	
	for path in data.get("desired_items", []):
		if path != "": ctx.desired_items.append(load(path))
	for path in data.get("delivered_items", []):
		if path != "": ctx.delivered_items.append(load(path))
		
	ctx.requested_category = data.get("requested_category", "")
	ctx.best_item_name = data.get("best_item_name", "")
	ctx.original_count = data.get("original_count", 0)
	ctx.upgrade_to_best_tier = data.get("upgrade_to_best_tier", false)
	ctx.is_next_tier_request = data.get("is_next_tier_request", false)
	ctx.event_hour = data.get("event_hour", 0)
	
	var tl_path = data.get("timeline_path", "")
	if tl_path != "": ctx.timeline = load(tl_path)
	
	ctx.is_placeholder = data.get("is_placeholder", false)
	ctx.is_riddle = data.get("is_riddle", false)
	if data.get("riddle_item_path", "") != "":
		ctx.riddle_item = load(data["riddle_item_path"])
		
	ctx.wants_debt = data.get("wants_debt", false)
	ctx.is_repaying = data.get("is_repaying", false)
	ctx.repayment_amount = data.get("repayment_amount", 0.0)
	ctx.rumor_active = data.get("rumor_active", false)
	ctx.rumor_type = data.get("rumor_type", 0.0)
	ctx.is_visit_story = data.get("is_visit_story", false)
	ctx.story_advanced = data.get("story_advanced", false)
	
	if not ctx.desired_items.is_empty() or not ctx.delivered_items.is_empty():
		print("[TransactionContext] Restored: %d desired, %d delivered items." % [ctx.desired_items.size(), ctx.delivered_items.size()])
	
	return ctx
