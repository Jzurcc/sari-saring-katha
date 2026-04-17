extends Node

## Global singleton for spawning common particle effects and visual flourishes.

# Preload common particle scenes (as CPUParticles3D for compatibility)
# Since I can't create .tscn files easily with raw properties, I will 
# construct them through code or use script-based generation.

const SMOKE_TEXTURE = preload("res://Assets/brackeys_vfx/smoke_04_a.png")
const STAR_TEXTURE = preload("res://Assets/brackeys_vfx/star_04_a.png")
const DUST_TEXTURE = preload("res://Assets/brackeys_vfx/circle_05_a.png")

# New Brackeys Preloads
const MIST_TEXTURE = preload("res://Assets/brackeys_vfx/smoke_02_a.png")
const HEART_STAR_TEXTURE = preload("res://Assets/brackeys_vfx/star_07_a.png")
const RANK_UP_STAR_TEXTURE = preload("res://Assets/brackeys_vfx/star_01_a.png")
const FLARE_TEXTURE = preload("res://Assets/brackeys_vfx/flare_01_a.png")
const STYLIZED_SMOKE = preload("res://Assets/brackeys_vfx/smoke_03_a.png")

func spawn_impact_dust(pos: Vector3) -> void:
	var p = _create_dust_particles()
	add_child(p)
	p.global_position = pos
	p.emitting = true
	# Auto-cleanup
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)

func spawn_transaction_glimmer(pos: Vector3, area_size: Vector3 = Vector3(0.4, 0.6, 0.1)) -> void:
	var p = _create_glimmer_particles(area_size)
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)

func _create_dust_particles() -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.amount = 6
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.4
	p.mesh = QuadMesh.new()
	p.mesh.size = Vector2(0.15, 0.15)
	
	# Material for smoke/dust texture
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = SMOKE_TEXTURE
	mat.albedo_color = Color(0.8, 0.75, 0.7, 0.5) # Slightly more subtle
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	p.mesh.material = mat
	
	p.direction = Vector3.UP
	p.spread = 45.0
	p.gravity = Vector3(0, -0.6, 0)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.2
	p.damping_min = 1.0
	p.damping_max = 2.0
	
	# Faster scale curve - quick puff and fade
	var curves = Curve.new()
	curves.add_point(Vector2(0, 0.4))
	curves.add_point(Vector2(0.3, 1.0))
	curves.add_point(Vector2(1, 0))
	p.scale_amount_curve = curves
	
	return p

func _create_glimmer_particles(area_size: Vector3) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	p.amount = 16
	p.one_shot = true
	p.explosiveness = 0.8
	p.lifetime = 1.6
	p.mesh = QuadMesh.new()
	p.mesh.size = Vector2(0.25, 0.25)
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = STAR_TEXTURE
	mat.albedo_color = Color(1.0, 0.95, 0.6, 1.0) # Bright pale yellow
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	# Additive blending for extra glow
	mat.blend_mode = StandardMaterial3D.BLEND_MODE_ADD
	p.mesh.material = mat
	
	# Emission area to cover the customer sprite
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = area_size
	
	p.direction = Vector3.UP
	p.spread = 180.0 # Full horizontal scattering
	p.gravity = Vector3(0, -0.5, 0) # Fall away quickly after burst
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.0
	
	# Rotation for "twinkle" feel
	p.angle_min = -180.0
	p.angle_max = 180.0
	
	# Scale curve - quick pulse
	var curves = Curve.new()
	curves.add_point(Vector2(0, 0))
	curves.add_point(Vector2(0.3, 1))
	curves.add_point(Vector2(1, 0))
	p.scale_amount_curve = curves
	
	return p

func spawn_cold_mist(pos: Vector3) -> CPUParticles3D:
	var p = CPUParticles3D.new()
	add_child(p)
	p.global_position = pos
	
	p.amount = 12
	p.one_shot = false
	p.explosiveness = 0.4
	p.lifetime = 4.0
	p.mesh = QuadMesh.new()
	p.mesh.size = Vector2(0.6, 0.6)
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = MIST_TEXTURE
	mat.albedo_color = Color(0.8, 0.9, 1.0, 0.15) # Cool blue-white, lesser opacity
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	p.mesh.material = mat
	
	# Puffs outward gently towards the player and drifts up
	p.direction = Vector3.BACK
	p.spread = 90.0
	p.gravity = Vector3(0, 0.15, 0) # Ascend gently
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.4
	p.damping_min = 0.2
	p.damping_max = 0.5
	
	var curves = Curve.new()
	curves.add_point(Vector2(0, 0.2))
	curves.add_point(Vector2(0.3, 1.2))
	curves.add_point(Vector2(0.7, 1.2))
	curves.add_point(Vector2(1, 0))
	p.scale_amount_curve = curves
	
	p.emitting = true
	return p

