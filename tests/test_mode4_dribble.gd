extends TestCase
## Conduccion en el modo 4 (el unico modo del juego): la pelota es fisica y el jugador se adapta a ella. Cada caso mide, paso
## a paso, la distancia pelota-jugador, que la pelota solo cambie de velocidad por un toque (Ball.kick) o su propia fisica
## (nunca un salto de posicion), y que despues del cambio pedido con el joystick la pelota vaya hacia donde se pidio.

const FACE := Vector3(1, 0, 0)

func _mode4() -> void:
	Tuning.gameplay_mode = 4
	PackLibrary.reload()

func _restore() -> void:
	Tuning.gameplay_mode = 1
	PackLibrary.reload()

func _skip_if_missing() -> bool:
	if not ResourceLoader.exists(PackLibrary.JSON_FIELD_PATH):
		skip("no existe assets/animations/json_clips.res")
		return true
	return false

## Jugador humano en (-10, 0, 0) mirando a +X con la pelota delante del pie; trota hacia +X `warm` pasos para tener la pelota
## en conduccion.
func _setup(seed: int, stick: Vector2 = Vector2(1, 0), warm: int = 90, start_z: float = 0.0) -> Dictionary:
	_mode4()
	# La cancha mide 40 x 20 m: el jugador empieza lejos de la banda hacia la que va a girar.
	var start := Vector3(-10.0, 0.0, start_z)
	var ctx: MatchContext = await make_match(start + FACE * 0.45 + Vector3(0, 0.11, 0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, start, 70, src, true)
	p.is_human_controlled = true
	p.locomotion.yaw = Locomotion.yaw_from_dir(FACE)
	p.ball_handler.rng.seed = seed
	await physics_frames(3)
	src.move = stick
	var s := {"ctx": ctx, "p": p, "src": src, "max_d": 0.0, "jumps": 0, "touches": 0, "lost": false}
	await _run(s, warm)
	s["max_d"] = 0.0
	return s

## Avanza `frames` pasos midiendo distancia maxima, saltos de posicion de la pelota y toques del portador.
func _run(s: Dictionary, frames: int) -> void:
	var ctx: MatchContext = s["ctx"]
	var p: Footballer = s["p"]
	var b: Ball = ctx.ball
	var prev: Vector3 = b.global_position
	var prev_v: Vector3 = b.linear_velocity
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	for i in frames:
		var t0: int = p.ball_handler.dribble_touch_count + p.ball_handler.foot_touches
		await tree.physics_frame
		var bp: Vector3 = b.global_position
		# Un salto de posicion mayor que lo que la pelota recorre a su velocidad (con margen) seria un teletransporte.
		if bp.distance_to(prev) > maxf(prev_v.length(), b.linear_velocity.length()) * dt * 1.6 + 0.02:
			s["jumps"] = int(s["jumps"]) + 1
		prev = bp
		prev_v = b.linear_velocity
		var d: float = KickModel.flat(bp - p.global_position).length()
		s["max_d"] = maxf(float(s["max_d"]), d)
		if p.ball_handler.dribble_touch_count + p.ball_handler.foot_touches > t0:
			s["touches"] = int(s["touches"]) + 1
	s["d"] = KickModel.flat(b.global_position - p.global_position).length()

func _ball_dir_error(s: Dictionary, want: Vector3) -> float:
	var b: Ball = (s["ctx"] as MatchContext).ball
	var v: Vector3 = KickModel.flat(b.linear_velocity)
	if v.length() < 0.3:
		# Pelota casi quieta: la direccion es donde esta respecto del jugador.
		v = KickModel.flat(b.global_position - (s["p"] as Footballer).global_position)
	return KickModel.angle_between_deg(v, want)

func test_straight_dribble_keeps_the_ball_with_touches() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _setup(11)
	await _run(s, 180)
	var p: Footballer = s["p"]
	note("recto 3 s: toques %d, distancia max %.2f m, final %.2f m, velocidad %.1f m/s, saltos %d" % [s["touches"], s["max_d"], s["d"], p.locomotion.speed, s["jumps"]])
	check(int(s["touches"]) >= 3, "conduce con toques (%d)" % s["touches"])
	check(float(s["max_d"]) < 2.2 and float(s["d"]) < 1.8, "la pelota no se escapa (max %.2f m)" % s["max_d"])
	check(int(s["jumps"]) == 0, "la pelota nunca salta de posicion")
	check(p.ball_handler.has_possession(), "sigue con la pelota")
	cleanup()
	_restore()

func _turn_case(seed: int, deg: float) -> Dictionary:
	var want: Vector3 = FACE.rotated(Vector3.UP, deg_to_rad(deg))
	var s: Dictionary = await _setup(seed, Vector2(1, 0), 90, -signf(want.z) * 6.0)
	(s["src"] as ScriptedInput).move = Vector2(want.x, want.z)
	await _run(s, 80)
	s["dir_err"] = _ball_dir_error(s, want)
	s["body_err"] = KickModel.angle_between_deg((s["p"] as Footballer).locomotion.forward(), want)
	s["progress"] = KickModel.flat((s["ctx"] as MatchContext).ball.global_position - (s["p"] as Footballer).global_position).dot(want)
	return s

func test_turn_right_takes_the_ball_along() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _turn_case(12, -90.0)
	note("giro a la derecha 90: pelota a %.0f grados del joystick, cuerpo a %.0f, distancia max %.2f m, final %.2f m, saltos %d" % [s["dir_err"], s["body_err"], s["max_d"], s["d"], s["jumps"]])
	check(float(s["body_err"]) < 30.0, "el cuerpo se orienta al joystick")
	check(float(s["dir_err"]) < 45.0, "la pelota va hacia la nueva direccion (%.0f grados)" % s["dir_err"])
	check(float(s["max_d"]) < 2.5 and float(s["d"]) < 1.8, "no la deja atras ni se escapa (max %.2f m)" % s["max_d"])
	check(int(s["jumps"]) == 0, "sin saltos de posicion")
	cleanup()
	_restore()

func test_turn_left_takes_the_ball_along() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _turn_case(13, 90.0)
	note("giro a la izquierda 90: pelota a %.0f grados del joystick, cuerpo a %.0f, distancia max %.2f m, final %.2f m, saltos %d" % [s["dir_err"], s["body_err"], s["max_d"], s["d"], s["jumps"]])
	check(float(s["body_err"]) < 30.0, "el cuerpo se orienta al joystick")
	check(float(s["dir_err"]) < 45.0, "la pelota va hacia la nueva direccion (%.0f grados)" % s["dir_err"])
	check(float(s["max_d"]) < 2.5 and float(s["d"]) < 1.8, "no la deja atras ni se escapa (max %.2f m)" % s["max_d"])
	check(int(s["jumps"]) == 0, "sin saltos de posicion")
	cleanup()
	_restore()

func test_sharp_direction_change_recovers_the_ball() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _turn_case(14, 150.0)
	note("cambio brusco 150: pelota a %.0f grados del joystick, cuerpo a %.0f, distancia max %.2f m, final %.2f m, avance hacia el joystick %.2f m, saltos %d" % [s["dir_err"], s["body_err"], s["max_d"], s["d"], s["progress"], s["jumps"]])
	check(float(s["body_err"]) < 35.0, "el cuerpo termina orientado al joystick")
	check(float(s["d"]) < 1.8 and (s["p"] as Footballer).ball_handler.has_possession(), "conserva o recupera la pelota (%.2f m)" % s["d"])
	check(int(s["jumps"]) == 0, "sin saltos de posicion")
	cleanup()
	_restore()

func test_accelerate_and_decelerate_with_the_ball() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _setup(15, Vector2(0.4, 0))
	var src: ScriptedInput = s["src"]
	src.move = Vector2(1, 0)
	src.sprint = true
	await _run(s, 120)
	var fast: float = (s["p"] as Footballer).locomotion.speed
	var max_fast: float = s["max_d"]
	src.sprint = false
	src.move = Vector2(0.25, 0)
	s["max_d"] = 0.0
	await _run(s, 120)
	var slow: float = (s["p"] as Footballer).locomotion.speed
	note("acelerar: %.1f m/s (max %.2f m); desacelerar: %.1f m/s (max %.2f m, final %.2f m); saltos %d" % [fast, max_fast, slow, s["max_d"], s["d"], s["jumps"]])
	check(fast > 4.0 and slow < 2.5, "acelera y desacelera (%.1f -> %.1f m/s)" % [fast, slow])
	check(max_fast < 3.2, "a sprint la pelota va mas adelantada pero alcanzable (%.2f m)" % max_fast)
	check(float(s["d"]) < 1.5, "al frenar la recoge cerca (%.2f m)" % s["d"])
	check(int(s["jumps"]) == 0, "sin saltos de posicion")
	cleanup()
	_restore()

func test_short_touches_at_walking_pace() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _setup(16, Vector2(0.3, 0), 60)
	s["touches"] = 0
	await _run(s, 240)
	var p: Footballer = s["p"]
	note("caminando 4 s: %d toques, distancia max %.2f m, velocidad %.1f m/s" % [s["touches"], s["max_d"], p.locomotion.speed])
	check(int(s["touches"]) >= 3, "toques cortos frecuentes (%d en 4 s)" % s["touches"])
	check(float(s["max_d"]) < 1.3, "pelota siempre cerca del pie (%.2f m)" % s["max_d"])
	cleanup()
	_restore()

func test_ball_that_runs_ahead_is_recovered() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _setup(17)
	var b: Ball = (s["ctx"] as MatchContext).ball
	var p: Footballer = s["p"]
	# La pelota se adelanta (rebote, toque largo): sale a 10.5 m/s hacia delante (el jugador va a ~5.4 m/s).
	b.kick(KickModel.flat(p.locomotion.forward()) * 10.5, b.rolling_spin(KickModel.flat(p.locomotion.forward()) * 10.5), null)
	var recovered: int = -1
	var away: float = 0.0
	var touches0: int = p.ball_handler.dribble_touch_count + p.ball_handler.foot_touches
	for i in 240:
		await tree.physics_frame
		var d: float = KickModel.flat(b.global_position - p.global_position).length()
		away = maxf(away, d)
		# Recuperada: despues de alejarse, el jugador la alcanza y la vuelve a tocar.
		if recovered < 0 and away > 2.0 and d < 1.2 and p.ball_handler.dribble_touch_count + p.ball_handler.foot_touches > touches0:
			recovered = i
	note("pelota adelantada a 10.5 m/s: se alejo hasta %.2f m, recuperada en el paso %d, distancia final %.2f m" % [away, recovered, KickModel.flat(b.global_position - p.global_position).length()])
	check(recovered >= 0 and recovered < 200, "la alcanza y vuelve a tocarla (paso %d)" % recovered)
	cleanup()
	_restore()

func test_drag_back_with_the_button_turns_with_the_ball() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _setup(18, Vector2(0.5, 0), 70)
	var src: ScriptedInput = s["src"]
	var p: Footballer = s["p"]
	var back: Vector3 = -FACE
	src.move = Vector2(back.x, back.z)
	src.skill()
	var started: String = ""
	for i in 6:
		await tree.physics_frame
		if started == "" and p.ball_handler.json_move.active:
			started = "%s/%s" % [p.ball_handler.json_move.intent, p.ball_handler.json_move.clip]
	await _run(s, 84)
	var body: float = KickModel.angle_between_deg(p.locomotion.forward(), back)
	var rel: Vector3 = KickModel.flat((s["ctx"] as MatchContext).ball.global_position - p.global_position)
	note("REGATE + atras: %s; cuerpo a %.0f grados del rumbo nuevo, pelota a %.2f m (%.2f m hacia alli), saltos %d" % [started, body, rel.length(), rel.dot(back), s["jumps"]])
	check(started.begins_with("drag/") or started.begins_with("skill/"), "arranca la vuelta con un clip con toques (%s)" % started)
	check(body < 45.0, "termina mirando al rumbo nuevo (%.0f grados)" % body)
	check(rel.length() < 1.5 and rel.dot(back) > -0.3, "la pelota va con el (%.2f m)" % rel.length())
	check(int(s["jumps"]) == 0, "sin saltos de posicion")
	cleanup()
	_restore()
