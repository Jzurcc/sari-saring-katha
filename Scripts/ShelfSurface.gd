@tool
class_name ShelfSurface
extends Node3D

## A single shelf plank surface that procedurally places items.
##
## Place this node as a child of the physical shelf mesh, positioned at
## the LEFT edge of the wooden plank at plank height (Y=0 local = shelf surface).
## Items will pack rightward along local +X and vary along local ±Z.
##
## Configure [member shelf_width] to match the physical plank width.
## Assign a [LayoutStrategy] resource (e.g. [ProceduralPackStrategy]) to
## [member layout_strategy] in the Inspector.
##
## To add new container types (candy jars, racks, fridges), create a new
## [LayoutStrategy] subclass — this node requires no changes.
##
## Scene hierarchy example:
## [code]
## ShelfUnit (StaticBody3D)
##  ├─ MeshInstance3D
##  ├─ CollisionShape3D
##  ├─ Area3D               (collision disabled in Shelf.gd)
##  ├─ ShelfSurface         ← top plank
##  ├─ ShelfSurface         ← middle plank
##  └─ ShelfSurface         ← bottom plank
## [/code]

const DRAGGABLE_ITEM_SCENE: PackedScene = preload("res://Scenes/DraggableItem.tscn")

@export_group("Surface")

## Usable width of this shelf plank in metres. Should match the physical mesh.
@export var shelf_width: float = 1.0:
	set(v):
		shelf_width = v
		if Engine.is_editor_hint():
			_update_preview()

## Maximum number of items that can appear on this surface, regardless of
## how many items would physically fit. Acts as a hard cap.
@export var max_items: int = 10

@export_group("Filtering")

## Which ItemData.ItemType this surface accepts.
@export var accepted_type: ItemData.ItemType = ItemData.ItemType.SHELF

## Optional category filter. Empty array = accept all categories.
@export var accepted_categories: PackedStringArray = []

@export_group("Layout")

## The layout strategy resource that determines item placement.
## Assign a [ProceduralPackStrategy] (or any [LayoutStrategy] subclass)
## in the Inspector.
@export var layout_strategy: LayoutStrategy

# --- Internal ---

var _spawned: Array[DraggableItem] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		_update_preview()
		return
		
	# Clean up preview node in actual game
	var preview = get_node_or_null("__DebugPreview")
	if preview:
		preview.queue_free()

	# Validate required config before proceeding
	if shelf_width <= 0.0:
		push_error("[ShelfSurface] '%s': shelf_width must be > 0. Got: %f" % [name, shelf_width])
		return
	if not layout_strategy:
		push_error("[ShelfSurface] '%s': No layout_strategy assigned. Assign a ProceduralPackStrategy in the Inspector." % name)
		return

	# Wait one frame so InventoryManager autoload finishes initialising.
	await get_tree().process_frame
	populate()


## Query InventoryManager, run the layout strategy, and spawn DraggableItem nodes.
## Safe to call multiple times — clears existing items first.
func populate() -> void:
	_clear()

	if not layout_strategy:
		push_error("[ShelfSurface] '%s': Cannot populate — no layout_strategy." % name)
		return

	var items := _query_inventory()
	if items.is_empty():
		return

	var transforms := layout_strategy.compute_positions(items, shelf_width, max_items)

	var slot_indices := {}

	for i in range(transforms.size()):
		if i >= items.size():
			break

		var item = items[i]
		if not slot_indices.has(item):
			slot_indices[item] = 0
		var current_slot: int = slot_indices[item]
		slot_indices[item] += 1

		var d: DraggableItem = DRAGGABLE_ITEM_SCENE.instantiate()
		add_child(d)
		d.setup(items[i], transforms[i])
		d.set_meta("slot", current_slot)
		_spawned.append(d)

	print("[ShelfSurface] '%s' placed %d items (width: %.2fm)" % [name, _spawned.size(), shelf_width])


## Show or hide each spawned item based on current inventory stock.
## Call this after a transaction to update shelf visibility without repopulating.
func refresh_visibility() -> void:
	for d in _spawned:
		if is_instance_valid(d) and d.item_data:
			var stock := InventoryManager.get_stock(d.item_data)
			var slot: int = d.get_meta("slot", 0)
			# Hide items whose slot index exceeds current stock.
			d.visible = (slot < stock)


# --- Private ---

## Remove all spawned DraggableItem children.
func _clear() -> void:
	for d in _spawned:
		if is_instance_valid(d):
			d.queue_free()
	_spawned.clear()


## Query InventoryManager for items that match this surface's type and category
## filters, skipping items with no texture or zero stock.
func _query_inventory() -> Array[ItemData]:
	var result: Array[ItemData] = []

	for item in InventoryManager.get_all_items():
		# Type filter
		if item.type != accepted_type:
			continue
		# Category filter (empty = accept all)
		if accepted_categories.size() > 0 and item.category not in accepted_categories:
			continue
		# Texture guard — items without textures cannot be displayed
		if not item.texture:
			push_warning("[ShelfSurface] '%s': Skipping item '%s' — no texture." % [name, item.item_name])
			continue
			
		# Multiply by max_stock to place duplicates on the shelf
		for i in range(item.max_stock):
			result.append(item)

	return result


## Editor-only visual preview of the shelf width.
func _update_preview() -> void:
	var preview = get_node_or_null("__DebugPreview") as MeshInstance3D
	if not preview:
		preview = MeshInstance3D.new()
		preview.name = "__DebugPreview"
		add_child(preview)
		
		# Set up a semi-transparent yellow debug material
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 1.0, 0.0, 0.3)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		
		var box = BoxMesh.new()
		box.material = mat
		preview.mesh = box

	var preview_box = preview.mesh as BoxMesh
	# Create a thin debug block representing the shelf surface area
	preview_box.size = Vector3(shelf_width, 0.02, 0.2)
	# Position it so the left edge aligns with ShelfSurface X=0
	preview.position = Vector3(shelf_width / 2.0, 0.01, 0.0)
