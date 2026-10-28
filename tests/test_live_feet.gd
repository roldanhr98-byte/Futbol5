extends TestCase
## Conduccion con el esqueleto ANIMADO: cada toque lo da una punta de pie que de verdad llega a la pelota (no un
## temporizador), y aun asi el jugador conserva la pelota al trote, a la carrera, a sprint y en zigzag.
## Necesita renderizado (xvfb-run -a godot --rendering-driver opengl3 ...): en headless el esqueleto no se anima y la
## prueba se OMITE (la conduccion usa entonces la cadencia de la marcha, cubierta por test_dribbling).

func _needs_render() -> bool:
	if DisplayServer.get_name() == "headless":
		skip("el esqueleto no se anima en headless: ejecutar con xvfb-run --rendering-driver opengl3")
		return true
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("no existe la libreria del pack")
		return true
	return false

func _carry(stick: Vector2, sprint: bool, seconds: float, zigzag: bool = false) -> Dictionary:
	var ctx: MatchContext = await make_match(Vector3(-14.4, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-15.0, 0.0, 0.0), 60, src, true)
	p.is_human_controlled = true   # el jugador de la persona (la IA tiene reglas propias, p. ej. no salir de la cancha)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	var dists: Array[float] = []
	p.ball_handler.touched_ball.connect(func(_k: StringName) -> void:
		if p.ball_handler.last_touch_foot_distance >= 0.0:
			dists.append(p.ball_handler.last_touch_foot_distance))
	src.move = stick
	src.sprint = sprint
	var kept: int = 0
	var frames: int = int(seconds * 60.0)
	var trace: bool = zigzag and OS.get_environment("TRACE_ZIGZAG") != ""
	if trace:
		p.ball_handler.touched_ball.connect(func(k: StringName) -> void:
			var o: Vector3 = KickModel.flat(ctx.ball.global_position - p.global_position)
			print("ZZ toque %s/%s pie %d pelota %.2f,%.2f v %.2f" % [k, p.ball_handler.last_touch_mode, p.ball_handler.last_touch_foot, o.dot(p.locomotion.forward()), o.dot(p.locomotion.right()), p.locomotion.speed]))
	for i in frames:
		if zigzag:
			src.move = Vector2(0.8, 0.6 if (i / 50) % 2 == 0 else -0.6)
		await tree.physics_frame
		if trace and i % 5 == 0:
			var o2: Vector3 = KickModel.flat(ctx.ball.global_position - p.global_position)
			print("ZZ f%d pelota %.2f,%.2f v %.2f giro %.2f escala %.2f clip %s curva %s activo %s" % [i, o2.dot(p.locomotion.forward()), o2.dot(p.locomotion.right()), p.locomotion.speed, p.locomotion.turn_rate, p.locomotion.turn_scale, p.ball_handler._clip_driving(), p.ball_handler._curving, not p.ball_handler._touch_active.is_empty()])
		if p.ball_handler.ball_distance() < 1.6:
			kept += 1
	var bh: BallHandler = p.ball_handler
	dists.sort()
	var out := {"live": bh.feet_live, "touches": bh.dribble_touch_count, "foot": bh.foot_touches,
		"median": dists[dists.size() / 2] if not dists.is_empty() else -1.0, "kept": float(kept) / float(frames),
		"speed": p.locomotion.speed}
	cleanup()
	return out

func test_dribble_touches_come_from_the_animated_foot() -> void:
	if _needs_render():
		return
	for cfg in [["trote", Vector2(0.65, 0), false], ["carrera", Vector2(1, 0), false], ["sprint", Vector2(1, 0), true]]:
		var r: Dictionary = await _carry(cfg[1], cfg[2], 4.0)
		note("%s (%.2f m/s): %d toques, %d con el pie animado, distancia punta-centro de la pelota mediana %.2f m, pelota cerca %d %%" % [cfg[0], r["speed"], r["touches"], r["foot"], r["median"], int(r["kept"] * 100.0)])
		check(r["live"], "%s: el esqueleto se anima (pies vivos)" % cfg[0])
		check(r["touches"] >= 3, "%s: hay toques de conduccion (%d)" % [cfg[0], r["touches"]])
		check(float(r["foot"]) >= 0.8 * float(r["touches"]), "%s: al menos el 80 %% de los toques los da un pie (%d de %d)" % [cfg[0], r["foot"], r["touches"]])
		check(r["median"] >= 0.0 and r["median"] <= 0.30, "%s: la punta del pie esta en la pelota al tocarla (mediana %.2f m)" % [cfg[0], r["median"]])
		check(r["kept"] > 0.95, "%s: conserva la pelota (%d %% del tiempo a menos de 1.6 m)" % [cfg[0], int(r["kept"] * 100.0)])

