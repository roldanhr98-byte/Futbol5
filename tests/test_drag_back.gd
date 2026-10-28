extends TestCase
## Vuelta atras pisando la pelota (DragBack): con la pelota delante y el joystick hacia atras el jugador la pisa con la
## suela, la frena con el cuerpo, la arrastra hacia el rumbo nuevo y pivota detras de ella, sin perderla. La fisica se
## mide en headless; con render (xvfb-run --rendering-driver opengl3) tambien que la suela este de verdad sobre la pelota.

func _skip_if_missing() -> bool:
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("no existe la libreria del pack")
		return true
	return false

## Conduce recto `run_s` segundos con el joystick a `stick` (y sprint), invierte el joystick y mide 1.5 s.
func _reverse(stick: float, sprint: bool, run_s: float = 1.6, angle_deg: float = 180.0) -> Dictionary:
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
	var p0: Vector3 = p.global_position
	var dbk: DragBack = p.ball_handler.drag_back
	var started0: int = int(dbk.stats["started"])
	var max_sep: float = 0.0
	var turned_at: float = -1.0
	var back: float = 0.0
	var sole_gap: Array[float] = []
	var sole_y: Array[float] = []
	var others: int = 0
	ctx.ball.touched.connect(func(who: Node) -> void:
		if who != p:
			others += 1)
	var trace: bool = OS.get_environment("TRACE_DRAG") != ""
	for i in 120:
		await tree.physics_frame
		max_sep = maxf(max_sep, p.ball_handler.ball_distance())
		back = minf(back, (p.global_position - p0).dot(want))
		if trace and i < 70:
			var o: Vector3 = KickModel.flat(ctx.ball.global_position - p.global_position)
			print("DB f%d fase %d v %.2f mira %.0f pelota %.2f,%.2f vb %.2f toque %s" % [i, dbk.phase, p.locomotion.speed, KickModel.angle_between_deg(p.locomotion.forward(), want), o.dot(want), o.dot(Vector3(-want.z, 0, want.x)), KickModel.flat(ctx.ball.linear_velocity).dot(want), p.ball_handler.last_touch_mode])
		if turned_at < 0.0 and KickModel.angle_between_deg(p.locomotion.forward(), want) < 25.0:
			turned_at = float(i + 1) / 60.0
		if dbk.phase == DragBack.Phase.HOLD and p.ball_handler.feet_live:
			var toe: Vector3 = p.visual.touch_ik.abs_toe_world[dbk.foot]
			var top: Vector3 = ctx.ball.global_position + Vector3.UP * ctx.ball.radius
			sole_gap.append(toe.distance_to(top))
			sole_y.append(toe.y)
	var off: Vector3 = KickModel.flat(ctx.ball.global_position - p.global_position)
	sole_gap.sort()
	sole_y.sort()
	var out := {
		"speed0": speed0,
		"started": int(dbk.stats["started"]) - started0,
		"done": int(dbk.stats["done"]),
		"last": dbk.last.duplicate(),
		"max_sep": max_sep,
		"prog": (p.global_position - p0).dot(want) - back,
		"overrun": -back,
		"ball_ahead": off.dot(want),
		"turned_at": turned_at,
		"possession": p.ball_handler.has_possession(),
		"sole_gap": sole_gap[sole_gap.size() / 2] if not sole_gap.is_empty() else -1.0,
		"sole_y": sole_y[sole_y.size() / 2] if not sole_y.is_empty() else -1.0,
		"live": p.ball_handler.feet_live,
	}
	cleanup()
	return out

func _describe(name: String, r: Dictionary) -> String:
	var l: Dictionary = r["last"]
	return "%s (%.1f m/s): vuelta %d, pisa a %.2f m a los %.2f s, pisando %.2f s, tiron %.1f m/s, mira al rumbo nuevo a %.2f s; sigue de largo %.2f m y despues avanza %.2f m en 2 s, pelota %.2f m delante, separacion maxima %.2f m; suela-pelota %.3f m (punta a %.2f m del suelo)" % [
		name, r["speed0"], r["started"], float(l.get("contact_ahead", -1.0)), float(l.get("contact_t", -1.0)), float(l.get("hold_time", -1.0)),
		float(l.get("pull_speed", -1.0)), r["turned_at"], r["overrun"], r["prog"], r["ball_ahead"], r["max_sep"], r["sole_gap"], r["sole_y"]]

