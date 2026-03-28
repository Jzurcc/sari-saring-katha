class_name TransactionTray
extends Area3D

signal item_placed(item)

@onready var glow_mesh: MeshInstance3D = $GlowMesh
@onready var drop_light: OmniLight3D = $DropLight

func _ready() -> void:
	add_to_group("transaction_tray")

func activate_dropzone() -> void:
	glow_mesh.visible = true
	var tween := create_tween()
	tween.tween_property(drop_light, "light_energy", 1.5, 0.3)

func deactivate_dropzone() -> void:
	var tween := create_tween()
	tween.tween_property(drop_light, "light_energy", 0.0, 0.3)
	await tween.finished
	glow_mesh.visible = false

func receive_item(item: DraggableItem) -> void:
	# Don't re-show 3D visuals — item came from 2D drag overlay.
	# MainGame._on_item_placed will either free or return the item.
	deactivate_dropzone()
	item_placed.emit(item)
	print("Item received in Tray: ", item.item_data.item_name if item.item_data else "unknown")
