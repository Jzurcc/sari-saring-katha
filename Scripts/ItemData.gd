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
@export var id: String = ""

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

var _cached_aspect: float = -1.0

## Calculates and caches the true aspect ratio (width / height) by extracting
## the opaque bounding box of the texture, ignoring transparent padding.
func get_visual_aspect() -> float:
	if _cached_aspect > 0.0:
		return _cached_aspect
		
	if not texture:
		_cached_aspect = 1.0
		return _cached_aspect
		
	var image: Image = texture.get_image()
	if image:
		var used_rect := image.get_used_rect()
		if used_rect.has_area():
			_cached_aspect = float(used_rect.size.x) / float(used_rect.size.y)
			return _cached_aspect

	var h := texture.get_height()
	_cached_aspect = float(texture.get_width()) / float(h) if h > 0 else 1.0
	return _cached_aspect
