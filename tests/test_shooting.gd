extends TestCase
## Tiros: asistencia moderada que se desvanece, error por atributos, potencia por carga,
## tiros elevados y resultados fisicos (gol, poste, fuera).

func _shooter(ctx: MatchContext, pos: Vector3, base_attr: int = 50) -> Footballer:
	var p: Footballer = add_player(ctx, 0, pos, base_attr)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	p.set_physics_process(false)
	return p

func _predicted_on_target_rate(p: Footballer, ctx: MatchContext, stick: Vector3, assist: float, charge: float, n: int, lob: bool = false) -> float:
	var hits: int = 0
	for i in n:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + i
		var r: KickModel.KickResult = ShotAssist.compute(p, ctx, stick, charge, lob, rng, assist)
		if r.on_target:
			hits += 1
	return float(hits) / n

func test_assist_improves_on_target_rate_but_never_guarantees() -> void:
	var ctx: MatchContext = await make_match(Vector3(10.5, 0.11, 4.0))
	var p: Footballer = _shooter(ctx, Vector3(10.0, 0.0, 4.0))
	# Apunta 30 grados hacia -Z: cae justo fuera del poste (z_hit ~ -1.8 m).
	var stick: Vector3 = Vector3(cos(deg_to_rad(30.0)), 0.0, -sin(deg_to_rad(30.0)))
	var with_assist: float = _predicted_on_target_rate(p, ctx, stick, 0.65, 0.8, 300)
	var without: float = _predicted_on_target_rate(p, ctx, stick, 0.0, 0.8, 300)
	note("tiros al arco (prediccion, 300 intentos, apuntando ligeramente afuera): con asistencia=%.0f %%, sin=%.0f %%" % [with_assist * 100.0, without * 100.0])
	check(with_assist > without + 0.2, "la asistencia mejora claramente el acierto al arco")
	check(with_assist < 0.97, "pero no es un sistema de goles automaticos (%.0f %%)" % (with_assist * 100.0))

