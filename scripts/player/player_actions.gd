class_name PlayerActions
extends RefCounted
## Acciones de cuerpo completo de un futbolista de campo con clips del pack y movimiento de raiz: entrada deslizante,
## caidas y levantarse. Mientras dura una accion el jugador no controla su movimiento (la raiz del clip lo mueve) y,
## al terminar, encadena la siguiente (p. ej. barrida -> levantarse). La entrada, el balon y la fisica siguen siendo las
## del juego: el resultado de una barrida depende de donde esta realmente el pie del clip respecto a la pelota.

const SLIDE_CLIPS := [&"soccer_tackle", &"soccer_tackle_2", &"soccer_tackle_3"]
## Carrera para marcar que termina en barrida (sale de parado, gira y corre ~7 m hacia su izquierda). Solo se usa
## cuando el portador pasa por ese lado del defensor: la orientacion que pide el clip coincide con la que ya tiene.
const LONG_SLIDE_CLIP := &"Defender"
const LONG_SLIDE_MAX_YAW_FIX := 22.0
## Caida a toda velocidad (golpe fuerte en sprint): resbala varios metros con la raiz del clip.
const FALL_SPRINT := &"Sprint_To_Backslide"
const FALL_SPRINT_MIN_SPEED := 5.0
## Misma caida en el sitio: sin espacio por delante para resbalar (pared o fin del area exterior) el cuerpo se frena.
const FALL_SPRINT_INPLACE := &"Sprint_To_Backslide_inplace"
const FALL_SPRINT_ROOM := 7.5
## Tendido en el suelo un instante tras un golpe, antes de levantarse.
const FALLEN_IDLE := &"fallen_idle"
const FALLEN_SECONDS := 0.8
## Trastabillar con raiz (pierde un choque de hombros a la carrera).
const STUMBLE_ROOT := &"Jogging_Stumble"
const FALL_TRIP := &"soccer_trip"
const FALL_HIT := &"Shoulder_Hit_And_Fall"
const GET_UP := [&"Getting_Up_3", &"standing_up"]
## Empujon sin caida (contacto leve a poca velocidad) y dolor en el suelo tras una zancadilla.
const SHOVE_CLIPS := [&"Shove_Reaction", &"Shove_Reaction_2"]
const PAIN_CLIP := &"Writhing_In_Pain"
const PAIN_SECONDS := 1.6
## Velocidad minima (m/s) para lanzarse a una barrida y distancia al portador (m) a la que se decide.
const SLIDE_MIN_SPEED := 3.6
const SLIDE_MIN_DIST := 1.0
const SLIDE_MAX_DIST := 3.6
const SLIDE_COOLDOWN := 6.0
const SLIDE_SPEED := 1.7
const FALL_SPEED := 1.7
## La barrida se lanza solo si la punta del pie del clip llega a esta distancia (m) de la pelota prevista en el contacto.
const SLIDE_REACH := 0.55
## Radio (m) entre la punta del pie de la barrida y la pelota / el portador para que cuente el contacto.
const SLIDE_BALL_RADIUS := 0.65
const SLIDE_BODY_RADIUS := 0.9

var owner: Footballer
var motion := ActionMotion.new()
var kind: StringName = &""
var rng := RandomNumberGenerator.new()
var _chain: Array[Dictionary] = []
var _slide: Dictionary = {}
var _slide_cd: float = 0.0
var stats := {"slides": 0, "slide_wins": 0, "slide_fouls": 0, "falls": 0}

func _init(o: Footballer) -> void:
	owner = o
	rng.randomize()

## Corta cualquier accion en curso (saque, reinicio, gol).
func reset() -> void:
	if kind == &"ball_move":
		owner.ball_handler.json_move.cancel()
	motion.stop()
	_chain.clear()
	_slide = {}
	kind = &""

## true mientras una accion (o su encadenado) controla el cuerpo.
func active() -> bool:
	return motion.active or not _chain.is_empty()

func _can_play() -> bool:
	return owner.visual != null and owner.visual.uses_pack and not owner.visual.is_placeholder

