extends TestCase
## Reglas con bandas: la pelota que cruza una linea se repone con saque de banda, corner o saque de arco; una falta
## da tiro libre o penal. Cada saque lo ejecuta un clip con su raiz real (throw_in, Chip, strike_foward_jog,
## soccer_penalty_kick, goalkeeper_placing_ball) y el juego se reanuda solo cuando la pelota sale del pie o las manos.

func _scene() -> MatchScene:
	PackLibrary.reload()
	var m: MatchScene = load("res://scenes/main/match.tscn").instantiate()
	m.duration_seconds = 0.0
	m.auto_switch = false
	m.intro_seconds = 0.0
	spawn(m)
	await physics_frames(3)
	# Todos con IA: el saque lo decide la maquina (la persona no toca nada en estas pruebas).
	m.home[0].input_source = AIInput.new(3, 0.6)
	m.home[0].is_human_controlled = false
	m.controlled = null
	await wait_seconds(1.5)
	return m

## Pone la pelota justo fuera de la cancha, tocada por ultima vez por `toucher`.
func _send_out(m: MatchScene, pos: Vector3, toucher: Node) -> void:
	m.ball.reset_at(pos)
	m.ball.register_touch(toucher)
	await physics_frames(3)

func _wait_resume(m: MatchScene, seconds: float) -> bool:
	for i in int(seconds * 60.0):
		await tree.physics_frame
		if m.manager.state == MatchManager.State.PLAYING:
			return true
	return false

func test_ball_over_the_sideline_gives_a_throw_in_taken_with_the_hands() -> void:
	var m: MatchScene = await _scene()
	var hw: float = m.pitch.config.half_width()
	var events: Array = []
	m.ctx.event_emitted.connect(func(e: GameEvent) -> void: events.append(e))
	var away_toucher: Footballer = m.away[0]
	await _send_out(m, Vector3(3.0, 0.11, hw + 0.4), away_toucher)
	check(m.manager.state == MatchManager.State.SET_PIECE, "la pelota fuera por la banda detiene el juego")
	check(m.manager.set_piece_kind == "throw_in", "es saque de banda (%s)" % m.manager.set_piece_kind)
	check(m.manager.set_piece_team == 0, "saca el rival del ultimo que la toco (equipo %d)" % m.manager.set_piece_team)
	var sp: SetPiece = m.manager.active_set_piece
	check(sp != null and sp.taker.team == 0, "hay ejecutor del equipo que saca")
	if sp == null:
		return
	check(m.ball.is_held() and m.ball.holder == sp.taker, "el ejecutor sostiene la pelota con las manos")
	var release_y: float = -1.0
	var was_held := true
	for i in 6 * 60:
		await tree.physics_frame
		if was_held and not m.ball.is_held():
			release_y = m.ball.global_position.y
			was_held = false
		if m.manager.state == MatchManager.State.PLAYING:
			break
	note("saque de banda: clip %s, resultado %s, la pelota sale de las manos a %.2f m de altura" % [sp.clip, sp.result, release_y])
	check(m.manager.state == MatchManager.State.PLAYING, "el juego se reanuda tras el saque")
	check(sp.clip == &"throw_in" or not m.home[0].visual.uses_pack, "se usa el clip throw_in")
	check(release_y > 1.2, "la pelota sale por encima de la cabeza (%.2f m)" % release_y)
	var thrown: bool = events.any(func(e: GameEvent) -> bool: return e.type == GameEvent.Type.PASS and e.data.get("set_piece", "") == "throw_in")
	check(thrown, "queda registrado como saque de banda")

