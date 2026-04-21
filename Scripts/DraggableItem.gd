class_name DraggableItem
extends WorldInteractor

signal drag_started
signal drag_ended

@export var item_data: ItemData

## Whether this item was spawned on the fly directly into dragging.
var is_transient: bool = false

## The plastic bag this item was taken from, if any.
var source_bag: PlasticDeliveryItem = null

## Full local transform at spawn time — used to tween item back to its slot.
var _original_transform: Transform3D = Transform3D.IDENTITY

@onready var sprite: Sprite3D = $Sprite3D
@onready var collider: CollisionShape3D = $CollisionShape3D

var is_hovered: bool = false
var is_mouse_inside: bool = false
var original_scale: Vector3 = Vector3.ONE
var _pricing_mode_active: bool = false

func _ready() -> void:
	super._ready()
	
	hover_scale_multiplier = 1.06 # Slightly enlarge when hovered
	
	if not Engine.is_editor_hint():
		add_to_group("draggable_items")
		# Connect to global drag events so we drop if clicked elsewhere
		# EventBus.drag_started.connect(_on_global_drag_started)
		original_scale = scale
		billboard_collision = false
	
	if item_data:
		setup(item_data)
	


## Configure this item with [param data] and place it at [param local_transform]
## in the parent surface's local coordinate space.
##
## [param local_transform] is supplied by the parent [ShelfSurface] via its
## [LayoutStrategy]. Defaults to [constant Transform3D.IDENTITY] so that
## items configured directly in the Inspector (without a ShelfSurface) stay
## at the position set in the scene tree.
func setup(data: ItemData, local_transform: Transform3D = Transform3D.IDENTITY, in_source_bag: PlasticDeliveryItem = null) -> void:
	source_bag = in_source_bag
	item_data = data
	
	# Defensive fetch in case setup is called before _ready
	if not sprite: sprite = get_node_or_null("Sprite3D")
	if not collider: collider = get_node_or_null("CollisionShape3D")
	
	if not sprite or not collider:
		push_error("[DraggableItem] Critical nodes missing from %s" % name)
		return

	# Apply the strategy-computed transform (position + tilt rotation)
	transform = local_transform
	# Store immediately — no deferred capture needed since transform is applied above
	_original_transform = local_transform

	if item_data and item_data.texture:
		sprite.texture = item_data.texture


		# --- Sizing ---
		# Guard against invalid display height
		var h: float = item_data.display_height_meters
		if h <= 0.0:
			push_warning("[DraggableItem] '%s': display_height_meters is <= 0, defaulting to 0.2" % item_data.item_name)
			h = 0.2

		# Reset any scale baked into the scene so pixel_size is the sole control
		sprite.scale = Vector3.ONE

		# --- Sizing ---
		var rect = item_data.get_used_rect()
		var v_h = float(rect.size.y) if rect.has_area() else float(item_data.texture.get_height())

		# pixel_size maps true visible height to real-world meters
		sprite.pixel_size = h / v_h

		# --- Offset & Alignment ---
		# Center the actual opaque pixels at the node's origin
		var tex_center = Vector2(item_data.texture.get_width(), item_data.texture.get_height()) / 2.0
		var opaque_center = Vector2(rect.position) + Vector2(rect.size) / 2.0

		# In Godot Sprite3D:
		# positive X offset moves texture right
		# positive Y offset moves texture UP
		var offset_x = tex_center.x - opaque_center.x
		var offset_y = opaque_center.y - tex_center.y 
		sprite.offset = Vector2(offset_x, offset_y)

		# Now that it's perfectly centered, shift it up to sit on the shelf
		sprite.position = Vector3.ZERO
		sprite.position.y = h / 2.0
		
		# --- Collision shape resize ---
		# Resize BoxShape3D to match the rendered sprite dimensions so picking
		# works correctly regardless of item size.
		var rendered_h: float = h
		var aspect: float = item_data.get_visual_aspect()
		var rendered_w: float = (
			item_data.display_width_override
			if item_data.display_width_override > 0.0
			else rendered_h * aspect
		)

		# --- Tilt (Z-axis roll on the Sprite3D) ---
		# Applied on the sprite itself so it's visible even with billboard=ENABLED.
		# The strategy encodes roll in the transform basis; extract and re-apply
		# to the sprite so the DraggableItem's own transform stays axis-aligned
		# (cleaner for physics / drag positioning).
		var roll_rad := local_transform.basis.get_euler().z
		sprite.rotation.z = roll_rad
		# Keep the DraggableItem's position-only transform (no rotation pollution)
		var pos_only := Transform3D(Basis(), local_transform.origin)
		transform = pos_only
		_original_transform = pos_only

		if collider.shape is BoxShape3D:
			collider.shape = collider.shape.duplicate()
			collider.shape.size = Vector3(rendered_w, rendered_h, 0.05) # Fixed thin depth
		collider.position.y = rendered_h / 2.0

	# UI is now handled by the global PricingOverlay



func on_hover(hovered: bool) -> void:
	self.is_hovered = hovered
	
	# Only call super on_hover if pricing mode is OFF.
	# This suppresses the giant white outline while in pricing mode.
	if hovered and _pricing_mode_active:
		_remove_outline()
	else:
		super.on_hover(hovered)
		
	_update_label_visibility()