func test_zigzag_keeps_the_ball_with_foot_touches() -> void:
	if _needs_render():
		return
	BallHandler.foot_sync_enabled = false
	var base: Dictionary = await _carry(Vector2(0.8, 0.6), false, 5.0, true)
	BallHandler.foot_sync_enabled = true
	note("zigzag sin pies vivos (referencia): pelota cerca %d %%" % int(base["kept"] * 100.0))
	# Cuatro pasadas (otra semilla del error del toque cada una): de una sola pasada la proporcion de toques con pie
	# oscila mucho (medido con el codigo anterior a los toques de clip: 45-81 % por pasada, 60-71 % sumando 8 pasadas;
	# con toques de clip 57 % sumando 8). Un zigzag de 74 grados cada 0.83 s lo resuelven sobre todo los toques de giro,
	# que rescatan la pelota sin pie cuando ninguno llega a tiempo.
	var foot := 0
	var touches := 0
	var kept := 1.0
	for k in 4:
		var r: Dictionary = await _carry(Vector2(0.8, 0.6), false, 5.0, true)
		note("zigzag %d: %d toques, %d con el pie, mediana %.2f m, pelota cerca %d %%" % [k, r["touches"], r["foot"], r["median"], int(r["kept"] * 100.0)])
		foot += int(r["foot"])
		touches += int(r["touches"])
		kept = minf(kept, float(r["kept"]))
	check(float(foot) >= 0.5 * float(touches), "en zigzag la mayoria de los toques los da un pie (%d de %d en 4 pasadas)" % [foot, touches])
	check(kept > 0.9, "en zigzag conserva la pelota (peor pasada %d %%)" % int(kept * 100.0))

func test_stopping_from_a_run_keeps_the_ball_at_the_feet() -> void:
	if _needs_render():
		return
	var ctx: MatchContext = await make_match(Vector3(-14.4, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-15.0, 0.0, 0.0), 60, src, true)
	p.is_human_controlled = true   # el jugador de la persona (la IA tiene reglas propias, p. ej. no salir de la cancha)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	src.move = Vector2(1, 0)
	await wait_seconds(2.0)
	var foot0: int = p.ball_handler.foot_touches
	var t0: int = p.ball_handler.dribble_touch_count
	src.move = Vector2.ZERO
	await wait_seconds(1.6)
	var d: float = p.ball_handler.ball_distance()
	note("frenada desde %.1f m/s: pelota a %.2f m del cuerpo, %d toques (%d con el pie) al frenar" % [5.3, d, p.ball_handler.dribble_touch_count - t0, p.ball_handler.foot_touches - foot0])
	check(p.locomotion.speed < 0.3, "el jugador se detiene (%.2f m/s)" % p.locomotion.speed)
	check(d < 1.0, "la pelota queda a sus pies al frenar (%.2f m)" % d)

