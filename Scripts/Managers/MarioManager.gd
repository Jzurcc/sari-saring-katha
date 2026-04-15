extends Node

## MarioManager.gd
## Centralized controller for Uncle Mario's interaction lifecycle:
## Call -> Order -> Delivery.
##
## IMPORTANT: Dialogic.start(timeline, X) — X is a LABEL, not a style.
## Style must be set via Dialogic.Styles.load_style() BEFORE calling start().

signal call_ended(success: bool)
signal delivery_finished

const MARIO_DATA_PATH = "res://Resources/customers/UncleMario.tres"
const TRICYCLE_TEXTURE = "res://Assets/ui/mario_tricycle.png"

## Timeline paths — full res:// paths, immune to stale Dialogic directory cache.
const TIMELINE_PATH := "res://Dialogue/Timelines/UncleMario.dtl"

var _mario_data: CustomerData = null
var is_restocking_active: bool = false

# Delivery Positions (3D)
const START_POS = Vector3(-15.299, 3.206, 20.0)
const TARGET_POS = Vector3(-15.299, 3.206, -6.055)
const EXIT_POS = Vector3(-15.299, 3.206, -45.0)

# Timing
const DELIVERY_DELAY_SEC := 2.0

# Audio
var sfx_arrive: AudioStream = preload("res://Audio/SFX/motorcyle arrives and honks.mp3")
var sfx_leave: AudioStream = preload("res://Audio/SFX/motorcyle leaves.mp3")

var _current_anchor: Node = null
var _is_calling: bool = false
var _delivery_sprite: Sprite3D = null
var _sfx_player: AudioStreamPlayer

func _ready() -> void:
	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)
	
	if ResourceLoader.exists(MARIO_DATA_PATH):
		_mario_data = load(MARIO_DATA_PATH)
	else:
		push_warning("[MarioManager] CustomerData resource not found: " + MARIO_DATA_PATH)

# ── CALL LOGIC ───────────────────────────────────────────────────────

func initiate_call(anchor: Node, bypass_cooldown: bool = false) -> void:
	if _is_calling:
		print("[MarioManager] Already calling — ignoring.")
		return
	_is_calling = true
	is_restocking_active = true
	_current_anchor = anchor
	
	var label := "Call"
	var success_expected := true
	
	# 1. Busy check: if a dialogue is ACTIVELY running (blocking the phone UI)
	# If a customer is just waiting silently for an item, we are NOT busy.
	if Dialogic.current_timeline != null:
		label = "Busy"
		success_expected = false
	# 2. Rest check: if Mario is still on cooldown
	elif InventoryManager.customers_needed_for_delivery > 0 and not bypass_cooldown:
		# If an upgrade is pending, Mario wants that franchise money! Bypass rest.
		if StoryManager.pending_upgrade_tier > 0:
			print("[MarioManager] Upgrade pending — bypassing rest cooldown.")
		else:
			label = "CallRest"
			success_expected = false
	
	print("[MarioManager] Initiating call → Label: ", label)
	_start_dialogue(TIMELINE_PATH, anchor, _on_call_dialogue_ended.bind(success_expected), label)

func _on_call_dialogue_ended(success: bool) -> void:
	print("[MarioManager] Call dialogue ended. Success: ", success)
	_is_calling = false
	if not success:
		is_restocking_active = false
	_current_anchor = null
	call_ended.emit(success)

func cancel_restock() -> void:
	print("[MarioManager] Restock cancelled by player or system.")
	is_restocking_active = false
	_is_calling = false
	_current_anchor = null

func trigger_sample_delivery(tier: int) -> void:
	print("[MarioManager] Triggering sample delivery for Tier ", tier)
	
	var all_items = InventoryManager.get_all_items()
	var new_items: Dictionary = {}
	
	for item in all_items:
		if item.tier == tier:
			new_items[item] = 2 # 2 units of each new item
	
	if new_items.is_empty():
		print("[MarioManager] No new items found for Tier ", tier, ". Skipping sample delivery.")
		return
		
	# Start delivery sequence with the samples
	start_delivery(new_items)

# ── DELIVERY LOGIC ───────────────────────────────────────────────────

