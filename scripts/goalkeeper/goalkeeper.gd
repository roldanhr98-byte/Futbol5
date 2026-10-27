class_name Goalkeeper
extends CharacterBody3D
## Arquero. Se posiciona sobre el arco mirando la pelota, anticipa los disparos con la trayectoria predicha, planifica
## la atajada con la trayectoria de manos medida de sus clips (KeeperPlanner) y la ejecuta con el clip y el
## desplazamiento de raiz reales: el contacto cuenta solo si las manos llegan a la pelota. Despues sostiene la pelota
## y la saca con la mano o con el pie (lanzamiento, pase rodado o patada de despeje).
##
## La pelota solo cambia por impulsos (rechazo / saque) o sostenida en el ancla de las manos (Ball.hold).

signal saved(kind: StringName)

enum State { POSITION, PREPARE, ACTION, HOLD, DISTRIBUTE }

## Segundos con la pelota parada en el area tras los que el arquero la recoge aunque haya rivales cerca.
const SCRUM_SECONDS := 1.2
## Segundos maximos que el arquero adelanta su reaccion al ver armar el disparo.
const KICK_READ_MAX := 0.22
## Segundos con el joystick quieto tras los que el arquero controlado por la persona vuelve a atajar por su cuenta.
const MANUAL_AUTO_SAVE_IDLE := 0.3
## Distancia (m) a la que el arquero controla con el pie un pase de un companero.
const FOOT_TRAP_RANGE := 0.75
## Segundos que espera con la pelota en los pies antes de jugarla (arquero de la IA).
const FOOT_PLAY_DELAY := 0.6
## Segundos maximos que el arquero controlado por la persona retiene la pelota antes de sacar solo.
const MANUAL_HOLD_MAX := 8.0

@export var team: int = 0
var actor_id: int = 0
var display_name: String = "Arquero"
var attributes: PlayerAttributes = PlayerAttributes.new()
var ctx: MatchContext = null
var visual: FootballerVisual = null
var state: State = State.POSITION
var yaw: float = 0.0
var rng := RandomNumberGenerator.new()
## Contadores y registro (diagnostico y pruebas).
var stats := {"shots_faced": 0, "catches": 0, "parries": 0, "beaten": 0, "dives": 0, "pickups": 0, "distributions": 0}
var save_log: Array[Dictionary] = []

var _tune: KeeperTuning = null
var _motion := ActionMotion.new()
var _plan: Dictionary = {}
var _state_time: float = 0.0
var _threat_since: float = -1.0
var _evaluated: bool = false
var _anchor: Node3D = null
var _capsule: CollisionShape3D = null
var _hold_left: float = 0.0
var _dist: Dictionary = {}
var _released: bool = false
var _dropped: bool = false
var _kick_done: bool = false
var _clock: float = 0.0
var _rest_clip_played: bool = false
var _idle_time: float = 0.0
var _plan_clock: float = 0.0
var _replan_cd: float = 0.0
## Segundos seguidos que la pelota lleva casi parada (para resolver un barullo en el area).
var _ball_still: float = 0.0
var _kick_seen_since: float = -1.0
## Entrada de la persona (null = decide la IA). Un arquero controlado obedece el joystick: no se lanza por su cuenta
## mientras la persona lo esta moviendo, y usa los botones para atrapar, despejar y sacar.
var input_source: InputSource = null
var is_human_controlled: bool = false
var _stick: Vector3 = Vector3.ZERO
var _stick_mag: float = 0.0
var _stick_idle: float = 10.0
var _button_cd: float = 0.0
## Segundos que la pelota lleva controlada con el pie tras un pase del propio equipo (0 = no la tiene en los pies).
var _foot_ball: float = 0.0

func _ready() -> void:
	add_to_group("keepers")
	rng.randomize()
	_tune = Tuning.keeper
	collision_layer = Ball.LAYER_KEEPERS
	collision_mask = Ball.LAYER_WORLD | Ball.LAYER_PLAYERS
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	_capsule = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	_capsule.shape = cap
	_capsule.position = Vector3(0.0, 0.875, 0.0)
	add_child(_capsule)
	_anchor = Node3D.new()
	_anchor.name = "HandsAnchor"
	add_child(_anchor)
	_anchor.position = Vector3(0.0, _tune.carry_height, 0.0)
	visual = FootballerVisual.new()
	visual.name = "Visual"
	visual.keeper_mode = true
	add_child(visual)
	visual.build(FootballerVisual.keeper_kit())

## Configura el arquero dentro de un partido y lo coloca en su arco.
func setup(context: MatchContext, team_index: int, id: int, attrs: PlayerAttributes) -> void:
	ctx = context
	team = team_index
	actor_id = id
	attributes = attrs
	ctx.register_keeper(self)
	if not ctx.event_emitted.is_connected(_on_match_event):
		ctx.event_emitted.connect(_on_match_event)
	reset_position()

