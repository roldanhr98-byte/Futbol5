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
	return await _phases([[stick, sprint, seconds]])

## Conduccion encadenando tramos [joystick, sprint, segundos, rumbo opcional] (cambios de ritmo como en la demo
## grabada). El rumbo opcional es una funcion del tiempo del tramo (s) que da el angulo del joystick en grados respecto a
## +X, positivo a la izquierda (curvas a velocidad). start_z: carril de salida (las curvas necesitan sitio a un lado).
func _phases(phases: Array, start_z: float = 0.0) -> Dictionary:
	var seconds := 0.0
	for ph in phases:
		seconds += float(ph[2])
	var ctx: MatchContext = await make_match(Vector3(-17.4, 0.11, start_z))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-18.0, 0.0, start_z), 60, src, true)
	p.is_human_controlled = true
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	var touches: Array = []
	var frame := [0]
	var timeline: Array = []
	p.ball_handler.touched_ball.connect(func(k: StringName) -> void:
		touches.append({"f": frame[0], "foot": p.ball_handler.last_touch_foot, "mode": k})
		var rel: Vector3 = ctx.ball.global_position - p.global_position
		timeline.append("f%d toque %s/%s pie %d pelota %.2f,%.2f v=%.2f" % [frame[0], k, p.ball_handler.last_touch_mode, p.ball_handler.last_touch_foot,
			rel.dot(p.locomotion.forward()), rel.dot(p.locomotion.right()), p.locomotion.speed]))
	var clip_log: Array = []
	var last_n := [0]
	var last_rj := [0]
	var pen: Dictionary = {}
	var over_n := [0]
	var curving_n := [0]
	var behind_n := [0]
	var ends: Array[int] = []
	var acc := 0.0
	for ph in phases:
		acc += float(ph[2])
		ends.append(int(acc * 60.0))
	var ahead: Array[float] = []
	var lateral: Array[float] = []
	var speeds: Array[float] = []
	var warm: int = 60
	var frames: int = int(seconds * 60.0)
	var cur := -1
	for i in frames:
		frame[0] = i
		var ph_i: int = 0
		while ph_i < ends.size() - 1 and i >= ends[ph_i]:
			ph_i += 1
		if ph_i != cur:
			cur = ph_i
			src.move = Vector2(float(phases[ph_i][0]), 0.0)
			src.sprint = bool(phases[ph_i][1])
			timeline.append("f%d tramo %s" % [i, phases[ph_i].slice(0, 3)])
		if phases[ph_i].size() > 3:
			var t_ph: float = (i - (ends[ph_i - 1] if ph_i > 0 else 0)) / 60.0
			var ang: float = deg_to_rad(float((phases[ph_i][3] as Callable).call(t_ph)))
			src.move = Vector2(cos(ang), -sin(ang)) * float(phases[ph_i][0])
		await tree.physics_frame
		var rj: int = 0
		for v in p.ball_handler.clip_plan_rejects.values():
			rj += int(v)
		if rj != last_rj[0]:
			last_rj[0] = rj
			var rel2: Vector3 = ctx.ball.global_position - p.global_position
			timeline.append("f%d descarte pelota %.2f,%.2f sync %.2f: %s" % [i, rel2.dot(p.locomotion.forward()), rel2.dot(p.locomotion.right()), p.ball_handler._touch_sync, p.ball_handler.last_plan_debug])
		var n: int = p.ball_handler.clip_touch_count + p.ball_handler.clip_touch_misses
		if n != last_n[0]:
			last_n[0] = n
			clip_log.append(p.ball_handler.last_clip_touch.duplicate())
		if OS.get_environment("TOUCH_LOG") == "2" and not touches.is_empty() and i - int(touches[-1]["f"]) <= 6:
			var rel3: Vector3 = ctx.ball.global_position - p.global_position
			timeline.append("   f%d pelota %.2f,%.2f v_pelota %.2f v_cuerpo %.2f" % [i, rel3.dot(p.locomotion.forward()), rel3.dot(p.locomotion.right()), KickModel.flat(ctx.ball.linear_velocity).length(), p.locomotion.speed])
		# Penetracion de la punta del pie que toco en la pelota en las imagenes que siguen al toque de clip (cuanto entra
		# la punta por detras de la superficie de la pelota, en la direccion de la marcha).
		if not touches.is_empty() and i - int(touches[-1]["f"]) <= 8 and p.ball_handler.last_touch_mode == &"clip":
			var tf: int = int(touches[-1]["foot"])
			if tf >= 0:
				var toe: Vector3 = p.ball_handler.toe_world(tf)
				var into: float = Tuning.ball.radius - KickModel.flat(ctx.ball.global_position - toe).dot(p.locomotion.forward())
				if absf(KickModel.flat(ctx.ball.global_position - toe).dot(p.locomotion.right())) < 0.15 and toe.y < 0.25:
					var tk: int = touches.size() - 1
					pen[tk] = maxf(float(pen.get(tk, 0.0)), into)
		if p.ball_handler._curving:
			curving_n[0] += 1
		if OS.get_environment("TOUCH_LOG") == "3" and i % 6 == 0:
			var o3: Vector3 = KickModel.flat(ctx.ball.global_position - p.global_position)
			timeline.append("   f%d escala de giro %.2f giro %.2f rad/s pelota %.2f,%.2f alcance %.2f" % [i, p.locomotion.turn_scale, p.locomotion.turn_rate, o3.dot(p.locomotion.forward()), o3.dot(p.locomotion.right()), p.ball_handler.touch_reach()])
		if i < warm:
			continue
		var off: Vector3 = KickModel.flat(ctx.ball.global_position - p.global_position)
		if off.length() < 0.25:
			over_n[0] += 1
		if off.dot(p.locomotion.forward()) < -0.15 and p.locomotion.speed > 1.0:
			behind_n[0] += 1
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
		"lat_p95": _abs_p95(lateral), "lat_std": sqrt(var_l / maxf(lateral.size(), 1)), "side_changes_s": side_changes / dur, "speed": sp / maxf(speeds.size(), 1),
		"kept": ahead.filter(func(a): return a > -0.3 and a < 1.8).size() / float(maxi(ahead.size(), 1)), "live": bh.feet_live,
		"clip": bh.clip_touch_count, "clip_miss": bh.clip_touch_misses, "clip_log": clip_log, "rejects": bh.clip_plan_rejects.duplicate(), "timeline": timeline, "pen": pen.values(),
		"over": over_n[0] / float(maxi(ahead.size(), 1)), "curving": curving_n[0] / float(frames), "behind": behind_n[0] / float(maxi(ahead.size(), 1))}