func test_byline_by_attacker_is_a_goal_kick_and_the_keeper_places_and_plays_it() -> void:
	var m: MatchScene = await _scene()
	var hl: float = m.pitch.config.half_length()
	var k1: Goalkeeper = m.keepers[1]
	# El equipo 0 ataca +X: la saca por el fondo del arco +X un atacante del equipo 0 -> saque de arco del equipo 1.
	await _send_out(m, Vector3(hl + 0.4, 0.11, 5.0), m.home[1])
	check(m.manager.set_piece_kind == "goal_kick" and m.manager.set_piece_team == 1, "saque de arco del defensor (%s, equipo %d)" % [m.manager.set_piece_kind, m.manager.set_piece_team])
	check(k1.state == Goalkeeper.State.GOAL_KICK, "el arquero hace el saque")
	var clip: StringName = k1._gk_clip
	var resumed: bool = await _wait_resume(m, 9.0)
	note("saque de arco: clip %s, distribuciones %d" % [clip, k1.stats["distributions"]])
	check(resumed, "el juego se reanuda tras el saque de arco")
	check(clip in [&"goalkeeper_placing_ball", &"goalkeeper_placing_ball_2"], "el arquero coloca la pelota con su clip (%s)" % clip)
	check(k1.goal_kick_done and m.ball.last_toucher == k1, "la pelota la juega el arquero")

func test_byline_by_defender_is_a_corner_crossed_with_a_run_up() -> void:
	var m: MatchScene = await _scene()
	var hl: float = m.pitch.config.half_length()
	await _send_out(m, Vector3(hl + 0.4, 0.11, -6.0), m.away[0])
	check(m.manager.set_piece_kind == "corner" and m.manager.set_piece_team == 0, "corner para el atacante (%s, equipo %d)" % [m.manager.set_piece_kind, m.manager.set_piece_team])
	var sp: SetPiece = m.manager.active_set_piece
	check(sp != null, "hay ejecutor del corner")
	if sp == null:
		return
	# Jugada ensayada: atacantes en el area.
	var in_box: int = 0
	for f in m.home:
		if f != sp.taker and absf(f.global_position.x - hl) < 9.0 and absf(f.global_position.z) < 6.0:
			in_box += 1
	check(in_box >= 2, "los atacantes van al area (%d)" % in_box)
	# Rivales a distancia del punto del corner.
	var min_d: float = INF
	for f in m.away:
		min_d = minf(min_d, Vector2(f.global_position.x - sp.spot.x, f.global_position.z - sp.spot.z).length())
	check(min_d >= 4.9, "los rivales respetan la distancia (%.1f m)" % min_d)
	var resumed: bool = await _wait_resume(m, 6.0)
	note("corner: accion %s, clip %s, resultado %s, pelota a %.1f m/s" % [sp.action, sp.clip, sp.result, m.ball.linear_velocity.length()])
	check(resumed, "el corner se ejecuta y se reanuda el juego")
	check(sp.result == &"contact", "el pie del clip llega a la pelota (%s)" % sp.result)
	check(sp.action == &"cross", "el corner es un centro (%s)" % sp.action)

func test_foul_inside_the_area_is_a_penalty_from_the_mark() -> void:
	var m: MatchScene = await _scene()
	var hl: float = m.pitch.config.half_length()
	var victim: Footballer = m.home[1]
	var fouler: Footballer = m.away[1]
	victim.place_at(Vector3(hl - 3.0, 0.0, 1.0), 0.0)
	await physics_frames(2)
	m.ctx.emit_event(GameEvent.make(GameEvent.Type.FOUL, fouler.actor_id, 1, {"victim": victim.actor_id, "pos": [hl - 3.0, 1.0]}))
	await physics_frames(2)
	check(m.manager.set_piece_kind == "penalty", "falta dentro del area: penal (%s)" % m.manager.set_piece_kind)
	var mark_x: float = hl - m.pitch.config.penalty_mark_distance
	check_near(m.manager.set_piece_pos.x, mark_x, 0.01, "desde el punto penal")
	var sp: SetPiece = m.manager.active_set_piece
	var k1: Goalkeeper = m.keepers[1]
	var shots := []
	m.ctx.event_emitted.connect(func(e: GameEvent) -> void:
		if e.type == GameEvent.Type.SHOT:
			shots.append(e))
	var keeper_depth: float = absf(k1.global_position.x - hl)
	var resumed: bool = await _wait_resume(m, 6.0)
	note("penal: clip %s, resultado %s, arquero a %.2f m de su linea al patear, disparos %d" % [sp.clip if sp != null else "-", sp.result if sp != null else "-", keeper_depth, shots.size()])
	check(resumed, "el penal se ejecuta")
	check(keeper_depth < 0.6, "el arquero espera en la linea (%.2f m)" % keeper_depth)
	check(shots.size() == 1, "el penal es un disparo")
	if sp != null and m.home[0].visual.uses_pack:
		check(String(sp.clip).begins_with("soccer_penalty_kick"), "con el clip de penal con carrera (%s)" % sp.clip)

