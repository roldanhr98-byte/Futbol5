extends TestCase
## Modos 2 y 3 de jugabilidad. Modo 2 (Tuning.gameplay_mode = 2): golpeos, penal, saque de banda, tarjeta del arbitro,
## festejos y modelo propio (Newton, MocapRig) del «Mocap Pack 05 Soccer»
## (assets/animations/mocap_clips.res, convertido con tools/animation_pack/build_mocap_library.tscn). Se comprueba que la
## libreria tiene los clips con su contacto medido, que en modo 2 el pase y el tiro usan el pase de interior y el tiro
## potente de la captura con el pie de verdad en la pelota (a cualquier velocidad), que el penal usa su carrera y que el
## modo 1 sigue con los clips de siempre. Modo 3: solo el modelo y los clips de Tripo, con la patada procedural.

const START := Vector3(-10.0, 0.0, 0.0)

func _skip_if_missing() -> bool:
	PackLibrary.reload()
	if not PackLibrary.available() or not PackLibrary.has_clip(&"mc_side_foot_pass"):
		skip("no existe assets/animations/mocap_clips.res (generar con tools/animation_pack/build_mocap_library.tscn)")
		return true
	return false

func _set_mode(m: int) -> void:
	Tuning.gameplay_mode = m

func test_library_has_the_mocap_clips_with_measured_contacts() -> void:
	if _skip_if_missing():
		return
	var ids: Array = []
	for id in PackLibrary.field().get_animation_list():
		if String(id).begins_with("mc_"):
			ids.append(id)
	note("clips de mocap: %d (%s)" % [ids.size(), ", ".join(ids)])
	check(ids.size() >= 20, "la libreria trae los clips del pack de mocap (%d)" % ids.size())
	for k in [&"mc_side_foot_pass", &"mc_side_foot_pass_mirror", &"mc_power_kick", &"mc_power_kick_mirror", &"mc_penalty_kick", &"mc_penalty_kick_mirror"]:
		var m: Dictionary = PackLibrary.meta(k)
		check(m.has("contact"), "%s tiene el contacto del pie medido" % k)
		if m.has("contact"):
			var c: Dictionary = m["contact"]
			check(float(c["speed"]) > 3.0 and (c["pos"] as Vector3).x > 0.1 and (c["pos"] as Vector3).y < 0.2, "%s: el pie golpea por delante y a ras de piso (%s, %.1f m/s)" % [k, str(c["pos"]), c["speed"]])
	check(float(PackLibrary.meta(&"mc_power_kick")["contact"]["speed"]) > float(PackLibrary.meta(&"mc_side_foot_pass")["contact"]["speed"]) * 1.5, "el tiro potente lleva el pie mucho mas rapido que el pase de interior")

func test_mode_switch_picks_the_clips() -> void:
	if _skip_if_missing():
		return
	var prev: int = Tuning.gameplay_mode
	_set_mode(1)
	var m1: Array = AnimationCatalog.kick_candidates(&"pass").map(func(c: Dictionary) -> String: return String(c["clip"]))
	_set_mode(2)
	var m2p: Array = AnimationCatalog.kick_candidates(&"pass").map(func(c: Dictionary) -> String: return String(c["clip"]))
	var m2s: Array = AnimationCatalog.kick_candidates(&"shot").map(func(c: Dictionary) -> String: return String(c["clip"]))
	var cel: Dictionary = AnimationCatalog.resolve(&"celebrate_scorer", true)
	_set_mode(prev)
	note("modo 1 pase %s | modo 2 pase %s, tiro %s, festejo %s" % [str(m1), str(m2p), str(m2s), str(cel)])
	check(not m1.is_empty() and m1.all(func(c: String) -> bool: return not c.begins_with("mc_")), "modo 1: los clips de siempre")
	check(m2p.has("mc_side_foot_pass") and m2p.has("mc_side_foot_pass_mirror"), "modo 2: pase de interior de la captura, con las dos piernas")
	check(m2s.has("mc_power_kick") and m2s.has("mc_power_kick_mirror"), "modo 2: tiro potente de la captura, con las dos piernas")
	check(String(cel.get("clip", "")).begins_with("mc_celebration"), "modo 2: festejo de la captura (%s)" % str(cel))

