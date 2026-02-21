extends Node

signal item_dropped(item)
signal view_switch_requested

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("switch_view") or event.is_action_pressed("ui_focus_next"): # Default fallbacks
        view_switch_requested.emit()
    if event is InputEventKey:
        if event.pressed and event.keycode == KEY_R:
             view_switch_requested.emit()
