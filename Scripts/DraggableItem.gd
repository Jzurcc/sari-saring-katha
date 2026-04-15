class_name DraggableItem
extends WorldInteractor

signal drag_started
signal drag_ended

@export var item_data: ItemData

const INDER_FONT := preload("res://Assets/Fonts/Inder/Inder-Regular.ttf")

## Whether this item was spawned on the fly directly into dragging.
var is_transient: bool = false

## Full local transform at spawn time — used to tween item back to its slot.
var _original_transform: Transform3D = Transform3D.IDENTITY

@onready var sprite: Sprite3D = $Sprite3D
@onready var collider: CollisionShape3D = $CollisionShape3D

# --- New Pricing UI Nodes (Created in code for cleaner management) ---
var pricing_ui: Sprite3D
var pricing_viewport: SubViewport
var name_label: Label
var price_label: Label
var comparison_label: Label
var pricing_panel: PanelContainer

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
		billboard_collision = true
	
	if item_data:
		setup(item_data)


## Configure this item with [param data] and place it at [param local_transform]
## in the parent surface's local coordinate space.
##
## [param local_transform] is supplied by the parent [ShelfSurface] via its
## [LayoutStrategy]. Defaults to [constant Transform3D.IDENTITY] so that
## items configured directly in the Inspector (without a ShelfSurface) stay
## at the position set in the scene tree.
func setup(data: ItemData, local_transform: Transform3D = Transform3D.IDENTITY) -> void:
	item_data = data

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
		if collider.shape is BoxShape3D:
			collider.shape = collider.shape.duplicate()
			collider.shape.size = Vector3(rendered_w, rendered_h, max(0.1, rendered_w))
		collider.position.y = rendered_h / 2.0

	_setup_pricing_ui()


func _setup_pricing_ui() -> void:
	# 1. SubViewport for 2D UI rendering
	pricing_viewport = SubViewport.new()
	pricing_viewport.transparent_bg = true
	# Higher resolution for sharper text
	pricing_viewport.size = Vector2(666, 208)
	pricing_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(pricing_viewport)

	# 2. PanelContainer for the "Modern" look
	pricing_panel = PanelContainer.new()
	pricing_viewport.add_child(pricing_panel)
	pricing_panel.size = Vector2(666, 208)
	pricing_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var style := StyleBoxFlat.new()
	# Glassmorphic transparency: 0.5 alpha as requested
	style.bg_color = Color(0.082, 0.078, 0.071, 0.5) 
	style.set_corner_radius_all(26)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	pricing_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pricing_panel.add_child(vbox)

	# 3. Label: Name
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 23)
	name_label.add_theme_color_override("font_color", Color(1, 0.92, 0.79, 0.8)) # Slightly faded cream
	vbox.add_child(name_label)

	# 4. Label: Main Price
	price_label = Label.new()
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 47)
	price_label.add_theme_color_override("font_color", Color(1, 0.92, 0.79)) # Warm cream
	vbox.add_child(price_label)

	# 5. Label: Comparison (Base -> Selling)
	comparison_label = Label.new()
	comparison_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	comparison_label.add_theme_font_size_override("font_size", 21)
	comparison_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6)) # Greyed out
	vbox.add_child(comparison_label)
	
	# Use preloaded font for all labels
	if INDER_FONT:
		name_label.add_theme_font_override("font", INDER_FONT)
		price_label.add_theme_font_override("font", INDER_FONT)
		comparison_label.add_theme_font_override("font", INDER_FONT)

	# 4. Sprite3D to display the viewport in 3D space
	pricing_ui = Sprite3D.new()
	pricing_ui.texture = pricing_viewport.get_texture()
	pricing_ui.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pricing_ui.no_depth_test = true
	pricing_ui.fixed_size = true
	# Scale down the sprite so the high-res text is appropriate size on screen
	pricing_ui.pixel_size = 0.001
	pricing_ui.alpha_cut = Sprite3D.ALPHA_CUT_DISABLED
	pricing_ui.transparent = true
	pricing_ui.shaded = false # DISALED SHADING for proper UI transparency
	pricing_ui.render_priority = 10
	add_child(pricing_ui)
	
	pricing_ui.hide()


func get_visual_nodes() -> Array[Node3D]:
	var nodes = super.get_visual_nodes()
	if pricing_ui in nodes:
		nodes.erase(pricing_ui)
	return nodes



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
	_update_label_visibility()
	
	# Re-trigger hover logic to immediately add/remove outline
	# if toggled while already hovering.
	on_hover(is_hovered)
	
	if active:
		update_pricing_ui()

func _update_label_visibility() -> void:
	if pricing_ui:
		pricing_ui.visible = is_hovered and _pricing_mode_active

func update_pricing_ui() -> void:
	if not price_label or not item_data: return
	
	var final_price = item_data.get_final_price()
	var base_price = item_data.price
	
	name_label.text = item_data.item_name
	price_label.text = "₱%.2f" % [final_price]
	comparison_label.text = "₱%.2f → ₱%.2f" % [base_price, final_price]
	
	# Position at center of item height and push forward (Z = 0.1)
	if pricing_ui:
		pricing_ui.position.y = item_data.display_height_meters / 2.0
		pricing_ui.position.z = 0.15 # Pushed more to the front

func on_interact() -> void:
	if DragManager._is_dragging: return
	EventBus.request_sfx.emit("pickup")
	DragManager.start_drag(self, sprite.texture)

func _on_drag_started_by_manager() -> void:
	sprite.hide()
	if pricing_ui: pricing_ui.hide()
	drag_started.emit()

func _on_drag_cancelled_by_manager() -> void:
	show_visuals()
	drag_ended.emit()

func show_visuals() -> void:
	sprite.show()

func return_to_start() -> void:
	EventBus.request_sfx.emit("drop")
	
	if is_transient:
		InventoryManager.return_item(item_data)
		queue_free()
		return
		
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
