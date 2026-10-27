extends TestCase
## Flujo de partido: saque, gol por cruce completo de linea, marcador, reinicios, fin de tiempo.

func _make_scene(duration: float = 0.0, keepers: bool = false) -> MatchScene:
	var scene: PackedScene = load("res://scenes/main/match.tscn")
	var m: MatchScene = scene.instantiate()
	m.duration_seconds = duration
	m.home_field_players = 1
	m.away_field_players = 0
	m.intro_seconds = 0.0
	m.with_referee = false
	m.with_keepers = keepers   # estas pruebas son de reglas: el arquero se prueba en test_goalkeeper
	spawn(m)
	await physics_frames(3)
	return m

func test_match_starts_with_kickoff_then_plays() -> void:
	var m: MatchScene = await _make_scene()
	check(m.manager.state == MatchManager.State.PRE_KICKOFF, "arranca en saque")
	check(not m.ctx.input_enabled, "la entrada esta bloqueada antes del saque")
	check(m.ball.global_position.distance_to(Vector3(0, 0.11, 0)) < 0.5, "la pelota esta en el centro")
	await wait_seconds(1.4)
	check(m.manager.state == MatchManager.State.PLAYING, "pasa a juego")
	check(m.ctx.input_enabled, "la entrada se habilita")
	await wait_seconds(2.0)
	check(m.ctx.match_time > 1.5, "el reloj avanza (%.2f s)" % m.ctx.match_time)

func test_goal_updates_score_stats_and_restarts_kickoff() -> void:
	var m: MatchScene = await _make_scene()
	await wait_seconds(1.5)
	var events: Array = []
	m.ctx.event_emitted.connect(func(e: GameEvent) -> void: events.append(e))
	var goals: Array = []
	m.manager.goal_scored.connect(func(team: int, scorer: int, assist: int, own: bool) -> void: goals.append([team, scorer, assist, own]))
	# El jugador local toca la pelota y esta sale hacia el arco +X.
	m.ball.register_touch(m.controlled)
	m.ball.reset_at(Vector3(17.0, 0.15, 0.0))
	await physics_frames(5)
	m.ball.register_touch(m.controlled)
	m.ball.kick(Vector3(20, 0.5, 0), Vector3.ZERO, m.controlled)
	await wait_seconds(1.5)
	check(m.manager.score[0] == 1 and m.manager.score[1] == 0, "marcador 1-0 (%s)" % [m.manager.score])
	check(goals.size() == 1, "se emite un unico gol")
	if goals.size() == 1:
		check(goals[0][0] == 0 and goals[0][1] == m.controlled.actor_id and not goals[0][3], "goleador correcto y no es en contra")
		check(goals[0][2] == -1, "sin asistencia ficticia (no hay companeros)")
	check(m.manager.state == MatchManager.State.GOAL, "estado de celebracion")
	var goal_events: int = 0
	for e in events:
		if e.type == GameEvent.Type.GOAL:
			goal_events += 1
	check(goal_events == 1, "evento GOAL registrado una vez")
	await wait_seconds(3.5)
	check(m.manager.state == MatchManager.State.PRE_KICKOFF or m.manager.state == MatchManager.State.PLAYING, "vuelve al saque tras la celebracion")
	check(m.manager.kickoff_team == 1, "saca el equipo que recibio el gol")
	check(m.ball.global_position.distance_to(Vector3(0, 0.11, 0)) < 1.5, "la pelota vuelve al centro (%s)" % m.ball.global_position)

func test_ball_on_the_line_without_crossing_is_no_goal() -> void:
	var m: MatchScene = await _make_scene()
	await wait_seconds(1.5)
	m.ball.reset_at(Vector3(19.95, 0.15, 0.0))
	await wait_seconds(0.3)
	m.ball.freeze = true
	await wait_seconds(0.5)
	check(m.manager.score[0] == 0, "con el centro antes de cruzar la linea no hay gol")

