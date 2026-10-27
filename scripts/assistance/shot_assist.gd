class_name ShotAssist
extends RefCounted
## Tiro asistido. El jugador apunta con el joystick; si esa intencion apunta al arco (o cerca),
## se corrige MODERADAMENTE la direccion hacia un punto razonable del arco y se ajusta la altura.
## La asistencia se desvanece cuando el usuario apunta claramente fuera del arco y nunca convierte
## un tiro en gol: hay error por potencia, equilibrio, orientacion, pierna y atributos; la pelota
## puede pegar en los postes, ser atajada o irse desviada.

static func compute(kicker: Footballer, ctx: MatchContext, stick_dir: Vector3, charge: float, lob: bool,
		rng: RandomNumberGenerator, assist_level: float) -> KickModel.KickResult:
	var cfg: AssistTuning = Tuning.assist
	var bt: BallTuning = Tuning.ball
	var pitch_cfg: PitchConfig = Tuning.pitch
	var res := KickModel.KickResult.new()
	res.kind = &"lob_shot" if lob else &"shot"
	res.charge = charge
	var origin: Vector3 = ctx.ball.global_position
	var intent: Vector3 = KickModel.flat(stick_dir)
	if intent.length() < 0.2:
		intent = kicker.locomotion.forward()
	intent = intent.normalized()
	res.intended_dir = intent

	var goal: Goal = ctx.attacking_goal(kicker.team)
	var goal_x: float = goal.global_position.x
	var to_goal_x: float = goal_x - origin.x
	var dist_goal: float = absf(to_goal_x)
	var usable: float = maxf(pitch_cfg.half_goal() - cfg.shot_post_margin, 0.1)

	# --- Hacia donde apunta la intencion respecto al arco ---
	var weight: float = 0.0
	var z_hit: float = 0.0
	var toward_goal: bool = intent.x * to_goal_x > 0.05
	if toward_goal and assist_level > 0.0 and dist_goal > 0.5:
		var t: float = to_goal_x / intent.x
		z_hit = origin.z + intent.z * t
		var extra_allowed: float = dist_goal * tan(deg_to_rad(cfg.shot_cone_deg * 0.5)) * 0.55
		var outside: float = maxf(absf(z_hit) - usable, 0.0)
		weight = clampf(1.0 - outside / maxf(extra_allowed, 0.2), 0.0, 1.0)

	# --- Punto de mira dentro del arco ---
	var lateral: float = clampf(z_hit / usable, -1.0, 1.0)
	if weight > 0.0 and absf(lateral) < 0.22 and assist_level >= 0.4:
		# Intencion centrada: sugerir el lado contrario al arquero.
		var keeper: Node = ctx.keeper_defending(1 - kicker.team)
		var side: float = 1.0
		if keeper != null:
			var kz: float = (keeper as Node3D).global_position.z
			side = -signf(kz) if absf(kz) > 0.15 else (1.0 if rng.randf() < 0.5 else -1.0)
		lateral = side * 0.62
	var height_ratio: float = 0.88 if lob else lerpf(0.08, 0.5, clampf(charge * 0.75, 0.0, 1.0))
	if dist_goal < 4.0 and not lob:
		height_ratio = minf(height_ratio, 0.3)
	res.aim_point = goal.aim_point(lateral, height_ratio, cfg.shot_post_margin)

	# --- Direccion final ---
	var final_dir: Vector3 = intent
	if weight > 0.0:
		var aim_dir: Vector3 = KickModel.flat(res.aim_point - origin).normalized()
		var diff: float = KickModel.signed_angle_deg(intent, aim_dir)
		var max_corr: float = cfg.shot_max_correction_deg * assist_level
		var applied: float = clampf(diff * assist_level * weight, -max_corr, max_corr)
		res.assisted_correction_deg = applied
		final_dir = intent.rotated(Vector3.UP, deg_to_rad(applied))

	# --- Potencia ---
	var power_mult: float = kicker.attributes.factor("shot_power", 0.14)
	var speed: float = lerpf(bt.shot_speed_min, bt.shot_speed_max, clampf(charge, 0.0, 1.0)) * power_mult
	res.weak_foot = KickModel.is_weak_foot(kicker, origin)
	if res.weak_foot:
		speed *= KickModel.weak_foot_power_mult(kicker)
	speed = minf(speed, bt.shot_speed_max * 1.2)

	# --- Error ---
	var acc: float = kicker.attributes.norm("shot_accuracy")
	var fin: float = kicker.attributes.norm("finishing")
	var balance: float = KickModel.balance_state(kicker)
	var misalign: float = KickModel.misalignment(kicker, final_dir)
	var speed_ratio: float = clampf(kicker.locomotion.speed / maxf(kicker.locomotion.max_sprint_speed(), 0.1), 0.0, 1.0)
	var sigma: float = cfg.shot_error_deg * (1.5 - 0.9 * acc)
	sigma *= 1.0 + 0.9 * charge * charge
	sigma *= 1.0 + 0.8 * (1.0 - balance)
	sigma *= 1.0 + 0.7 * misalign
	sigma *= 1.0 + 0.5 * speed_ratio * speed_ratio
	if dist_goal < 10.0:
		sigma *= lerpf(1.15, 0.85, fin)
	sigma *= lerpf(1.1, 0.88, kicker.attributes.norm("composure"))
	if res.weak_foot:
		sigma *= KickModel.weak_foot_error_mult(kicker)
	res.sigma_deg = sigma
	var err_h: float = KickModel.gaussian_clipped(rng, sigma)
	var err_v: float = KickModel.gaussian_clipped(rng, sigma * 0.6)
	res.error_deg = err_h
	final_dir = final_dir.rotated(Vector3.UP, deg_to_rad(err_h))
	res.final_dir = final_dir

	# --- Altura / trayectoria ---
	var v_h: float = speed * cos(deg_to_rad(lerpf(bt.shot_loft_low_deg, bt.shot_loft_high_deg, 1.0 if lob else 0.0)))
	var default_vy: float = speed * sin(deg_to_rad(bt.shot_loft_high_deg if lob else bt.shot_loft_low_deg))
	var vy: float = default_vy
	if weight > 0.0:
		var d_h: float = KickModel.flat(res.aim_point - origin).length()
		if d_h > 1.2:
			var tf: float = d_h / maxf(v_h * 0.95, 1.0)
			var vy_needed: float = (res.aim_point.y - maxf(origin.y, 0.1) + 0.5 * KickModel.G * tf * tf) / tf
			vy = lerpf(default_vy, vy_needed, clampf(assist_level * weight * 0.9, 0.0, 1.0))
	vy = clampf(vy, -1.0, speed * sin(deg_to_rad(40.0)))
	vy += v_h * tan(deg_to_rad(err_v))
	vy = maxf(vy, 0.0)
	v_h = sqrt(maxf(speed * speed - vy * vy, 0.25 * speed * speed))

	res.velocity = Vector3(final_dir.x * v_h, vy, final_dir.z * v_h)
	if vy < 1.5:
		res.spin = Vector3.UP.cross(KickModel.flat(res.velocity)) / maxf(bt.radius, 0.01) * 0.7
	else:
		res.spin = -Vector3.UP.cross(final_dir) * 14.0
	res.spin += Vector3.UP * (-err_h * bt.shot_spin_factor * 0.25)

	# Prediccion simple (sin resistencia) de si iria al arco, para estadisticas de intencion.
	if final_dir.x * to_goal_x > 0.0:
		var t_goal: float = to_goal_x / (final_dir.x * v_h)
		var z_end: float = origin.z + final_dir.z * v_h * t_goal
		var y_end: float = origin.y + vy * t_goal - 0.5 * KickModel.G * t_goal * t_goal
		res.on_target = absf(z_end) <= pitch_cfg.half_goal() and y_end >= 0.0 and y_end <= pitch_cfg.goal_height
	return res
