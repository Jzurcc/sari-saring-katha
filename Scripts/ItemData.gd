class_name ItemData
extends Resource

enum ItemType {
	SHELF,
	FRIDGE,
	CANDY_CONTAINER,
	SACHET_CONTAINER
}

@export var item_name: String = "New Item"
@export var texture: Texture2D
## The restock cost (what you pay Uncle Mario).
@export var price: float = 10.0
## The current selling price to customers. Initialized to 105% of price if set to 0.
@export var selling_price: float = 0.0
## Whether the player has manually adjusted this price.
@export var is_manually_priced: bool = false
## If false, customers will never ask for this item (e.g. for containers/props).
@export var can_be_sold: bool = true
@export var type: ItemType = ItemType.SHELF
@export_enum("snack", "sachet", "can", "candy", "cigarette", "bottle", "pack", "frozen") var category: String = "snack"
@export var tier: int = 1
@export var item_hint: String = ""

func get_clean_id() -> String:
	if not resource_path.is_empty():
		return resource_path.get_file().get_basename().to_lower()
	return item_name.to_lower().replace(" ", "_")

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

func get_final_price() -> float:
	# Migration/Default: if selling_price hasn't been set, initialize it with a 10% margin
	if selling_price <= 0.0:
		var margin = 0.10
		selling_price = price + round(price * margin)
		
	# Floor constraint: selling price can never be below base price
	if selling_price < price:
		selling_price = price
		
	return selling_price

func get_max_selling_price() -> float:
	var base_price : float = price
	var tier_val : int = max(1, tier)
	# Max margin: 35% (Tier 1) to 60% (Tier 10)
	var max_margin : float = 0.35 + (float(tier_val) - 1.0) * (0.25 / 9.0)
	var max_p : float = base_price * (1.0 + max_margin)
	
	# Rule: If potential max <= 15, add 3 pesos (Lifeline for cheap items)
	if max_p <= 15.0:
		max_p += 3.0
		
	return snapped(max_p, 0.5)