func _check_drag(name: String, r: Dictionary) -> void:
	var l: Dictionary = r["last"]
	check(r["started"] == 1, "%s: hace la vuelta pisando la pelota (%d)" % [name, r["started"]])
	check(l.has("pull_speed"), "%s: la suela arrastra la pelota (%s)" % [name, str(l)])
	check(r["turned_at"] > 0.0 and r["turned_at"] < 0.8, "%s: mira al rumbo nuevo en menos de 0.8 s (%.2f)" % [name, r["turned_at"]])
	check(r["max_sep"] < 1.4, "%s: no pierde la pelota (separacion maxima %.2f m)" % [name, r["max_sep"]])
	check(r["possession"] and r["ball_ahead"] > 0.0, "%s: termina con la pelota delante en el rumbo nuevo (%.2f m)" % [name, r["ball_ahead"]])
	check(r["prog"] > 1.5, "%s: sale hacia el rumbo nuevo (%.2f m tras girar)" % [name, r["prog"]])
	if r["live"]:
		check(r["sole_gap"] >= 0.0 and r["sole_gap"] < 0.12, "%s: la suela esta sobre la pelota mientras la pisa (%.3f m)" % [name, r["sole_gap"]])

func test_drag_back_with_the_sole_keeps_the_ball() -> void:
	if _skip_if_missing():
		return
	for cfg in [["caminando", 0.4], ["trote", 0.7]]:
		var r: Dictionary = await _reverse(cfg[1], false)
		note(_describe(cfg[0], r))
		_check_drag(cfg[0], r)

func test_drag_back_at_a_run_depends_on_where_the_ball_is() -> void:
	if _skip_if_missing():
		return
	# A la carrera la pelota va y vuelve del pie (toque y alcance): con la pelota al pie hay pisada; recien lanzada por
	# delante, la media vuelta por el costado (no espera a alcanzarla). En los dos casos se conserva la pelota.
	var drags: int = 0
	for run_s in [1.6, 1.7, 1.8, 1.9, 2.0, 2.1]:
		var r: Dictionary = await _reverse(1.0, false, run_s)
		var name: String = "carrera, vuelta a los %.1f s" % run_s
		note(_describe(name, r))
		if r["started"] == 1:
			drags += 1
			_check_drag(name, r)
		else:
			check(r["max_sep"] < 1.6, "%s: la media vuelta conserva la pelota (%.2f m)" % [name, r["max_sep"]])
			check(r["prog"] > 1.5, "%s: sale hacia el rumbo nuevo (%.2f m tras girar)" % [name, r["prog"]])
	note("a la carrera: %d de 6 vueltas con pisada" % drags)
	check(drags >= 1, "a la carrera, con la pelota al pie, tambien pisa (%d de 6)" % drags)

func test_sprint_reversal_keeps_the_side_half_turn() -> void:
	if _skip_if_missing():
		return
	# A sprint no hay pisada (MAX_SPEED): la media vuelta rodea la pelota por el costado, como antes.
	var r: Dictionary = await _reverse(1.0, true, 2.0)
	note("sprint (%.1f m/s): vueltas pisando %d, separacion maxima %.2f m, en 1.5 s avanza %.2f m" % [r["speed0"], r["started"], r["max_sep"], r["prog"]])
	check(r["speed0"] > DragBack.MAX_SPEED, "va a sprint (%.1f m/s)" % r["speed0"])
	check(r["started"] == 0, "a sprint no pisa la pelota (%d)" % r["started"])
	check(r["max_sep"] < 1.8, "conserva la pelota en la media vuelta (%.2f m)" % r["max_sep"])

func test_ai_carrier_uses_the_same_drag_back() -> void:
	if _skip_if_missing():
		return
	# La IA no tiene atajos: la misma vuelta la dispara su rumbo pedido. Con una persona de entrada scripteada en un
	# jugador NO humano (como la IA) la mecanica es la misma.
	var ctx: MatchContext = await make_match(Vector3(-9.4, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-10.0, 0.0, 0.0), 60, src, true)
	p.is_human_controlled = false
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	src.move = Vector2(0.7, 0.0)
	await wait_seconds(1.6)
	src.move = Vector2(-0.8, 0.0)
	await wait_seconds(1.2)
	note("IA: vueltas %s, ultima %s" % [str(p.ball_handler.drag_back.stats), str(p.ball_handler.drag_back.last)])
	check(int(p.ball_handler.drag_back.stats["done"]) >= 1, "la IA hace la misma vuelta (%s)" % str(p.ball_handler.drag_back.stats))
	check(p.ball_handler.has_possession(), "y conserva la pelota")
	cleanup()
