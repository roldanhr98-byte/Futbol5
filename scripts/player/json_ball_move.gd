class_name JsonBallMove
extends RefCounted
## Modo 4 (Json): movimientos con pelota de los clips JSON. Giros con pelota (de 45 a 180 grados, desde parado o en carrera),
## la vuelta atras pisando la pelota (REGATE + atras), regates (REGATE) y frenadas con la pelota. Como en FIFA/PES el
## movimiento es un clip con sus toques: el clip mueve y gira al cuerpo (raiz y rumbo, PlayerActions/ActionMotion) y la
## pelota va de un toque del clip al siguiente. Cada toque (instante y pie medidos en los datos, meta ball_touches) le da a
## la pelota el impulso que la lleva hasta donde estara la punta del pie en el toque siguiente; el ultimo la deja delante del
## rumbo de salida y sigue la conduccion normal. La pelota solo cambia de velocidad con Ball.kick (nunca se la coloca) y el
## pie se lleva con TouchFootIK los centimetros que falten hasta la pelota real, asi el toque se ve.
## Solo empieza si la pelota llega al primer toque (prediccion de su rodadura, con un ajuste de paso acotado); si no, siguen
## los mecanismos de siempre (BallTurn, DragBack, toques de conduccion).

## Angulo (grados) minimo entre el frente y el joystick para girar con un clip, y joystick minimo.
const TURN_MIN_ANGLE := 50.0
const MIN_STICK := 0.35
## Velocidad (m/s) maxima del cuerpo para empezar un movimiento con pelota.
const MAX_SPEED := 6.5
## Tolerancia (grados) entre el giro pedido y el del clip.
const TURN_TOL := 35.0
## Velocidad (m/s) minima y maxima para frenar con la pelota con un clip (joystick recien soltado, STOP_WINDOW s); a mas
## velocidad frena la conduccion de siempre (toque de parada).
const STOP_MIN_SPEED := 2.6
const STOP_MAX_SPEED := 4.6
const STOP_WINDOW := 0.15
## Diferencia maxima (m/s) entre la carrera de entrada del clip (v_in) y la del jugador: para los giros y frenadas que pide el
## joystick (a mas velocidad que la del clip el cuerpo frenaba en seco y perdia terreno; ahi manda el giro con toques,
## BallTurn) y para los que pide el boton REGATE (pedido explicito).
const MAX_DV_STICK := 1.5
const MAX_DV_BUTTON := 3.0
## Ajuste de paso: m/s extra del cuerpo para llegar a la pelota en el primer toque, y error (m) que cubre el pie (IK).
const CORR_SPEED := 1.4
const CORR_MAX := 0.4
const FOOT_SLACK := 0.16
## La pelota queda BALL_LEAD m por delante de la punta del pie en el sentido en que se mueve el pie (radio y holgura).
const BALL_LEAD := 0.12
## A mas de MISS_DIST m del pie en un toque, el toque se pierde; dos seguidos cancelan el movimiento.
const MISS_DIST := 0.5
## Espera maxima (s) hasta el primer toque del clip: con mas, en partido un rival tocaba o desviaba la pelota antes y el
## clip seguia hasta errar el toque (medido: primeros toques a 0.6-0.9 m tras 0.6 s de espera).
const MAX_LEAD := 0.4
## IK del pie: empieza IK_LEAD s antes del toque y se suelta IK_HOLD s despues; mas lejos de IK_MAX m no se fuerza.
const IK_LEAD := 0.16
const IK_HOLD := 0.06
const IK_MAX := 0.32
## La IA gira con un clip solo en los giros cerrados (AI_TURN_MIN grados) y como mucho uno cada AI_COOLDOWN s: mientras dura
## el clip no puede pasar (medido en un partido de IA: con giros de clip sin limite, 6-12 pases en 90 s frente a 14-17).
const AI_TURN_MIN := 110.0
const AI_COOLDOWN := 3.0
## Segundos entre movimientos y entre intentos de planificar (planificar recorre decenas de clips).
const COOLDOWN := 0.6
const PLAN_EVERY := 3

const ROLES_TURN: Array[StringName] = [&"ball_turn"]
const ROLES_DRAG: Array[StringName] = [&"ball_turn", &"ball_turn_stop", &"ball_skill"]
const ROLES_SKILL: Array[StringName] = [&"ball_skill"]
const ROLES_STOP: Array[StringName] = [&"ball_stop"]

