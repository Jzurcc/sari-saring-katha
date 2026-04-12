@tool
extends DialogicLayoutLayer

## A layer that holds a full-screen input catcher that DOES NOT advance on click.
## Used to suppress global mouse advance for specific styles (like FollowBubble).

func _ready() -> void:
	if Engine.is_editor_hint(): return
	# Adding to this group suppresses the global _input(event) fallback in subsystem_input.gd
	add_to_group('dialogic_input')

func _gui_input(event: InputEvent) -> void:
	# Catch the click and stop it from reaching anything else.
	# We intentionally do NOT call Dialogic.Inputs.handle_input() here.
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
