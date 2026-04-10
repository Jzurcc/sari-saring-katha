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
@export var max_stock: int = 5
@export var category: String = "food"
## Unique identifier for this item. Matches the .tres filename, lowercase.
## Used for transaction matching. Set via patch_item_ids.py or the Inspector.
@export var id: String = "unset"

@export_group("Display")
## Real-world height of the item on the shelf in meters.
## Drives pixel_size on Sprite3D automatically.
## Default 0.2m (~small can). Increase for tall boxes, decrease for sachets.
@export var display_height_meters: float = 0.2
## Optional manual width override in meters. Set to 0.0 to auto-compute
## from the texture's aspect ratio (recommended).
@export var display_width_override: float = 0.0
## Item's own lean preference in degrees (Z-axis roll).
## Added on top of the container's tilt_variance_deg.
## Positive = leans right, negative = leans left.
@export var tilt_offset_deg: float = 0.0

@export_group("Layout")
## The pre-calculated opaque bounding box of the texture (in pixels).
## Used to perfectly trim transparent padding so items pack flush together.
@export var opaque_rect: Rect2i = Rect2i()

func get_used_rect() -> Rect2i:
	if opaque_rect.has_area():
		return opaque_rect
		
	if not texture:
		return Rect2i()

	return Rect2i(0, 0, texture.get_width(), texture.get_height())

func get_visual_aspect() -> float:
	var rect = get_used_rect()
	if rect.has_area() and rect.size.y > 0:
		return float(rect.size.x) / float(rect.size.y)
	return 1.0
