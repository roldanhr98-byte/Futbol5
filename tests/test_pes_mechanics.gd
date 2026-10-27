extends TestCase
## Mecanicas inspiradas en los videos de referencia: pase filtrado al espacio, centros (elevado / tenso / raso),
## receptor que sale al encuentro, cambio de control al receptor y pared, entrada con boton (sin robo por mantener la
## presion), carga con el hombro, tiro colocado, y clips del pack que antes solo estaban en la galeria.

func _two_v_two() -> Dictionary:
	var ctx: MatchContext = await make_match(Vector3(0.0, 0.11, 0.0))
	var carrier: Footballer = add_player(ctx, 0, Vector3(-0.5, 0.0, 0.0), 60)
	var mate: Footballer = add_player(ctx, 0, Vector3(6.0, 0.0, 4.0), 60)
	var def1: Footballer = add_player(ctx, 1, Vector3(9.0, 0.0, 2.0), 60)
	var def2: Footballer = add_player(ctx, 1, Vector3(9.0, 0.0, -3.0), 60)
	carrier.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	return {"ctx": ctx, "carrier": carrier, "mate": mate, "def1": def1, "def2": def2}

# --- Pases ---------------------------------------------------------------------------------------------------

func test_through_pass_goes_into_space_ahead_of_the_runner() -> void:
	var s: Dictionary = await _two_v_two()
	var ctx: MatchContext = s["ctx"]
	var mate: Footballer = s["mate"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var normal: KickModel.KickResult = PassAssist.compute(s["carrier"], ctx, Vector3(1, 0, 0.6).normalized(), 0.4, false, rng, 0.6)
	var through: KickModel.KickResult = PassAssist.compute_through(s["carrier"], ctx, Vector3(1, 0, 0.6).normalized(), 0.4, false, rng, 0.6)
	note("pase al pie apunta a x=%.1f; filtrado a x=%.1f (receptor en x=%.1f), %.1f m/s" % [normal.aim_point.x, through.aim_point.x, mate.global_position.x, KickModel.flat(through.velocity).length()])
	check(through.target == mate, "el filtrado busca al companero que corre")
	check(through.aim_point.x > mate.global_position.x + 2.0, "el filtrado va al espacio por delante del receptor (%.1f)" % through.aim_point.x)
	check(KickModel.flat(normal.aim_point - mate.global_position).length() < 1.0, "el pase normal va al pie del companero quieto")
	check(through.aim_point.x > normal.aim_point.x + 2.5, "el filtrado va mucho mas adelante que el pase al pie")
	check(String(through.kind) == "through", "tipo de pase: %s" % through.kind)
	var lob: KickModel.KickResult = PassAssist.compute_through(s["carrier"], ctx, Vector3(1, 0, 0.6).normalized(), 0.4, true, rng, 0.6)
	check(lob.velocity.y > 3.0, "el filtrado con ALTO va por encima de la defensa (vy %.1f)" % lob.velocity.y)

func test_crosses_have_three_real_trajectories() -> void:
	var ctx: MatchContext = await make_match(Vector3(13.0, 0.11, 8.0))
	var w: Footballer = add_player(ctx, 0, Vector3(12.5, 0.0, 8.0), 60)
	var striker: Footballer = add_player(ctx, 0, Vector3(16.0, 0.0, -1.0), 60)
	w.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(0.3, 0, -1).normalized())
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var high: KickModel.KickResult = CrossAssist.compute(w, ctx, Vector3.ZERO, 0.3, false, rng, 0.6)
	var driven: KickModel.KickResult = CrossAssist.compute(w, ctx, Vector3.ZERO, 0.9, false, rng, 0.6)
	var low: KickModel.KickResult = CrossAssist.compute(w, ctx, Vector3.ZERO, 0.3, true, rng, 0.6)
	note("centros: elevado vy=%.1f |v|=%.1f, tenso vy=%.1f |v|=%.1f, raso vy=%.1f |v|=%.1f (zona %s)" % [high.velocity.y, high.velocity.length(), driven.velocity.y, driven.velocity.length(), low.velocity.y, low.velocity.length(), str(high.aim_point)])
	check(String(high.kind) == "cross_high" and String(driven.kind) == "cross_driven" and String(low.kind) == "cross_low", "tres tipos de centro")
	check(high.velocity.y > driven.velocity.y and driven.velocity.y > low.velocity.y, "el elevado sube mas que el tenso, y el raso va por el suelo")
	check(driven.velocity.length() > high.velocity.length(), "el tenso es mas rapido que el elevado")
	check(low.velocity.y == 0.0, "el raso sale sin altura")
	# Trayectoria real: el elevado pasa por la zona a altura de cabeza (con arrastre, sin teledirigir).
	var traj: PackedVector3Array = BallPredictor.trajectory(ctx.ball.global_position, high.velocity, 3.0, 1.0 / 60.0)
	var best: float = INF
	var best_y: float = 0.0
	for p in traj:
		var d: float = Vector2(p.x - high.aim_point.x, p.z - high.aim_point.z).length()
		if d < best:
			best = d
			best_y = p.y
	note("el centro elevado pasa a %.2f m de la zona a %.2f m de altura" % [best, best_y])
	check(best < 1.6, "el centro llega a la zona elegida (%.2f m)" % best)
	check(best_y > 0.9 and best_y < 2.6, "a altura de remate (%.2f m)" % best_y)

