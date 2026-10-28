extends TestCase
## Conduccion en linea recta MEDIDA con el esqueleto animado y comparada con la referencia del video B (juego comercial,
## medido fotograma a fotograma con seguimiento de la pelota y del jugador: un toque cada 0.60-0.66 s (mediana), la
## pelota 0.3-1.2 m por delante (media 0.56-0.76 m) y una deriva lateral de +-0.2 m que incluye el ruido de medicion).
## Mide por velocidad: intervalo entre toques, pie de cada toque (izquierdo, derecho o sin pie), alternancia de pies,
## distancia de la pelota por delante, deriva lateral y cambios de lado por segundo (oscilacion entre los pies).
## Necesita render (xvfb-run ... --rendering-driver opengl3); en headless se omite.

const REF_INTERVAL := 0.63
const REF_AHEAD_MEAN := 0.66

func _needs_render() -> bool:
	if DisplayServer.get_name() == "headless":
		skip("el esqueleto no se anima en headless: ejecutar con xvfb-run --rendering-driver opengl3")
		return true
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("no existe la libreria del pack")
		return true
	return false

func _straight(stick: float, sprint: bool, seconds: float) -> Dictionary:
	var ctx: MatchContext = await make_match(Vector3(-17.4, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-18.0, 0.0, 0.0), 60, src, true)
	p.is_human_controlled = true
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	var touches: Array = []
	var frame := [0]
	p.ball_handler.touched_ball.connect(func(k: StringName) -> void:
		touches.append({"f": frame[0], "foot": p.ball_handler.last_touch_foot, "mode": k}))
	src.move = Vector2(stick, 0.0)
	src.sprint = sprint
	var ahead: Array[float] = []
	var lateral: Array[float] = []
	var speeds: Array[float] = []
	var warm: int = 60
	var frames: int = int(seconds * 60.0)
	for i in frames:
		frame[0] = i
		await tree.physics_frame
		if i < warm:
			continue
		var off: Vector3 = KickModel.flat(ctx.ball.global_position - p.global_position)
		ahead.append(off.dot(p.locomotion.forward()))
		lateral.append(off.dot(p.locomotion.right()))
		speeds.append(p.locomotion.speed)
	var bh: BallHandler = p.ball_handler
	cleanup()
	# toques despues del calentamiento
	var tt: Array = touches.filter(func(e): return int(e["f"]) >= warm)
	var ints: Array[float] = []
	var alternate := 0
	var foot_l := 0
	var foot_r := 0
	var none := 0
	for k in tt.size():
		var e: Dictionary = tt[k]
		match int(e["foot"]):
			0: foot_l += 1
			1: foot_r += 1
			_: none += 1
		if k > 0:
			ints.append((int(e["f"]) - int(tt[k - 1]["f"])) / 60.0)
			if int(e["foot"]) >= 0 and int(tt[k - 1]["foot"]) >= 0 and int(e["foot"]) != int(tt[k - 1]["foot"]):
				alternate += 1
	ints.sort()
	var mean_a := 0.0
	for a in ahead:
		mean_a += a
	mean_a /= maxf(ahead.size(), 1)
	var mean_l := 0.0
	for l in lateral:
		mean_l += l
	mean_l /= maxf(lateral.size(), 1)
	var var_l := 0.0
	var side_changes := 0
	var side := 0   # lado actual respecto a la media, con histeresis de 3 cm
	for i in lateral.size():
		var dev: float = lateral[i] - mean_l
		var_l += dev * dev
		var now: int = 1 if dev > 0.03 else (-1 if dev < -0.03 else side)
		if side != 0 and now != side:
			side_changes += 1
		side = now
	var sp := 0.0
	for s in speeds:
		sp += s
	var dur: float = (frames - warm) / 60.0
	var sorted_a: Array[float] = ahead.duplicate()
	sorted_a.sort()
	return {"touches": tt.size(), "interval": ints[ints.size() / 2] if not ints.is_empty() else -1.0,
		"foot_l": foot_l, "foot_r": foot_r, "none": none, "alternate": float(alternate) / maxf(tt.size() - 1, 1),
		"ahead_min": sorted_a[int(sorted_a.size() * 0.05)] if not sorted_a.is_empty() else 0.0, "ahead_mean": mean_a,
		"ahead_max": sorted_a[int(sorted_a.size() * 0.95)] if not sorted_a.is_empty() else 0.0,
		"lat_std": sqrt(var_l / maxf(lateral.size(), 1)), "side_changes_s": side_changes / dur, "speed": sp / maxf(speeds.size(), 1),
		"kept": ahead.filter(func(a): return a > -0.3 and a < 1.8).size() / float(maxi(ahead.size(), 1)), "live": bh.feet_live}

func _report(name: String, r: Dictionary) -> void:
	note("%s (%.1f m/s): %d toques, intervalo mediano %.2f s (video B %.2f), pie izq./der./sin pie %d/%d/%d, alternancia %d %%, pelota delante %.2f / %.2f / %.2f m (p5/media/p95; B media %.2f), deriva lateral +-%.2f m, %.1f cambios de lado por s" % [
		name, r["speed"], r["touches"], r["interval"], REF_INTERVAL, r["foot_l"], r["foot_r"], r["none"], int(float(r["alternate"]) * 100.0),
		r["ahead_min"], r["ahead_mean"], r["ahead_max"], REF_AHEAD_MEAN, r["lat_std"], r["side_changes_s"]])

func test_straight_dribble_metrics_against_the_reference_video() -> void:
	if _needs_render():
		return
	for c in [["trote", 0.55, false], ["carrera", 1.0, false], ["sprint", 1.0, true]]:
		var r: Dictionary = await _straight(float(c[1]), bool(c[2]), 7.0)
		_report(String(c[0]), r)
		check(r["live"], "%s: los pies del esqueleto estan vivos" % c[0])
		check(float(r["kept"]) > 0.9, "%s: la pelota sigue con el jugador (%d %%)" % [c[0], int(float(r["kept"]) * 100.0)])
