extends TestCase
## Control de la persona (indicadores, cambio de jugador, arquero manejable) y la diferencia entre un disparo rival
## y una cedida del propio equipo. Son las reglas que hacen que el arquero obedezca al mando en vez de contradecirlo.

func _skip_if_missing() -> bool:
	PackLibrary.reload()
	if not PackLibrary.available() or PackLibrary.keeper() == null:
		skip("faltan assets/animations/pack_clips.res y pack_keeper.res")
		return true
	return false

func _scene(intro: float = 0.0) -> MatchScene:
	var m: MatchScene = load("res://scenes/main/match.tscn").instantiate()
	m.duration_seconds = 0.0
	m.intro_seconds = intro
	m.auto_switch = false
	spawn(m)
	await physics_frames(5)
	return m

func _keeper_world() -> Dictionary:
	var ctx: MatchContext = await make_match(Vector3(0.0, 0.11, 0.0))
	var k := Goalkeeper.new()
	spawn(k)
	var attrs := PlayerAttributes.new()
	attrs.reset_to(60)
	k.setup(ctx, 1, 90, attrs)
	await physics_frames(6)
	return {"ctx": ctx, "k": k}

## Lanza la pelota desde `from` hacia `target` a `speed`, marcando quien la toco (equipo del arquero = cedida).
func _send(ctx: MatchContext, from: Vector3, target: Vector3, speed: float, toucher: Node) -> void:
	ctx.ball.reset_at(from)
	await tree.physics_frame
	await tree.physics_frame
	var v: Vector3 = (target - from).normalized() * speed
	ctx.ball.kick(v, ctx.ball.rolling_spin(v), toucher)

func test_backpass_from_a_teammate_is_received_not_dived_at() -> void:
	if _skip_if_missing():
		return
	var w: Dictionary = await _keeper_world()
	var ctx: MatchContext = w["ctx"]
	var k: Goalkeeper = w["k"]
	# Un companero (mismo equipo que el arquero) le cede la pelota hacia el arco a velocidad de pase.
	var mate: Footballer = add_player(ctx, 1, Vector3(8.0, 0.0, 0.0), 55, null, false)
	await _send(ctx, Vector3(10.0, 0.11, 0.0), Vector3(20.0, 0.0, 0.0), 9.0, mate)
	await wait_seconds(2.5)
	note("cedida: estirada=%d, atajadas=%d, pelota a %.2f m del arquero, eventos de saque=%d" % [k.stats["dives"], k.stats["catches"], KickModel.flat(ctx.ball.global_position - k.global_position).length(), k.stats["distributions"]])
	check(k.stats["dives"] == 0, "no se lanza a una cedida del propio equipo (estiradas=%d)" % k.stats["dives"])
	check(ctx.ball.global_position.x < 20.0, "la cedida no termina en gol en contra")

func test_a_real_shot_from_the_opponent_still_makes_the_keeper_dive() -> void:
	if _skip_if_missing():
		return
	var w: Dictionary = await _keeper_world()
	var ctx: MatchContext = w["ctx"]
	var k: Goalkeeper = w["k"]
	var rival: Footballer = add_player(ctx, 0, Vector3(8.0, 0.0, 2.0), 55, null, false)
	await _send(ctx, Vector3(10.0, 0.11, 2.0), Vector3(20.0, 0.6, 1.0), 16.0, rival)
	await wait_seconds(1.5)
	note("disparo rival: estiradas=%d, atajadas=%d, rechaces=%d, superado=%d" % [k.stats["dives"], k.stats["catches"], k.stats["parries"], k.stats["beaten"]])
	check(k.stats["shots_faced"] >= 1, "el disparo rival si cuenta como peligro")
	check(k.stats["dives"] >= 1, "y el arquero se lanza a por el")

func test_user_controlled_keeper_follows_the_stick_and_never_dives_on_its_own() -> void:
	if _skip_if_missing():
		return
	var w: Dictionary = await _keeper_world()
	var ctx: MatchContext = w["ctx"]
	var k: Goalkeeper = w["k"]
	var src := ScriptedInput.new()
	k.input_source = src
	k.is_human_controlled = true
	var z0: float = k.global_position.z
	src.move = Vector2(0.0, 1.0)      # pantalla abajo = +Z en el mundo
	await wait_seconds(1.0)
	var moved: float = k.global_position.z - z0
	note("arquero manejado: se desplazo %.2f m en 1 s con el joystick" % moved)
	check(moved > 1.5, "el arquero obedece al joystick (%.2f m)" % moved)
	# Mientras la persona lo mueve, un disparo rival NO dispara una atajada automatica.
	var rival: Footballer = add_player(ctx, 0, Vector3(8.0, 0.0, 0.0), 55, null, false)
	await _send(ctx, Vector3(10.0, 0.11, 0.0), Vector3(20.0, 0.5, 0.0), 16.0, rival)
	await wait_seconds(1.2)
	check(k.stats["dives"] == 0, "con el joystick en la mano no se lanza solo (estiradas=%d)" % k.stats["dives"])
	check(k.state != Goalkeeper.State.ACTION, "el mando manda: no entra en una atajada automatica")

