extends Control

func _ready() -> void:
	$Buttons/NewGame.grab_focus()

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/MainGame.tscn")

func _on_options_pressed() -> void:
	$OptionsOverlay.show()

func _on_options_close_pressed() -> void:
	$OptionsOverlay.hide()

func _on_exit_pressed() -> void:
	get_tree().quit()