func test_foul_outside_the_area_is_a_free_kick_and_opponents_keep_distance() -> void:
	var m: MatchScene = await _scene()
	var fouler: Footballer = m.away[2]
	m.ctx.emit_event(GameEvent.make(GameEvent.Type.FOUL, fouler.actor_id, 1, {"victim": m.home[2].actor_id, "pos": [-2.0, 3.0]}))
	await wait_seconds(1.0)
	check(m.manager.set_piece_kind == "free_kick", "falta en el medio: tiro libre (%s)" % m.manager.set_piece_kind)
	var min_d: float = INF
	for f in m.away:
		min_d = minf(min_d, Vector2(f.global_position.x + 2.0, f.global_position.z - 3.0).length())
	check(min_d >= 4.5, "los rivales a distancia del tiro libre (%.1f m)" % min_d)
	check(await _wait_resume(m, 6.0), "el tiro libre se ejecuta y el juego sigue")

## Durante todo el saque (colocacion, espera y carrera) nadie salvo el ejecutor entra en la zona de la carrerilla
## (SetPiece.CLEAR_RADIUS alrededor de la pelota): ni companeros ofreciendose ni rivales. Antes el apoyo corto de la IA se
## acercaba a 1.9 m de la pelota y se metia en la carrera del ejecutor, que se desviaba y no llegaba a la pelota.
func test_nobody_but_the_taker_enters_the_run_up_zone() -> void:
	var cases := [["tiro libre en el medio", "fk", Vector2(-2.0, 3.0)], ["tiro libre cerca del area", "fk", Vector2(10.5, -2.0)],
		["corner", "corner", Vector2.ZERO]]
	for c in cases:
		var m: MatchScene = await _scene()
		var hl: float = m.pitch.config.half_length()
		if c[1] == "fk":
			m.ctx.emit_event(GameEvent.make(GameEvent.Type.FOUL, m.away[2].actor_id, 1, {"victim": m.home[2].actor_id, "pos": [c[2].x, c[2].y]}))
		else:
			await _send_out(m, Vector3(hl + 0.4, 0.11, -6.0), m.away[0])
		await physics_frames(1)
		var sp: SetPiece = m.manager.active_set_piece
		check(sp != null, "%s: hay ejecutor" % c[0])
		if sp == null:
			cleanup()
			continue
		var closest: float = INF
		var who: String = ""
		for k in 8 * 60:
			if m.manager.state == MatchManager.State.PLAYING or sp.resolved:
				break
			for f in m.ctx.footballers:
				if f == sp.taker:
					continue
				var d: float = Vector2(f.global_position.x - sp.spot.x, f.global_position.z - sp.spot.z).length()
				if d < closest:
					closest = d
					who = "%s (%s)" % [f.name, "companero" if f.team == sp.team else "rival"]
			await tree.physics_frame
		note("%s: el mas cercano a la pelota durante el saque, %s a %.2f m; resultado %s" % [c[0], who, closest, sp.result])
		check(closest >= SetPiece.CLEAR_RADIUS - 0.15, "%s: nadie en la carrerilla (%s a %.2f m)" % [c[0], who, closest])
		check(sp.result == &"contact", "%s: el pie del ejecutor llega a la pelota (%s)" % [c[0], sp.result])
		cleanup()
