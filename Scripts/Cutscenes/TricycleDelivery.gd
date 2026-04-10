extends CanvasLayer

var tricycle_texture: Texture2D
var tricycle_rect: TextureRect

func _ready() -> void:
    layer = 100 # Ensure it stays above everything
    
    # Try to load user's UI tricycle asset
    var path = "res://Assets/ui/tricycle.png"
    if ResourceLoader.exists(path):
        tricycle_texture = load(path)
    # They might have typed Tricycle, trying capital
    elif ResourceLoader.exists("res://Assets/ui/Tricycle.png"):
        tricycle_texture = load("res://Assets/ui/Tricycle.png")
    
    tricycle_rect = TextureRect.new()
    tricycle_rect.texture = tricycle_texture
    
    if not tricycle_texture:
        # Fallback block if no texture exists
        tricycle_rect.custom_minimum_size = Vector2(250, 150)
        var placeholder = ColorRect.new()
        placeholder.color = Color.DARK_ORANGE
        placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        var lbl = Label.new()
        lbl.text = "Tricycle Asset\nMissing"
        lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        placeholder.add_child(lbl)
        tricycle_rect.add_child(placeholder)
        
    add_child(tricycle_rect)
    
    # Set initial position off-screen left
    var viewport_size = get_viewport().get_visible_rect().size
    tricycle_rect.position = Vector2(-300, viewport_size.y - 250)
    
func start_delivery(items_to_restock: Dictionary) -> void:
    # 1. Start dialogue first
    if Dialogic.timeline_exists("UncleMario_Delivery"):
        Dialogic.start("UncleMario_Delivery")
        
    # 2. Tween tricycle across the screen
    var tween = create_tween()
    var target_x = get_viewport().get_visible_rect().size.x + 100
    
    # Move across the screen over 3 seconds
    tween.tween_property(tricycle_rect, "position:x", target_x, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    
    await tween.finished
    
    # 3. Actually restock the items
    for item in items_to_restock.keys():
        var amount_ordered = items_to_restock[item]
        var current_stock = InventoryManager.get_stock(item)
        InventoryManager.restock_item(item, current_stock + amount_ordered)
        
    # 4. Find all ItemContainers and refresh them
    # Iterate all nodes in current scene
    _refresh_containers(get_tree().root)
            
    print("[TricycleDelivery] Delivery complete. Restocked.")
    InventoryManager.save_state()
    queue_free()

func _refresh_containers(node: Node) -> void:
    if node is ItemContainer:
        node.refresh_visibility()
    for child in node.get_children():
        _refresh_containers(child)