func _exit_tree() -> void:
	if ctx != null:
		ctx.unregister_keeper(self)
		if ctx.event_emitted.is_connected(_on_match_event):
			ctx.event_emitted.disconnect(_on_match_event)

# --- Geometria del arco ------------------------------------------------------------------------

func goal_side() -> int:
	return -1 if team == 0 else 1

func goal_x() -> float:
	return float(goal_side()) * ctx.pitch.config.half_length()

func inward() -> Vector3:
	return Vector3(-float(goal_side()), 0.0, 0.0)

func forward() -> Vector3:
	return Locomotion.dir_from_yaw(yaw)

func right_vec() -> Vector3:
	var f: Vector3 = forward()
	return Vector3(-f.z, 0.0, f.x)

func reset_position() -> void:
	_cancel_action(true)
	state = State.POSITION
	yaw = Locomotion.yaw_from_dir(inward())
	rotation.y = yaw
	global_position = Vector3(goal_x(), 0.0, 0.0) + inward() * _tune.base_depth
	velocity = Vector3.ZERO

func _norm(key: String) -> float:
	return attributes.norm(key)

# --- Bucle ---------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if ctx == null or ctx.ball == null or ctx.pitch == null:
		return
	_clock += delta
	_state_time += delta
	_button_cd = maxf(_button_cd - delta, 0.0)
	_read_input(delta)
	_watch_kickers()
	if ctx.ball.linear_velocity.length() < 0.6 and not ctx.ball.is_held():
		_ball_still += delta
	else:
		_ball_still = 0.0
	if _foot_ball > 0.0:
		_foot_ball += delta
		if ctx.ball.is_held() or KickModel.flat(ctx.ball.global_position - global_position).length() > 1.6:
			_foot_ball = 0.0
	match state:
		State.POSITION:
			_tick_position(delta)
		State.PREPARE:
			_tick_prepare(delta)
		State.ACTION:
			_tick_action(delta)
		State.HOLD:
			_tick_hold(delta)
		State.DISTRIBUTE:
			_tick_distribute(delta)
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 9.81 * delta
	move_and_slide()
	rotation.y = yaw
	var f: Vector3 = forward()
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	visual.directional = state == State.POSITION or state == State.PREPARE or state == State.HOLD
	visual.dir_velocity = Vector2(flat.dot(f), flat.dot(right_vec()))
	visual.drive_motion(flat.length(), 0.0, delta)

# --- Posicionamiento y deteccion de disparos ------------------------------------------------------

func _tick_position(delta: float, preparing: bool = false) -> void:
	var ball: Ball = ctx.ball
	if not preparing:
		_assess_shot()
		if state != State.POSITION:
			return
		if is_human_controlled:
			_tick_manual(delta)
			return
		if _receive_backpass(delta):
			return
		if _try_pickup():
			return
	# Objetivo: sobre el arco, en la linea arco-pelota, mas adelantado cuanto mas cerca esta el peligro.
	var g := Vector3(goal_x(), 0.0, 0.0)
	var b := Vector3(ball.global_position.x, 0.0, ball.global_position.z)
	var to_ball: Vector3 = b - g
	var d: float = to_ball.length()
	var dir: Vector3 = to_ball / d if d > 0.1 else inward()
	var pos_k: float = lerpf(0.85, 1.2, _norm("positioning"))
	var depth: float = lerpf(_tune.base_depth, _tune.max_depth, clampf((14.0 - d) / 14.0, 0.0, 1.0)) * pos_k
	depth = clampf(depth, 0.4, _tune.max_depth)
	var target: Vector3 = g + dir * depth
	var hz: float = ctx.pitch.config.half_goal() + 0.9
	target.z = clampf(target.z, -hz, hz)
	var to_t: Vector3 = target - global_position
	to_t.y = 0.0
	var speed_cap: float = _tune.move_speed * lerpf(0.9, 1.15, _norm("reflexes"))
	var want: Vector3 = to_t.normalized() * minf(to_t.length() * 5.0, speed_cap) if to_t.length() > 0.06 else Vector3.ZERO
	var cur := Vector3(velocity.x, 0.0, velocity.z)
	cur = cur.move_toward(want, _tune.accel * delta)
	velocity.x = cur.x
	velocity.z = cur.z
	# Mira la pelota (o hacia el campo si la tiene).
	var face: Vector3 = (b - global_position)
	face.y = 0.0
	if state == State.HOLD or face.length() < 0.3:
		face = inward()
	var dy: float = wrapf(Locomotion.yaw_from_dir(face.normalized()) - yaw, -PI, PI)
	yaw = wrapf(yaw + clampf(dy, -deg_to_rad(420.0) * delta, deg_to_rad(420.0) * delta), -PI, PI)

