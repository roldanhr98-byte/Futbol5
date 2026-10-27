extends TestCase
## Repeticion de goles: congela el partido, muestra la jugada con su camara en camara lenta y lo devuelve tal cual.

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

## Repeticion forzada: un gol de tiro, la repeticion congela el partido, muestra la jugada y lo deja como estaba.
func test_goal_replay_shows_the_play_and_restores_the_match() -> void:
	var m: MatchScene = await _scene(0.0)
	await wait_seconds(3.0)
	var shooter: Footballer = m.home[1]
	var hl: float = m.pitch.config.half_length()
	# El arquero se aparta para que el gol sea seguro (la prueba es de la repeticion, no de la atajada).
	var k1: Goalkeeper = m.keepers[1]
	k1.process_mode = Node.PROCESS_MODE_DISABLED
	k1.global_position = Vector3(hl - 0.5, 0.0, 4.0)
	m.ball.reset_at(Vector3(hl - 4.0, 0.3, 0.0), Vector3(14.0, 0.5, 0.4))
	await physics_frames(2)
	m.ball.register_touch(shooter)
	var goal_seen := false
	for i in 240:
		await tree.physics_frame
		if m.manager.state == MatchManager.State.GOAL:
			goal_seen = true
			break
	check(goal_seen, "hay gol")
	var started := false
	for i in 200:
		await tree.physics_frame
		if m.replay.playing:
			started = true
			break
	check(started, "tras el festejo empieza la repeticion")
	if not started:
		return
	check(get_tree_paused(), "durante la repeticion el partido esta congelado")
	check(m.replay.camera.current, "con su propia camara")
	# Estado del momento en que empezo: se compara al terminar.
	var before: Vector3 = m.replay._restore["ball"][0]
	var p_before: Vector3 = (m.replay._restore["actors"][1] as Array)[0]
	var ball_track: Array = []
	for i in 900:
		await tree.physics_frame
		if not m.replay.playing:
			break
		if i % 15 == 0:
			ball_track.append(m.ball.global_position)
	note("repeticion: %d fotogramas, pelota recorrida en la repeticion de x=%.1f a x=%.1f" % [m.replay.last_played_frames, (ball_track[0] as Vector3).x if not ball_track.is_empty() else 0.0, (ball_track[-1] as Vector3).x if not ball_track.is_empty() else 0.0])
	check(not m.replay.playing, "la repeticion termina")
	check(not get_tree_paused(), "el partido se reanuda")
	check(ball_track.size() >= 4 and (ball_track[-1] as Vector3).x > (ball_track[0] as Vector3).x + 3.0, "la repeticion muestra la pelota yendo al arco")
	check(m.ball.global_position.distance_to(before) < 0.05, "la pelota vuelve a donde estaba")
	check(m.home[1].global_position.distance_to(p_before) < 0.05, "los jugadores vuelven a donde estaban")
	check(m.camera.current, "vuelve la camara de juego")

func get_tree_paused() -> bool:
	return tree.paused

func test_any_button_skips_the_replay() -> void:
	var m: MatchScene = await _scene(0.0)
	await wait_seconds(2.0)
	var k1: Goalkeeper = m.keepers[1]
	k1.process_mode = Node.PROCESS_MODE_DISABLED
	var hl: float = m.pitch.config.half_length()
	k1.global_position = Vector3(hl - 0.5, 0.0, 4.0)
	m.ball.reset_at(Vector3(hl - 4.0, 0.3, 0.0), Vector3(14.0, 0.5, 0.4))
	await physics_frames(2)
	m.ball.register_touch(m.home[1])
	var skipped := [false]
	m.replay.finished.connect(func(s: bool) -> void: skipped[0] = s)
	for i in 400:
		await tree.physics_frame
		if m.replay.playing:
			break
	check(m.replay.playing, "la repeticion esta en marcha")
	await physics_frames(20)
	Input.action_press("pass")
	await physics_frames(3)
	Input.action_release("pass")
	check(not m.replay.playing and skipped[0], "PASE la salta")
	check(not tree.paused, "y el partido sigue")
