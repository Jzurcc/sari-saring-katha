extends Button

@onready var character_sprite: TextureRect = %CharacterSprite
@onready var name_label: Label = %NameLabel
@onready var lock_overlay: Control = %LockOverlay

var character_data: CustomerData

func setup(data: CustomerData, is_locked: bool) -> void:
	character_data = data
	
	if is_locked:
		name_label.text = "???"
		lock_overlay.show()
		character_sprite.modulate = Color(0, 0, 0, 1)
		disabled = true
	else:
		name_label.text = data.character_name.to_upper()
		lock_overlay.hide()
		character_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		disabled = false
		
	character_sprite.texture = data.sprite_texture
	# Manual offset for "halfbody" torso-level framing
	# Reduced scale by 25% (from 1.2 to 0.9)
	character_sprite.position.y = 20 
	character_sprite.scale = Vector2(0.9, 0.9) 