func _report(name: String, r: Dictionary) -> void:
	note("%s (%.1f m/s): %d toques (%d con animacion de toque, %d de ellos sin pie en la pelota), intervalo mediano %.2f s (video B %.2f), pie izq./der./sin pie %d/%d/%d, alternancia %d %%, pelota delante %.2f / %.2f / %.2f m (p5/media/p95; B media %.2f), deriva lateral +-%.2f m, %.1f cambios de lado por s" % [
		name, r["speed"], r["touches"], r["clip"], r["clip_miss"], r["interval"], REF_INTERVAL, r["foot_l"], r["foot_r"], r["none"], int(float(r["alternate"]) * 100.0),
		r["ahead_min"], r["ahead_mean"], r["ahead_max"], REF_AHEAD_MEAN, r["lat_std"], r["side_changes_s"]])

func test_straight_dribble_metrics_against_the_reference_video() -> void:
	if _needs_render():
		return
	var cases := [["trote", [[0.55, false, 7.0]]], ["carrera", [[1.0, false, 7.0]]], ["sprint", [[1.0, true, 7.0]]],
		["cambios de ritmo: trote, carrera, sprint", [[0.55, false, 2.5], [1.0, false, 1.8], [1.0, true, 2.7]]],
		["arrancada: paso, carrera y sprint", [[0.3, false, 1.0], [1.0, false, 0.5], [1.0, true, 2.5]]]]
	if OS.get_environment("DRIBBLE_CASE") != "":
		cases = cases.filter(func(c): return String(c[0]).begins_with(OS.get_environment("DRIBBLE_CASE")))
	for c in cases:
		var r: Dictionary = await _phases(c[1])
		_report(String(c[0]), r)
		if OS.get_environment("TOUCH_LOG") != "":
			note("   balanceos descartados por el plan: %s; en modo curva %d %% del tiempo" % [r["rejects"], int(float(r["curving"]) * 100.0)])
			if OS.get_environment("TOUCH_LOG") >= "2" and String(c[0]).begins_with(OS.get_environment("DRIBBLE_LOG_CASE")):
				for ln in r["timeline"]:
					note("     " + ln)
			for e in r["clip_log"]:
				note("   %s pie %d: t %.3f (plan %.3f) hueco %+.2f lateral %+.2f punta %s pelota %s %s" % [e.get("clip", ""), e.get("foot", -1), e.get("time", -1.0), e.get("plan_time", -1.0), e.get("gap", 0.0), e.get("lat", 0.0), e.get("toe", Vector3.ZERO), e.get("ball", Vector3.ZERO), "OK" if e.get("ok", false) else "SIN PIE"])
		var pv: Array = r["pen"]
		pv.sort()
		if not pv.is_empty():
			note("   punta dentro de la pelota tras el toque de clip: mediana %.3f m, maxima %.3f m (%d toques)" % [pv[pv.size() / 2], pv[-1], pv.size()])
		check(r["live"], "%s: los pies del esqueleto estan vivos" % c[0])
		check(float(r["kept"]) > 0.9, "%s: la pelota sigue con el jugador (%d %%)" % [c[0], int(float(r["kept"]) * 100.0)])

