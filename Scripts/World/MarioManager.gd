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
var is_mario_physically_present: bool = false

# Delivery Positions (3D)
const START_POS = Vector3(-15.299, 3.206, 20.0)
const TARGET_POS = Vector3(-15.299, 3.206, -6.055)
const EXIT_POS = Vector3(-15.299, 3.206, -45.0)
const DEFAULT_PLASTIC_MARKER_POS := Vector3(0.9908627, 0.9105438, 2.585338)

# Timing
const DELIVERY_DELAY_SEC := 2.0

# Audio
var sfx_arrive: AudioStream = preload("res://Audio/SFX/motorcyle arrives and honks.mp3")
var sfx_leave: AudioStream = preload("res://Audio/SFX/motorcyle leaves.mp3")
var sfx_dial: AudioStream = preload("res://Audio/SFX/dial.wav")

var _current_anchor: Node = null
var _is_calling: bool = false
var _delivery_sprite: Sprite3D = null
var _sfx_player: AudioStreamPlayer
var _cached_bags_data: Array = []
var _call_session_id: int = 0
var _delivery_session_id: int = 0
var _pending_delivery_items: Dictionary = {}

func _ready() -> void:
	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)
	
	add_to_group("persist")
	
	if ResourceLoader.exists(MARIO_DATA_PATH):
		_mario_data = load(MARIO_DATA_PATH)
	else:
		LogManager.warn("MarioManager", "CustomerData resource not found: " + MARIO_DATA_PATH)
		
	
	# Connect for speaking animations
	EventBus.dialogue_character_speaking.connect(_on_character_speaking)
	
	# Restore bags when the game session actually begins
	EventBus.day_started.connect(_on_day_started)

func _is_in_main_game() -> bool:
	return get_tree() != null and get_tree().current_scene != null and get_tree().current_scene.name == "MainGame"

func _restore_audio_bus() -> void:
	ProjectSettings.set_setting("dialogic/audio/type_sound_bus", "Master")

# ── CALL LOGIC ───────────────────────────────────────────────────────

func initiate_call(anchor: Node, bypass_cooldown: bool = false) -> void:
	# Block if already in a call or restocking is active
	if is_restocking_active:
		# Defensive: If restocking is active but the Nokia UI is gone, something leaked.
		# But only reset if Mario isn't physically on his way (delivery phase).
		if not is_mario_physically_present and get_tree().get_nodes_in_group("nokia_ui_active").is_empty():
			LogManager.debug("MarioManager", "Orphaned restocking state detected. Resetting.")
			is_restocking_active = false
		else:
			LogManager.debug("MarioManager", "Already calling — ignoring.")
			return
			
	if _is_calling:
		LogManager.debug("MarioManager", "Already calling — ignoring.")
		return
	_is_calling = true
	is_restocking_active = true
	_current_anchor = anchor
	_call_session_id += 1
	var session_id := _call_session_id
	
	var label := "Call"
	var success_expected := true
	
	# 1. Busy check: if a dialogue is ACTIVELY running (blocking the phone UI)
	# If a customer is just waiting silently for an item, we are NOT busy.
	if Dialogic.current_timeline != null:
		label = "Busy"
		success_expected = false
	# 2. Rest check: if Mario is still on cooldown
	elif InventoryManager.customers_needed_for_delivery > 0 and not bypass_cooldown:
		# Update Dialogic variable for the restock dialogue to show remaining customers
		Dialogic.VAR.set_variable("Transaction_MarioRestCount", InventoryManager.customers_needed_for_delivery)
		label = "CallRest"
		success_expected = false
	
	LogManager.info("MarioManager", "Initiating call → Label: %s" % label)
	
	# All calls now feature the ringing/dial delay for realism
	LogManager.debug("MarioManager", "Playing dial sound...")
	_play_sfx(sfx_dial)
	
	var delay := randf_range(2.0, 4.0)
	await get_tree().create_timer(delay).timeout
	_sfx_player.stop()
	
	# Guard against call cancellation or scene exit during dial delay
	if session_id != _call_session_id or not is_restocking_active or not _is_in_main_game() or not is_instance_valid(anchor):
		LogManager.debug("MarioManager", "Call aborted during dial delay (cancelled or scene changed).")
		_is_calling = false
		_restore_audio_bus()
		return
	
	_start_dialogue(TIMELINE_PATH, anchor, _on_call_dialogue_ended.bind(success_expected), label)

