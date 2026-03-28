extends SceneTree
func _init():
	var packed_scene = load("res://Scenes/MainGame.tscn")
	if packed_scene:
		print("Scene loaded successfully!")
		
		# test instancing
		var instance = packed_scene.instantiate()
		if instance:
			print("Scene instanced successfully!")
		else:
			print("Failed to instance scene")
	else:
		print("Failed to load scene")
	quit()
