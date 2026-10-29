extends TestCase
## Giro con toques (BallTurn, el giro hacia atras de Dream League Soccer): conduciendo, con el joystick hacia atras, el
## jugador frena, rodea la pelota dando toques cortos y sale hacia el rumbo nuevo con la pelota delante, sin pisarla ni
## pivotar en seco. La fisica se mide en headless; con render (xvfb-run --rendering-driver opengl3) tambien que el pie
## que toca llegue a la pelota en cada toque.

func _skip_if_missing() -> bool:
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("no existe la libreria del pack")
		return true
	return false

## Conduce recto `run_s` s con el joystick a `stick` (y sprint), gira el joystick `angle_deg` grados y mide 2 s.
func _turn(stick: float, sprint: bool, run_s: float = 1.6, angle_deg: float = 180.0) -> Dictionary:
	var ctx: MatchContext = await make_match(Vector3(-9.4, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-10.0, 0.0, 0.0), 60, src, true)
	p.is_human_controlled = true
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	src.move = Vector2(stick, 0.0)
	src.sprint = sprint
	await wait_seconds(run_s)
	var speed0: float = p.locomotion.speed
	var a: float = deg_to_rad(angle_deg)
	var want := Vector3(cos(a), 0.0, sin(a))
	src.move = Vector2(want.x, want.z) * maxf(stick, 0.7)
	src.sprint = false
	var p0: Vector3 = p.global_position
	var bt: BallTurn = p.ball_handler.ball_turn
	var started0: int = int(bt.stats["started"])
	var max_sep: float = 0.0
	var turned_at: float = -1.0
	var back: float = 0.0
	var touch_gap: Array[float] = []
	var others: int = 0
	var live: bool = p.ball_handler.feet_live
	var touch_ball := []
	ctx.ball.touched.connect(func(who: Node) -> void:
		if who != p:
			others += 1)
	# Pie en cada toque: la pelota se guarda en el paso del toque y la punta del pie (con el IK) se lee en la imagen
	# siguiente, la que muestra el contacto; distancia de la punta a la superficie de la pelota.
	p.ball_handler.touched_ball.connect(func(kind: StringName) -> void:
		if live and (kind == &"turn" or kind == &"turn_exit"):
			touch_ball.append([ctx.ball.global_position, bt.foot]))
	var trace: bool = OS.get_environment("TRACE_TURN") != ""
	for i in 120:
		var pending: Array = touch_ball.duplicate()
		touch_ball.clear()
		await tree.physics_frame
		for tb in pending:
			var toe: Vector3 = p.visual.touch_ik.abs_toe_world[int(tb[1])]
			touch_gap.append((toe - (tb[0] as Vector3)).length() - ctx.ball.radius)
		max_sep = maxf(max_sep, p.ball_handler.ball_distance())
		back = minf(back, (p.global_position - p0).dot(want))
		if trace and i < 80:
			var o: Vector3 = KickModel.flat(ctx.ball.global_position - p.global_position)
			print("BT f%d fase %d v %.2f mira %.0f pelota %.2f,%.2f vb %.2f toques %d modo %s" % [i, bt.phase, p.locomotion.speed, KickModel.angle_between_deg(p.locomotion.forward(), want), o.dot(want), o.dot(Vector3(-want.z, 0, want.x)), KickModel.flat(ctx.ball.linear_velocity).length(), bt.touches, p.ball_handler.last_touch_mode])
		if turned_at < 0.0 and KickModel.angle_between_deg(p.locomotion.forward(), want) < 30.0:
			turned_at = float(i + 1) / 60.0
	var off: Vector3 = KickModel.flat(ctx.ball.global_position - p.global_position)
	touch_gap.sort()
	var out := {
		"speed0": speed0,
		"started": int(bt.stats["started"]) - started0,
		"done": int(bt.stats["done"]),
		"drag": int(p.ball_handler.drag_back.stats["started"]),
		"last": bt.last.duplicate(),
		"max_sep": max_sep,
		"prog": (p.global_position - p0).dot(want) - back,
		"overrun": -back,
		"ball_ahead": off.dot(want),
		"turned_at": turned_at,
		"possession": p.ball_handler.has_possession(),
		"others": others,
		"touch_gap_max": touch_gap[touch_gap.size() - 1] if not touch_gap.is_empty() else -9.0,
		"touch_gaps": touch_gap,
		"live": live,
	}
	cleanup()
	return out

func _describe(name: String, r: Dictionary) -> String:
	var l: Dictionary = r["last"]
	return "%s (%.1f m/s): giros %d, toques %d %s, mira al rumbo nuevo a %.2f s, giro completo en %.2f s; sigue de largo %.2f m, avanza %.2f m en 2 s, pelota %.2f m delante, separacion maxima %.2f m; pie-superficie de la pelota en el toque max %.3f m %s" % [
		name, r["speed0"], r["started"], int(l.get("touches", -1)), str(l.get("touch_speeds", [])), r["turned_at"], float(l.get("turn_time", -1.0)),
		r["overrun"], r["prog"], r["ball_ahead"], r["max_sep"], r["touch_gap_max"], str(r.get("touch_gaps", []))]

