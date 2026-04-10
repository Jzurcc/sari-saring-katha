extends Control

signal catalog_purchase_confirmed(total_cost: int, items_bought: Dictionary)
signal catalog_menu_closed

@onready var container = $ColorRect/VBoxContainer/ScrollContainer/VBoxContainer
@onready var total_price_label = $ColorRect/VBoxContainer/BottomPanel/HBoxContainer/TotalValue
@onready var cancel_btn = $ColorRect/VBoxContainer/BottomPanel/HBoxContainer/CancelBtn
@onready var confirm_btn = $ColorRect/VBoxContainer/BottomPanel/HBoxContainer/ConfirmBtn

var selected_items: Dictionary = {} # Dictionary mapping ItemData to int (order amount)
var total_price: int = 0

func _ready() -> void:
    cancel_btn.pressed.connect(_on_cancel_pressed)
    confirm_btn.pressed.connect(_on_confirm_pressed)
    hide() # Hidden by default
    populate_menu()

func open_menu() -> void:
    populate_menu() # Refresh stocks logically
    selected_items.clear()
    total_price = 0
    _update_total_price()
    show()

func populate_menu() -> void:
    # Clear existing items
    for child in container.get_children():
        child.queue_free()
        
    var all_items = InventoryManager.get_all_items()
    var categories = {}
    
    # Group items by category
    for item in all_items:
        if not categories.has(item.category):
            categories[item.category] = []
        categories[item.category].append(item)
        
    for cat in categories.keys():
        # Add category header
        var header = Label.new()
        header.text = "-- " + cat.capitalize() + " --"
        header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        container.add_child(header)
        
        # Add item rows
        for item in categories[cat]:
            var current_stock = InventoryManager.get_stock(item)
            
            var item_row = HBoxContainer.new()
            
            var name_lbl = Label.new()
            name_lbl.text = item.item_name
            name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            
            var stock_lbl = Label.new()
            stock_lbl.text = "In Stock: %d/%d" % [current_stock, item.max_stock]
            stock_lbl.custom_minimum_size = Vector2(100, 0)
            
            var price_lbl = Label.new()
            price_lbl.text = "₱" + str(item.price)
            price_lbl.custom_minimum_size = Vector2(40, 0)
            
            var minus_btn = Button.new()
            minus_btn.text = "-"
            
            var count_lbl = Label.new()
            count_lbl.text = "0"
            count_lbl.custom_minimum_size = Vector2(30, 0)
            count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            
            var plus_btn = Button.new()
            plus_btn.text = "+"
            
            # Connect signals
            minus_btn.pressed.connect(_on_item_change.bind(item, count_lbl, -1))
            plus_btn.pressed.connect(_on_item_change.bind(item, count_lbl, 1))
            
            # Construct row
            item_row.add_child(name_lbl)
            item_row.add_child(stock_lbl)
            item_row.add_child(price_lbl)
            item_row.add_child(minus_btn)
            item_row.add_child(count_lbl)
            item_row.add_child(plus_btn)
            
            container.add_child(item_row)

func _on_item_change(item: ItemData, lbl: Label, amount: int) -> void:
    var count = selected_items.get(item, 0)
    var current_stock = InventoryManager.get_stock(item)
    
    var new_count = count + amount
    
    # Cannot order less than 0
    if new_count < 0:
        return
        
    # Cannot order more than what's needed to reach max_stock
    if current_stock + new_count > item.max_stock:
        return
        
    selected_items[item] = new_count
    
    # Update total price based on diff
    total_price += amount * item.price
    
    # Update UI labels
    lbl.text = str(new_count)
    _update_total_price()

func _update_total_price() -> void:
    total_price_label.text = "₱" + str(total_price)

func _on_cancel_pressed() -> void:
    catalog_menu_closed.emit()
    hide()

func _on_confirm_pressed() -> void:
    if total_price > 0:
        catalog_purchase_confirmed.emit(total_price, selected_items)
        hide()
        
        # Set cooldown for Uncle Mario (3 to 5 customers)
        InventoryManager.customers_needed_for_delivery = randi() % 3 + 3
        InventoryManager.save_state()
        
        # Start Delivery Sequence dynamically
        var delivery_script = load("res://Scripts/Cutscenes/TricycleDelivery.gd")
        var delivery_node = CanvasLayer.new()
        delivery_node.set_script(delivery_script)
        get_tree().root.add_child(delivery_node)
        
        # Start the cutscene and pass the dictionary of orders
        delivery_node.call_deferred("start_delivery", selected_items)

