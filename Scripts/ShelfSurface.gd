@tool
class_name ShelfSurface
extends Node3D

## A single shelf plank surface that procedurally places items.
##
## Place this node as a child of the physical shelf mesh, positioned at
## the LEFT edge of the wooden plank at plank height (Y=0 local = shelf surface).
## Items will pack rightward along local +X and vary along local ±Z.
##
## Drag [ItemData] resources into [member items] in the Inspector to assign
## which specific items appear on this plank. Each entry in [member items]
## represents one physical copy of that product on the shelf.
##
## Configure [member shelf_width] to match the physical plank width.
## Assign a [LayoutStrategy] resource (e.g. [ProceduralPackStrategy]) to
## [member layout_strategy] in the Inspector.
##
## [member accepted_type] and [member accepted_categories] act as guards
## for drag-and-drop — they do NOT auto-populate the shelf.
##
## Scene hierarchy example:
## [code]
## ShelfUnit (StaticBody3D)
##  ├─ MeshInstance3D
##  ├─ CollisionShape3D
##  ├─ ShelfSurface         ← top plank   (items = [Anoba, Anoba, Dantes])
##  ├─ ShelfSurface         ← middle plank (items = [Patos, Patos])
##  └─ ShelfSurface         ← bottom plank (items = [])
## [/code]

const DRAGGABLE_ITEM_SCENE: PackedScene = preload("res://Scenes/DraggableItem.tscn")

@export_group("Items")

## The items that appear on this plank. Each entry = one physical copy.
## Drag [ItemData] .tres resources here directly in the Inspector.
## Duplicates are allowed — add Anoba three times to show three bags.
@export var items: Array[ItemData] = []

@export_group("Surface")

## Usable width of this shelf plank in metres. Should match the physical mesh.
@export var shelf_width: float = 1.0:
	set(v):
		shelf_width = v
		if Engine.is_editor_hint():
			_update_preview()

@export_group("Drop Guards")

## Optional. If not empty, only items matching these categories can be dropped here.
@export var allowed_categories: PackedStringArray = []

## Optional. Items matching these categories will be rejected.
@export var rejected_categories: PackedStringArray = []

@export_group("Layout")

## Whether this is a shelf for dry goods or a fridge for cold items.
@export var surface_type: ItemData.ItemType = ItemData.ItemType.SHELF

## The layout strategy resource that determines item placement.
## Assign a [ProceduralPackStrategy] (or any [LayoutStrategy] subclass)
## in the Inspector.
@export var layout_strategy: LayoutStrategy

## Width of each slot in metres. The strategy divides [member shelf_width]
## into evenly spaced slots of this size. Items snap to the nearest empty
## slot when dropped. Should roughly match the widest item you plan to stock.
@export var slot_width: float = 0.4

@export_group("Persistence")
## Unique identifier for this shelf to persist its items. 
## If empty, the shelf will not save/load its contents.
@export var save_id: String = ""

# --- Internal ---

var _spawned: Array[DraggableItem] = []
## Pre-generated world-local transforms, one per slot across the shelf.
var _slot_transforms: Array[Transform3D] = []
## Which DraggableItem occupies each slot index. null = empty.
var _slot_occupants: Array = []  # Array[DraggableItem?]
var _is_loading: bool = false
var _data_was_loaded: bool = false

