extends TestCase
## Partido completo 4 + arquero contra 4 + arquero con IA en ambos equipos (el humano no toca nada): comprueba que se
## juega de verdad (hay pases, tiros, atajadas, robos), que nadie se sale ni se queda trabado y que la pelota circula.

func _scene(duration: float) -> MatchScene:
	var packed: PackedScene = load("res://scenes/main/match.tscn")
	var m: MatchScene = packed.instantiate()
	m.duration_seconds = duration
	m.auto_switch = false
	spawn(m)
	await physics_frames(3)
	return m

func test_ai_teams_play_a_real_match_without_getting_stuck() -> void:
	PackLibrary.reload()
	var m: MatchScene = await _scene(0.0)
	# Los 8 jugadores de campo los lleva la IA: esta prueba mide como juega la IA, no que pasa si la persona no toca
	# el mando (eso lo cubre test_idle_human_carrier_loses_the_ball_to_the_press).
	m.home[0].input_source = AIInput.new(3, 0.6)
	m.home[0].is_human_controlled = false
	for f in m.home + m.away:
		if f.input_source is AIInput:
			(f.input_source as AIInput).rng.seed = 4400 + f.actor_id
	# El limite se toma al empezar: con la resistencia agotada max_sprint_speed() baja y dejaria de ser comparable.
	var speed_limit: float = m.home[0].locomotion.max_sprint_speed() + 0.3
	var counts := {}
	m.ctx.event_emitted.connect(func(e: GameEvent) -> void: counts[e.type_name()] = int(counts.get(e.type_name(), 0)) + 1)
	var ball_far := 0
	var total := 0
	var out_of_bounds := 0
	var travelled := {}
	var last_pos := {}
	var max_speed := 0.0
	var half_l: float = m.pitch.config.half_length()
	var half_w: float = m.pitch.config.width * 0.5
	var secs: int = 120
	for i in secs * 60:
		await tree.physics_frame
		total += 1
		if i % 30 == 0:
			for f in m.home + m.away:
				# Tras un gol el autor puede quedar dentro de la red festejando: solo cuenta el juego en marcha.
				if m.manager.state == MatchManager.State.PLAYING and (absf(f.global_position.x) > half_l + 1.0 or absf(f.global_position.z) > half_w + 1.0):
					out_of_bounds += 1
				# Una accion de cuerpo completo (barrida, caida) mueve el cuerpo con la raiz del clip y puede superar
				# la velocidad de carrera: no es locomocion y no cuenta para este limite.
				if not f.actions.active():
					max_speed = maxf(max_speed, f.locomotion.speed)
		if i % 30 == 0:
			for f in m.home + m.away:
				var key: int = f.actor_id
				if last_pos.has(key):
					travelled[key] = float(travelled.get(key, 0.0)) + (last_pos[key] as Vector3).distance_to(f.global_position)
				last_pos[key] = f.global_position
	note("120 s de partido 4+1 vs 4+1: eventos=%s | marcador=%s" % [str(counts), str(m.manager.score)])
	for k in m.keepers:
		note("arquero equipo %d: %s" % [k.team, str(k.stats)])
	check(int(counts.get("PASS", 0)) >= 2, "hay pases (%d)" % int(counts.get("PASS", 0)))
	check(int(counts.get("SHOT", 0)) >= 1, "hay tiros (%d)" % int(counts.get("SHOT", 0)))
	check(int(counts.get("KICK_WHIFF", 0)) <= 2 * (int(counts.get("PASS", 0)) + int(counts.get("SHOT", 0))) + 2, "la IA acierta al menos un tercio de sus patadas (%d falsas, %d acertadas)" % [int(counts.get("KICK_WHIFF", 0)), int(counts.get("PASS", 0)) + int(counts.get("SHOT", 0))])
	check(int(counts.get("TACKLE_WON", 0)) + int(counts.get("TACKLE_FAILED", 0)) >= 1, "hay disputas de pelota")
	check(out_of_bounds == 0, "nadie se sale de la cancha mas de 1 m (%d muestras fuera)" % out_of_bounds)
	check(max_speed <= speed_limit, "nadie supera la velocidad de sprint (%.2f m/s, limite %.2f)" % [max_speed, speed_limit])
	var idle_players: Array = []
	for f in m.home + m.away:
		if f != m.controlled and float(travelled.get(f.actor_id, 0.0)) < 40.0:
			idle_players.append("%d (%.0f m)" % [f.actor_id, float(travelled.get(f.actor_id, 0.0))])
	note("distancia recorrida por la IA en 120 s: %s" % str(travelled.values().map(func(v: float) -> int: return int(v))))
	check(idle_players.is_empty(), "todos los jugadores de IA se mueven (menos de 40 m en 120 s: %s)" % str(idle_players))
	var k0: Goalkeeper = m.keepers[0]
	var k1: Goalkeeper = m.keepers[1]
	check(k0.stats["shots_faced"] + k1.stats["shots_faced"] >= 1, "los arqueros enfrentan disparos")

