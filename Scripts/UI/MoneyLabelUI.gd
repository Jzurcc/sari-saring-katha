extends Label
class_name MoneyLabelUI

func _ready() -> void:
	EventBus.money_changed.connect(_on_money_changed)

func _on_money_changed(amount: float) -> void:
	text = "₱ %.2f" % amount