## Empieza una accion. chain: [{kind, clip, speed, cut}] que se encadenan al terminar.
func start(k: StringName, clip: StringName, speed: float = 1.0, cut: float = -1.0, chain: Array = [], start_at: float = 0.0) -> bool:
	if not _can_play() or not PackLibrary.has_clip(clip):
		return false
	owner.ball_handler.abort_kick()
	owner.ball_handler.cancel_charge()
	_chain.clear()
	for c in chain:
		_chain.append(c)
	_begin(k, clip, speed, cut, start_at)
	return true

func _begin(k: StringName, clip: StringName, speed: float, cut: float, start_at: float = 0.0) -> void:
	kind = k
	owner.visual.play_pack_clip(clip, speed, start_at, cut)
	motion.start(clip, speed, start_at, cut)
	# Clip con rumbo propio: la orientacion de su inicio es la de ahora menos lo que ya giro hasta start_at.
	motion.yaw0 = owner.locomotion.yaw - motion.heading_at(start_at)
	owner.ball_handler.lockout = maxf(owner.ball_handler.lockout, 0.3)

## Modo 4: movimiento de cuerpo entero con rumbo propio (giro, giro con pelota, regate) desde `start_at` s del clip. Igual
## que start pero sin cortar las acciones de pelota que lo piden (JsonBallMove maneja la pelota durante el clip).
func start_move(k: StringName, clip: StringName, speed: float = 1.0, start_at: float = 0.0) -> bool:
	if not _can_play() or not PackLibrary.has_clip(clip):
		return false
	_chain.clear()
	_begin(k, clip, speed, -1.0, start_at)
	return true

## Avanza un paso de fisica moviendo el cuerpo con la raiz del clip. Devuelve true si la accion se ocupo del paso.
func tick(delta: float) -> bool:
	_slide_cd = maxf(_slide_cd - delta, 0.0)
	_tackle_cd = maxf(_tackle_cd - delta, 0.0)
	_skill_cd = maxf(_skill_cd - delta, 0.0)
	if not active():
		return false
	var rv: Vector2 = motion.step(delta)
	var loco: Locomotion = owner.locomotion
	var wv: Vector3 = loco.forward() * rv.x + loco.right() * rv.y
	if motion.heading_driven:
		# Raiz en el marco del inicio del clip y el cuerpo girando con el rumbo del clip (giros, giros con pelota).
		var f0: Vector3 = Locomotion.dir_from_yaw(motion.yaw0)
		wv = f0 * rv.x + Vector3(-f0.z, 0.0, f0.x) * rv.y + motion.extra_velocity
		var new_yaw: float = motion.yaw0 + motion.heading_at(motion.t)
		loco.turn_rate = wrapf(new_yaw - loco.yaw, -PI, PI) / maxf(delta, 0.001)
		loco.yaw = new_yaw
	# Modo 4: la raiz de una caida o barrida puede llevar varios metros; el cuerpo no se sale del area de juego (+0.8 m).
	if PackLibrary.json_mode() and owner.ctx != null and owner.ctx.pitch != null:
		var cfg: PitchConfig = owner.ctx.pitch.config
		var nxt: Vector3 = owner.global_position + wv * delta
		if absf(nxt.x) > cfg.half_length() + 0.8 and signf(wv.x) == signf(nxt.x):
			wv.x = 0.0
		if absf(nxt.z) > cfg.half_width() + 0.8 and signf(wv.z) == signf(nxt.z):
			wv.z = 0.0
	owner.velocity.x = wv.x
	owner.velocity.z = wv.z
	if owner.is_on_floor():
		owner.velocity.y = -0.5
	else:
		owner.velocity.y -= 9.81 * delta
	owner.move_and_slide()
	loco.velocity = Vector3(owner.velocity.x, 0.0, owner.velocity.z)
	loco.speed = loco.velocity.length()
	owner.rotation.y = loco.yaw
	owner.ball_handler.lockout = maxf(owner.ball_handler.lockout, 0.15)
	if not _slide.is_empty() and motion.elapsed >= float(_slide["t"]):
		_resolve_slide()
	if kind == &"skill":
		_skill_touches()
	if kind == &"ball_move":
		owner.ball_handler.json_move.step(motion.t, delta)
	if not motion.active:
		if not _chain.is_empty():
			var nxt: Dictionary = _chain.pop_front()
			_begin(nxt.get("kind", &"chain"), nxt["clip"], float(nxt.get("speed", 1.0)), float(nxt.get("cut", -1.0)))
		else:
			var ended: StringName = kind
			kind = &""
			if motion.heading_driven:
				# Giros y movimientos con pelota terminan en marcha: el cuerpo sigue con la velocidad de salida del clip.
				loco.velocity = Vector3(wv.x, 0.0, wv.z)
				loco.speed = loco.velocity.length()
				loco.turn_rate = 0.0
			else:
				loco.stop()
				owner.velocity = Vector3.ZERO
			if ended == &"ball_move":
				owner.ball_handler.json_move.finish()
	return true