static func _abs_p95(values: Array[float]) -> float:
	var a: Array[float] = []
	for v in values:
		a.append(absf(v))
	a.sort()
	return a[int(a.size() * 0.95)] if not a.is_empty() else 0.0

## Curvas a velocidad sin giros bruscos: apuntar un poco a un lado corriendo, como en los videos de referencia (PES 2021,
## Dream League Soccer). Eslalon (el joystick oscila a los dos lados), arco sostenido y cambio de carril, a la carrera y
## a sprint. Mide lo mismo que la recta y ademas si la pelota se va al exterior de la curva (lateral p95), si el
## jugador la pisa (centro del cuerpo a menos de 0.25 m) o la deja atras.
func test_gentle_curves_at_speed() -> void:
	if _needs_render():
		return
	var slalom := func(t: float) -> float: return 25.0 * sin(TAU * t / 3.0)
	var slalom_sprint := func(t: float) -> float: return 20.0 * sin(TAU * t / 3.0)
	var arc := func(t: float) -> float: return 15.0 * maxf(t - 1.0, 0.0)
	var lane := func(_t: float) -> float: return 30.0
	# El zigzag de test_live_feet (joystick (0.8, +-0.6) cada 50 imagenes): giros de 74 grados, no una curva suave.
	var zigzag := func(t: float) -> float: return 36.87 if int(round(t * 60.0)) / 50 % 2 == 0 else -36.87
	var ahead := func(_t: float) -> float: return 0.0
	var cases := [
		["eslalon a la carrera (+-25 grados cada 3 s)", [[1.0, false, 6.0, slalom]], 0.0],
		["eslalon a sprint (+-20 grados cada 3 s)", [[1.0, true, 6.0, slalom_sprint]], 0.0],
		["arco a la carrera (15 grados/s)", [[1.0, false, 6.0, arc]], 7.0],
		["cambio de carril a la carrera (30 grados)", [[1.0, false, 1.5], [1.0, false, 0.8, lane], [1.0, false, 3.2, ahead]], 4.0],
		["zigzag a la carrera (+-37 grados cada 0.83 s)", [[1.0, false, 5.0, zigzag]], 0.0],
	]
	if OS.get_environment("DRIBBLE_CASE") != "":
		cases = cases.filter(func(c): return String(c[0]).begins_with(OS.get_environment("DRIBBLE_CASE")))
	# DRIBBLE_SEEDS=n: repite cada caso n veces (otra semilla del error del toque) y da la media: el resultado de una sola
	# pasada depende mucho del ruido.
	var seeds: int = maxi(int(OS.get_environment("DRIBBLE_SEEDS")), 1)
	for c in cases:
		if seeds > 1:
			var agg := {"lat_p95": 0.0, "clip": 0.0, "touches": 0.0, "none": 0.0, "miss": 0.0, "kept": 0.0}
			var worst := 0.0
			for k in seeds:
				var rk: Dictionary = await _phases(c[1], float(c[2]))
				agg["lat_p95"] += float(rk["lat_p95"]) / seeds
				agg["clip"] += float(rk["clip"]) / seeds
				agg["touches"] += float(rk["touches"]) / seeds
				agg["none"] += float(rk["none"]) / seeds
				agg["miss"] += float(rk["clip_miss"]) / seeds
				agg["kept"] += float(rk["kept"]) / seeds
				worst = maxf(worst, float(rk["lat_p95"]))
			note("%s (%d semillas): pelota al costado p95 media %.2f m (peor %.2f), toques %.1f (de clip %.1f, fallidos %.1f, sin pie %.1f), pelota cerca %d %%" % [
				c[0], seeds, agg["lat_p95"], worst, agg["touches"], agg["clip"], agg["miss"], agg["none"], int(agg["kept"] * 100.0)])
			check(agg["kept"] > 0.9, "%s: la pelota sigue con el jugador" % c[0])
			continue
		var r: Dictionary = await _phases(c[1], float(c[2]))
		_report(String(c[0]), r)
		note("   pelota al costado p95 %.2f m, encima de la pelota %d %%, pelota atras %d %%" % [r["lat_p95"], int(float(r["over"]) * 100.0), int(float(r["behind"]) * 100.0)])
		if OS.get_environment("TOUCH_LOG") != "":
			note("   balanceos descartados por el plan: %s; en modo curva %d %% del tiempo" % [r["rejects"], int(float(r["curving"]) * 100.0)])
			if OS.get_environment("TOUCH_LOG") >= "2" and String(c[0]).begins_with(OS.get_environment("DRIBBLE_LOG_CASE")):
				for ln in r["timeline"]:
					note("     " + ln)
		check(float(r["kept"]) > 0.9, "%s: la pelota sigue con el jugador (%d %%)" % [c[0], int(float(r["kept"]) * 100.0)])
