extends WorldInteractor

## Interactive Counter Radio hosted by Papa Ulap (an unseen Tawong Lipod wind-engkanto).
## Uses a camera-following Y-billboard Sprite3D + thick outline shader matching Sto. Niño & Mingming.
## Clicking the Radio plays Papa Ulap's Dialogic broadcast (with Radio.wav blips):
## - Reveals today's hidden Market Event(s) (extra events unlocked by Radio Lv.2–3 after a 2h cooldown)
## - Plays random barangay chatter on quiet days, during Quiet Eclipse, or while waiting on cooldown
## - Never toggles or interrupts BGM.

const TIMELINE_PATH := "res://Dialogue/Timelines/PapaUlap.dtl"
const CHARACTER_PATH := "res://Dialogue/Timelines/PapaUlap.dch"

var _visual_base_scale: Vector3 = Vector3.ONE
var _pulse_time: float = 0.0
var _sprite: Sprite3D = null
var _speech_anchor: Marker3D = null
var _pending_reveal_active: bool = false
var _pending_visitor_path: String = ""

func _ready() -> void:
	super._ready()
	add_to_group("store_radio")
	billboard_collision = true
	outline_shader = preload("res://Assets/Shaders/item_outline_spatial.gdshader")
	default_outline_color = Color(1.0, 0.84, 0.42, 1.0)
	outline_width = 32.0

	var visuals := get_visual_nodes()
	if not visuals.is_empty():
		_visual_base_scale = visuals[0].scale
		if visuals[0] is Sprite3D:
			_sprite = visuals[0] as Sprite3D
			_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y

	_speech_anchor = get_node_or_null("SpeechMarker") as Marker3D
	if _speech_anchor == null:
		_speech_anchor = Marker3D.new()
		_speech_anchor.name = "SpeechMarker"
		_speech_anchor.position = Vector3(0.0, 0.42, 0.0)
		add_child(_speech_anchor)

	EventBus.radio_upgraded.connect(_on_radio_upgraded)
	EventBus.day_started.connect(func(_d): _refresh_visual_state(false))
	if is_instance_valid(StoreEventManager):
		StoreEventManager.events_changed.connect(func(_evs): _refresh_pulse_state())
	_refresh_visual_state(false)

func _process(delta: float) -> void:
	super._process(delta)
	if not visible or StoryManager.radio_upgrade_level < 1 or not is_instance_valid(_sprite):
		return
	# Lively speaking squash-and-stretch + warm golden pulse when Papa Ulap has a broadcast ready
	var ready_to_tune := is_instance_valid(StoreEventManager) and StoreEventManager.can_reveal_next_broadcast() and not StoryManager.is_past_closing_time() and Dialogic.current_timeline == null
	if ready_to_tune:
		_pulse_time += delta
		# Rhythmic 2-beat speaking cadence (squish-stretch bursts with brief breath pause)
		var cycle := fmod(_pulse_time, 1.45)
		var beat := 0.0
		if cycle < 0.24:
			beat = sin((cycle / 0.24) * PI)
		elif cycle >= 0.30 and cycle < 0.54:
			beat = sin(((cycle - 0.30) / 0.24) * PI) * 0.80
		var sx := 1.0 + beat * 0.075
		var sy := 1.0 - beat * 0.060 + sin(_pulse_time * 3.2) * 0.015
		_sprite.scale = Vector3(_visual_base_scale.x * sx, _visual_base_scale.y * sy, _visual_base_scale.z * sx)
		var glow := 0.5 + 0.5 * sin(_pulse_time * 3.2)
		_sprite.modulate = Color(1.0, 0.94 + glow * 0.06, 0.82 + glow * 0.18, 1.0)
	else:
		_pulse_time = 0.0
		_sprite.scale = _sprite.scale.lerp(_visual_base_scale, clampf(delta * 10.0, 0.0, 1.0))
		_sprite.modulate = Color.WHITE

func _refresh_pulse_state() -> void:
	if is_instance_valid(_sprite) and (not is_instance_valid(StoreEventManager) or not StoreEventManager.can_reveal_next_broadcast()):
		_sprite.scale = _visual_base_scale
		_sprite.modulate = Color.WHITE

