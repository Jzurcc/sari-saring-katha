class_name DialogicBridge
extends RefCounted

## DialogicBridge — centralises ALL Dialogic VAR synchronization.
##
## Call sync_transaction(transaction, chapter, branch, arc) once after building
## a TransactionContext, rather than scattering set_variable() calls across StoryManager.
##
## All methods are static so no instance is needed — call DialogicBridge.sync_transaction(...)
## from anywhere.

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Synchronises a complete TransactionContext to Dialogic variables.
## Call this once after StoryManager finishes building a transaction.
static func sync_transaction(
	transaction: TransactionContext,
	chapter: float,
	branch: float,
	current_arc: float
) -> void:
	if not transaction or not transaction.customer_data:
		return

	# --- Item Strings ---
	var item_wants := _build_item_string(transaction)
	var item_wants_id := _build_item_id(transaction)
	var highest_item := _build_highest_item_name(transaction)
	var any_item := _pick_any_item_name(transaction)

	Dialogic.VAR.set_variable("Transaction_ItemWants", item_wants)
	Dialogic.VAR.set_variable("Transaction_ItemWantsID", item_wants_id)
	Dialogic.VAR.set_variable("Transaction_HighestItemWants", highest_item)
	Dialogic.VAR.set_variable("Transaction_ItemAnyWants", any_item)
	Dialogic.VAR.set_variable("Transaction_ItemWantsBest", transaction.best_item_name)

	# --- Customer Identity ---
	Dialogic.VAR.set_variable(
		"Transaction_CustomerName",
		transaction.customer_data.character_name if transaction.customer_data else ""
	)

	# --- Transaction Flags ---
	Dialogic.VAR.set_variable("Transaction_IsRiddle", 1.0 if transaction.is_riddle else 0.0)
	Dialogic.VAR.set_variable("Transaction_WantsDebt", 1.0 if transaction.wants_debt else 0.0)
	Dialogic.VAR.set_variable("Transaction_IsRepaying", 1.0 if transaction.is_repaying else 0.0)
	Dialogic.VAR.set_variable("Transaction_RepaymentAmount", transaction.repayment_amount)
	Dialogic.VAR.set_variable("Transaction_IsNextTier", 1.0 if transaction.is_next_tier_request else 0.0)
	Dialogic.VAR.set_variable(
		"Transaction_ItemHint",
		transaction.riddle_item.item_hint if transaction.is_riddle and transaction.riddle_item else ""
	)

	# --- Narrative State ---
	Dialogic.VAR.set_variable("Transaction_Chapter", chapter)
	Dialogic.VAR.set_variable("Transaction_Branch", branch)
	Dialogic.VAR.set_variable("Transaction_CurrentArc", current_arc)
	Dialogic.VAR.set_variable("Transaction_DeliveredCount", float(transaction.delivered_items.size()))
	Dialogic.VAR.set_variable("Transaction_RemainingCount", float(transaction.desired_items.size()))

	# --- Rumor ---
	Dialogic.VAR.set_variable("Global_RumorActive", 1.0 if transaction.rumor_active else 0.0)
	Dialogic.VAR.set_variable("Global_RumorType", transaction.rumor_type)

	# --- Random Variety Rolls (rolled fresh for each new transaction) ---
	Dialogic.VAR.set_variable("Transaction_GreetingVar", randf() * 100.0)
	Dialogic.VAR.set_variable("Transaction_TalkVar", randf() * 100.0)
	Dialogic.VAR.set_variable("Transaction_SatisfyVar", randf() * 100.0)
	Dialogic.VAR.set_variable("Transaction_WrongItemVar", randf() * 100.0)
	Dialogic.VAR.set_variable("Transaction_VisitVar", randf() * 100.0)


## Synchronises global game-state variables (call on load/day-start).
static func sync_global(day: int, tier: int, max_tier: int, quota_day: int) -> void:
	Dialogic.VAR.set_variable("Global_CurrentDay", float(day))
	Dialogic.VAR.set_variable("Global_CurrentTier", float(tier))
	Dialogic.VAR.set_variable("Global_MaxUnlockedTier", float(max_tier))
	Dialogic.VAR.set_variable("Global_QuotaDay", float(quota_day))


## Rebuilds the Transaction_ItemWants string and syncs to Dialogic.
## Used when desired_items changes mid-dialogue (e.g. upgrade_desires, fulfill_item).
static func sync_item_string(transaction: TransactionContext) -> void:
	if not transaction:
		return

	var item_wants := _build_item_string(transaction)
	var item_wants_id := _build_item_id(transaction)
	var highest_item := _build_highest_item_name(transaction)
	var any_item := _pick_any_item_name(transaction)

	Dialogic.VAR.set_variable("Transaction_ItemWants", item_wants)
	Dialogic.VAR.set_variable("Transaction_ItemWantsID", item_wants_id)
	Dialogic.VAR.set_variable("Transaction_HighestItemWants", highest_item)
	Dialogic.VAR.set_variable("Transaction_ItemAnyWants", any_item)
	Dialogic.VAR.set_variable("Transaction_DeliveredCount", float(transaction.delivered_items.size()))
	Dialogic.VAR.set_variable("Transaction_RemainingCount", float(transaction.desired_items.size()))
	Dialogic.VAR.set_variable("Transaction_IsNextTier", 1.0 if transaction.is_next_tier_request else 0.0)


# ---------------------------------------------------------------------------
# Private String Builders
# ---------------------------------------------------------------------------

static func _build_item_string(transaction: TransactionContext) -> String:
	if transaction.desired_items.is_empty():
		return ""
	var names: Array[String] = []
	for item in transaction.desired_items:
		names.append(item.item_name)
	return _join_names(names)


static func _build_item_id(transaction: TransactionContext) -> String:
	if transaction.desired_items.is_empty():
		return ""
	return transaction.desired_items[0].get_clean_id()


static func _build_highest_item_name(transaction: TransactionContext) -> String:
	var highest_tier := -1
	var highest_name := ""
	for item in transaction.desired_items:
		if item.tier > highest_tier:
			highest_tier = item.tier
			highest_name = item.item_name
	return highest_name


static func _pick_any_item_name(transaction: TransactionContext) -> String:
	if transaction.desired_items.is_empty():
		return ""
	return transaction.desired_items.pick_random().item_name


static func _join_names(names: Array[String]) -> String:
	match names.size():
		0: return ""
		1: return names[0]
		2: return names[0] + " and " + names[1]
	var last := names[-1]
	var rest := names.slice(0, names.size() - 1)
	return ", ".join(rest) + ", and " + last
