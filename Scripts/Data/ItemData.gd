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
## Current discrete pricing step: -3 (loss leader) to +3 (heavy markup). 0 = wholesale cost.
@export var current_step: int = 0
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

## Calculates the peso increment per step for this product based on wholesale cost and tier.
## Formula: 10% of cost for Tier 1, +2.5% per extra tier. Minimum 2.0 pesos.
func get_step_increment() -> float:
	var step_pct: float = 0.10 + float(max(1, tier) - 1) * 0.025
	return max(2.0, snapped(price * step_pct, 0.5))

## Calculates the selling price for a given discrete step (-3 to +3).
## Step 0 = wholesale cost (price). Negative steps sell at a loss.
func get_price_for_step(step_idx: int) -> float:
	var clamped_step := clampi(step_idx, -3, 3)
	var inc := get_step_increment()
	return max(1.0, snapped(price + float(clamped_step) * inc, 0.5))

## Calculates the nearest discrete step (-3 to +3) corresponding to a given price.
func get_step_from_price(target_price: float) -> int:
	var inc := get_step_increment()
	if inc <= 0.001:
		return 0
	var calc_step := roundi((target_price - price) / inc)
	return clampi(calc_step, -3, 3)

## Returns the current final selling price.
func get_final_price() -> float:
	if not is_manually_priced and selling_price <= 0.0:
		current_step = 0
		selling_price = get_price_for_step(0)
	elif is_manually_priced and selling_price > 0.0 and current_step == 0:
		# Sync step from existing selling_price if step was uninitialized
		current_step = get_step_from_price(selling_price)
		selling_price = get_price_for_step(current_step)
	else:
		selling_price = get_price_for_step(current_step)
		
	return max(1.0, selling_price)

## Returns the maximum selling price (at step +3).
func get_max_selling_price() -> float:
	return get_price_for_step(3)

## Returns the minimum selling price (at step -3).
func get_min_selling_price() -> float:
	return get_price_for_step(-3)
