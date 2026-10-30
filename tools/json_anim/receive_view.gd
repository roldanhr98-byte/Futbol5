extends Node
## Revision a ojo y medida de la recepcion del modo 4 (F3, JsonReceive): una pelota rodando llega a un jugador y se guarda
## una tira de imagenes alrededor del toque, con la medida del pie VIVO (esqueleto animado) frente a la pelota:
##  - en el instante del toque, distancia de la punta del pie del toque a la superficie de la pelota;
##  - antes del toque, distancia minima de cualquier punta de pie a la pelota (si es casi cero, el pie la «toca» o la
##    atraviesa antes de tiempo) y de la pelota al centro del cuerpo (si baja del radio de la capsula, la cruza).
## Necesita render:
##   ANGLE=30 SPEED=9 OUT=/tmp/r.png xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tools/json_anim/receive_view.tscn
## Env: ANGLE (grados de donde viene la pelota respecto al frente, + izquierda), SPEED (m/s), DIST (m), LAT (m de desvio
## lateral del pase), STICK_ANGLE (grados del joystick respecto al frente; vacio = suelto), RUN (joystick de marcha hacia el
## frente, 0..1), SEED, EVERY (pasos entre imagenes), COUNT, W/H, VIEW side|three|top|close, ARRIVE_Y (altura en m a la que
## llega la pelota al jugador: se lanza por el aire; vacio = rodando), PASS (1 = el jugador carga un pase mientras llega la
## pelota y lo suelta tras el contacto).

func _env(k: String, d: String) -> String:
	return OS.get_environment(k) if OS.get_environment(k) != "" else d

