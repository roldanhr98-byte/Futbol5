extends TestCase
## Conduccion fisica (estilo FTS / Ultimate Clash): la pelota solo cambia de rumbo cuando un pie la toca y el jugador la
## sigue. Guiones de joystick (diagonal tras sprint, giro de 90 al trote, curva suave a la carrera) con cada toque
## registrado: modo, pie, distancia del pie y del cuerpo a la pelota y giro que el toque le dio a la pelota. Antes de este
## cambio (sonda del 2026-11-05) a sprint la mitad de los toques eran sin pie, uno a 1.28 m del cuerpo, y el jugador corria
## hasta 71 grados apartado de la pelota: la pelota lo seguia «como con un hilo».

## Los guiones de conduccion miden toques de pie: hace falta el esqueleto animado (render).
func _needs_render() -> bool:
	if DisplayServer.get_name() == "headless":
		skip("el esqueleto no se anima en headless: ejecutar con xvfb-run --rendering-driver opengl3")
		return true
	return false

func _probe(name: String, script: Array, sprint: bool, total_s: float) -> Dictionary:
	var ctx: MatchContext = await make_match(Vector3(-14.4, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-15.0, 0.0, 0.0), 60, src, true)
	p.is_human_controlled = true
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	src.sprint = sprint
	var touches: Array = []
	var bh: BallHandler = p.ball_handler
	# Estado compartido con la lambda (las lambdas copian las variables locales de tipo valor al crearse).
	var st := {"prev_v": Vector3.ZERO}
	var pending: Array = []
	bh.touched_ball.connect(func(kind: StringName) -> void:
		var off: Vector3 = KickModel.flat(ctx.ball.global_position - p.global_position)
		pending.append({"t": 0.0, "kind": String(kind), "foot": bh.last_touch_foot, "foot_d": bh.last_touch_foot_distance,
			"body_d": off.length(), "fwd": off.dot(p.locomotion.forward()), "v_before": st["prev_v"], "speed": p.locomotion.speed}))
	var lost_max: float = 0.0
	var t := 0.0
	var leave_max: float = 0.0
	for i in int(total_s * 60.0):
		# Guion: [[desde_s, Vector2 joystick], ...]
		for step in script:
			if t >= float(step[0]):
				src.move = step[1]
		await tree.physics_frame
		t += 1.0 / 60.0
		var bv: Vector3 = KickModel.flat(ctx.ball.linear_velocity)
		var keep: Array = []
		for e in pending:
			e["frames"] = int(e.get("frames", 0)) + 1
			if int(e["frames"]) < 3:
				keep.append(e)
				continue
			e["t"] = t
			e["v_after"] = bv
			var a: float = 0.0
			if (e["v_before"] as Vector3).length() > 0.3 and bv.length() > 0.3:
				a = rad_to_deg((e["v_before"] as Vector3).angle_to(bv))
			e["turn"] = a
			touches.append(e)
		pending.clear()
		pending.append_array(keep)
		if keep.is_empty():
			st["prev_v"] = bv
		var off: Vector3 = KickModel.flat(ctx.ball.global_position - p.global_position)
		lost_max = maxf(lost_max, off.length())
		# Angulo entre hacia donde corre el jugador y donde esta la pelota (si se aleja de ella).
		var pv: Vector3 = KickModel.flat(p.locomotion.velocity)
		if pv.length() > 1.0 and off.length() > 0.6:
			leave_max = maxf(leave_max, rad_to_deg(pv.angle_to(off)))
	var remote := 0
	var far_body := 0.0
	var max_turn_excess := -INF
	var lines: PackedStringArray = []
	for e in touches:
		var far: bool = int(e["foot"]) < 0 or float(e["foot_d"]) > 0.32
		if far and String(e["kind"]) != "clip":
			remote += 1
		far_body = maxf(far_body, float(e["body_d"]))
		max_turn_excess = maxf(max_turn_excess, float(e["turn"]) - p.ball_handler.touch_turn_max_deg(float(e["speed"])))
		lines.append("%.2fs %s pie=%d d_pie=%.2f d_cuerpo=%.2f adel=%.2f v=%.1f giro=%.0f%s" % [e["t"], e["kind"], e["foot"], e["foot_d"], e["body_d"], e["fwd"], e["speed"], e["turn"], " <-- SIN PIE" if far else ""])
	note("%s: %d toques, %d sin pie o lejos, pelota max %.2f m, jugador se aparta de la pelota hasta %.0f grados" % [name, touches.size(), remote, lost_max, leave_max])
	for l in lines:
		note("   " + l)
	var heading: float = rad_to_deg(atan2(KickModel.flat(p.locomotion.velocity).z, KickModel.flat(p.locomotion.velocity).x))
	cleanup()
	return {"touches": touches.size(), "remote": remote, "lost_max": lost_max, "far_body": far_body, "leave_max": leave_max,
		"turn_excess": max_turn_excess, "heading": heading}

func _common_checks(name: String, r: Dictionary) -> void:
	check(float(r["far_body"]) < 0.8, "%s: ningun toque a distancia (cuerpo-pelota max %.2f m)" % [name, r["far_body"]])
	check(float(r["leave_max"]) < 35.0, "%s: el jugador no se aparta de su pelota (max %.0f grados)" % [name, r["leave_max"]])
	check(float(r["lost_max"]) < 1.4, "%s: la pelota no se pierde (max %.2f m)" % [name, r["lost_max"]])
	check(float(r["turn_excess"]) < 12.0, "%s: ningun toque gira la pelota mas de lo que permite la velocidad (exceso %.0f grados)" % [name, r["turn_excess"]])