# --- Barrida ------------------------------------------------------------------------------------------------

## Intenta lanzarse a una barrida contra el portador. Planifica como el golpeo: para cada clip (y su espejo) calcula
## donde estara la punta del pie en su instante de contacto y donde estara la pelota; solo se lanza si llegan.
## Devuelve true si la inicio (entonces el robo normal no se hace).
func try_slide_tackle(carrier: Footballer, forced: bool = false) -> bool:
	if carrier == null or active() or _slide_cd > 0.0 or not _can_play():
		return false
	var loco: Locomotion = owner.locomotion
	var to_c: Vector3 = KickModel.flat(carrier.global_position - owner.global_position)
	var dist: float = to_c.length()
	if loco.stamina < 0.12 or dist < SLIDE_MIN_DIST:
		return false
	var ball: Ball = owner.ctx.ball
	var best: Dictionary = {}
	var best_d: float = INF
	var fast: bool = loco.speed >= SLIDE_MIN_SPEED and dist <= SLIDE_MAX_DIST and KickModel.angle_between_deg(loco.forward(), to_c) <= 55.0
	if fast:
		for base in SLIDE_CLIPS:
			for variant in [base, StringName(String(base) + "_mirror")]:
				var c: Dictionary = _slide_candidate(variant, loco.yaw, ball, 0.0)
				if not c.is_empty() and float(c["d"]) < best_d:
					best_d = float(c["d"])
					best = c
	# Carrera larga con barrida (Defender): el portador pasa por el costado del defensor, a 4-8 m.
	if best.is_empty() and not forced and dist > SLIDE_MAX_DIST and dist < 8.5 and PackLibrary.has_clip(LONG_SLIDE_CLIP):
		var c2: Dictionary = _slide_candidate(LONG_SLIDE_CLIP, loco.yaw, ball, LONG_SLIDE_MAX_YAW_FIX)
		if not c2.is_empty() and float(c2["d"]) <= SLIDE_REACH:
			best = c2
			best_d = float(c2["d"])
	if best.is_empty():
		return false
	# La persona decide cuando barrer (boton ENTRADA): se lanza aunque no llegue del todo (puede fallar o hacer falta).
	if forced:
		if best_d > SLIDE_REACH * 3.0:
			return false
	else:
		if best_d > SLIDE_REACH:
			return false
		# No siempre: la ventana util dura unos pasos de fisica y cada uno tiene ~8 % de lanzarse.
		if rng.randf() > 0.08:
			return false
	loco.yaw = float(best["yaw"])
	owner.rotation.y = loco.yaw
	var getup: StringName = &"standing_up"
	if not start(&"slide", best["clip"], SLIDE_SPEED, -1.0, [{"kind": &"getup", "clip": getup, "speed": FALL_SPEED}]):
		return false
	_slide_cd = SLIDE_COOLDOWN
	_slide = {"carrier": carrier, "t": best["t"], "key": best["key"], "clip": best["clip"]}
	stats["slides"] += 1
	if best["clip"] == LONG_SLIDE_CLIP:
		stats["long_slides"] = int(stats.get("long_slides", 0)) + 1
	return true

