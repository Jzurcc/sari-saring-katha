extends WorldInteractor
class_name TrashInteractable

## A dedicated interactable for deleting unwanted items.
## Includes "game feel" logic like squash & stretch and particle feedback.

func _ready() -> void:
	super._ready()
	add_to_group("trash")
	
	# Default outline color for trash could be a slight red or just white
	default_outline_color = Color(1.0, 0.8, 0.8)

## Called when an item is dropped onto this Area3D.
func receive_item(item: DraggableItem) -> void:
	if not item: return
	
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
	
	# 4. Cleanup
	item.notify_placed()
	item.queue_free()

func _play_trash_animation() -> void:
	var visuals = get_visual_nodes()
	if visuals.is_empty(): return
	
	var visual = visuals[0]
	var tw = create_tween()
	var start_scale = visual.scale
	
	# Fast Squash (Wider and shorter)
	tw.tween_property(visual, "scale", start_scale * Vector3(1.2, 0.8, 1.2), 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Fast Stretch (Taller and thinner)
	tw.tween_property(visual, "scale", start_scale * Vector3(0.9, 1.15, 0.9), 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# Overshoot bounce back to normal
	tw.tween_property(visual, "scale", start_scale, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
