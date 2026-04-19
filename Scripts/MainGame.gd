class_name MainGame
extends Node3D

# --- MainGame: Dramatically simplified via architectural rewrite ---
# All physics and input are handled by FPSController.gd
# All dragging is handled by EventBus and DragManager
# All time logic is handled by DayNightManager
# -----------------------------------------------------------------

var _debug_show_collisions: bool = false
@onready var tray: TransactionTray

@onready var street_lights: Array[Light3D] = [
	$OutsideSpotLight3D,
	$OutsideOmniLight3D,
	$OutsideOmniLight3D2,
	$OutsideOmniLight3D3
]
@onready var pause_menu_scene: PackedScene = preload("res://Scenes/UI/PauseMenu.tscn")
var pause_menu: Control

func _ready() -> void:
	print("[DEBUG] MainGame._ready() START")
	# Keep notifications accessible - Spawn the NoticeOverlay if it doesn't exist
	if get_tree().get_nodes_in_group("notice_overlay").is_empty():
		print("[DEBUG] MainGame: Spawning NoticeOverlay")
		var notice_scene = load("res://Scenes/UI/NoticeOverlay.tscn")
		if notice_scene:
			var notice_instance = notice_scene.instantiate()
			add_child(notice_instance)
			notice_instance.add_to_group("notice_overlay")

	# Ensure camera is correctly scaled to 75 as a fallback
	print("[DEBUG] MainGame: Yielding frame for camera set")
	await get_tree().process_frame
	print("[DEBUG] MainGame: Frame yielded")
	var camera = $Player/Head/Camera3D
	if camera and camera.fov != 75:
		camera.fov = 75.0

	# Ensure Transaction tray exists
	var tray_nodes := get_tree().get_nodes_in_group("transaction_tray")
	if tray_nodes.size() > 0:
		tray = tray_nodes[0] as TransactionTray
	else:
		push_error("[MainGame] Missing Transaction Tray in Scene")

	# Setup Ambient Effects
	VisualEffectManager.setup_ambient_dust(self)

	# Connect the tray to the generic event bus instead of handling logic here
	tray.item_placed.connect(_on_tray_item_placed)
	
	# Street Lights Time Sync
	var tod = get_tree().root.find_child("TimeOfDay", true, false)
	if tod:
		if not tod.time_changed.is_connected(_on_time_changed):
			tod.time_changed.connect(_on_time_changed)
		# Initial check
		_on_time_changed(tod.get("current_time") if "current_time" in tod else 0.0)
	
	# Instantiate Pause menu
	print("[DEBUG] MainGame: Instantiating pause menu")
	pause_menu = pause_menu_scene.instantiate().get_node("Control")
	add_child(pause_menu.get_parent()) # Add the CanvasLayer
	print("[DEBUG] MainGame._ready() END")

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
				
				# Spawn glimmer at the customer's visual center (SpeechMarker)
				var glimmer_pos = tray.global_position + Vector3(0, 0.2, 0)
				var marker = customer.get_node_or_null("SpeechMarker")
				if marker:
					glimmer_pos = marker.global_position
				
				VisualEffectManager.spawn_transaction_glimmer(glimmer_pos)
				var c_path = customer.customer_data.resource_path if customer.customer_data else ""
				EventBus.transaction_completed.emit(item.item_data, true, context.wants_debt, c_path)
				InventoryManager.take_item(item.item_data)
				item.notify_placed()
				item.play_give_animation()
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
				var c_path = customer.customer_data.resource_path if customer.customer_data else ""
				
				# Special Tutorial Handling: If Uncle Mario is blocking items, or hasn't started yet.
				var is_mario = customer.customer_data and customer.customer_data.get_clean_id() == "unclemario"
				var gm = get_tree().get_first_node_in_group("game_manager") as GameManager
				var is_tut_block = gm and gm.is_tutorial_task_active and gm.current_tutorial_task_id != "wait_for_sale"
				
				if is_mario:
					if is_tut_block:
						# Just skip feedback, item will return to shelf automatically at end of function
						print("[MainGame] Suppressing WrongItem feedback for Mario during tutorial.")
					elif not gm or not gm.is_tutorial_task_active:
						# If they haven't even greeted him yet (no task active), treat this as a "Greeting" trigger
						print("[MainGame] Early Mario interaction detected. Triggering tutorial greeting.")
						spawner._on_customer_clicked(customer)
				else:
					EventBus.transaction_completed.emit(item.item_data, false, context.wants_debt, c_path)
					# Wrong item — play per-character reaction. CustomerSpawner handles the jump if talking.
					if context and context.timeline and spawner:
						spawner.start_dialogue(context.timeline, customer, CustomerSpawner.DialoguePhase.WRONG_ITEM, "WrongItem")
				
				# Keep item in hand so it doesn't just vanish or jump
				if DragManager and item.sprite and item.sprite.texture:
					DragManager.call_deferred("start_drag", item, item.sprite.texture)
				
				item = null # Preempt return_to_start
			
	if not handled:
		print("[MainGame] No customer waiting, dropping item")
		
	# Return item to its shelf slot only if it was not consumed by a sale.
	if item:
		item.show_visuals()
		item.return_to_start()

func _input(event: InputEvent) -> void:
	# F1 toggles collision shape debug visualization
	# if event is InputEventKey and event.keycode == KEY_F1 and event.pressed and not event.is_echo():
	# 	_debug_show_collisions = !_debug_show_collisions
	# 	DebugDraw2D.set_text("Collision Debug", "ON" if _debug_show_collisions else "OFF")
	
	# Escape toggles pause menu
	if (event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed)) and not event.is_echo():
		if pause_menu and not pause_menu.visible:
			get_viewport().set_input_as_handled()
			pause_menu.pause()
			
	# H key to test notifications (debug only)
	# if event is InputEventKey and event.keycode == KEY_H and event.pressed and not event.is_echo():
	# 	EventBus.show_notification.emit("Shelf is full!", "Can't add any more stock.", "")

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

func _on_time_changed(hour: float) -> void:
	# Street lights turn on at 6 PM (18:00) and off at 8 PM (20:00)
	var should_be_on = hour >= 18.0 and hour < 20.5
	
	for light in street_lights:
		if is_instance_valid(light) and light.visible != should_be_on:
			light.visible = should_be_on
			# print("[MainGame] Street Light %s toggled: %s" % [light.name, should_be_on])