## Anota desde cuando un rival cercano a la pelota esta armando una patada hacia su arco (para adelantar la reaccion).
func _watch_kickers() -> void:
	var seen: bool = false
	var bp: Vector3 = ctx.ball.global_position
	if absf(bp.x - goal_x()) < 16.0:
		for f in ctx.footballers:
			if f.team != team and f.ball_handler.is_kick_in_progress() and Vector2(f.global_position.x - bp.x, f.global_position.z - bp.z).length() < 1.5:
				seen = true
				break
	if seen:
		if _kick_seen_since < 0.0:
			_kick_seen_since = _clock
	elif _kick_seen_since >= 0.0 and ctx.ball.linear_velocity.length() < _tune.shot_min_speed:
		_kick_seen_since = -1.0

## Revisa si hay un disparo a puerta; si lo hay, tras el tiempo de reaccion planifica y empieza la atajada.
func _assess_shot() -> void:
	var ball: Ball = ctx.ball
	if ball.is_held():
		_threat_since = -1.0
		return
	var v: Vector3 = ball.linear_velocity
	var side: float = float(goal_side())
	if v.length() < _tune.shot_min_speed or v.x * side < 1.0:
		_threat_since = -1.0
		return
	# Un pase de un companero NO es un disparo: se recibe, no se ataja. Solo si viene muy fuerte (rebote, despeje
	# desviado) se trata como peligro.
	if ball.last_touch_team == team and v.length() < _tune.backpass_speed_max:
		_threat_since = -1.0
		return
	# Con la persona moviendo el joystick el arquero no se lanza solo: manda el mando.
	if is_human_controlled and _stick_idle < MANUAL_AUTO_SAVE_IDLE:
		_threat_since = -1.0
		return
	var traj: PackedVector3Array = BallPredictor.trajectory(ball.global_position, v, _tune.plan_horizon)
	var ci: int = BallPredictor.crossing_x(traj, goal_x(), side)
	if ci < 0:
		_threat_since = -1.0
		return
	var cp: Vector3 = traj[ci]
	var cfg: PitchConfig = ctx.pitch.config
	if absf(cp.z) > cfg.half_goal() + 0.35 or cp.y > cfg.goal_height + 0.35:
		_threat_since = -1.0
		return
	if _threat_since < 0.0:
		# Lee el cuerpo del rival: si ya estaba armando el disparo, la reaccion arranco antes de que saliera la pelota.
		var lead: float = 0.0
		if _kick_seen_since >= 0.0:
			lead = clampf(_clock - _kick_seen_since, 0.0, KICK_READ_MAX) * lerpf(0.5, 1.0, _norm("reflexes"))
		_threat_since = _clock - lead
		stats["shots_faced"] += 1
	var dist_shot: float = absf(ball.global_position.x - goal_x())
	var react: float = maxf(0.05, _tune.reaction_time * lerpf(1.5, 0.65, _norm("reflexes")) - _tune.anticipation_gain * dist_shot / 10.0)
	if _clock - _threat_since < react:
		return
	var plan: Dictionary = KeeperPlanner.plan_save(_origin_after_stop(), yaw, traj, 1.0 / 30.0, 0.0, v.length(), false)
	if plan.is_empty() or float(plan["dist"]) > _tune.effort_radius:
		# Sin posibilidad de llegar: sigue mirando; el cuerpo todavia puede tapar con la colision.
		_log_save(&"no_chance", {"dist": plan.get("dist", -1.0), "speed": v.length()})
		_threat_since = _clock + 5.0
		return
	_plan = plan
	_plan["ball_speed"] = v.length()
	_plan_clock = _clock
	_replan_cd = 0.1
	_state_time = 0.0
	state = State.PREPARE
	_threat_since = -1.0

## Donde quedara el arquero si frena desde ahora (los planes se hacen desde ese punto: en la preparacion se planta).
func _origin_after_stop() -> Vector3:
	var v := Vector3(velocity.x, 0.0, velocity.z)
	var a: float = _tune.accel * 1.5
	return global_position + v * (v.length() / (2.0 * a))

## Preparacion: sigue replanificando (posicion y trayectoria actuales) y se planta justo antes de lanzarse.
func _tick_prepare(delta: float) -> void:
	var remaining: float = float(_plan["delay"]) - (_clock - _plan_clock)
	# Se planta desde el primer instante: los planes asumen el punto donde queda parado.
	var cur := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, _tune.accel * 1.5 * delta)
	velocity.x = cur.x
	velocity.z = cur.z
	if remaining > 0.08:
		_replan_cd -= delta
		if _replan_cd <= 0.0:
			_replan_cd = 0.08
			_replan()
		return
	if remaining <= 0.0:
		_begin_action()

func _replan() -> void:
	var ball: Ball = ctx.ball
	if ball.is_held():
		state = State.POSITION
		return
	var v: Vector3 = ball.linear_velocity
	# La amenaza cambio (desvio, bloqueo de un rival, pelota lenta): se cancela y vuelve a posicionarse.
	if v.length() < _tune.shot_min_speed * 0.6 or v.x * float(goal_side()) < 0.5:
		state = State.POSITION
		return
	var traj: PackedVector3Array = BallPredictor.trajectory(ball.global_position, v, _tune.plan_horizon)
	var plan: Dictionary = KeeperPlanner.plan_save(_origin_after_stop(), yaw, traj, 1.0 / 30.0, 0.0, v.length(), false)
	if plan.is_empty() or float(plan["dist"]) > _tune.effort_radius:
		state = State.POSITION
		return
	plan["ball_speed"] = v.length()
	_plan = plan
	_plan_clock = _clock

