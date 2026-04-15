class_name MainGame
extends Node3D

# --- MainGame: Dramatically simplified via architectural rewrite ---
# All physics and input are handled by FPSController.gd
# All dragging is handled by EventBus and DragManager
# All time logic is handled by DayNightManager
# -----------------------------------------------------------------

var _debug_show_collisions: bool = false
@onready var tray: TransactionTray

func _ready() -> void:
	# Ensure camera is correctly scaled to 75 as a fallback
	await get_tree().process_frame
	var camera = $Player/Head/Camera3D
	if camera and camera.fov != 75:
		camera.fov = 75.0

	# Ensure Transaction tray exists
	var tray_nodes := get_tree().get_nodes_in_group("transaction_tray")
	if tray_nodes.size() > 0:
		tray = tray_nodes[0] as TransactionTray
	else:
		push_error("[MainGame] Missing Transaction Tray in Scene")

	# Connect the tray to the generic event bus instead of handling logic here
	tray.item_placed.connect(_on_tray_item_placed)

func _on_tray_item_placed(item: DraggableItem) -> void:
	# Check if we have an active customer
	# The generic flow is: Item -> Tray -> Signal emitted
	# We query the active customer directly from the signal bus or CustomerSpawner
	EventBus.transaction_started.emit(item.item_data)
	
	var handled = false
	var spawners = get_tree().get_nodes_in_group("customer_spawner")
	if spawners.size() > 0:
		var spawner := spawners[0] as CustomerSpawner
		var customer = spawner.current_customer
		if customer and customer.is_waiting:
			handled = true
			var is_correct = customer.check_item(item.item_data)
			var context = customer.transaction_context
			
			if is_correct:
				EventBus.request_camera_shake.emit(0.1, 0.15) # Small physical bump for selling
				EventBus.transaction_completed.emit(item.item_data, true)
				InventoryManager.take_item(item.item_data)
				item.hide()
				# We removed the Dialogic.current_timeline == null check so that CustomerSpawner
				# can intelligently jump to the 'Satisfy' label even if a 'Greeting' was playing.
				# Only trigger Satisfy if the whole order is done.
				# Otherwise, trigger Partial.
				var phase = CustomerSpawner.DialoguePhase.SATISFIED if context.desired_items.is_empty() else CustomerSpawner.DialoguePhase.TALK
				var label = "Satisfy" if context.desired_items.is_empty() else "Partial"
				
				if context and context.timeline and spawner:
					spawner.start_dialogue(context.timeline, customer, phase, label)
				item = null  # prevent return_to_start below from running on a hidden node
			else:
				EventBus.transaction_completed.emit(item.item_data, false)
				# Wrong item — play per-character reaction. CustomerSpawner handles the jump if talking.
				if context and context.timeline and spawner:
					spawner.start_dialogue(context.timeline, customer, CustomerSpawner.DialoguePhase.WRONG_ITEM, "WrongItem")
			
	if not handled:
		print("[MainGame] No customer waiting, dropping item")
		
	# Return item to its shelf slot only if it was not consumed by a sale.
	if item:
		item.show_visuals()
		item.return_to_start()

func _input(event: InputEvent) -> void:
	# F1 toggles collision shape debug visualization
	if event is InputEventKey and event.keycode == KEY_F1 and event.pressed and not event.is_echo():
		_debug_show_collisions = !_debug_show_collisions
		DebugDraw2D.set_text("Collision Debug", "ON" if _debug_show_collisions else "OFF")

func _process(_delta: float) -> void:
	if not _debug_show_collisions:
		return
	_draw_all_collision_shapes(get_tree().root)

func _draw_all_collision_shapes(node: Node) -> void:
	# Keep the debug drawer logic intact
	if node is CollisionShape3D:
		var cs: CollisionShape3D = node
		if cs.shape == null or not cs.visible:
			return
		var xform: Transform3D = cs.global_transform
		var color := Color(0.0, 1.0, 0.3, 0.8)
		if cs.get_parent() is CharacterBody3D:
			color = Color(0.2, 0.6, 1.0, 0.9)  # Blue for player
		elif cs.get_parent() is Area3D:
			color = Color(1.0, 1.0, 0.0, 0.8)  # Yellow for areas/items

		if cs.shape is BoxShape3D:
			var box: BoxShape3D = cs.shape
			DebugDraw3D.draw_box(xform.origin, xform.basis.get_rotation_quaternion(), box.size, color)
		elif cs.shape is CapsuleShape3D:
			var cap: CapsuleShape3D = cs.shape
			DebugDraw3D.draw_capsule(xform.origin, xform.basis.get_rotation_quaternion(), cap.radius, cap.height, color)
		elif cs.shape is SphereShape3D:
			var sph: SphereShape3D = cs.shape
			DebugDraw3D.draw_sphere(xform.origin, sph.radius, color)
		elif cs.shape is ConcavePolygonShape3D:
			var faces = cs.shape.get_faces()
			var lines = PackedVector3Array()
			for i in range(0, faces.size(), 3):
				var a: Vector3 = xform * faces[i]
				var b: Vector3 = xform * faces[i+1]
				var c: Vector3 = xform * faces[i+2]
				lines.append(a)
				lines.append(b)
				lines.append(b)
				lines.append(c)
				lines.append(c)
				lines.append(a)
			if lines.size() > 0:
				DebugDraw3D.draw_lines(lines, color)
		elif cs.shape is WorldBoundaryShape3D:
			DebugDraw3D.draw_position(xform, color)
		elif cs.shape is ConvexPolygonShape3D:
			DebugDraw3D.draw_position(xform, color)

	for child in node.get_children():
		_draw_all_collision_shapes(child)
