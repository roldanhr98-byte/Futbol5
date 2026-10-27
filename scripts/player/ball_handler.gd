class_name BallHandler
extends RefCounted
## Interaccion del futbolista con la pelota. Todo ocurre mediante IMPULSOS en el instante del contacto:
## nunca se fija la posicion de la pelota ni se anula su velocidad.
##  - Conduccion: toques periodicos cuya fuerza depende de la velocidad, el giro y los atributos.
##  - Control de primer toque: absorbe parte de la energia de un balon que llega (con error).
##  - Pase y tiro: se calculan con PassAssist / ShotAssist; se ejecutan al soltar el boton y
##    se guardan en buffer 0.3 s si la pelota aun no esta a alcance.
##  - Disputa: robo probabilistico dependiente de orientacion, atributos y velocidad relativa.

signal kicked(action: StringName, result: KickModel.KickResult)
signal touched_ball(kind: StringName)

## Interruptor global (pruebas): false fuerza siempre la patada procedural antigua.
static var clip_kicks_enabled: bool = true
## Maximo de entradas del registro de patadas.
const KICK_LOG_MAX := 64
## Segundos que espera un pase o tiro pulsado hasta que algun pie llegue a la pelota antes de descartarse.
const PENDING_KICK_MAX := 0.5

var owner: Footballer
var rng := RandomNumberGenerator.new()

var _redirect_hold: float = 0.0
## Segundos que el cuerpo conserva su orientacion tras un control lateral (no gira hacia el joystick todavia).
var _lateral_hold: float = 0.0
## Orientacion congelada durante el control lateral y espera antes de poder encadenar otro.
var _lateral_face: Vector3 = Vector3.ZERO
var _lateral_cooldown: float = 0.0
## Direccion a la que mira el cuerpo mientras conduce (control lateral / proteccion). Cero = libre.
var _carry_face: Vector3 = Vector3.ZERO
## Modo del ultimo toque de conduccion (settle, lateral, redirect, carry): lo usa la animacion.
var last_touch_mode: StringName = &""
## Instante (ms) del ultimo pase o tiro ejecutado: el jugador no vuelve a tocar su propio envio enseguida.
var _last_kick_msec: int = 0
var _kick_start_touch: int = 0
var _kick_start_ball_v: Vector3 = Vector3.ZERO
var touch_timer: float = 0.0
var lockout: float = 0.0
var control_cooldown: float = 0.0
var dribble_touch_count: int = 0
var last_result: KickModel.KickResult = null

var _pass_active: bool = false
var _pass_time: float = 0.0
var _shoot_active: bool = false
var _shoot_time: float = 0.0
var _pending_action: StringName = &""
var _pending_charge: float = 0.0
var _pending_lob: bool = false
var _pending_stick: Vector3 = Vector3.ZERO
var _pending_age: float = 0.0
## Patada en curso: el impulso se aplica en el instante de contacto de la animacion.
var _kick_action: StringName = &""
var _kick_timer: float = 0.0
var _kick_stick: Vector3 = Vector3.ZERO
var _kick_charge: float = 0.0
var _kick_lob: bool = false
## Patada con clip del pack en curso: {clip, speed, offset, latency, contact, distance (al iniciar)}. Vacio = patada procedural.
var _kick_clip: Dictionary = {}

## Contadores y registro de patadas con animacion (diagnostico reproducible; ver kick_log).
## started: balanceos iniciados; contact: golpeos validos; missed: balanceos que no alcanzaron la pelota;
## out_of_reach: pulsaciones descartadas sin iniciar el balanceo por no haber pie que llegara.
var kick_stats := {"started": 0, "contact": 0, "missed": 0, "out_of_reach": 0}
var kick_log: Array[Dictionary] = []
var last_foot_distance: float = -1.0
## Distancia delante del jugador a la que se coloco la pelota en el ultimo toque de conduccion (m).
var _planned_gap: float = 0.0
var _kick_event_info: Dictionary = {}

## Ultima direccion deseada del jugador (mundo): sirve para predecir hacia donde girara durante el balanceo.
var _desired_dir: Vector3 = Vector3.ZERO

## Progreso de carga actual (0..1) para el HUD.
var pass_charge: float = 0.0
var shot_charge: float = 0.0

func _init(o: Footballer) -> void:
	owner = o
	rng.randomize()

func ball() -> Ball:
	return owner.ctx.ball if owner.ctx != null else null

func ball_offset() -> Vector3:
	var b: Ball = ball()
	return KickModel.flat(b.global_position - owner.global_position) if b != null else Vector3.ZERO

func ball_distance() -> float:
	return ball_offset().length()

## Radio (m) dentro del cual se considera que el jugador lleva la pelota. Crece con la velocidad: a sprint la pelota
## va mas adelantada y seguiria siendo suya.
func possession_radius() -> float:
	return maxf(Tuning.player.possession_radius, touch_reach() * 1.3)

func has_possession() -> bool:
	var b: Ball = ball()
	if b == null or b.is_held():
		return false
	return ball_distance() <= possession_radius() and b.global_position.y < 0.6

## El equipo del jugador controla la pelota: esta cerca Y fue tocada por ultima vez por su equipo.
## Una pelota suelta o ultimo tocada por el rival no cuenta (se puede seguir presionando).
func controls_ball() -> bool:
	var b: Ball = ball()
	return has_possession() and b != null and b.last_touch_team == owner.team

func can_reach(reach: float) -> bool:
	var b: Ball = ball()
	return b != null and not b.is_held() and ball_distance() <= reach and b.global_position.y < 0.65

## Alcance efectivo de un toque: el jugador estira mas la pierna a mayor velocidad.
func touch_reach() -> float:
	var t: PlayerTuning = Tuning.player
	return t.touch_reach + 0.22 * _sprint_ratio()

func _sprint_ratio() -> float:
	var t: PlayerTuning = Tuning.player
	return clampf((owner.locomotion.speed - t.jog_speed) / maxf(t.sprint_speed - t.jog_speed, 0.1), 0.0, 1.0)

func assist_pass_level() -> float:
	return owner.assist_override_pass if owner.assist_override_pass >= 0.0 else Tuning.assist.pass_assist

func assist_shot_level() -> float:
	return owner.assist_override_shot if owner.assist_override_shot >= 0.0 else Tuning.assist.shot_assist