func test_receiver_runs_to_meet_the_pass_and_human_control_switches_to_him() -> void:
	PackLibrary.reload()
	var m: MatchScene = load("res://scenes/main/match.tscn").instantiate()
	m.duration_seconds = 0.0
	m.auto_switch = false
	m.intro_seconds = 0.0
	spawn(m)
	await wait_seconds(1.6)
	var passer: Footballer = m.controlled
	var target: Footballer = m.home[1]
	m.ball.reset_at(passer.global_position + passer.locomotion.forward() * 0.45 + Vector3(0, 0.11, 0))
	await physics_frames(3)
	var to: Vector3 = KickModel.flat(target.global_position - passer.global_position).normalized()
	passer.locomotion.yaw = Locomotion.yaw_from_dir(to)
	var res: KickModel.KickResult = passer.ball_handler.perform_pass(to, 0.35, false)
	await physics_frames(2)
	check(res.target == target, "el pase va al companero apuntado")
	check(m.controlled == target, "el control de la persona pasa al receptor al pasar")
	check(target.has_incoming_pass(), "el receptor sabe que la pelota va hacia el")
	var d0: float = KickModel.flat(target.global_position - m.ball.global_position).length()
	await wait_seconds(0.5)
	var moved: float = KickModel.flat(target.global_position - target.incoming_pass_point).length()
	note("receptor: a %.1f m de la pelota al pasar; tras 0.5 s esta a %.1f m del punto de encuentro" % [d0, moved])
	check(target.locomotion.speed > 0.5 or target.has_ball(), "el receptor sale al encuentro (%.2f m/s) aunque la persona no toque el joystick" % target.locomotion.speed)
	check(not passer.is_human_controlled, "el pasador queda en manos de la IA")

# --- Defensa ---------------------------------------------------------------------------------------------------

func test_human_press_contains_but_does_not_steal_by_holding_the_button() -> void:
	var ctx: MatchContext = await make_match(Vector3(0.5, 0.11, 0.0))
	var att_src := ScriptedInput.new()
	var att: Footballer = add_player(ctx, 0, Vector3(0.0, 0.0, 0.0), 50, att_src)
	var def_src := ScriptedInput.new()
	var def: Footballer = add_player(ctx, 1, Vector3(3.0, 0.0, 0.0), 50, def_src)
	def.is_human_controlled = true
	def_src.press_held = true
	var tackles := [0]
	ctx.event_emitted.connect(func(e: GameEvent) -> void:
		if e.type == GameEvent.Type.TACKLE_WON or e.type == GameEvent.Type.TACKLE_FAILED:
			tackles[0] += 1)
	await wait_seconds(4.0)
	var d: float = KickModel.flat(def.global_position - ctx.ball.global_position).length()
	note("presion humana mantenida 4 s: defensor a %.2f m de la pelota, entradas %d" % [d, tackles[0]])
	check(d < 2.0, "la presion cierra la distancia (%.2f m)" % d)
	check(tackles[0] == 0, "mantener la presion no roba la pelota sola (%d entradas)" % tackles[0])
	def_src.tackle()
	await physics_frames(3)
	check(tackles[0] >= 1 or def.last_tackle != &"", "con el boton ENTRADA si entra (%s)" % def.last_tackle)

func test_tackle_button_choices_stand_slide_whiff() -> void:
	var ctx: MatchContext = await make_match(Vector3(0.5, 0.11, 0.0))
	var att: Footballer = add_player(ctx, 0, Vector3(0.0, 0.0, 0.0), 50)
	var def_src := ScriptedInput.new()
	var def: Footballer = add_player(ctx, 1, Vector3(1.2, 0.0, 0.0), 50, def_src, true)
	def.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(-1, 0, 0))
	await physics_frames(5)
	def_src.tackle()
	await physics_frames(2)
	check(def.last_tackle == &"stand", "pelota al alcance: entrada de pie (%s)" % def.last_tackle)
	# Lejos y parado: entrada al aire (pierde velocidad y queda un instante sin poder repetir).
	def.place_at(Vector3(6.0, 0.0, 0.0), Locomotion.yaw_from_dir(Vector3(-1, 0, 0)))
	await wait_seconds(1.0)
	def_src.tackle()
	await physics_frames(2)
	check(def.last_tackle == &"whiff", "fuera de alcance: entrada al aire (%s)" % def.last_tackle)

