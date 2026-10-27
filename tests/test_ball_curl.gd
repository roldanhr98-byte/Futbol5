extends TestCase
## Efecto (chanfle / comba): el giro lateral curva la pelota por el efecto Magnus de la fisica real de la pelota. Un tiro
## con efecto sale "abierto" y la curva lo devuelve; el gesto del joystick (girar entre pulsar y soltar) lo pide.

func _fly(ball: Ball, v: Vector3, spin: Vector3, seconds: float) -> Array:
	ball.reset_at(Vector3(0.0, 0.3, 0.0))
	await physics_frames(2)
	ball.kick(v, spin, null)
	var pts: Array = []
	for i in int(seconds * 60.0):
		await tree.physics_frame
		pts.append(ball.global_position)
	return pts

func test_side_spin_curves_the_real_ball() -> void:
	var w: Dictionary = await make_world(Vector3(0.0, 0.3, 0.0))
	var ball: Ball = w["ball"]
	var v := Vector3(22.0, 4.0, 0.0)
	var straight: Array = await _fly(ball, v, Vector3.ZERO, 0.8)
	var curl_right: Array = await _fly(ball, v, KickModel.curl_spin(Vector3(1, 0, 0), 1.0, 50.0), 0.8)
	var curl_left: Array = await _fly(ball, v, KickModel.curl_spin(Vector3(1, 0, 0), -1.0, 50.0), 0.8)
	var zs: float = (straight[-1] as Vector3).z
	var zr: float = (curl_right[-1] as Vector3).z
	var zl: float = (curl_left[-1] as Vector3).z
	note("tras 0.8 s (~17 m): sin efecto z=%.2f, chanfle a la derecha z=%.2f, a la izquierda z=%.2f" % [zs, zr, zl])
	# Mirando a +X, la derecha es +Z.
	check(zr > zs + 0.6, "con efecto a la derecha la pelota se curva a la derecha (%.2f m)" % (zr - zs))
	check(zl < zs - 0.6, "y al reves (%.2f m)" % (zl - zs))
	# La curva crece con el tiempo (es una curva, no un angulo de salida): desvio a mitad < mitad del desvio final.
	var mid: float = (curl_right[curl_right.size() / 2] as Vector3).z - (straight[straight.size() / 2] as Vector3).z
	check(mid < 0.5 * (zr - zs), "la desviacion aumenta en el vuelo (mitad %.2f m de %.2f m)" % [mid, zr - zs])
	check(ball.trail_active or ball.linear_velocity.length() > 10.0, "estela activa en el tiro rapido")

func test_stick_gesture_asks_for_curl_and_shot_bends_back_on_goal() -> void:
	check_near(BallHandler.curl_from(Vector3(1, 0, 0), Vector3(1, 0, 0)), 0.0, 0.001, "sin giro, sin efecto")
	var right_turn: float = BallHandler.curl_from(Vector3(1, 0, 0), Vector3(1, 0, 0.8).normalized())
	check(right_turn > 0.4, "girar el joystick a la derecha (+Z mirando a +X) pide efecto a la derecha (%.2f)" % right_turn)
	check(BallHandler.curl_from(Vector3(1, 0, 0), Vector3(1, 0, -0.8).normalized()) < -0.4, "a la izquierda, efecto a la izquierda")
	# Tiro con chanfle real: la salida se abre y la pelota acaba en el arco.
	var ctx: MatchContext = await make_match(Vector3(5.0, 0.11, 4.0))
	var p: Footballer = add_player(ctx, 0, Vector3(4.5, 0.0, 4.0), 70)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, -0.2).normalized())
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var aim: Vector3 = (Vector3(20.0, 0.0, -1.0) - Vector3(5.0, 0.0, 4.0)).normalized()
	var res: KickModel.KickResult = ShotAssist.compute(p, ctx, aim, 0.7, false, rng, 0.5, -0.9)
	note("tiro con chanfle a la izquierda: tipo %s, efecto %.1f, sale %.1f grados abierto" % [res.kind, res.curl, KickModel.signed_angle_deg(aim, res.final_dir)])
	check(String(res.kind) == "curl_shot", "tipo de tiro con efecto")
	check(KickModel.signed_angle_deg(aim, res.final_dir) < -1.5, "sale abierto hacia la derecha para cerrarse a la izquierda")
	ctx.ball.kick(res.velocity, res.spin, p)
	p.ball_handler.lockout = 1.0   # el que patea no vuelve a tocarla (como tras cualquier golpeo)
	var goal := [false]
	ctx.pitch.goal_scored.connect(func(_g: Goal, _pos: Vector3) -> void: goal[0] = true)
	var min_z: float = INF
	for i in 120:
		await tree.physics_frame
		if ctx.ball.global_position.x > 18.0:
			min_z = minf(min_z, absf(ctx.ball.global_position.z))
	note("pelota en la linea de gol a |z|=%.2f m (medio arco %.2f), gol=%s" % [min_z, ctx.pitch.config.half_goal(), str(goal[0])])
	check(min_z < ctx.pitch.config.half_goal() + 0.6, "la curva la devuelve hacia el arco")
