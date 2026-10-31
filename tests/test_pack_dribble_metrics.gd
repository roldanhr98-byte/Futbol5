extends TestCase
## Metricas reproducibles de conduccion y de ejecucion de pase/tiro a trote, carrera y sprint.
## Compara en la MISMA ejecucion el camino antiguo (Tripo + patada procedural) y el del pack (patada con clip).
## No ajusta nada para pasar: las cotas son minimos de jugabilidad y los numeros reales salen en el log (note).
##
## ANTES/DESPUES. La fila TRIPO usa la patada procedural y la fila PACK la patada con clip, pero AMBAS llevan ya la
## correccion de conduccion (error del toque sobre la velocidad relativa, hueco acotado, umbral de re-toque). Los numeros
## de la conduccion ORIGINAL, medidos con este mismo protocolo antes de corregirla, estan en
## docs/technical-index/CHANGELOG.md: carrera 36 % / sprint 31 % de tiempo con la pelota a 0.35-1.5 m (64 % / 69 % lejos).

## Sistema del modo 1 (pack de Mixamo / Tripo), descartado como modo de juego pero todavia en el codigo: se prueba en su modo.
func gameplay_mode() -> int:
	return 1

const SEEDS := [101, 202, 303, 404]
const WARMUP := 0.8
const WINDOW := 2.7
const MODES := [
	{"name": "trote", "stick": Vector2(0.7, 0.0), "sprint": false},
	{"name": "carrera", "stick": Vector2(1.0, 0.0), "sprint": false},
	{"name": "sprint", "stick": Vector2(1.0, 0.0), "sprint": true},
]

func _skip_if_missing() -> bool:
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("no existe assets/animations/pack_clips.res (generar con tools/animation_pack/build_pack_library.tscn)")
		return true
	return false

func _legacy(on: bool) -> void:
	FootballerVisual.prefer_pack = not on
	BallHandler.clip_kicks_enabled = not on

## Corre conduciendo hacia +X. Si press es &"pass"/&"shot", pulsa el boton en press_at s y devuelve que ocurrio.
func _run(mode: Dictionary, seed_value: int, press: StringName = &"", press_at: float = 1.6) -> Dictionary:
	var ctx: MatchContext = await make_match(Vector3(-18.3, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-19.0, 0.0, 0.0), 50, src, true)
	p.ball_handler.rng.seed = seed_value
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	await physics_frames(10)
	var events: Array = []
	ctx.event_emitted.connect(func(e: GameEvent) -> void: events.append(e))
	src.move = mode["stick"]
	src.sprint = mode["sprint"]
	var fwd: Array[float] = []
	var lat: Array[float] = []
	var dist: Array[float] = []
	var total: float = WARMUP + WINDOW
	var t: float = 0.0
	var pressed := false
	var result := &""
	var steps: int = int(total * 60.0)
	for i in steps:
		await tree.physics_frame
		t += 1.0 / 60.0
		if press != &"" and not pressed and t >= press_at:
			pressed = true
			if press == &"pass":
				src.hold_pass()
			else:
				src.hold_shoot()
		elif press != &"" and pressed and result == &"" and t >= press_at + 0.04:
			if press == &"pass":
				src.release_pass()
			else:
				src.release_shoot()
			result = &"released"
		if t >= WARMUP:
			var off: Vector3 = p.ball_handler.ball_offset()
			var f: Vector3 = p.locomotion.forward()
			fwd.append(off.dot(f))
			lat.append(off.dot(p.locomotion.right()))
			dist.append(off.length())
	var outcome := &"none"
	if press != &"":
		var want: int = GameEvent.Type.PASS if press == &"pass" else GameEvent.Type.SHOT
		outcome = &"not_executed"
		for e in events:
			if e.type == want:
				outcome = &"executed"
		if outcome != &"executed":
			for e in events:
				if e.type == GameEvent.Type.KICK_WHIFF:
					outcome = StringName(String(e.data.get("reason", "whiff")))
	return {"fwd": fwd, "lat": lat, "dist": dist, "outcome": outcome, "speed": p.locomotion.speed, "touches": p.ball_handler.dribble_touch_count, "stats": p.ball_handler.kick_stats, "log": p.ball_handler.kick_log.duplicate()}

static func _avg(arr: Array[float]) -> float:
	var t := 0.0
	for x in arr:
		t += x
	return t / maxf(arr.size(), 1)

static func _pct(arr: Array[float], q: float) -> float:
	if arr.is_empty():
		return 0.0
	var a: Array[float] = arr.duplicate()
	a.sort()
	return a[clampi(int(a.size() * q), 0, a.size() - 1)]

