class_name MainGame
extends Node3D

## Level root for the sari-sari store main scene.
## Wires up scene overlays, ambient environment effects, lighting schedules, and player pause handling.
## Transaction resolution is owned by CustomerSpawner / TransactionSession.

@onready var street_lights: Array[Light3D] = [
	$OutsideSpotLight3D,
	$OutsideOmniLight3D,
	$OutsideOmniLight3D2,
	$OutsideOmniLight3D3
]
@onready var pause_menu_scene: PackedScene = preload("res://Scenes/UI/PauseMenu.tscn")
var pause_menu: Control

func _ready() -> void:
	LogManager.debug("MainGame", "_ready() START")
	# Keep notifications accessible - Spawn the NoticeOverlay if it doesn't exist
	if get_tree().get_nodes_in_group("notice_overlay").is_empty():
		LogManager.debug("MainGame", "Spawning NoticeOverlay")
		var notice_scene = load("res://Scenes/UI/NoticeOverlay.tscn")
		if notice_scene:
			var notice_instance = notice_scene.instantiate()
			add_child(notice_instance)
			notice_instance.add_to_group("notice_overlay")

	# Ensure camera is correctly scaled to 75 as a fallback
	LogManager.debug("MainGame", "Yielding frame for camera set")
	await get_tree().process_frame
	LogManager.debug("MainGame", "Frame yielded")
	var camera = $Player/Head/Camera3D
	if camera and camera.fov != 75:
		camera.fov = 75.0

	# Setup Ambient Effects
	VisualEffectManager.setup_ambient_dust(self)

	# Street Lights Time Sync
	var tod = get_tree().root.find_child("TimeOfDay", true, false)
	if tod:
		if not tod.time_changed.is_connected(_on_time_changed):
			tod.time_changed.connect(_on_time_changed)
		_on_time_changed(tod.get("current_time") if "current_time" in tod else 0.0)

	# Instantiate Pause menu
	LogManager.debug("MainGame", "Instantiating pause menu")
	pause_menu = pause_menu_scene.instantiate().get_node("Control")
	add_child(pause_menu.get_parent()) # Add the CanvasLayer

	# Instantiate Customer Request HUD
	LogManager.debug("MainGame", "Instantiating Customer Request HUD")
	var hud_scene = load("res://Scenes/UI/CustomerRequestHUD.tscn")
	if hud_scene:
		var hud_instance = hud_scene.instantiate()
		add_child(hud_instance)

	LogManager.debug("MainGame", "_ready() END")

func _input(event: InputEvent) -> void:
	# Escape toggles pause menu
	if (event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed)) and not event.is_echo():
		if pause_menu and not pause_menu.visible:
			get_viewport().set_input_as_handled()
			pause_menu.pause()

func _on_time_changed(hour: float) -> void:
	# Street lights turn on at 6 PM (18:00) and off at 8 PM (20:00)
	var should_be_on = hour >= 18.0 and hour < 20.5
	for light in street_lights:
		if is_instance_valid(light) and light.visible != should_be_on:
			light.visible = should_be_on
