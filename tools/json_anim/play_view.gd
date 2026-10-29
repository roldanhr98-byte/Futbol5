extends Node
## Revision a ojo y medida de la jugabilidad del modo 4 (Json): un jugador con la pelota que conduce, pasa o tira, con camara de
## costado que lo sigue. Guarda una tira de imagenes (cada EVERY pasos de fisica) y escribe por la salida la distancia de la
## pelota al cuerpo en cada paso (resumen al final). Necesita render:
##   SCENARIO=dribble MODEL=1 OUT=/tmp/x.png xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/json_anim/play_view.tscn
## Env: SCENARIO dribble|pass|shot|turn|zigzag, MODEL 0 (Tripo adaptado) | 1 (humanoide), STICK (0..1), SPRINT (0|1), SECONDS, EVERY,
## COUNT (imagenes), START (s sin imagen), W/H (tamano de cada imagen), VIEW side|three|top, CHARGE (pasos de carga del tiro/pase).

func _env(k: String, d: String) -> String:
	return OS.get_environment(k) if OS.get_environment(k) != "" else d

func _ready() -> void:
	Tuning.gameplay_mode = int(_env("MODE", "4"))
	Tuning.json_model = int(_env("MODEL", "1"))
	PackLibrary.reload()
	var scenario: String = _env("SCENARIO", "dribble")
	var out: String = _env("OUT", "/tmp/play.png")
	var stick: float = float(_env("STICK", "0.8"))
	var sprint: bool = _env("SPRINT", "0") == "1"
	var seconds: float = float(_env("SECONDS", "6.0"))
	var every: int = int(_env("EVERY", "6"))
	var count: int = int(_env("COUNT", "10"))
	var t_start: float = float(_env("START", "1.5"))
	var w: int = int(_env("W", "320"))
	var h: int = int(_env("H", "240"))
	var view: String = _env("VIEW", "side")
	get_window().size = Vector2i(w, h)
	get_viewport().size = Vector2i(w, h)
	var pitch := Pitch.new()
	add_child(pitch)
	var ball: Ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
	add_child(ball)
	pitch.set_ball(ball)
	ball.global_position = Vector3(-14.4, 0.11, 0.0)
	var ctx := MatchContext.new()
	ctx.ball = ball
	ctx.pitch = pitch
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var src := ScriptedInput.new()
	var f: Footballer = (load("res://scenes/player/footballer.tscn") as PackedScene).instantiate()
	f.build_visual = true
	add_child(f)
	f.global_position = Vector3(-15.0, 0.0, 0.0)
	var attrs := PlayerAttributes.new()
	attrs.reset_to(60)
	f.setup(ctx, 0, 1, attrs, src)
	f.is_human_controlled = true
	f.locomotion.yaw = Locomotion.yaw_from_dir(Vector3(1, 0, 0))
	var cam := Camera3D.new()
	cam.fov = float(_env("FOV", "36"))
	add_child(cam)
	cam.current = true
	src.move = Vector2(stick, 0.0)
	src.sprint = sprint
	var total: int = int(seconds * 60.0)
	var sheet := Image.create(w * mini(count, 12), h * ((count + 11) / 12), false, Image.FORMAT_RGB8)
	var shot_i := 0
	var dists: Array[float] = []
	var gaps: Array[float] = []
	var touches_prev: int = 0
	var charge: int = int(_env("CHARGE", "14"))
	var act_at: int = int(float(_env("ACT_AT", "3.0")) * 60.0)
	var log_every: int = 6
	for i in total:
		if scenario == "pass" and i == act_at:
			src.hold_pass()
		elif scenario == "pass" and i == act_at + charge:
			src.release_pass()
		elif scenario == "shot" and i == act_at:
			src.hold_shoot()
		elif scenario == "shot" and i == act_at + charge:
			src.release_shoot()
		elif scenario == "zigzag":
			var ph: float = float(i) / 60.0
			src.move = Vector2(stick, 0.9 * sin(ph * 2.2))
		elif scenario == "turn" and i == act_at:
			src.move = Vector2(-stick, 0.0)
		await get_tree().physics_frame
		await get_tree().process_frame
		var c: Vector3 = f.global_position
		match view:
			"three":
				cam.global_position = Vector3(c.x + 1.0 + 2.2, 1.5, 3.4)
			"top":
				cam.global_position = Vector3(c.x + 0.5, 9.0, 0.01)
			_:
				cam.global_position = Vector3(c.x + 0.6, 0.95, 4.0)
		cam.look_at(Vector3(c.x + 0.6, 0.8 if view != "top" else 0.0, 0.0), Vector3.UP)
		var rel: Vector3 = ball.global_position - c
		var fwd: Vector3 = f.locomotion.forward()
		var ahead: float = rel.dot(fwd)
		dists.append(Vector2(rel.x, rel.z).length())
		gaps.append(ahead)
		if i % log_every == 0:
			print("t=%.2f v=%.2f bola adelante %.2f lateral %.2f y %.2f vel %.1f | dist pie-pelota (ult. toque) %.3f | toques %d" % [float(i) / 60.0, f.locomotion.speed, ahead, rel.dot(f.locomotion.right()), ball.global_position.y, ball.linear_velocity.length(), f.ball_handler.last_touch_foot_distance, f.ball_handler.dribble_touch_count])
		if float(i) / 60.0 >= t_start and (i % every == 0) and shot_i < count:
			var img: Image = get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i((shot_i % 12) * w, (shot_i / 12) * h))
			shot_i += 1
	sheet.save_png(out)
	dists.sort()
	var far := 0
	for d in dists:
		if d > 1.8:
			far += 1
	print("RESUMEN %s: pelota-cuerpo mediana %.2f m, p90 %.2f m, max %.2f m, >1.8 m: %d de %d pasos; toques %d, de pie vivo %d; kick_stats %s" % [scenario, dists[dists.size() / 2], dists[int(dists.size() * 0.9)], dists[dists.size() - 1], far, dists.size(), f.ball_handler.dribble_touch_count, f.ball_handler.foot_touches, str(f.ball_handler.kick_stats)])
	print("PLAYVIEW guardado ", out)
	get_tree().quit()