func set_pricing_ui_active(active: bool) -> void:
	_pricing_mode_active = active
	
	# Re-trigger hover logic to immediately add/remove outline
	# if toggled while already hovering.
	on_hover(is_hovered)
	
	if active and is_hovered:
		update_pricing_ui()
	elif not active and is_hovered:
		_update_label_visibility()

func adjust_price(delta: float) -> void:
	if not item_data: return
	
	var base_price : float = item_data.price
	var current_price : float = item_data.get_final_price()
	
	# Range Rules: 
	# 1. Minimum: Base price.
	# 2. Maximum: Progressive margin based on tier. 25% (Tier 1) to 50% (Tier 10).
	var min_price : float = base_price
	var max_price : float = item_data.get_max_selling_price()
	
	var new_price : float = clamp(current_price + delta, min_price, max_price)
	
	item_data.selling_price = new_price
	
	if new_price > current_price:
		EventBus.price_increased.emit(item_data)
	
	# Refresh all items of this type (they share the resource)
	get_tree().call_group("draggable_items", "update_pricing_ui")
	# Also update containers if any of their item_data changed
	get_tree().call_group("pricing_ui_containers", "update_pricing_ui")

func _update_label_visibility() -> void:
	if not _pricing_mode_active or not is_hovered:
		# If we stop hovering while this was the active item, hide the overlay.
		# A global check could ensure we don't hide it if another item is already hovered,
		# but `on_hover(true)` on the new item will instantly show it again.
		if is_instance_valid(get_node_or_null("/root/PricingOverlay")):
			get_node("/root/PricingOverlay").hide_ui()
	elif _pricing_mode_active and is_hovered:
		update_pricing_ui()

func update_pricing_ui() -> void:
	if not item_data: return
	
	if not is_hovered or not _pricing_mode_active: return
	
	if is_instance_valid(get_node_or_null("/root/PricingOverlay")):
		get_node("/root/PricingOverlay").show_item(item_data, global_position)


func on_interact() -> void:
	if DragManager._is_dragging: return
	EventBus.request_sfx.emit("pickup")
	DragManager.start_drag(self, sprite.texture)

func _on_drag_started_by_manager() -> void:
	sprite.hide()
	if is_instance_valid(get_node_or_null("/root/PricingOverlay")):
		get_node("/root/PricingOverlay").hide_ui()
	drag_started.emit()

func _on_drag_cancelled_by_manager() -> void:
	show_visuals()
	drag_ended.emit()

func show_visuals() -> void:
	if not sprite: sprite = get_node_or_null("Sprite3D")
	if sprite:
		sprite.show()
	else:
		push_error("[DraggableItem] Cannot show visuals: Sprite3D is missing!")

## Notify the source bag (if any) that this item has been placed correctly.
func notify_placed() -> void:
	if source_bag and is_instance_valid(source_bag):
		if source_bag.has_method("notify_item_placed"):
			source_bag.notify_item_placed(self)
		source_bag = null # Only notify once

func return_to_start() -> void:
	EventBus.request_sfx.emit("drop")
	
	if is_transient:
		if source_bag and is_instance_valid(source_bag):
			source_bag.receive_item(self)
			return

		# Restore digital stock (fallback if no source bag)
		InventoryManager.return_item(item_data)
		
		# Now use the standardized disappear animation instead of sliding back
		play_disappear_animation()
		return

	# Standard shelf item behavior
	show_visuals()
	var tween := create_tween()
	# Restore full local transform (position only — tilt lives on the sprite node)
	tween.tween_property(self, "transform", _original_transform, 0.25)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			
	# Bounce scale effect on the sprite only (keeps physics area stable)
	var base_sprite_scale = Vector3.ONE
	sprite.scale = base_sprite_scale * Vector3(1.2, 0.8, 1.2) # Squash
	var scale_tween = create_tween()
	scale_tween.tween_property(sprite, "scale", base_sprite_scale * Vector3(0.9, 1.1, 0.9), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(sprite, "scale", base_sprite_scale, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

## Standard animation for "letting go" or trashing an item.
func play_disappear_animation() -> void:
	show_visuals()
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Shrink to zero quickly
	tween.tween_property(sprite, "scale", Vector3.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	# Fade out
	tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
	
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

## Emphasized "give" animation for successful sales.
func play_give_animation() -> void:
	show_visuals()
	var tween = create_tween()
	
	# Small initial pop UP and squash
	tween.set_parallel(true)
	tween.tween_property(sprite, "position:y", sprite.position.y + 0.1, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector3(1.2, 0.8, 1.2), 0.1).set_trans(Tween.TRANS_SINE)
	
	tween.set_parallel(false)
	
	# Then shrink away
	var shrink_tween = create_tween()
	shrink_tween.set_parallel(true)
	shrink_tween.tween_property(sprite, "scale", Vector3.ZERO, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	shrink_tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
	
	shrink_tween.set_parallel(false)
	shrink_tween.tween_callback(queue_free)
