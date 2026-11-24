extends WorldInteractor

## Interactive door between inside the sari-sari store and the outside Karimlan neighborhood.
## Requires Storefront Upgrade Lv. 3 ("Open Door") to unlock; clicking teleports smoothly
## with a crisp fade blink between inside and outside.

const INSIDE_TELEPORT_POS := Vector3(1.40, 2.92, 3.45)
const INSIDE_LOOK_POS := Vector3(1.40, 2.92, -0.50)
const OUTSIDE_TELEPORT_POS := Vector3(1.40, 2.92, 6.20)
const OUTSIDE_LOOK_POS := Vector3(1.40, 2.92, 10.50)
const DOOR_Z_THRESHOLD := 4.90

var _is_teleporting: bool = false


func _ready() -> void:
	outline_shader = preload("res://Shaders/outline.gdshader")
	outline_width = 2.0
	default_outline_color = Color(1.0, 0.86, 0.48, 1.0)
	super._ready()
	add_to_group("store_door")


func refresh_lock_state() -> void:
	pass


func get_visual_nodes() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		var models := parent_node.get_node_or_null("3DModels")
		if is_instance_valid(models):
			var door_mesh := models.find_child("door_floor1", true, false) as MeshInstance3D
			if is_instance_valid(door_mesh):
				result.append(door_mesh)
	return result


func on_hover(is_hovered: bool) -> void:
	super.on_hover(is_hovered)
	if not is_hovered:
		EventBus.helper_prompt_requested.emit("", false)
		return
	if StoryManager.storefront_upgrade_level < 3:
		EventBus.helper_prompt_requested.emit("Locked Door", true)
	elif _is_player_outside():
		EventBus.helper_prompt_requested.emit("Open Door — Return Inside [LMB]", true)
	else:
		EventBus.helper_prompt_requested.emit("Open Door — Step Outside [LMB]", true)


func on_interact() -> void:
	if _is_teleporting or Dialogic.current_timeline != null or DragManager.is_dragging:
		return

	if StoryManager.storefront_upgrade_level < 3:
		EventBus.request_sfx.emit("interact")
		EventBus.show_notification.emit(
			"Locked Tight...",
			"A cool breeze slips under the door, but you don't have the key yet.",
			"interact"
		)
		return

	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player) or not player.has_method("teleport_to"):
		return

	_is_teleporting = true
	EventBus.request_sfx.emit("interact")
	EventBus.helper_prompt_requested.emit("", false)

	var going_inside := _is_player_outside()
	var dest_pos := INSIDE_TELEPORT_POS if going_inside else OUTSIDE_TELEPORT_POS
	var look_pos := INSIDE_LOOK_POS if going_inside else OUTSIDE_LOOK_POS

	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 120
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.color = Color(0.0, 0.0, 0.0, 0.0)
	flash_layer.add_child(rect)
	get_tree().root.add_child(flash_layer)

	var tw_in := flash_layer.create_tween()
	tw_in.tween_property(rect, "color:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw_in.finished

	if is_instance_valid(player):
		player.call("teleport_to", dest_pos, look_pos)

	var tw_out := flash_layer.create_tween()
	tw_out.tween_property(rect, "color:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw_out.finished

	if is_instance_valid(flash_layer):
		flash_layer.queue_free()
	_is_teleporting = false


func _is_player_outside() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	return is_instance_valid(player) and player.global_position.z > DOOR_Z_THRESHOLD
