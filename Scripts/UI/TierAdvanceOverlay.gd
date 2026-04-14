extends CanvasLayer

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var tier_label: Label = %TierLabel
@onready var source_label: Label = %SourceLabel
@onready var grid: GridContainer = %ItemGrid
@onready var control: Control = $Control

func _ready() -> void:
	control.visible = false
	EventBus.tier_advanced.connect(_on_tier_advanced)
	
	# Add a simple dismiss button via code if it doesn't exist in the scene
	var btn = Button.new()
	btn.text = "Continue"
	btn.custom_minimum_size = Vector2(120, 40)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	$Control/Panel/VBox.add_child(btn)
	btn.pressed.connect(_on_close_pressed)

func _on_tier_advanced(new_tier: int, source: String) -> void:
	tier_label.text = "TIER %d UNLOCKED" % new_tier
	source_label.text = "Reached via %s" % source
	
	# Clear old items
	for child in grid.get_children():
		child.queue_free()
	
	# Show icons + names for new items
	var all_items = InventoryManager.get_all_items()
	for item in all_items:
		if item.tier == new_tier:
			var item_vbox = VBoxContainer.new()
			
			var rect = TextureRect.new()
			rect.texture = item.texture
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.custom_minimum_size = Vector2(80, 80)
			item_vbox.add_child(rect)
			
			var name_label = Label.new()
			name_label.text = item.item_name
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.add_theme_font_size_override("font_size", 14)
			item_vbox.add_child(name_label)
			
			grid.add_child(item_vbox)
	
	# Visual Fanfare (Tween)
	control.visible = true
	control.modulate.a = 0
	control.scale = Vector2(0.8, 0.8)
	control.pivot_offset = control.size / 2
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, 0.5)
	tween.tween_property(control, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_close_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 0.0, 0.3)
	await tween.finished
	control.visible = false