## Pelota suelta y lenta dentro de su area sin rival cerca: sale a recogerla con una atajada baja o la recogida.
func _try_pickup() -> bool:
	var ball: Ball = ctx.ball
	if ball.is_held() or ball.global_position.y > 0.5 or ball.linear_velocity.length() > _tune.pickup_ball_speed_max:
		return false
	if _foot_ball > 0.0:
		return false   # la cedida se juega con el pie, no se recoge con la mano
	var cfg: PitchConfig = ctx.pitch.config
	var bp: Vector3 = ball.global_position
	if (bp.x - goal_x()) * float(goal_side()) > -0.15:
		return false   # la pelota ya esta en la linea o dentro de la red
	if absf(bp.x - goal_x()) > cfg.penalty_area_radius + 1.0 or absf(bp.z) > cfg.half_goal() + cfg.penalty_area_radius:
		return false
	if Vector2(bp.x - global_position.x, bp.z - global_position.z).length() > _tune.pickup_distance:
		return false
	# Con rivales encima no sale a recoger... salvo que la pelota lleve un rato parada en el area (barullo): la saca el arquero.
	var scrum: bool = _ball_still >= SCRUM_SECONDS
	if not scrum:
		for f in ctx.footballers:
			if f.team != team and Vector2(f.global_position.x - bp.x, f.global_position.z - bp.z).length() < _tune.pickup_opponent_clearance:
				return false
	var traj := PackedVector3Array([bp, bp, bp, bp])
	var plan: Dictionary = KeeperPlanner.plan_save(global_position, yaw, traj, 0.5, 0.0, 0.0, true, [1.0])
	if plan.is_empty() or float(plan["dist"]) > 0.5:
		return false
	_plan = plan
	_plan["pickup"] = true
	_plan["delay"] = 0.0
	_state_time = 0.0
	_begin_action()
	return true

# --- Control de la persona y cedidas -------------------------------------------------------------

## Lee la entrada de la persona (si este arquero es el que maneja) y actualiza el tiempo con el joystick quieto.
func _read_input(delta: float) -> void:
	if not is_human_controlled or input_source == null or not ctx.input_enabled:
		_stick = Vector3.ZERO
		_stick_mag = 0.0
		_stick_idle = 10.0
		return
	var frame: InputFrame = input_source.poll(null)
	_stick_mag = clampf(frame.move_length(), 0.0, 1.0)
	var w: Vector3 = frame.move_world if frame.use_world else ctx.screen_to_world(frame.move)
	_stick = w.normalized() if _stick_mag > 0.05 else Vector3.ZERO
	_stick_idle = 0.0 if _stick_mag > 0.2 else _stick_idle + delta
	if _button_cd <= 0.0 and (frame.pass_pressed or frame.shoot_pressed):
		_button_cd = 0.2
		_manual_action(frame.shoot_pressed)

## Boton con el arquero controlado: con la pelota en las manos saca (PASE = corto, TIRO = largo); con la pelota
## suelta a su alcance la atrapa si viene suave y la despeja si no.
func _manual_action(long: bool) -> void:
	var ball: Ball = ctx.ball
	if ball.holder == self:
		_begin_distribution(&"throw" if not long else &"kick")
		return
	if state != State.POSITION:
		return
	var off: Vector3 = KickModel.flat(ball.global_position - global_position)
	if off.length() > _tune.reach + 0.35 or ball.global_position.y > 1.6:
		return
	if ball.linear_velocity.length() <= _tune.pickup_ball_speed_max * 1.6 and ball.global_position.y < 1.2:
		_catch_in_place()
	else:
		_clear_ball(off)

## Atrapa la pelota donde esta (boton del arquero controlado): pasa a sostenerla y esperar orden de saque.
func _catch_in_place() -> void:
	var ball: Ball = ctx.ball
	ball.hold(_anchor, self)
	stats["catches"] += 1
	_foot_ball = 0.0
	ctx.emit_event(GameEvent.make(GameEvent.Type.KEEPER_CATCH, actor_id, team, {"manual": true}))
	_enter_hold()

## Despeje de emergencia con el pie hacia donde mira el arquero (o hacia el campo si no hay direccion).
func _clear_ball(off: Vector3) -> void:
	var ball: Ball = ctx.ball
	var dir: Vector3 = _stick if _stick.length_squared() > 0.01 else inward()
	var v: Vector3 = dir.normalized() * _tune.clearance_speed + Vector3.UP * 3.0
	ball.kick(v, Vector3.ZERO, self)
	_foot_ball = 0.0
	stats["distributions"] += 1
	ctx.emit_event(GameEvent.make(GameEvent.Type.KEEPER_DISTRIBUTE, actor_id, team, {"mode": "clear", "manual": true}))