var handler: BallHandler
var active: bool = false
var intent: StringName = &""
var clip: StringName = &""
var _touches: Array = []
var _next: int = 0
var _misses: int = 0
var _origin: Vector3 = Vector3.ZERO
var _yaw0: float = 0.0
var _speed: float = 1.0
var _length: float = 0.0
var _root_end: Vector2 = Vector2.ZERO
var _turn_end: float = 0.0
var _v_out: float = 0.0
var _first_t: float = 0.0
var _corr: Vector3 = Vector3.ZERO
var _cooldown: float = 0.0
var _plan_tick: int = 0
## Pedidos con el boton REGATE: vuelta atras pisando la pelota o regate (segundos que quedan del pedido).
var _skill_req: float = 0.0
var _ik_foot: int = -1
var _released_t: float = 0.0
## Recepcion (intencion &"receive", JsonReceive): quien toco la pelota por ultimo al planificar (si otro la toca antes del
## primer toque la recepcion se corta) y si ya hubo toque.
var _recv_toucher: Node = null
## Direccion (en el suelo) por donde llega la pelota a recibir: el pie se pone delante de ella (JsonReceive.contact_offset).
var _recv_inc: Vector3 = Vector3.ZERO
## Parte del cuerpo e instante (s del clip) del primer contacto de la recepcion (perfil de JsonReceive), e instante en que se
## corta el clip antes de su pase o golpeo posterior (-1 = sin corte).
var _recv_part: StringName = &""
var _recv_t: float = 0.0
var _recv_cut: float = -1.0
## Perfil de contacto (trayectoria de la parte del cuerpo alrededor del contacto, JsonReceive.contact_point).
var _recv_cp: Dictionary = {}
## Distancia minima (m) entre la pelota y la parte del cuerpo antes del contacto (diagnostico).
var _recv_gap: float = INF
## Trayectoria prevista de la pelota al planificar y paso de fisica del plan.
var _recv_traj: PackedVector3Array = PackedVector3Array()
var _recv_frame0: int = 0
var stats := {"started": 0, "done": 0, "touches": 0, "missed": 0, "aborted": 0}
var last := {}
## Ultimos movimientos terminados o cortados (diagnostico y pruebas).
var history: Array = []

func _init(h: BallHandler) -> void:
	handler = h

func request_skill() -> void:
	_skill_req = 0.3

## Paso de fisica (BallHandler.update, modo 4, antes de DragBack y BallTurn): decide si empieza un movimiento con pelota.
## Devuelve true si empezo (el resto del paso lo maneja la accion).
func consider(desired_dir: Vector3, stick_mag: float, dt: float) -> bool:
	_cooldown = maxf(_cooldown - dt, 0.0)
	_skill_req = maxf(_skill_req - dt, 0.0)
	_released_t = _released_t + dt if stick_mag < 0.15 else 0.0
	if active or _cooldown > 0.0:
		return false
	# Un giro con toques o una vuelta pisando la pelota ya en curso no se interrumpe (sumados, el giro tardaba el doble).
	if handler.ball_turn.active() or handler.drag_back.active():
		return false
	var owner: Footballer = handler.owner
	if owner.actions == null or owner.actions.active() or not owner.actions._can_play():
		return false
	if handler.is_kick_in_progress() or handler._pending_action != &"" or not handler.has_possession():
		return false
	# Cargando un pase o tiro no se gira con la pelota: si el destino queda atras, el golpeo mismo gira (plan_turn_kick).
	if handler._pass_active or handler._shoot_active or handler._through_active or handler._cross_active:
		return false
	var b: Ball = handler.ball()
	if b == null or b.is_held() or b.global_position.y > 0.3 or handler.ball_distance() > 1.4:
		return false
	var loco: Locomotion = owner.locomotion
	if loco.speed > MAX_SPEED:
		return false
	var fwd: Vector3 = loco.forward()
	var has_dir: bool = stick_mag >= MIN_STICK and desired_dir.length_squared() > 0.01
	var ang: float = 0.0
	if has_dir:
		var dir: Vector3 = KickModel.flat(desired_dir).normalized()
		ang = rad_to_deg(wrapf(Locomotion.yaw_from_dir(dir) - loco.yaw, -PI, PI))
	var roles: Array[StringName] = []
	var want: float = 0.0
	var tol: float = TURN_TOL
	var new_intent: StringName = &""
	if _skill_req > 0.0:
		if has_dir and absf(ang) >= DragBack.MIN_ANGLE - 15.0:
			roles = ROLES_DRAG
			want = 180.0 * (signf(ang) if absf(ang) < 178.0 else 1.0)
			tol = 55.0
			new_intent = &"drag"
		else:
			roles = ROLES_SKILL
			want = ang
			tol = 70.0 if has_dir else 200.0
			new_intent = &"skill"
	elif has_dir and absf(ang) >= (TURN_MIN_ANGLE if owner.is_human_controlled else AI_TURN_MIN):
		roles = ROLES_TURN
		want = ang
		new_intent = &"turn"
	elif not has_dir and _released_t > 0.0 and _released_t <= STOP_WINDOW and loco.speed >= STOP_MIN_SPEED and loco.speed <= STOP_MAX_SPEED and handler.is_dribbling():
		roles = ROLES_STOP
		want = 0.0
		tol = 60.0
		new_intent = &"stop"
	else:
		return false
	# Planificar recorre decenas de clips: no en cada paso (salvo un pedido con el boton, que es puntual).
	_plan_tick += 1
	if new_intent != &"drag" and new_intent != &"skill" and _plan_tick % PLAN_EVERY != 0:
		return false
	var plan: Dictionary = plan_move(roles, want, tol, new_intent == &"drag", MAX_DV_BUTTON if (new_intent == &"drag" or new_intent == &"skill") else MAX_DV_STICK)
	if plan.is_empty():
		return false
	if not _start(plan, new_intent):
		return false
	if not owner.is_human_controlled:
		_cooldown = AI_COOLDOWN
	return true

