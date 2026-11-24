class_name StorefrontCustomDisplay
extends Node3D

## Renders the player's custom Roof Signage (Lv.1) and Storefront Promo Poster (Lv.2)
## in 3D space on the sari-sari storefront. Works in both MainGame (live StoryManager state)
## and TitleScreen3D (read-only SaveManager.peek_save() diorama).

const SIGNAGE_OFFSET := 0.018
const POSTER_WORLD_POS := Vector3(-4.81, 3.68, -3.58)
const POSTER_BOARD_SIZE := Vector2(0.92, 1.33) # Matches 540x780 portrait aspect

@export var read_from_save_peek: bool = false

var _signage_mesh: MeshInstance3D = null
var _poster_root: Node3D = null
var _poster_quad: MeshInstance3D = null
var _signage_interactor: Area3D = null
var _poster_interactor: Area3D = null


func _ready() -> void:
	add_to_group("storefront_custom_display")
	if not read_from_save_peek:
		EventBus.storefront_upgraded.connect(_on_storefront_changed)
		EventBus.storefront_artwork_updated.connect(_on_storefront_artwork_updated)
	call_deferred("refresh_display")


func _on_storefront_changed(_lvl: int) -> void:
	refresh_display()


func _on_storefront_artwork_updated(_slot: String) -> void:
	refresh_display()


func refresh_display(override_story: Dictionary = {}) -> void:
	var sf_level := 0
	var has_signage := false
	var has_poster := false

	if not override_story.is_empty():
		sf_level = int(override_story.get("storefront_upgrade_level", 0))
		has_signage = bool(override_story.get("has_custom_signage", false))
		has_poster = bool(override_story.get("has_custom_poster", false))
	elif read_from_save_peek:
		var save := SaveManager.peek_save()
		var story: Dictionary = {}
		if save.has("StoryManager") and save["StoryManager"] is Dictionary:
			story = save["StoryManager"]
		elif save.has("progression") and save["progression"] is Dictionary:
			story = save["progression"]
		sf_level = int(story.get("storefront_upgrade_level", 0))
		has_signage = bool(story.get("has_custom_signage", false))
		has_poster = bool(story.get("has_custom_poster", false))
	else:
		sf_level = StoryManager.storefront_upgrade_level
		has_signage = StoryManager.has_custom_signage
		has_poster = StoryManager.has_custom_poster

	_update_signage(sf_level >= 1, sf_level >= 1 and has_signage)
	_update_poster(sf_level >= 2, sf_level >= 2 and has_poster)


func _update_signage(is_unlocked: bool, show_custom: bool) -> void:
	_ensure_signage_quad()
	if not is_instance_valid(_signage_mesh):
		return

	_set_interactor_active(_signage_interactor, is_unlocked and not read_from_save_peek)

	if not show_custom or not FileAccess.file_exists(StoryManager.SIGNAGE_IMAGE_PATH):
		_signage_mesh.visible = false
		return

	var img := Image.load_from_file(StoryManager.SIGNAGE_IMAGE_PATH)
	if not img or img.is_empty():
		_signage_mesh.visible = false
		return

	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.78
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	_signage_mesh.material_override = mat
	_signage_mesh.visible = true


func _update_poster(show_board: bool, has_art: bool) -> void:
	_ensure_poster_board()
	if not is_instance_valid(_poster_root):
		return

	_poster_root.visible = show_board
	_set_interactor_active(_poster_interactor, show_board and not read_from_save_peek)
	if not show_board or not is_instance_valid(_poster_quad):
		return

	var mat := StandardMaterial3D.new()
	mat.roughness = 0.80
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	if has_art and FileAccess.file_exists(StoryManager.POSTER_IMAGE_PATH):
		var img := Image.load_from_file(StoryManager.POSTER_IMAGE_PATH)
		if img and not img.is_empty():
			mat.albedo_texture = ImageTexture.create_from_image(img)
		else:
			mat.albedo_color = Color(0.97, 0.96, 0.93, 1.0)
	else:
		mat.albedo_color = Color(0.97, 0.96, 0.93, 1.0)
	_poster_quad.material_override = mat


