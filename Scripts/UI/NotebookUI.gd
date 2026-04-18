extends Control

signal notebook_closed

@onready var debts_container = %DebtsContainer
@onready var close_button = %CloseButton

func _ready() -> void:
	close_button.pressed.connect(_on_close_button_pressed)
	_populate_debts()

func _populate_debts() -> void:
	# Clear existing children if any
	for child in debts_container.get_children():
		child.queue_free()
		
	var has_debts = false
	
	# StoryManager.customer_debts is a Dictionary: { customer_path: float_amount }
	for path in StoryManager.customer_debts.keys():
		var amount = StoryManager.customer_debts[path]
		if amount > 0:
			has_debts = true
			# Get the character data
			var data: CustomerData = load(path) as CustomerData
			var char_name = "Unknown"
			if data:
				char_name = data.character_name
			
			var hbox = HBoxContainer.new()
			var name_label = Label.new()
			name_label.text = char_name
			name_label.add_theme_font_size_override("font_size", 24)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			var amount_label = Label.new()
			amount_label.text = "Php %.2f" % amount
			amount_label.add_theme_font_size_override("font_size", 24)
			amount_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			
			hbox.add_child(name_label)
			hbox.add_child(amount_label)
			debts_container.add_child(hbox)
	
	if not has_debts:
		var label = Label.new()
		label.text = "No one owes you any money."
		label.add_theme_font_size_override("font_size", 24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		debts_container.add_child(label)

func _on_close_button_pressed() -> void:
	notebook_closed.emit()
	queue_free()