## Golpeo pedido hacia `dir` casi detras del jugador: giro con la pelota hacia alli (el golpeo espera a que termine).
func turn_for_kick(dir: Vector3) -> bool:
	var owner: Footballer = handler.owner
	if active or owner.actions == null or owner.actions.active() or not owner.actions._can_play():
		return false
	var ang: float = rad_to_deg(wrapf(Locomotion.yaw_from_dir(KickModel.flat(dir).normalized()) - owner.locomotion.yaw, -PI, PI))
	var roles: Array[StringName] = [&"ball_turn", &"ball_turn_stop"]
	var plan: Dictionary = plan_move(roles, ang, 50.0, absf(ang) > 165.0)
	if plan.is_empty():
		return false
	return _start(plan, &"kick_turn")

## Elige el clip, el instante de inicio y el ajuste de paso para que la pelota llegue al primer toque del clip.
## {} si ninguno llega. want: giro pedido (grados, + izquierda); tol: tolerancia; both_sides: vale girar por cualquier lado.
func plan_move(roles: Array[StringName], want: float, tol: float, both_sides: bool = false, max_dv: float = MAX_DV_BUTTON) -> Dictionary:
	var owner: Footballer = handler.owner
	var loco: Locomotion = owner.locomotion
	var b: Ball = handler.ball()
	var best: Dictionary = {}
	var best_score: float = INF
	var pos: Vector3 = KickModel.flat(owner.global_position)
	for role in roles:
		for id in PackLibrary.by_role(role):
			var m: Dictionary = PackLibrary.meta(id)
			var bt: Array = m.get("ball_touches", [])
			if bt.is_empty():
				continue
			var hp: PackedFloat32Array = m.get("heading_path", PackedFloat32Array())
			var dur: float = float(m.get("duration", 1.0))
			var turn: float = rad_to_deg(ActionMotion.heading_rel(hp, dur))
			var dturn: float = absf(turn - want)
			if both_sides:
				dturn = minf(dturn, absf(turn + want))
			if dturn > tol:
				continue
			var v_in: float = float(m.get("v_in", 0.0))
			var dv: float = absf(v_in - loco.speed)
			if dv > max_dv:
				continue
			var rp: PackedVector2Array = m.get("root_path", PackedVector2Array())
			for start_at in [0.0, 0.1, 0.2, 0.3]:
				var t1: float = float(bt[0][0])
				if t1 - start_at < 0.12:
					break
				var yaw0: float = loco.yaw - ActionMotion.heading_rel(hp, start_at)
				var f0: Vector3 = Locomotion.dir_from_yaw(yaw0)
				var r0 := Vector3(-f0.z, 0.0, f0.x)
				var rs: Vector2 = ActionMotion._at(rp, start_at) if rp.size() >= 2 else Vector2.ZERO
				var origin: Vector3 = pos - f0 * rs.x - r0 * rs.y
				var p1: Vector3 = bt[0][2]
				var vel1: Vector2 = bt[0][3]
				var lead: Vector3 = (f0 * vel1.x + r0 * vel1.y).normalized() * BALL_LEAD if vel1.length() > 0.3 else Vector3.ZERO
				var target: Vector3 = origin + f0 * p1.x + r0 * p1.z + lead
				var dt1: float = t1 - start_at
				if dt1 > MAX_LEAD:
					continue
				var bp: Vector3 = KickModel.flat(b.global_position + handler.ball_travel(b, dt1))
				var err: Vector3 = bp - target
				var corr: Vector3 = err.limit_length(minf(CORR_MAX, CORR_SPEED * dt1))
				var residual: float = (err - corr).length()
				if residual > FOOT_SLACK:
					continue
				var score: float = residual + 0.25 * corr.length() + 0.12 * dv + 0.004 * dturn + 0.03 * start_at + handler.rng.randf() * 0.04
				if score < best_score:
					best_score = score
					best = {"clip": id, "start_at": start_at, "yaw0": yaw0, "origin": origin, "corr": corr, "dt1": dt1, "residual": residual, "turn": turn}
	return best