## Movimiento del arquero que maneja la persona: va a donde apunta el joystick, mirando siempre a la pelota.
func _tick_manual(delta: float) -> void:
	var ball: Ball = ctx.ball
	var want: Vector3 = _stick * (_tune.manual_speed * _stick_mag)
	var cur := Vector3(velocity.x, 0.0, velocity.z)
	cur = cur.move_toward(want, _tune.accel * delta)
	velocity.x = cur.x
	velocity.z = cur.z
	# Con la pelota suelta al alcance del pie, la controla (no se la queda bajo los pies sin tocarla).
	if _foot_ball <= 0.0 and not ball.is_held() and ball.global_position.y < 0.6:
		var off: Vector3 = KickModel.flat(ball.global_position - global_position)
		if off.length() < FOOT_TRAP_RANGE and ball.linear_velocity.length() < _tune.backpass_speed_max:
			_foot_trap(off)
	_face_ball(delta)

## Orienta el cuerpo hacia la pelota (o hacia el campo si la tiene encima).
func _face_ball(delta: float) -> void:
	var face: Vector3 = KickModel.flat(ctx.ball.global_position - global_position)
	if face.length() < 0.3:
		face = inward()
	var dy: float = wrapf(Locomotion.yaw_from_dir(face.normalized()) - yaw, -PI, PI)
	yaw = wrapf(yaw + clampf(dy, -deg_to_rad(420.0) * delta, deg_to_rad(420.0) * delta), -PI, PI)

## Cedida de un companero: el arquero sale a su encuentro y la para con el pie en vez de lanzarse. Devuelve true
## si esta ocupandose de ella (entonces no hace nada mas en este paso).
func _receive_backpass(delta: float) -> bool:
	var ball: Ball = ctx.ball
	if ball.is_held() or ball.last_touch_team != team or ball.global_position.y > 0.6:
		return false
	var v: Vector3 = KickModel.flat(ball.linear_velocity)
	var off: Vector3 = KickModel.flat(ball.global_position - global_position)
	if _foot_ball > 0.0:
		# Ya la tiene en los pies: la juega con el pie tras una pausa corta.
		velocity.x = 0.0
		velocity.z = 0.0
		_face_ball(delta)
		if _foot_ball >= FOOT_PLAY_DELAY:
			_begin_distribution(&"foot")
		return true
	if v.length() > _tune.backpass_speed_max or off.length() > _tune.pickup_distance * 1.6:
		return false
	# Solo si viene hacia el (si no, es una jugada del equipo, no una cedida).
	if v.length() > 0.6 and v.normalized().dot(off.normalized() * -1.0) < 0.4:
		return false
	if off.length() <= FOOT_TRAP_RANGE:
		_foot_trap(off)
		return true
	var want: Vector3 = off.normalized() * minf(off.length() * 3.0, _tune.move_speed)
	var cur := Vector3(velocity.x, 0.0, velocity.z)
	cur = cur.move_toward(want, _tune.accel * delta)
	velocity.x = cur.x
	velocity.z = cur.z
	_face_ball(delta)
	return true

## Para la pelota con el pie: amortigua su velocidad y la deja junto al arquero.
func _foot_trap(off: Vector3) -> void:
	var ball: Ball = ctx.ball
	var place: Vector3 = global_position + (off.normalized() if off.length() > 0.1 else forward()) * 0.42
	var v: Vector3 = KickModel.flat(place - ball.global_position) * 1.6
	ball.kick(v, ball.rolling_spin(v), self)
	_foot_ball = 0.0001
	ctx.emit_event(GameEvent.make(GameEvent.Type.FIRST_TOUCH, actor_id, team, {"keeper": true}))

# --- Atajada ---------------------------------------------------------------------------------------

func _begin_action() -> void:
	state = State.ACTION
	_state_time = 0.0
	_evaluated = false
	var clip: StringName = _plan["clip"]
	visual.play_pack_clip(clip, float(_plan["speed"]))
	_motion.start(clip, float(_plan["speed"]))
	_set_lying(true)
	if not _plan.get("pickup", false):
		stats["dives"] += 1

func _tick_action(delta: float) -> void:
	var rv: Vector2 = _motion.step(delta)
	var f: Vector3 = forward()
	var r: Vector3 = right_vec()
	var wv: Vector3 = f * rv.x + r * rv.y
	velocity.x = wv.x
	velocity.z = wv.z
	var k: int = int(_motion.t * 30.0)
	if ctx.ball.holder == self:
		_anchor.global_position = KeeperPlanner.path_world_at_body(_plan["clip"], "hands", k, global_position, yaw)
	if not _evaluated and _motion.t >= float(_plan["tau"]):
		_evaluated = true
		_evaluate_contact(k)
	if not _motion.active:
		_set_lying(false)
		if ctx.ball.holder == self:
			_enter_hold()
		else:
			state = State.POSITION
			_state_time = 0.0
			velocity = Vector3.ZERO

