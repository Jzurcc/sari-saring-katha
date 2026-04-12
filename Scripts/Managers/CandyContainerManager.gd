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
	_hide_all()

func _hide_all() -> void:
	if mix_container:    mix_container.visible = false
	if mentor_container: mentor_container.visible = false
	if pocha_container:  pocha_container.visible = false
	if chubs_container:  chubs_container.visible = false

func _on_day_started(day: int) -> void:
	# Cumulative — once a container appears, it stays visible for the rest of the game.
	if mix_container:    mix_container.visible    = day >= 2
	if mentor_container: mentor_container.visible = day >= 5
	if pocha_container:  pocha_container.visible  = day >= 5
	if chubs_container:  chubs_container.visible  = day >= 7
	print("[CandyContainerManager] Day %d — updated container visibility." % day)
