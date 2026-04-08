extends Node

## Central event bus for decoupled communication between game systems.
## Systems emit signals they own; other systems subscribe to what they care about.

# --- Customer lifecycle ---
signal customer_spawned(customer: Customer)
signal customer_arrived(customer: Customer)
signal customer_satisfied(customer: Customer)
signal customer_rejected(customer: Customer)

# --- Transactions ---
signal transaction_started(item: ItemData)
signal transaction_completed(item: ItemData, was_correct: bool)

# --- Progression ---
signal day_ended(day_number: int)
signal day_started(day_number: int)

# --- Economy ---
signal money_changed(new_amount: int)

# --- Drag & Drop ---
signal drag_started(item: DraggableItem)
signal drag_ended(item: DraggableItem, dropped_successfully: bool)