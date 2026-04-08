extends Label
class_name HeldItemLabelUI

func _ready() -> void:
	visible = false
	EventBus.transaction_completed.connect(_on_transaction_completed)
	EventBus.drag_ended.connect(_on_drag_ended)

func _on_transaction_completed(item: ItemData, was_correct: bool) -> void:
	if was_correct and item:
		text = item.item_name
		visible = true

func _on_drag_ended(_item, _success) -> void:
	pass
