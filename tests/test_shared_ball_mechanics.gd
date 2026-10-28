extends TestCase
## Una sola mecanica de pelota para la persona y para la IA: la IA solo produce entradas (InputFrame, como el joystick y
## los botones) y TODOS los impulsos que recibe la pelota de un jugador de campo salen de su BallHandler (toques de
## conduccion, control, golpeos con contacto) o de sus acciones (regate). Nadie mas empuja la pelota por la IA.

func _code(dir: String) -> String:
	var out := ""
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out += FileAccess.get_file_as_string(dir + "/" + f) + "\n"
	return out

func test_ai_code_never_moves_the_ball_directly() -> void:
	var ai: String = _code("res://scripts/ai")
	for forbidden in [".kick(", ".push(", "apply_central_impulse", "ball.global_position =", "reset_at(", "linear_velocity ="]:
		check(ai.find(forbidden) < 0, "scripts/ai no contiene '%s'" % forbidden)

func test_every_touch_of_an_ai_carrier_comes_from_its_ball_handler() -> void:
	var ctx: MatchContext = await make_match(Vector3(-7.5, 0.11, 0.0))
	var ai := AIInput.new(3, 0.7)
	var p: Footballer = add_player(ctx, 0, Vector3(-8.0, 0.0, 0.0), 60, ai, true)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	var handler_frames := {}
	p.ball_handler.touched_ball.connect(func(_k: StringName) -> void: handler_frames[Engine.get_physics_frames()] = true)
	p.ball_handler.kicked.connect(func(_a: StringName, _r) -> void: handler_frames[Engine.get_physics_frames()] = true)
	var ball_frames: Array = []
	ctx.ball.touched.connect(func(actor: Node) -> void:
		if actor == p:
			ball_frames.append(Engine.get_physics_frames()))
	await wait_seconds(6.0)
	var orphan := 0
	for f in ball_frames:
		if not handler_frames.has(f):
			orphan += 1
	note("IA con la pelota 6 s: %d toques de la pelota por el jugador, %d sin evento de su BallHandler; conduccion %d toques, golpeos %s" % [
		ball_frames.size(), orphan, p.ball_handler.dribble_touch_count, str(p.ball_handler.kick_stats)])
	check(ball_frames.size() > 3, "la IA juega la pelota (%d toques)" % ball_frames.size())
	check(orphan == 0, "todos los impulsos salen del BallHandler del jugador (%d sueltos)" % orphan)