## near_max: distancia (m) hasta la que la pelota se considera controlada. A sprint el toque es deliberadamente mas
## largo (la pelota se empuja al espacio y el jugador la alcanza en la zancada siguiente), asi que el limite sube.
func _summ(runs: Array, near_max: float = 1.5) -> Dictionary:
	var fwd: Array[float] = []
	var lat: Array[float] = []
	var n := 0
	var near := 0
	var behind := 0
	var glued := 0
	var far := 0
	var touches := 0
	for r in runs:
		for i in r["dist"].size():
			var d: float = r["dist"][i]
			var fw: float = r["fwd"][i]
			n += 1
			fwd.append(fw)
			lat.append(absf(r["lat"][i]))
			if d < 0.35:
				glued += 1
			elif d > near_max:
				far += 1
			else:
				near += 1
			if fw < -0.2:
				behind += 1
		touches += r["touches"]
	return {"near": 100.0 * near / n, "far": 100.0 * far / n, "glued": 100.0 * glued / n, "behind": 100.0 * behind / n,
		"fwd_p10": _pct(fwd, 0.1), "fwd_med": _pct(fwd, 0.5), "fwd_p90": _pct(fwd, 0.9), "lat_med": _pct(lat, 0.5),
		"touches_per_s": float(touches) / (runs.size() * (WARMUP + WINDOW)), "speed": runs[0]["speed"]}

func _line(tag: String, mode: String, s: Dictionary) -> String:
	return "%-6s %-8s v=%.1f m/s | pelota controlada: %3.0f %% | lejos: %3.0f %% | pegada <0.35 m: %3.0f %% | detras: %3.0f %% | adelante p10/med/p90: %.2f/%.2f/%.2f m | lateral med %.2f m | toques/s %.2f" % [tag, mode, s["speed"], s["near"], s["far"], s["glued"], s["behind"], s["fwd_p10"], s["fwd_med"], s["fwd_p90"], s["lat_med"], s["touches_per_s"]]

func test_dribble_distribution_at_jog_run_and_sprint() -> void:
	if _skip_if_missing():
		return
	var rows := {}
	for legacy_mode in [true, false]:
		_legacy(legacy_mode)
		for mode in MODES:
			var runs: Array = []
			for sd in SEEDS:
				runs.append(await _run(mode, sd))
				cleanup()
				_legacy(legacy_mode)
			var s: Dictionary = _summ(runs, 1.7 if mode["name"] == "sprint" else 1.5)
			rows["%s/%s" % [legacy_mode, mode["name"]]] = s
			note(_line("TRIPO" if legacy_mode else "PACK", mode["name"], s))
	var j: Dictionary = rows["false/trote"]
	check(j["behind"] < 2.0 and j["glued"] < 2.0, "trote con pack: la pelota nunca queda atras ni pegada (atras %.1f %%, pegada %.1f %%)" % [j["behind"], j["glued"]])
	check(j["near"] > 90.0, "trote con pack: la pelota esta a distancia de control el %.0f %% del tiempo" % j["near"])
	check(rows["false/sprint"]["behind"] < 2.0, "sprint con pack: la pelota no queda atras (%.1f %%)" % rows["false/sprint"]["behind"])
	check(rows["false/carrera"]["near"] > 90.0, "carrera con pack: pelota controlada el %.0f %% del tiempo (> 90 %%)" % rows["false/carrera"]["near"])
	check(rows["false/sprint"]["near"] > 80.0, "sprint con pack: pelota al alcance de la zancada siguiente (< 1.7 m) el %.0f %% del tiempo (> 80 %%)" % rows["false/sprint"]["near"])

func test_pass_and_shot_execution_rate_per_speed() -> void:
	if _skip_if_missing():
		return
	for legacy_mode in [true, false]:
		_legacy(legacy_mode)
		for mode in MODES:
			for kind in [&"pass", &"shot"]:
				var counts := {}
				var dists: Array[float] = []
				var adjusts: Array[float] = []
				var lats: Array[float] = []
				var n := 0
				for sd in SEEDS:
					for press_at in [1.4, 1.9]:
						var r: Dictionary = await _run(mode, sd, kind, press_at)
						counts[r["outcome"]] = int(counts.get(r["outcome"], 0)) + 1
						n += 1
						for e in r["log"]:
							if e["result"] == &"contact":
								dists.append(e["foot_distance"])
								adjusts.append(e["adjust_m"])
								lats.append(e["latency"])
						cleanup()
						_legacy(legacy_mode)
				var ex: int = int(counts.get(&"executed", 0))
				var foot := ""
				if not dists.is_empty():
					foot = " | pie-pelota al golpear max %.3f m, media %.3f m | ajuste de zancada medio %.2f m | latencia media %.3f s" % [dists.max(), _avg(dists), _avg(adjusts), _avg(lats)]
				note("%-5s %-8s %-5s: ejecutados %d/%d (%.0f %%) | otros: %s%s" % ["TRIPO" if legacy_mode else "PACK", mode["name"], kind, ex, n, 100.0 * ex / n, str(counts), foot])
				if not legacy_mode:
					var floor_rate: float = 0.6 if mode["name"] == "sprint" else 0.8
					check(ex >= n * floor_rate, "con pack a %s el %s se ejecuta en al menos el %.0f %% de las pulsaciones (%d/%d)" % [mode["name"], kind, floor_rate * 100.0, ex, n])
					check(counts.get(&"missed", 0) == 0, "con pack a %s ninguna patada iniciada falla en el golpeo (missed=%d)" % [mode["name"], counts.get(&"missed", 0)])
					if not dists.is_empty():
						check(dists.max() <= Tuning.player.kick_contact_radius, "con pack a %s todo golpeo valido tiene el pie a <= %.2f m de la pelota (max %.3f)" % [mode["name"], Tuning.player.kick_contact_radius, dists.max()])
