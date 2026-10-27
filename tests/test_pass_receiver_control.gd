extends TestCase
## Control de la persona en los pases: el receptor pasa a ser de la persona en el momento del pase (tenga o no
## destinatario) y lo sigue siendo durante todo el vuelo de la pelota; la IA del equipo de la persona nunca decide con
## la pelota (ni pasa ni patea): si un companero se queda con ella, el control pasa a el.

func _scene(auto: bool) -> MatchScene:
	PackLibrary.reload()
	MatchScene.training_mode = true   # sin rivales de campo: nadie corta el pase ni roba
	var m: MatchScene = load("res://scenes/main/match.tscn").instantiate()
	m.duration_seconds = 0.0
	m.intro_seconds = 0.0
	m.auto_switch = auto
	spawn(m)
	MatchScene.training_mode = false   # solo se lee al crear la escena
	await wait_seconds(1.6)
	return m

## Pone la pelota al pie de `p` mirando hacia `dir`.
func _ball_at_feet(m: MatchScene, p: Footballer, dir: Vector3) -> void:
	p.locomotion.yaw = Locomotion.yaw_from_dir(dir)
	m.ball.reset_at(p.global_position + dir * 0.45 + Vector3(0, 0.11, 0))
	await physics_frames(3)

## Cuenta los pases y tiros del equipo de la persona que no son el pase de la persona (`passer_id`) ni de quien
## controla la persona en ese momento.
func _ai_kicks_counter(m: MatchScene, passer_id: int = -1) -> Array:
	var count := [0]
	m.ctx.event_emitted.connect(func(e: GameEvent) -> void:
		if (e.type == GameEvent.Type.PASS or e.type == GameEvent.Type.SHOT) and e.team == 0 and e.actor_id != passer_id:
			if m.controlled == null or e.actor_id != m.controlled.actor_id:
				count[0] += 1)
	return count

func test_a_pass_into_space_without_target_hands_control_to_the_teammate_who_gets_there_first() -> void:
	var m: MatchScene = await _scene(true)
	var passer: Footballer = m.controlled
	# El companero mas adelantado en +X recibe; la pelota va al espacio delante de el (sin destinatario asignado).
	var mate: Footballer = null
	for f in m.home:
		if f != passer and (mate == null or f.global_position.x > mate.global_position.x):
			mate = f
	var aim: Vector3 = KickModel.flat(mate.global_position) + Vector3(3.0, 0.0, 0.0)
	var dir: Vector3 = KickModel.flat(aim - passer.global_position).normalized()
	await _ball_at_feet(m, passer, dir)
	var ai_kicks: Array = _ai_kicks_counter(m, passer.actor_id)
	var v: Vector3 = dir * 11.0
	m.ball.kick(v, m.ball.rolling_spin(v), passer)
	# Como tras cualquier golpeo: el pasador no vuelve a tocar la pelota que acaba de patear.
	passer.ball_handler.lockout = Tuning.player.kick_lockout
	passer.ball_handler.touch_timer = Tuning.player.kick_lockout
	m.ctx.emit_event(GameEvent.make(GameEvent.Type.PASS, passer.actor_id, 0, {"target": -1, "kind": "ground"}))
	await physics_frames(1)
	var receiver: Footballer = m.controlled
	note("pase al espacio sin destinatario: control en %s (pasador %d, companero adelantado %d)" % [receiver.actor_id, passer.actor_id, mate.actor_id])
	check(receiver != passer, "el control deja al pasador en el momento del pase")
	check(receiver.has_incoming_pass(), "el nuevo controlado sabe que la pelota va hacia el")
	check(not passer.is_human_controlled and receiver.is_human_controlled, "el pasador queda en manos de la IA")
	var switches := 0
	var last: Footballer = receiver
	for i in 150:
		await physics_frames(1)
		if m.controlled != last:
			switches += 1
			note("cambio en el paso %d: %d -> %d (pelota %s, %.1f m/s; receptor tiene pase=%s, tiene pelota=%s)" % [i, last.actor_id, m.controlled.actor_id, m.ball.global_position, m.ball.linear_velocity.length(), last.has_incoming_pass(), last.has_ball()])
			last = m.controlled
	note("cambios de control durante el vuelo: %d; pases/tiros de la IA del equipo: %d" % [switches, ai_kicks[0]])
	check(switches == 0, "el control no vuelve a otro durante el vuelo (%d cambios)" % switches)
	check(ai_kicks[0] == 0, "la IA del equipo no pasa ni patea (%d)" % ai_kicks[0])