func _start(plan: Dictionary, new_intent: StringName) -> bool:
	var owner: Footballer = handler.owner
	var id: StringName = plan["clip"]
	if not owner.actions.start_move(&"ball_move", id, 1.0, float(plan["start_at"])):
		return false
	var m: Dictionary = PackLibrary.meta(id)
	active = true
	intent = new_intent
	clip = id
	_touches = m.get("ball_touches", [])
	_next = 0
	_misses = 0
	_origin = plan["origin"]
	_yaw0 = float(plan["yaw0"])
	_speed = 1.0
	_length = float(m.get("duration", 1.0))
	_root_end = m.get("root_total", Vector2.ZERO)
	_turn_end = ActionMotion.heading_rel(m.get("heading_path", PackedFloat32Array()), _length)
	_v_out = float(m.get("v_out", 0.0))
	_first_t = float(plan["dt1"])
	var dt1: float = maxf(float(plan["dt1"]), 0.05)
	_corr = (plan["corr"] as Vector3) / dt1
	owner.actions.motion.extra_velocity = _corr
	_skill_req = 0.0
	handler.drag_back.cancel("movimiento")
	handler.ball_turn.cancel("movimiento")
	owner.set_ball_ghost(true)
	stats["started"] += 1
	last = {"clip": String(id), "intent": String(new_intent), "residual": plan["residual"], "turn": plan["turn"], "touches": []}
	return true

## Recepcion planificada por JsonReceive: el mismo movimiento con pelota, pero la pelota llega al primer toque desde lejos
## y, hasta ese toque, el cuerpo no es fantasma (la pelota no lo atraviesa).
func start_receive(plan: Dictionary) -> bool:
	var b: Ball = handler.ball()
	var toucher: Node = b.last_toucher if b != null else null
	if not _start(plan, &"receive"):
		return false
	_recv_toucher = toucher
	_recv_inc = plan.get("inc", Vector3.ZERO)
	_recv_part = plan.get("part", &"foot")
	_recv_t = float(plan.get("t_contact", 0.0))
	var post_t: float = float(plan.get("post_t", -1.0))
	# Corte antes del pase o golpeo del clip (-2: el nombre dice pase pero no hay toque registrado: 0.25 s tras el contacto).
	_recv_cut = post_t - 0.05 if post_t > 0.0 else (_recv_t + 0.25 if post_t < -1.5 else -1.0)
	_recv_cp = plan.get("cp", {})
	if String(PackLibrary.meta(clip).get("heading_mode", "")) != "turn":
		_turn_end = 0.0   # el cuerpo no gira con este clip (ActionMotion): la salida es el frente
	_recv_gap = INF
	_recv_traj = plan.get("traj", PackedVector3Array())
	_recv_frame0 = int(plan.get("frame", Engine.get_physics_frames()))
	# Toques: el primer contacto real (la parte del cuerpo del perfil, no el primer `ball_touches`) y los toques de pie
	# registrados despues, sin el pase o golpeo posterior (lo da el sistema de pase/tiro si hay orden).
	var touches: Array = [[_recv_t, int(plan.get("foot", 0)), plan["contact_local"], Vector2.ZERO]]
	for bt in PackLibrary.meta(clip).get("ball_touches", []):
		var tt: float = float(bt[0])
		if tt > _recv_t + 0.05 and (_recv_cut < 0.0 or tt < _recv_cut):
			touches.append(bt)
	_touches = touches
	handler.owner.set_ball_ghost(false)
	return true

