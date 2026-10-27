extends TestCase
## Sala de practica: la galeria cubre TODOS los clips del pack (campo y arquero), cada uno se reproduce y los malabares
## mantienen la pelota en el aire solo con impulsos hacia los puntos de contacto medidos de los clips.

func _skip_if_missing() -> bool:
	PackLibrary.reload()
	if not PackLibrary.available() or PackLibrary.keeper() == null:
		skip("faltan assets/animations/pack_clips.res / pack_keeper.res (generar con tools/animation_pack/build_pack_library.tscn)")
		return true
	return false

func _make_scene() -> PracticeScene:
	var s := PracticeScene.new()
	spawn(s)
	await physics_frames(3)
	return s

func test_gallery_lists_every_clip_with_a_known_role() -> void:
	if _skip_if_missing():
		return
	var ids: Array[StringName] = PracticeScene.clip_ids()
	var g: Dictionary = PracticeScene.grouped()
	var total: int = 0
	for role in g:
		total += g[role].size()
		check(PracticeScene.ROLE_NAMES.has(role), "el rol '%s' tiene nombre de galeria" % role)
	note("%d animaciones sin espejos en %d grupos" % [ids.size(), g.size()])
	check(total == ids.size(), "todos los clips pertenecen a un grupo (%d de %d)" % [total, ids.size()])
	check(ids.size() >= 133, "al menos las 133 animaciones del pack (hay %d)" % ids.size())
	for must in [&"kick_up_soccerball", &"stall_soccerball", &"goalkeeper_drop_kick", &"soccer_tackle", &"Soccer_Spin"]:
		check(ids.has(must), "la galeria incluye '%s'" % must)

func test_every_clip_plays_and_moves_the_root_along_its_path() -> void:
	if _skip_if_missing():
		return
	var s: PracticeScene = await _make_scene()
	var failed: Array[String] = []
	var ids: Array[StringName] = PracticeScene.clip_ids()
	for id in ids:
		var d: float = s.play(id)
		if d <= 0.0 or s.visual.current_action != id:
			failed.append(String(id))
		await physics_frames(2)
	check(failed.is_empty(), "todos los clips se reproducen (fallan: %s)" % ", ".join(failed))
	note("%d clips reproducidos en la sala de practica" % ids.size())
	# Un clip con desplazamiento de raiz mueve al personaje lo que dice su metadato.
	s.mirror = false
	s.play(&"soccer_tackle")
	var start: Vector3 = s.stage.position
	await wait_seconds(PackLibrary.clip(&"soccer_tackle").length + 0.2)
	var moved: float = Vector2(s.stage.position.x - start.x, s.stage.position.z - start.z).length()
	var expected: float = (PackLibrary.meta(&"soccer_tackle")["root_total"] as Vector2).length()
	check_near(moved, expected, 0.35, "la entrada desliza lo que mide su raiz (%.2f m)" % expected)
	# Con la raiz apagada el personaje se queda en su sitio.
	s.root_motion = false
	s.play(&"soccer_tackle")
	start = s.stage.position
	await wait_seconds(0.8)
	check(Vector2(s.stage.position.x - start.x, s.stage.position.z - start.z).length() < 0.01, "sin «Raíz» el personaje no se desplaza")

func test_mirror_toggle_plays_the_mirrored_clip() -> void:
	if _skip_if_missing():
		return
	var s: PracticeScene = await _make_scene()
	s.mirror = true
	s.play(&"soccer_tackle")
	check(s.current_clip == &"soccer_tackle_mirror", "con «Espejo» se reproduce la variante espejo")

func test_juggling_keeps_the_ball_in_the_air_with_impulses_only() -> void:
	if _skip_if_missing():
		return
	var s: PracticeScene = await _make_scene()
	s.toggle_juggle()
	var max_h: float = 0.0
	var max_d: float = 0.0
	for i in 60 * 14:
		await tree.physics_frame
		max_h = maxf(max_h, s.ball.global_position.y)
		var d: Vector3 = s.ball.global_position - s.stage.global_position
		max_d = maxf(max_d, Vector2(d.x, d.z).length())
	note("malabares: %d toques en 14 s, altura maxima %.2f m, alejamiento maximo %.2f m, clip actual %s" % [s.juggler.count, max_h, max_d, s.juggler._step.get("clip", &"")])
	check(s.juggler.count >= 6, "al menos 6 toques encadenados en 14 s (hubo %d)" % s.juggler.count)
	check_range(max_h, 0.6, 3.0, "la pelota sube a una altura de jueguitos")
	check(max_d < 2.5, "la pelota no se aleja del jugador (%.2f m)" % max_d)
	s.toggle_juggle()
	check(not s.juggler.running, "los malabares se detienen")
