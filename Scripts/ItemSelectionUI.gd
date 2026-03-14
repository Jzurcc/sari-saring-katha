class_name ItemSelectionUI
extends CanvasLayer

signal item_selected(item_index: int)
signal cancelled()

@onready var panel: Panel = $Panel
@onready var grid: GridContainer = $Panel/MarginContainer/VBoxContainer/GridContainer

var close_btn: Button

var max_items: int = 33  # Default max, can be set externally

func set_item_count(count: int) -> void:
	max_items = count
	# Clear existing buttons and recreate
	for child in grid.get_children():
		child.queue_free()
	_create_buttons()

func _ready() -> void:
	panel.visible = false
	_create_buttons()
	_create_close_button()

func _create_close_button() -> void:
	# Remove old button if exists
	if panel.has_node("CloseButton"):
		var old = panel.get_node("CloseButton")
		old.queue_free()
	
	# Create new X button
	var btn = Button.new()
	btn.name = "CloseButton"
	btn.text = "X"
	btn.custom_minimum_size = Vector2(40, 40)
	
	# Simple positioning - place at top right of panel
	var panel_size = panel.size
	btn.position = Vector2(panel_size.x - 50, 5)  # 50px from right edge, 5px from top
	
	# Connect signal
	btn.pressed.connect(_on_close_pressed)
	
	# Add to panel
	panel.add_child(btn)
	print("Close button created for ItemSelectionUI")

func _create_buttons() -> void:
	grid.columns = 6
	
	for i in range(max_items):
		var button = Button.new()
		button.custom_minimum_size = Vector2(80, 80)
		
		var texture_path = "res://Assets/items/%d.png" % (i + 1)
		var texture = load(texture_path)
		
		if texture:
			var texture_rect = TextureRect.new()
			texture_rect.texture = texture
			texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Make TextureRect fill the button
			texture_rect.anchor_right = 1.0
			texture_rect.anchor_bottom = 1.0
			texture_rect.offset_left = 0
			texture_rect.offset_top = 0
			texture_rect.offset_right = 0
			texture_rect.offset_bottom = 0
			button.add_child(texture_rect)
		else:
			# If texture fails to load, show the item number
			button.text = str(i + 1)
		
		button.pressed.connect(_on_button_pressed.bind(i))
		grid.add_child(button)

func _on_button_pressed(index: int) -> void:
	print("DEBUG: ItemSelectionUI button pressed, index:", index)
	panel.visible = false
	item_selected.emit(index)

func _on_close_pressed() -> void:
	print("X button pressed! (ItemSelectionUI)")
	panel.visible = false
	cancelled.emit()

func show_selection() -> void:
	panel.visible = true
	# Removed: panel.grab_focus() - causes warning

func hide_selection() -> void:
	panel.visible = false
