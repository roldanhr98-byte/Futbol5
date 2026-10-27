class_name PlayerActions
extends RefCounted
## Acciones de cuerpo completo de un futbolista de campo con clips del pack y movimiento de raiz: entrada deslizante,
## caidas y levantarse. Mientras dura una accion el jugador no controla su movimiento (la raiz del clip lo mueve) y,
## al terminar, encadena la siguiente (p. ej. barrida -> levantarse). La entrada, el balon y la fisica siguen siendo las
## del juego: el resultado de una barrida depende de donde esta realmente el pie del clip respecto a la pelota.

const SLIDE_CLIPS := [&"soccer_tackle", &"soccer_tackle_2", &"soccer_tackle_3"]
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
func start(k: StringName, clip: StringName, speed: float = 1.0, cut: float = -1.0, chain: Array = []) -> bool:
	if not _can_play() or not PackLibrary.has_clip(clip):
		return false
	owner.ball_handler.abort_kick()
	owner.ball_handler.cancel_charge()
	_chain.clear()
	for c in chain:
		_chain.append(c)
	_begin(k, clip, speed, cut)
	return true

func _begin(k: StringName, clip: StringName, speed: float, cut: float) -> void:
	kind = k
	owner.visual.play_pack_clip(clip, speed, 0.0, cut)
	motion.start(clip, speed, 0.0, cut)
	owner.ball_handler.lockout = maxf(owner.ball_handler.lockout, 0.3)

## Avanza un paso de fisica moviendo el cuerpo con la raiz del clip. Devuelve true si la accion se ocupo del paso.
func tick(delta: float) -> bool:
	_slide_cd = maxf(_slide_cd - delta, 0.0)
	_skill_cd = maxf(_skill_cd - delta, 0.0)
	if not active():
		return false
	var rv: Vector2 = motion.step(delta)
	var loco: Locomotion = owner.locomotion
	var wv: Vector3 = loco.forward() * rv.x + loco.right() * rv.y
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
	if not motion.active:
		if not _chain.is_empty():
			var nxt: Dictionary = _chain.pop_front()
			_begin(nxt.get("kind", &"chain"), nxt["clip"], float(nxt.get("speed", 1.0)), float(nxt.get("cut", -1.0)))
		else:
			kind = &""
			loco.stop()
			owner.velocity = Vector3.ZERO
	return true

# --- Barrida ------------------------------------------------------------------------------------------------

## Intenta lanzarse a una barrida contra el portador. Planifica como el golpeo: para cada clip (y su espejo) calcula
## donde estara la punta del pie en su instante de contacto y donde estara la pelota; solo se lanza si llegan.
## Devuelve true si la inicio (entonces el robo normal no se hace).
func try_slide_tackle(carrier: Footballer) -> bool:
	if carrier == null or active() or _slide_cd > 0.0 or not _can_play():
		return false
	var loco: Locomotion = owner.locomotion
	var to_c: Vector3 = KickModel.flat(carrier.global_position - owner.global_position)
	var dist: float = to_c.length()
	if loco.speed < SLIDE_MIN_SPEED or dist < SLIDE_MIN_DIST or dist > SLIDE_MAX_DIST or loco.stamina < 0.12:
		return false
	if KickModel.angle_between_deg(loco.forward(), to_c) > 55.0:
		return false
	var ball: Ball = owner.ctx.ball
	var best: Dictionary = {}
	var best_d: float = INF
	for base in SLIDE_CLIPS:
		for variant in [base, StringName(String(base) + "_mirror")]:
			if not PackLibrary.has_clip(variant):
				continue
			var toes: Dictionary = PackLibrary.meta(variant).get("paths", {})
			for key in ["toe_r", "toe_l"]:
				if not toes.has(key):
					continue
				var tau: float = KeeperPlanner.peak_speed_time(variant, key)
				var t_c: float = tau / SLIDE_SPEED
				var foot: Vector3 = KeeperPlanner.path_world(variant, key, int(tau * 30.0), owner.global_position, loco.yaw)
				var bp: Vector3 = ball.global_position + Vector3(ball.linear_velocity.x, 0.0, ball.linear_velocity.z) * t_c
				var d: float = Vector2(foot.x - bp.x, foot.z - bp.z).length()
				if d < best_d:
					best_d = d
					best = {"clip": variant, "key": key, "t": t_c}
	if best.is_empty() or best_d > SLIDE_REACH:
		return false
	# No siempre: la ventana util dura unos pasos de fisica y cada uno tiene ~8 % de lanzarse.
	if rng.randf() > 0.08:
		return false
	var getup: StringName = &"standing_up"
	if not start(&"slide", best["clip"], SLIDE_SPEED, -1.0, [{"kind": &"getup", "clip": getup, "speed": FALL_SPEED}]):
		return false
	_slide_cd = SLIDE_COOLDOWN
	_slide = {"carrier": carrier, "t": best["t"], "key": best["key"], "clip": best["clip"]}
	stats["slides"] += 1
	return true

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
		var away: Vector3 = KickModel.flat(carrier.global_position - owner.global_position)
		carrier.actions.suffer_contact(&"trip", away)
		ctx.emit_event(GameEvent.make(GameEvent.Type.TACKLE_FAILED, owner.actor_id, owner.team, {"victim": carrier.actor_id, "foul": true, "slide": true}))
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
	if owner.locomotion.speed < 3.0:
		# Parado o caminando no hay carrera que arrastre la caida: caidas cortas (raiz de 0.7-1 m) o, si fue un golpe
		# leve, un simple empujon del que se recupera sin llegar al suelo.
		if k == &"hit" and rng.randf() < 0.4:
			clip = SHOVE_CLIPS[rng.randi() % SHOVE_CLIPS.size()]
			shove = true
		else:
			clip = [&"Falling_Down", &"Sweep_Fall"][rng.randi() % 2]
	var side: float = from_dir.dot(owner.locomotion.right())
	if side < 0.0 and PackLibrary.has_clip(StringName(String(clip) + "_mirror")):
		clip = StringName(String(clip) + "_mirror")
	var getup: StringName = GET_UP[rng.randi() % GET_UP.size()]
	var chain: Array = [] if shove else [{"kind": &"getup", "clip": getup, "speed": FALL_SPEED}]
	if k == &"trip" and PackLibrary.has_clip(PAIN_CLIP):
		# Tras una zancadilla se queda un momento en el suelo con dolor antes de levantarse.
		chain.push_front({"kind": &"pain", "clip": PAIN_CLIP, "speed": 1.0, "cut": PAIN_SECONDS})
	if start(&"fall", clip, FALL_SPEED, -1.0, chain):
		stats["falls"] += 1
		owner.ctx.emit_event(GameEvent.make(GameEvent.Type.TURNOVER, owner.actor_id, owner.team, {"reason": String(k)}))

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
