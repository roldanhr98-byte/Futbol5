extends TestCase
## Acciones de cuerpo completo del jugador de campo con clips del pack: barrida con contacto real del pie, caidas y
## levantarse, todo movido por la raiz del clip. Se omite sin la libreria local del pack.

func _skip_if_missing() -> bool:
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("no existe assets/animations/pack_clips.res (ver tools/animation_pack/build_pack_library.tscn)")
		return true
	return false

func _two(ball_pos: Vector3) -> Dictionary:
	var ctx: MatchContext = await make_match(ball_pos)
	var da: ScriptedInput = ScriptedInput.new()
	var defender: Footballer = add_player(ctx, 1, Vector3(-4.0, 0.0, 0.0), 50, da, true)
	defender.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	var carrier: Footballer = add_player(ctx, 0, Vector3(0.0, 0.0, 0.0), 50, ScriptedInput.new(), true)
	carrier.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	await physics_frames(5)
	return {"ctx": ctx, "d": defender, "c": carrier, "in": da}

func test_fall_moves_the_body_with_the_clip_root_and_gets_up_without_input() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _two(Vector3(30.0, 0.11, 8.0))
	var c: Footballer = s["c"]
	var start: Vector3 = c.global_position
	c.actions.suffer_contact(&"trip", Vector3(-1, 0, 0))
	check(c.actions.active(), "la zancadilla inicia una accion")
	await wait_seconds(0.5)
	check(c.actions.kind == &"fall" and c.visual.is_action_playing(), "cae con el clip del pack (%s)" % c.visual.current_action)
	var moved: float = c.global_position.distance_to(start)
	await wait_seconds(7.0)
	check(not c.actions.active() and c.actions.kind == &"", "termina de levantarse sola y recupera el control")
	note("la caida desplazo al jugador %.2f m con la raiz del clip" % c.global_position.distance_to(start))
	check(moved > 0.1 or c.global_position.distance_to(start) > 0.3, "el cuerpo se mueve con la raiz del clip")

func test_slide_tackle_resolves_by_where_the_foot_actually_is() -> void:
	if _skip_if_missing():
		return
	var slides := 0
	var wins := 0
	var fouls := 0
	var recoveries := 0
	var duels := 16
	for seed_i in duels:
		# El portador conduce hacia +X y el defensor sale a su encuentro (hacia -X) presionando.
		var ctx: MatchContext = await make_match(Vector3(-5.6, 0.11, 0.0))
		var din := ScriptedInput.new()
		var d: Footballer = add_player(ctx, 1, Vector3(9.0, 0.0, 0.3), 50, din, true)
		var cin := ScriptedInput.new()
		var c: Footballer = add_player(ctx, 0, Vector3(-6.3, 0.0, 0.0), 50, cin, true)
		d.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(-1, 0, 0))
		c.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
		d.actions.rng.seed = 500 + seed_i
		d.ball_handler.rng.seed = 900 + seed_i
		await physics_frames(5)
		cin.move = Vector2(1, 0)      # el portador conduce
		din.move = Vector2(-1, 0)
		din.sprint = true
		din.press_held = true         # el defensor presiona
		for i in 600:
			await tree.physics_frame
			if d.actions.stats["slides"] > 0 and not d.actions.active():
				break
			if absf(c.global_position.x) > 17.0:
				break
		slides += int(d.actions.stats["slides"])
		wins += int(d.actions.stats["slide_wins"])
		fouls += int(d.actions.stats["slide_fouls"])
		if d.actions.stats["slides"] > 0:
			await wait_seconds(0.4)
			recoveries += 1 if not d.actions.active() else 0
		cleanup()
	note("%d persecuciones: barridas=%d, balon ganado=%d, faltas=%d, se levanto despues=%d" % [duels, slides, wins, fouls, recoveries])
	check(slides >= 1, "el defensor se lanza a barrer en alguna ocasion (%d)" % slides)
	check(recoveries == slides, "tras cada barrida se levanta y recupera el control (%d de %d)" % [recoveries, slides])

func test_defender_marks_facing_the_carrier_and_uses_the_directional_blend() -> void:
	if _skip_if_missing():
		return
	var ctx: MatchContext = await make_match(Vector3(0.7, 0.11, 0.0))
	var din := ScriptedInput.new()
	var d: Footballer = add_player(ctx, 1, Vector3(3.5, 0.0, 0.0), 50, din, true)
	var c: Footballer = add_player(ctx, 0, Vector3(0.0, 0.0, 0.0), 50, ScriptedInput.new(), true)
	c.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	d.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))   # mira para otro lado
	await physics_frames(5)
	din.press_held = true
	din.move = Vector2(0, 0.6)    # joystick de lado
	await wait_seconds(0.8)
	var to_c: Vector3 = KickModel.flat(c.global_position - d.global_position)
	var ang: float = KickModel.angle_between_deg(d.locomotion.forward(), to_c)
	note("jockey: angulo cuerpo-portador %.1f grados, velocidad (adelante %.2f, lateral %.2f) m/s, direccional=%s" % [ang, d.locomotion.forward_speed, d.locomotion.lateral_speed, str(d.visual.directional)])
	check(d.locomotion.jockeying and d.visual.directional, "marca en jockey con la mezcla direccional")
	check(ang < 35.0, "el cuerpo mira al portador (%.1f grados)" % ang)
	check(absf(d.locomotion.lateral_speed) > 0.4, "se desplaza de lado sin girar el cuerpo (lateral %.2f m/s)" % d.locomotion.lateral_speed)

func test_skill_spin_protects_the_carrier_and_keeps_the_ball_close() -> void:
	if _skip_if_missing():
		return
	var ctx: MatchContext = await make_match(Vector3(-8.3, 0.11, 0.0))
	var src := ScriptedInput.new()
	var c: Footballer = add_player(ctx, 0, Vector3(-9.0, 0.0, 0.0), 50, src, true)
	c.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	await physics_frames(5)
	src.move = Vector2(0.8, 0)
	await wait_seconds(1.2)
	check(c.ball_handler.has_possession(), "conduce la pelota antes del regate")
	src.skill()
	await physics_frames(3)
	check(c.actions.kind == &"skill", "el regate arranca la ruleta (%s)" % c.actions.kind)
	var worst := 0.0
	var steps := 0
	while c.actions.active() and steps < 240:
		await tree.physics_frame
		steps += 1
		worst = maxf(worst, c.ball_handler.ball_distance())
	note("ruleta: %.2f s, la pelota se alejo como maximo %.2f m del jugador" % [steps / 60.0, worst])
	check(steps > 30, "la ruleta dura un tiempo visible (%d pasos)" % steps)
	check(worst < 3.2, "la pelota no se pierde durante la ruleta (max %.2f m)" % worst)
