extends Node

## Central event bus for decoupled communication between game systems.
## Systems emit signals they own; other systems subscribe to what they care about.

# --- Customer lifecycle ---
@warning_ignore("unused_signal")
signal customer_spawned(customer: Customer)
@warning_ignore("unused_signal")
signal customer_arrived(customer: Customer)
@warning_ignore("unused_signal")
signal customer_satisfied(customer: Customer)
@warning_ignore("unused_signal")
signal customer_partial_satisfaction(customer: Customer)
@warning_ignore("unused_signal")
signal customer_rejected(customer: Customer)
@warning_ignore("unused_signal")
signal customer_dismissed(customer: Customer)
@warning_ignore("unused_signal")
signal dialogue_character_speaking(customer_data: CustomerData)


# --- Transactions ---
@warning_ignore("unused_signal")
signal transaction_started(item: ItemData)
@warning_ignore("unused_signal")
signal transaction_completed(item: ItemData, was_correct: bool)

# --- Progression ---
@warning_ignore("unused_signal")
signal day_ended(day_number: int)
@warning_ignore("unused_signal")
signal day_started(day_number: int)
@warning_ignore("unused_signal")
signal closing_time_reached()
@warning_ignore("unused_signal")
signal tier_advanced(new_tier: int, source: String)
@warning_ignore("unused_signal")
signal upgrade_available(new_tier: int, cost: float, items: Array[ItemData])
@warning_ignore("unused_signal")
signal purchase_made()

# --- Economy ---
@warning_ignore("unused_signal")
signal money_changed(new_amount: float)
@warning_ignore("unused_signal")
signal insufficient_funds()
@warning_ignore("unused_signal")
signal pricing_mode_changed(is_active: bool)
@warning_ignore("unused_signal")
signal utang_accepted(customer: Customer)
@warning_ignore("unused_signal")
signal utang_rejected(customer: Customer)
@warning_ignore("unused_signal")
signal debt_quota_met(is_successful: bool)

# --- Nokia / Phone UI ---
@warning_ignore("unused_signal")
signal nokia_opened()
@warning_ignore("unused_signal")
signal nokia_closed()

# --- Drag & Drop ---
@warning_ignore("unused_signal")
signal drag_started(item: DraggableItem)
@warning_ignore("unused_signal")
signal drag_ended(item: DraggableItem, dropped_successfully: bool)

# --- Juice & Feedback ---
@warning_ignore("unused_signal")
signal request_camera_shake(intensity: float, duration: float)
@warning_ignore("unused_signal")
signal request_sfx(sfx_name: String)
@warning_ignore("unused_signal")
signal show_notification(message: String, sub_message: String, sfx_to_play: String)
