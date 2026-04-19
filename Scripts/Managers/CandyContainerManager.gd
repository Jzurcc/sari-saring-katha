## CandyContainerManager — Shows/hides candy container 3D nodes based on the current day.
##
## Usage: Attach this script to any Node in the MainGame scene tree.
## In the Inspector, assign each candy container's 3D node to the appropriate
## export slot. They will automatically become visible on the correct day.
##
## Day 2: Mix container spawns
## Day 5: Mentor + Pocha containers spawn
## Day 7: Chubs container spawns
extends Node

@export_group("Candy Container Nodes")
## The Mix candy container 3D node — appears on Day 2.
@export var mix_container: Node3D
## The Mentor candy container 3D node — appears on Day 5.
@export var mentor_container: Node3D
## The Pocha candy container 3D node — appears on Day 5.
@export var pocha_container: Node3D
## The Chubs candy container 3D node — appears on Day 7.
@export var chubs_container: Node3D

func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	# Hide all containers initially; _on_day_started will show the right ones.
	# _hide_all() # Legacy logic disabled: containers manage themselves via StoryManager tiers now.

func _hide_all() -> void:
	_set_container_active(mix_container, false)
	_set_container_active(mentor_container, false)
	_set_container_active(pocha_container, false)
	_set_container_active(chubs_container, false)

func _on_day_started(_day: int) -> void:
	# Disabled — individual containers now manage themselves via StoryManager tiers
	pass

func _set_container_active(container: Node3D, active: bool) -> void:
	if not container: return
	container.visible = active
	# Ensure physics, scripts, and inputs are completely disabled when invisible
	container.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