## Mejor pie de un clip de barrida para alcanzar la pelota prevista. yaw_fix: grados que se permite reorientar el cuerpo
## al empezar para que la trayectoria del clip apunte a la pelota (0 = con la orientacion actual).
## Devuelve {clip, key, t, d, yaw} o {}.
func _slide_candidate(variant: StringName, yaw: float, ball: Ball, yaw_fix: float) -> Dictionary:
	if not PackLibrary.has_clip(variant):
		return {}
	var toes: Dictionary = PackLibrary.meta(variant).get("paths", {})
	var best: Dictionary = {}
	for key in ["toe_r", "toe_l"]:
		if not toes.has(key):
			continue
		var tau: float = KeeperPlanner.peak_speed_time(variant, key)
		var t_c: float = tau / SLIDE_SPEED
		var bp: Vector3 = ball.global_position + Vector3(ball.linear_velocity.x, 0.0, ball.linear_velocity.z) * t_c
		var use_yaw: float = yaw
		if yaw_fix > 0.0:
			# Orientacion que pone el pie del clip sobre la pelota: yaw = rumbo a la pelota + angulo del pie en el clip.
			var h: Vector3 = (toes[key] as PackedVector3Array)[clampi(int(tau * 30.0), 0, (toes[key] as PackedVector3Array).size() - 1)]
			var need: float = Locomotion.yaw_from_dir(KickModel.flat(bp - owner.global_position).normalized()) + atan2(h.z, h.x)
			if absf(wrapf(need - yaw, -PI, PI)) > deg_to_rad(yaw_fix):
				continue
			use_yaw = need
		var foot: Vector3 = KeeperPlanner.path_world(variant, key, int(tau * 30.0), owner.global_position, use_yaw)
		var d: float = Vector2(foot.x - bp.x, foot.z - bp.z).length()
		if best.is_empty() or d < float(best["d"]):
			best = {"clip": variant, "key": key, "t": t_c, "d": d, "yaw": use_yaw}
	return best

# --- Entrada de pie y carga con el hombro (boton ENTRADA) ---------------------------------------------------------

## Entrada pedida por la persona. Segun la situacion: entrada de pie (pelota al alcance), carga con el hombro (corriendo
## a la par del portador) o barrida (a la carrera, con el portador a unos metros). Fuera de alcance es una entrada al
## aire: el defensor se compromete, pierde velocidad y queda un instante sin poder volver a intentarlo.
## Devuelve &"stand", &"shoulder", &"slide", &"whiff" o &"" (no hizo nada: ya estaba en una accion).
func tackle_request(carrier: Footballer) -> StringName:
	if active() or _tackle_cd > 0.0:
		return &""
	var ball: Ball = owner.ctx.ball
	if ball == null or ball.is_held():
		return &""
	_tackle_cd = 0.7
	var bh: BallHandler = owner.ball_handler
	var loco: Locomotion = owner.locomotion
	var to_ball: Vector3 = KickModel.flat(ball.global_position - owner.global_position)
	if carrier != null and _alongside(carrier):
		shoulder_charge(carrier)
		return &"shoulder"
	if to_ball.length() <= Tuning.assist.press_tackle_range * 1.2 and ball.global_position.y < 0.6 \
			and KickModel.angle_between_deg(loco.forward(), to_ball) < 100.0:
		if owner.visual != null:
			if PackLibrary.json_mode():
				tackle_gesture(carrier)
			else:
				owner.visual.start_kick(0.12, 0.45, 1 if to_ball.dot(loco.right()) >= 0.0 else -1)
		var won: bool = bh.attempt_tackle(carrier)
		# Entrar por detras derriba al portador: falta.
		if not won and carrier != null and _from_behind(carrier) and rng.randf() < 0.45:
			_commit_foul(carrier, false)
		owner.tackled.emit(won)
		return &"stand"
	if carrier != null and loco.speed >= SLIDE_MIN_SPEED * 0.8 and try_slide_tackle(carrier, true):
		return &"slide"
	# Entrada al aire.
	loco.velocity *= 0.45
	bh.lockout = maxf(bh.lockout, 0.45)
	owner.ctx.emit_event(GameEvent.make(GameEvent.Type.TACKLE_FAILED, owner.actor_id, owner.team, {"victim": carrier.actor_id if carrier != null else -1, "whiff": true}))
	return &"whiff"

