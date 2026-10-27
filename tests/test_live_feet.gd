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
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	var dists: Array[float] = []
	p.ball_handler.touched_ball.connect(func(_k: StringName) -> void:
		if p.ball_handler.last_touch_foot_distance >= 0.0:
			dists.append(p.ball_handler.last_touch_foot_distance))
	src.move = stick
	src.sprint = sprint
	var kept: int = 0
	var frames: int = int(seconds * 60.0)
	for i in frames:
		if zigzag:
			src.move = Vector2(0.8, 0.6 if (i / 50) % 2 == 0 else -0.6)
		await tree.physics_frame
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
	var r: Dictionary = await _carry(Vector2(0.8, 0.6), false, 5.0, true)
	note("zigzag: %d toques, %d con el pie, mediana %.2f m, pelota cerca %d %%" % [r["touches"], r["foot"], r["median"], int(r["kept"] * 100.0)])
	check(float(r["foot"]) >= 0.7 * float(r["touches"]), "en zigzag la mayoria de los toques los da un pie (%d de %d)" % [r["foot"], r["touches"]])
	check(r["kept"] > 0.9, "en zigzag conserva la pelota (%d %%)" % int(r["kept"] * 100.0))

func test_stopping_from_a_run_keeps_the_ball_at_the_feet() -> void:
	if _needs_render():
		return
	var ctx: MatchContext = await make_match(Vector3(-14.4, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-15.0, 0.0, 0.0), 60, src, true)
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