func test_diagonal_after_sprint_follows_the_ball() -> void:
	if _needs_render():
		return
	var r: Dictionary = await _probe("sprint + diagonal 40", [[0.0, Vector2(1, 0)], [1.6, Vector2(cos(deg_to_rad(40)), sin(deg_to_rad(40)))]], true, 3.6)
	_common_checks("sprint + diagonal", r)
	check(absf(float(r["heading"]) - 40.0) < 12.0, "termina corriendo en la diagonal pedida (rumbo %.0f grados)" % r["heading"])

func test_jog_turn_90_in_touches() -> void:
	if _needs_render():
		return
	var r: Dictionary = await _probe("trote + giro 90", [[0.0, Vector2(0.6, 0)], [1.5, Vector2(0, 0.6)]], false, 3.5)
	_common_checks("trote + giro 90", r)
	check(absf(float(r["heading"]) - 90.0) < 15.0, "termina en el rumbo nuevo (%.0f grados)" % r["heading"])

func test_run_gentle_curve() -> void:
	if _needs_render():
		return
	var s: Array = []
	for k in 13:
		s.append([1.0 + k * 0.15, Vector2(cos(deg_to_rad(k * 5.0)), sin(deg_to_rad(k * 5.0)))])
	s.push_front([0.0, Vector2(1, 0)])
	var r: Dictionary = await _probe("carrera + curva suave 60", s, false, 4.0)
	_common_checks("curva suave", r)
	check(absf(float(r["heading"]) - 60.0) < 15.0, "termina en el rumbo de la curva (%.0f grados)" % r["heading"])

## Pase a un companero que esta a la espalda: el jugador se acomoda (gira con la pelota al pie) y golpea de frente al
## destino; la pelota no sale «de espaldas» con un balanceo hacia delante.
func _pass_behind(stick: Vector2) -> Dictionary:
	var ctx: MatchContext = await make_match(Vector3(-9.45, 0.11, 0.1))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-10.0, 0.0, 0.0), 60, src, true)
	p.is_human_controlled = true
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	var mate: Footballer = add_player(ctx, 0, Vector3(-18.0, 0.0, 1.5), 60, null, false)
	ctx.ball.register_touch(p)
	await physics_frames(20)
	var st := {"fwd": Vector3.ZERO, "t": -1.0, "clip": ""}
	var frames := [0]
	ctx.event_emitted.connect(func(e: GameEvent) -> void:
		if e.type == GameEvent.Type.PASS and float(st["t"]) < 0.0:
			st["fwd"] = p.locomotion.forward()
			st["clip"] = String(e.data.get("clip", ""))
			st["t"] = frames[0] / 60.0)
	src.move = stick
	src.hold_pass()
	await physics_frames(6)
	src.release_pass()
	var ball_dir := Vector3.ZERO
	for i in 150:
		await tree.physics_frame
		frames[0] += 1
		if float(st["t"]) >= 0.0 and ball_dir == Vector3.ZERO and frames[0] > int(float(st["t"]) * 60.0) + 3:
			ball_dir = KickModel.flat(ctx.ball.linear_velocity).normalized()
	var to_mate: Vector3 = KickModel.flat(mate.global_position - p.global_position).normalized()
	var out := {"kicked": float(st["t"]) >= 0.0, "t": st["t"], "body_vs_ball": KickModel.angle_between_deg(st["fwd"], ball_dir) if ball_dir != Vector3.ZERO else 999.0,
		"ball_vs_mate": KickModel.angle_between_deg(ball_dir, to_mate) if ball_dir != Vector3.ZERO else 999.0, "stats": p.ball_handler.kick_stats.duplicate(),
		"clip": st["clip"], "role": String(PackLibrary.meta(StringName(st["clip"])).get("role", "")) if String(st["clip"]) != "" else ""}
	cleanup()
	return out

func test_pass_to_a_mate_behind_uses_a_back_kick_or_turns() -> void:
	for cfg in [["joystick suelto", Vector2.ZERO], ["joystick hacia el companero", Vector2(-1, 0.15)]]:
		var r: Dictionary = await _pass_behind(cfg[1])
		note("pase atras (%s): golpeo=%s a los %.2f s con %s (%s), cuerpo vs pelota %.0f grados, pelota vs companero %.0f grados, %s" % [cfg[0], r["kicked"], r["t"], r["clip"], r["role"], r["body_vs_ball"], r["ball_vs_mate"], str(r["stats"])])
		check(r["kicked"], "%s: el pase sale" % cfg[0])
		# La pelota solo puede salir hacia la espalda del cuerpo con un golpeo girando o un taco (clips kick_turn / kick_back
		# del banco): nunca con un balanceo de frente.
		var back_clip: bool = String(r["role"]) == "kick_turn" or String(r["role"]) == "kick_back"
		check(float(r["body_vs_ball"]) < 60.0 or back_clip, "%s: golpea de frente al destino o con un golpeo girando / taco (%.0f grados, %s)" % [cfg[0], r["body_vs_ball"], r["role"]])
		check(int(r["stats"].get("missed", 0)) == 0, "%s: con el pie en la pelota" % cfg[0])
		# Con el joystick suelto el pase va al frente (como en PES); con el joystick hacia el companero, a el.
		if (cfg[1] as Vector2).length() > 0.2:
			check(float(r["ball_vs_mate"]) < 25.0, "%s: la pelota va al companero (%.0f grados)" % [cfg[0], r["ball_vs_mate"]])