var _tackle_cd: float = 0.0

## Modo 4: el gesto de la entrada de pie (uno de los clips de entrada parada, del lado de la pelota). Solo presentacion: el
## robo lo decide attempt_tackle.
func tackle_gesture(carrier: Footballer) -> void:
	if not PackLibrary.json_mode() or owner.visual == null or owner.visual.is_action_playing():
		return
	if owner.locomotion.speed > GESTURE_MAX_SPEED:
		return
	var c: StringName = JsonCatalog.situation_clip(&"tackle_stand", owner.actor_id)
	if c == &"":
		return
	var ball: Ball = owner.ctx.ball
	if ball != null and KickModel.flat(ball.global_position - owner.global_position).dot(owner.locomotion.right()) < 0.0 and PackLibrary.has_clip(StringName(String(c) + "_mirror")):
		c = StringName(String(c) + "_mirror")
	owner.visual.play_pack_clip(c, 1.35, 0.0, 0.8)

## Velocidad (m/s) maxima del cuerpo para los gestos en el sitio (entrada de pie, forcejeo) del modo 4.
const GESTURE_MAX_SPEED := 2.2

## Modo 4: disputa de quien presiona pegado al portador sin llegar a entrar (forcejeo con el cuerpo y amago de pierna,
## clips «jostle» y entradas de pie del zip): la presion siempre se ve, como en First Touch. Solo presentacion.
func press_gesture(carrier: Footballer) -> void:
	if not PackLibrary.json_mode() or owner.visual == null or owner.visual.is_action_playing() or carrier == null:
		return
	# Gesto en el sitio: solo con el cuerpo casi frenado junto al portador (corriendo se veria deslizarse).
	if owner.locomotion.speed > GESTURE_MAX_SPEED:
		return
	var c: StringName = JsonCatalog.situation_clip(&"press_duel", owner.actor_id)
	if c == &"":
		return
	if KickModel.flat(carrier.global_position - owner.global_position).dot(owner.locomotion.right()) < 0.0 and PackLibrary.has_clip(StringName(String(c) + "_mirror")):
		c = StringName(String(c) + "_mirror")
	owner.visual.play_pack_clip(c, 1.2, 0.0, 0.9)
	stats["press_gestures"] = int(stats.get("press_gestures", 0)) + 1

## true si el defensor corre a la par del portador (hombro con hombro): mismos sentidos, cerca y de costado.
func _alongside(carrier: Footballer) -> bool:
	var d: Vector3 = KickModel.flat(carrier.global_position - owner.global_position)
	if d.length() > 1.25 or d.length() < 0.35:
		return false
	if owner.locomotion.speed < 2.8 or carrier.locomotion.speed < 2.8:
		return false
	var cf: Vector3 = carrier.locomotion.forward()
	if owner.locomotion.forward().dot(cf) < 0.7:
		return false
	return absf(d.dot(Vector3(-cf.z, 0.0, cf.x))) > 0.3 and absf(d.dot(cf)) < 0.9

func _from_behind(carrier: Footballer) -> bool:
	var d: Vector3 = KickModel.flat(owner.global_position - carrier.global_position)
	return d.length() > 0.01 and d.normalized().dot(carrier.locomotion.forward()) < -0.5