## Paso de fisica durante el clip (PlayerActions.tick). clip_t: tiempo del clip ya avanzado.
func step(clip_t: float, dt: float) -> void:
	if not active:
		return
	var owner: Footballer = handler.owner
	var b: Ball = handler.ball()
	handler._sample_feet(dt)
	var receiving: bool = intent == &"receive"
	# Recibiendo, el cuerpo no es fantasma hasta el contacto (la pelota no lo atraviesa); con pecho, muslo o rodilla el punto
	# de contacto esta dentro de la capsula y pasa a fantasma un instante antes.
	# Dentro de la ventana de contacto el cuerpo es fantasma: la capsula (0.3 m de radio) es mas ancha que las piernas y
	# frenaba la pelota que iba al pie a un costado; antes de la ventana la pelota no cruza el cuerpo (JsonReceive._path_clear).
	owner.set_ball_ghost(not receiving or _next > 0 or clip_t >= float(_recv_cp.get("path_t0", _recv_t)))
	if b == null or b.is_held() or handler.ball_owned_by_other() or (b.last_toucher != owner and b.last_toucher != null and _next > 0):
		_abort("pelota perdida")
		return
	if receiving and _receive_step(clip_t, dt, b):
		return
	if receiving and _next == 0:
		# Primer contacto: cuando la pelota y la parte del cuerpo animada (posicion y rumbo reales del cuerpo + su trayectoria
		# en el clip) se encuentran dentro de la ventana; pasada la ventana sin encontrarse, el toque se pierde.
		if clip_t <= float(_touches[0][0]):
			owner.actions.motion.extra_velocity = _corr
		else:
			owner.actions.motion.extra_velocity = Vector3.ZERO
		var lp: Vector3 = JsonReceive.path_point(_recv_cp, clip_t)
		if lp != Vector3.INF:
			var f: Vector3 = owner.locomotion.forward()
			var r := Vector3(-f.z, 0.0, f.x)
			var part_w: Vector3 = KickModel.flat(owner.global_position) + f * lp.x + r * lp.z + Vector3(0.0, lp.y, 0.0)
			var reach: float = b.radius + float(JsonReceive.PART_REACH.get(_recv_part, 0.08))
			var gap: float = b.global_position.distance_to(part_w)
			_recv_gap = minf(_recv_gap, gap)
			if gap <= reach:
				_touch(0, b, true)
				if not active:
					return
				_next = 1
		elif clip_t > float(_recv_cp.get("path_t0", 0.0)) + 0.1:
			last["contact_gap"] = snappedf(_recv_gap, 0.01)
			handler.receive.stats["missed"] += 1
			_abort("la pelota no llego a la parte del cuerpo")
			return
		if _next == 0:
			_update_ik(clip_t, b)
			return
	# El ajuste de paso solo hasta el primer toque.
	if _next > 0 or clip_t >= float(_touches[0][0]):
		owner.actions.motion.extra_velocity = Vector3.ZERO
	# Toques cuyo instante ya paso.
	while _next < _touches.size() and clip_t >= float(_touches[_next][0]):
		_touch(_next, b)
		if not active:
			return
		_next += 1
	_update_ik(clip_t, b)

