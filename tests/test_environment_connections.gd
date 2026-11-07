extends TestCase
## Cada ruta ambiental se invoca en su actor real y exige su condicion; no basta con estar en el inventario.

func test_each_environment_route_invokes_the_corresponding_actor() -> void:
	var ctx: MatchContext = await make_match(Vector3.ZERO)
	var presentation := MatchPresentation.new()
	spawn(presentation)
	presentation.setup(ctx)
	presentation.set_physics_process(false)
	check(presentation.routes.size() == 204, "204 tramos ambientales y de presentacion investigados")
	for id in presentation.routes:
		var route: Dictionary = presentation.routes[id]
		check(not presentation.request(StringName(id), "condicion_incorrecta", 0), "%s no entra sin su condicion" % id)
		check(presentation.request(StringName(id), route["context"], 0), "%s invocado por su consumidor real" % id)
		var slot: Dictionary = presentation.actors[route["actor"] + "0"]
		check((slot["visual"] as FootballerVisual).current_action == StringName(id), "%s ocupa la pose del actor correcto" % id)
		check(AnimDB.candidates(StringName(route["actor"] + "/" + route["context"])).has(StringName(id)), "%s resuelve su accion en el catalogo central" % id)
	check(presentation.invocations.size() == 204, "204 invocaciones comprobadas individualmente")
	for id in presentation.routes:
		var mirror := StringName(id + "_mirror")
		if PackLibrary.has_clip(mirror):
			check(presentation.request(mirror, presentation.routes[id]["context"], 0), "%s espejo disponible en su mismo contexto" % mirror)

func test_match_events_select_environment_actors_without_touching_the_ball() -> void:
	var ctx: MatchContext = await make_match(Vector3.ZERO)
	var presentation := MatchPresentation.new()
	spawn(presentation)
	presentation.setup(ctx)
	var before: Vector3 = ctx.ball.global_position
	ctx.emit_event(GameEvent.make(GameEvent.Type.KICKOFF, -1, 0))
	check(presentation.actors.has("manager0") and presentation.actors.has("crowd1"), "el reinicio activa tecnicos y publico")
	ctx.emit_event(GameEvent.make(GameEvent.Type.GOAL, -1, 0))
	check(presentation.actors.has("mascot0"), "el gol activa la mascota del equipo que convierte")
	check(ctx.ball.global_position == before, "las poses ambientales no modifican la pelota de partido")