func test_a_long_pass_keeps_control_on_the_receiver_during_the_whole_flight() -> void:
	var m: MatchScene = await _scene(true)
	var passer: Footballer = m.controlled
	var far: Footballer = null
	for f in m.home:
		if f != passer and (far == null or f.global_position.distance_to(passer.global_position) > far.global_position.distance_to(passer.global_position)):
			far = f
	# Receptor lejos (18 m): durante el vuelo el pasador y otros companeros quedan mas cerca de la pelota que el.
	far.global_position = passer.global_position + Vector3(16.0, 0.0, 8.0)
	await physics_frames(2)
	var to: Vector3 = KickModel.flat(far.global_position - passer.global_position)
	await _ball_at_feet(m, passer, to.normalized())
	var ai_kicks: Array = _ai_kicks_counter(m, passer.actor_id)
	var res: KickModel.KickResult = passer.ball_handler.perform_pass(to.normalized(), 0.9, false)
	await physics_frames(1)
	var receiver: Footballer = m.controlled
	note("pase largo de %.1f m hacia %d: control en %d (destinatario %d)" % [to.length(), far.actor_id, receiver.actor_id, res.target.actor_id if res.target != null else -1])
	check(receiver != passer, "el control pasa al receptor al pasar")
	var others := 0
	var got := false
	for i in 240:
		await physics_frames(1)
		if m.controlled != receiver:
			others += 1
		if receiver.has_ball():
			got = true
			break
	note("pasos con el control en otro jugador durante el vuelo: %d; el receptor la controla: %s" % [others, got])
	check(others == 0, "el control no vuelve al pasador ni a otro companero mas cerca de la pelota (%d pasos)" % others)
	check(ai_kicks[0] == 0, "la IA del equipo no pasa ni patea (%d)" % ai_kicks[0])

func test_teammate_ai_never_decides_with_the_ball() -> void:
	var m: MatchScene = await _scene(false)
	var me: Footballer = m.controlled
	var mate: Footballer = m.home[2]
	var ai_kicks: Array = _ai_kicks_counter(m)
	# La pelota queda al pie de un companero controlado por la IA (rebote, pase del arquero...).
	await _ball_at_feet(m, mate, Vector3(1.0, 0.0, 0.0))
	await physics_frames(10)
	note("pelota al pie de %d: control en %d (antes %d)" % [mate.actor_id, m.controlled.actor_id, me.actor_id])
	check(m.controlled == mate, "el control pasa al companero que tiene la pelota (aun sin cambio automatico)")
	check(mate.is_human_controlled and not me.is_human_controlled, "el anterior vuelve a la IA")
	await wait_seconds(3.0)
	note("en 3 s con la persona sin tocar nada: pases/tiros de la IA del equipo %d" % ai_kicks[0])
	check(ai_kicks[0] == 0, "la IA del equipo de la persona no pasa ni patea (%d)" % ai_kicks[0])
	check(mate.has_ball() or m.controlled == mate, "la pelota sigue esperando la orden de la persona")

func test_ai_teams_still_play_without_a_human() -> void:
	var m: MatchScene = await _scene(false)
	m.home[0].input_source = AIInput.new(3, 0.6)
	m.home[0].is_human_controlled = false
	var kicks := [0]
	m.ctx.event_emitted.connect(func(e: GameEvent) -> void:
		if (e.type == GameEvent.Type.PASS or e.type == GameEvent.Type.SHOT) and e.team == 0:
			kicks[0] += 1)
	# Un saque o un cambio pasa ese control de IA a otro jugador (lo marca como controlado): sigue sin haber persona.
	m._give_control(m.home[1])
	await physics_frames(2)
	check(m.ctx.human_team == -1, "un control de IA pasado a otro jugador no cuenta como persona")
	var stall := 0.0
	var carriers := {}
	for k in 25 * 60:
		await physics_frames(1)
		stall = maxf(stall, m.ctx.ball_stall_seconds)
		var pos: Footballer = m.ctx.possessor
		if pos != null and pos.team == 0:
			carriers[pos.actor_id] = true
	note("equipo 0 sin persona (IA contra el arquero), 25 s: %d pases/tiros, %d jugadores distintos con la pelota, pelota quieta max %.1f s, human_team=%d" % [kicks[0], carriers.size(), stall, m.ctx.human_team])
	check(m.ctx.human_team == -1, "sin persona no hay equipo humano")
	# Con la persona ausente la IA del equipo 0 juega la pelota (antes del arreglo quedaba quieta: 311 s en un partido).
	check(stall < 3.0, "la pelota no se queda quieta en los pies de la IA (%.1f s)" % stall)
	check(carriers.size() >= 2 or kicks[0] > 0, "la IA del equipo 0 sigue jugando (%d con la pelota, %d pases/tiros)" % [carriers.size(), kicks[0]])
