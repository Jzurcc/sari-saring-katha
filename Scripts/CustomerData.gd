class_name CustomerData
extends Resource

@export var character_id: String
@export var character_name: String
## The pool of items this customer can ask for during a Filler transaction.
@export var filler_items: Array[ItemData] = []
## Base directory containing the dialog files for this character, e.g. "res://Dialogue/KuyaKap/"
@export var timelines_dir: String = ""

## The sound played once per dialogue text bubble (e.g., KuyaKap's blip)
@export var dialogue_blip_sound: AudioStream
