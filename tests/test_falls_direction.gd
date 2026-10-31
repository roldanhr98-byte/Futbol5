extends TestCase
## Modo 4: las caidas y los trastabillones van hacia donde los llevan la inercia del cuerpo y el empujon del contacto
## (PlayerActions._directed_pick sobre root_total de los clips convertidos), no a un clip al azar: parado y golpeado de
## frente cae hacia atras o en el sitio (nunca encima del rival), corriendo y golpeado por detras cae hacia adelante, y un
## golpe de costado a la carrera lo desvia hacia el lado contrario al rival.

func gameplay_mode() -> int:
	return 4

func _skip_if_missing() -> bool:
	if not ResourceLoader.exists(PackLibrary.JSON_FIELD_PATH):
		skip("no existe assets/animations/json_clips.res")
		return true
	return false

## Un jugador mirando a +X que corre `run` (0 = parado) y recibe un contacto con empuje `push` (del rival al jugador).
## Devuelve el recorrido del cuerpo durante la caida en el marco del jugador (x = adelante, y = derecha), el clip y el
## sentido esperado.
func _fall(seed_i: int, run: bool, push: Vector3, kind: StringName = &"hit") -> Dictionary:
	var ctx: MatchContext = await make_match(Vector3(15.0, 0.11, 9.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-12.0, 0.0, 0.0), 60, src, true)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	p.actions.rng.seed = 700 + seed_i
	await physics_frames(5)
	if run:
		src.move = Vector2(1, 0)
		await physics_frames(70)
	var f: Vector3 = p.locomotion.forward()
	var r: Vector3 = p.locomotion.right()
	var want: Vector2 = p.actions.push_dir_local(push)
	var start: Vector3 = p.global_position
	var speed: float = p.locomotion.speed
	src.move = Vector2.ZERO
	p.actions.suffer_contact(kind, push)
	var clip: StringName = p.actions.motion.clip if p.actions.active() else &""
	var travel := Vector3.ZERO
	for i in 150:
		await tree.physics_frame
		if p.actions.kind == &"fall":
			travel = KickModel.flat(p.global_position - start)
	cleanup()
	return {"travel": Vector2(travel.dot(f), travel.dot(r)), "clip": clip, "want": want, "speed": speed}

func test_standing_player_hit_from_the_front_never_falls_onto_the_attacker() -> void:
	if _skip_if_missing():
		return
	var bad: int = 0
	var n: int = 6
	for i in n:
		# El rival esta delante (en +X): el empujon va hacia -X.
		var r: Dictionary = await _fall(i, false, Vector3(-1, 0, 0))
		var t: Vector2 = r["travel"]
		note("parado, de frente: %s recorrido adelante %.2f lado %.2f" % [r["clip"], t.x, t.y])
		if t.x > 0.35:
			bad += 1
	check(bad == 0, "parado y golpeado de frente cae hacia atras o en el sitio (%d de %d hacia el rival)" % [bad, n])

func test_running_player_hit_from_behind_falls_forward() -> void:
	if _skip_if_missing():
		return
	var bad: int = 0
	var n: int = 6
	for i in n:
		var r: Dictionary = await _fall(10 + i, true, Vector3(1, 0, 0))
		var t: Vector2 = r["travel"]
		note("corriendo %.1f m/s, por detras: %s recorrido adelante %.2f lado %.2f" % [r["speed"], r["clip"], t.x, t.y])
		if t.x < 0.3:
			bad += 1
	check(bad == 0, "a la carrera y golpeado por detras cae hacia adelante (%d de %d no)" % [bad, n])

