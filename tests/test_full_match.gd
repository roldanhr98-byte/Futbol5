extends TestCase
## Partidos REALES con reloj (3 y 5 minutos de juego), IA contra IA con arqueros, arbitro, bandas, balon parado y
## repeticion de cada gol: el partido termina con el pitazo final, no se traba, nadie se sale y cada gol tiene su
## repeticion (que se ve y despues devuelve el partido exactamente como estaba).

func _scene(minutes: float) -> MatchScene:
	PackLibrary.reload()
	var m: MatchScene = load("res://scenes/main/match.tscn").instantiate()
	m.duration_seconds = minutes * 60.0
	m.intro_seconds = 0.0
	m.auto_switch = false
	spawn(m)
	await physics_frames(3)
	m.home[0].input_source = AIInput.new(3, 0.6)
	m.home[0].is_human_controlled = false
	m.controlled = null
	for f in m.home + m.away:
		if f.input_source is AIInput:
			(f.input_source as AIInput).rng.seed = 7700 + f.actor_id * 17 + int(minutes)
	return m

func _play_full(m: MatchScene, max_real_minutes: float) -> Dictionary:
	var counts := {}
	m.ctx.event_emitted.connect(func(e: GameEvent) -> void: counts[e.type_name()] = int(counts.get(e.type_name(), 0)) + 1)
	var still: float = 0.0
	var worst_still: float = 0.0
	var out := 0
	var replay_frames := 0
	var hl: float = m.pitch.config.half_length() + m.pitch.config.run_off + 0.5
	var hw: float = m.pitch.config.half_width() + m.pitch.config.run_off + 0.5
	var frames: int = int(max_real_minutes * 60.0 * 60.0)
	for i in frames:
		await tree.physics_frame
		if m.replay.playing:
			replay_frames += 1
			continue
		if m.manager.state == MatchManager.State.FULL_TIME:
			break
		if m.manager.state == MatchManager.State.PLAYING and m.ball.linear_velocity.length() < 0.6 and not m.ball.is_held():
			still += 1.0 / 60.0
		else:
			still = 0.0
		worst_still = maxf(worst_still, still)
		if i % 60 == 0:
			for f in m.home + m.away:
				if absf(f.global_position.x) > hl or absf(f.global_position.z) > hw:
					out += 1
	return {"counts": counts, "worst_still": worst_still, "out": out, "replay_frames": replay_frames}

func _report(m: MatchScene, r: Dictionary, minutes: int) -> void:
	var c: Dictionary = r["counts"]
	note("%d min: marcador %s, reloj %s, estado %d | goles %d, repeticiones %d (%d fotogramas de repeticion) | pases %d, tiros %d, atajadas %d, faltas %d, fueras %d, balon parado %d | pelota quieta max %.1f s" % [
		minutes, str(m.manager.score), MatchManager.format_clock(m.ctx.match_time), m.manager.state, int(c.get("GOAL", 0)),
		m.replay.replays_shown, r["replay_frames"], int(c.get("PASS", 0)), int(c.get("SHOT", 0)), int(c.get("SAVE", 0)),
		int(c.get("FOUL", 0)), int(c.get("OUT_OF_PLAY", 0)), int(c.get("SET_PIECE", 0)) + int(c.get("OUT_OF_PLAY", 0)), r["worst_still"]])
	note("balon parado por tipo: %s" % str(m.manager.stats))

func test_three_minute_match_is_played_to_the_final_whistle_with_goal_replays() -> void:
	var m: MatchScene = await _scene(3.0)
	var r: Dictionary = await _play_full(m, 7.0)
	_report(m, r, 3)
	var c: Dictionary = r["counts"]
	check(m.manager.state == MatchManager.State.FULL_TIME, "el partido de 3 minutos termina con el pitazo final")
	check(int(c.get("MATCH_END", 0)) == 1, "un solo final de partido")
	check(m.ctx.match_time >= 180.0, "se juegan los 3 minutos (%.1f s)" % m.ctx.match_time)
	check(int(c.get("PASS", 0)) >= 10, "hay juego de pases (%d)" % int(c.get("PASS", 0)))
	check(int(c.get("SHOT", 0)) >= 2, "hay tiros (%d)" % int(c.get("SHOT", 0)))
	check(m.replay.replays_shown == int(c.get("GOAL", 0)), "cada gol tiene su repeticion (%d goles, %d repeticiones)" % [int(c.get("GOAL", 0)), m.replay.replays_shown])
	if int(c.get("GOAL", 0)) > 0:
		check(r["replay_frames"] > 60, "las repeticiones se reproducen (%d fotogramas)" % r["replay_frames"])
	check(r["worst_still"] < 12.0, "la pelota no queda trabada (%.1f s)" % r["worst_still"])
	check(r["out"] == 0, "nadie se va fuera del area de juego (%d)" % r["out"])
	check(m.score_total_consistent(), "el marcador coincide con los goles")

func test_five_minute_match_with_rules_and_set_pieces() -> void:
	var m: MatchScene = await _scene(5.0)
	var r: Dictionary = await _play_full(m, 11.0)
	_report(m, r, 5)
	var c: Dictionary = r["counts"]
	check(m.manager.state == MatchManager.State.FULL_TIME, "el partido de 5 minutos termina")
	check(m.ctx.match_time >= 300.0, "se juegan los 5 minutos")
	var restarts: int = int(c.get("OUT_OF_PLAY", 0)) + int(c.get("SET_PIECE", 0))
	check(restarts >= 1, "hay pelotas fuera / balon parado y se reanudan (%d)" % restarts)
	check(m.replay.replays_shown == int(c.get("GOAL", 0)), "repeticion por gol (%d/%d)" % [m.replay.replays_shown, int(c.get("GOAL", 0))])
	check(r["worst_still"] < 12.0, "sin atascos (%.1f s)" % r["worst_still"])