func test_own_goal_is_credited_to_the_opponent() -> void:
	var m: MatchScene = await _make_scene()
	await wait_seconds(1.5)
	var goals: Array = []
	m.manager.goal_scored.connect(func(team: int, _s: int, _a: int, own: bool) -> void: goals.append([team, own]))
	# El jugador local (equipo 0) manda la pelota a SU propio arco (-X).
	m.ball.reset_at(Vector3(-17.0, 0.15, 0.0))
	await physics_frames(5)
	m.ball.kick(Vector3(-20, 0.5, 0), Vector3.ZERO, m.controlled)
	await wait_seconds(1.5)
	check(m.manager.score[1] == 1 and m.manager.score[0] == 0, "gol en contra suma al rival (%s)" % [m.manager.score])
	check(goals.size() == 1 and goals[0][1] == true, "marcado como gol en contra")

func test_restart_play_keeps_score_and_restart_match_resets_it() -> void:
	var m: MatchScene = await _make_scene()
	await wait_seconds(1.5)
	m.ball.register_touch(m.controlled)
	m.ball.reset_at(Vector3(17.0, 0.15, 0.0))
	await physics_frames(3)
	m.ball.kick(Vector3(22, 0.5, 0), Vector3.ZERO, m.controlled)
	await wait_seconds(1.2)
	check(m.manager.score[0] == 1, "hay un gol")
	m.manager.restart_play()
	await wait_seconds(0.2)
	check(m.manager.score[0] == 1, "reiniciar la jugada conserva el marcador")
	check(m.ball.global_position.distance_to(Vector3(0, 0.11, 0)) < 1.0, "la pelota vuelve al centro")
	m.manager.restart_match()
	await wait_seconds(0.2)
	check(m.manager.score[0] == 0 and m.manager.score[1] == 0, "reiniciar el partido pone el marcador a 0-0")
	check(is_equal_approx(m.ctx.match_time, 0.0) or m.ctx.match_time < 0.5, "y el reloj a 0 (%.2f)" % m.ctx.match_time)

func test_pause_and_full_time() -> void:
	var m: MatchScene = await _make_scene(3.0)
	await wait_seconds(1.5)
	m.manager.toggle_pause()
	check(m.manager.state == MatchManager.State.PAUSED and tree.paused, "pausa detiene el arbol")
	var t0: float = m.ctx.match_time
	await physics_frames(30)
	check(is_equal_approx(m.ctx.match_time, t0), "el reloj no avanza en pausa")
	m.manager.toggle_pause()
	check(m.manager.state == MatchManager.State.PLAYING and not tree.paused, "reanuda")
	await wait_seconds(3.5)
	check(m.manager.state == MatchManager.State.FULL_TIME, "termina el partido al cumplirse la duracion")
	check(not m.ctx.input_enabled, "sin entrada al terminar")

func test_full_scene_has_a_keeper_per_team_and_a_goal_still_counts_when_the_keeper_is_beaten() -> void:
	var m: MatchScene = await _make_scene(0.0, true)
	await wait_seconds(1.5)
	check(m.keepers.size() == 2 and m.ctx.keeper_defending(0) != null and m.ctx.keeper_defending(1) != null, "un arquero por equipo, registrados en el contexto")
	check(m.ctx.keeper_defending(1).global_position.x > 18.0, "el arquero rival esta en su arco")
	# Tiro a quemarropa al angulo fuera de alcance: gol aunque haya arquero.
	m.ball.register_touch(m.controlled)
	m.ball.reset_at(Vector3(19.0, 1.9, 1.35))
	await physics_frames(5)
	m.ball.kick(Vector3(14, 0.2, 0.3), Vector3.ZERO, m.controlled)
	await wait_seconds(1.2)
	check(m.manager.score[0] == 1, "gol con el arquero en el arco (%s)" % [m.manager.score])