## Conduccion con un joystick que cambia en el tiempo: stick_at(i) da el joystick en el fotograma i, sprint_at(i) el
## sprint. Ademas de los toques mide si el jugador pasa POR ENCIMA de la pelota (centro del cuerpo a menos de 0.25 m
## de ella) o la deja atras sin causa (pelota detras del cuerpo, fuera de un giro), y lo mas lejos que se adelanta.
func _carry_fn(stick_at: Callable, sprint_at: Callable, seconds: float) -> Dictionary:
	var ctx: MatchContext = await make_match(Vector3(-14.4, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-15.0, 0.0, 0.0), 60, src, true)
	p.is_human_controlled = true   # el jugador de la persona (la IA tiene reglas propias, p. ej. no salir de la cancha)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	var dists: Array[float] = []
	p.ball_handler.touched_ball.connect(func(_k: StringName) -> void:
		if p.ball_handler.last_touch_foot_distance >= 0.0:
			dists.append(p.ball_handler.last_touch_foot_distance))
	var frames: int = int(seconds * 60.0)
	var kept: int = 0
	var over: int = 0
	var behind: int = 0
	var max_ahead: float = 0.0
	var max_speed: float = 0.0
	for i in frames:
		src.move = stick_at.call(i)
		src.sprint = sprint_at.call(i)
		await tree.physics_frame
		var off: Vector3 = KickModel.flat(ctx.ball.global_position - p.global_position)
		if off.length() < 1.6:
			kept += 1
		if off.length() < 0.25:
			over += 1
		var fwd: float = off.dot(p.locomotion.forward())
		if fwd < -0.15 and absf(p.locomotion.turn_rate) < 1.5 and p.locomotion.speed > 1.0:
			behind += 1
		max_ahead = maxf(max_ahead, fwd)
		max_speed = maxf(max_speed, p.locomotion.speed)
	var bh: BallHandler = p.ball_handler
	dists.sort()
	var out := {"touches": bh.dribble_touch_count, "foot": bh.foot_touches, "median": dists[dists.size() / 2] if not dists.is_empty() else -1.0,
		"kept": float(kept) / float(frames), "over": float(over) / float(frames), "behind": float(behind) / float(frames),
		"max_ahead": max_ahead, "max_speed": max_speed, "possessor": ctx.possessor == p}
	cleanup()
	return out

func _report_carry(name: String, r: Dictionary) -> void:
	note("%s: %d toques (%d con el pie), mediana punta-pelota %.2f m, pelota cerca %d %%, encima de la pelota %d %%, pelota atras %d %%, se adelanta hasta %.2f m, velocidad max %.1f m/s" % [
		name, r["touches"], r["foot"], r["median"], int(r["kept"] * 100.0), int(r["over"] * 100.0), int(r["behind"] * 100.0), r["max_ahead"], r["max_speed"]])

func test_curved_dribble_acceleration_and_turns_with_the_ball() -> void:
	if _needs_render():
		return
	var no_sprint := func(_i: int) -> bool: return false
	# Curva continua: el joystick gira 360 grados cada 6.3 s (circulo de ~4 m de radio al trote), durante 10 s.
	var curve: Dictionary = await _carry_fn(func(i: int) -> Vector2: return Vector2(cos(i / 60.0), sin(i / 60.0)) * 0.8, no_sprint, 10.0)
	_report_carry("curva", curve)
	check(curve["kept"] > 0.9, "en curva conserva la pelota (%d %%)" % int(curve["kept"] * 100.0))
	# 60 %: en una curva cerrada continua (radio ~4 m) parte de los toques son de rescate (ningun pie llega a tiempo).
	# Medido: 11 de 18 con la pelota siempre cerca y nunca atras; exigir un pie cerca para el rescate (probado) rompia
	# el frenado y los giros. Limitacion documentada.
	check(float(curve["foot"]) >= 0.6 * float(curve["touches"]), "en curva la mayoria de los toques los da un pie (%d de %d)" % [curve["foot"], curve["touches"]])
	check(curve["over"] < 0.05, "en curva no pasa por encima de la pelota (%d %%)" % int(curve["over"] * 100.0))
	# Arranque desde parado hasta el sprint: los toques se alargan (la pelota se adelanta mas) sin perderla.
	var accel: Dictionary = await _carry_fn(func(i: int) -> Vector2: return Vector2(0.3 if i < 60 else 1.0, 0.0), func(i: int) -> bool: return i >= 90, 4.0)
	_report_carry("aceleracion hasta el sprint", accel)
	check(accel["max_speed"] > 5.5, "llega al sprint con la pelota (%.1f m/s)" % accel["max_speed"])
	# 0.75 m (antes 0.9): con toques de clip la pelota llega a su punto sin velocidad relativa (sin el «pasarse»
	# involuntario de la conduccion por pisadas, que la dejaba a 1.09 m); medido 0.82 m, frente a ~0.55 m al trote.
	check(accel["max_ahead"] > 0.75 and accel["max_ahead"] < 2.6, "al acelerar el toque se alarga sin perderla (se adelanta %.2f m)" % accel["max_ahead"])
	check(accel["kept"] > 0.85 and accel["possessor"], "conserva la pelota al acelerar (%d %%)" % int(accel["kept"] * 100.0))
	check(accel["over"] < 0.05 and accel["behind"] < 0.05, "no la pisa ni la deja atras al acelerar (encima %d %%, atras %d %%)" % [int(accel["over"] * 100.0), int(accel["behind"] * 100.0)])
	# Cambio de direccion de 180 grados a la carrera y vuelta.
	var turn: Dictionary = await _carry_fn(func(i: int) -> Vector2: return Vector2(1.0 if (i / 120) % 2 == 0 else -1.0, 0.0), no_sprint, 6.0)
	_report_carry("cambios de direccion de 180 grados", turn)
	check(turn["kept"] > 0.8 and turn["possessor"], "en los giros de 180 grados conserva la pelota (%d %%)" % int(turn["kept"] * 100.0))
	check(turn["over"] < 0.08, "en los giros no atraviesa la pelota (%d %%)" % int(turn["over"] * 100.0))