func test_shoulder_charge_when_running_side_by_side() -> void:
	PackLibrary.reload()
	var ctx: MatchContext = await make_match(Vector3(0.6, 0.11, 0.0))
	var att: Footballer = add_player(ctx, 0, Vector3(0.0, 0.0, 0.0), 50, null, true)
	var def: Footballer = add_player(ctx, 1, Vector3(-0.2, 0.0, 0.75), 70, null, true)
	var yaw: float = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	for p in [att, def]:
		p.locomotion.yaw = yaw
		p.locomotion.velocity = Vector3(4.5, 0, 0)
		p.locomotion.speed = 4.5
	check(def.actions._alongside(att), "hombro con hombro a la carrera se detecta")
	var wins: int = 0
	for i in 20:
		def.actions.rng.seed = 100 + i
		def.actions.reset()
		att.actions.reset()
		if def.actions.shoulder_charge(att):
			wins += 1
	note("cargas con el hombro (fuerza 70 vs 50): %d de 20 ganadas" % wins)
	check(wins > 6 and wins < 20, "la carga depende de la fuerza y del azar (%d/20)" % wins)

# --- Tiro ----------------------------------------------------------------------------------------------------

func test_placed_shot_is_slower_more_accurate_and_curled() -> void:
	var ctx: MatchContext = await make_match(Vector3(10.0, 0.11, 3.0))
	var p: Footballer = add_player(ctx, 0, Vector3(9.5, 0.0, 3.0), 60)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var placed: KickModel.KickResult = ShotAssist.compute(p, ctx, Vector3(1, 0, -0.3).normalized(), 0.15, false, rng, 0.6)
	var power: KickModel.KickResult = ShotAssist.compute(p, ctx, Vector3(1, 0, -0.3).normalized(), 0.95, false, rng, 0.6)
	note("colocado %.1f m/s sigma %.2f, potente %.1f m/s sigma %.2f, punto %s" % [placed.velocity.length(), placed.sigma_deg, power.velocity.length(), power.sigma_deg, str(placed.aim_point)])
	check(String(placed.kind) == "placed_shot" and String(power.kind) == "power_shot", "tipos: %s / %s" % [placed.kind, power.kind])
	check(placed.velocity.length() < power.velocity.length(), "el colocado es mas lento")
	check(placed.sigma_deg < power.sigma_deg, "y mas preciso")
	check(placed.aim_point.z < 0.0, "va al palo lejano (z %.2f desde z=3)" % placed.aim_point.z)

# --- Clips antes sueltos ---------------------------------------------------------------------------------------

## Cada clip que antes solo estaba en la galeria tiene ahora un uso en el juego (constante en el codigo de juego) y
## existe en las librerias.
func test_every_former_gallery_clip_is_wired_into_gameplay() -> void:
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("no existe la libreria del pack")
		return
	var former := ["goalkeeper_directing", "goalkeeper_directing_2", "goalkeeper_idle_2", "goalkeeper_miss", "goalkeeper_placing_ball",
		"goalkeeper_placing_ball_2", "Chip", "Dribble_2", "Soccer_Idle", "receive_soccerball", "soccer_penalty_kick", "strike_foward_jog",
		"throw_in", "Defender", "Jogging_Stumble", "Defender_2", "fallen_idle", "Idle_To_Sprint", "Jogging", "Jogging_inplace", "Running",
		"Running_Tired", "Running_inplace", "Sprint", "Sprint_To_Backslide", "Sprint_To_Backslide_inplace", "Sprint_Turn", "Strafe_3",
		"Strafe_3_inplace", "Two_Cycle_Sprint", "Two_Cycle_Sprint_inplace", "Walking_7", "jog_backward", "jog_backward_diagonal",
		"jog_backward_diagonal_2", "jog_forward", "jog_forward_diagonal", "jog_forward_diagonal_2", "jog_strafe_left", "jog_strafe_right"]
	var text: String = ""
	for dir in ["res://scripts/player", "res://scripts/goalkeeper", "res://scripts/gameplay", "res://scripts/animation", "res://scripts/ai"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") and f != "practice_scene.gd":
				text += FileAccess.get_file_as_string(dir + "/" + f)
	var missing: Array = []
	for id in former:
		if not PackLibrary.has_clip(StringName(id)) or not text.contains("&\"%s\"" % id):
			missing.append(id)
	note("%d clips antes solo en la galeria; sin uso en el juego: %s" % [former.size(), str(missing)])
	check(former.size() == 40, "son los 40 clips sueltos")
	check(missing.is_empty(), "todos tienen disparador en el juego (faltan: %s)" % str(missing))

func test_referee_follows_play_with_root_motion_twins() -> void:
	PackLibrary.reload()
	if not PackLibrary.available():
		skip("no existe la libreria del pack")
		return
	var m: MatchScene = load("res://scenes/main/match.tscn").instantiate()
	m.duration_seconds = 0.0
	m.intro_seconds = 0.0
	spawn(m)
	await wait_seconds(1.5)
	var ref: Referee = m.referee
	var x0: float = ref.position.x
	m.ball.reset_at(Vector3(14.0, 0.11, -3.0))
	await wait_seconds(5.0)
	note("arbitro: de x=%.1f a x=%.1f, %.1f m recorridos, gemelos usados %s" % [x0, ref.position.x, ref.travelled, str(ref.twins_used.keys())])
	check(ref.position.x > x0 + 6.0, "el arbitro sigue la jugada por la banda")
	check(ref.twins_used.size() >= 1, "se mueve con los gemelos con raiz del pack")
	check(absf(ref.position.z) > m.pitch.config.half_width(), "corre por fuera de la linea")