func test_each_team_wears_its_own_kit() -> void:
	var m: MatchScene = await _scene(0.0)
	var home_c: Color = m.home[0].visual.kit_material.get_shader_parameter("jersey_color")
	var away_c: Color = m.away[0].visual.kit_material.get_shader_parameter("jersey_color")
	check(home_c.is_equal_approx(FootballerVisual.default_kit(0)["jersey"]), "el equipo local usa su camiseta")
	check(away_c.is_equal_approx(FootballerVisual.default_kit(1)["jersey"]), "el visitante usa su camiseta (no la del local)")
	check(not home_c.is_equal_approx(away_c), "los dos equipos se distinguen por el color")

## Partidos de IA contra IA con semillas distintas: la pelota nunca queda trabada en un barullo ni en una esquina, la IA
## solo dispara con angulo de arco util y no patea al aire la mayor parte de las veces.
func test_ai_matches_never_deadlock_and_shoot_from_sensible_places() -> void:
	PackLibrary.reload()
	var worst_still: float = 0.0
	var acc := {"shots": 0, "bad_shots": 0, "kicks": 0, "whiffs": 0}
	for seed_i in 3:
		var m: MatchScene = await _scene(0.0)
		m.home[0].input_source = AIInput.new(3, 0.6)
		m.home[0].is_human_controlled = false
		for f in m.home + m.away:
			if f.input_source is AIInput:
				(f.input_source as AIInput).rng.seed = 1300 + seed_i * 23 + f.actor_id
		var half_goal: float = m.pitch.config.half_goal()
		var half_l: float = m.pitch.config.half_length()
		m.ctx.event_emitted.connect(func(e: GameEvent) -> void:
			var kind: String = e.type_name()
			if kind == "SHOT":
				acc["shots"] += 1
				acc["kicks"] += 1
				var bp: Vector3 = m.ball.global_position
				if absf(bp.x) > half_l:
					return   # patada ya con la pelota dentro del arco (el gol acaba de ocurrir): no cuenta
				var gx: float = half_l * (1.0 if e.team == 0 else -1.0)
				var a := Vector3(gx, 0.0, half_goal) - Vector3(bp.x, 0.0, bp.z)
				var b := Vector3(gx, 0.0, -half_goal) - Vector3(bp.x, 0.0, bp.z)
				# El angulo se mide con la pelota donde esta al patear (unos centimetros de margen por el balanceo).
				# Desde la linea de fondo solo vale entre los postes (empujar la pelota adentro); fuera de ellos o con el arco
				# casi de canto es un disparo imposible.
				if rad_to_deg(a.angle_to(b)) < 8.0 or (absf(bp.x) > half_l - 0.5 and absf(bp.z) > half_goal):
					acc["bad_shots"] += 1
			elif kind == "PASS":
				acc["kicks"] += 1
			elif kind == "KICK_WHIFF":
				acc["whiffs"] += 1)
		var still: float = 0.0
		for i in 120 * 60:
			await tree.physics_frame
			if m.ball.linear_velocity.length() < 0.6 and not m.ball.is_held() and m.manager.state == MatchManager.State.PLAYING:
				still += 1.0 / 60.0
			else:
				still = 0.0
			worst_still = maxf(worst_still, still)
		cleanup()
	note("3 partidos de 120 s: pelota quieta max %.1f s, tiros %d (desde angulo cerrado: %d), patadas %d, al aire %d" % [worst_still, acc["shots"], acc["bad_shots"], acc["kicks"], acc["whiffs"]])
	check(worst_still < 12.0, "la pelota no queda trabada (maximo %.1f s quieta en juego)" % worst_still)
	check(int(acc["bad_shots"]) == 0, "ningun tiro sale desde la linea de fondo o un angulo imposible (%d de %d)" % [acc["bad_shots"], acc["shots"]])
	check(float(acc["whiffs"]) <= 0.45 * float(int(acc["kicks"]) + int(acc["whiffs"])), "la IA no patea al aire la mayoria de las veces (%d al aire de %d intentos)" % [acc["whiffs"], int(acc["kicks"]) + int(acc["whiffs"])])


## Si la persona suelta el mando con la pelota, el juego no se congela: el jugador protege el balon con el cuerpo
## (control cercano), pero el rival que presiona rodea el cuerpo y acaba disputandoselo.
func test_idle_human_carrier_loses_the_ball_to_the_press() -> void:
	PackLibrary.reload()
	var m: MatchScene = await _scene(0.0)
	var human: Footballer = m.home[0]
	var kept: float = 0.0
	var lost_at: float = -1.0
	for i in 60 * 60:
		await tree.physics_frame
		if m.manager.state != MatchManager.State.PLAYING:
			continue
		if human.ball_handler.has_possession():
			kept += 1.0 / 60.0
		elif kept > 0.5 and lost_at < 0.0:
			lost_at = kept
			break
	note("el jugador parado conservo la pelota %.1f s antes de que la presion se la quitara" % kept)
	check(lost_at > 0.4, "proteger el balon parado le da tiempo (%.1f s)" % kept)
	check(lost_at >= 0.0 and lost_at < 30.0, "pero la presion rival acaba quitandosela (%.1f s)" % kept)
