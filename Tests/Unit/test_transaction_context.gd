## GdUnit4 test suite for TransactionContext round-trip integrity
## Tests: to_dict() → from_dict() is lossless and null-safe
extends GdUnitTestSuite

class_name TestTransactionContext


# --- Helpers ---

func _make_context() -> TransactionContext:
	var ctx = TransactionContext.new()
	ctx.transaction_type = TransactionContext.Type.PURCHASE
	ctx.requested_category = "bottle"
	ctx.best_item_name = "Royal Tru-Orange"
	ctx.original_count = 2
	ctx.upgrade_to_best_tier = true
	ctx.is_next_tier_request = false
	ctx.event_hour = 3
	ctx.is_placeholder = false
	ctx.is_riddle = false
	ctx.wants_debt = false
	ctx.is_repaying = false
	ctx.repayment_amount = 0.0
	ctx.rumor_active = true
	ctx.rumor_type = 1.0
	ctx.is_visit_story = false
	ctx.story_advanced = false
	ctx.guest_spawns_later = false
	return ctx


# --- Tests ---

## [TC-01] Primitive fields survive a to_dict → from_dict round-trip
func test_roundtrip_preserves_primitive_fields() -> void:
	var original := _make_context()
	var restored := TransactionContext.from_dict(original.to_dict())

	assert_int(restored.transaction_type).is_equal(original.transaction_type)
	assert_str(restored.requested_category).is_equal(original.requested_category)
	assert_str(restored.best_item_name).is_equal(original.best_item_name)
	assert_int(restored.original_count).is_equal(original.original_count)
	assert_bool(restored.upgrade_to_best_tier).is_equal(original.upgrade_to_best_tier)
	assert_int(restored.event_hour).is_equal(original.event_hour)
	assert_bool(restored.rumor_active).is_equal(original.rumor_active)
	assert_float(restored.rumor_type).is_equal(original.rumor_type)
	assert_bool(restored.is_visit_story).is_equal(original.is_visit_story)
	assert_bool(restored.story_advanced).is_equal(original.story_advanced)
	assert_bool(restored.wants_debt).is_equal(original.wants_debt)
	assert_bool(restored.is_repaying).is_equal(original.is_repaying)
	assert_float(restored.repayment_amount).is_equal(original.repayment_amount)


## [TC-02] VISIT type survives round-trip
func test_roundtrip_visit_type() -> void:
	var ctx := TransactionContext.new()
	ctx.transaction_type = TransactionContext.Type.VISIT
	var restored := TransactionContext.from_dict(ctx.to_dict())
	assert_int(restored.transaction_type).is_equal(TransactionContext.Type.VISIT)


## [TC-03] STORY type survives round-trip
func test_roundtrip_story_type() -> void:
	var ctx := TransactionContext.new()
	ctx.transaction_type = TransactionContext.Type.STORY
	ctx.is_visit_story = true
	var restored := TransactionContext.from_dict(ctx.to_dict())
	assert_int(restored.transaction_type).is_equal(TransactionContext.Type.STORY)
	assert_bool(restored.is_visit_story).is_true()


## [TC-04] desired_items with a bad path does NOT append null to typed array
## This catches the HIGH-4 bug: load() returning null appended to Array[ItemData]
func test_from_dict_bad_item_path_skips_null() -> void:
	var raw := {
		"transaction_type": TransactionContext.Type.PURCHASE,
		"desired_items": ["res://DOES_NOT_EXIST.tres"],  # invalid path
		"delivered_items": [],
		"requested_category": "",
		"best_item_name": "",
		"original_count": 0,
		"upgrade_to_best_tier": false,
		"is_next_tier_request": false,
		"event_hour": 0,
		"timeline_path": "",
		"is_placeholder": false,
		"is_riddle": false,
		"riddle_item_path": "",
		"wants_debt": false,
		"is_repaying": false,
		"repayment_amount": 0.0,
		"rumor_active": false,
		"rumor_type": 0.0,
		"is_visit_story": false,
		"story_advanced": false,
		"customer_data_path": "",
		"secondary_customer_data_path": "",
		"guest_spawns_later": false
	}
	var restored := TransactionContext.from_dict(raw)
	# Must not have any nulls in the typed array
	assert_int(restored.desired_items.size()).is_equal(0)


## [TC-05] Empty desired_items list survives round-trip
func test_roundtrip_empty_desired_items() -> void:
	var ctx := _make_context()
	ctx.desired_items.clear()
	var restored := TransactionContext.from_dict(ctx.to_dict())
	assert_int(restored.desired_items.size()).is_equal(0)


## [TC-06] to_dict produces all expected keys
func test_to_dict_has_required_keys() -> void:
	var ctx := _make_context()
	var d := ctx.to_dict()
	var required_keys := [
		"transaction_type", "customer_data_path", "desired_items",
		"delivered_items", "requested_category", "best_item_name",
		"original_count", "event_hour", "timeline_path",
		"is_placeholder", "is_riddle", "wants_debt",
		"is_repaying", "repayment_amount", "rumor_active",
		"rumor_type", "is_visit_story", "story_advanced"
	]
	for key in required_keys:
		assert_bool(d.has(key)).is_true()
