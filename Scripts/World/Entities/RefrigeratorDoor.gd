## RefrigeratorDoor.gd
## Root script for the refrigerator door mesh (MeshInstance3D).
## Chapter is driven by PlayerInteraction's center-screen raycast which
## calls on_hover() / on_interact() on the Area3D child. The Area3D forwards
## those calls here via FridgeDoorInteractor.gd.
##
## PIVOT: set the `hinge` export to a clean Node3D parent (no baked rotation)
## positioned at the door's hinge edge. The script rotates that node on Y
## instead of self, giving a clean swing regardless of any baked mesh transform.
class_name RefrigeratorDoor
extends MeshInstance3D

# ----- Exports ------------------------------------------------------------------
## Node to rotate for the door swing (should be a clean Node3D at the hinge).
## Leave empty to fall back to rotating self.
@export var hinge: Node3D = null

# ----- Tunables -----------------------------------------------------------------
const OPEN_ANGLE_DEG := 90.0   ## Flip sign if the door swings the wrong way
const ANIM_DURATION   := 0.5
const OUTLINE_SHADER  := "res://Shaders/outline.gdshader"

# ----- State --------------------------------------------------------------------
var is_open: bool = false
var _tween: Tween
var _outline_mat: ShaderMaterial
var _pivot: Node3D
var _active_mists: Array[CPUParticles3D] = []
var _wind_gusts_remaining: int = 0
var _wind_timer: float = 0.0

# ================================================================================
func _ready() -> void:
	add_to_group("fridge_surfaces")
	_resolve_pivot()
	_build_outline_material()
	set_process(true)
	EventBus.day_started.connect(_on_day_started)
	EventBus.mayari_card_changed.connect(_on_mayari_card_changed)
	_schedule_disembodied_wind()
	# Sync initial coldness state to HUD
	EventBus.fridge_coldness_changed.emit(StoryManager.fridge_coldness, is_open, StoryManager.is_fridge_warm)

func _on_day_started(_day: int) -> void:
	_schedule_disembodied_wind()

func _on_mayari_card_changed(_card_id: String) -> void:
	_schedule_disembodied_wind()

func _schedule_disembodied_wind() -> void:
	if StoryManager.has_mayari_card(MayariCardRegistry.CARD_DISEMBODIED_WIND):
		_wind_gusts_remaining = randi_range(1, 2)
		_wind_timer = randf_range(35.0, 75.0)
	else:
		_wind_gusts_remaining = 0
		_wind_timer = 0.0

func _process(delta: float) -> void:
	# Disembodied Wind Moon Card: 1-2 eerie gusts pop the fridge open during the day
	if _wind_gusts_remaining > 0 and StoryManager.is_clock_running and Dialogic.current_timeline == null:
		_wind_timer -= delta
		if _wind_timer <= 0.0:
			if not is_open:
				_wind_gusts_remaining -= 1
				_wind_timer = randf_range(55.0, 95.0)
				_trigger_disembodied_wind_gust()
			else:
				_wind_timer = 12.0

	var prev_cold := StoryManager.fridge_coldness
	var prev_warm := StoryManager.is_fridge_warm

	if is_open:
		if StoryManager.fridge_coldness > 0.0:
			StoryManager.fridge_coldness = maxf(0.0, StoryManager.fridge_coldness - StoryManager.get_fridge_drain_rate() * delta)
			if StoryManager.fridge_coldness <= 0.0:
				StoryManager.is_fridge_warm = true
	else:
		if StoryManager.fridge_coldness < 100.0:
			StoryManager.fridge_coldness = minf(100.0, StoryManager.fridge_coldness + StoryManager.get_fridge_regen_rate() * delta)
			if StoryManager.fridge_coldness >= StoryManager.FRIDGE_WARM_RECOVER_THRESHOLD:
				StoryManager.is_fridge_warm = false

	if not is_equal_approx(prev_cold, StoryManager.fridge_coldness) or prev_warm != StoryManager.is_fridge_warm:
		EventBus.fridge_coldness_changed.emit(StoryManager.fridge_coldness, is_open, StoryManager.is_fridge_warm)