func _ensure_signage_quad() -> void:
	if is_instance_valid(_signage_mesh):
		return

	var models := _find_models_root()
	if not is_instance_valid(models):
		return
	var cube2 := models.find_child("Cube_002", true, false) as MeshInstance3D
	if not is_instance_valid(cube2) or not cube2.mesh:
		return

	var arrays := cube2.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]

	var front_pts: Array[Vector3] = []
	for i in range(verts.size()):
		var wn := (cube2.global_transform.basis * norms[i]).normalized()
		if wn.x < -0.5:
			front_pts.append(cube2.global_transform * verts[i])

	if front_pts.size() < 4:
		return

	# Sort top vs bottom (by Y), then left (-Z) vs right (+Z)
	front_pts.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y > b.y)
	var top_pair := [front_pts[0], front_pts[1]]
	var bot_pair := [front_pts[2], front_pts[3]]
	top_pair.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z < b.z)
	bot_pair.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z < b.z)

	var tl: Vector3 = top_pair[0]
	var tr: Vector3 = top_pair[1]
	var bl: Vector3 = bot_pair[0]
	var br: Vector3 = bot_pair[1]

	var right_dir := (tr - tl).normalized()
	var up_dir := (tl - bl).normalized()
	var normal_dir := right_dir.cross(up_dir).normalized()
	var q_width := maxf(0.1, tl.distance_to(tr) - 0.02)
	var q_height := maxf(0.1, tl.distance_to(bl) - 0.02)
	var center := (tl + tr + bl + br) * 0.25 + normal_dir * SIGNAGE_OFFSET

	var quad := QuadMesh.new()
	quad.size = Vector2(q_width, q_height)

	_signage_mesh = MeshInstance3D.new()
	_signage_mesh.name = "CustomSignageQuad"
	_signage_mesh.mesh = quad
	_signage_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_signage_mesh)
	_signage_mesh.global_transform = Transform3D(Basis(right_dir, up_dir, normal_dir), center)
	_signage_mesh.visible = false

	if not read_from_save_peek:
		_signage_interactor = _create_paint_interactor("SignageInteractor", Vector3(q_width, q_height, 0.2), _signage_mesh.global_transform, "signage")


func _ensure_poster_board() -> void:
	if is_instance_valid(_poster_root):
		return

	_poster_root = Node3D.new()
	_poster_root.name = "CustomPosterBoard"
	add_child(_poster_root)
	_poster_root.global_position = POSTER_WORLD_POS

	var frame_mesh := MeshInstance3D.new()
	frame_mesh.name = "PosterFrame"
	var box := BoxMesh.new()
	box.size = Vector3(0.03, POSTER_BOARD_SIZE.y + 0.06, POSTER_BOARD_SIZE.x + 0.06)
	frame_mesh.mesh = box
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.24, 0.16, 0.10, 1.0)
	wood.roughness = 0.85
	frame_mesh.material_override = wood
	_poster_root.add_child(frame_mesh)

	_poster_quad = MeshInstance3D.new()
	_poster_quad.name = "CustomPosterQuad"
	var quad := QuadMesh.new()
	quad.size = POSTER_BOARD_SIZE
	_poster_quad.mesh = quad
	_poster_quad.position = Vector3(-0.017, 0.0, 0.0)
	_poster_quad.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	_poster_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_poster_root.add_child(_poster_quad)
	_poster_root.visible = false

	if not read_from_save_peek:
		var poster_xform := Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), POSTER_WORLD_POS)
		_poster_interactor = _create_paint_interactor("PosterInteractor", Vector3(POSTER_BOARD_SIZE.x, POSTER_BOARD_SIZE.y, 0.2), poster_xform, "poster")


func _find_models_root() -> Node:
	var p := get_parent()
	if is_instance_valid(p):
		var direct := p.get_node_or_null("3DModels")
		if direct:
			return direct
		var up := p.get_parent()
		if is_instance_valid(up):
			return up.get_node_or_null("3DModels")
	return null


func _create_paint_interactor(area_name: String, box_size: Vector3, world_xform: Transform3D, slot_name: String) -> Area3D:
	var area := _PaintPropInteractor.new()
	area.name = area_name
	area.slot_name = slot_name
	var col := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = box_size
	col.shape = shp
	area.add_child(col)
	add_child(area)
	area.global_transform = world_xform
	return area


func _set_interactor_active(area: Area3D, active: bool) -> void:
	if not is_instance_valid(area):
		return
	area.visible = active
	area.monitoring = active
	area.monitorable = active
	area.collision_layer = 1 if active else 0


class _PaintPropInteractor extends WorldInteractor:
	var slot_name: String = "signage"

	func on_hover(is_hovered: bool) -> void:
		if is_hovered and _can_interact_from_outside():
			var label := "Repaint Promo Poster [LMB]" if slot_name == "poster" else "Repaint Roof Signage [LMB]"
			EventBus.helper_prompt_requested.emit(label, true)
		else:
			EventBus.helper_prompt_requested.emit("", false)

	func on_interact() -> void:
		if not _can_interact_from_outside():
			return
		if Dialogic.current_timeline != null or DragManager.is_dragging:
			return
		if not get_tree().get_nodes_in_group("storefront_canvas_active").is_empty():
			return
		AudioManager.play_sfx("interact")
		var overlay_cls = preload("res://Scripts/UI/StorefrontCanvasOverlay.gd")
		var overlay = overlay_cls.new()
		get_tree().root.add_child(overlay)
		overlay.open_editor(slot_name)

	func _can_interact_from_outside() -> bool:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		return is_instance_valid(player) and player.global_position.z > 4.9