func _ready() -> void:
	# 1. Auto-generate save_id if empty based on hierarchy
	if save_id == "":
		save_id = "shelf_" + get_parent().name + "_" + name
		print("[ShelfSurface] Auto-generated save_id: ", save_id)
		
	# 2. Join persistence groups
	add_to_group("shelf_surface")
	add_to_group("persist")
	if surface_type == ItemData.ItemType.FRIDGE:
		add_to_group("fridge_surfaces")
		
	# Propagate groups to parent body to ensure gaze raycast (which hits bodies) 
	# correctly identifies the physical shelf/fridge as part of the tutorial targets.
	if get_parent() is CollisionObject3D:
		get_parent().add_to_group("shelf_surface")
		if surface_type == ItemData.ItemType.FRIDGE:
			get_parent().add_to_group("fridge_surfaces")

	# Validate required config before proceeding
	if shelf_width <= 0.0:
		push_error("[ShelfSurface] '%s': shelf_width must be > 0. Got: %f" % [name, shelf_width])
		return
	if not layout_strategy:
		push_error("[ShelfSurface] '%s': No layout_strategy assigned." % name)
		return

	if Engine.is_editor_hint():
		_update_preview()
		return
		
	# Clean up preview node in actual game
	var preview = get_node_or_null("__DebugPreview")
	if preview:
		preview.queue_free()

	_create_drop_zone()
	
	if not layout_strategy:
		push_error("[ShelfSurface] '%s': No layout_strategy assigned." % name)
		return

	# Free the slot when any item on this surface is picked up.
	EventBus.drag_started.connect(_on_any_drag_started)

	await get_tree().process_frame
	
	# Always populate with Inspector defaults first, BUT ONLY if no save data was loaded.
	# If a save file exists, SaveManager.request_load() will call load_save_data()
	# which clears and rebuilds from saved state. This removes the timing race
	# that caused empty shelves when a stray save existed before full game load.
	if not _data_was_loaded:
		populate()
	else:
		print("[ShelfSurface] '%s' skipping populate() because data was already loaded." % save_id)


## Create a thin Area3D covering the shelf surface so DragManager's
## area-only raycast can detect drops without body collision.
func _create_drop_zone() -> void:
	var area := Area3D.new()
	area.name = "__DropZone"
	area.add_to_group("shelf_drop_zone")
	# Layer 2 = drop zones only. Layer 1 = interactive items (DraggableItem, tray).
	# This keeps PlayerInteraction's layer-1-only raycast from hitting drop zones.
	area.collision_layer = 2
	area.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(shelf_width, 0.4, 0.5)
	cs.shape = box
	area.add_child(cs)
	area.position = Vector3(shelf_width / 2.0, 0.2, 0.0)
	add_child(area)


## Spawn [DraggableItem] nodes for each entry in [member items],
## filling slots left-to-right from the pre-generated slot list.
## Safe to call multiple times — clears existing spawns first.
func populate() -> void:
	_clear()

	if not layout_strategy:
		push_error("[ShelfSurface] '%s': Cannot populate — no layout_strategy." % name)
		return

	# Regenerate slots every time we populate (random tilt/depth per session).
	_slot_transforms = layout_strategy.generate_slots(shelf_width, slot_width)
	_slot_occupants.clear()
	_slot_occupants.resize(_slot_transforms.size())
	_slot_occupants.fill(null)

	# Build the validated item list.
	var spawn_list: Array[ItemData] = []
	for item in items:
		if not item:
			continue
		if not item.texture:
			push_warning("[ShelfSurface] '%s': Skipping '%s' — no texture." % [name, item.item_name])
			continue
		
		# Guard: Only allow items that match this surface's type (SHELF vs FRIDGE vs etc)
		if item.type != surface_type:
			push_warning("[ShelfSurface] '%s': Skipping '%s' — type mismatch (Item: %d, Surface: %d)." % [name, item.item_name, item.type, surface_type])
			continue
			
		spawn_list.append(item)

	if spawn_list.is_empty():
		return

	# Assign each item to the next available slot (left-to-right).
	var slot_idx := 0
	for item in spawn_list:
		if slot_idx >= _slot_transforms.size():
			push_warning("[ShelfSurface] '%s': No more slots for '%s'." % [name, item.item_name])
			break
		var d: DraggableItem = DRAGGABLE_ITEM_SCENE.instantiate()
		add_child(d)
		d.setup(item, _slot_transforms[slot_idx])
		d.set_meta("slot_index", slot_idx)
		_slot_occupants[slot_idx] = d
		_spawned.append(d)
		slot_idx += 1

	print("[ShelfSurface] '%s' placed %d/%d items in %d slots" % [name, _spawned.size(), spawn_list.size(), _slot_transforms.size()])


