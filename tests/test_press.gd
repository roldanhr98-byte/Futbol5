extends TestCase
## Presion defensiva: busca la pelota (no al rival), respeta el joystick como ajuste de angulo,
## no teletransporta y robar no esta garantizado.

func _dist_to_ball(ctx: MatchContext, f: Footballer) -> float:
	return Vector2(ctx.ball.global_position.x - f.global_position.x, ctx.ball.global_position.z - f.global_position.z).length()

func test_press_closes_distance_to_a_loose_ball_even_when_the_stick_changes_direction() -> void:
	var ctx: MatchContext = await make_match(Vector3(0.0, 0.11, 0.0))
	var src := ScriptedInput.new()
	var d: Footballer = add_player(ctx, 0, Vector3(-9.0, 0.0, 4.0), 50, src)
	src.press_held = true
	src.move = Vector2(0.0, -1.0)      # joystick hacia arriba, perpendicular a la pelota
	var d0: float = _dist_to_ball(ctx, d)
	await wait_seconds(0.8)
	var d1: float = _dist_to_ball(ctx, d)
	src.move = Vector2(-1.0, 0.0)      # el usuario cambia a la izquierda (alejandose de la pelota)
	await wait_seconds(0.8)
	var d2: float = _dist_to_ball(ctx, d)
	src.move = Vector2(0.0, 1.0)       # y luego hacia abajo
	await wait_seconds(0.8)
	var d3: float = _dist_to_ball(ctx, d)
	note("distancia defensor-pelota: %.1f -> %.1f -> %.1f -> %.1f m (joystick arriba/izquierda/abajo)" % [d0, d1, d2, d3])
	check(d.is_pressing or d3 < 2.5, "la presion sigue activa mientras se mantiene el boton")
	check(d1 < d0 - 1.0, "se acerca aunque el joystick apunte de lado (%.1f -> %.1f)" % [d0, d1])
	check(d2 < d1, "no abandona la busqueda al cambiar el joystick (%.1f -> %.1f)" % [d1, d2])
	check(d3 < 2.0, "alcanza la zona de la pelota (%.1f m)" % d3)

func test_press_never_exceeds_physical_speed_limits() -> void:
	var ctx: MatchContext = await make_match(Vector3(15.0, 0.11, 8.0))
	var src := ScriptedInput.new()
	var d: Footballer = add_player(ctx, 0, Vector3(-15.0, 0.0, -8.0), 50, src)
	src.press_held = true
	var prev: Vector3 = d.global_position
	var max_step_speed: float = 0.0
	for i in 240:
		await tree.physics_frame
		var step: float = d.global_position.distance_to(prev) * 60.0
		max_step_speed = maxf(max_step_speed, step)
		prev = d.global_position
	note("velocidad maxima observada durante la presion: %.2f m/s (limite de sprint %.2f)" % [max_step_speed, d.locomotion.max_sprint_speed()])
	check(max_step_speed <= d.locomotion.max_sprint_speed() * 1.08, "no hay teletransporte ni sobrevelocidad")
	check(d.global_position.x > -15.0 + 5.0, "avanza hacia la pelota")

func test_press_intercept_point_is_ahead_of_a_moving_carrier() -> void:
	var ctx: MatchContext = await make_match(Vector3(0.0, 0.11, 0.0))
	var src := ScriptedInput.new()
	var d: Footballer = add_player(ctx, 0, Vector3(6.0, 0.0, 6.0), 50, src)
	var att_src := ScriptedInput.new()
	var att: Footballer = add_player(ctx, 1, Vector3(-2.0, 0.0, 0.0), 50, att_src)
	att.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	ctx.ball.reset_at(Vector3(-1.4, 0.11, 0.0))
	att_src.move = Vector2(0.6, 0.0)       # el atacante conduce hacia +X
	await wait_seconds(1.2)
	src.press_held = true
	await wait_seconds(0.1)
	check(d.press_info != null and d.press_info.active, "la presion esta activa")
	if d.press_info != null:
		var ip: Vector3 = d.press_info.intercept_point
		note("pelota en x=%.2f, punto de intercepcion x=%.2f (el portador avanza hacia +X)" % [ctx.ball.global_position.x, ip.x])
		check(ip.x > ctx.ball.global_position.x + 0.3, "intercepta por delante de la trayectoria, no persigue la posicion actual")
		check(d.press_info.carrier == att, "identifica al portador rival")

func test_press_released_stops_the_chase() -> void:
	var ctx: MatchContext = await make_match(Vector3(0.0, 0.11, 0.0))
	var src := ScriptedInput.new()
	var d: Footballer = add_player(ctx, 0, Vector3(-9.0, 0.0, 0.0), 50, src)
	src.press_held = true
	await wait_seconds(0.8)
	check(d.is_pressing, "presionando mientras se mantiene el boton")
	src.press_held = false
	await wait_seconds(1.0)
	check(not d.is_pressing, "al soltar el boton termina la presion")
	check(d.locomotion.speed < 0.3, "sin joystick se detiene (v=%.2f)" % d.locomotion.speed)

func test_tackle_success_is_probabilistic() -> void:
	var ctx: MatchContext = await make_match(Vector3(0.0, 0.11, 0.0))
	var def_src := ScriptedInput.new()
	var att_src := ScriptedInput.new()
	var d: Footballer = add_player(ctx, 0, Vector3(-6.0, 0.0, 0.0), 50, def_src)
	var att: Footballer = add_player(ctx, 1, Vector3(2.0, 0.0, 0.0), 50, att_src)
	var won: int = 0
	var lost: int = 0
	var events: Array = []
	ctx.event_emitted.connect(func(e: GameEvent) -> void: events.append(e))
	for i in 40:
		def_src.press_held = false
		att_src.move = Vector2.ZERO
		d.place_at(Vector3(-6.0, 0.0, 0.0), Locomotion.yaw_from_dir(Vector3(1, 0, 0)))
		att.place_at(Vector3(2.0, 0.0, 0.0), Locomotion.yaw_from_dir(Vector3(-1, 0, 0)))
		ctx.ball.reset_at(Vector3(1.4, 0.11, 0.0))
		d.press.tackle_cooldown = 0.0
		d.press.reset()
		d.ball_handler.rng.seed = 900 + i
		att.ball_handler.rng.seed = 1900 + i
		events.clear()
		await physics_frames(4)
		# El atacante conduce hacia el defensor (-X); el defensor presiona.
		att_src.move = Vector2(-0.5, 0.0)
		def_src.press_held = true
		await wait_seconds(3.0)
		for e in events:
			if e.type == GameEvent.Type.TACKLE_WON:
				won += 1
			elif e.type == GameEvent.Type.TACKLE_FAILED:
				lost += 1
	note("40 duelos (atacante conduce, defensor presiona, marcaje 50): robos ganados=%d, intentos fallidos=%d" % [won, lost])
	check(won > 0, "a veces roba la pelota (%d)" % won)
	check(lost > 0, "a veces falla: robar no esta garantizado (%d)" % lost)