func _evaluate_contact(k: int) -> void:
	var ball: Ball = ctx.ball
	var clip: StringName = _plan["clip"]
	var hands: Vector3 = KeeperPlanner.path_world_at_body(clip, "hands", k, global_position, yaw)
	var d: float = hands.distance_to(ball.global_position)
	var speed: float = ball.linear_velocity.length()
	var radius: float = float(_plan["radius"]) * lerpf(0.8, 1.25, _norm("catching"))
	var info := {"clip": String(clip), "dist": d, "speed": speed, "radius": radius, "pickup": _plan.get("pickup", false)}
	if ball.is_held() or d > radius:
		stats["beaten"] += 1
		_log_save(&"beaten", info)
		return
	var is_dive: bool = String(clip).contains("diving") or String(clip).contains("sidestep")
	var catch_limit: float = _tune.catch_speed_max * attributes.factor("catching", 0.4) * (_tune.dive_catch_factor if is_dive else 1.0)
	if _plan.get("pickup", false) or speed <= catch_limit:
		ball.hold(_anchor, self)
		_anchor.global_position = hands
		stats["catches"] += 1
		if _plan.get("pickup", false):
			stats["pickups"] += 1
		_log_save(&"catch", info)
		saved.emit(&"catch")
		ctx.emit_event(GameEvent.make(GameEvent.Type.SAVE, actor_id, team, {"kind": "catch", "speed": speed, "clip": String(clip)}))
		ctx.emit_event(GameEvent.make(GameEvent.Type.KEEPER_CATCH, actor_id, team, {"speed": speed}))
	elif speed <= _tune.parry_speed_max * attributes.factor("diving", 0.25):
		var lat: float = signf(ball.global_position.z - global_position.z)
		if lat == 0.0:
			lat = 1.0 if rng.randf() < 0.5 else -1.0
		var out_dir: Vector3 = (inward() * 0.6 + Vector3(0.0, 0.0, lat) * 0.8 + Vector3.UP * 0.25).normalized()
		var damp: float = _tune.deflect_damping * lerpf(1.3, 0.8, _norm("rebound_control"))
		var nv: Vector3 = out_dir * maxf(speed * damp, 3.5)
		ball.kick(nv, ball.rolling_spin(nv) * 0.3, self)
		stats["parries"] += 1
		_log_save(&"parry", info)
		saved.emit(&"parry")
		ctx.emit_event(GameEvent.make(GameEvent.Type.SAVE, actor_id, team, {"kind": "parry", "speed": speed, "clip": String(clip)}))
	else:
		stats["beaten"] += 1
		_log_save(&"too_hard", info)

func _log_save(result: StringName, info: Dictionary) -> void:
	var e := {"result": result, "time": _clock}
	e.merge(info)
	save_log.append(e)
	if save_log.size() > 64:
		save_log.pop_front()

func _set_lying(on: bool) -> void:
	var cap: CapsuleShape3D = _capsule.shape as CapsuleShape3D
	cap.height = 0.6 if on else 1.75
	_capsule.position.y = 0.3 if on else 0.875

func _cancel_action(release_ball: bool) -> void:
	_motion.stop()
	if visual != null:
		visual.stop_current_action()
	if _capsule != null:
		_set_lying(false)
	if release_ball and ctx != null and ctx.ball != null and ctx.ball.holder == self:
		ctx.ball.release(self, Vector3.ZERO)

# --- Sostener y sacar ----------------------------------------------------------------------------------

func _enter_hold() -> void:
	state = State.HOLD
	_state_time = 0.0
	_hold_left = lerpf(_tune.hold_time_max, _tune.hold_time_min, _norm("reflexes") * 0.5 + _norm("throwing") * 0.5) * rng.randf_range(0.9, 1.1)
	_anchor.position = Vector3(0.0, _tune.carry_height, -_tune.carry_forward)
	_anchor.position = Vector3(0.0, _tune.carry_height, 0.0)
	velocity = Vector3.ZERO

func _tick_hold(delta: float) -> void:
	var ball: Ball = ctx.ball
	if ball.holder != self:
		state = State.POSITION
		return
	# El ancla va delante del pecho (marco del cuerpo, ya girado).
	_anchor.global_position = global_position + forward() * _tune.carry_forward + Vector3.UP * _tune.carry_height
	_tick_position(delta, true)
	if is_human_controlled:
		# Con el arquero en las manos de la persona, el saque lo ordena ella (hay un limite largo para que la
		# jugada no quede congelada si suelta el mando).
		if _state_time >= MANUAL_HOLD_MAX:
			_begin_distribution()
		return
	if _state_time >= _hold_left:
		_begin_distribution()

