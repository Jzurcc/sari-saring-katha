class_name MinigameJuice
extends RefCounted

## Shared audio + visual game-feel juice helpers for all 2D vignette minigames
## (Sipa, Dusk Lamp Mosquito Swat, and Teks Memory).


static func play_sfx(sfx_name: String, pitch: float = 1.0, vol_delta_db: float = 0.0) -> void:
	if is_instance_valid(AudioManager) and is_instance_valid(AudioManager.sfx_pool):
		AudioManager.sfx_pool.play_sfx_pitched(sfx_name, pitch, vol_delta_db)
	else:
		EventBus.request_sfx.emit(sfx_name)


static func play_win_fanfare(owner: Node) -> void:
	if not is_instance_valid(owner) or not owner.is_inside_tree():
		return
	play_sfx("pickup", 1.05, 1.0)
	var tw := owner.create_tween()
	tw.tween_interval(0.11)
	tw.tween_callback(func(): play_sfx("pickup", 1.26, 1.5))
	tw.tween_interval(0.11)
	tw.tween_callback(func():
		play_sfx("pickup", 1.50, 2.0)
		play_sfx("money_gain", 1.08, -1.0)
	)


static func play_lose_sting(owner: Node) -> void:
	if not is_instance_valid(owner) or not owner.is_inside_tree():
		return
	play_sfx("drop", 0.80, 1.0)
	var tw := owner.create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(func(): play_sfx("money_decrease", 0.88, -2.0))


static func shake_control(ctrl: Control, intensity: float = 8.0, duration: float = 0.22) -> void:
	if not is_instance_valid(ctrl) or not ctrl.is_inside_tree():
		return
	var orig_pos: Vector2 = ctrl.get_meta("_juice_orig_pos", ctrl.position)
	ctrl.set_meta("_juice_orig_pos", orig_pos)
	var old_tw = ctrl.get_meta("_juice_shake_tw", null)
	if old_tw is Tween and old_tw.is_valid():
		old_tw.kill()
		ctrl.position = orig_pos
	var steps := maxi(3, int(roundf(duration / 0.032)))
	var step_dt := duration / float(steps)
	var tw := ctrl.create_tween()
	ctrl.set_meta("_juice_shake_tw", tw)
	for i in range(steps):
		var decay := 1.0 - float(i) / float(steps)
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * intensity * decay
		tw.tween_property(ctrl, "position", orig_pos + off, step_dt)
	tw.tween_property(ctrl, "position", orig_pos, step_dt)


static func pop_control(ctrl: Control, peak_scale: float = 1.18, duration: float = 0.22) -> void:
	if not is_instance_valid(ctrl) or not ctrl.is_inside_tree():
		return
	ctrl.pivot_offset = ctrl.size * 0.5
	var old_tw = ctrl.get_meta("_juice_pop_tw", null)
	if old_tw is Tween and old_tw.is_valid():
		old_tw.kill()
	var tw := ctrl.create_tween()
	ctrl.set_meta("_juice_pop_tw", tw)
	tw.tween_property(ctrl, "scale", Vector2(peak_scale, peak_scale), duration * 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "scale", Vector2.ONE, duration * 0.62).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func pop_panel_in(panel: Control) -> void:
	if not is_instance_valid(panel) or not panel.is_inside_tree():
		return
	panel.visible = true
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.84, 0.84)
	panel.modulate.a = 0.0
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)


static func spawn_burst(parent: Control, origin: Vector2, color: Color, count: int = 10, spread: float = 130.0) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	for i in range(count):
		var p := ColorRect.new()
		var sz := randf_range(5.0, 10.0)
		p.size = Vector2(sz, sz)
		p.pivot_offset = p.size * 0.5
		p.position = origin - p.size * 0.5
		p.rotation = randf() * TAU
		p.color = color.lerp(Color.WHITE, randf_range(0.0, 0.35))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(p)

		var ang := (TAU * float(i) / float(count)) + randf_range(-0.35, 0.35)
		var dist := randf_range(spread * 0.45, spread)
		var dest := p.position + Vector2(cos(ang), sin(ang)) * dist + Vector2(0.0, randf_range(12.0, 38.0))
		var dur := randf_range(0.32, 0.52)
		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p, "position", dest, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "rotation", p.rotation + randf_range(-4.0, 4.0), dur)
		tw.tween_property(p, "scale", Vector2(0.15, 0.15), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(p, "modulate:a", 0.0, dur).set_delay(dur * 0.30)
		tw.chain().tween_callback(p.queue_free)