## Soltar el joystick conduciendo (lento, trote, carrera, sprint): el jugador frena Y para la pelota cerca del cuerpo.
## Hallado en el video del usuario (10.2 s): al soltar el joystick despues de un toque, la pelota seguia rodando sola y
## el jugador se quedaba quieto, perdiendola. Mide la separacion maxima durante la parada, donde queda la pelota y si
## sigue rodando; despues vuelve a acelerar y comprueba que la lleva.
func test_releasing_the_stick_stops_with_the_ball_and_accelerates_again() -> void:
	if _needs_render():
		return
	for cfg in [["paso lento", Vector2(0.35, 0.0), false], ["trote", Vector2(0.7, 0.0), false], ["carrera", Vector2(1.0, 0.0), false], ["sprint", Vector2(1.0, 0.0), true]]:
		var ctx: MatchContext = await make_match(Vector3(-14.4, 0.11, 0.0))
		var src := ScriptedInput.new()
		var p: Footballer = add_player(ctx, 0, Vector3(-15.0, 0.0, 0.0), 60, src, true)
		p.is_human_controlled = true
		p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
		src.move = cfg[1]
		src.sprint = cfg[2]
		await wait_seconds(1.8)
		var v0: float = p.locomotion.speed
		src.move = Vector2.ZERO
		src.sprint = false
		var max_sep: float = 0.0
		var stop_t: float = -1.0
		for i in 120:
			await tree.physics_frame
			var d: float = p.ball_handler.ball_distance()
			max_sep = maxf(max_sep, d)
			if stop_t < 0.0 and p.locomotion.speed < 0.3 and ctx.ball.ground_speed() < 0.3:
				stop_t = i / 60.0
		var d_end: float = p.ball_handler.ball_distance()
		var bv_end: float = ctx.ball.ground_speed()
		# Volver a acelerar con la pelota.
		src.move = Vector2(1.0, 0.0)
		var kept: int = 0
		for i in 90:
			await tree.physics_frame
			if p.ball_handler.ball_distance() < 1.6:
				kept += 1
		note("%s (%.1f m/s): al soltar, separacion maxima %.2f m, quieto con la pelota a los %.2f s, pelota a %.2f m y %.2f m/s al final; al reacelerar la conserva %d %%" % [
			cfg[0], v0, max_sep, stop_t, d_end, bv_end, int(kept * 100 / 90)])
		check(d_end < 0.9 and bv_end < 0.3, "%s: termina parado con la pelota al pie (%.2f m, %.2f m/s)" % [cfg[0], d_end, bv_end])
		check(max_sep < 1.6, "%s: la pelota no se va al frenar (separacion maxima %.2f m)" % [cfg[0], max_sep])
		check(kept >= 85, "%s: vuelve a acelerar con la pelota (%d %%)" % [cfg[0], int(kept * 100 / 90)])
		cleanup()

