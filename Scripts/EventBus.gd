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
signal customer_rejected(customer: Customer)

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

# --- Economy ---
@warning_ignore("unused_signal")
signal money_changed(new_amount: int)

# --- Drag & Drop ---
@warning_ignore("unused_signal")
signal drag_started(item: DraggableItem)
@warning_ignore("unused_signal")
signal drag_ended(item: DraggableItem, dropped_successfully: bool)