## Carga legal con el hombro: gana el mas fuerte y equilibrado (con azar). El que pierde trastabilla (clip con raiz) y
## el defensor que gana se queda con la pelota con un toque. Nadie se teletransporta: el resto lo hace la fisica.
func shoulder_charge(carrier: Footballer) -> bool:
	var mine: float = owner.attributes.factor("strength", 0.5) * owner.attributes.factor("balance", 0.3) * lerpf(0.9, 1.1, owner.locomotion.speed / 7.0)
	var theirs: float = carrier.attributes.factor("strength", 0.5) * carrier.attributes.factor("balance", 0.3) * lerpf(0.9, 1.1, carrier.locomotion.speed / 7.0)
	# El portador conduce: protege mejor si la pelota esta pegada.
	if carrier.ball_handler.ball_distance() < 0.7:
		theirs *= 1.1
	var p_win: float = clampf(0.5 + (mine - theirs) * 1.4, 0.15, 0.8)
	var won: bool = rng.randf() < p_win
	stats["shoulder"] = int(stats.get("shoulder", 0)) + 1
	var away: Vector3 = KickModel.flat(carrier.global_position - owner.global_position)
	if won:
		stats["shoulder_wins"] = int(stats.get("shoulder_wins", 0)) + 1
		carrier.actions.stumble_root(away)
		carrier.ball_handler.lockout = maxf(carrier.ball_handler.lockout, 0.7)
		owner.ball_handler.touch_timer = 0.0
		owner.ctx.emit_event(GameEvent.make(GameEvent.Type.TACKLE_WON, owner.actor_id, owner.team, {"victim": carrier.actor_id, "shoulder": true}))
	else:
		stumble_root(-away)
		owner.ctx.emit_event(GameEvent.make(GameEvent.Type.TACKLE_FAILED, owner.actor_id, owner.team, {"victim": carrier.actor_id, "shoulder": true}))
	owner.tackled.emit(won)
	return won

## Trastabilla con el clip con raiz (pierde el equilibrio a la carrera y se recupera sin caer).
func stumble_root(_from_dir: Vector3 = Vector3.ZERO) -> void:
	if not _can_play() or active():
		return
	if start(&"stumble", STUMBLE_ROOT, 1.15, 0.9):
		stats["stumbles"] = int(stats.get("stumbles", 0)) + 1

## Falta del defensor sobre el portador: el portador cae y el partido la sanciona (tiro libre o penal).
func _commit_foul(carrier: Footballer, slide: bool) -> void:
	stats["fouls"] = int(stats.get("fouls", 0)) + 1
	carrier.actions.suffer_contact(&"trip", KickModel.flat(carrier.global_position - owner.global_position))
	owner.ctx.emit_event(GameEvent.make(GameEvent.Type.FOUL, owner.actor_id, owner.team, {"victim": carrier.actor_id,
		"slide": slide, "pos": [carrier.global_position.x, carrier.global_position.z]}))

func _resolve_slide() -> void:
	var s: Dictionary = _slide
	_slide = {}
	var ctx: MatchContext = owner.ctx
	var ball: Ball = ctx.ball
	var carrier: Footballer = s["carrier"]
	var toe: Vector3 = KeeperPlanner.path_world_at_body(s["clip"], s["key"], int(motion.t * 30.0), owner.global_position, owner.locomotion.yaw)
	var d_ball: float = toe.distance_to(ball.global_position)
	var d_body: float = Vector2(toe.x - carrier.global_position.x, toe.z - carrier.global_position.z).length() if is_instance_valid(carrier) else INF
	var won: bool = false
	if not ball.is_held() and d_ball <= SLIDE_BALL_RADIUS:
		won = owner.ball_handler.attempt_tackle(carrier)
	elif d_body <= SLIDE_BODY_RADIUS:
		# Llego al jugador y no a la pelota: falta; el portador cae.
		stats["slide_fouls"] += 1
		ctx.emit_event(GameEvent.make(GameEvent.Type.TACKLE_FAILED, owner.actor_id, owner.team, {"victim": carrier.actor_id, "foul": true, "slide": true}))
		_commit_foul(carrier, true)
	else:
		ctx.emit_event(GameEvent.make(GameEvent.Type.TACKLE_FAILED, owner.actor_id, owner.team, {"victim": carrier.actor_id if is_instance_valid(carrier) else -1, "slide": true, "miss": true}))
	if won:
		stats["slide_wins"] += 1
		# Un robo con barrida a veces derriba al portador.
		if rng.randf() < 0.35:
			carrier.actions.suffer_contact(&"hit", KickModel.flat(carrier.global_position - owner.global_position))
	owner.tackled.emit(won)