## Conduce `run_s` s con el joystick a `stick` (y sprint) y pulsa pase o tiro; devuelve el golpeo.
func _kick_while_running(action: StringName, stick: float, sprint: bool, run_s: float) -> Dictionary:
	var ctx: MatchContext = await make_match(START + Vector3(0.6, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, START, 60, src, true)
	p.is_human_controlled = true
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	src.move = Vector2(stick, 0.0)
	src.sprint = sprint
	await wait_seconds(run_s)
	var ev := {}
	ctx.event_emitted.connect(func(e: GameEvent) -> void:
		if (e.type == GameEvent.Type.PASS or e.type == GameEvent.Type.SHOT) and ev.is_empty():
			ev["data"] = e.data
			ev["speed"] = float(e.data.get("speed", 0.0)))
	if action == &"pass":
		src.hold_pass()
	else:
		src.hold_shoot()
	await physics_frames(12)
	if action == &"pass":
		src.release_pass()
	else:
		src.release_shoot()
	await wait_seconds(1.6)
	var out := {"kicked": not ev.is_empty(), "stats": p.ball_handler.kick_stats.duplicate(), "speed0": p.locomotion.speed}
	if not ev.is_empty():
		out["clip"] = String(ev["data"].get("clip", ""))
		out["foot"] = float(ev["data"].get("foot_distance", -1.0))
		out["latency"] = float(ev["data"].get("latency", -1.0))
	cleanup()
	return out

func test_mode2_passes_and_shots_connect_at_every_speed() -> void:
	if _skip_if_missing():
		return
	var prev: int = Tuning.gameplay_mode
	_set_mode(2)
	var done := 0
	var total := 0
	for action in [&"pass", &"shot"]:
		for cfg in [["parado", 0.0, false, 0.6], ["trote", 0.7, false, 1.4], ["trote", 0.7, false, 1.7], ["carrera", 1.0, false, 1.5], ["carrera", 1.0, false, 1.9], ["sprint", 1.0, true, 1.8]]:
			var r: Dictionary = await _kick_while_running(action, cfg[1], cfg[2], cfg[3])
			_set_mode(2)
			total += 1
			var line: String = "%s %s (%.1f m/s, a los %.1f s)" % [action, cfg[0], r["speed0"], cfg[3]]
			if r["kicked"]:
				done += 1
				note("%s: clip %s, pie a %.3f m de la pelota, latencia %.2f s" % [line, r["clip"], r["foot"], r["latency"]])
				check(String(r["clip"]).begins_with("mc_"), "%s: golpea con el clip de la captura (%s)" % [line, r["clip"]])
				check(r["foot"] >= 0.0 and r["foot"] <= Tuning.player.kick_contact_radius, "%s: el pie esta en la pelota al golpear (%.3f m)" % [line, r["foot"]])
			else:
				note("%s: SIN golpeo %s" % [line, str(r["stats"])])
			check(int(r["stats"].get("missed", 0)) == 0, "%s: ninguna patada en falso (%s)" % [line, str(r["stats"])])
	_set_mode(prev)
	note("modo 2: %d de %d golpeos ejecutados" % [done, total])
	check(done >= total - 1, "modo 2: casi todas las pulsaciones acaban en golpeo (%d de %d)" % [done, total])

func test_mode2_penalty_uses_the_mocap_run_up() -> void:
	if _skip_if_missing():
		return
	var prev: int = Tuning.gameplay_mode
	_set_mode(2)
	var m: MatchScene = load("res://scenes/main/match.tscn").instantiate()
	m.duration_seconds = 0.0
	m.auto_switch = false
	m.intro_seconds = 0.0
	spawn(m)
	await physics_frames(3)
	m.home[0].input_source = AIInput.new(3, 0.6)
	m.home[0].is_human_controlled = false
	m.controlled = null
	await wait_seconds(1.5)
	var hl: float = m.pitch.config.half_length()
	var victim: Footballer = m.home[1]
	victim.place_at(Vector3(hl - 3.0, 0.0, 1.0), 0.0)
	await physics_frames(2)
	m.ctx.emit_event(GameEvent.make(GameEvent.Type.FOUL, m.away[1].actor_id, 1, {"victim": victim.actor_id, "pos": [hl - 3.0, 1.0]}))
	await physics_frames(2)
	var sp: SetPiece = m.manager.active_set_piece
	var shots := []
	m.ctx.event_emitted.connect(func(e: GameEvent) -> void:
		if e.type == GameEvent.Type.SHOT:
			shots.append(e))
	var resumed := false
	for i in 360:
		await tree.physics_frame
		if m.manager.state == MatchManager.State.PLAYING:
			resumed = true
			break
	note("penal en modo 2: clip %s, resultado %s, disparos %d" % [sp.clip if sp != null else "-", sp.result if sp != null else "-", shots.size()])
	_set_mode(prev)
	check(m.manager.set_piece_kind == "penalty" or resumed, "hay penal")
	check(resumed and shots.size() == 1, "el penal se ejecuta con un disparo (%d)" % shots.size())
	if sp != null and m.home[0].visual.uses_pack:
		check(String(sp.clip).begins_with("mc_penalty_kick"), "con el penal de la captura, con su carrera (%s)" % sp.clip)
	cleanup()

## Partido real en modo `mode`, todos con IA.
func _match_scene(mode: int) -> MatchScene:
	_set_mode(mode)
	var m: MatchScene = load("res://scenes/main/match.tscn").instantiate()
	m.duration_seconds = 0.0
	m.auto_switch = false
	m.intro_seconds = 0.0
	spawn(m)
	await physics_frames(3)
	m.home[0].input_source = AIInput.new(3, 0.6)
	m.home[0].is_human_controlled = false
	m.controlled = null
	await wait_seconds(1.5)
	return m

func test_mode2_draws_the_mocap_model_following_the_skeleton() -> void:
	if _skip_if_missing():
		return
	if not MocapRig.available():
		skip("no existe assets/characters/mocap/mocap_player.scn (generar con tools/animation_pack/build_mocap_character.tscn)")
		return
	var prev: int = Tuning.gameplay_mode
	var m: MatchScene = await _match_scene(2)
	var players: Array = m.home + m.away
	var with_rig: int = players.filter(func(p: Footballer) -> bool: return p.visual.mocap_rig != null).size()
	var keepers_rig: int = m.keepers.filter(func(k: Goalkeeper) -> bool: return k.visual != null and k.visual.mocap_rig != null).size()
	note("modo 2: %d de %d jugadores y %d arqueros con el modelo del mocap" % [with_rig, players.size(), keepers_rig])
	check(with_rig == players.size(), "todos los jugadores se ven con el modelo del mocap (%d de %d)" % [with_rig, players.size()])
	check(keepers_rig == m.keepers.size(), "los arqueros tambien (%d)" % keepers_rig)
	# El modelo copia la pose: pies y manos de Newton donde estan los del futbolista (medido justo despues de cada copia,
	# que es lo que se dibuja), y la cabeza cerca.
	var worst := {"limb": 0.0, "head": 0.0, "where": ""}
	for p in players:
		var r: MocapRig = p.visual.mocap_rig
		if r == null:
			continue
		r.src.skeleton_updated.connect(func() -> void:
			for pair in [["mixamorig_LeftFoot", "LeftFoot"], ["mixamorig_RightFoot", "RightFoot"], ["mixamorig_LeftHand", "LeftHand"], ["mixamorig_RightHand", "RightHand"], ["mixamorig_Head", "Head"]]:
				var a: Vector3 = r.src.global_transform * r.src.get_bone_global_pose(r.src.find_bone(pair[0])).origin
				var b: Vector3 = r.dst.global_transform * r.dst.get_bone_global_pose(r.dst.find_bone(pair[1])).origin
				var key: String = "head" if pair[1] == "Head" else "limb"
				if a.distance_to(b) > float(worst[key]):
					worst[key] = a.distance_to(b)
					if key == "limb":
						worst["where"] = "%s %s" % [p.name, pair[1]])
	for k in 6:
		await wait_seconds(0.25)
		var vis: bool = players.all(func(p: Footballer) -> bool: return p.visual.mesh_instances.all(func(mi: MeshInstance3D) -> bool: return not mi.visible))
		check(vis, "el modelo de Tripo no se dibuja en modo 2")
	note("separacion maxima entre los dos esqueletos: pies/manos %.3f m (%s), cabeza %.3f m" % [worst["limb"], worst["where"], worst["head"]])
	check(float(worst["limb"]) < 0.08, "pies y manos de Newton donde estan los del futbolista (%.3f m)" % worst["limb"])
	check(float(worst["head"]) < 0.25, "la cabeza acompana (%.3f m)" % worst["head"])
	_set_mode(prev)
	cleanup()

func test_mode2_throw_in_and_referee_card() -> void:
	if _skip_if_missing():
		return
	var prev: int = Tuning.gameplay_mode
	var m: MatchScene = await _match_scene(2)
	var hw: float = m.pitch.config.half_width()
	m.ball.reset_at(Vector3(3.0, 0.11, hw + 0.4))
	m.ball.register_touch(m.away[0])
	await physics_frames(3)
	var sp: SetPiece = m.manager.active_set_piece
	check(sp != null and m.manager.set_piece_kind == "throw_in", "saque de banda")
	if sp == null:
		_set_mode(prev)
		return
	var release_y: float = -1.0
	for i in 6 * 60:
		await tree.physics_frame
		if release_y < 0.0 and not m.ball.is_held():
			release_y = m.ball.global_position.y
		if m.manager.state == MatchManager.State.PLAYING:
			break
	note("saque en modo 2: clip %s, resultado %s, sale a %.2f m" % [sp.clip, sp.result, release_y])
	check(m.manager.state == MatchManager.State.PLAYING, "el juego se reanuda tras el saque")
	if m.home[0].visual.uses_pack:
		check(sp.clip == SetPiece.MOCAP_THROW_CLIP, "con el saque de la captura (%s)" % sp.clip)
	check(release_y > 1.2, "la pelota sale por encima de la cabeza (%.2f m)" % release_y)
	# Falta: el arbitro muestra la tarjeta de la captura.
	var ref: Referee = m.find_children("*", "Referee", true, false)[0] if not m.find_children("*", "Referee", true, false).is_empty() else null
	if ref != null and ref.visual != null and ref.visual.uses_pack:
		var victim: Footballer = m.home[1]
		m.ctx.emit_event(GameEvent.make(GameEvent.Type.FOUL, m.away[1].actor_id, 1, {"victim": victim.actor_id, "pos": [0.0, 1.0]}))
		var clip := ""
		for i in 60:
			await tree.physics_frame
			if ref.visual.is_action_playing():
				clip = String(ref.visual.current_action)
				break
		note("falta en modo 2: el arbitro reproduce %s" % clip)
		check(clip == "mc_yellow_card", "el arbitro muestra la tarjeta amarilla (%s)" % clip)
	_set_mode(prev)
	cleanup()

func test_mode3_is_tripo_only_and_kicks_connect() -> void:
	var prev: int = Tuning.gameplay_mode
	_set_mode(3)
	var done := 0
	for action in [&"pass", &"shot"]:
		var ctx: MatchContext = await make_match(START + Vector3(0.6, 0.11, 0.0))
		var src := ScriptedInput.new()
		var p: Footballer = add_player(ctx, 0, START, 60, src, true)
		p.is_human_controlled = true
		check(not p.visual.uses_pack and p.visual.mocap_rig == null, "modo 3: modelo y clips de Tripo, sin pack ni mocap")
		var ev := []
		ctx.event_emitted.connect(func(e: GameEvent) -> void:
			if e.type == GameEvent.Type.PASS or e.type == GameEvent.Type.SHOT:
				ev.append(e))
		src.move = Vector2(0.7, 0.0)
		await wait_seconds(1.2)
		if action == &"pass":
			src.hold_pass()
		else:
			src.hold_shoot()
		await physics_frames(12)
		if action == &"pass":
			src.release_pass()
		else:
			src.release_shoot()
		await wait_seconds(1.4)
		note("modo 3 %s: eventos %d, %s" % [action, ev.size(), str(p.ball_handler.kick_stats)])
		check(ev.size() >= 1, "modo 3: el %s sale" % action)
		check(int(p.ball_handler.kick_stats.get("missed", 0)) == 0, "modo 3: sin patadas en falso")
		done += ev.size()
		cleanup()
	_set_mode(prev)
