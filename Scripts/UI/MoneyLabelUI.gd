extends Label
class_name MoneyLabelUI

func _ready() -> void:
	EventBus.money_changed.connect(_on_money_changed)

func _on_money_changed(amount: int) -> void:
	text = "Peso: " + str(amount)
