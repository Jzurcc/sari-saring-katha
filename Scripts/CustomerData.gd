class_name CustomerData
extends Resource

@export var character_id: String
@export var character_name: String
## The sprite sheet / texture displayed for this customer in the 3D world.
@export var sprite_texture: Texture2D
## The Dialogic Character resource (.dch) for this customer
@export var dialogic_character: DialogicCharacter
## The pool of items this customer can ask for during a Filler transaction.
@export var filler_items: Array[ItemData] = []
## Base directory containing the dialog files for this character, e.g. "res://Dialogue/kuyakap/"
@export var timelines_dir: String = ""
## Multiplier applied to the 3D sprite scale.
@export var sprite_scale: float = 1.0

## The sound played once per dialogue text bubble (e.g., KuyaKap's blip)
@export var dialogue_blip_sound: AudioStream
