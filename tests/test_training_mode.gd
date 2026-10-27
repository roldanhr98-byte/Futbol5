extends TestCase
## Modo entrenamiento: tu equipo (4 + arquero) contra el arquero rival SOLO. Se juega sin rivales de campo ni reloj:
## hay pases, tiros al arco y atajadas, los saques los hace tu equipo (salvo el saque de arco del arquero rival) y la
## pelota no se traba.

func test_training_has_only_my_team_and_the_rival_keeper() -> void:
	PackLibrary.reload()
	MatchScene.training_mode = true
	var m: MatchScene = load("res://scenes/main/match.tscn").instantiate()
	m.auto_switch = false
	spawn(m)
	await physics_frames(3)
	MatchScene.training_mode = false
	check(m.away.is_empty(), "sin rivales de campo (%d)" % m.away.size())
	check(m.home.size() == 4, "tu equipo completo (%d)" % m.home.size())
	check(m.keepers.size() == 2, "los dos arqueros (%d)" % m.keepers.size())
	check(m.manager.duration_seconds == 0.0, "sin reloj que termine")
	check(m.hud._pause_buttons.has("training"), "el menu de pausa tiene el boton de entrenamiento")
	# La IA maneja a todo el equipo para jugar solo (el resultado es el mismo que con la persona: no hay rivales).
	m.home[0].input_source = AIInput.new(3, 0.6)
	m.home[0].is_human_controlled = false
	m.controlled = null
	var counts := {}
	m.ctx.event_emitted.connect(func(e: GameEvent) -> void: counts[e.type_name()] = int(counts.get(e.type_name(), 0)) + 1)
	var still := 0.0
	var worst := 0.0
	var set_piece_teams := {}
	m.manager.set_piece_requested.connect(func(kind: String, team: int, _p: Vector3) -> void: set_piece_teams["%s/%d" % [kind, team]] = true)
	for i in 150 * 60:
		await tree.physics_frame
		if m.replay.playing:
			continue
		if m.manager.state == MatchManager.State.PLAYING and m.ball.linear_velocity.length() < 0.6 and not m.ball.is_held():
			still += 1.0 / 60.0
		else:
			still = 0.0
		worst = maxf(worst, still)
	note("150 s de entrenamiento: eventos %s | marcador %s | saques %s | pelota quieta max %.1f s" % [str(counts), str(m.manager.score), str(set_piece_teams.keys()), worst])
	check(m.manager.state != MatchManager.State.FULL_TIME, "el entrenamiento no termina solo")
	check(int(counts.get("PASS", 0)) >= 5, "hay pases (%d)" % int(counts.get("PASS", 0)))
	# Llegadas al arco: tiros, goles y pelotas que el arquero ataja o se lleva en el mano a mano (sin rivales la IA suele
	# llegar hasta el arquero, que sale a achicar, en vez de tirar de lejos).
	var attempts: int = int(counts.get("SHOT", 0)) + int(counts.get("GOAL", 0)) + int(counts.get("SAVE", 0))
	check(attempts >= 3, "hay llegadas al arco (%d: tiros %d, goles %d, atajadas %d)" % [attempts, int(counts.get("SHOT", 0)), int(counts.get("GOAL", 0)), int(counts.get("SAVE", 0))])
	check(int(counts.get("KEEPER_DISTRIBUTE", 0)) >= 1 or int(counts.get("SAVE", 0)) == 0, "el arquero rival devuelve la pelota al juego")
	check(worst < 12.0, "la pelota no se traba (%.1f s)" % worst)
	for k in set_piece_teams.keys():
		check(String(k).ends_with("/0") or String(k).begins_with("goal_kick"), "saque %s: lo hace tu equipo o el arquero rival" % k)