func _refresh_visual_state(play_pop_in: bool = false) -> void:
	var was_visible := visible
	var unlocked := StoryManager.radio_upgrade_level >= 1
	visible = unlocked
	monitoring = unlocked
	monitorable = unlocked
	collision_layer = 1 if unlocked else 0
	if not unlocked:
		on_hover(false)
		return

	if is_instance_valid(_sprite):
		_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y

	if not was_visible and play_pop_in:
		var visuals := get_visual_nodes()
		if not visuals.is_empty():
			var visual := visuals[0]
			visual.scale = Vector3.ZERO
			var tw := create_tween()
			tw.tween_property(visual, "scale", _visual_base_scale * Vector3(1.18, 0.86, 1.18), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(visual, "scale", _visual_base_scale, 0.24).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			VisualEffectManager.spawn_heart_burst(visual.global_position + Vector3(0.0, 0.22, 0.0))

func _on_radio_upgraded(_new_level: int) -> void:
	_refresh_visual_state(true)
	_play_radio_bounce()

func on_interact() -> void:
	if StoryManager.radio_upgrade_level < 1:
		return
	if Dialogic.current_timeline != null:
		return
	if StoryManager.is_past_closing_time():
		return

	_play_radio_bounce()

	var is_eclipse: bool = StoryManager.has_mayari_card(MayariCardRegistry.CARD_QUIET_ECLIPSE)
	var cd_ready: bool = is_instance_valid(StoreEventManager) and StoreEventManager.get_reveal_cooldown_remaining_hours() <= 0.0
	var has_ev: bool = cd_ready and not is_eclipse and is_instance_valid(StoreEventManager) and StoreEventManager.has_unrevealed_events()
	var has_vis: bool = cd_ready and is_instance_valid(StoryManager) and StoryManager.has_unrevealed_daily_visitors()

	if has_ev or has_vis:
		var pick_visitor := false
		if has_ev and has_vis:
			pick_visitor = (randf() < 0.5)
		elif has_vis:
			pick_visitor = true

		if pick_visitor:
			var vis: CustomerData = StoryManager.peek_next_unrevealed_visitor()
			if vis:
				_pending_reveal_active = true
				_pending_visitor_path = vis.resource_path
				Dialogic.VAR.set_variable("Global_RadioEclipse", false)
				Dialogic.VAR.set_variable("Global_RadioVisitorName", vis.character_name)
				var favs: PackedStringArray = []
				for fcat in vis.get_favorite_categories():
					favs.append(StoryManager.get_category_display_name(fcat))
				var hint_txt := ("They usually look for %s." % ", ".join(favs)) if not favs.is_empty() else "Keep the shelves ready for them!"
				Dialogic.VAR.set_variable("Global_RadioVisitorHint", hint_txt)
				_start_papa_ulap_dialogue("VisitorBroadcast")
				return
		else:
			var ev: StoreEventData = StoreEventManager.peek_next_unrevealed_event()
			if ev:
				_pending_reveal_active = true
				_pending_visitor_path = ""
				Dialogic.VAR.set_variable("Global_RadioEclipse", false)
				Dialogic.VAR.set_variable("Global_RadioEventName", ev.event_name)
				Dialogic.VAR.set_variable("Global_EventRumorText", ev.rumor_text)
				_start_papa_ulap_dialogue("EventBroadcast")
				return

	_pending_reveal_active = false
	_pending_visitor_path = ""
	if is_instance_valid(StoreEventManager) and StoreEventManager.is_chatter_on_cooldown():
		_start_papa_ulap_dialogue("CommercialBreak")
		return

	if is_instance_valid(StoreEventManager):
		StoreEventManager.start_chatter_cooldown()
	Dialogic.VAR.set_variable("Global_RadioEclipse", is_eclipse)
	_start_papa_ulap_dialogue("Chatter")

func _start_papa_ulap_dialogue(label: String) -> void:
	if not ResourceLoader.exists(TIMELINE_PATH):
		LogManager.error("RadioInteractable", "Missing PapaUlap timeline: %s" % TIMELINE_PATH)
		return

	Dialogic.Styles.load_style("FollowBubble")
	var layout = Dialogic.start(TIMELINE_PATH, label)

	var dch = DialogicResourceUtil.get_character_resource("PapaUlap")
	if dch == null and ResourceLoader.exists(CHARACTER_PATH):
		dch = load(CHARACTER_PATH)
	if layout and dch and layout.has_method("register_character"):
		var anchor: Node3D = _speech_anchor if is_instance_valid(_speech_anchor) else self
		layout.register_character(dch, null)
		layout.register_character(dch, anchor)

	if not Dialogic.signal_event.is_connected(_on_dialogic_signal):
		Dialogic.signal_event.connect(_on_dialogic_signal)
	Dialogic.timeline_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)

func _on_dialogic_signal(arg: String) -> void:
	if arg == "radio_event_revealed" or arg == "radio_visitor_revealed":
		_commit_pending_event_reveal()

func _on_dialogue_ended() -> void:
	if Dialogic.signal_event.is_connected(_on_dialogic_signal):
		Dialogic.signal_event.disconnect(_on_dialogic_signal)
	if _pending_reveal_active:
		_commit_pending_event_reveal()

func _commit_pending_event_reveal() -> void:
	if not _pending_reveal_active:
		return
	_pending_reveal_active = false
	if _pending_visitor_path != "":
		var vpath := _pending_visitor_path
		_pending_visitor_path = ""
		var vis := StoryManager.reveal_daily_visitor(vpath)
		if is_instance_valid(StoreEventManager):
			StoreEventManager.start_reveal_cooldown()
		if vis:
			EventBus.request_sfx.emit("interact")
			EventBus.radio_card_announced.emit({
				"type": "visitor",
				"visitor": vis,
			})
		_refresh_pulse_state()
		return
	if not is_instance_valid(StoreEventManager):
		return
	var revealed := StoreEventManager.reveal_next_event()
	if revealed:
		EventBus.request_sfx.emit("interact")
		EventBus.radio_card_announced.emit({
			"type": "event",
			"event": revealed,
		})

func _play_radio_bounce() -> void:
	var visuals := get_visual_nodes()
	if visuals.is_empty():
		return
	var visual := visuals[0]
	var tw := create_tween()
	tw.tween_property(visual, "scale", _visual_base_scale * Vector3(1.12, 0.90, 1.12), 0.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(visual, "scale", _visual_base_scale * Vector3(0.96, 1.08, 0.96), 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(visual, "scale", _visual_base_scale, 0.20).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _ensure_outline_material() -> void:
	super._ensure_outline_material()
	if _outline_mat:
		_outline_mat.set_shader_parameter("fixed_y_billboard", true)
