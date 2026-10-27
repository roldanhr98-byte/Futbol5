extends TestCase
## Pases: asistencia configurable, error por atributos, pase al espacio, elevado e intercepcion.

const START := Vector3(-10.0, 0.0, 0.0)

func _setup_passer(ctx: MatchContext, base_attr: int = 50) -> Footballer:
	var p: Footballer = add_player(ctx, 0, START, base_attr)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	return p

func _reset_ball_at_feet(ctx: MatchContext, p: Footballer) -> void:
	ctx.ball.reset_at(p.global_position + Vector3(0.55, 0.11, 0.0))

## Ejecuta un pase y devuelve la distancia minima entre la pelota y el companero durante 2.6 s.
func _pass_trial(ctx: MatchContext, p: Footballer, mate: Footballer, stick: Vector3, charge: float, seed_value: int, lob: bool = false) -> float:
	p.place_at(START, Locomotion.yaw_from_dir(Vector3(1, 0, 0)))
	_reset_ball_at_feet(ctx, p)
	await physics_frames(3)
	p.ball_handler.rng.seed = seed_value
	p.ball_handler.lockout = 0.0
	p.ball_handler.perform_pass(stick, charge, lob)
	var best: float = INF
	for i in 160:
		await tree.physics_frame
		var d: float = Vector2(ctx.ball.global_position.x - mate.global_position.x, ctx.ball.global_position.z - mate.global_position.z).length()
		best = minf(best, d)
	return best

func test_assisted_pass_arrives_far_more_often_than_unassisted() -> void:
	var ctx: MatchContext = await make_match()
	var p: Footballer = _setup_passer(ctx)
	var mate: Footballer = add_player(ctx, 0, Vector3(0.0, 0.0, -5.0))
	mate.set_physics_process(false)
	# El companero esta a ~26.6 grados hacia -Z; el joystick apunta 12 grados mas hacia el centro.
	var stick: Vector3 = Vector3(1.0, 0.0, -0.20).normalized()
	var ok_assist: int = 0
	var ok_none: int = 0
	var n: int = 24
	for i in n:
		p.assist_override_pass = 0.65
		if await _pass_trial(ctx, p, mate, stick, 0.3, 100 + i) < 1.6:
			ok_assist += 1
		p.assist_override_pass = 0.0
		if await _pass_trial(ctx, p, mate, stick, 0.3, 100 + i) < 1.6:
			ok_none += 1
	note("pases al companero (de %d): con asistencia=%d, sin asistencia=%d" % [n, ok_assist, ok_none])
	check(ok_assist >= int(n * 0.7), "con asistencia la mayoria llega (%d/%d)" % [ok_assist, n])
	check(ok_none <= int(n * 0.35), "sin asistencia, apuntando 12 grados mal, casi ninguno llega (%d/%d)" % [ok_none, n])

func test_pass_is_never_guaranteed_with_poor_accuracy_at_long_range() -> void:
	var ctx: MatchContext = await make_match()
	var p: Footballer = _setup_passer(ctx, 15)
	var mate: Footballer = add_player(ctx, 0, Vector3(8.0, 0.0, -2.0))
	mate.set_physics_process(false)
	var stick: Vector3 = Vector3(1.0, 0.0, -0.11).normalized()
	p.assist_override_pass = 0.95
	var ok: int = 0
	var n: int = 30
	for i in n:
		if await _pass_trial(ctx, p, mate, stick, 0.9, 500 + i) < 1.6:
			ok += 1
	note("pase largo con precision 15 y asistencia maxima: %d/%d" % [ok, n])
	check(ok < n, "la asistencia no garantiza el pase (llegaron %d/%d)" % [ok, n])
	check(ok > n / 5, "pero tampoco es imposible (llegaron %d/%d)" % [ok, n])