## Paso de simulacion. stick_world: direccion del joystick en el mundo; desired_dir: direccion deseada final.
func update(frame: InputFrame, stick_world: Vector3, stick_mag: float, desired_dir: Vector3, dt: float) -> void:
	lockout = maxf(lockout - dt, 0.0)
	touch_timer = maxf(touch_timer - dt, 0.0)
	control_cooldown = maxf(control_cooldown - dt, 0.0)
	_redirect_hold = maxf(_redirect_hold - dt, 0.0)
	_desired_dir = desired_dir
	_update_buttons(frame, stick_world, dt)
	if _kick_action != &"":
		_kick_timer -= dt
		if _kick_timer <= 0.0:
			_finish_kick()
		return
	if _pending_action != &"":
		_pending_age += dt
		if _try_execute_pending():
			return
		if _pending_age > PENDING_KICK_MAX:
			if uses_clip_kicks():
				_log_kick(_pending_action, &"out_of_reach", {"stage": "pending"})
				kick_stats["out_of_reach"] += 1
				owner.ctx.emit_event(GameEvent.make(GameEvent.Type.KICK_WHIFF, owner.actor_id, owner.team, {"action": String(_pending_action), "reason": "out_of_reach"}))
			_pending_action = &""
	if lockout > 0.0:
		return
	if _try_first_touch(desired_dir):
		return
	_try_dribble_touch(desired_dir, stick_mag)

# --- Botones ---------------------------------------------------------------

func _update_buttons(frame: InputFrame, stick_world: Vector3, dt: float) -> void:
	var bt: BallTuning = Tuning.ball
	if frame.pass_pressed and not _shoot_active:
		_pass_active = true
		_pass_time = 0.0
	if _pass_active:
		if frame.pass_held:
			_pass_time += dt
		pass_charge = clampf(_pass_time / 0.8, 0.0, 1.0)
		if frame.pass_released or not frame.pass_held:
			_queue(&"pass", pass_charge, frame.lob_held, stick_world)
			_pass_active = false
			pass_charge = 0.0
	if frame.shoot_pressed and not _pass_active:
		_shoot_active = true
		_shoot_time = 0.0
	if _shoot_active:
		if frame.shoot_held:
			_shoot_time += dt
		shot_charge = clampf(_shoot_time / bt.shot_charge_time, 0.0, 1.0)
		if frame.shoot_released or not frame.shoot_held:
			_queue(&"shot", shot_charge, frame.lob_held, stick_world)
			_shoot_active = false
			shot_charge = 0.0

func _queue(action: StringName, charge: float, lob: bool, stick_world: Vector3) -> void:
	_pending_action = action
	_pending_charge = charge
	_pending_lob = lob
	_pending_stick = stick_world
	_pending_age = 0.0

func _try_execute_pending() -> bool:
	if lockout > 0.0:
		return false
	if uses_clip_kicks():
		var plan: Dictionary = plan_clip_kick(_pending_action, _pending_charge, _pending_lob)
		if plan.is_empty():
			return false   # ningun pie llegaria a la pelota: se espera (buffer) o se descarta
		var act: StringName = _pending_action
		_pending_action = &""
		_start_clip_kick(act, plan, _pending_stick, _pending_charge, _pending_lob)
		return true
	if not can_reach(Tuning.player.touch_reach + 0.3):
		return false
	var action: StringName = _pending_action
	_pending_action = &""
	request_kick(action, _pending_stick, _pending_charge, _pending_lob)
	return true

## Segundos entre el inicio de la patada y el golpeo (la animacion y el impulso comparten este instante).
func contact_delay(action: StringName, charge: float) -> float:
	return 0.10 if action == &"pass" else 0.12 + 0.06 * charge

## Comienza una patada: arranca la animacion y programa el impulso para el instante de contacto.
func request_kick(action: StringName, stick_world: Vector3, charge: float, lob: bool) -> void:
	if _kick_action != &"":
		return
	_kick_action = action
	_kick_stick = stick_world
	_kick_charge = charge
	_kick_lob = lob
	_kick_timer = contact_delay(action, charge)
	lockout = _kick_timer + 0.4
	touch_timer = lockout
	var side: int = 1 if ball_offset().dot(owner.locomotion.right()) >= 0.0 else -1
	if owner.visual != null:
		var power: float = charge if action == &"shot" else 0.35 + 0.5 * charge
		owner.visual.start_kick(_kick_timer, power, side)

func is_kick_in_progress() -> bool:
	return _kick_action != &""

# --- Patada con clip del pack: el golpeo ocurre cuando el PIE llega a la pelota --------------------

## true si este futbolista patea con los clips del pack (visual con libreria y clips de patada en el sitio).
func uses_clip_kicks() -> bool:
	var v: FootballerVisual = owner.visual
	return clip_kicks_enabled and v != null and v.uses_pack and not v.is_placeholder and not AnimationCatalog.kick_candidates(&"pass").is_empty()

## Posicion MUNDIAL de la punta del pie en el golpeo de un clip, para un jugador en pos con orientacion yaw.
## contact.pos es (adelante, arriba, derecha) en metros, medido sobre el esqueleto retargeteado del propio clip.
static func foot_contact_world(contact: Dictionary, pos: Vector3, yaw: float) -> Vector3:
	var f: Vector3 = Locomotion.dir_from_yaw(yaw)
	var r := Vector3(-f.z, 0.0, f.x)
	var c: Vector3 = contact["pos"]
	return Vector3(pos.x, 0.0, pos.z) + f * c.x + r * c.z + Vector3.UP * c.y

## Velocidad de reproduccion, punto de inicio y latencia real para que el clip llegue a su contacto en kick_latency.
func clip_timing(contact_time: float, action: StringName, charge: float) -> Dictionary:
	var t: PlayerTuning = Tuning.player
	var latency: float = t.kick_latency + (0.04 * charge if action == &"shot" else 0.0)
	var speed: float = clampf(contact_time / 0.30, 1.0, t.kick_clip_speed_max)
	var offset: float = maxf(contact_time - latency * speed, 0.0)
	return {"speed": speed, "offset": offset, "latency": (contact_time - offset) / speed}