func test_side_hit_while_running_deflects_the_fall_away_from_the_attacker() -> void:
	if _skip_if_missing():
		return
	var bad: int = 0
	var n: int = 8
	for i in n:
		# Rival a la izquierda o a la derecha (yaw 0 mira a -Z, asi que mirando a +X la derecha es +Z).
		var from_left: bool = i % 2 == 0
		var push := Vector3(0, 0, 1) if from_left else Vector3(0, 0, -1)
		var r: Dictionary = await _fall(20 + i, true, push)
		var t: Vector2 = r["travel"]
		var w: Vector2 = r["want"]
		note("corriendo, golpe desde la %s: %s recorrido (%.2f, %.2f), esperado (%.2f, %.2f)" % ["izquierda" if from_left else "derecha", r["clip"], t.x, t.y, w.x, w.y])
		# El recorrido lateral no va hacia el rival (tolerancia: caidas casi rectas valen).
		if t.y * w.y < 0.0 and absf(t.y) > 0.3:
			bad += 1
	check(bad == 0, "golpe de costado: la caida no va hacia el lado del rival (%d de %d si)" % [bad, n])

func test_directed_pick_follows_the_expected_direction() -> void:
	if _skip_if_missing():
		return
	var ctx: MatchContext = await make_match(Vector3(15.0, 0.11, 9.0))
	var p: Footballer = add_player(ctx, 0, Vector3(-12.0, 0.0, 0.0), 60, ScriptedInput.new(), true)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	await physics_frames(3)
	var pool: Array[StringName] = []
	for id in PackLibrary.by_role(&"stumble"):
		if not String(id).ends_with("_mirror"):
			pool.append(id)
	var misaligned: int = 0
	for push in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var want: Vector2 = p.actions.push_dir_local(push)
		for k in 8:
			var c: StringName = p.actions._directed_pick(pool, push)
			var rt: Vector2 = PackLibrary.meta(StringName(String(c).trim_suffix("_mirror"))).get("root_total", Vector2.ZERO)
			if String(c).ends_with("_mirror"):
				rt.y = -rt.y
			if rt.length() >= PlayerActions.DIRECTED_IN_PLACE and rt.normalized().dot(want.normalized()) < PlayerActions.DIRECTED_MIN_COS:
				misaligned += 1
	note("trastabillones disponibles: %d" % pool.size())
	check(pool.size() > 0 and misaligned == 0, "el trastabillon elegido va en el sentido del empujon (%d desalineados de 32)" % misaligned)
	cleanup()

## Junto a la banda, un golpe que empuja hacia fuera no elige una caida cuyo recorrido terminaria fuera de la cancha
## (+ PlayerActions.LAND_MARGIN): _room_ahead solo mira hacia adelante. (En la cancha de prueba el borde frena al cuerpo,
## asi que se comprueba la eleccion: hay candidatas que terminarian fuera y ninguna sale elegida.)
func test_fall_next_to_the_sideline_never_picks_a_clip_that_ends_outside() -> void:
	if _skip_if_missing():
		return
	var ctx: MatchContext = await make_match(Vector3(15.0, 0.11, -9.0))
	var hw: float = ctx.pitch.config.half_width()
	var p: Footballer = add_player(ctx, 0, Vector3(-12.0, 0.0, hw - 0.6), 60, ScriptedInput.new(), true)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	await physics_frames(3)
	var pool: Array[StringName] = []
	var outside: int = 0
	for role in [&"fall", &"fall_hit", &"trip"]:
		for id in PackLibrary.by_role(role):
			if String(id).ends_with("_mirror"):
				continue
			pool.append(id)
			if not p.actions._lands_inside(id) or not p.actions._lands_inside(StringName(String(id) + "_mirror")):
				outside += 1
	var bad: int = 0
	for k in 40:
		var c: StringName = p.actions._directed_pick(pool, Vector3(0, 0, 1))
		if c != &"" and not p.actions._lands_inside(c):
			bad += 1
	note("junto a la banda: %d caidas, %d terminarian fuera en alguna version; elegidas fuera %d de 40" % [pool.size(), outside, bad])
	check(outside > 0 and bad == 0, "nunca elige una caida que termine fuera de la cancha (%d de 40)" % bad)
	cleanup()