## Recepcion en curso: la pelota desviada antes del toque la corta; los botones se leen (PlayerActions no deja pasar el
## paso normal de BallHandler): una orden de golpeo antes del toque es de primera (se corta la recepcion y golpea el
## planificador de siempre) y despues del toque corta la cola del clip para golpear ya. true si la recepcion termino.
func _receive_step(clip_t: float, dt: float, b: Ball) -> bool:
	var owner: Footballer = handler.owner
	if _recv_cut > 0.0 and clip_t >= _recv_cut:
		_end_early("golpeo tras el control" if handler._pending_action != &"" else "corte antes del golpeo del clip")
		return true
	if _next == 0 and b.last_toucher != _recv_toucher:
		_abort("pelota desviada")
		return true
	if _next == 0 and _recv_traj.size() > 1:
		# La pelota no va por donde se previo (desviada, frenada, patinando): se corta ya, a tiempo para el control fisico.
		var tp: float = float(Engine.get_physics_frames() - _recv_frame0) / float(Engine.physics_ticks_per_second)
		var v_pred: Vector3 = (JsonReceive._at(_recv_traj, tp + JsonReceive.TRAJ_STEP) - JsonReceive._at(_recv_traj, tp)) / JsonReceive.TRAJ_STEP
		if b.global_position.distance_to(JsonReceive._at(_recv_traj, tp)) > JsonReceive.TRAJ_DRIFT \
				or (b.linear_velocity - v_pred).length() > JsonReceive.TRAJ_DV:
			_abort("la pelota no va por donde se previo")
			return true
	var fr: InputFrame = owner.last_frame
	if fr != null:
		var sw: Vector3 = fr.move_world if fr.use_world else owner.ctx.screen_to_world(fr.move)
		handler._update_buttons(fr, sw.limit_length(1.0), dt)
	var charging: bool = handler._pass_active or handler._shoot_active or handler._through_active or handler._cross_active
	# Antes del contacto, una orden de golpeo es de primera; cargandola, solo sigue un clip con accion posterior (recibir y
	# luego pasar o tirar: el golpeo lo da el sistema de pase/tiro al soltar tras el contacto o en el corte del clip).
	if _next == 0 and (handler._pending_action != &"" or (charging and _recv_cut < 0.0)):
		_abort("golpeo de primera")
		return true
	if _next > 0 and handler._pending_action != &"":
		_end_early("golpeo tras el control")
		return true
	return false

## Lo que se desvio el cuerpo de la trayectoria prevista (choques): se suma a los puntos de toque.
func _drift(clip_t: float) -> Vector3:
	var owner: Footballer = handler.owner
	var f0: Vector3 = Locomotion.dir_from_yaw(_yaw0)
	var r0 := Vector3(-f0.z, 0.0, f0.x)
	var rr: Vector2 = owner.actions.motion.root_at(clip_t)
	var planned: Vector3 = _origin + f0 * rr.x + r0 * rr.y
	return KickModel.flat(owner.global_position) - planned

## Punto del mundo donde debe estar el centro de la pelota en el toque i (punta del pie mas el radio, hacia donde va el pie).
func _touch_point(i: int, drift: Vector3) -> Vector3:
	var f0: Vector3 = Locomotion.dir_from_yaw(_yaw0)
	var r0 := Vector3(-f0.z, 0.0, f0.x)
	var p: Vector3 = _touches[i][2]
	var vel: Vector2 = _touches[i][3]
	var lead: Vector3 = (f0 * vel.x + r0 * vel.y).normalized() * BALL_LEAD if vel.length() > 0.3 else Vector3.ZERO
	if intent == &"receive" and i == 0 and _recv_inc != Vector3.ZERO:
		lead = JsonReceive.contact_offset(_recv_inc, handler.ball())
	return _origin + drift + f0 * p.x + r0 * p.z + lead