## Vector (pelota - pie) en el plano, en metros, al instante de contacto del clip, PREDICHO desde el estado actual
## (jugador y pelota siguen su velocidad; el giro sigue el ritmo actual reducido por kick_turn_scale). La altura va en y.
## Orientacion prevista del cuerpo al contacto: gira hacia la direccion deseada a la velocidad de giro actual, reducida
## por kick_turn_scale (durante el balanceo el pie de apoyo fija la direccion). Con la direccion ya apuntando al frente
## equivale a mantener el yaw; si el joystick acaba de girar, anticipa el giro que todavia no se ve en turn_rate.
func _predicted_yaw(latency: float) -> float:
	var loco: Locomotion = owner.locomotion
	var t: PlayerTuning = Tuning.player
	if _desired_dir.length_squared() < 0.01:
		return loco.yaw + loco.turn_rate * t.kick_turn_scale * latency
	var dy: float = wrapf(Locomotion.yaw_from_dir(_desired_dir.normalized()) - loco.yaw, -PI, PI)
	var ratio: float = clampf(loco.speed / maxf(loco.max_sprint_speed(), 0.1), 0.0, 1.0)
	var rate: float = deg_to_rad(lerpf(t.turn_rate_standing, t.turn_rate_sprint, ratio * ratio)) * owner.attributes.factor("agility", 0.14)
	var max_turn: float = rate * t.kick_turn_scale * latency
	return loco.yaw + clampf(dy, -max_turn, max_turn)

## Aborta una patada en curso y la accion pendiente (caida, barrida): no se aplica ningun impulso.
func abort_kick() -> void:
	if _kick_action != &"":
		_kick_action = &""
		_kick_clip = {}
		owner.locomotion.turn_scale = 1.0
		owner.nudge_velocity = Vector3.ZERO
		owner.set_ball_ghost(false)
		lockout = 0.0
	_pending_action = &""

## Cancela la carga de pase/tiro en curso sin ejecutar nada (la IA lo usa cuando la pelota se le fue).
func cancel_charge() -> void:
	_pass_active = false
	_shoot_active = false
	pass_charge = 0.0
	shot_charge = 0.0

func predicted_foot_to_ball(contact: Dictionary, latency: float) -> Vector3:
	var b: Ball = ball()
	var loco: Locomotion = owner.locomotion
	var yaw: float = _predicted_yaw(latency)
	var p: Vector3 = owner.global_position + Vector3(loco.velocity.x, 0.0, loco.velocity.z) * latency
	var bp: Vector3 = b.global_position + Vector3(b.linear_velocity.x, 0.0, b.linear_velocity.z) * latency
	bp.y = b.global_position.y
	return bp - foot_contact_world(contact, p, yaw)

## Puntos validos de golpeo de un clip: muestras de la trayectoria del pie (adelante, arriba, derecha) con la punta baja y
## lanzada hacia adelante. Devuelve [{time, pos}] (tiempo del clip en segundos).
static func contact_samples(contact: Dictionary) -> Array:
	var t: PlayerTuning = Tuning.player
	var path: PackedVector3Array = contact.get("path", PackedVector3Array())
	var out: Array = []
	if path.size() < 3:
		return [{"time": float(contact["time"]), "pos": contact["pos"]}]
	var dt: float = contact["path_dt"]
	for k in range(1, path.size() - 1):
		var vfwd: float = (path[k + 1].x - path[k - 1].x) / (2.0 * dt)
		if path[k].y <= t.kick_foot_max_height and vfwd >= t.kick_foot_min_speed:
			out.append({"time": float(contact["path_t0"]) + k * dt, "pos": path[k]})
	return out if not out.is_empty() else [{"time": float(contact["time"]), "pos": contact["pos"]}]

## Clips de pelota en el aire: cabezazos (trayectoria de la cabeza) y voleas/acrobacias (punta del pie), con su espejo.
const AERIAL_SETS := [
	{"clips": [&"Header", &"Soccer_Header", &"header_soccerball", &"header_soccerball_2", &"Jumping_Up"], "keys": ["head"], "min_speed": 1.6, "kind": &"header"},
	{"clips": [&"kick_soccerball", &"kick_soccerball_2", &"scissor_kick", &"Flying_Bicycle_Kick"], "keys": ["toe_l", "toe_r"], "min_speed": 4.5, "kind": &"volley"},
]
## Altura de la pelota (m) a partir de la cual se juega en el aire (cabezazo / volea) en vez de a ras de piso.
const AERIAL_MIN_BALL_Y := 0.5

## Planifica un golpeo con la pelota en el aire: busca, entre los clips de cabezazo y volea, el instante en que la cabeza
## o la punta del pie (con velocidad suficiente) coincide con la pelota PREDICHA, con ajuste de zancada acotado.
func plan_aerial_kick(action: StringName, charge: float) -> Dictionary:
	var b: Ball = ball()
	if b == null or b.is_held():
		return {}
	var t: PlayerTuning = Tuning.player
	var traj: PackedVector3Array = BallPredictor.trajectory(b.global_position, b.linear_velocity, 1.3, 1.0 / 30.0)
	var adjust_max: float = t.kick_adjust_max + t.kick_adjust_sprint * _sprint_ratio()
	var best: Dictionary = {}
	var best_score: float = INF
	for set in AERIAL_SETS:
		for base in set["clips"]:
			for clip in [base, StringName(String(base) + "_mirror")]:
				if not PackLibrary.has_clip(clip):
					continue
				var paths: Dictionary = PackLibrary.meta(clip).get("paths", {})
				for key in set["keys"]:
					if not paths.has(key):
						continue
					var path: PackedVector3Array = paths[key]
					for k in range(4, path.size() - 1):
						var v: float = (path[k + 1] - path[k - 1]).length() * 15.0
						if v < float(set["min_speed"]):
							continue
						for sp in [1.0, 1.4]:
							var lat: float = float(k) / 30.0 / sp
							if lat < 0.1 or lat > 1.1:
								continue
							var c := {"time": float(k) / 30.0, "pos": path[k], "foot": 1}
							var ip: float = lat * 30.0
							var i0: int = mini(int(ip), traj.size() - 2)
							var bp: Vector3 = traj[i0].lerp(traj[i0 + 1], ip - float(i0))
							var yaw: float = _predicted_yaw(lat)
							var loco: Locomotion = owner.locomotion
							var pb: Vector3 = owner.global_position + Vector3(loco.velocity.x, 0.0, loco.velocity.z) * lat
							var delta: Vector3 = bp - foot_contact_world(c, pb, yaw)
							var flat_d := Vector3(delta.x, 0.0, delta.z)
							var step: Vector3 = flat_d.limit_length(adjust_max)
							var residual: float = Vector3(flat_d.x - step.x, delta.y, flat_d.z - step.z).length()
							var score: float = residual + 0.12 * step.length() + (0.06 if sp > 1.0 else 0.0) + (0.0 if set["kind"] == &"volley" else 0.03)
							if score < best_score:
								best_score = score
								best = {"clip": clip, "speed": sp, "offset": 0.0, "latency": lat, "contact": c, "distance": delta.length(),
									"residual": residual, "adjust": step, "aerial": set["kind"]}
	return best if not best.is_empty() and best["residual"] <= t.kick_start_residual else {}

