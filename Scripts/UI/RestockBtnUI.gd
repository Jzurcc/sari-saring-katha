extends TextureRect

func _ready() -> void:
	EventBus.restock_screen_opened.connect(_on_restock_opened)
	EventBus.restock_screen_closed.connect(_on_restock_closed)

func _on_restock_opened() -> void:
	hide()

func _on_restock_closed() -> void:
	show()
