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

	# 1. Pending (unlogged) utang entries with "+ Add Loan" button
	if StoryManager.has_pending_debts():
		var pending_header := Label.new()
		pending_header.text = "New Utang to Record"
		pending_header.add_theme_font_size_override("font_size", 20)
		pending_header.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		debts_container.add_child(pending_header)

		for i in range(StoryManager.pending_debts.size()):
			var entry: Dictionary = StoryManager.pending_debts[i]
			var path: String = str(entry.get("customer_path", ""))
			var amount: float = float(entry.get("amount", 0.0))
			var data: CustomerData = load(path) as CustomerData if ResourceLoader.exists(path) else null
			var char_name: String = data.character_name if data else "Customer"

			var card := PanelContainer.new()
			var card_style := UIStyle.create_flat_stylebox(Color(0.22, 0.2, 0.12, 0.9), 8, 12, 10)
			card_style.border_color = Color(1.0, 0.85, 0.2, 0.9)
			card_style.border_width_left = 2
			card_style.border_width_top = 2
			card_style.border_width_right = 2
			card_style.border_width_bottom = 2
			card.add_theme_stylebox_override("panel", card_style)

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			card.add_child(row)

			var info_lbl := Label.new()
			info_lbl.text = "%s  (Php %.2f)" % [char_name, amount]
			info_lbl.add_theme_font_size_override("font_size", 21)
			info_lbl.add_theme_color_override("font_color", Color.WHITE)
			info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(info_lbl)

			var add_btn := Button.new()
			add_btn.text = "+ Add Loan"
			add_btn.custom_minimum_size = Vector2(130, 38)
			UIStyle.style_button(add_btn, UIStyle.COLOR_CONFIRM, Color.WHITE, 17.0)
			add_btn.pressed.connect(_on_add_loan_pressed.bind(i))
			row.add_child(add_btn)

			debts_container.add_child(card)

		var sep := HSeparator.new()
		debts_container.add_child(sep)

	# 2. Recorded loans
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
	
	if not has_debts and not StoryManager.has_pending_debts():
		var label = Label.new()
		label.text = "No one owes you any money."
		label.add_theme_font_size_override("font_size", 24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		debts_container.add_child(label)

func _on_add_loan_pressed(index: int) -> void:
	AudioManager.play_sfx("interact")
	StoryManager.commit_pending_debt(index)
	_populate_debts()

func _on_close_button_pressed() -> void:
	notebook_closed.emit()
	queue_free()