## Elige el mejor clip, pierna E INSTANTE DE CONTACTO para la accion. El instante sale de la trayectoria real del pie del
## clip (contact_samples), no es fijo: se busca el punto que mejor encaja con la pelota predicha. Cada opcion puede
## compensar hasta el ajuste de zancada maximo; se empieza solo si, tras el ajuste, el pie quedaria a menos de
## kick_start_residual de la pelota. Si ninguna llega, devuelve {} y NO hay patada.
func plan_clip_kick(action: StringName, charge: float, lob: bool) -> Dictionary:
	var b: Ball = ball()
	if b == null or b.is_held():
		return {}
	if b.global_position.y > AERIAL_MIN_BALL_Y:
		return plan_aerial_kick(action, charge)
	var t: PlayerTuning = Tuning.player
	var adjust_max: float = t.kick_adjust_max + t.kick_adjust_sprint * _sprint_ratio()
	var best: Dictionary = {}
	var best_score: float = INF
	for cand in AnimationCatalog.kick_candidates(&"lob" if lob else action):
		for smp in contact_samples(cand["contact"]):
			var c := {"time": smp["time"], "pos": smp["pos"], "foot": cand["foot"]}
			var timing: Dictionary = clip_timing(float(c["time"]), action, charge)
			var delta: Vector3 = predicted_foot_to_ball(c, timing["latency"])
			var flat_d := Vector3(delta.x, 0.0, delta.z)
			var step: Vector3 = flat_d.limit_length(adjust_max)
			var residual: float = Vector3(flat_d.x - step.x, delta.y, flat_d.z - step.z).length()
			var score: float = residual + 0.15 * step.length()
			if score < best_score:
				best_score = score
				best = timing.merged({"clip": cand["clip"], "contact": c, "distance": delta.length(), "residual": residual, "adjust": step})
	return best if not best.is_empty() and best["residual"] <= t.kick_start_residual else {}

func _start_clip_kick(action: StringName, plan: Dictionary, stick_world: Vector3, charge: float, lob: bool) -> void:
	var t: PlayerTuning = Tuning.player
	_kick_action = action
	_kick_stick = stick_world
	_kick_charge = charge
	_kick_lob = lob
	_kick_clip = plan
	var b0: Ball = ball()
	_kick_start_touch = b0.last_touch_msec if b0 != null else 0
	_kick_start_ball_v = KickModel.flat(b0.linear_velocity) if b0 != null else Vector3.ZERO
	_kick_timer = plan["latency"]
	lockout = _kick_timer + 0.4
	touch_timer = lockout
	owner.locomotion.turn_scale = t.kick_turn_scale
	owner.nudge_velocity = (plan["adjust"] as Vector3) / maxf(_kick_timer, 0.05)
	# Durante el balanceo el cuerpo (que se acerca a la pelota por el ajuste de zancada) no debe empujarla: el golpe lo da
	# el pie en el instante de contacto, con impulso.
	owner.set_ball_ghost(true)
	owner.visual.play_pack_clip(plan["clip"], plan["speed"], plan["offset"], _kick_timer + t.kick_follow_through)
	kick_stats["started"] += 1

func _log_kick(action: StringName, result: StringName, extra: Dictionary = {}) -> void:
	var entry := {"action": action, "result": result, "time_ms": Time.get_ticks_msec()}
	entry.merge(extra)
	kick_log.append(entry)
	if kick_log.size() > KICK_LOG_MAX:
		kick_log.pop_front()

## Resuelve el golpeo de una patada con clip: valido solo si la pelota esta a kick_contact_radius del pie REAL
## (posicion de contacto del clip, con el jugador donde esta ahora). Si no, patada en falso: sin impulso.
func _finish_clip_kick() -> void:
	var action: StringName = _kick_action
	var plan: Dictionary = _kick_clip
	_kick_action = &""
	_kick_clip = {}
	lockout = 0.0
	owner.locomotion.turn_scale = 1.0
	owner.nudge_velocity = Vector3.ZERO
	owner.set_ball_ghost(false)
	var b: Ball = ball()
	var d: float = -1.0
	if b != null and not b.is_held():
		d = b.global_position.distance_to(foot_contact_world(plan["contact"], owner.global_position, owner.locomotion.yaw))
	last_foot_distance = d
	var interfered: bool = b != null and b.last_touch_msec != _kick_start_touch and b.last_toucher != owner
	var dv: float = (KickModel.flat(b.linear_velocity) - _kick_start_ball_v).length() if b != null else 0.0
	var info := {"clip": String(plan["clip"]), "foot_distance": d, "predicted": plan["residual"], "latency": plan["latency"], "adjust_m": (plan["adjust"] as Vector3).length(), "interfered": interfered, "ball_dv": dv, "by_team": int(b.last_touch_team) if b != null else -1, "own_team": owner.team}
	if d < 0.0 or d > Tuning.player.kick_contact_radius:
		lockout = 0.3
		touch_timer = lockout
		kick_stats["missed"] += 1
		_log_kick(action, &"missed", info)
		owner.ctx.emit_event(GameEvent.make(GameEvent.Type.KICK_WHIFF, owner.actor_id, owner.team, {"action": String(action), "reason": "missed"}.merged(info)))
		return
	kick_stats["contact"] += 1
	_log_kick(action, &"contact", info)
	_kick_event_info = info
	if action == &"pass":
		perform_pass(_kick_stick, _kick_charge, _kick_lob)
	else:
		perform_shot(_kick_stick, _kick_charge, _kick_lob)
	_kick_event_info = {}