func test_attributes_and_weak_foot_change_error() -> void:
	var ctx: MatchContext = await make_match(Vector3(-9.45, 0.11, 0.0))
	var low: Footballer = _setup_passer(ctx, 10)
	var res_low: KickModel.KickResult = PassAssist.compute(low, ctx, Vector3(1, 0, 0), 0.5, false, low.ball_handler.rng, 0.5)
	low.attributes.reset_to(100)
	var res_high: KickModel.KickResult = PassAssist.compute(low, ctx, Vector3(1, 0, 0), 0.5, false, low.ball_handler.rng, 0.5)
	note("sigma de pase: atributos 10 = %.2f grados, atributos 100 = %.2f grados" % [res_low.sigma_deg, res_high.sigma_deg])
	check(res_high.sigma_deg < res_low.sigma_deg * 0.7, "mejores atributos reducen claramente el error")
	# Pierna debil: balon del lado izquierdo (jugador diestro, mirando +X => izquierda = -Z).
	low.attributes.reset_to(50)
	ctx.ball.reset_at(low.global_position + Vector3(0.5, 0.11, 0.35))
	await physics_frames(2)
	var right_side: bool = not KickModel.is_weak_foot(low, ctx.ball.global_position)
	ctx.ball.reset_at(low.global_position + Vector3(0.5, 0.11, -0.35))
	await physics_frames(2)
	var left_weak: bool = KickModel.is_weak_foot(low, ctx.ball.global_position)
	check(right_side and left_weak, "la pelota del lado izquierdo usa la pierna no dominante")
	var res_weak: KickModel.KickResult = PassAssist.compute(low, ctx, Vector3(1, 0, 0), 0.5, false, low.ball_handler.rng, 0.5)
	ctx.ball.reset_at(low.global_position + Vector3(0.5, 0.11, 0.35))
	await physics_frames(2)
	var res_strong: KickModel.KickResult = PassAssist.compute(low, ctx, Vector3(1, 0, 0), 0.5, false, low.ball_handler.rng, 0.5)
	check(res_weak.weak_foot and not res_strong.weak_foot, "el resultado marca el uso de pierna debil")
	check(res_weak.sigma_deg > res_strong.sigma_deg * 1.2, "la pierna debil es menos precisa (%.2f vs %.2f)" % [res_weak.sigma_deg, res_strong.sigma_deg])

func test_pass_to_space_when_no_teammates_scales_with_charge() -> void:
	var ctx: MatchContext = await make_match()
	var p: Footballer = _setup_passer(ctx)
	var dists: Array[float] = []
	for charge in [0.0, 0.5, 1.0]:
		p.place_at(START, Locomotion.yaw_from_dir(Vector3(1, 0, 0)))
		_reset_ball_at_feet(ctx, p)
		await physics_frames(5)
		p.ball_handler.rng.seed = 42
		p.ball_handler.lockout = 0.0
		var x0: float = ctx.ball.global_position.x
		var res: KickModel.KickResult = p.ball_handler.perform_pass(Vector3(1, 0, 0), charge, false)
		check(res.target == null, "sin companeros no hay objetivo")
		await wait_seconds(9.0)
		dists.append(ctx.ball.global_position.x - x0)
		check(absf(ctx.ball.global_position.z) < 3.5, "mantiene la direccion apuntada (z=%.2f)" % ctx.ball.global_position.z)
	note("recorrido del pase al espacio por carga 0/0.5/1: %.1f / %.1f / %.1f m" % [dists[0], dists[1], dists[2]])
	check(dists[0] < dists[1] and dists[1] < dists[2], "mas carga = pase mas largo")
	check(dists[0] > 2.5 and dists[2] > 12.0, "rangos razonables (corto > 2.5 m, largo > 12 m)")

func test_lob_pass_flies_over_the_ground_and_lands_near_target() -> void:
	var ctx: MatchContext = await make_match()
	var p: Footballer = _setup_passer(ctx, 70)
	var mate: Footballer = add_player(ctx, 0, Vector3(4.0, 0.0, 0.0))
	mate.set_physics_process(false)
	p.assist_override_pass = 0.8
	p.place_at(START, Locomotion.yaw_from_dir(Vector3(1, 0, 0)))
	_reset_ball_at_feet(ctx, p)
	await physics_frames(5)
	p.ball_handler.rng.seed = 9
	p.ball_handler.lockout = 0.0
	var res: KickModel.KickResult = p.ball_handler.perform_pass(Vector3(1, 0, 0), 0.5, true)
	check(res.kind == &"lob", "el pase se marca como elevado")
	var max_h: float = 0.0
	var landed_x: float = -999.0
	var was_high: bool = false
	for i in 220:
		await tree.physics_frame
		var y: float = ctx.ball.global_position.y
		max_h = maxf(max_h, y)
		if y > 1.0:
			was_high = true
		if was_high and landed_x < -900.0 and y < 0.2:
			landed_x = ctx.ball.global_position.x
	note("pase elevado de 14 m: altura max=%.2f m, aterriza en x=%.2f (companero en x=4.0)" % [max_h, landed_x])
	check(max_h > 2.0, "el pase elevado vuela alto (%.2f m)" % max_h)
	check(absf(landed_x - 4.0) < 4.0, "aterriza cerca del companero (%.2f m)" % absf(landed_x - 4.0))

