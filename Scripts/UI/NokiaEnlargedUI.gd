extends Control

var current_input: String = ""
var target_number: String = "62777444666"

@export var store_menu: Control

@onready var close_btn = $CloseButton
@onready var grid = $PhonePanel/GridContainer
@onready var screen_label = $PhonePanel/ScreenLabel

func _ready() -> void:
    close_btn.pressed.connect(queue_free)
    screen_label.text = ""
    
    # Assign all Generic Buttons in the grid
    for btn in grid.get_children():
        if btn is Button:
            # We assume buttons are simply named "1", "2", "3" etc.
            var digit = btn.name
            btn.pressed.connect(_on_key_pressed.bind(digit))

func _on_key_pressed(digit: String) -> void:
    current_input += digit
    screen_label.text = current_input
    
    # Check if number is complete
    if current_input.ends_with(target_number):
        _trigger_store_menu()
        
    # Prevent infinite length
    if current_input.length() > 20:
        current_input = current_input.right(11)
        screen_label.text = current_input

func _trigger_store_menu() -> void:
    if InventoryManager.customers_needed_for_delivery > 0:
        if Dialogic.timeline_exists("UncleMario_Call_Rest"):
            Dialogic.start("UncleMario_Call_Rest")
    else:
        # Number accepted!
        if store_menu and store_menu.has_method("open_menu"):
            store_menu.open_menu()