func _finish_kick() -> void:
	if not _kick_clip.is_empty():
		_finish_clip_kick()
		return
	var action: StringName = _kick_action
	_kick_action = &""
	lockout = 0.0
	if not can_reach(Tuning.player.touch_reach + 0.5):
		# La pelota se alejo durante el balanceo: la patada se pierde en el aire.
		lockout = 0.3
		owner.ctx.emit_event(GameEvent.make(GameEvent.Type.KICK_WHIFF, owner.actor_id, owner.team, {"action": String(action)}))
		return
	if action == &"pass":
		perform_pass(_kick_stick, _kick_charge, _kick_lob)
	else:
		perform_shot(_kick_stick, _kick_charge, _kick_lob)

## Ejecuta un pase ahora mismo (la pelota debe estar a alcance). Devuelve el resultado.
func perform_pass(stick_world: Vector3, charge: float, lob: bool) -> KickModel.KickResult:
	var ctx: MatchContext = owner.ctx
	var res: KickModel.KickResult = PassAssist.compute(owner, ctx, stick_world, charge, lob, rng, assist_pass_level())
	var b: Ball = ball()
	b.kick(res.velocity, res.spin, owner)
	_after_kick(&"pass", res)
	var data: Dictionary = {
		"target": res.target.actor_id if res.target != null else -1,
		"kind": String(res.kind), "charge": charge, "error_deg": res.error_deg,
		"weak_foot": res.weak_foot, "speed": res.velocity.length(),
		"assisted_deg": res.assisted_correction_deg,
	}
	data.merge(_kick_event_info)
	ctx.emit_event(GameEvent.make(GameEvent.Type.PASS, owner.actor_id, owner.team, data))
	return res

func perform_shot(stick_world: Vector3, charge: float, lob: bool) -> KickModel.KickResult:
	var ctx: MatchContext = owner.ctx
	var res: KickModel.KickResult = ShotAssist.compute(owner, ctx, stick_world, charge, lob, rng, assist_shot_level())
	var b: Ball = ball()
	b.kick(res.velocity, res.spin, owner)
	_after_kick(&"shot", res)
	var data: Dictionary = {
		"kind": String(res.kind), "charge": charge, "error_deg": res.error_deg,
		"weak_foot": res.weak_foot, "speed": res.velocity.length(),
		"predicted_on_target": res.on_target, "assisted_deg": res.assisted_correction_deg,
	}
	data.merge(_kick_event_info)
	ctx.emit_event(GameEvent.make(GameEvent.Type.SHOT, owner.actor_id, owner.team, data))
	return res

func _after_kick(action: StringName, res: KickModel.KickResult) -> void:
	last_result = res
	_last_kick_msec = Time.get_ticks_msec()
	lockout = Tuning.player.kick_lockout
	touch_timer = lockout
	# Patear desequilibra levemente: pierde algo de velocidad.
	owner.locomotion.velocity *= 0.9
	kicked.emit(action, res)

# --- Conduccion ------------------------------------------------------------
##
## Modelo de control cercano. Una sola ley define la sensacion: la pelota se coloca a `carry_gap()` metros del pie,
## y esa distancia crece con la velocidad (parado queda pegada, a sprint se empuja lejos). Cada toque es un IMPULSO
## calculado para que la pelota llegue a ese punto justo cuando el jugador llega alli.
##
## Modos de toque (los elige `_touch_mode`):
##  - settle: el joystick esta suelto -> para la pelota junto al pie (pisada). Si hay un rival cerca, la coloca del
##    lado contrario y el cuerpo se interpone (proteccion).
##  - lateral: el joystick apunta de costado a poca velocidad -> empuja la pelota al costado manteniendo el cuerpo
##    orientado (control lateral). El cuerpo mantiene su orientacion durante `lateral_hold_seconds`.
##  - redirect: cambio de rumbo amplio -> la pelota se lleva hacia el rumbo nuevo, mas pegada al pie.
##  - carry: conduccion normal (caminar, trotar, correr, sprint).

## Distancia (m) a la que el jugador quiere la pelota respecto al pie a una velocidad dada. Ley de tres tramos
## (parado / trote / sprint) con los valores de PlayerTuning; la habilidad de conduccion la acerca.
func carry_gap(speed: float, skill: float) -> float:
	var t: PlayerTuning = Tuning.player
	var g: float
	if speed <= t.jog_speed:
		g = lerpf(t.carry_gap_stand, t.touch_lead_jog, clampf(speed / maxf(t.jog_speed, 0.1), 0.0, 1.0))
	else:
		g = lerpf(t.touch_lead_jog, t.touch_lead_sprint, clampf((speed - t.jog_speed) / maxf(t.sprint_speed - t.jog_speed, 0.1), 0.0, 1.0))
	return g * lerpf(1.12, 0.9, clampf(skill, 0.0, 1.0))

func _carry_skill() -> float:
	return 0.5 * owner.attributes.norm("ball_control") + 0.5 * owner.attributes.norm("ball_carrying")

## Segundos entre toques. Con el pack, la cadencia sigue a la de los pasos de la animacion (uno por apoyo a trote,
## uno cada dos apoyos a carrera/sprint); sin el, los valores fijos de PlayerTuning.
func _touch_interval(ratio: float) -> float:
	var t: PlayerTuning = Tuning.player
	var fixed: float = lerpf(t.touch_interval_jog, t.touch_interval_sprint, ratio)
	var v: FootballerVisual = owner.visual
	if v == null or not v.uses_pack or v.is_placeholder:
		return fixed
	var step: float = FootballerVisual.step_interval_for(owner.locomotion.speed)
	if step <= 0.0:
		return fixed
	return clampf(step * (1.0 if ratio < 0.2 else 2.0), 0.2, 0.6)

## Rival mas cercano a este jugador dentro de `radius` (o null). Lo usan la proteccion y el calculo de presion.
func nearest_opponent(radius: float) -> Footballer:
	var ctx: MatchContext = owner.ctx
	if ctx == null:
		return null
	var best: Footballer = null
	var best_d: float = radius
	for o in ctx.footballers:
		if o.team == owner.team or o == owner:
			continue
		var d: float = KickModel.flat(o.global_position - owner.global_position).length()
		if d < best_d:
			best_d = d
			best = o
	return best

## Modo del proximo toque segun la intencion del joystick y el estado del cuerpo.
func _touch_mode(desired_dir: Vector3, stick_mag: float, turn_angle: float) -> StringName:
	var t: PlayerTuning = Tuning.player
	var loco: Locomotion = owner.locomotion
	if _pending_action != &"":
		return &"setup"
	if stick_mag < 0.18:
		return &"settle"
	if _lateral_hold > 0.0:
		return &"lateral"
	if turn_angle > 55.0:
		return &"redirect"
	if loco.speed > t.jog_speed and stick_mag > 0.9:
		return &"carry"
	return &"carry"

