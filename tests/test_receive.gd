extends TestCase
## F3 — Recepcion y control de pelota con clips (JsonReceive + JsonBallMove, modo 4). Una pelota rodando llega al jugador:
## el clip se elige antes de que llegue, el pie del clip la toca en su instante de toque, la pelota solo cambia de velocidad
## en ese toque (Ball.kick) y la recepcion pasa por ActionArbiter (nivel de movimiento con pelota). Semillas fijas en el
## azar del jugador (BallHandler.rng). Headless: el toque usa la punta del pie de los datos; la medida con el pie animado
## esta en test_live_foot_meets_the_ball (solo con render).

const ME := Vector3(0.0, 0.0, 0.0)
const FACE := Vector3(1, 0, 0)

func _skip_if_missing() -> bool:
	if not ResourceLoader.exists(PackLibrary.JSON_FIELD_PATH):
		skip("no existe assets/animations/json_clips.res")
		return true
	return false

func _mode4() -> void:
	Tuning.gameplay_mode = 4
	PackLibrary.reload()

func _restore() -> void:
	Tuning.gameplay_mode = 1
	PackLibrary.reload()

## Escena: un jugador en ME mirando a +X (con un compañero a +X a 8 m para los pases), la pelota sale rodando desde `ang`
## grados (respecto al frente, + izquierda) a `dist` m, apuntada adonde estara el jugador. run: joystick de marcha previa
## hacia +X; stick: joystick durante la recepcion (coordenadas de pantalla = x, z del mundo).
func _setup(ang: float, spd: float, seed: int, run: float = 0.0, stick: Vector2 = Vector2.ZERO, dist: float = 6.0, rival: bool = false, lat: float = 0.0) -> Dictionary:
	_mode4()
	var from: Vector3 = FACE.rotated(Vector3.UP, deg_to_rad(ang))
	var start: Vector3 = ME + from * dist
	var ctx: MatchContext = await make_match(start + Vector3(0, 0.11, 0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, ME, 60, src, true)
	var mate: Footballer = add_player(ctx, 0, ME + Vector3(8.0, 0.0, 3.0), 60, ScriptedInput.new(), true)
	if rival:
		add_player(ctx, 1, ME + Vector3(-1.5, 0.0, 1.2), 60, ScriptedInput.new(), true)
	p.locomotion.yaw = Locomotion.yaw_from_dir(FACE)
	p.ball_handler.rng.seed = seed
	await physics_frames(3)
	if run > 0.0:
		src.move = Vector2(run, 0.0)
		await physics_frames(40)
	var t_arrive: float = start.distance_to(p.global_position) / spd
	var aim: Vector3 = p.global_position + p.velocity * t_arrive + Vector3(-from.z, 0.0, from.x) * lat
	var dir: Vector3 = KickModel.flat(aim - start).normalized()
	ctx.ball.kick(dir * spd, ctx.ball.rolling_spin(dir * spd), null)
	if stick != Vector2.ZERO:
		src.move = stick
	return {"ctx": ctx, "p": p, "src": src, "mate": mate}

## Sigue la escena `frames` pasos y mide: clip de recepcion, paso del toque, historia de la pelota (posicion y velocidad),
## velocidad del jugador y estado del arbitro. stop_after: pasos tras el toque (0 = todos los `frames`).
func _run(s: Dictionary, frames: int, stop_after: int = 0) -> Dictionary:
	var ctx: MatchContext = s["ctx"]
	var p: Footballer = s["p"]
	var rv: JsonReceive = p.ball_handler.receive
	var r := {"clip": &"", "start": -1, "contact": -1, "bpos": [], "bvel": [], "pspeed": [], "levels": [], "plan": {}, "planned_ft": 0, "physical_ft": 0}
	ctx.event_emitted.connect(func(e: GameEvent) -> void:
		if e.type == GameEvent.Type.FIRST_TOUCH and e.actor_id == p.actor_id:
			if e.data.get("planned", false):
				r["planned_ft"] += 1
			else:
				r["physical_ft"] += 1)
	for i in frames:
		await tree.physics_frame
		if r["start"] < 0 and p.ball_handler.json_move.active and p.ball_handler.json_move.intent == &"receive":
			r["start"] = i
			r["clip"] = p.ball_handler.json_move.clip
			r["plan"] = rv.last_plan.duplicate()
		if r["contact"] < 0 and rv.stats["contact"] > 0:
			r["contact"] = i
		(r["bpos"] as Array).append(ctx.ball.global_position)
		(r["bvel"] as Array).append(ctx.ball.linear_velocity)
		(r["pspeed"] as Array).append(p.locomotion.speed)
		(r["levels"] as Array).append(p.arbiter.level)
		if stop_after > 0 and r["contact"] >= 0 and i >= int(r["contact"]) + stop_after:
			break
	return r

func _ball_dist(s: Dictionary) -> float:
	return KickModel.flat((s["ctx"] as MatchContext).ball.global_position - (s["p"] as Footballer).global_position).length()

# --- Situaciones de recepcion -----------------------------------------------------------------------------------------

func test_standing_receiver_controls_with_a_clip_whose_foot_meets_the_ball() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _setup(0.0, 12.0, 11)
	var r: Dictionary = await _run(s, 150)
	var p: Footballer = s["p"]
	note("parado, pelota de frente a 12 m/s: clip %s, toque en el paso %d, pelota a %.2f m al final" % [r["clip"], r["contact"], _ball_dist(s)])
	check(r["contact"] >= 0 and JsonReceive.ROLES.has(StringName(PackLibrary.meta(r["clip"]).get("role", ""))), "recibe con un clip de recepcion (%s)" % r["clip"])
	check(r["planned_ft"] == 1 and r["physical_ft"] == 0, "un solo primer toque, el del clip (clip %d, fisico %d)" % [r["planned_ft"], r["physical_ft"]])
	check(_ball_dist(s) < 1.3 and (s["ctx"] as MatchContext).ball.linear_velocity.length() < 2.0, "la pelota queda controlada cerca (%.2f m)" % _ball_dist(s))
	check(p.ball_handler.has_possession(), "el jugador queda con la pelota")
	cleanup()
	_restore()

func test_walking_receiver_uses_a_clip_that_matches_its_pace() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _setup(45.0, 11.0, 12, 0.25)
	var speed0: float = (s["p"] as Footballer).locomotion.speed
	var r: Dictionary = await _run(s, 150)
	var m: Dictionary = PackLibrary.meta(r["clip"]) if r["clip"] != &"" else {}
	note("caminando a %.2f m/s, pelota a 45 grados: clip %s (carrera de entrada %.2f m/s), toque en el paso %d" % [speed0, r["clip"], float(m.get("v_in", -1.0)), r["contact"]])
	check(speed0 > 0.6, "el jugador camina al llegar la pelota (%.2f m/s)" % speed0)
	check(r["contact"] >= 0, "recibe caminando con un clip")
	check(float(r["plan"].get("dv", 99.0)) <= JsonReceive.MAX_DV, "la carrera de entrada del clip es la del jugador (diferencia %.2f m/s)" % float(r["plan"].get("dv", -1.0)))
	check(_ball_dist(s) < 1.3, "la pelota queda controlada (%.2f m)" % _ball_dist(s))
	cleanup()
	_restore()

## Trotando o corriendo no hay clip de recepcion a ras de piso con esa carrera de entrada (todos empiezan a <= 1 m/s): no se
## fuerza ninguno; recibe el control fisico de siempre, sin frenar en seco.
func _moving_without_compatible_clip(run: float, label: String) -> void:
	var s: Dictionary = await _setup(30.0, 11.0, 13, run, Vector2(run, 0.0))
	var p: Footballer = s["p"]
	var speed0: float = p.locomotion.speed
	var r: Dictionary = await _run(s, 150)
	var dv: float = float(r["plan"].get("dv", 0.0))
	var min_speed: float = 99.0
	for i in mini((r["pspeed"] as Array).size(), 60):
		min_speed = minf(min_speed, float(r["pspeed"][i]))
	note("%s a %.2f m/s: clip %s, primer toque fisico %d, del clip %d, velocidad minima %.2f m/s, pelota a %.2f m" % [label, speed0, r["clip"], r["physical_ft"], r["planned_ft"], min_speed, _ball_dist(s)])
	check(r["clip"] == &"" or dv <= JsonReceive.MAX_DV, "no se fuerza un clip de otra carrera (%s, diferencia %.2f)" % [r["clip"], dv])
	check(r["physical_ft"] + r["planned_ft"] >= 1, "la pelota se controla igual (primer toque)")
	check(min_speed > speed0 * 0.4, "no frena en seco para recibir (minimo %.2f de %.2f m/s)" % [min_speed, speed0])

func test_jogging_receiver_is_not_forced_into_an_incompatible_clip() -> void:
	if _skip_if_missing():
		return
	await _moving_without_compatible_clip(0.6, "trotando")
	cleanup()
	_restore()

func test_running_receiver_is_not_forced_into_an_incompatible_clip() -> void:
	if _skip_if_missing():
		return
	await _moving_without_compatible_clip(1.0, "corriendo")
	cleanup()
	_restore()

func test_ball_from_the_side_is_received_with_the_foot_on_that_side() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _setup(-90.0, 12.0, 14)
	var r: Dictionary = await _run(s, 150)
	var p: Footballer = s["p"]
	var contact_ball: Vector3 = r["bpos"][r["contact"]] if r["contact"] >= 0 else Vector3.ZERO
	var side: float = KickModel.flat(contact_ball - ME).dot(FACE.rotated(Vector3.UP, deg_to_rad(-90.0)))
	note("pelota de costado (derecha): clip %s, toque en el paso %d, pelota en el toque a %.2f m hacia ese lado; final a %.2f m" % [r["clip"], r["contact"], side, _ball_dist(s)])
	check(r["contact"] >= 0, "recibe la pelota que llega de costado con un clip")
	check(side > 0.0, "el toque es del lado por donde llega la pelota (%.2f m)" % side)
	check(_ball_dist(s) < 1.3 and p.ball_handler.has_possession(), "la pelota queda controlada (%.2f m)" % _ball_dist(s))
	cleanup()
	_restore()

## Control orientado: con el joystick hacia un lado el clip sale hacia alli (rumbo de salida del clip) y la pelota tambien.
func _oriented(stick_ang: float) -> void:
	var sd: Vector3 = FACE.rotated(Vector3.UP, deg_to_rad(stick_ang))
	var s: Dictionary = await _setup(0.0, 12.0, 15, 0.0, Vector2(sd.x, sd.z))
	var r: Dictionary = await _run(s, 110)
	var p: Footballer = s["p"]
	var ok_clip: bool = r["contact"] >= 0
	var moved: float = 0.0
	if ok_clip and int(r["contact"]) + 30 < (r["bpos"] as Array).size():
		moved = KickModel.flat((r["bpos"][int(r["contact"]) + 30] as Vector3) - (r["bpos"][r["contact"]] as Vector3)).dot(sd)
	var exit_dir: Vector3 = Locomotion.dir_from_yaw(float(r["plan"].get("yaw0", 0.0)) + deg_to_rad(float(r["plan"].get("turn", 0.0))))
	note("joystick a %+d grados: clip %s (giro %.0f grados), salida a %.0f grados del joystick, la pelota avanzo %.2f m hacia alli en 0.5 s; jugador mira a %.0f grados del joystick al final" % [int(stick_ang), r["clip"], float(r["plan"].get("turn", 0.0)), KickModel.angle_between_deg(exit_dir, sd), moved, KickModel.angle_between_deg(p.locomotion.forward(), sd)])
	check(ok_clip, "recibe con un clip de control orientado")
	check(KickModel.angle_between_deg(exit_dir, sd) <= JsonReceive.TURN_TOL, "el clip sale hacia el joystick")
	check(moved > 0.2, "la pelota sale hacia donde apunta el joystick (%.2f m)" % moved)

func test_oriented_control_to_the_left() -> void:
	if _skip_if_missing():
		return
	await _oriented(70.0)
	cleanup()
	_restore()

func test_oriented_control_to_the_right() -> void:
	if _skip_if_missing():
		return
	await _oriented(-70.0)
	cleanup()
	_restore()

# --- Continuidad -------------------------------------------------------------------------------------------------------

func test_reception_then_dribble() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _setup(0.0, 12.0, 16)
	var r: Dictionary = await _run(s, 120, 50)
	var p: Footballer = s["p"]
	var src: ScriptedInput = s["src"]
	var touches0: int = p.ball_handler.dribble_touch_count
	src.move = Vector2(0.0, 0.6)
	var far: float = 0.0
	for i in 150:
		await tree.physics_frame
		far = maxf(far, _ball_dist(s))
	var moved: float = p.global_position.z
	note("recepcion (%s) y luego conduccion hacia +Z: %d toques, %.2f m recorridos, pelota a como mucho %.2f m" % [r["clip"], p.ball_handler.dribble_touch_count - touches0, moved, far])
	check(r["contact"] >= 0, "primero recibe con un clip")
	check(moved > 1.5 and p.ball_handler.dribble_touch_count > touches0, "despues conduce con toques (%.2f m)" % moved)
	check(far < 1.6 and p.ball_handler.has_possession(), "sin perder la pelota (max %.2f m)" % far)
	cleanup()
	_restore()

## Golpeo pedido durante la cola del clip, despues del toque: corta la cola y sale el golpeo.
func _reception_then_kick(shot: bool) -> void:
	var s: Dictionary = await _setup(0.0, 12.0, 17)
	var r: Dictionary = await _run(s, 120, 3)
	var p: Footballer = s["p"]
	var src: ScriptedInput = s["src"]
	var started0: int = int(p.ball_handler.kick_stats["started"])
	var in_clip: bool = p.ball_handler.json_move.active
	var aim: Vector3 = KickModel.flat((s["mate"] as Footballer).global_position - p.global_position).normalized()
	src.move = Vector2(aim.x, aim.z)
	if shot:
		src.hold_shoot()
	else:
		src.hold_pass()
	await physics_frames(10)
	if shot:
		src.release_shoot()
	else:
		src.release_pass()
	var kicked_at: int = -1
	for i in 60:
		await tree.physics_frame
		if kicked_at < 0 and int(p.ball_handler.kick_stats["started"]) > started0:
			kicked_at = i
	var bv: float = (s["ctx"] as MatchContext).ball.linear_velocity.length()
	note("%s tras recibir (%s; en la cola del clip al pulsar: %s): golpeo %0.2f s despues de soltar, pelota a %.1f m/s, recepcion terminada: %s" % ["tiro" if shot else "pase", r["clip"], str(in_clip), float(kicked_at) / 60.0, bv, str(p.ball_handler.json_move.last.get("ended", p.ball_handler.json_move.last.get("aborted", "fin")))])
	check(r["contact"] >= 0 and in_clip, "el boton se pulsa con la recepcion en curso, despues del toque")
	check(kicked_at >= 0 and kicked_at <= 40, "el %s sale enseguida (%d pasos)" % ["tiro" if shot else "pase", kicked_at])
	check(p.arbiter.level == ActionArbiter.Level.NONE or p.arbiter.kind == &"kick", "la recepcion libero su lugar en el arbitro (%s)" % p.arbiter.kind)

func test_reception_then_pass() -> void:
	if _skip_if_missing():
		return
	await _reception_then_kick(false)
	cleanup()
	_restore()

func test_reception_then_shot() -> void:
	if _skip_if_missing():
		return
	await _reception_then_kick(true)
	cleanup()
	_restore()

# --- Arbitro (F2) ------------------------------------------------------------------------------------------------------

func test_a_fall_interrupts_a_reception_before_the_touch() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _setup(0.0, 12.0, 18)
	var p: Footballer = s["p"]
	var started := false
	for i in 90:
		await tree.physics_frame
		if p.ball_handler.json_move.active and p.ball_handler.json_move.intent == &"receive":
			started = true
			break
	check(started and p.arbiter.level == ActionArbiter.Level.BALL_MOVE, "la recepcion corre con el nivel de movimiento con pelota")
	p.actions.suffer_contact(&"trip", Vector3(-1, 0, 0))
	await physics_frames(2)
	note("falta durante la recepcion: arbitro %s (nivel %d), recepcion activa %s, toques del clip %d" % [p.arbiter.kind, p.arbiter.level, str(p.ball_handler.json_move.active), p.ball_handler.receive.stats["contact"]])
	check(p.arbiter.level == ActionArbiter.Level.FALL and p.actions.kind == &"fall", "la caida (nivel mayor) la interrumpe")
	check(not p.ball_handler.json_move.active and p.ball_handler.receive.stats["contact"] == 0, "la recepcion se corta del todo: no hay toque del clip")
	cleanup()
	_restore()

func test_no_reception_starts_during_a_fall() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _setup(0.0, 12.0, 19)
	var p: Footballer = s["p"]
	p.actions.suffer_contact(&"trip", Vector3(-1, 0, 0))
	var r: Dictionary = await _run(s, 60)
	note("pelota que llega a un jugador caido: recepciones %d, nivel del arbitro %d" % [p.ball_handler.receive.stats["started"], p.arbiter.level])
	check(p.ball_handler.receive.stats["started"] == 0 and r["clip"] == &"", "no empieza ninguna recepcion durante la caida")
	cleanup()
	_restore()

func test_no_reception_starts_during_a_set_piece() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _setup(0.0, 12.0, 20)
	var p: Footballer = s["p"]
	var clip: StringName = PackLibrary.by_role(&"throw_in")[0]
	var ok: bool = p.actions.start(&"set_piece", clip, 1.0)
	var r: Dictionary = await _run(s, 50)
	note("balon parado en curso (%s, %s): recepciones %d, nivel del arbitro %d" % [clip, str(ok), p.ball_handler.receive.stats["started"], p.arbiter.level])
	check(ok, "el balon parado empieza")
	check(p.ball_handler.receive.stats["started"] == 0 and r["clip"] == &"", "no empieza ninguna recepcion durante el balon parado")
	cleanup()
	_restore()

func test_reception_releases_the_arbiter_when_it_ends() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _setup(0.0, 12.0, 21)
	var p: Footballer = s["p"]
	var freed0: int = int(p.arbiter.stats["liberadas"])
	var r: Dictionary = await _run(s, 150)
	var held: int = 0
	for lv in r["levels"]:
		if int(lv) == ActionArbiter.Level.BALL_MOVE:
			held += 1
	note("recepcion %s: %d pasos con el nivel de movimiento con pelota; al terminar nivel %d, testigo %d, liberadas %d" % [r["clip"], held, p.arbiter.level, p.arbiter.token, int(p.arbiter.stats["liberadas"]) - freed0])
	check(r["contact"] >= 0 and held > 10, "la recepcion tomo el arbitro mientras duro")
	check(p.arbiter.level == ActionArbiter.Level.NONE and p.arbiter.token == 0 and not p.actions.active(), "al terminar no queda nada tomado")
	check(int(p.arbiter.stats["liberadas"]) > freed0, "se libero por su testigo")
	cleanup()
	_restore()

func test_no_orphan_pose_after_a_reception_or_an_aborted_one() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _setup(0.0, 12.0, 22)
	var p: Footballer = s["p"]
	var r: Dictionary = await _run(s, 150)
	var orphan_end: bool = p.visual.is_action_playing() and p.arbiter.level == ActionArbiter.Level.NONE
	cleanup()
	# Recepcion cortada: alguien desvia la pelota antes del toque.
	var s2: Dictionary = await _setup(0.0, 12.0, 23)
	var p2: Footballer = s2["p"]
	var ctx2: MatchContext = s2["ctx"]
	var started := false
	for i in 90:
		await tree.physics_frame
		if p2.ball_handler.json_move.active and p2.ball_handler.json_move.intent == &"receive":
			started = true
			break
	var other: Footballer = s2["mate"]
	ctx2.ball.kick(Vector3(0.0, 0.0, 6.0), ctx2.ball.rolling_spin(Vector3(0.0, 0.0, 6.0)), other)
	await physics_frames(3)
	var aborted: bool = not p2.ball_handler.json_move.active
	var orphan_abort: bool = p2.visual.is_action_playing() and p2.arbiter.level == ActionArbiter.Level.NONE
	note("al terminar (%s): pose sin dueno %s; recepcion desviada (empezo %s, cortada %s, motivo %s): pose sin dueno %s" % [r["clip"], str(orphan_end), str(started), str(aborted), str(p2.ball_handler.json_move.last.get("aborted", "")), str(orphan_abort)])
	check(not orphan_end, "terminada la recepcion no queda una pose sin dueno")
	check(started and aborted and p2.arbiter.level == ActionArbiter.Level.NONE, "la pelota desviada antes del toque corta la recepcion y libera el arbitro")
	check(not orphan_abort, "cortada la recepcion no queda una pose sin dueno")
	cleanup()
	_restore()

# --- Pelota fisica -----------------------------------------------------------------------------------------------------

func test_ball_is_never_teleported_and_only_changes_speed_at_the_touch() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _setup(30.0, 12.0, 24)
	var r: Dictionary = await _run(s, 120, 30)
	var dt: float = 1.0 / 60.0
	var jumps: int = 0
	var early_kicks: int = 0
	for i in range(1, (r["bpos"] as Array).size()):
		var step: float = ((r["bpos"][i] as Vector3) - (r["bpos"][i - 1] as Vector3)).length()
		var vmax: float = maxf((r["bvel"][i] as Vector3).length(), (r["bvel"][i - 1] as Vector3).length())
		if step > vmax * dt + 0.02:
			jumps += 1
		var dv: float = ((r["bvel"][i] as Vector3) - (r["bvel"][i - 1] as Vector3)).length()
		if r["contact"] >= 0 and i < int(r["contact"]) and dv > 0.4:
			early_kicks += 1
	note("recepcion %s: saltos de posicion %d, cambios bruscos de velocidad antes del toque %d (toque en el paso %d)" % [r["clip"], jumps, early_kicks, r["contact"]])
	check(r["contact"] >= 0, "hay recepcion con clip")
	check(jumps == 0, "la pelota nunca se teletransporta (%d saltos)" % jumps)
	check(early_kicks == 0, "antes del toque la pelota solo frena por su rodadura (%d cambios bruscos)" % early_kicks)
	cleanup()
	_restore()

func test_touch_happens_at_the_clip_contact_instant_not_before() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _setup(0.0, 12.0, 25)
	var r: Dictionary = await _run(s, 120, 10)
	var planned: int = int(r["start"]) + int(round(float(r["plan"].get("dt1", 0.0)) * 60.0))
	var first_change: int = -1
	for i in range(1, (r["bvel"] as Array).size()):
		if ((r["bvel"][i] as Vector3) - (r["bvel"][i - 1] as Vector3)).length() > 0.4:
			first_change = i
			break
	note("clip %s empieza en el paso %d con el toque a %.2f s: previsto en el paso %d, toque en el %d, primer cambio de la pelota en el %d" % [r["clip"], r["start"], float(r["plan"].get("dt1", 0.0)), planned, r["contact"], first_change])
	check(r["contact"] >= 0 and absi(int(r["contact"]) - planned) <= 2, "el toque llega en el instante de toque del clip (%d frente a %d)" % [r["contact"], planned])
	check(first_change >= int(r["contact"]) - 1, "la pelota no cambia antes del toque (%d)" % first_change)
	cleanup()
	_restore()

func test_without_a_compatible_clip_the_physical_control_takes_over() -> void:
	if _skip_if_missing():
		return
	# Esprintando hacia la pelota no hay clip de recepcion con esa carrera: control fisico, sin bloqueo.
	var s: Dictionary = await _setup(20.0, 11.0, 26, 1.0, Vector2(1.0, 0.0))
	var p: Footballer = s["p"]
	(s["src"] as ScriptedInput).sprint = true
	var r: Dictionary = await _run(s, 120)
	note("sin clip compatible (%.1f m/s): recepciones con clip %d, primer toque fisico %d, nivel del arbitro %d, pelota a %.2f m" % [p.locomotion.speed, p.ball_handler.receive.stats["started"], r["physical_ft"], p.arbiter.level, _ball_dist(s)])
	check(p.ball_handler.receive.stats["started"] == 0, "no se fuerza ningun clip")
	check(p.arbiter.level == ActionArbiter.Level.NONE and not p.ball_handler.json_move.active, "el jugador no queda bloqueado")
	check(r["physical_ft"] >= 1 or p.ball_handler.has_possession(), "la pelota la controla el control fisico de siempre")
	cleanup()
	_restore()

func test_rival_nearby_allows_the_shielding_control_only_then() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _setup(0.0, 12.0, 27, 0.0, Vector2.ZERO, 6.0, true)
	var r: Dictionary = await _run(s, 150)
	note("con un rival a 1.9 m: clip %s (rol %s)" % [r["clip"], PackLibrary.meta(r["clip"]).get("role", "") if r["clip"] != &"" else ""])
	var s2: Dictionary = await _setup(0.0, 12.0, 27)
	var r2: Dictionary = await _run(s2, 150)
	check(r2["clip"] == &"" or PackLibrary.meta(r2["clip"]).get("role", "") != "jostle_ball", "sin rival cerca no se usa el control protegiendo la pelota (%s)" % r2["clip"])
	check(r["contact"] >= 0, "con rival cerca tambien recibe con un clip")
	cleanup()
	_restore()

## Cobertura medida: parado, sin joystick, pelota desde 7 direcciones (de frente a los costados), 2 velocidades y 3 desvios.
func test_coverage_of_standing_receptions() -> void:
	if _skip_if_missing():
		return
	var total: int = 0
	var with_clip: int = 0
	var controlled: int = 0
	var used := {}
	for ang in [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0]:
		for spd in [9.0, 12.0]:
			for lat in [-0.4, 0.0, 0.4]:
				# Desvio lateral: la pelota sale del mismo sitio pero apuntada a `lat` m del jugador (una sola patada: dos en el
				# mismo paso se suman, Ball.kick aplica un impulso).
				var s: Dictionary = await _setup(ang, spd, 100 + total, 0.0, Vector2.ZERO, 6.0, false, lat)
				var ctx: MatchContext = s["ctx"]
				var r: Dictionary = await _run(s, 130)
				total += 1
				if r["contact"] >= 0:
					with_clip += 1
					used[r["clip"]] = int(used.get(r["clip"], 0)) + 1
				if _ball_dist(s) < 1.3:
					controlled += 1
				cleanup()
	note("parado: %d de %d recepciones con clip (toque del pie del clip), %d de %d con la pelota controlada al final; clips %s" % [with_clip, total, controlled, total, str(used)])
	check(with_clip * 2 >= total, "al menos la mitad de las recepciones de un jugador parado son con clip (%d de %d)" % [with_clip, total])
	check(controlled >= total - 2, "y la pelota queda controlada (%d de %d)" % [controlled, total])
	_restore()

# --- Con render: el pie animado ----------------------------------------------------------------------------------------

func test_live_foot_meets_the_ball() -> void:
	if _skip_if_missing():
		return
	if DisplayServer.get_name() == "headless":
		skip("el esqueleto no se anima en headless: ejecutar con xvfb-run --rendering-driver opengl3")
		return
	var lines: Array[String] = []
	var worst_at: float = 0.0
	var worst_pre: float = INF
	var n: int = 0
	for ang in [0.0, 30.0, -90.0]:
		var s: Dictionary = await _setup(ang, 12.0, 30 + n)
		var p: Footballer = s["p"]
		var ctx: MatchContext = s["ctx"]
		var bh: BallHandler = p.ball_handler
		var pre: Array[float] = []
		var at: float = -1.0
		var clip: StringName = &""
		for i in 150:
			await tree.physics_frame
			if clip == &"" and bh.json_move.active and bh.json_move.intent == &"receive":
				clip = bh.json_move.clip
			var bp: Vector3 = ctx.ball.global_position
			if at < 0.0 and bh.receive.stats["contact"] > 0:
				at = bh.toe_world(bh.last_touch_foot).distance_to(bp) - ctx.ball.radius
			elif at < 0.0 and clip != &"":
				pre.append(minf(bh.toe_world(0).distance_to(bp), bh.toe_world(1).distance_to(bp)) - ctx.ball.radius)
		var min_pre: float = INF
		for k in maxi(pre.size() - 3, 0):
			min_pre = minf(min_pre, pre[k])
		lines.append("%+d grados: %s, pie a %.3f m de la pelota en el toque, antes como mucho a %.3f m" % [int(ang), clip, at, min_pre])
		if at >= 0.0 or clip != &"":
			worst_at = maxf(worst_at, absf(at))
			worst_pre = minf(worst_pre, min_pre)
			n += 1
		cleanup()
	note("pie animado: " + "; ".join(lines))
	check(n == 3, "las tres recepciones son con clip (%d)" % n)
	# Criterio del proyecto para «pie en la pelota»: punta a <= BallHandler.FOOT_CONTACT del centro (radio + 0.17 m).
	check(worst_at <= BallHandler.FOOT_CONTACT - 0.11, "la punta del pie llega a la pelota en el toque (peor %.3f m de la superficie)" % worst_at)
	check(worst_pre >= 0.05, "antes del toque ningun pie toca ni atraviesa la pelota (minimo %.3f m)" % worst_pre)
	_restore()

# --- F3 corregido: perfiles de contacto, trayectoria 3D y partes del cuerpo --------------------------------------------

## Pelota por el aire que llega al jugador a unos `h` m (sin arrastre en la cuenta; el plan usa la trayectoria real).
func _setup_air(h: float, vh: float, dist: float, ang: float, seed: int, run: float = 0.0) -> Dictionary:
	_mode4()
	var from: Vector3 = FACE.rotated(Vector3.UP, deg_to_rad(ang))
	var ctx: MatchContext = await make_match(ME + from * dist + Vector3(0, 0.11, 0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, ME, 60, src, true)
	var mate: Footballer = add_player(ctx, 0, ME + Vector3(8.0, 0.0, 3.0), 60, ScriptedInput.new(), true)
	p.locomotion.yaw = Locomotion.yaw_from_dir(FACE)
	p.ball_handler.rng.seed = seed
	await physics_frames(3)
	if run > 0.0:
		src.move = Vector2(run, 0.0)
		await physics_frames(40)
	var tt: float = dist / vh
	var start: Vector3 = ctx.ball.global_position
	var dir: Vector3 = KickModel.flat(p.global_position + p.velocity * tt - start).normalized()
	ctx.ball.kick(dir * vh + Vector3(0.0, (h - 0.11 + 0.5 * 9.81 * tt * tt) / tt, 0.0), Vector3.ZERO, null)
	return {"ctx": ctx, "p": p, "src": src, "mate": mate}

func _part(r: Dictionary) -> String:
	return String((r["plan"] as Dictionary).get("part", ""))

func test_profiles_follow_the_audit_and_resolve_the_mirrored_sides() -> void:
	if _skip_if_missing():
		return
	_mode4()
	var counts := {}
	for id in ReceiveProfiles.PROFILES:
		var st: String = ReceiveProfiles.PROFILES[id]["status"]
		counts[st] = int(counts.get(st, 0)) + 1
	note("perfiles: %s; verificados en el visor: %d" % [str(counts), ReceiveProfiles.PROFILES.values().filter(func(p: Dictionary) -> bool: return p["confidence"] == "verified").size()])
	check(counts.get("usable", 0) == 23 and counts.get("conditional", 0) == 27 and counts.get("pending", 0) == 70 and counts.get("not_reception", 0) == 4, "la clasificacion es la de la auditoria (23 / 27 / 70 / 4)")
	var leaked: int = 0
	for id in ReceiveProfiles.PROFILES:
		var p: Dictionary = ReceiveProfiles.PROFILES[id]
		if (p["status"] == "pending" or p["status"] == "not_reception") and JsonReceive.selectable(p):
			leaked += 1
	check(leaked == 0, "ningun pendiente ni arranque de conduccion entra en la seleccion automatica (%d)" % leaked)
	# 572 (TURN_R_180): el primer contacto es el del pie al recibir (~0.30 s), no su primer toque registrado (0.60 s).
	var p572: Dictionary = JsonReceive.profile(&"jn_receive_turn_0572")
	var bt: Array = PackLibrary.meta(&"jn_receive_turn_0572").get("ball_touches", [])
	note("572: contacto %.2f s, primer ball_touches %.2f s; 564 (sin ball_touches): %s, contacto %.2f s" % [float(p572["t"]), float(bt[0][0]), JsonReceive.profile(&"jn_receive_foot_0564")["status"], float(JsonReceive.profile(&"jn_receive_foot_0564")["t"])])
	check(float(p572["t"]) < float(bt[0][0]) - 0.2, "el primer contacto no es el primer ball_touches")
	check(JsonReceive.selectable(JsonReceive.profile(&"jn_receive_foot_0564")), "un clip sin ball_touches (STAND_RECEIVE_BALL) es utilizable")
	# Lados: «R_THIGH» levanta el muslo IZQUIERDO del modelo (z < 0); su espejo, el derecho.
	var cp: Dictionary = JsonReceive.contact_point(&"jn_receive_0580", &"thigh", float(JsonReceive.profile(&"jn_receive_0580")["t"]))
	var cpm: Dictionary = JsonReceive.contact_point(&"jn_receive_0580_mirror", &"thigh", float(JsonReceive.profile(&"jn_receive_0580_mirror")["t"]))
	note("580 «R_THIGH»: muslo en z %.2f (espejo %.2f); FROM_R_45 (600) llega por %+.0f grados" % [(cp["point"] as Vector3).z, (cpm["point"] as Vector3).z, float(JsonReceive.profile(&"jn_receive_turn_0600")["from_deg"])])
	check((cp["point"] as Vector3).z < 0.0 and (cpm["point"] as Vector3).z > 0.0, "el lado del nombre esta invertido en los datos: R_THIGH es el muslo izquierdo del modelo")
	check(float(JsonReceive.profile(&"jn_receive_turn_0600")["from_deg"]) > 0.0 and float(JsonReceive.profile(&"jn_receive_turn_0600_mirror")["from_deg"]) < 0.0, "FROM_R llega por la izquierda en los datos; su espejo por la derecha")
	_restore()

func _air_case(h: float, vh: float, ang: float, seed: int, run: float = 0.0) -> Dictionary:
	var s: Dictionary = await _setup_air(h, vh, 7.0, ang, seed, run)
	var r: Dictionary = await _run(s, 150)
	r["final"] = _ball_dist(s)
	if r["contact"] >= 0 and int(r["contact"]) + 2 < (r["bvel"] as Array).size():
		r["v_in"] = r["bvel"][maxi(int(r["contact"]) - 1, 0)]
		r["v_out"] = r["bvel"][int(r["contact"]) + 1]
	r["speed_min"] = 99.0
	for i in mini((r["pspeed"] as Array).size(), 80):
		r["speed_min"] = minf(float(r["speed_min"]), float(r["pspeed"][i]))
	cleanup()
	return r

## La parte del cuerpo corresponde a la altura REAL de la pelota en el contacto (la de lanzamiento es aproximada: el plan
## usa la trayectoria con arrastre y bote): pie a ras de piso hasta 0.3 m, pie en el aire o rodilla hasta 0.75 m, muslo, pie
## en el aire o rodilla hasta 1.0 m, pecho por encima.
func test_body_part_matches_the_ball_height_at_contact() -> void:
	if _skip_if_missing():
		return
	var ok_cases: int = 0
	var lines: Array[String] = []
	for c in [[0.3, 8.0, 0.0], [0.45, 8.0, 20.0], [0.6, 8.0, 0.0], [0.7, 8.0, -20.0], [0.85, 7.0, 30.0]]:
		var r: Dictionary = await _air_case(c[0], c[1], c[2], 41)
		if r["contact"] < 0:
			lines.append("~%.2f m: sin clip" % c[0])
			continue
		var y: float = float((r["plan"] as Dictionary).get("ball_y", -1.0))
		var part: String = _part(r)
		var allowed: Array = ["foot"] if y <= 0.3 else (["foot_air", "knee"] if y <= 0.75 else (["thigh", "foot_air", "knee"] if y <= 1.0 else ["chest"]))
		var vo: Vector3 = r.get("v_out", Vector3.ZERO)
		var physical: bool = float(r["final"]) < 1.6 and (part != "foot_air" or vo.y <= 0.45)
		lines.append("pelota a %.2f m: %s (%s), sale vy %.2f, final a %.2f m" % [y, part, r["clip"], vo.y, r["final"]])
		if allowed.has(part) and physical:
			ok_cases += 1
		check(allowed.has(part), "a %.2f m la parte es %s (admitidas %s)" % [y, part, str(allowed)])
		check(physical, "respuesta de %s: pelota controlada (%.2f m) y, con el pie en el aire, hacia abajo (vy %.2f)" % [part, r["final"], vo.y])
	note("; ".join(lines))
	check(ok_cases >= 4, "al menos 4 de 5 alturas con clip y control (%d)" % ok_cases)
	_restore()

func test_waist_high_ball_is_controlled_with_the_thigh() -> void:
	if _skip_if_missing():
		return
	var r: Dictionary = await _air_case(0.7, 8.0, 0.0, 42)
	var vo: Vector3 = r.get("v_out", Vector3.ZERO)
	note("pelota a la cintura: clip %s parte %s, pelota a %.2f m, sale %s, final a %.2f m" % [r["clip"], _part(r), float((r["plan"] as Dictionary).get("ball_y", -1.0)), str(vo.snapped(Vector3.ONE * 0.01)), r["final"]])
	check(r["contact"] >= 0 and _part(r) == "thigh", "muslo (%s)" % _part(r))
	check(vo.y > 0.2 and vo.y < 2.5 and KickModel.flat(vo).length() < 2.5, "rebote pequeno hacia arriba (%.2f m/s) y poca velocidad horizontal" % vo.y)
	check(float(r["final"]) < 1.5, "cae delante del jugador (%.2f m)" % r["final"])
	_restore()

func test_chest_high_ball_is_controlled_with_the_chest() -> void:
	if _skip_if_missing():
		return
	var r: Dictionary = await _air_case(0.85, 7.0, 30.0, 43)
	var vi: Vector3 = r.get("v_in", Vector3.ZERO)
	var vo: Vector3 = r.get("v_out", Vector3.ZERO)
	note("pelota al pecho: clip %s parte %s, pelota a %.2f m, llega a %.1f m/s en el suelo, sale a %.1f m/s, final a %.2f m" % [r["clip"], _part(r), float((r["plan"] as Dictionary).get("ball_y", -1.0)), KickModel.flat(vi).length(), KickModel.flat(vo).length(), r["final"]])
	check(r["contact"] >= 0 and _part(r) == "chest", "pecho (%s)" % _part(r))
	check(KickModel.flat(vo).length() < 0.5 * KickModel.flat(vi).length(), "el pecho quita la mayor parte de la velocidad horizontal")
	check(float(r["final"]) < 1.6, "la pelota cae delante (%.2f m)" % r["final"])
	_restore()

func test_lob_received_while_running() -> void:
	if _skip_if_missing():
		return
	var r: Dictionary = await _air_case(0.8, 9.0, 0.0, 44, 0.45)
	note("globo en carrera: clip %s parte %s (carrera de entrada del clip %.2f m/s), velocidad minima %.2f m/s, final a %.2f m" % [r["clip"], _part(r), float(PackLibrary.meta(r["clip"]).get("v_in", -1.0)) if r["clip"] != &"" else -1.0, r["speed_min"], r["final"]])
	check(r["contact"] >= 0 and ["chest", "thigh", "foot_air", "knee"].has(_part(r)), "recibe el globo en marcha con una parte del cuerpo alta (%s)" % _part(r))
	check(float(r["final"]) < 1.6, "y la controla (%.2f m)" % r["final"])
	_restore()

func test_turn_reception_follows_the_stick() -> void:
	if _skip_if_missing():
		return
	var sd: Vector3 = FACE.rotated(Vector3.UP, deg_to_rad(120.0))
	var s: Dictionary = await _setup(0.0, 12.0, 45, 0.0, Vector2(sd.x, sd.z))
	var r: Dictionary = await _run(s, 110)
	var p: Footballer = s["p"]
	var moved: float = 0.0
	if r["contact"] >= 0 and int(r["contact"]) + 40 < (r["bpos"] as Array).size():
		moved = KickModel.flat((r["bpos"][int(r["contact"]) + 40] as Vector3) - (r["bpos"][r["contact"]] as Vector3)).dot(sd)
	note("joystick a 120 grados: clip %s (giro %.0f), jugador mira a %.0f grados del joystick, la pelota avanzo %.2f m hacia alli" % [r["clip"], float((r["plan"] as Dictionary).get("turn", 0.0)), KickModel.angle_between_deg(p.locomotion.forward(), sd), moved])
	check(r["contact"] >= 0, "recibe con un clip")
	check(KickModel.angle_between_deg(p.locomotion.forward(), sd) < 60.0 and moved > 0.2, "sale orientado hacia el joystick (cuerpo y pelota)")
	_restore()

func test_second_contact_that_does_not_arrive_cuts_the_clip() -> void:
	if _skip_if_missing():
		return
	# Una recepcion cuyo clip tiene toques de pie posteriores: tras el contacto, la pelota se va (se la desvia el mismo
	# jugador, sin otro tocador) y el toque siguiente no llega.
	var done := false
	for k in 8:
		var s: Dictionary = await _setup(float(k * 25 - 90), 12.0, 60 + k)
		var p: Footballer = s["p"]
		var ctx: MatchContext = s["ctx"]
		var jm: JsonBallMove = p.ball_handler.json_move
		for i in 120:
			await tree.physics_frame
			if jm.active and jm.intent == &"receive" and jm._next == 1 and jm._touches.size() > 1:
				ctx.ball.kick(Vector3(0.0, 0.0, 7.0), ctx.ball.rolling_spin(Vector3(0.0, 0.0, 7.0)), p)
				for j in 60:
					await tree.physics_frame
				note("clip %s con %d toques: recepcion terminada %s (%s), arbitro nivel %d" % [jm.clip, jm._touches.size(), str(not jm.active), str(jm.last.get("ended", jm.last.get("aborted", ""))), p.arbiter.level])
				check(not jm.active and str(jm.last.get("ended", "")) == "segundo contacto no llega", "el clip se corta cuando la pelota no llega al toque siguiente")
				check(p.arbiter.level == ActionArbiter.Level.NONE, "y el jugador queda libre para ir a por ella")
				done = true
				break
		cleanup()
		if done:
			break
	if not done:
		skip("ninguna recepcion de prueba eligio un clip con toques posteriores")
	_restore()

func test_receiver_moves_to_where_a_clip_fits_before_the_ball_arrives() -> void:
	if _skip_if_missing():
		return
	# Pelota que pasa a 1 m del jugador quieto: sin anticipacion ningun clip llega; el receptor se coloca y recibe.
	_mode4()
	var ctx: MatchContext = await make_match(ME + Vector3(8.0, 0.11, 1.0))
	var p: Footballer = add_player(ctx, 0, ME, 60, ScriptedInput.new(), true)
	p.locomotion.yaw = Locomotion.yaw_from_dir(FACE)
	p.ball_handler.rng.seed = 46
	await physics_frames(3)
	ctx.ball.kick(Vector3(-11.0, 0.0, 0.0), ctx.ball.rolling_spin(Vector3(-11.0, 0.0, 0.0)), null)
	var approached := false
	var start_pos := Vector3.INF
	var contact := false
	for i in 120:
		await tree.physics_frame
		if p.ball_handler.receive.approach != Vector3.INF:
			approached = true
		if start_pos == Vector3.INF and p.ball_handler.json_move.active:
			start_pos = p.global_position
		if p.ball_handler.receive.stats["contact"] > 0:
			contact = true
	note("pelota a 1 m del jugador: se coloco %s, al empezar el clip estaba a %.2f m de donde estaba, contacto %s" % [str(approached), KickModel.flat(start_pos - ME).length() if start_pos != Vector3.INF else -1.0, str(contact)])
	check(approached and start_pos != Vector3.INF and KickModel.flat(start_pos - ME).length() > 0.3, "el receptor se desplaza antes de empezar el clip")
	check(contact, "y recibe con el clip")
	cleanup()
	_restore()

func test_reception_with_a_pass_in_the_clip_uses_the_real_pass_once() -> void:
	if _skip_if_missing():
		return
	var s: Dictionary = await _setup(0.0, 12.0, 47)
	var p: Footballer = s["p"]
	var src: ScriptedInput = s["src"]
	src.hold_pass()
	var jumps_after: int = 0
	var released := false
	var r: Dictionary = {"clip": &"", "contact": -1}
	var prev := Vector3.ZERO
	for i in 120:
		await tree.physics_frame
		var jm: JsonBallMove = p.ball_handler.json_move
		if r["clip"] == &"" and jm.active and jm.intent == &"receive":
			r["clip"] = jm.clip
		if int(r["contact"]) < 0 and p.ball_handler.receive.stats["contact"] > 0:
			r["contact"] = i
			src.release_pass()
			released = true
		var v: Vector3 = (s["ctx"] as MatchContext).ball.linear_velocity
		if released and i > int(r["contact"]) + 1 and (v - prev).length() > 3.0:
			jumps_after += 1
		prev = v
	var conds: Array = JsonReceive.profile(r["clip"]).get("conds", []) if r["clip"] != &"" else []
	note("pase cargado mientras llega la pelota: clip %s (condiciones %s), golpeos %d, impulsos fuertes tras el control %d" % [r["clip"], str(conds), int(p.ball_handler.kick_stats["started"]), jumps_after])
	check(r["clip"] != &"" and conds.has("post_action"), "elige un clip de recepcion con pase posterior")
	check(int(p.ball_handler.kick_stats["started"]) == 1 and jumps_after == 1, "el pase lo da una sola vez el sistema de pase real")
	cleanup()
	_restore()
