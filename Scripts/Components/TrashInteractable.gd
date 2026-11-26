extends WorldInteractor
class_name TrashInteractable

## A dedicated interactable for deleting unwanted items.
## Includes "game feel" logic like squash & stretch and particle feedback.
 
var _visual_base_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	super._ready()
	add_to_group("trash")
	
	var visuals = get_visual_nodes()
	if not visuals.is_empty():
		_visual_base_scale = visuals[0].scale
	
	# Default outline color for trash could be a slight red or just white
	default_outline_color = Color(1.0, 0.8, 0.8)

	EventBus.trash_can_unlocked.connect(_on_trash_can_unlocked)
	refresh_visibility(false)

func _on_trash_can_unlocked() -> void:
	refresh_visibility(true)

func refresh_visibility(play_pop_in: bool = false) -> void:
	var was_visible := visible
	var unlocked := StoryManager.has_trash_can
	visible = unlocked
	monitoring = unlocked
	monitorable = unlocked
	collision_layer = 1 if unlocked else 0

	var body_col := get_node_or_null("TrashPhysicsBody/CollisionShape3D") as CollisionShape3D
	if body_col:
		body_col.disabled = not unlocked

	if not unlocked:
		on_hover(false)
		return

	if not was_visible and play_pop_in:
		_play_trash_animation()
		if VisualEffectManager.has_method("spawn_impact_dust"):
			VisualEffectManager.spawn_impact_dust(global_position + Vector3(0, 0.35, 0))

## Called when an item is dropped onto this Area3D.
func receive_item(item: DraggableItem) -> void:
	if not visible or not item: return
	
	# 1. Game Feel: Squash and Stretch
	_play_trash_animation()
	
	# 2. VFX: Poof!
	if VisualEffectManager.has_method("spawn_impact_dust"):
		VisualEffectManager.spawn_impact_dust(global_position + Vector3(0, 0.5, 0))
	
	# 3. SFX: Throw away sound
	# (Assuming EventBus or similar handles SFX strings)
	if EventBus.has_signal("request_sfx"):
		# Using 'trash' as a placeholder sound name
		EventBus.request_sfx.emit("trash")
	
	# 4. Recycling Program: refund a share of the item's original value
	if not item.is_transient:
		var refund := StoryManager.get_recycling_refund(item.item_data)
		if refund > 0.0:
			for gm in get_tree().get_nodes_in_group("game_manager"):
				if gm.has_method("add_money"):
					gm.add_money(refund)
					EventBus.show_notification.emit("Recycled!", "+₱%.2f refunded" % refund, "purchase")
					break

	# 5. Cleanup
	item.notify_placed()
	item.play_disappear_animation()

func on_interact() -> void:
	if not visible:
		return
	if EventBus.has_signal("request_sfx"):
		EventBus.request_sfx.emit("trash")
	_play_trash_animation()

func _play_trash_animation() -> void:
	var visuals = get_visual_nodes()
	if visuals.is_empty(): return
	
	var visual = visuals[0]
	var tw = create_tween()
	var start_scale = _visual_base_scale
	
	# Fast Squash (Wider and shorter)
	tw.tween_property(visual, "scale", start_scale * Vector3(1.2, 0.8, 1.2), 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Fast Stretch (Taller and thinner)
	tw.tween_property(visual, "scale", start_scale * Vector3(0.9, 1.15, 0.9), 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# Overshoot bounce back to normal
	tw.tween_property(visual, "scale", start_scale, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