func test_user_controlled_keeper_catches_and_distributes_with_the_button() -> void:
	if _skip_if_missing():
		return
	var w: Dictionary = await _keeper_world()
	var ctx: MatchContext = w["ctx"]
	var k: Goalkeeper = w["k"]
	var src := ScriptedInput.new()
	k.input_source = src
	k.is_human_controlled = true
	add_player(ctx, 1, Vector3(8.0, 0.0, 3.0), 55, null, false)
	# Pelota lenta justo delante del arquero: el boton la atrapa.
	ctx.ball.reset_at(k.global_position + Vector3(-0.6, 0.11, 0.0))
	await physics_frames(10)
	src.hold_pass()
	await physics_frames(4)
	src.release_pass()
	await physics_frames(10)
	check(ctx.ball.is_held(), "el boton atrapa la pelota que esta a su alcance")
	check(k.state == Goalkeeper.State.HOLD, "y pasa a sostenerla esperando la orden de saque")
	await physics_frames(20)
	src.hold_pass()
	await physics_frames(4)
	src.release_pass()
	for i in 3 * 60:
		await tree.physics_frame
		if not ctx.ball.is_held():
			break
	await wait_seconds(0.4)
	note("saque manual: la pelota salio a %.1f m/s y esta en x=%.1f" % [ctx.ball.linear_velocity.length(), ctx.ball.global_position.x])
	check(not ctx.ball.is_held(), "el segundo boton la saca")
	check(k.stats["distributions"] >= 1, "y queda registrado como saque")

func test_markers_follow_the_controlled_player_and_the_switch_candidate() -> void:
	if _skip_if_missing():
		return
	var m: MatchScene = await _scene()
	await physics_frames(10)
	check(m.marker.visible and m.next_marker.visible, "los dos indicadores se ven")
	check(m.marker.global_position.distance_to(m.controlled.global_position + Vector3(0, PlayerMarker.HEIGHT, 0)) < 0.2,
		"el indicador principal esta sobre el jugador controlado")
	var nxt: Footballer = m.switch_candidate()
	check(nxt != null and nxt != m.controlled, "hay un siguiente jugador distinto del actual")
	check(m.next_marker.global_position.distance_to(nxt.global_position + Vector3(0, PlayerMarker.HEIGHT, 0)) < 0.2,
		"el indicador secundario esta sobre el siguiente jugador")
	# Al cambiar de jugador, el indicador principal se va con el nuevo (no se queda flotando en el anterior).
	var before: Footballer = m.controlled
	m.switch_to_nearest_to_ball()
	await physics_frames(5)
	check(m.controlled != before, "el cambio pasa el control a otro jugador")
	check(m.marker.global_position.distance_to(m.controlled.global_position + Vector3(0, PlayerMarker.HEIGHT, 0)) < 0.2,
		"y el indicador principal lo sigue")

func test_switching_to_the_keeper_when_the_play_is_in_our_area() -> void:
	if _skip_if_missing():
		return
	var m: MatchScene = await _scene()
	m.ball.reset_at(Vector3(-17.0, 0.11, 0.0))
	await physics_frames(6)
	check(m.take_keeper_control(), "con la pelota en el area propia se puede tomar el arquero")
	await physics_frames(5)
	check(m.controlled_keeper != null and m.controlled_keeper.is_human_controlled, "el arquero pasa a estar bajo control")
	check(not m.controlled.is_human_controlled, "y el jugador de campo vuelve a la IA")
	check(m.human_actor() == m.controlled_keeper, "el nodo que maneja la persona es el arquero")
	check(m.marker.global_position.distance_to(m.controlled_keeper.global_position + Vector3(0, PlayerMarker.HEIGHT, 0)) < 0.2,
		"el indicador principal esta sobre el arquero")
	m.release_keeper_control()
	await physics_frames(5)
	check(m.controlled_keeper == null and m.controlled.is_human_controlled, "al soltarlo el control vuelve al campo")

func test_kickoff_puts_a_taker_on_the_ball_and_the_rival_outside_the_circle() -> void:
	if _skip_if_missing():
		return
	var m: MatchScene = await _scene()
	await physics_frames(4)
	var ball_pos: Vector3 = m.ball.global_position
	var mine: float = INF
	var theirs: float = INF
	for f in m.home:
		mine = minf(mine, KickModel.flat(f.global_position - ball_pos).length())
	for f in m.away:
		theirs = minf(theirs, KickModel.flat(f.global_position - ball_pos).length())
	note("saque: el ejecutor esta a %.2f m de la pelota y el rival mas cercano a %.2f m" % [mine, theirs])
	check(mine < 1.0, "el equipo que saca tiene un jugador junto a la pelota (%.2f m)" % mine)
	check(theirs > 3.0, "el rival respeta el circulo central (%.2f m)" % theirs)
	# Y la jugada arranca: alguien toca la pelota en los primeros segundos.
	var touched := false
	for i in 5 * 60:
		await tree.physics_frame
		if m.ball.linear_velocity.length() > 1.5:
			touched = true
			break
	check(touched, "la pelota se pone en juego en los primeros 5 s")
