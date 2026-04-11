extends SceneTree
func _init():
    var customer_scene = preload("res://Scenes/Customer.tscn")
    var customer = customer_scene.instantiate()
    print("Customer instanced successfully!")
    quit()
