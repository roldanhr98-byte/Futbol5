extends TestCase
## Los centros laterales no necesitan tener la pelota delante del cuerpo: necesitan que llegue a su pie lateral.

func test_each_lateral_cross_plans_and_executes_when_the_ball_is_on_its_contact_side() -> void:
	for id in [&"jn_kick_cross_0744", &"jn_kick_cross_0746"]:
		var ctx: MatchContext = await make_match(Vector3.ZERO)
		var p: Footballer = add_player(ctx, 0, Vector3(-5, 0, 0), 60, ScriptedInput.new(), true)
		p.set_physics_process(false)
		p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3.RIGHT)
		await physics_frames(3)
		var contact: Dictionary = PackLibrary.meta(id)["contact"]
		var cp: Vector3 = contact["pos"]
		ctx.ball.reset_at(p.global_position + p.locomotion.forward() * cp.x + p.locomotion.right() * cp.z + Vector3.UP * 0.11)
		ctx.ball.register_touch(p)
		await physics_frames(3)
		var plan: Dictionary = p.ball_handler.plan_clip_kick(&"cross", 0.5, false, id)
		check(not plan.is_empty(), "%s tiene plan valido con la pelota a su costado" % id)
		if not plan.is_empty():
			check(p.ball_handler._start_clip_kick(&"cross", plan, Vector3.RIGHT, 0.5, false), "%s invocado por el golpeo real" % id)
			p.set_physics_process(true)
			for frame in 120:
				await tree.physics_frame
				if p.ball_handler.kick_stats["contact"] > 0 or p.ball_handler.kick_stats["missed"] > 0:
					break
			note("%s: contacto %s, distancia %.3f" % [id, p.ball_handler.kick_stats, p.ball_handler.last_foot_distance])
			check(p.ball_handler.kick_stats["contact"] == 1 and p.ball_handler.last_foot_distance < 0.3, "%s golpea la pelota desde su contacto lateral" % id)
		check(p.ball_handler.plan_clip_kick(&"shot", 0.5, false, id).is_empty(), "%s no se fuerza como tiro si no pertenece a ese rol" % id)
		cleanup()
		await physics_frames(2)