## Elige companero libre y el tipo de saque; si no hay companero, despeja hacia el campo.
func _choose_distribution(force_mode: StringName = &"") -> Dictionary:
	var mine: Vector3 = global_position
	var best: Footballer = null
	var best_score: float = -INF
	for f in ctx.footballers:
		if f.team != team:
			continue
		var fp: Vector3 = f.global_position
		var progress: float = (fp.x - mine.x) * float(-goal_side())
		var open: float = 6.0
		for o in ctx.footballers:
			if o.team != team:
				open = minf(open, Vector2(o.global_position.x - fp.x, o.global_position.z - fp.z).length())
		var score: float = progress * 0.5 + open * 2.0 - Vector2(fp.x - mine.x, fp.z - mine.z).length() * 0.2
		if open < 2.0:
			score -= 20.0
		if score > best_score:
			best_score = score
			best = f
	var target: Vector3 = best.global_position if best != null else Vector3(goal_x() + inward().x * 16.0, 0.0, rng.randf_range(-4.0, 4.0))
	var dist: float = Vector2(target.x - mine.x, target.z - mine.z).length()
	var mode: StringName = &"roll" if dist < 8.0 else (&"throw" if dist < 18.0 else &"kick")
	if force_mode != &"":
		mode = force_mode
	# Pase con el pie (cedida): se juega con un clip de campo, la pelota no pasa por las manos.
	if mode == &"foot":
		var fclip: StringName = &"Soccer_Pass" if PackLibrary.has_clip(&"Soccer_Pass") else &""
		return {"clip": fclip, "mode": mode, "target": target, "dist": dist}
	var clip: StringName = &"goalkeeper_pass" if mode == &"roll" else (&"goalkeeper_overhand_throw" if mode == &"throw" else &"goalkeeper_drop_kick")
	if mode == &"throw" and rng.randf() < 0.4:
		clip = &"Goalie_Throw"
	if not PackLibrary.has_clip(clip):
		clip = &""
	# Espejo para sacar con el lado que mira al companero.
	if clip != &"" and (target.z - mine.z) * float(goal_side()) * -1.0 < 0.0 and PackLibrary.has_clip(StringName(String(clip) + "_mirror")):
		clip = StringName(String(clip) + "_mirror")
	return {"clip": clip, "mode": mode, "target": target, "dist": dist}

## Empieza el saque. `force_mode` lo fija la persona (o la cedida con el pie); vacio = lo elige el arquero.
func _begin_distribution(force_mode: StringName = &"") -> void:
	_dist = _choose_distribution(force_mode)
	var clip: StringName = _dist["clip"]
	_released = false
	_dropped = false
	_kick_done = false
	state = State.DISTRIBUTE
	_state_time = 0.0
	if clip == &"" or not visual.uses_pack:
		_dist["tau"] = 0.4
		_dist["clip"] = &""
		return
	visual.play_pack_clip(clip, 1.15)
	_motion.start(clip, 1.15)
	var key: String = "hands"
	if _dist["mode"] == &"foot":
		var fp: Dictionary = PackLibrary.meta(clip).get("paths", {})
		key = "toe_r" if fp.has("toe_r") else ("toe_l" if fp.has("toe_l") else "hands")
	elif _dist["mode"] == &"kick":
		var toes: Dictionary = PackLibrary.meta(clip).get("paths", {})
		key = "toe_r" if toes.has("toe_r") and _toe_speed(clip, "toe_r") >= _toe_speed(clip, "toe_l") else "toe_l"
	_dist["key"] = key
	_dist["tau"] = KeeperPlanner.peak_speed_time(clip, key)
	_dist["start_pos"] = global_position

func _toe_speed(clip: StringName, key: String) -> float:
	var hp: PackedVector3Array = PackLibrary.meta(clip).get("paths", {}).get(key, PackedVector3Array())
	var best: float = 0.0
	for i in range(1, hp.size() - 1):
		best = maxf(best, (hp[i + 1] - hp[i - 1]).length())
	return best

