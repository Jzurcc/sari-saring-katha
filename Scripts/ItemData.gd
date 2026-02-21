class_name ItemData
extends Resource

enum ItemType {
	SHELF,
	FRIDGE
}

@export var item_name: String = "New Item"
@export var texture: Texture2D
@export var price: int = 10
@export var type: ItemType = ItemType.SHELF
