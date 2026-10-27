class_name PassAssist
extends RefCounted
## Pase asistido. El jugador apunta con el joystick; el sistema elige el companero que mejor coincide
## con esa INTENCION (direccion, distancia, linea libre) y corrige de forma moderada direccion y fuerza.
## No garantiza que el pase llegue: el error depende de distancia, potencia, equilibrio,
## orientacion corporal, pierna de golpeo y atributos.

## Calcula un pase. stick_dir: direccion deseada en el mundo (o cero), charge: 0..1, lob: pase elevado.
## assist_level: 0 = sin ayuda ... 1 = maxima ayuda.
static func compute(kicker: Footballer, ctx: MatchContext, stick_dir: Vector3, charge: float, lob: bool,
		rng: RandomNumberGenerator, assist_level: float) -> KickModel.KickResult:
	var cfg: AssistTuning = Tuning.assist
	var ball_tuning: BallTuning = Tuning.ball
	var res := KickModel.KickResult.new()
	res.charge = charge
	var origin: Vector3 = ctx.ball.global_position
	var intent: Vector3 = KickModel.flat(stick_dir)
	var has_stick: bool = intent.length() > 0.2
	if not has_stick:
		intent = kicker.locomotion.forward()
	intent = intent.normalized()
	res.intended_dir = intent

	# --- 1. Elegir candidato ---
	var best: Footballer = null
	var best_score: float = -1.0
	if assist_level > 0.0:
		var cone: float = cfg.pass_cone_deg * lerpf(0.65, 1.0, assist_level)
		if not has_stick:
			cone *= 0.75
		var ideal: float = 4.5 + 13.0 * charge
		for tm in ctx.teammates_of(kicker):
			var to: Vector3 = KickModel.flat(tm.global_position - origin)
			var dist: float = to.length()
			if dist < 1.2 or dist > cfg.pass_max_distance:
				continue
			var ang: float = KickModel.angle_between_deg(intent, to)
			if ang > cone:
				continue
			var angle_score: float = 1.0 - ang / cone
			var dist_score: float = clampf(1.0 - absf(dist - ideal) / (ideal + 6.0), 0.0, 1.0)
			var lane_score: float = _lane_clearance(origin, tm.global_position, ctx.opponents_of(kicker), cfg.pass_lane_block_radius)
			var score: float = cfg.pass_weight_angle * angle_score + cfg.pass_weight_distance * dist_score + cfg.pass_weight_lane * lane_score
			if score > best_score:
				best_score = score
				best = tm
	res.target = best

	# --- 2. Punto de mira y direccion ---
	var dist_to_aim: float
	var aim_dir: Vector3 = intent
	if best != null:
		var to_t: Vector3 = KickModel.flat(best.global_position - origin)
		var est_speed: float = clampf(KickModel.ground_speed_for_distance(to_t.length(), ball_tuning.pass_arrival_speed), 5.0, 18.0)
		var t_flight: float = clampf(to_t.length() / est_speed, 0.1, 1.2)
		var lead: Vector3 = KickModel.flat(best.velocity) * t_flight * 0.85
		res.aim_point = best.global_position + lead
		var to_aim: Vector3 = KickModel.flat(res.aim_point - origin)
		dist_to_aim = to_aim.length()
		aim_dir = to_aim.normalized()
	else:
		# Pase al espacio: la distancia depende de la carga.
		dist_to_aim = lerpf(4.5, 19.0, charge)
		res.aim_point = origin + intent * dist_to_aim

	var final_dir: Vector3 = intent
	if best != null:
		var diff: float = KickModel.signed_angle_deg(intent, aim_dir)
		var max_corr: float = cfg.pass_max_correction_deg * assist_level
		var applied: float = clampf(diff * assist_level, -max_corr, max_corr)
		res.assisted_correction_deg = applied
		final_dir = intent.rotated(Vector3.UP, deg_to_rad(applied))

	# --- 3. Fuerza ---
	var power_mult: float = kicker.attributes.factor("long_pass" if dist_to_aim > 11.0 else "short_pass", 0.12)
	var speed_h: float
	var vy: float = 0.0
	if lob:
		res.kind = &"lob"
		var angle: float = ball_tuning.lob_angle_deg
		var v: float = KickModel.lob_speed_for_distance(dist_to_aim, angle)
		v = clampf(v, 6.0, 20.0 * power_mult)
		speed_h = v * cos(deg_to_rad(angle))
		vy = v * sin(deg_to_rad(angle))
	else:
		res.kind = &"driven" if charge > 0.45 else (&"short" if best != null else &"space")
		# Hacia un companero se llega con velocidad de control; al espacio, la pelota debe casi detenerse alli.
		var arrival: float = ball_tuning.pass_arrival_speed if best != null else 0.8
		var v0: float = KickModel.ground_speed_for_distance(dist_to_aim, arrival)
		if best != null:
			v0 *= lerpf(1.0, ball_tuning.driven_pass_extra, charge)
		var v_min: float = ball_tuning.pass_speed_min if best != null else 1.6
		speed_h = clampf(v0, v_min, ball_tuning.pass_speed_max * power_mult)

	# --- 4. Error ---
	var acc: float = kicker.attributes.norm("pass_accuracy")
	var balance: float = KickModel.balance_state(kicker)
	var misalign: float = KickModel.misalignment(kicker, final_dir)
	var speed_ratio: float = clampf(kicker.locomotion.speed / maxf(kicker.locomotion.max_sprint_speed(), 0.1), 0.0, 1.0)
	var sigma: float = cfg.pass_error_deg * (1.45 - 0.9 * acc)
	sigma *= 0.6 + 0.4 * sqrt(maxf(dist_to_aim, 1.0) / 8.0)
	sigma *= 1.0 + 0.9 * (1.0 - balance)
	sigma *= 1.0 + 0.6 * misalign
	sigma *= 1.0 + 0.5 * speed_ratio * speed_ratio
	sigma *= 1.0 + 0.45 * charge * charge
	sigma *= lerpf(1.1, 0.88, kicker.attributes.norm("composure"))
	res.weak_foot = KickModel.is_weak_foot(kicker, origin)
	if res.weak_foot:
		sigma *= KickModel.weak_foot_error_mult(kicker)
		speed_h *= KickModel.weak_foot_power_mult(kicker)
	res.sigma_deg = sigma
	var err_deg: float = KickModel.gaussian_clipped(rng, sigma)
	res.error_deg = err_deg
	final_dir = final_dir.rotated(Vector3.UP, deg_to_rad(err_deg))
	speed_h *= clampf(rng.randfn(1.0, 0.025 + 0.025 * (1.0 - acc)), 0.9, 1.1)
	res.final_dir = final_dir

	res.velocity = Vector3(final_dir.x * speed_h, vy, final_dir.z * speed_h)
	if lob:
		# Efecto hacia atras (backspin) leve para que el balon frene al caer.
		var side_axis: Vector3 = Vector3.UP.cross(final_dir)
		res.spin = -side_axis * 18.0
	else:
		res.spin = Vector3.UP.cross(KickModel.flat(res.velocity)) / maxf(ball_tuning.radius, 0.01)
	return res

## 1.0 = linea totalmente libre; baja cuanto mas cerca de la linea de pase este un rival.
static func _lane_clearance(from_pos: Vector3, to_pos: Vector3, opponents: Array[Footballer], block_radius: float) -> float:
	var a := Vector2(from_pos.x, from_pos.z)
	var b := Vector2(to_pos.x, to_pos.z)
	var ab: Vector2 = b - a
	var len2: float = ab.length_squared()
	var clearance: float = 1.0
	for o in opponents:
		var p := Vector2(o.global_position.x, o.global_position.z)
		var t: float = clampf((p - a).dot(ab) / maxf(len2, 0.0001), 0.0, 1.0)
		# Ignorar rivales casi sobre el receptor o sobre quien patea.
		if t < 0.08 or t > 0.98:
			continue
		var d: float = (a + ab * t).distance_to(p)
		if d < block_radius * 2.0:
			clearance = minf(clearance, clampf(d / (block_radius * 2.0), 0.0, 1.0))
	return clearance