func _touch(i: int, b: Ball, met: bool = false) -> void:
	var owner: Footballer = handler.owner
	var clip_t: float = float(_touches[i][0])
	var drift: Vector3 = _drift(owner.actions.motion.t)
	var here: Vector3 = _touch_point(i, drift)
	var bp: Vector3 = KickModel.flat(b.global_position)
	var d: float = bp.distance_to(here)
	(last["touches"] as Array).append(snappedf(d, 0.01))
	var receiving: bool = intent == &"receive"
	# Recibiendo, tambien la altura: el primer contacto a la altura de su parte del cuerpo; los toques de pie posteriores,
	# con la pelota ya abajo.
	var high: bool = false
	if receiving:
		var want_y: float = float((_touches[i][2] as Vector3).y) if i == 0 else 0.0
		high = absf(b.global_position.y - want_y) > 0.35 if i == 0 else b.global_position.y > 0.45
	if (d > MISS_DIST or high) and not met:
		_misses += 1
		stats["missed"] += 1
		if receiving:
			handler.receive.stats["missed"] += 1
			if i > 0:
				# La pelota no llega al toque siguiente del clip: se corta y el jugador va a por ella.
				_end_early("segundo contacto no llega")
				return
		if _misses >= 2 or i == 0:
			_abort("toque perdido")
		return
	_misses = 0
	if receiving and i == 0 and _recv_part != &"foot":
		# Pie en el aire, muslo, rodilla o pecho: la respuesta de esa parte del cuerpo, no un toque de pie.
		var rel_air: float = (b.linear_velocity - owner.velocity).length()
		var va: Vector3 = handler.receive.contact_velocity(Vector3.ZERO, b, _recv_part).limit_length(9.0)
		b.kick(va, Vector3.ZERO, owner)
		_received(b, rel_air)
		return
	var target: Vector3
	var travel: float
	var stop: bool = false
	if i + 1 < _touches.size():
		target = _touch_point(i + 1, drift)
		travel = maxf((float(_touches[i + 1][0]) - clip_t) / _speed, 0.06)
	else:
		# Ultimo toque: la pelota queda delante del rumbo de salida, donde el jugador la encuentra al terminar el clip.
		var f0: Vector3 = Locomotion.dir_from_yaw(_yaw0)
		var r0 := Vector3(-f0.z, 0.0, f0.x)
		var end_pos: Vector3 = _origin + drift + f0 * _root_end.x + r0 * _root_end.y
		var exit_dir: Vector3 = Locomotion.dir_from_yaw(_yaw0 + _turn_end)
		var desired: Vector3 = handler._desired_dir
		var oriented: bool = false
		if desired.length_squared() > 0.01 and KickModel.angle_between_deg(exit_dir, desired) < (JsonReceive.TURN_TOL if intent == &"receive" else 35.0):
			exit_dir = KickModel.flat(desired).normalized()
			oriented = intent == &"receive"
		var remain: float = maxf((_length - clip_t) / _speed, 0.0)
		if intent == &"kick_turn" or handler._pending_action != &"":
			# Giro para golpear: la pelota queda quieta delante del pie, lista para el golpeo que espera.
			stop = true
			target = end_pos + exit_dir * 0.5
		elif oriented:
			# Control orientado: la pelota sale hacia el joystick, un paso por delante de donde termina el clip.
			stop = true
			target = end_pos + exit_dir * (Tuning.player.settle_gap + 0.6)
		elif _v_out < 0.8:
			stop = true
			target = end_pos + exit_dir * Tuning.player.settle_gap
		else:
			travel = remain + 0.35
			target = end_pos + exit_dir * (_v_out * 0.35 + handler.carry_gap(_v_out, handler._carry_skill()))
	var to_t: Vector3 = target - bp
	var v: Vector3
	if stop:
		v = to_t.normalized() * Ball.roll_speed_to_stop(to_t.length()) if to_t.length() > 0.02 else Vector3.ZERO
	else:
		v = to_t.normalized() * Ball.roll_speed_for(to_t.length(), travel) if to_t.length() > 0.01 else Vector3.ZERO
	var received: bool = intent == &"receive" and i == 0
	var rel_in: float = KickModel.flat(b.linear_velocity - owner.velocity).length()
	if received:
		v = handler.receive.contact_velocity(v, b, &"foot")
	v = v.limit_length(9.0)
	b.kick(v, b.rolling_spin(v), owner)
	if received:
		_received(b, rel_in)
	var foot: int = 1 if int(_touches[i][1]) > 0 else 0
	stats["touches"] += 1
	handler.dribble_touch_count += 1
	handler.foot_touches += 1
	handler.last_touch_foot = foot
	handler.last_touch_foot_distance = d
	handler.last_touch_mode = &"move"
	handler.touched_ball.emit(&"move")

## Primer contacto de la recepcion hecho: no se vuelve a controlar enseguida, el cuerpo ya no choca con la pelota y se avisa
## al partido (FIRST_TOUCH con el clip y la parte del cuerpo).
func _received(b: Ball, rel_in: float) -> void:
	var owner: Footballer = handler.owner
	handler.control_cooldown = 0.5
	handler.receive.stats["contact"] += 1
	owner.set_ball_ghost(true)
	owner.ctx.emit_event(GameEvent.make(GameEvent.Type.FIRST_TOUCH, owner.actor_id, owner.team,
		{"absorb": handler.receive.last_contact.get("absorb", 0.0), "incoming_speed": rel_in, "clip": String(clip), "planned": true, "part": String(_recv_part)}))
	var foot: int = int(_touches[0][1])
	handler.last_touch_foot = 1 if foot > 0 else (0 if foot < 0 else -1)