func test_pass_can_be_intercepted_by_a_defender() -> void:
	var ctx: MatchContext = await make_match()
	var p: Footballer = _setup_passer(ctx)
	var mate: Footballer = add_player(ctx, 0, Vector3(2.0, 0.0, 0.0))
	mate.set_physics_process(false)
	var rival: Footballer = add_player(ctx, 1, Vector3(-4.0, 0.0, 0.0))
	rival.set_physics_process(false)
	p.assist_override_pass = 0.8
	p.place_at(START, Locomotion.yaw_from_dir(Vector3(1, 0, 0)))
	_reset_ball_at_feet(ctx, p)
	await physics_frames(5)
	p.ball_handler.lockout = 0.0
	p.ball_handler.perform_pass(Vector3(1, 0, 0), 0.4, false)
	var closest_to_mate: float = INF
	for i in 150:
		await tree.physics_frame
		closest_to_mate = minf(closest_to_mate, Vector2(ctx.ball.global_position.x - mate.global_position.x, ctx.ball.global_position.z - mate.global_position.z).length())
	note("rival pasivo en la linea de pase: la pelota se acerco al companero a %.2f m" % closest_to_mate)
	check(closest_to_mate > 3.0, "un rival en la linea de pase la bloquea (min %.2f m)" % closest_to_mate)

func test_active_defender_takes_possession_of_intercepted_pass() -> void:
	var ctx: MatchContext = await make_match()
	var p: Footballer = _setup_passer(ctx)
	var mate: Footballer = add_player(ctx, 0, Vector3(2.0, 0.0, 0.0))
	mate.set_physics_process(false)
	var rival: Footballer = add_player(ctx, 1, Vector3(-4.0, 0.0, 0.0))   # sin entrada: recibe el balon y lo controla
	p.assist_override_pass = 0.8
	p.place_at(START, Locomotion.yaw_from_dir(Vector3(1, 0, 0)))
	_reset_ball_at_feet(ctx, p)
	await physics_frames(5)
	p.ball_handler.lockout = 0.0
	var events: Array = []
	ctx.event_emitted.connect(func(e: GameEvent) -> void: events.append(e))
	p.ball_handler.perform_pass(Vector3(1, 0, 0), 0.4, false)
	await wait_seconds(1.5)
	var controlled: bool = false
	for e in events:
		if e.type == GameEvent.Type.FIRST_TOUCH and e.team == 1:
			controlled = true
	check(ctx.ball.last_touch_team == 1, "el rival fue el ultimo en tocar la pelota (equipo %d)" % ctx.ball.last_touch_team)
	check(controlled, "el rival controla el pase (evento FIRST_TOUCH del equipo 1)")
	check(ctx.ball.global_position.distance_to(mate.global_position) > 3.0, "el companero no la recibe")

func test_assist_picks_best_aligned_and_ignores_out_of_cone() -> void:
	var ctx: MatchContext = await make_match(Vector3(-9.45, 0.11, 0.0))
	var p: Footballer = _setup_passer(ctx)
	var left_mate: Footballer = add_player(ctx, 0, Vector3(-2.0, 0.0, -4.0))   # ~ -26 grados
	var right_mate: Footballer = add_player(ctx, 0, Vector3(-4.0, 0.0, 6.0))   # ~ +45 grados
	var behind: Footballer = add_player(ctx, 0, Vector3(-18.0, 0.0, 0.0))      # 180 grados
	left_mate.set_physics_process(false)
	right_mate.set_physics_process(false)
	behind.set_physics_process(false)
	await physics_frames(2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var r1: KickModel.KickResult = PassAssist.compute(p, ctx, Vector3(1.0, 0.0, -0.45).normalized(), 0.3, false, rng, 0.65)
	check(r1.target == left_mate, "joystick hacia -Z elige al companero de ese lado")
	var r2: KickModel.KickResult = PassAssist.compute(p, ctx, Vector3(1.0, 0.0, 0.9).normalized(), 0.3, false, rng, 0.65)
	check(r2.target == right_mate, "joystick hacia +Z elige al otro companero")
	var r3: KickModel.KickResult = PassAssist.compute(p, ctx, Vector3(0.0, 0.0, 1.0), 0.3, false, rng, 0.65)
	check(r3.target != behind and r3.target != left_mate, "no elige a un companero fuera del cono de intencion")
	var r4: KickModel.KickResult = PassAssist.compute(p, ctx, Vector3(1.0, 0.0, -0.45).normalized(), 0.3, false, rng, 0.0)
	check(r4.target == null and absf(r4.assisted_correction_deg) < 0.001, "con asistencia desactivada no hay objetivo ni correccion")
