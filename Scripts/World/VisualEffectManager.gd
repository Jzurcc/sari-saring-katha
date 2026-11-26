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

func _attach_effect(node: Node, pos: Vector3) -> void:
	var target_parent: Node = get_tree().current_scene if (get_tree() and get_tree().current_scene) else self
	target_parent.add_child(node)
	if node is Node3D:
		node.global_position = pos

func _schedule_cleanup(node: Node, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(func():
		if is_instance_valid(node):
			node.queue_free()
	)

func spawn_impact_dust(pos: Vector3) -> void:
	var p = _create_dust_particles()
	_attach_effect(p, pos)
	p.emitting = true
	_schedule_cleanup(p, 2.0)

func spawn_transaction_glimmer(pos: Vector3, area_size: Vector3 = Vector3(0.4, 0.6, 0.1)) -> void:
	var p = _create_glimmer_particles(area_size)
	_attach_effect(p, pos)
	p.emitting = true
	_schedule_cleanup(p, 3.0)

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
	p.mesh.size = Vector2(0.4, 0.4)
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = STAR_TEXTURE
	mat.albedo_color = Color(1.2, 1.1, 0.5, 1.0) # Over-bright yellow for better bloom
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
	_attach_effect(p, pos)
	
	p.amount = 6
	p.one_shot = false
	p.explosiveness = 0.4
	p.lifetime = 4.0
	p.mesh = QuadMesh.new()
	p.mesh.size = Vector2(0.6, 0.6)
	
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.1, 0.15, 0.2)
	
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.0))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	gradient.add_point(0.2, Color(1, 1, 1, 1.0))
	gradient.add_point(0.7, Color(1, 1, 1, 1.0))
	p.color_ramp = gradient
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = MIST_TEXTURE
	mat.albedo_color = Color(0.8, 0.9, 1.0, 0.0) # Start transparent for fade-in
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
	var reduced_width = width * 0.7 # closer to center
	var burst_count = max(int(reduced_width / 0.5), 1)
	var step = reduced_width / burst_count
	var start_x = pos.x - (reduced_width / 2.0)
	var particles: Array[CPUParticles3D] = []
	
	for i in range(burst_count):
		var burst_pos = Vector3(start_x + (i * step), pos.y, pos.z)
		# Add a tiny bit of random drift so it doesn't look like a perfect grid
		burst_pos += Vector3(randf_range(-0.1, 0.1), 0, randf_range(-0.1, 0.1))
		particles.append(spawn_cold_mist(burst_pos))
	
	return particles

func spawn_heart_burst(pos: Vector3) -> void:
	var p = CPUParticles3D.new()
	_attach_effect(p, pos)
	
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
	_schedule_cleanup(p, 2.0)

func spawn_rank_up_fanfare(pos: Vector3) -> void:
	# 1. Main Gold Burst
	var p = CPUParticles3D.new()
	_attach_effect(p, pos)
	
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
	_schedule_cleanup(p, 3.0)
	
	# 2. Central Flare
	var f = CPUParticles3D.new()
	_attach_effect(f, pos)
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
	_schedule_cleanup(f, 1.0)


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


func spawn_floating_xp(source_node_or_pos: Variant, amount: int, is_partial: bool = false) -> void:
	if amount <= 0:
		return
	var spawn_pos := Vector3.ZERO
	if source_node_or_pos is Node3D:
		var n3d: Node3D = source_node_or_pos
		if not is_instance_valid(n3d):
			return
		var cam := get_viewport().get_camera_3d()
		var right_dir := cam.global_transform.basis.x if is_instance_valid(cam) else Vector3.RIGHT
		right_dir.y = 0.0
		right_dir = right_dir.normalized() if right_dir.length_squared() > 0.0001 else Vector3.RIGHT
		spawn_pos = n3d.global_position + right_dir * randf_range(0.36, 0.46) + Vector3(0.0, randf_range(1.62, 1.72), 0.0)
	elif source_node_or_pos is Vector3:
		spawn_pos = source_node_or_pos
	else:
		return

	var lbl := Label3D.new()
	lbl.name = "FloatingXP"
	lbl.text = "+%d XP (Partial)" % amount if is_partial else "+%d XP" % amount
	if UIStyle.FONT_FREDOKA_SEMIBOLD:
		lbl.font = UIStyle.FONT_FREDOKA_SEMIBOLD
	lbl.font_size = 40 if is_partial else 42
	lbl.pixel_size = 0.0055
	lbl.outline_size = 10
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.shaded = false
	lbl.render_priority = 12
	lbl.modulate = Color(0.98, 0.64, 0.28, 0.0) if is_partial else Color(0.66, 0.96, 0.56, 0.0)
	lbl.outline_modulate = Color(0.08, 0.06, 0.04, 0.0)
	lbl.scale = Vector3.ONE * 0.55

	_attach_effect(lbl, spawn_pos)
	if not lbl.is_inside_tree():
		lbl.queue_free()
		return

	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", spawn_pos.y + 0.62, 1.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lbl, "outline_modulate:a", 0.95, 0.14).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lbl, "scale", Vector3.ONE * 1.05, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().set_parallel(true)
	tw.tween_property(lbl, "scale", Vector3.ONE * 0.92, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.50).set_delay(0.32).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lbl, "outline_modulate:a", 0.0, 0.50).set_delay(0.32).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(lbl.queue_free)


func spawn_price_refusal_fx(source_node: Node3D, price: float) -> void:
	if not is_instance_valid(source_node):
		return
	var cam := get_viewport().get_camera_3d()
	var right_dir := cam.global_transform.basis.x if is_instance_valid(cam) else Vector3.RIGHT
	right_dir.y = 0.0
	right_dir = right_dir.normalized() if right_dir.length_squared() > 0.0001 else Vector3.RIGHT
	var spawn_pos := source_node.global_position + right_dir * 0.42 + Vector3(0.0, 1.72, 0.0)

	var lbl := Label3D.new()
	lbl.name = "FloatingPriceRefusal"
	lbl.text = "₱%.0f?! Too pricey!" % roundf(price)
	if UIStyle.FONT_INDER:
		lbl.font = UIStyle.FONT_INDER
	lbl.font_size = 46
	lbl.pixel_size = 0.0056
	lbl.outline_size = 12
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.shaded = false
	lbl.render_priority = 14
	lbl.modulate = Color(1.0, 0.36, 0.32, 0.0)
	lbl.outline_modulate = Color(0.14, 0.03, 0.03, 0.0)
	lbl.scale = Vector3.ONE * 0.5

	_attach_effect(lbl, spawn_pos)
	if not lbl.is_inside_tree():
		lbl.queue_free()
		return

	# Sharp pop-in with lateral irritation jolt, then rise & fade out
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.10).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lbl, "outline_modulate:a", 0.96, 0.10).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lbl, "scale", Vector3.ONE * 1.18, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "global_position:y", spawn_pos.y + 0.55, 1.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(lbl, "global_position:x", spawn_pos.x + right_dir.x * 0.07, 0.06)
	tw.tween_property(lbl, "global_position:x", spawn_pos.x - right_dir.x * 0.07, 0.06)
	tw.tween_property(lbl, "global_position:x", spawn_pos.x, 0.06)
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector3.ONE * 0.96, 0.30).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.45).set_delay(0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lbl, "outline_modulate:a", 0.0, 0.45).set_delay(0.55).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(lbl.queue_free)