## Show or hide each spawned item based on whether its slot is occupied.
## Call this after any operation that may have changed slot occupancy.
func refresh_visibility() -> void:
	for i in range(_slot_occupants.size()):
		var d = _slot_occupants[i]
		if d != null and is_instance_valid(d):
			d.show_visuals()


## Accept a [DraggableItem] dropped from a drag.
## [param world_hit_pos]: The world-space point where the ray hit the drop zone.
## The item snaps to the nearest empty slot to that position.
func receive_item(item: DraggableItem, world_hit_pos: Vector3 = Vector3.ZERO) -> void:
	if not item or not item.item_data:
		return
	if not accepts_drop(item.item_data):
		push_warning("[ShelfSurface] '%s': Rejected drop of '%s' — type/category mismatch." % [name, item.item_data.item_name])
		item._on_drag_cancelled_by_manager()
		item.return_to_start()
		return

	# Find the nearest empty slot to the player's aim point.
	var local_x := to_local(world_hit_pos).x if world_hit_pos != Vector3.ZERO else shelf_width * 0.5
	var target_idx := _find_nearest_empty_slot(local_x)

	if target_idx < 0:
		push_warning("[ShelfSurface] '%s': No empty slot available for '%s'." % [name, item.item_data.item_name])
		item._on_drag_cancelled_by_manager()
		item.return_to_start()
		return

	# Re-parent item to this surface.
	var old_parent := item.get_parent()
	if old_parent and old_parent != self:
		# Clear the item's slot on the source shelf before moving it so the
		# source doesn't continue tracking a node it no longer owns.
		if old_parent.has_method("_free_slot_for"):
			old_parent._free_slot_for(item)
		old_parent.remove_child(item)
		add_child(item)
	if item not in _spawned:
		_spawned.append(item)

	# Occupy the slot.
	_slot_occupants[target_idx] = item
	item.set_meta("slot_index", target_idx)
	item.notify_placed()

	var target_pos := _slot_transforms[target_idx].origin

	# Update _original_transform to the new slot so return_to_start()
	# correctly snaps back to this shelf/slot if a later drag is cancelled.
	item._original_transform = Transform3D(Basis(), target_pos)
	item.is_transient = false # No longer transient once it has a shelf home

	# Snap to slot XY immediately, then ease backward in Z (push-back onto shelf feel).
	item.show_visuals()
	item.position = Vector3(target_pos.x, target_pos.y, target_pos.z + 0.18)
	var tween := item.create_tween()
	tween.tween_property(item, "position", target_pos, 0.15)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Spawn impact dust at the final snapped global position
	VisualEffectManager.spawn_impact_dust(to_global(target_pos))

	print("[ShelfSurface] '%s' received '%s' → slot %d (X=%.2f)" % [name, item.item_data.item_name, target_idx, target_pos.x])


## Returns an array of indices for all currently unoccupied slots.
func get_empty_slots() -> Array[int]:
	var empty_indices: Array[int] = []
	for i in _slot_transforms.size():
		if _slot_occupants[i] == null or not is_instance_valid(_slot_occupants[i]):
			empty_indices.append(i)
	return empty_indices


## Programmatically spawn an item into a specific slot index.
## Returns the newly created DraggableItem instance.
func place_item_in_slot(item: ItemData, slot_idx: int) -> DraggableItem:
	if slot_idx < 0 or slot_idx >= _slot_transforms.size():
		return null
		
	var d: DraggableItem = DRAGGABLE_ITEM_SCENE.instantiate()
	add_child(d)
	d.setup(item, _slot_transforms[slot_idx])
	d.set_meta("slot_index", slot_idx)
	_slot_occupants[slot_idx] = d
	_spawned.append(d)
	
	var target_pos := _slot_transforms[slot_idx].origin
	d.position = target_pos
	d.show_visuals()
	
	return d


# --- Private ---

## Remove all spawned DraggableItem children.
func _clear() -> void:
	for d in _spawned:
		if is_instance_valid(d):
			d.queue_free()
	_spawned.clear()
	# Do not resize or fill _slot_occupants here — populate() always rebuilds
	# the array to the correct slot count immediately after calling _clear().