## Pie al toque: la punta va hasta la pelota real (unos centimetros) en el tramo del toque.
func _update_ik(clip_t: float, b: Ball) -> void:
	var v: FootballerVisual = handler.owner.visual
	if v == null or v.touch_ik == null:
		return
	var idx: int = -1
	for i in range(maxi(_next - 1, 0), mini(_next + 1, _touches.size())):
		var tt: float = float(_touches[i][0])
		if clip_t >= tt - IK_LEAD and clip_t <= tt + IK_HOLD:
			idx = i
			break
	if idx < 0:
		if _ik_foot >= 0:
			v.touch_ik.set_target(_ik_foot, Vector3.ZERO, 0.0, 0.0)
			_ik_foot = -1
		return
	var foot: int = 1 if int(_touches[idx][1]) > 0 else 0
	var tt2: float = float(_touches[idx][0])
	var w: float = clampf(1.0 - (tt2 - clip_t) / IK_LEAD, 0.0, 1.0) if clip_t < tt2 else clampf(1.0 - (clip_t - tt2) / IK_HOLD, 0.0, 1.0)
	var bp: Vector3 = b.global_position
	var toe: Vector3 = handler.toe_world(foot)
	var vel: Vector2 = _touches[idx][3]
	var f0: Vector3 = Locomotion.dir_from_yaw(_yaw0)
	var push: Vector3 = (f0 * vel.x + Vector3(-f0.z, 0.0, f0.x) * vel.y)
	push = push.normalized() if push.length() > 0.3 else KickModel.flat(bp - toe).normalized()
	var want: Vector3 = bp - push * (b.radius + 0.03)
	if intent == &"receive" and idx == 0 and _recv_part != &"foot" and _recv_part != &"foot_air":
		return   # pecho, muslo o rodilla: sin IK del pie
	if intent == &"receive" and idx == 0 and _recv_inc != Vector3.ZERO:
		# Recepcion: el pie va delante de la pelota que llega (la para), no detras empujandola.
		want = bp - JsonReceive.contact_offset(_recv_inc, b).normalized() * (b.radius + 0.03)
	want.y = maxf(toe.y, 0.04)
	if toe != Vector3.ZERO and KickModel.flat(want - toe).length() > IK_MAX:
		w = 0.0
	v.touch_ik.set_target(foot, want, 0.0, w)
	_ik_foot = foot

## Fin del clip (PlayerActions): la conduccion normal sigue desde aqui.
func finish() -> void:
	if not active:
		return
	active = false
	stats["done"] += 1
	if intent == &"receive":
		handler.receive.ended(_next > 0)
	_remember()
	_cooldown = maxf(_cooldown, COOLDOWN)
	handler.touch_timer = 0.12
	_release_ik()

func _abort(reason: String) -> void:
	if not active:
		return
	active = false
	stats["aborted"] += 1
	last["aborted"] = reason
	if intent == &"receive":
		handler.receive.ended(_next > 0)
	_remember()
	_cooldown = COOLDOWN
	_release_ik()
	# Sin pelota que llevar el clip no sigue: se corta con un fundido y vuelve la marcha (el jugador puede ir a por ella).
	# PlayerActions.stop corta raiz y pose y libera el lugar en el arbitro.
	var owner: Footballer = handler.owner
	owner.actions.motion.extra_velocity = Vector3.ZERO
	owner.actions.stop(reason)

## Fin antes de tiempo sin error (golpeo pedido tras el control): se suelta el clip y sigue el paso normal.
func _end_early(reason: String) -> void:
	finish()
	last["ended"] = reason
	handler.owner.actions.motion.extra_velocity = Vector3.ZERO
	handler.owner.actions.stop(reason)

func _remember() -> void:
	history.append(last)
	if history.size() > 20:
		history.pop_front()

## La accion se corto desde fuera (saque, gol, caida).
func cancel() -> void:
	if active:
		active = false
		if intent == &"receive":
			handler.receive.ended(_next > 0)
		_cooldown = COOLDOWN
		_release_ik()

func _release_ik() -> void:
	var v: FootballerVisual = handler.owner.visual if handler.owner != null else null
	if v != null and v.touch_ik != null and _ik_foot >= 0:
		v.touch_ik.set_target(_ik_foot, Vector3.ZERO, 0.0, 0.0)
	_ik_foot = -1
