extends ColorRect

signal closed

@onready var collection_grid : GridContainer = %Grid

func _ready() -> void:
	pass

func open() -> void:
	show()
	_populate_collection()

func close() -> void:
	hide()
	closed.emit()

func _populate_collection() -> void:
	# Clear existing items
	for child in collection_grid.get_children():
		child.queue_free()
	
	# Load item cards
	var ItemCardScript = load("res://Scripts/UI/CollectionItemCard.gd")
	var all_items = InventoryManager.get_all_items()
	
	for item in all_items:
		if not item.can_be_sold:
			continue
			
		var card = PanelContainer.new()
		card.set_script(ItemCardScript)
		collection_grid.add_child(card)
		
		var unlocked = StoryManager.is_item_unlocked(item)
		card.setup(item, unlocked)
