extends TestCase
## El jugador de la persona va a la pelota suelta (prueba03: «el jugador siempre va al balon, el que esta siendo
## controlado»): con el joystick suelto corre solo al punto donde la alcanza y la controla; con el joystick apuntando mas
## o menos hacia ella, el rumbo se ajusta a ese punto; apuntando a otro lado manda el joystick. Un pase a un companero o
## una pelota que otro conduce no se persigue.

## Pelota rodando cruzada delante del jugador (velocidad bv) y joystick `stick`; devuelve tiempo hasta controlarla.
func _chase(bv: Vector3, stick: Vector2, human: bool = true, seconds: float = 3.0) -> Dictionary:
	var ctx: MatchContext = await make_match(Vector3(0.0, 0.11, 4.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-3.0, 0.0, 0.0), 60, src, false)
	p.is_human_controlled = human
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	await physics_frames(2)
	ctx.ball.kick(bv, ctx.ball.rolling_spin(bv), null)
	src.move = stick
	var got: float = -1.0
	var min_d: float = INF
	for i in int(seconds * 60.0):
		await tree.physics_frame
		min_d = minf(min_d, p.ball_handler.ball_distance())
		if got < 0.0 and p.ball_handler.has_possession() and ctx.ball.last_toucher == p:
			got = float(i + 1) / 60.0
	var out := {"got": got, "min_d": min_d, "moved": KickModel.flat(p.global_position - Vector3(-3.0, 0.0, 0.0)).length()}
	cleanup()
	return out

func test_controlled_player_goes_to_the_loose_ball_alone() -> void:
	var r: Dictionary = await _chase(Vector3(1.5, 0.0, -2.0), Vector2.ZERO)
	note("joystick suelto: controla la pelota suelta a los %.2f s (distancia minima %.2f m)" % [r["got"], r["min_d"]])
	check(r["got"] > 0.0 and r["got"] < 2.5, "con el joystick suelto va a la pelota suelta y la controla (%.2f s)" % r["got"])

func test_stick_toward_the_ball_is_adjusted_to_the_meeting_point() -> void:
	# El joystick apunta a donde ESTA la pelota (no a donde va): sin ajuste el jugador llega tarde y detras.
	var r: Dictionary = await _chase(Vector3(2.5, 0.0, -1.5), Vector2(0.6, 0.8).normalized())
	note("joystick hacia la pelota: la controla a los %.2f s" % r["got"])
	check(r["got"] > 0.0 and r["got"] < 2.5, "con el joystick hacia la pelota la alcanza y la controla (%.2f s)" % r["got"])

func test_stick_elsewhere_and_ai_are_not_steered() -> void:
	var away: Dictionary = await _chase(Vector3(1.5, 0.0, -2.0), Vector2(-1.0, 0.0), true, 1.5)
	note("joystick hacia el otro lado: distancia minima a la pelota %.2f m" % away["min_d"])
	check(away["got"] < 0.0, "apuntando a otro lado manda el joystick (no va a la pelota)")
	var ai: Dictionary = await _chase(Vector3(1.5, 0.0, -2.0), Vector2.ZERO, false, 1.5)
	check(ai["moved"] < 0.5, "la asistencia es solo para el jugador de la persona (la IA con entrada quieta no se mueve: %.2f m)" % ai["moved"])

func test_pass_pressed_before_reaching_a_loose_ball_is_not_lost() -> void:
	# Pase pedido con la pelota suelta a 2.5 m (un rebote): el jugador va a por ella y pasa al llegar; antes la orden
	# caducaba a los 0.5 s sin patada (KICK_WHIFF out_of_reach), «los pases erran la patada».
	var ctx: MatchContext = await make_match(Vector3(-0.5, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-3.0, 0.0, 0.0), 60, src, false)
	p.is_human_controlled = true
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	var mate: Footballer = add_player(ctx, 0, Vector3(6.0, 0.0, 3.0), 60, null, false)
	await physics_frames(2)
	ctx.ball.kick(Vector3(0.8, 0.0, 0.4), Vector3.ZERO, null)
	var passes := []
	var whiffs := []
	ctx.event_emitted.connect(func(e: GameEvent) -> void:
		if e.type == GameEvent.Type.PASS:
			passes.append(e)
		elif e.type == GameEvent.Type.KICK_WHIFF:
			whiffs.append(e))
	src.move = Vector2(1.0, 0.35).normalized() * 0.3
	src.hold_pass()
	await physics_frames(6)
	src.release_pass()
	await wait_seconds(2.0)
	note("pase pedido a 2.5 m de la pelota suelta: pases %d, golpes en falso %d" % [passes.size(), whiffs.size()])
	check(passes.size() == 1, "el pase se da al llegar a la pelota (%d pases, %d en falso)" % [passes.size(), whiffs.size()])
	check(mate != null, "hay receptor")
	cleanup()
