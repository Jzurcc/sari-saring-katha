extends Node

@export_file("*.tscn") var next_scene_path: String = "res://Scenes/MainGame.tscn"

@onready var sequences_container = $Sequences
@onready var camera = $Camera3D
@onready var bgm_player = $AudioStreamPlayer
@onready var fade_rect = $CanvasLayer/ColorRect
@onready var subtitle_label = $CanvasLayer/SubtitleContainer/SubtitleLabel
@onready var indicator = $CanvasLayer/IndicatorLabel
@onready var skip_button = %SkipButton

signal player_clicked
var waiting_for_input: bool = false
var fast_forwarding: bool = false
var _is_skipping: bool = false

func _ready():
	fade_rect.color = Color(0, 0, 0, 1) # Start fully black
	subtitle_label.text = ""
	subtitle_label.visible_ratio = 0.0
	indicator.hide()
	
	if bgm_player and bgm_player.stream:
		# Stop local BGM to let AudioManager's Autumn Wind play continuously without overlap
		bgm_player.stop()
		
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)
		
	play_all_sequences()

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if waiting_for_input:
			waiting_for_input = false
			player_clicked.emit()
		else:
			fast_forwarding = true
	elif event.is_action_pressed("ui_accept"):
		if waiting_for_input:
			waiting_for_input = false
			player_clicked.emit()
		else:
			fast_forwarding = true
	elif event.is_action_pressed("ui_cancel"):
		_on_skip_pressed()

func wait_for_click():
	indicator.show()
	var blink_tween = create_tween().set_loops()
	blink_tween.tween_property(indicator, "modulate:a", 0.0, 0.5)
	blink_tween.tween_property(indicator, "modulate:a", 1.0, 0.5)
	
	waiting_for_input = true
	fast_forwarding = false
	await player_clicked
	
	blink_tween.kill()
	indicator.modulate.a = 1.0
	indicator.hide()

func play_all_sequences():
	for sequence_node in sequences_container.get_children():
		if _is_skipping:
			break
		if sequence_node is CutsceneSequence:
			await play_sequence(sequence_node)
			
	if not _is_skipping:
		_finish_cutscene()

func _on_skip_pressed():
	if _is_skipping: return
	_is_skipping = true
	
	# Hide UI immediately
	if subtitle_label: subtitle_label.hide()
	if indicator: indicator.hide()
	if skip_button: skip_button.hide()
	
	# Kill any active tweens (panning, typing, etc.)
	for tween in get_tree().get_processed_tweens():
		if tween.is_valid():
			tween.kill()
			
	# If we were waiting for a click, release the block
	if waiting_for_input:
		waiting_for_input = false
		player_clicked.emit()
	
	# Perform a slow fade out to black
	var fade_out = create_tween()
	fade_out.tween_property(fade_rect, "color", Color(0, 0, 0, 1), 2.0)
	await fade_out.finished
	
	_finish_cutscene()

func _finish_cutscene():
	print("Transitions finished. Moving to game!")
	var transition_manager = get_node_or_null("/root/SceneTransitionManager")
	if transition_manager:
		transition_manager.transition_to_scene(next_scene_path)
	else:
		var err = get_tree().change_scene_to_file(next_scene_path)
		if err != OK:
			push_error("[IntroManager] Failed to load next scene: ", next_scene_path)

func play_sequence(sequence: CutsceneSequence):
	# Setup text
	subtitle_label.text = sequence.subtitle_text
	subtitle_label.visible_ratio = 0.0
	fast_forwarding = false
	indicator.hide()
	
	var pans = []
	for child in sequence.get_children():
		if child is CameraPan:
			pans.append(child)
			
	if pans.size() == 0:
		push_warning("Sequence has no CameraPans! " + sequence.name)
		return
		
	var total_duration = 0.0
	for pan in pans:
		total_duration += pan.duration
		
	var text_duration = max(1.0, total_duration - 1.5)
	
	# 1. Start Text Typing Concurrently
	var text_tween = create_tween()
	text_tween.tween_property(subtitle_label, "visible_ratio", 1.0, text_duration)
	
	# 2. Fade In Black -> Clear (only at start of sequence)
	var first_pan = pans[0]
	var start_node = first_pan.get_node_or_null(first_pan.start_marker) as Node3D
	if start_node:
		camera.global_transform = start_node.global_transform
		
	var fade_in = create_tween()
	fade_in.tween_property(fade_rect, "color", Color(0, 0, 0, 0), 1.0)
	await fade_in.finished
	
	# 3. Loop through pans (Camera Cuts)
	for i in range(pans.size()):
		var pan = pans[i]
		var pan_start = pan.get_node_or_null(pan.start_marker) as Node3D
		var pan_end = pan.get_node_or_null(pan.end_marker) as Node3D
		
		if pan_start:
			camera.global_transform = pan_start.global_transform
			
		if not pan_end:
			continue
			
		var pan_tween = create_tween()
		pan_tween.set_parallel(true)
		pan_tween.set_trans(Tween.TRANS_SINE)
		pan_tween.set_ease(Tween.EASE_IN_OUT)
		pan_tween.tween_property(camera, "global_position", pan_end.global_position, pan.duration)
		pan_tween.tween_property(camera, "global_rotation", pan_end.global_rotation, pan.duration)
		
		# We process the duration in smaller chunks so we can interrupt it if fast_forwarding
		var time_passed = 0.0
		while time_passed < pan.duration:
			await get_tree().process_frame
			time_passed += get_process_delta_time()
			if fast_forwarding:
				pan_tween.kill()
				camera.global_position = pan_end.global_position
				camera.global_rotation = pan_end.global_rotation
				break
				
		# If fast forward was triggered, break the panning loop entirely
		if fast_forwarding:
			break
				
	# If fast_forwarding, make sure text immediately finishes forming
	if fast_forwarding:
		text_tween.kill()
		subtitle_label.visible_ratio = 1.0
		fast_forwarding = false
	
	# Wait for text to finish typing just in case pan ended early
	if text_tween.is_running():
		await text_tween.finished
		
	# 4. Wait for player click
	await wait_for_click()
	
	# 5. Fade out at the end of the sequence
	var fade_out = create_tween()
	fade_out.tween_property(fade_rect, "color", Color(0, 0, 0, 1), 1.0)
	await fade_out.finished
