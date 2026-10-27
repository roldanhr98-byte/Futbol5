extends TestCase
## Reacciones de presentacion conectadas a eventos reales del partido (gol, primer toque, saque) con los clips del pack
## y el respaldo de Tripo. Son SOLO animacion: no bloquean la entrada ni cambian el movimiento.

func _skip_if_missing() -> bool:
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("no existe assets/animations/pack_clips.res (generar con tools/animation_pack/build_pack_library.tscn)")
		return true
	return false

func _two_teams() -> Dictionary:
	var ctx: MatchContext = await make_match(Vector3(30.0, 0.11, 8.0))
	var a: Footballer = add_player(ctx, 0, Vector3(-5, 0, 0), 50, null, true)
	var b: Footballer = add_player(ctx, 1, Vector3(5, 0, 0), 50, null, true)
	await physics_frames(5)
	return {"ctx": ctx, "a": a, "b": b}

func _goal(ctx: MatchContext, team: int) -> void:
	ctx.emit_event(GameEvent.make(GameEvent.Type.GOAL, -1, team, {"assist": -1, "own_goal": false, "score": [1, 0]}))

func test_goal_makes_the_scoring_team_celebrate_and_the_other_one_mourn() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _two_teams()
	var ctx: MatchContext = s["ctx"]
	var a: Footballer = s["a"]
	var b: Footballer = s["b"]
	_goal(ctx, 0)
	check(not a.visual.is_action_playing(), "la reaccion no es instantanea: espera a que el jugador se detenga")
	await wait_seconds(0.6)
	var cel: Array = AnimationCatalog.FIELD[&"celebrate_team"]["pack"]
	var dej: Array = AnimationCatalog.FIELD[&"dejected"]["pack"]
	note("tras el gol: equipo 0 reproduce '%s', equipo 1 reproduce '%s'" % [a.visual.current_action, b.visual.current_action])
	check(cel.has(a.visual.current_action), "el equipo que marca celebra con un clip del pack")
	check(dej.has(b.visual.current_action), "el equipo que recibe se lamenta con un clip del pack")
	check(a.visual._action_timer <= Footballer.REACTION_MAX_SECONDS + 0.01, "la reaccion se recorta a %.1f s (queda %.2f s)" % [Footballer.REACTION_MAX_SECONDS, a.visual._action_timer])
	check(ctx.input_enabled, "la reaccion no bloquea la entrada por si misma")
	await _goal_cleanup(a, b)

func _goal_cleanup(a: Footballer, b: Footballer) -> void:
	a.ctx.emit_event(GameEvent.make(GameEvent.Type.KICKOFF, -1, 0))
	await tree.physics_frame
	check(not a.visual.is_action_playing() and not b.visual.is_action_playing(), "el saque corta cualquier reaccion en curso")

func test_own_goal_scorer_is_on_the_conceding_team() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _two_teams()
	var ctx: MatchContext = s["ctx"]
	ctx.emit_event(GameEvent.make(GameEvent.Type.GOAL, s["b"].actor_id, 0, {"assist": -1, "own_goal": true, "score": [1, 0]}))
	await wait_seconds(0.6)
	check(AnimationCatalog.FIELD[&"dejected"]["pack"].has(s["b"].visual.current_action), "el autor de un gol en contra no celebra: se lamenta (%s)" % s["b"].visual.current_action)

func test_reaction_waits_for_a_running_player_to_slow_down() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _two_teams()
	var ctx: MatchContext = s["ctx"]
	var a: Footballer = s["a"]
	(a.input_source as ScriptedInput).move = Vector2(1, 0)
	(a.input_source as ScriptedInput).sprint = true
	await wait_seconds(1.5)
	check(a.locomotion.speed > 4.0, "el jugador corre a sprint (%.1f m/s)" % a.locomotion.speed)
	ctx.input_enabled = false   # como en el estado GOAL del partido
	_goal(ctx, 0)
	await wait_seconds(0.5)
	var early_speed: float = a.locomotion.speed
	note("a los 0.5 s del gol: v=%.1f m/s, accion '%s'" % [early_speed, a.visual.current_action])
	if early_speed > Footballer.REACTION_START_SPEED:
		check(not a.visual.is_action_playing(), "aun corriendo, no se superpone un clip en el sitio")
	await wait_seconds(1.5)
	check(AnimationCatalog.FIELD[&"celebrate_team"]["pack"].has(a.visual.current_action) or a.visual.current_action == &"", "tras detenerse celebra (o ya termino): '%s'" % a.visual.current_action)

func test_slow_first_touch_plays_receive_and_fast_one_does_not() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _two_teams()
	var ctx: MatchContext = s["ctx"]
	var a: Footballer = s["a"]
	a.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	# Pelota que llega rodando al jugador parado.
	ctx.ball.reset_at(Vector3(-2.5, 0.11, 0.0), Vector3(-5.5, 0.0, 0.0))
	var got := {"first_touch": false, "action": &""}
	ctx.event_emitted.connect(func(e: GameEvent) -> void:
		if e.type == GameEvent.Type.FIRST_TOUCH and e.actor_id == a.actor_id:
			got["first_touch"] = true)
	for i in 120:
		await tree.physics_frame
		if got["first_touch"]:
			got["action"] = a.visual.current_action
			break
	check(got["first_touch"], "el jugador controla la pelota que le llega")
	check(got["action"] == &"Receive", "primer toque lento: gesto de recepcion del pack (%s)" % got["action"])
	# Un primer toque a velocidad de carrera no se anima (el cuerpo ya corre).
	a.visual.stop_current_action()
	a.locomotion.velocity = Vector3(4.0, 0.0, 0.0)
	a.locomotion.speed = 4.0
	ctx.emit_event(GameEvent.make(GameEvent.Type.FIRST_TOUCH, a.actor_id, 0, {}))
	check(not a.visual.is_action_playing(), "primer toque corriendo: sin gesto de recepcion")

func test_kick_cancels_a_reaction_and_actions_never_overlap() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _two_teams()
	var a: Footballer = s["a"]
	a.visual.play_situation(&"celebrate", 0, 1.0, 2.0)
	check(a.visual.is_action_playing(), "arranca la celebracion")
	var d: float = a.visual.play_pack_clip(&"Soccer_Pass", 1.5, 0.15, 0.5)
	check(d > 0.0 and a.visual.current_action == &"Soccer_Pass", "una patada sustituye a la celebracion (una sola accion a la vez)")

func test_tripo_fallback_for_goal_reactions_and_no_invented_receive() -> void:
	FootballerVisual.prefer_pack = false
	var s: Dictionary = await _two_teams()
	var ctx: MatchContext = s["ctx"]
	var a: Footballer = s["a"]
	var b: Footballer = s["b"]
	_goal(ctx, 0)
	await wait_seconds(0.6)
	check(a.visual.current_action == &"celebrate_goal", "sin pack celebra con el clip de Tripo (%s)" % a.visual.current_action)
	check(b.visual.current_action == &"dejected", "sin pack se lamenta con el clip de Tripo (%s)" % b.visual.current_action)
	a.visual.stop_current_action()
	ctx.emit_event(GameEvent.make(GameEvent.Type.FIRST_TOUCH, a.actor_id, 0, {}))
	check(not a.visual.is_action_playing(), "no hay clip de recepcion de Tripo: no se inventa uno")