func _tick_distribute(delta: float) -> void:
	var ball: Ball = ctx.ball
	var clip: StringName = _dist["clip"]
	var rv: Vector2 = _motion.step(delta) if clip != &"" else Vector2.ZERO
	var wv: Vector3 = forward() * rv.x + right_vec() * rv.y
	velocity.x = wv.x
	velocity.z = wv.z
	var tgt: Vector3 = _dist["target"]
	# Mira hacia donde saca.
	var face: Vector3 = tgt - global_position
	face.y = 0.0
	if face.length() > 0.5:
		var dy: float = wrapf(Locomotion.yaw_from_dir(face.normalized()) - yaw, -PI, PI)
		yaw = wrapf(yaw + clampf(dy, -deg_to_rad(300.0) * delta, deg_to_rad(300.0) * delta), -PI, PI)
	var k: int = int(_motion.t * 30.0)
	var tau: float = float(_dist["tau"])
	var mode: StringName = _dist["mode"]
	if clip == &"":
		_anchor.global_position = global_position + forward() * _tune.carry_forward + Vector3.UP * _tune.carry_height
		if _state_time >= tau and ball.holder == self:
			_release_ball(mode, global_position + Vector3.UP * 1.1)
		if _state_time >= 0.9:
			_finish_distribution()
		return
	if mode == &"foot":
		if not _released and _motion.t >= tau:
			_released = true
			_foot_ball = 0.0
			var ftoe: Vector3 = KeeperPlanner.path_world_at_body(clip, String(_dist.get("key", "toe_r")), k, global_position, yaw)
			if ftoe.distance_to(ball.global_position) <= 0.8:
				ball.kick(_throw_velocity(&"roll", ball.global_position, tgt), Vector3.ZERO, self)
				stats["distributions"] += 1
				ctx.emit_event(GameEvent.make(GameEvent.Type.KEEPER_DISTRIBUTE, actor_id, team, {"mode": "foot", "dist": _dist["dist"]}))
		if not _motion.active or (clip == &"" and _state_time > 0.5):
			_finish_distribution()
		return
	if ball.holder == self and not _released:
		var key: String = "hands"
		if mode == &"kick":
			# Patada de despeje: suelta la pelota un instante antes del golpeo y la golpea con el pie.
			if not _dropped and _motion.t >= tau - 0.38:
				_dropped = true
				var hp: Vector3 = KeeperPlanner.path_world_at_body(clip, "hands", k, global_position, yaw)
				ball.release(self, Vector3.ZERO)
				ball.global_position = hp
			else:
				_anchor.global_position = KeeperPlanner.path_world_at_body(clip, key, k, global_position, yaw)
		else:
			_anchor.global_position = KeeperPlanner.path_world_at_body(clip, key, k, global_position, yaw)
			if _motion.t >= tau:
				_release_ball(mode, _anchor.global_position)
	if mode == &"kick" and _dropped and not _kick_done and _motion.t >= tau:
		_kick_done = true
		var toe: Vector3 = KeeperPlanner.path_world_at_body(clip, String(_dist["key"]), k, global_position, yaw)
		if toe.distance_to(ball.global_position) <= 0.55:
			ball.kick(_throw_velocity(&"kick", toe, tgt), Vector3.ZERO, self)
			_released = true
			stats["distributions"] += 1
			ctx.emit_event(GameEvent.make(GameEvent.Type.KEEPER_DISTRIBUTE, actor_id, team, {"mode": "kick", "dist": _dist["dist"]}))
		else:
			_released = true
	if not _motion.active:
		_finish_distribution()

func _release_ball(mode: StringName, from: Vector3) -> void:
	var ball: Ball = ctx.ball
	var v: Vector3 = _throw_velocity(mode, from, _dist["target"])
	ball.release(self, v)
	ball.global_position = from
	ball.register_touch(self)
	_released = true
	stats["distributions"] += 1
	ctx.emit_event(GameEvent.make(GameEvent.Type.KEEPER_DISTRIBUTE, actor_id, team, {"mode": String(mode), "dist": _dist["dist"]}))

## Velocidad de salida para que la pelota llegue a `target` (con error segun el atributo de saque).
func _throw_velocity(mode: StringName, from: Vector3, target: Vector3) -> Vector3:
	var d := Vector3(target.x - from.x, 0.0, target.z - from.z)
	var dist: float = d.length()
	var dir: Vector3 = d / dist if dist > 0.01 else inward()
	var key: String = "kicking" if mode == &"kick" else "throwing"
	var err: float = deg_to_rad(rng.randfn(0.0, lerpf(9.0, 2.5, _norm(key))))
	dir = dir.rotated(Vector3.UP, err)
	if mode == &"roll":
		return dir * clampf(dist * 0.9 + 2.0, 4.0, 11.0)
	var vmax: float = _tune.kick_speed if mode == &"kick" else _tune.throw_speed
	if mode == &"kick":
		vmax = lerpf(_tune.kick_speed, _tune.clearance_speed, 0.5)
	var g: float = BallPredictor.GRAVITY
	var v: float = minf(vmax, maxf(sqrt(g * dist) * 1.08, 7.0))
	var s: float = clampf(g * dist / (v * v), 0.0, 1.0)
	var theta: float = 0.5 * asin(s)
	return Vector3(dir.x * cos(theta), sin(theta), dir.z * cos(theta)) * v

func _finish_distribution() -> void:
	if ctx.ball.holder == self:
		ctx.ball.release(self, Vector3.ZERO)
	state = State.POSITION
	_state_time = 0.0
	_motion.stop()
	velocity = Vector3.ZERO
	_threat_since = -1.0

# --- Eventos del partido ------------------------------------------------------------------------------

func _on_match_event(e: GameEvent) -> void:
	match e.type:
		GameEvent.Type.KICKOFF, GameEvent.Type.RESTART, GameEvent.Type.MATCH_START:
			reset_position()
		GameEvent.Type.GOAL:
			if visual != null and not visual.is_placeholder:
				visual.stop_current_action()
				var conceded: bool = e.team != team
				_cancel_action(true)
				state = State.POSITION
				visual.play_situation(&"dejected" if conceded else &"celebrate", actor_id, 1.0, 2.4)
