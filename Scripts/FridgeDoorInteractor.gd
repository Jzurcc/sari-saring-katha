## FridgeDoorInteractor.gd
## Attach to the Area3D child of the refrigerator door mesh.
## The Area3D sits on collision layer 1 so PlayerInteraction's center-raycast
## detects it. This script simply forwards the game's standard on_hover /
## on_interact calls up to the parent RefrigeratorDoor node.
extends Area3D

func on_hover(is_hovered: bool) -> void:
	var door := get_parent() as RefrigeratorDoor
	if door:
		door.on_hover(is_hovered)

func on_interact() -> void:
	var door := get_parent() as RefrigeratorDoor
	if door:
		door.on_interact()