func _on_call_dialogue_ended(success: bool) -> void:
	LogManager.info("MarioManager", "Call dialogue ended. Success: %s" % str(success))
	_is_calling = false
	_restore_audio_bus()
	
	if not success:
		is_restocking_active = false
	_current_anchor = null
	call_ended.emit(success)

func cancel_restock() -> void:
	LogManager.info("MarioManager", "Restock cancelled by player or system.")
	_call_session_id += 1
	is_restocking_active = false
	_is_calling = false
	_current_anchor = null
	if _sfx_player and _sfx_player.playing:
		_sfx_player.stop()
	_restore_audio_bus()

func trigger_sample_delivery(tier: int) -> void:
	LogManager.info("MarioManager", "Triggering sample delivery for Tier %d" % tier)
	
	var all_items = InventoryManager.get_all_items()
	var new_items: Dictionary = {}
	
	for item in all_items:
		if item.tier == tier:
			new_items[item] = 2 # 2 units of each new item
	
	if new_items.is_empty():
		LogManager.debug("MarioManager", "No new items found for Tier %d. Skipping sample delivery." % tier)
		return
		
	# Start delivery sequence with the samples
	start_delivery(new_items)

# ── DELIVERY LOGIC ───────────────────────────────────────────────────

func start_delivery(items_to_restock: Dictionary) -> void:
	LogManager.info("MarioManager", "Starting delivery sequence...")
	is_mario_physically_present = true
	_delivery_session_id += 1
	var session_id := _delivery_session_id
	_pending_delivery_items = items_to_restock.duplicate()
	
	await get_tree().create_timer(DELIVERY_DELAY_SEC).timeout
	if session_id != _delivery_session_id or not _is_in_main_game():
		LogManager.debug("MarioManager", "Delivery sequence aborted before arrival (scene changed or reset).")
		flush_pending_delivery()
		return
	
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
	# Position at a fixed height of 1.3 (original tuned value)
	# with a slight side offset of 0.4
	marker.position = Vector3(0.4, 1.3, 0)
	_delivery_sprite.add_child(marker)
	
	# Start a continuous rocking/bobbing animation
	var rock_tween = create_tween().bind_node(_delivery_sprite).set_loops()
	rock_tween.tween_property(_delivery_sprite, "rotation_degrees:z", 3.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rock_tween.tween_property(_delivery_sprite, "rotation_degrees:z", -3.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rock_tween.tween_property(_delivery_sprite, "rotation_degrees:z", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 2. Arrive
	_play_sfx(sfx_arrive)
	var arrive_tween = create_tween().bind_node(_delivery_sprite)
	arrive_tween.set_parallel(true)
	arrive_tween.tween_property(_delivery_sprite, "position:z", TARGET_POS.z, 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arrive_tween.tween_property(_delivery_sprite, "position:x", TARGET_POS.x, 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arrive_tween.tween_property(_delivery_sprite, "position:y", TARGET_POS.y + 0.15, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	await arrive_tween.finished
	if session_id != _delivery_session_id or not _is_in_main_game() or not is_instance_valid(_delivery_sprite):
		LogManager.debug("MarioManager", "Delivery sequence aborted during arrival.")
		flush_pending_delivery()
		return
	if _sfx_player.playing:
		await _sfx_player.finished
	if session_id != _delivery_session_id or not _is_in_main_game() or not is_instance_valid(_delivery_sprite):
		LogManager.debug("MarioManager", "Delivery sequence aborted after arrival SFX.")
		flush_pending_delivery()
		return
	
	# 3. Delivery Dialogue
	_current_anchor = _delivery_sprite
	
	EventBus.customer_arrived.emit(null)
	
	_start_dialogue(TIMELINE_PATH, _delivery_sprite, _on_delivery_dialogue_ended.bind(items_to_restock, session_id), "Delivery")


## Immediately commits any in-flight paid order so stock, tier upgrades, and bags are never lost on save/exit.
func flush_pending_delivery() -> void:
	if _pending_delivery_items.is_empty():
		return
	LogManager.info("MarioManager", "Flushing in-flight delivery order to persistent stock & bag cache.")
	_commit_pending_delivery(_is_in_main_game())


func _commit_pending_delivery(spawn_in_tree: bool) -> void:
	if _pending_delivery_items.is_empty():
		return
	var items := _pending_delivery_items.duplicate()
	_pending_delivery_items.clear()

	# 1. Finalize Stock Immediately (Digital pool always has the total)
	for item in items.keys():
		InventoryManager.add_stock(item, items[item])
	
	# 2. Plastic Bag Delivery Logic
	LogManager.info("MarioManager", "Processing delivery bags...")
	var marker = get_tree().root.find_child("PlasticMarker", true, false) if get_tree() and get_tree().root else null
	var base_marker_pos: Vector3 = marker.global_position if marker else DEFAULT_PLASTIC_MARKER_POS
	var plastic_scene = preload("res://Scenes/PlasticDeliveryItem.tscn")
	
	var items_to_bag: Array[ItemData] = []
	var upgrade_delivered := false
	var target_tier := 1

	for item in items.keys():
		if item.get_meta("is_upgrade", false):
			upgrade_delivered = true
			target_tier = max(target_tier, item.get_meta("target_tier", 1))
			LogManager.info("MarioManager", "Upgrade detected in delivery! Target Tier: %d" % target_tier)
			continue

		# Filter: Candies and Sachets bypass bags
		if item.category == "candy" or item.category == "sachet" or item.type == ItemData.ItemType.CANDY_CONTAINER or item.type == ItemData.ItemType.SACHET_CONTAINER:
			LogManager.debug("MarioManager", "Auto-stocking digital item: %s" % item.item_name)
			continue
		else:
			LogManager.debug("MarioManager", "Adding to physical bag: %s" % item.item_name)
			
		# Everything else goes into bags
		for i in range(items[item]):
			items_to_bag.append(item)
	
	# Handle Tier Advancement and Samples
	if upgrade_delivered:
		while StoryManager.current_tier < target_tier:
			StoryManager.advance_tier("Mario Delivery")
			var new_tier = StoryManager.current_tier
			LogManager.info("MarioManager", "Processing unlocked samples for NEW Tier: %d" % new_tier)
			
			var all_items = InventoryManager.get_all_items()
			for i in all_items:
				if i.tier == new_tier and i.can_be_sold:
					LogManager.debug("MarioManager", "Unpacking 2 samples of: %s" % i.item_name)
					InventoryManager.add_stock(i, 2)
					
					if not (i.type == ItemData.ItemType.CANDY_CONTAINER or i.type == ItemData.ItemType.SACHET_CONTAINER):
						# Samples go into bags (2 units each)
						items_to_bag.append(i)
						items_to_bag.append(i)
	
	# Group items into batches of 5
	var batch_size = 5
	for i in range(0, items_to_bag.size(), batch_size):
		var batch = items_to_bag.slice(i, i + batch_size)
		var offset := Vector3(
			randf_range(-1.1, 1.1),
			0.05, # Slight lift
			randf_range(-1.1, 1.1)
		)
		var bag_pos: Vector3 = base_marker_pos + offset
		if spawn_in_tree and _is_in_main_game():
			var bag = plastic_scene.instantiate()
			get_tree().current_scene.add_child(bag)
			bag.items = batch
			bag.global_position = bag_pos
		else:
			var item_paths: Array = []
			for batch_item in batch:
				item_paths.append(batch_item.resource_path)
			_cached_bags_data.append({
				"pos_x": bag_pos.x,
				"pos_y": bag_pos.y,
				"pos_z": bag_pos.z,
				"items": item_paths
			})
	
	if spawn_in_tree and get_tree() and get_tree().root:
		_refresh_containers(get_tree().root)


func _on_delivery_dialogue_ended(_items: Dictionary, session_id: int = -1) -> void:
	_restore_audio_bus()
	_commit_pending_delivery(_is_in_main_game())
	
	# 3. Clear interaction blockers immediately so customers can be clicked 
	# while Mario is driving off.
	_current_anchor = null
	is_restocking_active = false
	
	if (session_id != -1 and session_id != _delivery_session_id) or not _is_in_main_game() or not is_instance_valid(_delivery_sprite):
		if is_instance_valid(_delivery_sprite):
			_delivery_sprite.queue_free()
		_delivery_sprite = null
		is_mario_physically_present = false
		return

	# 4. Leave sequence
	_play_sfx(sfx_leave)
	var leave_tween = create_tween().bind_node(_delivery_sprite)
	leave_tween.tween_property(_delivery_sprite, "position:z", EXIT_POS.z, 3.5).set_trans(Tween.TRANS_LINEAR)
	await leave_tween.finished
	if _sfx_player.playing and _is_in_main_game():
		await _sfx_player.finished
	
	# 5. Cleanup
	if is_instance_valid(_delivery_sprite):
		_delivery_sprite.queue_free()
	_delivery_sprite = null
	is_mario_physically_present = false
	
	if _is_in_main_game():
		EventBus.customer_dismissed.emit(null)
		delivery_finished.emit()

func _on_day_started(_day: int) -> void:
	_check_and_spawn_bags()

func _check_and_spawn_bags() -> void:
	if _cached_bags_data.is_empty():
		return
		
	# Security check: Only spawn if we're in the MainGame scene
	if get_tree().current_scene.name != "MainGame":
		LogManager.debug("MarioManager", "Postponing bag spawn — not in MainGame (Current: %s)" % get_tree().current_scene.name)
		return
		
	LogManager.info("MarioManager", "Spawning %d cached bags..." % _cached_bags_data.size())
	
	# Clear whatever dummy bags currently exist to prevent dupes.
	for old_bag in get_tree().get_nodes_in_group("delivery_bag"):
		old_bag.queue_free()
		
	var plastic_scene = preload("res://Scenes/PlasticDeliveryItem.tscn")
	for b_data in _cached_bags_data:
		var new_bag = plastic_scene.instantiate()
		get_tree().current_scene.add_child(new_bag)
		
		new_bag.global_position = Vector3(
			b_data.get("pos_x", 0.0),
			b_data.get("pos_y", 0.0),
			b_data.get("pos_z", 0.0)
		)
		
		var restored_items: Array[ItemData] = []
		for path in b_data.get("items", []):
			if ResourceLoader.exists(path):
				restored_items.append(load(path))
				
		new_bag.items = restored_items
		# Wait for scene tree to process the added node before skipping fade
		new_bag.set_deferred("is_fading_in", false)
		
		# Optional: Quick visuals pulse
		if new_bag.has_method("_refresh_visuals"):
			new_bag.call_deferred("_refresh_visuals")
			
	# Clear cache once spawned
	_cached_bags_data.clear()

# ── INTERNAL HELPERS ────────────────────────────────────────────────

# ── SAVE / LOAD LOGIC ────────────────────────────────────────────────

func get_save_data() -> Dictionary:
	# Ensure any in-flight paid order is committed before serializing bags
	if not _pending_delivery_items.is_empty():
		_commit_pending_delivery(false)

	var bags_data = []
	for bag in get_tree().get_nodes_in_group("delivery_bag"):
		var item_paths = []
		for item in bag.items:
			item_paths.append(item.resource_path)
			
		bags_data.append({
			"pos_x": bag.global_position.x,
			"pos_y": bag.global_position.y,
			"pos_z": bag.global_position.z,
			"items": item_paths
		})
	
	# Include any cached bags that haven't been spawned in the scene yet
	if not _cached_bags_data.is_empty():
		bags_data.append_array(_cached_bags_data)
		
	return {
		"bags": bags_data
	}

func load_save_data(data: Dictionary) -> void:
	if not data.has("bags"):
		return
		
	_cached_bags_data = data["bags"]
	LogManager.info("MarioManager", "Received %d bags in load_save_data. Cached for spawning." % _cached_bags_data.size())
	
	# Try spawning immediately if the scene is already ready
	_check_and_spawn_bags()
		
	# Clear whatever dummy bags currently exist to prevent dupes.
	# (LOGIC MOVED TO _check_and_spawn_bags)

func reset_state() -> void:
	_call_session_id += 1
	_delivery_session_id += 1
	_pending_delivery_items.clear()
	_cached_bags_data.clear()
	is_restocking_active = false
	is_mario_physically_present = false
	_is_calling = false
	_current_anchor = null
	if is_instance_valid(_delivery_sprite):
		_delivery_sprite.queue_free()
	_delivery_sprite = null
	if _sfx_player and _sfx_player.playing:
		_sfx_player.stop()
	_restore_audio_bus()
	LogManager.info("MarioManager", "State reset for New Game.")



## Starts a Dialogic timeline with the FollowBubble style.
## Mirrors the WORKING pattern from CustomerSpawner._start_dialogue:
##   1. Load style via Dialogic.Styles.load_style()
##   2. Start timeline via Dialogic.start() with NO second argument
##   3. Register character anchor for bubble positioning
func _start_dialogue(timeline_path: String, anchor: Node, callback: Callable, label: String = "") -> void:
	LogManager.debug("MarioManager", "  Path:   %s" % timeline_path)
	LogManager.debug("MarioManager", "  Anchor: %s" % (str(anchor.name) if is_instance_valid(anchor) else "NULL"))
	
	# 1. Verify the file exists
	if not ResourceLoader.exists(timeline_path):
		LogManager.error("MarioManager", "Timeline file does not exist: " + timeline_path)
		callback.call()
		return
	
	# 2. If Dialogic is running, wait for it to finish first
	if Dialogic.current_timeline != null:
		LogManager.debug("MarioManager", "  Dialogic busy — waiting for current timeline to end...")
		await Dialogic.timeline_ended
		if not _is_in_main_game() or not is_instance_valid(anchor):
			LogManager.debug("MarioManager", "  Anchor or MainGame invalid after waiting for Dialogic. Aborting.")
			callback.call()
			return
		LogManager.debug("MarioManager", "  Previous timeline ended. Proceeding with Mario call.")
	
	# 3. Load the FollowBubble style FIRST (this is how Dialogic works)
	Dialogic.Styles.load_style("FollowBubble")
	
	# 4. Set telephone bus for Mario's blips
	# This setting is read by Dialogic's type sound module.
	ProjectSettings.set_setting("dialogic/audio/type_sound_bus", "Telephone")
	
	# 5. Start the timeline (second arg is label)
	var layout = Dialogic.start(timeline_path, label)
	
	LogManager.debug("MarioManager", "  Layout: %s" % (str(layout.name) if layout else "NULL"))
	
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
			
			LogManager.debug("MarioManager", "  Registered character → %s @ %s" % [final_anchor.name, str(final_anchor.global_position)])
		else:
			LogManager.warn("MarioManager", "  Layout does not support register_character!")
	else:
		LogManager.warn("MarioManager", "  Failed to find layout or UncleMario dch resource!")
	
	# 6. Connect the end signal
	Dialogic.timeline_ended.connect(callback, CONNECT_ONE_SHOT)
	LogManager.debug("MarioManager", "--- Dialogue Started OK ---")

func _play_sfx(stream: AudioStream) -> void:
	_sfx_player.stream = stream
	_sfx_player.volume_db = -9.0
	_sfx_player.play()

func _refresh_containers(_ignored_node: Node) -> void:
	LogManager.debug("MarioManager", "Refreshing shelf surfaces via group lookup...")
	for surface in get_tree().get_nodes_in_group("shelf_surface"):
		if surface.has_method("refresh_visibility"):
			surface.refresh_visibility()
			
	for container in get_tree().get_nodes_in_group("pricing_ui_containers"):
		if container.has_method("refresh_stock"):
			container.refresh_stock()


func _on_character_speaking(customer: CustomerData) -> void:
	if not _mario_data: return
	if not _delivery_sprite or not _delivery_sprite.visible: return
	
	if customer == _mario_data:
		play_speak_animation()

## One-shot squash-and-stretch animation for the tricycle
func play_speak_animation() -> void:
	if not _delivery_sprite: return
	
	var base_scale = Vector3(1.5, 1.5, 1.5)
	var speak_tween = create_tween()
	
	# Pulse 1
	speak_tween.tween_property(_delivery_sprite, "scale", Vector3(base_scale.x * 1.05, base_scale.y * 0.95, base_scale.z), 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	speak_tween.tween_property(_delivery_sprite, "scale", base_scale, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Pulse 2
	speak_tween.tween_property(_delivery_sprite, "scale", Vector3(base_scale.x * 1.05, base_scale.y * 0.95, base_scale.z), 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	speak_tween.tween_property(_delivery_sprite, "scale", base_scale, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