## Return the index of the slot with the smallest X distance to [param local_x].
## Returns -1 if all slots are occupied.
func _find_nearest_empty_slot(local_x: float) -> int:
	var best_idx := -1
	var best_dist := INF
	for i in _slot_transforms.size():
		if _slot_occupants[i] != null and is_instance_valid(_slot_occupants[i]):
			continue  # occupied
		var dist := absf(_slot_transforms[i].origin.x - local_x)
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	return best_idx


## Free this surface's slot when any of its items is picked up.
func _on_any_drag_started(dragged: DraggableItem) -> void:
	_free_slot_for(dragged)


## Release whichever slot [param item] occupies on this surface.
## Called internally on drag-start and by neighbour surfaces on cross-shelf drops.
func _free_slot_for(item: DraggableItem) -> void:
	var idx := _slot_occupants.find(item)
	if idx >= 0:
		_slot_occupants[idx] = null



## Returns true if [param item] is allowed to be dropped onto this surface
## based on the [member surface_type] and category guards.
func accepts_drop(item: ItemData) -> bool:
	if not item:
		return false
	if item.type != surface_type:
		return false
	if rejected_categories.has(item.category):
		return false
	if allowed_categories.size() > 0 and not allowed_categories.has(item.category):
		return false
	return true


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
		box.resource_local_to_scene = true
		preview.mesh = box

	var preview_box: BoxMesh
	if preview.mesh and preview.mesh is BoxMesh:
		preview_box = preview.mesh as BoxMesh
		if not preview_box.resource_local_to_scene:
			preview_box = preview_box.duplicate(true) as BoxMesh
			preview_box.resource_local_to_scene = true
			preview.mesh = preview_box
	else:
		preview_box = BoxMesh.new()
		preview_box.resource_local_to_scene = true
		preview.mesh = preview_box
		
	# Create a thin debug block representing the shelf surface area
	preview_box.size = Vector3(shelf_width, 0.02, 0.2)
	# Position it so the left edge aligns with ShelfSurface X=0
	preview.position = Vector3(shelf_width / 2.0, 0.01, 0.0)

# --- Persistence ---

func get_save_id() -> String:
	return save_id

func get_save_data() -> Dictionary:
	var slots := []
	for i in range(_slot_occupants.size()):
		var occupant = _slot_occupants[i]
		if occupant != null and is_instance_valid(occupant) and occupant.item_data:
			slots.append({"slot": i, "item_path": occupant.item_data.resource_path})
	return {"slots": slots}

func load_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
		
	print("[ShelfSurface] '%s' applying save data: %s" % [save_id, data.keys()])
	_is_loading = true
	_data_was_loaded = true
	_clear()
	
	# Rebuild slot transforms
	if not layout_strategy:
		_is_loading = false
		return
	_slot_transforms = layout_strategy.generate_slots(shelf_width, slot_width)
	_slot_occupants.clear()
	_slot_occupants.resize(_slot_transforms.size())
	_slot_occupants.fill(null)
	
	var slots_data: Array = data.get("slots", [])
	var placed := 0
	for entry in slots_data:
		var slot_idx: int = entry.get("slot", -1)
		var item_path: String = entry.get("item_path", "")
		
		# Guard: slot index must be within current shelf bounds
		if slot_idx < 0 or slot_idx >= _slot_transforms.size():
			push_warning("[ShelfSurface] '%s': Skipping slot %d — out of bounds (max %d)" % [name, slot_idx, _slot_transforms.size() - 1])
			continue
		
		# Guard: resource must exist
		if not ResourceLoader.exists(item_path):
			push_warning("[ShelfSurface] '%s': Skipping slot %d — resource not found: %s" % [name, slot_idx, item_path])
			continue
		
		var item_res = load(item_path) as ItemData
		if item_res:
			place_item_in_slot(item_res, slot_idx)
			placed += 1
	
	_is_loading = false
	print("[ShelfSurface] '%s' loaded %d/%d saved items" % [name, placed, slots_data.size()])