func spawn_mass_mist(pos: Vector3, width: float) -> Array[CPUParticles3D]:
	# Spawns a series of mist bursts across the specified width
	var burst_count = int(width / 0.4) + 1
	var step = width / burst_count
	var start_x = pos.x - (width / 2.0)
	var particles: Array[CPUParticles3D] = []
	
	for i in range(burst_count):
		var burst_pos = Vector3(start_x + (i * step), pos.y, pos.z)
		# Add a tiny bit of random drift so it doesn't look like a perfect grid
		burst_pos += Vector3(randf_range(-0.1, 0.1), 0, randf_range(-0.1, 0.1))
		particles.append(spawn_cold_mist(burst_pos))
	
	return particles

func spawn_heart_burst(pos: Vector3) -> void:
	var p = CPUParticles3D.new()
	add_child(p)
	p.global_position = pos
	
	p.amount = 8
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 1.0
	p.mesh = QuadMesh.new()
	p.mesh.size = Vector2(0.2, 0.2)
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = HEART_STAR_TEXTURE
	mat.albedo_color = Color(1.0, 0.4, 0.7, 1.0) # Pink
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	mat.blend_mode = StandardMaterial3D.BLEND_MODE_ADD
	p.mesh.material = mat
	
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3(0, 0.2, 0) # Float up
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.5
	
	var curves = Curve.new()
	curves.add_point(Vector2(0, 0))
	curves.add_point(Vector2(0.2, 1.2))
	curves.add_point(Vector2(1, 0))
	p.scale_amount_curve = curves
	
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)

func spawn_rank_up_fanfare(pos: Vector3) -> void:
	# 1. Main Gold Burst
	var p = CPUParticles3D.new()
	add_child(p)
	p.global_position = pos
	
	p.amount = 40
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 1.5
	p.mesh = QuadMesh.new()
	p.mesh.size = Vector2(0.3, 0.3)
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = RANK_UP_STAR_TEXTURE
	mat.albedo_color = Color(1.0, 0.85, 0.3, 1.0) # Gold
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	mat.blend_mode = StandardMaterial3D.BLEND_MODE_ADD
	p.mesh.material = mat
	
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3(0, -0.5, 0)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.damping_min = 2.0
	p.damping_max = 4.0
	
	var curves = Curve.new()
	curves.add_point(Vector2(0, 1))
	curves.add_point(Vector2(1, 0))
	p.scale_amount_curve = curves
	
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)
	
	# 2. Central Flare
	var f = CPUParticles3D.new()
	add_child(f)
	f.global_position = pos
	f.amount = 1
	f.one_shot = true
	f.lifetime = 0.5
	f.mesh = QuadMesh.new()
	f.mesh.size = Vector2(3.0, 3.0)
	
	var f_mat = StandardMaterial3D.new()
	f_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	f_mat.albedo_texture = FLARE_TEXTURE
	f_mat.albedo_color = Color(1.0, 1.0, 0.8, 0.6)
	f_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	f_mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	f_mat.blend_mode = StandardMaterial3D.BLEND_MODE_ADD
	f.mesh.material = f_mat
	
	var f_curves = Curve.new()
	f_curves.add_point(Vector2(0, 0))
	f_curves.add_point(Vector2(0.5, 1))
	f_curves.add_point(Vector2(1, 0))
	f.scale_amount_curve = f_curves
	
	f.emitting = true
	get_tree().create_timer(1.0).timeout.connect(f.queue_free)


func setup_ambient_dust(parent: Node3D) -> void:
	var p = CPUParticles3D.new()
	p.name = "AmbientDust"
	p.amount = 120
	p.lifetime = 15.0
	p.preprocess = 8.0
	p.mesh = QuadMesh.new()
	# Randomize slightly by using different mesh instances or just scale variance
	p.mesh.size = Vector2(0.12, 0.12)
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = STYLIZED_SMOKE
	mat.albedo_color = Color(1, 0.95, 0.8, 0.12) # Warm, slightly more visible
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = StandardMaterial3D.BILLBOARD_ENABLED
	p.mesh.material = mat
	
	# Large area for the store
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(5, 3, 5)
	
	p.direction = Vector3(0.2, -0.1, 0.1) # Gentle drift
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.02
	p.initial_velocity_max = 0.06
	
	# Rotation for stylized feel
	p.angle_min = -180.0
	p.angle_max = 180.0
	
	# Subtle fade in/out
	var curves = Curve.new()
	curves.add_point(Vector2(0, 0))
	curves.add_point(Vector2(0.2, 1.0))
	curves.add_point(Vector2(0.8, 1.0))
	curves.add_point(Vector2(1, 0))
	p.scale_amount_curve = curves
	
	parent.add_child(p)