func _check_turn(name: String, r: Dictionary, max_overrun: float) -> void:
	var l: Dictionary = r["last"]
	check(r["started"] == 1 and r["done"] == 1, "%s: gira con toques (%d empezados, %d completos, %s)" % [name, r["started"], r["done"], str(l.get("aborted", ""))])
	check(r["drag"] == 0, "%s: sin el boton REGATE no pisa la pelota (%d)" % [name, r["drag"]])
	check(int(l.get("touches", 0)) >= 3, "%s: rodea la pelota con varios toques (%d)" % [name, int(l.get("touches", 0))])
	check(r["turned_at"] > 0.0 and r["turned_at"] < 1.5, "%s: mira al rumbo nuevo en menos de 1.5 s (%.2f)" % [name, r["turned_at"]])
	check(r["max_sep"] < 1.3, "%s: no pierde la pelota (separacion maxima %.2f m)" % [name, r["max_sep"]])
	check(r["possession"] and r["ball_ahead"] > 0.0, "%s: termina con la pelota delante en el rumbo nuevo (%.2f m)" % [name, r["ball_ahead"]])
	check(r["overrun"] < max_overrun, "%s: frena sin irse de largo (%.2f m < %.1f)" % [name, r["overrun"], max_overrun])
	check(r["others"] == 0, "%s: nadie mas toca la pelota (%d)" % [name, r["others"]])
	if r["live"]:
		check(r["touch_gap_max"] > -1.0 and r["touch_gap_max"] < 0.12, "%s: el pie llega a la pelota en cada toque (max %.3f m de su superficie)" % [name, r["touch_gap_max"]])

func test_turn_back_with_touches_at_walk_jog_and_run() -> void:
	if _skip_if_missing():
		return
	for cfg in [["caminando", 0.4, false, 1.2], ["trote", 0.7, false, 1.6], ["carrera", 1.0, false, 2.4]]:
		var r: Dictionary = await _turn(cfg[1], cfg[2])
		note(_describe(cfg[0], r))
		_check_turn(cfg[0], r, cfg[3])

func test_turn_at_different_stride_phases() -> void:
	if _skip_if_missing():
		return
	# A la carrera la pelota va y vuelve del pie: el giro tiene que salir en cualquier momento de la zancada.
	var ok: int = 0
	for run_s in [1.6, 1.7, 1.8, 1.9, 2.0, 2.1]:
		var r: Dictionary = await _turn(1.0, false, run_s)
		var name: String = "carrera, giro a los %.1f s" % run_s
		note(_describe(name, r))
		if r["started"] == 1 and r["done"] == 1:
			ok += 1
		check(r["max_sep"] < 1.5, "%s: conserva la pelota (%.2f m)" % [name, r["max_sep"]])
		check(r["prog"] > 1.2, "%s: sale hacia el rumbo nuevo (%.2f m)" % [name, r["prog"]])
	check(ok >= 5, "a la carrera gira con toques en casi cualquier momento de la zancada (%d de 6)" % ok)

func test_wide_turn_and_sprint() -> void:
	if _skip_if_missing():
		return
	var r: Dictionary = await _turn(0.7, false, 1.6, 135.0)
	note(_describe("trote, 135 grados", r))
	_check_turn("trote, 135 grados", r, 1.6)
	var s: Dictionary = await _turn(1.0, true, 2.0)
	note(_describe("sprint", s))
	check(s["max_sep"] < 1.8, "sprint: conserva la pelota en el giro (%.2f m)" % s["max_sep"])
	check(s["prog"] > 1.0, "sprint: sale hacia el rumbo nuevo (%.2f m)" % s["prog"])

func test_ai_carrier_turns_with_the_same_touches() -> void:
	if _skip_if_missing():
		return
	var ctx: MatchContext = await make_match(Vector3(-9.4, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-10.0, 0.0, 0.0), 60, src, true)
	p.is_human_controlled = false
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	src.move = Vector2(0.7, 0.0)
	await wait_seconds(1.6)
	src.move = Vector2(-0.8, 0.0)
	await wait_seconds(1.6)
	note("IA: giros %s, ultimo %s" % [str(p.ball_handler.ball_turn.stats), str(p.ball_handler.ball_turn.last)])
	check(int(p.ball_handler.ball_turn.stats["done"]) >= 1, "la IA hace el mismo giro (%s)" % str(p.ball_handler.ball_turn.stats))
	check(p.ball_handler.has_possession(), "y conserva la pelota")
	cleanup()
