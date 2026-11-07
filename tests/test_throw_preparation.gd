extends TestCase
## El giro de saque de banda participa en la secuencia y conserva la pelota hasta el lanzamiento verdadero.

func test_throw_orientation_clip_is_followed_by_the_real_throw() -> void:
	Tuning.pitch.boundary_mode = PitchConfig.BoundaryMode.OUT_OF_BOUNDS
	var hw: float = Tuning.pitch.half_width()
	var ctx: MatchContext = await make_match(Vector3(0, 0.11, hw))
	var p: Footballer = add_player(ctx, 0, Vector3.ZERO, 60, ScriptedInput.new(), true)
	await physics_frames(3)
	var sp := SetPiece.new(SetPiece.Kind.THROW_IN, 0, Vector3(0, 0, hw), p, ctx)
	p.set_piece = sp
	sp.place_taker()
	var id := &"jn_throw_prep_2516"
	var m: Dictionary = PackLibrary.meta(id)
	var turn: float = ActionMotion.heading_rel(m["heading_path"], m["duration"])
	var direction: Vector3 = Locomotion.dir_from_yaw(p.locomotion.yaw + turn)
	sp.execute(&"pass", 0.4, false, direction)
	check(sp.stage == &"orient" and sp.orientation_clip == id, "entra el giro de preparacion cuando coincide el cambio de orientacion")
	check(p.visual.current_action == id and ctx.ball.is_held(), "el clip se invoca con la pelota sostenida")
	var held_during_turn: bool = true
	for frame in 360:
		await tree.physics_frame
		if sp.stage == &"orient":
			held_during_turn = held_during_turn and ctx.ball.is_held()
		if sp.resolved:
			break
	check(held_during_turn, "girar no lanza la pelota")
	check(sp.result == &"thrown" and not ctx.ball.is_held(), "despues se ejecuta el saque de banda real")