## El caso del video (10.2 s): con el joystick suelto, la pelota propia sale rodando del pie (1.6 m/s). Antes el
## jugador se quedaba quieto y la perdia; ahora la acompana y la para.
func test_ball_rolling_away_after_releasing_the_stick_is_followed_and_stopped() -> void:
	if _needs_render():
		return
	var ctx: MatchContext = await make_match(Vector3(-14.4, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-15.0, 0.0, 0.0), 60, src, true)
	p.is_human_controlled = true
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	await physics_frames(10)
	ctx.ball.reset_at(Vector3(-14.3, 0.11, 0.3), Vector3(1.2, 0.0, 1.0))
	await physics_frames(1)
	ctx.ball.register_touch(p)
	var max_sep: float = 0.0
	var stopped_at: float = -1.0
	for i in 180:
		await tree.physics_frame
		var d: float = p.ball_handler.ball_distance()
		max_sep = maxf(max_sep, d)
		if stopped_at < 0.0 and d < 0.9 and ctx.ball.ground_speed() < 0.3 and p.locomotion.speed < 0.4:
			stopped_at = i / 60.0
	note("pelota que se va rodando con el joystick suelto: separacion maxima %.2f m, parada con el jugador a los %.2f s, pelota a %.2f m al final" % [max_sep, stopped_at, p.ball_handler.ball_distance()])
	check(stopped_at > 0.0, "el jugador va a por la pelota y la para (%.2f s)" % stopped_at)
	check(max_sep < 2.2, "no la deja irse (separacion maxima %.2f m)" % max_sep)

## Cambios de direccion de 45, 90 y 180 grados (al trote, a la carrera, a sprint y despacio): en 1.5 s el jugador avanza
## hacia el rumbo nuevo CON la pelota. Mide el avance, la separacion maxima y si el cuerpo se va primero en sentido
## contrario a buscarla (fallo visto en el video: giraba sobre si mismo sin avanzar).
func test_direction_changes_make_progress_with_the_ball() -> void:
	if _needs_render():
		return
	for cfg in [["despacio 90", 0.4, false, 90.0], ["despacio 180", 0.4, false, 180.0], ["trote 45", 0.7, false, 45.0], ["trote 90", 0.7, false, 90.0],
			["carrera 135", 1.0, false, 135.0], ["carrera 180", 1.0, false, 180.0], ["sprint 90", 1.0, true, 90.0], ["sprint 180", 1.0, true, 180.0]]:
		var ctx: MatchContext = await make_match(Vector3(-4.4, 0.11, 0.0))
		var src := ScriptedInput.new()
		var p: Footballer = add_player(ctx, 0, Vector3(-5.0, 0.0, 0.0), 60, src, true)
		p.is_human_controlled = true
		p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
		src.move = Vector2(cfg[1], 0.0)
		src.sprint = cfg[2]
		await wait_seconds(1.5)
		var a: float = deg_to_rad(cfg[3])
		var want := Vector3(cos(a), 0.0, sin(a))
		src.move = Vector2(want.x, want.z) * float(cfg[1])
		var p0: Vector3 = p.global_position
		var back: float = 0.0
		var max_sep: float = 0.0
		for i in 90:
			await tree.physics_frame
			back = minf(back, (p.global_position - p0).dot(want))
			max_sep = maxf(max_sep, p.ball_handler.ball_distance())
		var prog: float = (p.global_position - p0).dot(want)
		var ball_prog: float = (KickModel.flat(ctx.ball.global_position) - KickModel.flat(p0)).dot(want)
		note("%s grados: en 1.5 s avanza %.2f m hacia el rumbo nuevo (retrocede como mucho %.2f m), pelota a %.2f m de su inicio en ese rumbo, separacion maxima %.2f m" % [cfg[0], prog, -back, ball_prog, max_sep])
		# Despacio se recorre menos; la media vuelta a sprint primero frena desde 6.4 m/s (~0.5 s y ~0.5 m hacia atras).
		var min_prog: float = 1.0 if float(cfg[1]) < 0.5 else (1.5 if (cfg[2] and float(cfg[3]) >= 180.0) else 2.0)
		check(prog > min_prog, "%s: avanza hacia el rumbo nuevo (%.2f m)" % [cfg[0], prog])
		check(max_sep < 1.6, "%s: conserva la pelota en el giro (separacion maxima %.2f m)" % [cfg[0], max_sep])
		check(ball_prog > min_prog - 0.5, "%s: la pelota va con el (%.2f m)" % [cfg[0], ball_prog])
		cleanup()
