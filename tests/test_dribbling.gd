extends TestCase
## Conduccion con toques fisicos: la pelota se adelanta, puede separarse y nunca se teletransporta.

func _dribble_run(stick: Vector2, sprint: bool, seconds: float, seed_value: int = 7, base_attr: int = 50) -> Dictionary:
	var ctx: MatchContext = await make_match(Vector3(-14.4, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-15.0, 0.0, 0.0), base_attr, src)
	p.ball_handler.rng.seed = seed_value
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	src.move = stick
	src.sprint = sprint
	var near_frames: int = 0
	var total: int = 0
	var dist_sum: float = 0.0
	var max_dist: float = 0.0
	var max_ball_step: float = 0.0
	var prev_ball: Vector3 = ctx.ball.global_position
	for i in int(seconds * 60.0):
		await tree.physics_frame
		var d: float = Vector2(ctx.ball.global_position.x - p.global_position.x, ctx.ball.global_position.z - p.global_position.z).length()
		total += 1
		dist_sum += d
		max_dist = maxf(max_dist, d)
		if d < 2.0:
			near_frames += 1
		max_ball_step = maxf(max_ball_step, ctx.ball.global_position.distance_to(prev_ball))
		prev_ball = ctx.ball.global_position
	return {
		"near_ratio": float(near_frames) / total, "mean_dist": dist_sum / total, "max_dist": max_dist,
		"touches": p.ball_handler.dribble_touch_count, "player_x": p.global_position.x,
		"ball_x": ctx.ball.global_position.x, "max_ball_step": max_ball_step,
	}

func test_dribble_at_jog_keeps_ball_close_with_physical_touches() -> void:
	var r: Dictionary = await _dribble_run(Vector2(0.6, 0.0), false, 6.0)
	note("trote: cerca=%.0f %%, distancia media=%.2f m, max=%.2f m, toques=%d, avance jugador=%.1f m" % [r["near_ratio"] * 100.0, r["mean_dist"], r["max_dist"], r["touches"], r["player_x"] + 15.0])
	check(r["near_ratio"] > 0.85, "al trotar la pelota esta a menos de 2 m el 85 %% del tiempo (%.0f %%)" % (r["near_ratio"] * 100.0))
	check(r["touches"] >= 8 and r["touches"] <= 40, "se dan toques periodicos (%d)" % r["touches"])
	check(r["player_x"] > -15.0 + 12.0, "el jugador avanza (x=%.1f)" % r["player_x"])
	check(r["max_ball_step"] < 0.55, "la pelota nunca se teletransporta (paso max %.3f m por tick)" % r["max_ball_step"])

func test_sprint_dribble_is_less_precise_than_jog() -> void:
	var jog: Dictionary = await _dribble_run(Vector2(0.6, 0.0), false, 5.0, 11)
	var sprint: Dictionary = await _dribble_run(Vector2(1.0, 0.0), true, 5.0, 11)
	note("distancia media: trote=%.2f m, sprint=%.2f m; maxima: trote=%.2f, sprint=%.2f" % [jog["mean_dist"], sprint["mean_dist"], jog["max_dist"], sprint["max_dist"]])
	check(sprint["mean_dist"] > jog["mean_dist"], "a sprint la pelota se separa mas del jugador")
	check(sprint["player_x"] > jog["player_x"], "pero el sprint avanza mas")
	check(sprint["near_ratio"] > 0.55, "el sprint no pierde la pelota por completo (%.0f %%)" % (sprint["near_ratio"] * 100.0))

func test_better_ball_carrying_means_tighter_control() -> void:
	var novice: Dictionary = await _dribble_run(Vector2(1.0, 0.0), true, 5.0, 3, 10)
	var skilled: Dictionary = await _dribble_run(Vector2(1.0, 0.0), true, 5.0, 3, 95)
	note("sprint distancia media: novato=%.2f m, habil=%.2f m" % [novice["mean_dist"], skilled["mean_dist"]])
	check(skilled["mean_dist"] < novice["mean_dist"], "mejores atributos de control = pelota mas cerca")

func test_no_touch_when_standing_still() -> void:
	var ctx: MatchContext = await make_match(Vector3(-14.4, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-15.0, 0.0, 0.0), 50, src)
	await wait_seconds(1.5)
	check(p.ball_handler.dribble_touch_count == 0, "sin joystick no se empuja la pelota (toques=%d)" % p.ball_handler.dribble_touch_count)
	check(ctx.ball.ground_speed() < 0.3, "la pelota permanece quieta (v=%.2f)" % ctx.ball.ground_speed())

func test_turning_with_ball_changes_ball_direction_physically() -> void:
	var ctx: MatchContext = await make_match(Vector3(-14.4, 0.11, 0.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(-15.0, 0.0, 0.0), 60, src)
	p.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	src.move = Vector2(0.7, 0.0)
	await wait_seconds(2.5)
	var z_before: float = ctx.ball.global_position.z
	src.move = Vector2(0.0, -0.7)   # girar hacia -Z (pantalla: arriba)
	await wait_seconds(3.0)
	var z_after: float = ctx.ball.global_position.z
	note("giro con pelota: z_pelota %.2f -> %.2f; z_jugador=%.2f" % [z_before, z_after, p.global_position.z])
	check(z_after < z_before - 3.0, "tras girar, la pelota viaja en la nueva direccion (dz=%.2f)" % (z_after - z_before))
	var d: float = Vector2(ctx.ball.global_position.x - p.global_position.x, ctx.ball.global_position.z - p.global_position.z).length()
	check(d < 3.5, "el jugador mantiene la pelota cerca tras girar (d=%.2f m)" % d)

func test_player_collides_with_walls() -> void:
	var ctx: MatchContext = await make_match(Vector3(0, 0.11, 8.0))
	var src := ScriptedInput.new()
	var p: Footballer = add_player(ctx, 0, Vector3(0.0, 0.0, 5.0), 50, src)
	src.move = Vector2(0.0, 1.0)
	src.sprint = true
	await wait_seconds(4.0)
	check(p.global_position.z <= Tuning.pitch.half_width() + 0.01, "no atraviesa la pared lateral (z=%.2f)" % p.global_position.z)
	check(p.global_position.z > 8.0, "llega hasta la pared (z=%.2f)" % p.global_position.z)
