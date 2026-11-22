extends WorldInteractor

@export var nokia_ui_scene: PackedScene
## 3D marker near the phone where Uncle Mario's speech bubble will anchor.
@export var phone_anchor: Node3D

var _meshes: Array[MeshInstance3D] = []
var _nokia_root: Node = null  # Kept so we can hide/show the 3D model
var _is_ui_open: bool = false
var _ring_tween: Tween = null
var _nokia_base_pos: Vector3 = Vector3.ZERO
var _is_ringing: bool = false

func _ready() -> void:
	add_to_group("nokia_phone")
	super._ready()
	# Nokia outline needs to be thicker since the model is small/detailed
	outline_width = 96.0
	# RESTORE: Use the specialized 3D mesh outline shader instead of the 2D billboard one
	outline_shader = preload("res://Shaders/outline.gdshader")
	_collect_meshes()

func _collect_meshes() -> void:
	var nokia_root = get_node_or_null("../nokia")
	if not nokia_root:
		nokia_root = get_node_or_null("../nokia_phone")
		
	if not nokia_root:
		push_warning("[NokiaClickRegion] No sibling 'nokia' or 'nokia_phone' found.")
		return
	
	_nokia_root = nokia_root
	if _nokia_root is Node3D:
		_nokia_base_pos = _nokia_root.position
	_find_meshes_recursive(nokia_root)

func set_ringing(active: bool) -> void:
	_is_ringing = active
	if _ring_tween and _ring_tween.is_valid():
		_ring_tween.kill()
		_ring_tween = null

	if active:
		_apply_outline(Color(0.494, 0.761, 0.573))
		if _nokia_root is Node3D:
			_ring_tween = create_tween().set_loops()
			_ring_tween.tween_property(_nokia_root, "position:x", _nokia_base_pos.x + 0.015, 0.05)
			_ring_tween.tween_property(_nokia_root, "position:x", _nokia_base_pos.x - 0.015, 0.05)
	else:
		if _nokia_root is Node3D:
			_nokia_root.position = _nokia_base_pos
		_remove_outline()


func _find_meshes_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		_meshes.append(node)
	for child in node.get_children():
		_find_meshes_recursive(child)

## Override base visual node detection to use our collected mesh list
func get_visual_nodes() -> Array[Node3D]:
	# Cast Array[MeshInstance3D] to Array[Node3D]
	var result: Array[Node3D] = []
	for m in _meshes:
		result.append(m)
	return result

func _is_tutorial_phone_task_active() -> bool:
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	return gm != null and gm.tutorial != null and gm.tutorial.is_waiting_for_phone_call()

func on_hover(is_hovered: bool) -> void:
	if is_hovered:
		var color = default_outline_color
		if MarioManager.is_mario_physically_present and not _is_tutorial_phone_task_active():
			color = Color.RED
		_apply_outline(color)
	else:
		_remove_outline()

func on_interact() -> void:
	if _is_ui_open:
		return

	var is_tutorial_call := _is_tutorial_phone_task_active()
	var is_incoming_call: bool = MarioManager.is_incoming_upgrade_call

	if Dialogic.current_timeline != null and not is_tutorial_call:
		return # Block call while someone is already talking
		
	if MarioManager.is_mario_physically_present and not is_tutorial_call and not is_incoming_call:
		print("[Nokia] Blocked: Uncle Mario is physically present.")
		AudioManager.play_sfx("error")
		return
		
	if nokia_ui_scene:
		_is_ui_open = true
		var ui := nokia_ui_scene.instantiate()
		# Pass the 3D anchor to the NokiaUI before adding to tree
		if phone_anchor:
			ui.phone_anchor = phone_anchor
		get_tree().root.add_child(ui)
		EventBus.nokia_opened.emit()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Restore state when the UI closes (cancel or end of call)
		ui.nokia_closed.connect(_on_nokia_ui_closed, CONNECT_ONE_SHOT)
		var restock_menu = ui.get_node_or_null("RestockMenu")
		if restock_menu and restock_menu.has_signal("menu_close_requested"):
			restock_menu.menu_close_requested.connect(_on_nokia_ui_closed_with_parent.bind(ui), CONNECT_ONE_SHOT)
		var upgrade_menu = ui.get_node_or_null("UpgradeMenu")
		if upgrade_menu and upgrade_menu.has_signal("menu_close_requested"):
			upgrade_menu.menu_close_requested.connect(_on_nokia_ui_closed_with_parent.bind(ui), CONNECT_ONE_SHOT)
		if is_incoming_call and ui.has_method("start_incoming_answer"):
			ui.start_incoming_answer()
	else:
		push_error("[Nokia3D] Missing Nokia UI Scene in the Inspector!")

func _on_nokia_ui_closed() -> void:
	_is_ui_open = false
	# Restore first-person input
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.nokia_closed.emit()

func _on_nokia_ui_closed_with_parent(ui: Node) -> void:
	_is_ui_open = false
	# Free the dynamically instantiated Nokia UI
	if is_instance_valid(ui):
		ui.queue_free()
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.nokia_closed.emit()