func test_assist_fades_when_aiming_clearly_away_from_goal() -> void:
	var ctx: MatchContext = await make_match(Vector3(10.5, 0.11, 0.0))
	var p: Footballer = _shooter(ctx, Vector3(10.0, 0.0, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var away: Vector3 = Vector3(0.0, 0.0, -1.0)    # perpendicular al arco
	var r_away: KickModel.KickResult = ShotAssist.compute(p, ctx, away, 0.8, false, rng, 0.95)
	check(absf(r_away.assisted_correction_deg) < 0.001, "apuntar claramente fuera: sin correccion (%.2f grados)" % r_away.assisted_correction_deg)
	var back: Vector3 = Vector3(-1.0, 0.0, 0.0)
	var r_back: KickModel.KickResult = ShotAssist.compute(p, ctx, back, 0.8, false, rng, 0.95)
	check(absf(r_back.assisted_correction_deg) < 0.001, "apuntar hacia atras: sin correccion")
	check(r_back.final_dir.x < 0.0, "el tiro respeta la direccion del usuario")
	var near_goal: Vector3 = Vector3(cos(deg_to_rad(12.0)), 0.0, -sin(deg_to_rad(12.0)))
	var r_near: KickModel.KickResult = ShotAssist.compute(p, ctx, near_goal, 0.8, false, rng, 0.95)
	note("correccion con intencion hacia el arco (12 grados): %.2f grados (maximo %.1f)" % [r_near.assisted_correction_deg, Tuning.assist.shot_max_correction_deg * 0.95])
	check(absf(r_near.assisted_correction_deg) <= Tuning.assist.shot_max_correction_deg * 0.95 + 0.01, "la correccion esta acotada")

func test_charge_controls_power_and_attributes_scale_it_moderately() -> void:
	var ctx: MatchContext = await make_match(Vector3(10.5, 0.11, 0.0))
	var p: Footballer = _shooter(ctx, Vector3(10.0, 0.0, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var low: KickModel.KickResult = ShotAssist.compute(p, ctx, Vector3(1, 0, 0), 0.0, false, rng, 0.0)
	var high: KickModel.KickResult = ShotAssist.compute(p, ctx, Vector3(1, 0, 0), 1.0, false, rng, 0.0)
	note("velocidad de tiro con carga 0 / 1: %.1f / %.1f m/s" % [low.velocity.length(), high.velocity.length()])
	check(high.velocity.length() > low.velocity.length() * 1.8, "cargar el tiro aumenta mucho la potencia")
	check_range(high.velocity.length(), 22.0, 31.0, "tiro maximo realista (m/s)")
	p.attributes.set_value("shot_power", 100)
	var strong: KickModel.KickResult = ShotAssist.compute(p, ctx, Vector3(1, 0, 0), 1.0, false, rng, 0.0)
	p.attributes.set_value("shot_power", 1)
	var weak: KickModel.KickResult = ShotAssist.compute(p, ctx, Vector3(1, 0, 0), 1.0, false, rng, 0.0)
	check(strong.velocity.length() > weak.velocity.length(), "potencia de tiro alta = tiro mas fuerte")
	check(strong.velocity.length() < weak.velocity.length() * 1.4, "los atributos modifican, no sustituyen la fisica")
	var accurate: float = 0.0
	var sloppy: float = 0.0
	p.attributes.set_value("shot_accuracy", 100)
	accurate = ShotAssist.compute(p, ctx, Vector3(1, 0, 0), 0.7, false, rng, 0.0).sigma_deg
	p.attributes.set_value("shot_accuracy", 1)
	sloppy = ShotAssist.compute(p, ctx, Vector3(1, 0, 0), 0.7, false, rng, 0.0).sigma_deg
	check(accurate < sloppy * 0.6, "mejor precision de tiro = menor error (%.2f vs %.2f grados)" % [accurate, sloppy])

func test_lob_shot_is_higher_than_driven_shot() -> void:
	var ctx: MatchContext = await make_match(Vector3(10.5, 0.11, 0.0))
	var p: Footballer = _shooter(ctx, Vector3(10.0, 0.0, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var low: KickModel.KickResult = ShotAssist.compute(p, ctx, Vector3(1, 0, 0), 0.7, false, rng, 0.0)
	var high: KickModel.KickResult = ShotAssist.compute(p, ctx, Vector3(1, 0, 0), 0.7, true, rng, 0.0)
	check(high.velocity.y > low.velocity.y + 2.0, "el tiro elevado sale con mas componente vertical (%.1f vs %.1f)" % [high.velocity.y, low.velocity.y])

func test_physical_shot_outcomes_include_goals_posts_and_misses() -> void:
	var ctx: MatchContext = await make_match(Vector3(12.0, 0.11, 0.0))
	var p: Footballer = _shooter(ctx, Vector3(11.5, 0.0, 1.0), 40)
	p.assist_override_shot = 0.55
	var goals: Array = []
	ctx.pitch.goal_scored.connect(func(_g: Goal, _pos: Vector3) -> void: goals.append(1))
	var frame_hits: Array = [0]
	ctx.ball.hit_goal_frame.connect(func(_p: Vector3, _s: float) -> void: frame_hits[0] += 1)
	var n: int = 40
	var goal_count: int = 0
	var post_shots: int = 0
	for i in n:
		goals.clear()
		frame_hits[0] = 0
		p.place_at(Vector3(11.5, 0.0, 1.0), Locomotion.yaw_from_dir(Vector3(1, 0, 0)))
		ctx.pitch.reset_goal_latches()
		ctx.ball.reset_at(Vector3(12.05, 0.11, 1.0))
		await physics_frames(6)
		p.ball_handler.rng.seed = 7000 + i
		p.ball_handler.lockout = 0.0
		# El usuario apunta de forma variada: algunos tiros claramente al arco, otros anchos.
		var aim_deg: float = -24.0 + 4.5 * float(i % 9)
		var stick := Vector3(cos(deg_to_rad(aim_deg)), 0.0, sin(deg_to_rad(aim_deg)))
		p.ball_handler.perform_shot(stick, 0.95, false)
		await wait_seconds(1.6)
		if goals.size() > 0:
			goal_count += 1
		if frame_hits[0] > 0:
			post_shots += 1
	note("40 tiros fisicos con asistencia 0.55 desde 8.5 m sin arquero: goles=%d, tiros que tocaron poste/travesano=%d" % [goal_count, post_shots])
	check(goal_count >= 10, "muchos tiros son gol (%d/%d)" % [goal_count, n])
	check(goal_count < n, "no todos los tiros son gol (%d/%d)" % [goal_count, n])

func test_far_shots_are_much_harder_than_close_ones() -> void:
	var ctx: MatchContext = await make_match(Vector3(0.5, 0.11, 0.0))
	var p: Footballer = _shooter(ctx, Vector3(0.0, 0.0, 0.0), 40)
	var stick := Vector3(1.0, 0.0, 0.0)
	var far_rate: float = _predicted_on_target_rate(p, ctx, stick, 0.55, 1.0, 300)
	p.global_position = Vector3(15.0, 0.0, 0.0)
	ctx.ball.reset_at(Vector3(15.5, 0.11, 0.0))
	await physics_frames(3)
	var close_rate: float = _predicted_on_target_rate(p, ctx, stick, 0.55, 1.0, 300)
	note("a puerta con atributos 40: desde 20 m=%.0f %%, desde 5 m=%.0f %%" % [far_rate * 100.0, close_rate * 100.0])
	check(close_rate > far_rate + 0.15, "tirar desde lejos es menos preciso")
	check(far_rate < 0.8, "desde 20 m con atributos bajos no es un gol casi seguro (%.0f %%)" % (far_rate * 100.0))