func _ready() -> void:
	Tuning.gameplay_mode = 4
	PackLibrary.reload()
	var out: String = _env("OUT", "/tmp/receive.png")
	var ang: float = float(_env("ANGLE", "0"))
	var spd: float = float(_env("SPEED", "9"))
	var dist: float = float(_env("DIST", "6"))
	var lat: float = float(_env("LAT", "0"))
	var stick_ang: String = _env("STICK_ANGLE", "")
	var run: float = float(_env("RUN", "0"))
	var arrive_y: String = _env("ARRIVE_Y", "")
	var with_pass: bool = _env("PASS", "0") == "1"
	var every: int = int(_env("EVERY", "4"))
	var count: int = int(_env("COUNT", "12"))
	var w: int = int(_env("W", "320"))
	var h: int = int(_env("H", "240"))
	var view: String = _env("VIEW", "three")
	get_window().size = Vector2i(w, h)
	get_viewport().size = Vector2i(w, h)
	var pitch := Pitch.new()
	add_child(pitch)
	var ball: Ball = (load("res://scenes/ball/ball.tscn") as PackedScene).instantiate()
	add_child(ball)
	pitch.set_ball(ball)
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
	var me := Vector3(-8.0, 0.0, 0.0)
	f.global_position = me
	var attrs := PlayerAttributes.new()
	attrs.reset_to(60)
	f.setup(ctx, 0, 1, attrs, src)
	f.is_human_controlled = true
	var face := Vector3(1, 0, 0)
	f.locomotion.yaw = Locomotion.yaw_from_dir(face)
	f.ball_handler.rng.seed = int(_env("SEED", "7"))
	var cam := Camera3D.new()
	cam.fov = float(_env("FOV", "36"))
	add_child(cam)
	cam.current = true
	var from: Vector3 = face.rotated(Vector3.UP, deg_to_rad(ang))
	var side := Vector3(-from.z, 0.0, from.x)
	var start: Vector3 = me + from * dist + side * lat
	ball.reset_at(start + Vector3(0, 0.11, 0))
	for i in 20:
		await get_tree().physics_frame
	if run > 0.0:
		src.move = Vector2(run, 0.0)
		for i in 40:
			await get_tree().physics_frame
	# El pase apunta a donde estara el jugador (a su marcha) cuando llegue.
	var aim: Vector3 = f.global_position + f.velocity * (dist / maxf(spd, 1.0)) + side * lat
	var dir: Vector3 = KickModel.flat(aim - start).normalized()
	if arrive_y != "":
		# Por el aire: velocidad vertical para llegar a ARRIVE_Y m al jugador (sin arrastre; el plan usa la trayectoria real).
		var tt: float = dist / maxf(spd, 1.0)
		var vy: float = (float(arrive_y) - 0.11 + 0.5 * 9.81 * tt * tt) / tt
		ball.kick(dir * spd + Vector3(0.0, vy, 0.0), Vector3.ZERO, null)
	else:
		ball.kick(dir * spd, ball.rolling_spin(dir * spd), null)
	if with_pass:
		src.hold_pass()
	if stick_ang != "":
		var sd: Vector3 = face.rotated(Vector3.UP, deg_to_rad(float(stick_ang)))
		src.move = Vector2(sd.x, sd.z)
	var frames: Array[Image] = []
	var contact_i: int = -1
	var clip: StringName = &""
	var toe_pre: Array[float] = []
	var min_body_pre: float = INF
	var toe_at: float = -1.0
	var rv: JsonReceive = f.ball_handler.receive
	for i in 200:
		await get_tree().physics_frame
		var c: Vector3 = f.global_position
		match view:
			"top":
				cam.global_position = Vector3(c.x + 0.3, 7.0, c.z + 0.01)
			"side":
				cam.global_position = Vector3(c.x + 0.6, 0.95, c.z + 4.0)
			"close":
				cam.global_position = Vector3(c.x + 2.0, 1.45, c.z + 2.7)
			_:
				cam.global_position = Vector3(c.x + 3.2, 1.6, c.z + 3.2)
		cam.look_at(Vector3(c.x + 0.3, 0.5 if view != "top" else 0.0, c.z), Vector3.UP)
		if clip == &"" and f.ball_handler.json_move.active and f.ball_handler.json_move.intent == &"receive":
			clip = f.ball_handler.json_move.clip
		var bh: BallHandler = f.ball_handler
		var bp: Vector3 = ball.global_position
		if contact_i < 0 and rv.stats["contact"] > 0:
			contact_i = i
			if with_pass:
				src.release_pass()
			var foot: int = bh.last_touch_foot
			toe_at = bh.toe_world(foot).distance_to(bp) - ball.radius if foot >= 0 else -1.0
		elif contact_i < 0 and clip != &"":
			toe_pre.append(minf(bh.toe_world(0).distance_to(bp), bh.toe_world(1).distance_to(bp)) - ball.radius)
			min_body_pre = minf(min_body_pre, KickModel.flat(bp - c).length())
		await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		frames.append(img)
		if contact_i >= 0 and i > contact_i + 40:
			break
	# Tira: COUNT imagenes cada EVERY pasos centradas en el toque (o las primeras si no hubo toque con clip).
	var center: int = contact_i if contact_i >= 0 else frames.size() / 2
	var first: int = maxi(center - every * (count / 2), 0)
	var sheet := Image.create(w * mini(count, 6), h * ((count + 5) / 6), false, Image.FORMAT_RGB8)
	for k in count:
		var idx: int = mini(first + k * every, frames.size() - 1)
		sheet.blit_rect(frames[idx], Rect2i(0, 0, w, h), Vector2i((k % 6) * w, (k / 6) * h))
	sheet.save_png(out)
	var d_end: float = KickModel.flat(ball.global_position - f.global_position).length()
	# Antes del toque, sin los 3 ultimos pasos (el pie llega a la pelota justo antes del toque).
	var min_toe_pre: float = INF
	for k in maxi(toe_pre.size() - 3, 0):
		min_toe_pre = minf(min_toe_pre, toe_pre[k])
	print("RECEPCION angulo %+d v %.1f lat %.1f run %.1f stick %s: clip %s, toque en paso %d, punta del pie a %.3f m de la pelota en el toque; antes del toque: punta minima %.3f m, pelota-cuerpo minima %.2f m; al final pelota a %.2f m (%.1f m/s) | %s | %s" % [int(ang), spd, lat, run, stick_ang, clip, contact_i, toe_at, min_toe_pre, min_body_pre, d_end, ball.linear_velocity.length(), str(rv.stats), str(rv.last_contact)])
	print("PARTE %s (confianza %s), pelota a %.2f m en el contacto | golpeos %s" % [str(rv.last_plan.get("part", "")), str(rv.last_plan.get("confidence", "")), float(rv.last_plan.get("ball_y", -1.0)), str(f.ball_handler.kick_stats)])
	print("MOVIMIENTO %s | plan %s | rechazos %s" % [str(f.ball_handler.json_move.last), str(rv.last_plan), str(rv.rejects)])
	print("RECEIVEVIEW guardado ", out)
	get_tree().quit()