## Un toque de conduccion en la direccion dada (lo usa una accion con raiz, que no pasa por update()).
func force_dribble_touch(dir: Vector3) -> void:
	_try_dribble_touch(dir, 0.8)

func _try_dribble_touch(desired_dir: Vector3, stick_mag: float) -> void:
	var b: Ball = ball()
	if b == null or b.is_held() or b.global_position.y > 0.45:
		return
	# Nadie vuelve a tocar su propio pase o tiro recien ejecutado (si no, el jugador se "robaria" su propio envio).
	if b.last_toucher == owner and Time.get_ticks_msec() - _last_kick_msec < 700:
		return
	var loco: Locomotion = owner.locomotion
	var t: PlayerTuning = Tuning.player
	var off: Vector3 = ball_offset()
	var dist: float = off.length()
	var reach: float = touch_reach()
	if dist > reach * 1.55:
		return
	var fwd: Vector3 = loco.forward()
	var body_v := Vector3(loco.velocity.x, 0.0, loco.velocity.z)
	var ball_v: Vector3 = KickModel.flat(b.linear_velocity)
	var rel_v: Vector3 = ball_v - body_v
	# Un balon que LLEGA rapido no se conduce: se controla (primer toque). Si no, el toque de parada lo frenaria
	# desde lejos y el control orientado no llegaria a ocurrir nunca.
	if dist > 0.5:
		var closing: float = -rel_v.dot(off / maxf(dist, 0.01))
		if closing > 2.0:
			return
	var has_dir: bool = desired_dir.length_squared() > 0.01
	var turn_angle: float = KickModel.angle_between_deg(fwd, desired_dir) if has_dir else 0.0
	var mode: StringName = _touch_mode(desired_dir, stick_mag, turn_angle)

	# Parado y con la pelota quieta no hay nada que hacer: no se la empuja sin motivo.
	if mode == &"settle" and loco.speed < 0.5 and rel_v.length() < 0.55 and _shield_dir(dist).length_squared() < 0.01:
		return

	var ratio: float = _sprint_ratio()
	var interval: float = _touch_interval(ratio)
	if mode == &"settle":
		interval = 0.26
	elif mode == &"lateral":
		interval = maxf(interval * 0.8, 0.2)

	# --- Cuando tocar: cuando la pelota vuelve al alcance del pie, o antes si se esta escapando ---------------
	var escaping: bool = false
	if _redirect_hold <= 0.0 and rel_v.length() > 0.5:
		var rel_future: Vector3 = off + rel_v * 0.14
		escaping = rel_future.length() > reach * t.touch_escape_factor and dist < reach * 1.3
	var urgent: bool = escaping or mode == &"redirect" or (mode == &"settle" and rel_v.length() > 0.8)
	if touch_timer > 0.0 and not (urgent and touch_timer < interval * 0.8):
		return
	var lateral_off: float = absf(off.dot(loco.right()))
	var trigger: float = clampf(_planned_gap + 0.14, reach * 0.5, reach * 1.1)
	if mode == &"redirect" or mode == &"lateral":
		trigger = reach * 1.35
	elif mode == &"settle" or mode == &"setup":
		trigger = reach * 1.5
	elif lateral_off > 0.45:
		trigger = reach * 1.25
	if dist > trigger:
		return
	# La pelota quedo detras: hay que girar o recuperarla, salvo que el toque sea justo para traerla de vuelta.
	if off.dot(fwd) < -0.3 and (mode == &"carry" or mode == &"setup") and lateral_off < 0.45:
		return

	var skill: float = _carry_skill()

	# --- A donde va la pelota -------------------------------------------------------------------------------
	var touch_dir: Vector3 = fwd
	var gap: float = 0.0
	var travel: float = interval          # segundos hasta el proximo toque
	var carry_speed: float = 0.0
	match mode:
		&"settle":
			var shield: Vector3 = _shield_dir(dist)
			touch_dir = shield if shield.length_squared() > 0.01 else fwd
			gap = t.settle_gap
			carry_speed = 0.0
			travel = 0.3
			# Frenando desde carrera la pelota no se para en seco: se amortigua hasta donde el cuerpo va a detenerse.
			if loco.speed > t.walk_speed and shield.length_squared() < 0.01:
				var stop_dist: float = loco.speed * loco.speed / (2.0 * maxf(t.decel * owner.attributes.factor("acceleration", 0.16), 1.0))
				gap += stop_dist * 0.8
				travel = clampf(loco.speed / maxf(t.decel, 1.0) * 1.1, 0.3, 0.9)
		&"setup":
			# Con un pase o tiro pulsado el siguiente toque PREPARA el golpeo: acerca la pelota al pie en vez de
			# empujarla lejos, asi el jugador puede ejecutar sin frenar la carrera.
			carry_speed = _carry_speed_after_turn(stick_mag, turn_angle) if has_dir else loco.speed
			touch_dir = (desired_dir.normalized() if has_dir else fwd)
			gap = carry_gap(carry_speed, skill) * 0.6
		&"lateral":
			touch_dir = desired_dir.normalized()
			gap = t.carry_gap_stand + 0.12
			carry_speed = minf(loco.speed_for_magnitude(stick_mag), t.jog_speed)
		&"redirect":
			touch_dir = desired_dir.normalized()
			# En un giro cerrado la pelota se lleva pegada al pie: cuanto mas cerrado, mas corta la colocacion.
			var tight: float = clampf((turn_angle - 55.0) / 125.0, 0.0, 1.0)
			carry_speed = _carry_speed_after_turn(stick_mag, turn_angle)
			gap = lerpf(carry_gap(carry_speed, skill), t.carry_gap_stand, tight * 0.75)
			_redirect_hold = 0.22 if turn_angle > 90.0 else 0.0
		_:
			carry_speed = _carry_speed_after_turn(stick_mag, turn_angle)
			gap = carry_gap(carry_speed, skill)
			var w: float = 0.45 if turn_angle < 25.0 else 0.8
			touch_dir = (fwd * (1.0 - w) + desired_dir.normalized() * w).normalized() if has_dir else fwd
			# A sprint el toque puede pasarse (toque largo); con mejor control se pasa menos.
			gap += absf(rng.randfn(0.0, t.touch_overshoot_sprint * (1.2 - skill))) * ratio * ratio

	gap = minf(gap, reach * 1.35 - 0.05)
	_planned_gap = gap

	# Posicion del jugador cuando la pelota llegue a destino: promedio entre su velocidad actual y la que tendra.
	var p_pos: Vector3 = KickModel.flat(owner.global_position)
	var b_pos: Vector3 = KickModel.flat(b.global_position)
	var future_player: Vector3
	if turn_angle > 55.0 and mode != &"settle":
		# Giro cerrado: el cuerpo frena (sigue un instante su rumbo) y despues acelera hacia el nuevo.
		var t_align: float = minf(0.25 * turn_angle / 90.0, travel)
		future_player = p_pos + body_v * (t_align * 0.5) + touch_dir * carry_speed * maxf(travel - t_align, 0.0) * 0.5
	else:
		future_player = p_pos + (body_v + touch_dir * carry_speed) * 0.5 * travel
	var target: Vector3 = future_player + touch_dir * gap
	var v: Vector3 = (target - b_pos) / maxf(travel, 0.05)
	# Compensa la desaceleracion de rodadura durante el trayecto.
	if v.length() > 0.1:
		v += v.normalized() * 0.5 * 1.1 * travel
	v = v.limit_length(maxf(carry_speed, 0.5) + 4.5)

	# --- Error del toque: crece con sprint y giros bruscos; baja con control y conduccion --------------------
	var sigma: float = t.touch_error_deg * (1.5 - 0.9 * skill)
	sigma *= 1.0 + (t.touch_error_sprint - 1.0) * ratio
	sigma *= 1.0 + (t.touch_error_turn - 1.0) * clampf(absf(loco.turn_rate) / 6.0, 0.0, 1.0)
	if mode == &"settle" or mode == &"lateral" or mode == &"setup":
		sigma *= 0.5
	elif mode == &"redirect":
		sigma *= 0.7
	sigma = minf(sigma, t.touch_error_max_deg)
	var err: float = KickModel.gaussian_clipped(rng, sigma)
	# El error es del empuje del pie: se aplica a la velocidad RELATIVA al jugador. Aplicado a la velocidad absoluta,
	# un error de unos grados a 6-7 m/s mandaba la pelota >2 m al costado (se perdia el balon a carrera y sprint).
	var rel: Vector3 = (v - body_v).rotated(Vector3.UP, deg_to_rad(err))
	rel *= clampf(rng.randfn(1.0, 0.03 + 0.05 * ratio), 0.85, 1.15)
	v = body_v + rel
	b.kick(v, b.rolling_spin(v), owner)
	touch_timer = interval * rng.randf_range(0.9, 1.1)
	dribble_touch_count += 1
	last_touch_mode = mode
	touched_ball.emit(mode)