# --- Recibir un contacto (caidas) --------------------------------------------------------------------------

## El jugador cae por un contacto: "trip" (zancadilla), "hit" (golpe de hombro). Luego se levanta solo.
func suffer_contact(k: StringName, from_dir: Vector3) -> void:
	if not _can_play() or active():
		return
	var clip: StringName = FALL_TRIP if k == &"trip" else FALL_HIT
	var shove: bool = false
	var sprint_fall: bool = false
	if k == &"hit" and owner.locomotion.speed >= FALL_SPRINT_MIN_SPEED and PackLibrary.has_clip(FALL_SPRINT):
		# A toda velocidad el golpe lo tira y resbala por el piso (raiz del clip: ~7 m a velocidad de sprint).
		clip = FALL_SPRINT
		sprint_fall = true
		# Sin sitio para resbalar ~7 m: version en el sitio (el cuerpo se queda donde cae).
		var room: float = _room_ahead()
		if room < FALL_SPRINT_ROOM and PackLibrary.has_clip(FALL_SPRINT_INPLACE):
			clip = FALL_SPRINT_INPLACE
	if owner.locomotion.speed < 3.0 and not sprint_fall:
		# Parado o caminando no hay carrera que arrastre la caida: caidas cortas (raiz de 0.7-1 m) o, si fue un golpe
		# leve, un simple empujon del que se recupera sin llegar al suelo.
		if k == &"hit" and rng.randf() < 0.4:
			clip = SHOVE_CLIPS[rng.randi() % SHOVE_CLIPS.size()]
			shove = true
		else:
			clip = [&"Falling_Down", &"Sweep_Fall"][rng.randi() % 2]
	if PackLibrary.json_mode() and not shove:
		# Modo 4: cualquiera de las caidas convertidas, segun la carrera y el sitio que hay por delante.
		var jf: StringName = _json_fall(owner.locomotion.speed)
		if jf != &"":
			clip = jf
	var side: float = from_dir.dot(owner.locomotion.right())
	if side < 0.0 and PackLibrary.has_clip(StringName(String(clip) + "_mirror")):
		clip = StringName(String(clip) + "_mirror")
	var getup: StringName = GET_UP[rng.randi() % GET_UP.size()]
	var lie_ok: bool = true
	if PackLibrary.json_mode():
		# Se levanta desde la misma postura en que quedo tendido (boca arriba, boca abajo o de costado).
		var lie: String = String(PackLibrary.meta(clip).get("lie", ""))
		var jg: StringName = _json_getup(lie)
		if jg != &"":
			getup = jg
		lie_ok = lie == "" or String(PackLibrary.meta(FALLEN_IDLE).get("lie", "")) == lie
	var chain: Array = [] if shove else [{"kind": &"getup", "clip": getup, "speed": FALL_SPEED}]
	if k == &"trip" and PackLibrary.has_clip(PAIN_CLIP):
		# Tras una zancadilla se queda un momento en el suelo con dolor antes de levantarse.
		chain.push_front({"kind": &"pain", "clip": PAIN_CLIP, "speed": 1.0, "cut": PAIN_SECONDS})
	elif not shove and PackLibrary.has_clip(FALLEN_IDLE) and lie_ok:
		# Tras un golpe queda tendido un instante (aturdido) antes de levantarse.
		chain.push_front({"kind": &"down", "clip": FALLEN_IDLE, "speed": 1.0, "cut": FALLEN_SECONDS})
	if start(&"fall", clip, FALL_SPEED, -1.0, chain):
		stats["falls"] += 1
		owner.ctx.emit_event(GameEvent.make(GameEvent.Type.TURNOVER, owner.actor_id, owner.team, {"reason": String(k)}))

