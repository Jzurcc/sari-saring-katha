class_name ConfirmationPopup
extends CanvasLayer

signal confirmed(item_index: int)

@onready var panel: Panel = $Panel
@onready var texture_rect: TextureRect = $Panel/MarginContainer/VBoxContainer/TextureRect
@onready var item_name_label: Label = $Panel/MarginContainer/VBoxContainer/ItemNameLabel
@onready var confirm_btn: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_btn: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer/CancelButton
var close_btn: Button

var current_index: int = -1

func _ready() -> void:
	print("ConfirmationPopup._ready() called")
	if not panel:
		print("ERROR: panel is null in _ready!")
		return
	panel.visible = false
	
	# Connect confirm and cancel buttons
	if confirm_btn:
		print("Connecting confirm_btn")
		confirm_btn.pressed.connect(_on_confirm)
	else:
		print("ERROR: confirm_btn is null!")
	
	if cancel_btn:
		print("Connecting cancel_btn")
		cancel_btn.pressed.connect(_on_cancel)
	else:
		print("ERROR: cancel_btn is null!")
	
	# Fix OO button text visibility - make them white and ensure they're visible
	confirm_btn.add_theme_color_override("font_color", Color.WHITE)
	confirm_btn.add_theme_color_override("font_hover_color", Color.YELLOW)
	cancel_btn.add_theme_color_override("font_color", Color.WHITE)
	cancel_btn.add_theme_color_override("font_hover_color", Color.YELLOW)
	
	# Also try setting the label directly in case theme override doesn't work
	if confirm_btn.get_child_count() > 0:
		for child in confirm_btn.get_children():
			if child is Label:
				child.modulate = Color.WHITE
	if cancel_btn.get_child_count() > 0:
		for child in cancel_btn.get_children():
			if child is Label:
				child.modulate = Color.WHITE
	
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
	btn.pressed.connect(_on_cancel)
	
	# Add to panel
	panel.add_child(btn)
	print("Close button created for ConfirmationPopup")

func show_confirmation(index: int, texture: Texture2D, item_name: String = "") -> void:
	current_index = index
	texture_rect.texture = texture
	item_name_label.text = item_name if item_name != "" else "Item #%d" % (index + 1)
	panel.visible = true
	print("Confirmation shown for item: ", index)

func _on_confirm() -> void:
	print("Confirm button pressed! Index:", current_index)
	if not is_instance_valid(panel):
		print("ERROR: panel is not valid!")
		return
	panel.visible = false
	if has_signal("confirmed"):
		confirmed.emit(current_index)
	else:
		print("ERROR: confirmed signal does not exist!")

func _on_cancel() -> void:
	print("Cancel/X button pressed! (ConfirmationPopup)")
	panel.visible = false

func emit_confirmed(index: int) -> void:
	"""Manually emit the confirmed signal with the given index."""
	current_index = index
	confirmed.emit(current_index)

func hide_popup() -> void:
	"""Hide the confirmation popup panel."""
	if panel:
		panel.visible = false
