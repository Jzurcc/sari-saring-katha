extends ColorRect

signal closed

@onready var collection_grid : GridContainer = %Grid
@onready var detail_overlay : Control = %DetailOverlay
@onready var detail_image : TextureRect = %DetailImage
@onready var detail_name : Label = %DetailName
@onready var detail_info : Label = %DetailInfo
@onready var _ui_player : AudioStreamPlayer = AudioStreamPlayer.new()

var _sfx_click   : AudioStream = preload("res://Audio/SFX/ui_sfx_4.mp3")
var _sfx_confirm : AudioStream = preload("res://Audio/SFX/ui_sfx_9.mp3")

func _ready() -> void:
	_ui_player.bus = "SFX"
	add_child(_ui_player)
	_hide_details()

func open() -> void:
	show()
	_hide_details()
	_populate_collection()

func close() -> void:
	_play_confirm()
	hide()
	closed.emit()

func _play_click() -> void:
	_ui_player.stream = _sfx_click
	_ui_player.play()

func _play_confirm() -> void:
	_ui_player.stream = _sfx_confirm
	_ui_player.play()

func _populate_collection() -> void:
	# Clear existing items
	for child in collection_grid.get_children():
		child.queue_free()
	
	# Load item cards
	var ItemCardScript = load("res://Scripts/UI/CollectionItemCard.gd")
	var all_items = InventoryManager.get_all_items()
	
	for item in all_items:
		if not item.can_be_sold:
			continue
			
		var card = Button.new()
		card.set_script(ItemCardScript)
		collection_grid.add_child(card)
		
		var unlocked = StoryManager.is_item_unlocked(item)
		card.setup(item, unlocked)
		
		if unlocked:
			card.item_pressed.connect(_show_details)

func _show_details(item: ItemData) -> void:
	_play_click()
	detail_image.texture = item.texture
	detail_name.text = item.item_name.to_upper()
	detail_info.text = "Category: %s  |  Tier: %d" % [item.category.capitalize(), item.tier]
	
	detail_overlay.show()
	
	# Fade in effect
	detail_overlay.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(detail_overlay, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _hide_details() -> void:
	detail_overlay.hide()

func _on_detail_close_pressed() -> void:
	_play_confirm()
	_hide_details()