## Modo 4: una caida convertida al azar con un recorrido acorde a la carrera (a sprint resbala; parado, cae en el sitio) y
## que entra en el sitio libre por delante. &"" si no hay.
func _json_fall(speed: float) -> StringName:
	var room: float = _room_ahead()
	var lo: float = 1.5 if speed >= FALL_SPRINT_MIN_SPEED else 0.0
	var hi: float = minf(1.3 if speed < 3.0 else 4.0, room - 0.5) if speed < FALL_SPRINT_MIN_SPEED else minf(8.0, room - 0.5)
	var pool: Array[StringName] = []
	for role in [&"fall", &"fall_hit", &"trip"]:
		for id in PackLibrary.by_role(role):
			if String(id).ends_with("_mirror"):
				continue
			var m: Dictionary = PackLibrary.meta(id)
			var travel: float = (m.get("root_total", Vector2.ZERO) as Vector2).length()
			if travel >= lo and travel <= maxf(hi, 0.4) and m.has("lie"):
				pool.append(id)
	return pool[rng.randi() % pool.size()] if not pool.is_empty() else &""

## Modo 4: un levantarse convertido que empieza en la postura `lie` (cualquiera si no hay de esa postura).
func _json_getup(lie: String) -> StringName:
	var same: Array[StringName] = []
	var all: Array[StringName] = []
	for id in PackLibrary.by_role(&"getup"):
		var m: Dictionary = PackLibrary.meta(id)
		all.append(id)
		if String(m.get("lie", "")) == lie:
			same.append(id)
	var pool: Array[StringName] = same if not same.is_empty() else all
	return pool[rng.randi() % pool.size()] if not pool.is_empty() else &""

## Metros libres por delante del jugador hasta el borde del area de juego (lineas + area exterior).
func _room_ahead() -> float:
	var ctx: MatchContext = owner.ctx
	if ctx == null or ctx.pitch == null:
		return 99.0
	var cfg: PitchConfig = ctx.pitch.config
	var m: float = cfg.run_off if cfg.boundary_mode == PitchConfig.BoundaryMode.OUT_OF_BOUNDS else 0.0
	var f: Vector3 = owner.locomotion.forward()
	var p: Vector3 = owner.global_position
	var best: float = 99.0
	if absf(f.x) > 0.01:
		best = minf(best, ((cfg.half_length() + m) * signf(f.x) - p.x) / f.x)
	if absf(f.z) > 0.01:
		best = minf(best, ((cfg.half_width() + m) * signf(f.z) - p.z) / f.z)
	return maxf(best, 0.0)

# --- Regate (ruleta) -----------------------------------------------------------------------------------------

const SKILL_COOLDOWN := 2.5
const SKILL_MIN_SPEED := 1.8
var _skill_cd: float = 0.0

## Ruleta de 360 grados con la pelota (Soccer_Spin): mientras dura, el portador esta protegido de las entradas y la
## pelota sigue con el (toques de conduccion durante la accion). Requiere llevar la pelota y cierta velocidad.
func try_skill() -> bool:
	if active() or _skill_cd > 0.0 or not _can_play() or not owner.ball_handler.has_possession():
		return false
	if owner.locomotion.speed < SKILL_MIN_SPEED:
		return false
	if not start(&"skill", &"Soccer_Spin", 1.3):
		return false
	_skill_cd = SKILL_COOLDOWN
	stats["skills"] = int(stats.get("skills", 0)) + 1
	return true

## Mientras gira, la pelota no se queda atras: toques de conduccion en la direccion del avance.
func _skill_touches() -> void:
	owner.ball_handler.force_dribble_touch(owner.locomotion.forward())

## Tropiezo leve (solo presentacion): el cuerpo sigue su movimiento y el clip actua sobre el tronco.
func stumble() -> void:
	if _can_play() and not active() and not owner.visual.is_action_playing():
		owner.visual.play_pack_clip(&"Jogging_Stumble_inplace", 1.0, 0.0, 0.9)