func start_delivery(items_to_restock: Dictionary) -> void:
	print("[MarioManager] Starting delivery sequence...")
	await get_tree().create_timer(DELIVERY_DELAY_SEC).timeout
	
	# 1. Setup Tricycle
	_delivery_sprite = Sprite3D.new()
	_delivery_sprite.pixel_size = 0.01
	_delivery_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_delivery_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_delivery_sprite.shaded = true
	_delivery_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_delivery_sprite.scale = Vector3(1.5, 1.5, 1.5)
	
	if ResourceLoader.exists(TRICYCLE_TEXTURE):
		_delivery_sprite.texture = load(TRICYCLE_TEXTURE)
	
	_delivery_sprite.position = START_POS
	get_tree().current_scene.add_child(_delivery_sprite)
	
	# Add a speech marker so the bubble floats above the tricycle
	var marker = Marker3D.new()
	marker.name = "SpeechMarker"
	marker.position = Vector3(0.4, 1.3, 0)
	_delivery_sprite.add_child(marker)
	
	# Start a continuous rocking/bobbing animation
	var rock_tween = create_tween().bind_node(_delivery_sprite).set_loops()
	rock_tween.tween_property(_delivery_sprite, "rotation_degrees:z", 3.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rock_tween.tween_property(_delivery_sprite, "rotation_degrees:z", -3.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rock_tween.tween_property(_delivery_sprite, "rotation_degrees:z", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 2. Arrive
	_play_sfx(sfx_arrive)
	var arrive_tween = create_tween()
	arrive_tween.set_parallel(true)
	arrive_tween.tween_property(_delivery_sprite, "position:z", TARGET_POS.z, 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arrive_tween.tween_property(_delivery_sprite, "position:x", TARGET_POS.x, 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arrive_tween.tween_property(_delivery_sprite, "position:y", TARGET_POS.y + 0.15, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	await arrive_tween.finished
	if _sfx_player.playing: await _sfx_player.finished
	
	# 3. Delivery Dialogue
	_current_anchor = _delivery_sprite
	
	# Automatically face the tricycle as dialogue begins.
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("face_node"):
		player.face_node(_delivery_sprite)
		
	_start_dialogue(TIMELINE_PATH, _delivery_sprite, _on_delivery_dialogue_ended.bind(items_to_restock), "Delivery")

func _on_delivery_dialogue_ended(items: Dictionary) -> void:
	# 1. Finalize Stock Immediately
	for item in items.keys():
		InventoryManager.add_stock(item, items[item])
	
	# 2. Auto-Restock Physical Slots
	# Randomly pick empty slots on compatible shelves and place items there.
	print("[MarioManager] Commencing auto-restock sweep...")
	var all_shelves = get_tree().get_nodes_in_group("shelf_surface")
	
	for item in items.keys():
		var amount_ordered = items[item]
		# Try to place as many as ordered, but respect physical shelf capacity
		for i in range(amount_ordered):
			var valid_options = []
			for shelf in all_shelves:
				if shelf.has_method("accepts_drop") and shelf.accepts_drop(item):
					var empty_slots = shelf.get_empty_slots()
					for slot_idx in empty_slots:
						valid_options.append({"shelf": shelf, "slot": slot_idx})
			
			if valid_options.is_empty():
				break # No more room for this specific item type
				
			var choice = valid_options.pick_random()
			choice.shelf.place_item_in_slot(item, choice.slot)
			
			# Since we placed it physically, take it out of the digital "back-of-house" stock
			InventoryManager.take_item(item)
	
	_refresh_containers(get_tree().root)
	InventoryManager.save_state()
	
	# 3. Clear interaction blockers immediately so customers can be clicked 
	# while Mario is driving off.
	_current_anchor = null
	is_restocking_active = false
	
	# 4. Leave sequence
	_play_sfx(sfx_leave)
	var leave_tween = create_tween()
	leave_tween.tween_property(_delivery_sprite, "position:z", EXIT_POS.z, 3.5).set_trans(Tween.TRANS_LINEAR)
	await leave_tween.finished
	if _sfx_player.playing: await _sfx_player.finished
	
	# 5. Cleanup
	_delivery_sprite.queue_free()
	_delivery_sprite = null
	delivery_finished.emit()

# ── INTERNAL HELPERS ────────────────────────────────────────────────

## Starts a Dialogic timeline with the FollowBubble style.
## Mirrors the WORKING pattern from CustomerSpawner._start_dialogue:
##   1. Load style via Dialogic.Styles.load_style()
##   2. Start timeline via Dialogic.start() with NO second argument
##   3. Register character anchor for bubble positioning
func _start_dialogue(timeline_path: String, anchor: Node, callback: Callable, label: String = "") -> void:
	print("[MarioManager] --- Starting Dialogue ---")
	print("[MarioManager]   Path:   ", timeline_path)
	print("[MarioManager]   Anchor: ", str(anchor.name) if anchor else "NULL")
	
	# 1. Verify the file exists
	if not ResourceLoader.exists(timeline_path):
		push_error("[MarioManager] Timeline file does not exist: " + timeline_path)
		callback.call()
		return
	
	# 2. If Dialogic is running, wait for it to finish first
	if Dialogic.current_timeline != null:
		print("[MarioManager]   Dialogic busy — waiting for current timeline to end...")
		await Dialogic.timeline_ended
		print("[MarioManager]   Previous timeline ended. Proceeding with Mario call.")
	
	# 3. Load the FollowBubble style FIRST (this is how Dialogic works)
	Dialogic.Styles.load_style("FollowBubble")
	
	# 4. Start the timeline (second arg is label)
	var layout = Dialogic.start(timeline_path, label)
	
	# Freeze game clock while dialogue is active
	StoryManager.is_clock_running = false
	
	print("[MarioManager]   Layout: ", str(layout.name) if layout else "NULL")
	
	# 5. Register character so the bubble anchors to the marker
	# We use DialogicResourceUtil to ensure we get the exact same object reference as NokiaUI.
	var mario_dch = DialogicResourceUtil.get_character_resource("UncleMario")
	if layout and mario_dch:
		if layout.has_method("register_character"):
			var marker = anchor.get_node_or_null("SpeechMarker")
			var final_anchor = marker if marker else anchor
			
			# Force clear any previous global registration before setting the new one
			layout.register_character(mario_dch, null)
			layout.register_character(mario_dch, final_anchor)
			
			print("[MarioManager]   Registered character → ", final_anchor.name, " @ ", final_anchor.global_position)
		else:
			push_warning("[MarioManager]   Layout does not support register_character!")
	else:
		push_warning("[MarioManager]   Failed to find layout or UncleMario dch resource!")
	
	# 6. Connect the end signal
	Dialogic.timeline_ended.connect(callback, CONNECT_ONE_SHOT)
	print("[MarioManager] --- Dialogue Started OK ---")

func _play_sfx(stream: AudioStream) -> void:
	_sfx_player.stream = stream
	_sfx_player.play()

func _refresh_containers(_ignored_node: Node) -> void:
	print("[MarioManager] Refreshing shelf surfaces via group lookup...")
	for surface in get_tree().get_nodes_in_group("shelf_surface"):
		if surface.has_method("refresh_visibility"):
			surface.refresh_visibility()