## Velocidad a la que el jugador podra llevar la pelota tras el giro (en un giro cerrado el cuerpo frena antes de
## acelerar hacia el rumbo nuevo: empujar la pelota al ritmo de la carrera actual la perderia).
func _carry_speed_after_turn(stick_mag: float, turn_angle: float) -> float:
	var t: PlayerTuning = Tuning.player
	var loco: Locomotion = owner.locomotion
	var desired: float = loco.max_sprint_speed() if loco.sprinting else loco.speed_for_magnitude(stick_mag)
	var turn_pen: float = clampf((turn_angle - 55.0) / 95.0, 0.0, 1.0)
	desired = lerpf(desired, minf(desired, t.walk_speed + 0.8), turn_pen)
	var carry: float = minf(desired * 0.95, loco.speed + t.accel * 0.2)
	return maxf(carry, loco.speed * 0.9)

## Direccion en la que conviene colocar la pelota al pararla: lejos del rival mas cercano (proteccion). Cero si no
## hay rival a quien proteger la pelota.
func _shield_dir(dist: float) -> Vector3:
	var opp: Footballer = nearest_opponent(Tuning.player.shield_radius)
	if opp == null:
		return Vector3.ZERO
	var away: Vector3 = KickModel.flat(owner.global_position - opp.global_position)
	if away.length() < 0.2:
		return Vector3.ZERO
	away = away.normalized()
	# Si la pelota ya esta del lado protegido no hace falta moverla.
	if dist < Tuning.player.settle_gap + 0.2 and ball_offset().normalized().dot(away) > 0.55:
		return Vector3.ZERO
	return away

## Decide, ANTES de que el cuerpo gire, hacia donde mira el jugador mientras lleva la pelota. Lo llama el futbolista
## al principio del paso de fisica, porque la decision depende de la orientacion que el cuerpo tiene todavia:
##  - Proteccion: casi parado con un rival cerca -> le da la espalda y deja la pelota del lado contrario.
##  - Control lateral: el joystick apunta de costado a poca velocidad -> el cuerpo conserva su orientacion durante
##    `lateral_hold_seconds` y el jugador se desplaza de lado (mezcla direccional de la animacion). Despues gira
##    normalmente: el control lateral es un recurso puntual, no un bloqueo del giro.
## Devuelve la direccion a la que mirar, o cero para que el cuerpo gire libremente hacia el joystick.
func plan_carry(desired_dir: Vector3, stick_mag: float, dt: float) -> Vector3:
	_lateral_hold = maxf(_lateral_hold - dt, 0.0)
	_lateral_cooldown = maxf(_lateral_cooldown - dt, 0.0)
	_carry_face = Vector3.ZERO
	var loco: Locomotion = owner.locomotion
	if loco == null or not has_possession():
		_lateral_hold = 0.0
		return _carry_face
	var t: PlayerTuning = Tuning.player
	if _lateral_hold > 0.0:
		if stick_mag < 0.15:
			_lateral_hold = 0.0
		else:
			_carry_face = _lateral_face
			return _carry_face
	if stick_mag < 0.35 and loco.speed < t.walk_speed:
		var opp: Footballer = nearest_opponent(t.shield_radius)
		if opp != null:
			var away: Vector3 = KickModel.flat(owner.global_position - opp.global_position)
			if away.length() > 0.3:
				_carry_face = away.normalized()
				return _carry_face
	if _lateral_cooldown <= 0.0 and desired_dir.length_squared() > 0.01 and stick_mag > 0.18 \
			and stick_mag <= t.lateral_max_stick and loco.speed < t.jog_speed:
		var ang: float = KickModel.angle_between_deg(loco.forward(), desired_dir)
		if ang > 55.0 and ang < 125.0:
			_lateral_hold = t.lateral_hold_seconds
			_lateral_cooldown = t.lateral_hold_seconds + 0.5
			_lateral_face = loco.forward()
			_carry_face = _lateral_face
	return _carry_face

