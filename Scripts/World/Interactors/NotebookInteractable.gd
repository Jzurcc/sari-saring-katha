extends WorldInteractor

@export var notebook_ui_scene: PackedScene

const AttentionBadge3D = preload("res://Scripts/World/Entities/CustomerAttentionBadge3D.gd")
const BLINK_COLOR := Color(1.0, 0.85, 0.15, 1.0)
const BLINK_DIM_COLOR := Color(1.0, 0.85, 0.15, 0.12)

var _meshes: Array[MeshInstance3D] = []
var _is_ui_open: bool = false
var _is_hovered: bool = false
var _blink_tween: Tween = null
var _attention_badge: AttentionBadge3D = null

func _ready() -> void:
	add_to_group("notebook_item")
	super._ready()
	# Notebook outline
	outline_width = 64.0
	outline_shader = preload("res://Shaders/outline.gdshader")
	_collect_meshes()
	_attention_badge = AttentionBadge3D.new()
	add_child(_attention_badge)
	_attention_badge.position = Vector3(0.0, 0.42, 0.0)
	_attention_badge.set_base_y(0.42)
	StoryManager.pending_debts_changed.connect(_refresh_blink_state)
	EventBus.customer_satisfied.connect(_on_customer_left)
	EventBus.customer_dismissed.connect(_on_customer_left)
	_refresh_blink_state()

func _on_customer_left(_customer: Customer) -> void:
	_refresh_blink_state()

func _refresh_blink_state() -> void:
	var has_pending := StoryManager.has_pending_debts()
	if is_instance_valid(_attention_badge):
		var show_badge := has_pending and not _is_ui_open and Dialogic.current_timeline == null
		_attention_badge.set_mode(AttentionBadge3D.Mode.UNGREETED if show_badge else AttentionBadge3D.Mode.HIDDEN)

	if _is_hovered:
		_stop_blink()
		_apply_outline(BLINK_COLOR if has_pending else default_outline_color)
		return

	if has_pending and Dialogic.current_timeline == null:
		_start_blink()
	else:
		_stop_blink()
		_remove_outline()

func _start_blink() -> void:
	if _blink_tween and _blink_tween.is_valid():
		return
	_apply_outline(BLINK_COLOR)
	if not _outline_mat:
		return
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_method(_set_blink_color, BLINK_DIM_COLOR, BLINK_COLOR, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_blink_tween.tween_method(_set_blink_color, BLINK_COLOR, BLINK_DIM_COLOR, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_blink_color(col: Color) -> void:
	if _outline_mat:
		_outline_mat.set_shader_parameter("outline_color", col)

func _stop_blink() -> void:
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = null

func _collect_meshes() -> void:
	var notebook_root = get_node_or_null("../notebook")
	if not notebook_root:
		push_warning("[NotebookInteractable] No sibling 'notebook' found.")
		return
	
	_find_meshes_recursive(notebook_root)

func _find_meshes_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		_meshes.append(node)
	for child in node.get_children():
		_find_meshes_recursive(child)

## Override base visual node detection to use our collected mesh list
func get_visual_nodes() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for m in _meshes:
		result.append(m)
	return result

func on_hover(is_hovered: bool) -> void:
	_is_hovered = is_hovered
	_refresh_blink_state()

func on_interact() -> void:
	if _is_ui_open:
		return

	if Dialogic.current_timeline != null:
		return # Block call while someone is already talking
		
	if notebook_ui_scene:
		_is_ui_open = true
		var ui := notebook_ui_scene.instantiate()
		get_tree().root.add_child(ui)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ui.notebook_closed.connect(_on_notebook_ui_closed, CONNECT_ONE_SHOT)
	else:
		push_error("[NotebookInteractable] Missing Notebook UI Scene in the Inspector!")

func _on_notebook_ui_closed() -> void:
	_is_ui_open = false
	# Restore first-person input
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh_blink_state()