func _resolve_pivot() -> void:
	# 1. Use the exported hinge node if it resolved correctly.
	if is_instance_valid(hinge):
		_pivot = hinge
		return
	# 2. Fall back to the direct parent Node3D (FridgeDoorPivot).
	#    Instanced-scene-root NodePath overrides are unreliable in Godot 4;
	#    get_parent() gives us the pivot reliably.
	var p: Node = get_parent()
	if p is Node3D:
		_pivot = p as Node3D
		return
	# 3. Last resort — rotate self (hinge setup is missing entirely).
	_pivot = self


func _build_outline_material() -> void:
	var shader := load(OUTLINE_SHADER) as Shader
	if not shader:
		push_warning("RefrigeratorDoor: shader not found at %s" % OUTLINE_SHADER)
		return
	_outline_mat = ShaderMaterial.new()
	_outline_mat.shader = shader
	_outline_mat.set_shader_parameter("outline_color", Color.WHITE)
	_outline_mat.set_shader_parameter("outline_width", 16.0)


# Called by FridgeDoorInteractor (Area3D child) — matches PlayerInteraction API
func on_hover(is_hovered: bool) -> void:
	material_overlay = _outline_mat if is_hovered else null


func on_interact() -> void:
	toggle_open()

func _trigger_disembodied_wind_gust() -> void:
	if is_open:
		return
	LogManager.info("RefrigeratorDoor", "Disembodied Wind gust popped the refrigerator door open!")
	EventBus.request_camera_shake.emit(0.06, 0.25)
	if get_tree():
		get_tree().call_group("store_cats", "play_startled_meow")
	EventBus.show_notification.emit("Disembodied Wind!", "An eerie gust swung your fridge door open!", "refrigerator_open")
	toggle_open()

# Close open
func toggle_open() -> void:
	is_open = !is_open
	var target_rot: Vector3 = Vector3(0, deg_to_rad(OPEN_ANGLE_DEG), 0) if is_open \
					  else Vector3.ZERO

	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(_pivot, "rotation", target_rot, 0.65) \
		  .set_trans(Tween.TRANS_SINE) \
		  .set_ease(Tween.EASE_IN_OUT)
	
	if is_open:
		EventBus.refrigerator_opened.emit()
		EventBus.request_sfx.emit("refrigerator_open")
	else:
		EventBus.refrigerator_closed.emit()
		EventBus.request_sfx.emit("refrigerator_close")
	EventBus.fridge_coldness_changed.emit(StoryManager.fridge_coldness, is_open, StoryManager.is_fridge_warm)
	
	# VFX: Cold Mist
	if is_open:
		var fridge_surfaces = get_tree().get_nodes_in_group("fridge_surfaces")
		for surface in fridge_surfaces:
			if surface is ShelfSurface:
				var center_pos = surface.to_global(Vector3(surface.shelf_width / 2.0, 0.1, 0.0))
				var mists = VisualEffectManager.spawn_mass_mist(center_pos, surface.shelf_width)
				_active_mists.append_array(mists)
				
				# Fade in each mist
				for p in mists:
					if is_instance_valid(p) and p.mesh and p.mesh.material:
						var fade_tween = create_tween()
						fade_tween.tween_property(p.mesh.material, "albedo_color:a", 0.07, 1.0)
	else:
		# Close door behavior -> fade out, then stop emitting and clean up
		for p in _active_mists:
			if is_instance_valid(p) and p.mesh and p.mesh.material:
				var fade_out = create_tween()
				fade_out.tween_property(p.mesh.material, "albedo_color:a", 0.0, 1.0)
				fade_out.finished.connect(func():
					if is_instance_valid(p):
						p.emitting = false
						# Wait for existing particles to die naturally (lifetime is 4s)
						get_tree().create_timer(4.0).timeout.connect(func():
							if is_instance_valid(p): p.queue_free()
						)
				)
		_active_mists.clear()