## Direccion a la que debe mirar el cuerpo mientras conduce (control lateral o proteccion). Cero = libre.
func carry_face() -> Vector3:
	return _carry_face


# --- Control de primer toque -----------------------------------------------

func _try_first_touch(desired_dir: Vector3) -> bool:
	if control_cooldown > 0.0:
		return false
	var b: Ball = ball()
	if b == null or b.is_held():
		return false
	var t: PlayerTuning = Tuning.player
	var off: Vector3 = ball_offset()
	var dist: float = off.length()
	if dist > t.possession_radius or b.global_position.y > 0.7 or dist < 0.01:
		return false
	# Un balon que acaba de golpear este mismo jugador no se "controla".
	if b.last_toucher == owner and Time.get_ticks_msec() - b.last_touch_msec < 450:
		return false
	# Un balon disputado (otro jugador lo acaba de tocar y sigue junto a el) no se controla gratis:
	# hay que disputarlo (entrada / presion).
	var last: Footballer = b.last_toucher as Footballer
	if last != null and last != owner and KickModel.flat(last.global_position - b.global_position).length() < 1.5:
		return false
	var rel_v: Vector3 = KickModel.flat(b.linear_velocity - owner.velocity)
	var closing: float = -rel_v.dot(off / dist)
	if closing < 2.2:
		return false
	var loco: Locomotion = owner.locomotion
	var ratio: float = _sprint_ratio()
	var absorb: float = t.first_touch_absorb * owner.attributes.factor("ball_control", 0.35)
	var behind: bool = off.dot(loco.forward()) < -0.25
	if behind:
		absorb *= 0.5
	absorb *= 1.0 - 0.25 * ratio
	absorb *= lerpf(0.85, 1.0, KickModel.balance_state(owner))
	absorb = clampf(absorb, 0.15, 0.93)
	var leftover: Vector3 = rel_v * (1.0 - absorb)
	# Ruido: peor control = rebote menos predecible.
	var sigma: float = 20.0 * (1.35 - owner.attributes.norm("ball_control")) * (1.0 + 0.4 * ratio)
	leftover = leftover.rotated(Vector3.UP, deg_to_rad(KickModel.gaussian_clipped(rng, sigma)))
	# Control orientado: empuja el sobrante hacia donde quiere ir el jugador.
	if desired_dir.length_squared() > 0.01:
		leftover += desired_dir.normalized() * (rel_v.length() * (1.0 - absorb) * 0.25 * owner.attributes.norm("ball_control"))
	var new_v: Vector3 = owner.velocity + leftover
	new_v.y = minf(b.linear_velocity.y, 1.2) * 0.3
	b.kick(new_v, b.rolling_spin(new_v) * 0.8, owner)
	control_cooldown = 0.5
	touch_timer = 0.12
	owner.ctx.emit_event(GameEvent.make(GameEvent.Type.FIRST_TOUCH, owner.actor_id, owner.team,
		{"absorb": absorb, "incoming_speed": rel_v.length()}))
	touched_ball.emit(&"first_touch")
	return true

# --- Disputa ----------------------------------------------------------------

## Intenta quitar la pelota. No esta garantizado: depende de distancia, orientacion, equilibrio,
## velocidad relativa y atributos de ambos jugadores. Devuelve true si la recupera.
func attempt_tackle(carrier: Footballer) -> bool:
	var b: Ball = ball()
	if b == null:
		return false
	var d_off: Vector3 = ball_offset()
	var dist: float = d_off.length()
	var facing: float = KickModel.angle_between_deg(owner.locomotion.forward(), d_off)
	var chance: float = 0.32 * owner.attributes.factor("marking", 0.9)
	chance *= clampf(1.0 - facing / 140.0, 0.35, 1.0)
	chance *= lerpf(0.85, 1.0, KickModel.balance_state(owner))
	chance *= clampf(1.15 - dist * 0.25, 0.55, 1.1)
	var rel_speed: float = KickModel.flat(owner.velocity - (carrier.velocity if carrier != null else Vector3.ZERO)).length()
	if rel_speed > 6.0:
		chance *= 0.75
	if carrier != null:
		var shield: float = carrier.attributes.factor("strength", 0.4) * carrier.attributes.factor("balance", 0.3)
		# Proteger la pelota parado no aguanta: sin movimiento el cuerpo no puede seguir tapando al rival.
		shield *= lerpf(0.55, 1.0, clampf(carrier.locomotion.speed / 2.0, 0.0, 1.0))
		shield *= lerpf(1.0, 1.25, 1.0 - clampf(KickModel.angle_between_deg(carrier.locomotion.forward(), owner.global_position - carrier.global_position) / 180.0, 0.0, 1.0))
		chance /= maxf(shield, 0.5)
		# Si el balon esta lejos de su portador (toque largo) es mas facil.
		if carrier.ball_handler.ball_distance() > 0.9:
			chance *= 1.5
	else:
		chance *= 1.6
	if carrier != null and carrier.actions != null and carrier.actions.kind == &"skill":
		chance *= 0.3   # la ruleta protege al portador
	chance = clampf(chance, 0.04, 0.88)
	var won: bool = rng.randf() < chance
	var ctx: MatchContext = owner.ctx
	if won:
		var away: Vector3 = owner.locomotion.forward()
		var v: Vector3 = owner.velocity * 0.6 + away * rng.randf_range(2.2, 3.6)
		b.kick(v, b.rolling_spin(v), owner)
		touch_timer = 0.25
		if carrier != null:
			carrier.ball_handler.lockout = maxf(carrier.ball_handler.lockout, 0.6)
			carrier.ball_handler.touch_timer = 0.6
		ctx.emit_event(GameEvent.make(GameEvent.Type.TACKLE_WON, owner.actor_id, owner.team,
			{"victim": carrier.actor_id if carrier != null else -1, "chance": chance}))
	else:
		# Fallar la disputa te deja fuera de posicion un instante.
		owner.locomotion.velocity *= 0.55
		ctx.emit_event(GameEvent.make(GameEvent.Type.TACKLE_FAILED, owner.actor_id, owner.team,
			{"victim": carrier.actor_id if carrier != null else -1, "chance": chance}))
	return won
