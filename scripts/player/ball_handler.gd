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
## Interruptor global (pruebas): false ignora los pies animados y conduce con la cadencia de la marcha.
static var foot_sync_enabled: bool = true
## Maximo de entradas del registro de patadas.
const KICK_LOG_MAX := 64
## Segundos que espera un pase o tiro pulsado hasta que algun pie llegue a la pelota antes de descartarse.
const PENDING_KICK_MAX := 0.5
## Ultimos segundos antes del contacto con el pie de apoyo plantado: sin ajuste de paso y con el cuerpo a la velocidad
## que pide el propio clip (la que deja quieto en el suelo el pie de apoyo: clip_plant_velocity), asi no patina.
## Sin datos del pie de apoyo (cabezazos, voleas) el cuerpo se frena a KICK_PLANT_SPEED de su velocidad.
const KICK_PLANT_TIME := 0.10
const KICK_PLANT_SPEED := 0.4
## Altura maxima (m) de la punta del pie de apoyo para considerarlo plantado.
const PLANT_FOOT_MAX_Y := 0.06
## m/s que la velocidad de apoyo de un clip puede superar a la del cuerpo al empezar la patada.
const PLANT_SPEED_GAIN_MAX := 1.5
## Coste (m de residuo equivalentes por m/s) de elegir un clip cuya velocidad de apoyo no encaja con la del jugador.
const PLANT_MISMATCH_COST := 0.06
## Velocidad maxima del ajuste de paso (m/s) durante el balanceo, parado; a la carrera la ultima zancada puede
## alargarse mas (KICK_NUDGE_PER_MS por cada m/s del cuerpo).
const KICK_NUDGE_MAX := 3.2
const KICK_NUDGE_PER_MS := 0.4
## Espera maxima de una orden de golpeo con la pelota viniendo hacia el jugador (pase o tiro de primera).
const PENDING_FIRST_TIME_MAX := 1.4
## Toque de arrancada: metros extra de colocacion por cada m/s que falta para la velocidad punta (y su tope).
const ACCEL_TOUCH_PER_MS := 0.12
const ACCEL_TOUCH_MAX := 0.3
## Segundos minimos entre dos toques de media vuelta seguidos (el pie no puede tocar la pelota cada fotograma).
const REVERSAL_TOUCH_GAP := 0.12

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
## Velocidad del cuerpo y direccion deseada al empezar la patada con clip: durante el balanceo el jugador ya se
## comprometio (el joystick deja de girarlo/acelerarlo) y en los ultimos KICK_PLANT_TIME el pie de apoyo se planta.
var _kick_v0: Vector3 = Vector3.ZERO
var kick_desired_dir: Vector3 = Vector3.ZERO
var kick_desired_mag: float = 0.0
var touch_timer: float = 0.0
var lockout: float = 0.0
var control_cooldown: float = 0.0
var dribble_touch_count: int = 0
var last_result: KickModel.KickResult = null

var _pass_active: bool = false
var _pass_time: float = 0.0
var _shoot_active: bool = false
var _shoot_time: float = 0.0
var _through_active: bool = false
var _through_time: float = 0.0
var _cross_active: bool = false
var _cross_time: float = 0.0
var _pending_action: StringName = &""
var _pending_charge: float = 0.0
var _pending_lob: bool = false
var _pending_curl: float = 0.0
## Efecto (chanfle) del golpeo en curso: -1..1, positivo = la pelota se curva a la derecha del tiro. Lo marca el gesto
## del joystick entre pulsar y soltar el boton (ver _curl_from).
var _kick_curl: float = 0.0
var shot_curl: float = 0.0
var _aim_press: Vector3 = Vector3.ZERO
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
var through_charge: float = 0.0
var cross_charge: float = 0.0

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
	# Pelota al pie Y no es de otro (MatchContext.possessor arbitra cuando dos estan cerca). No se exige ser ya el
	# poseedor arbitrado: eso exige un toque previo y cortaba la conduccion entre toques (zigzag: 8 de 16 toques con el
	# pie frente a 16 de 18).
	if ball_distance() > possession_radius() or b.global_position.y >= 0.6:
		return false
	if owner.ctx != null:
		owner.ctx.update_possession()
		return owner.ctx.possessor == null or owner.ctx.possessor == owner
	return true

## Conduce aunque el ultimo toque largo la haya alejado un poco: fue el ultimo en tocarla, no la pateo (pase/tiro) y
## sigue cerca. Sirve para no cambiar de marcha (ni de tope de velocidad) entre dos toques de una conduccion larga.
func is_dribbling() -> bool:
	if has_possession():
		return true
	var b: Ball = ball()
	return b != null and not b.is_held() and b.last_toucher == owner and ball_distance() < 2.3 \
		and Time.get_ticks_msec() - _last_kick_msec > 700 and b.global_position.y < 0.6

## Segundos hasta que una pelota que se ACERCA pase a menos de radius del jugador (INF si no viene hacia el, va alta o
## es de otro). Prediccion lineal en el plano: alcanza para decidir si una orden espera el golpeo de primera.
func incoming_ball_eta(radius: float = 2.5) -> float:
	var b: Ball = ball()
	if b == null or b.is_held() or b.global_position.y > 1.2 or ball_owned_by_other():
		return INF
	var rel := Vector2(b.global_position.x - owner.global_position.x, b.global_position.z - owner.global_position.z)
	var v := Vector2(b.linear_velocity.x, b.linear_velocity.z)
	var vv: float = v.length_squared()
	if vv < 1.0 or rel.dot(v) >= 0.0:
		return INF
	var t: float = -rel.dot(v) / vv
	if (rel + v * t).length() > radius:
		return INF
	return t

## Punto (en el suelo) de la trayectoria de la pelota que viene mas cercano al jugador: donde preparar el golpeo de primera.
func incoming_ball_point() -> Vector3:
	var b: Ball = ball()
	var eta: float = incoming_ball_eta()
	if b == null or eta == INF:
		return owner.global_position
	var p: Vector3 = b.global_position + KickModel.flat(b.linear_velocity) * eta
	return Vector3(p.x, 0.0, p.z)

## Hay una orden de pase/tiro esperando una pelota que llega (golpeo de primera, sin control previo).
func is_waiting_first_time() -> bool:
	return _pending_action != &"" and _pending_age <= PENDING_FIRST_TIME_MAX and incoming_ball_eta() < PENDING_FIRST_TIME_MAX

## La pelota es de otro jugador (la conduce o la acaba de controlar): no se la puede conducir ni controlar, solo disputar.
func ball_owned_by_other() -> bool:
	if owner.ctx == null:
		return false
	owner.ctx.update_possession()
	var p: Footballer = owner.ctx.possessor
	if p == null or p == owner:
		return false
	# Un toque largo (la pelota lejos de su dueno) si se puede cortar.
	return Vector2(p.global_position.x - ball().global_position.x, p.global_position.z - ball().global_position.z).length() < 1.05

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
	_sample_feet(dt)
	_update_buttons(frame, stick_world, dt)
	if _kick_action != &"":
		_kick_timer -= dt
		if _kick_timer <= 0.0:
			_finish_kick()
		elif not _kick_clip.is_empty():
			_steer_clip_kick()
		return
	if _pending_action != &"":
		_pending_age += dt
		if _try_execute_pending():
			return
		# Pase o tiro de primera: con la pelota viniendo hacia el jugador, la orden espera a que llegue (hasta
		# PENDING_FIRST_TIME_MAX) en vez de caducar a los PENDING_KICK_MAX.
		var waiting_first_time: bool = is_waiting_first_time()
		if _pending_age > PENDING_KICK_MAX and not waiting_first_time:
			if uses_clip_kicks():
				_log_kick(_pending_action, &"out_of_reach", {"stage": "pending"})
				kick_stats["out_of_reach"] += 1
				owner.ctx.emit_event(GameEvent.make(GameEvent.Type.KICK_WHIFF, owner.actor_id, owner.team, {"action": String(_pending_action), "reason": "out_of_reach"}))
			_pending_action = &""
		elif waiting_first_time:
			return   # sin control previo: el golpeo sera de primera
	if lockout > 0.0 or owner.ctx.ball_locked_for(owner) or ball_owned_by_other():
		return
	if _try_first_touch(desired_dir):
		return
	_try_dribble_touch(desired_dir, stick_mag)

# --- Botones ---------------------------------------------------------------

func _update_buttons(frame: InputFrame, stick_world: Vector3, dt: float) -> void:
	var bt: BallTuning = Tuning.ball
	# Un solo boton de golpeo a la vez: el primero que se pulsa manda hasta soltarse.
	var busy: bool = _pass_active or _shoot_active or _through_active or _cross_active
	if frame.pass_pressed and not busy:
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
	if frame.shoot_pressed and not busy:
		_shoot_active = true
		_shoot_time = 0.0
		_aim_press = KickModel.flat(stick_world)
	if _shoot_active:
		if frame.shoot_held:
			_shoot_time += dt
		shot_charge = clampf(_shoot_time / bt.shot_charge_time, 0.0, 1.0)
		if frame.shoot_released or not frame.shoot_held:
			var curl: float = curl_from(_aim_press, stick_world)
			# Con chanfle, el tiro va hacia donde se apunto al pulsar; el giro posterior del joystick es el efecto.
			_queue(&"shot", shot_charge, frame.lob_held, _aim_press if curl != 0.0 else stick_world, curl)
			_shoot_active = false
			shot_charge = 0.0
	if frame.through_pressed and not busy:
		_through_active = true
		_through_time = 0.0
	if _through_active:
		if frame.through_held:
			_through_time += dt
		through_charge = clampf(_through_time / 0.8, 0.0, 1.0)
		if frame.through_released or not frame.through_held:
			_queue(&"through", through_charge, frame.lob_held, stick_world)
			_through_active = false
			through_charge = 0.0
	if frame.cross_pressed and not busy:
		_cross_active = true
		_cross_time = 0.0
		_aim_press = KickModel.flat(stick_world)
	if _cross_active:
		if frame.cross_held:
			_cross_time += dt
		cross_charge = clampf(_cross_time / 0.8, 0.0, 1.0)
		if frame.cross_released or not frame.cross_held:
			var ccurl: float = curl_from(_aim_press, stick_world)
			_queue(&"cross", cross_charge, frame.lob_held, _aim_press if ccurl != 0.0 else stick_world, ccurl)
			_cross_active = false
			cross_charge = 0.0

## Efecto pedido con el joystick: angulo (con signo) entre la direccion al pulsar y al soltar. Un giro de 15-60 grados
## a la derecha del tiro curva la pelota a la derecha (y a la izquierda al reves). Menos de 15 grados: sin efecto extra.
static func curl_from(at_press: Vector3, at_release: Vector3) -> float:
	if at_press.length() < 0.3 or at_release.length() < 0.3:
		return 0.0
	# signed_angle_deg es positivo hacia la izquierda (antihorario visto desde arriba): la derecha es negativa.
	var ang: float = -KickModel.signed_angle_deg(at_press, at_release)
	if absf(ang) < 15.0:
		return 0.0
	return clampf(ang / 60.0, -1.0, 1.0)

func _queue(action: StringName, charge: float, lob: bool, stick_world: Vector3, curl: float = 0.0) -> void:
	_pending_curl = curl
	_pending_action = action
	_pending_charge = charge
	_pending_lob = lob
	_pending_stick = stick_world
	_pending_age = 0.0

func _try_execute_pending() -> bool:
	if lockout > 0.0 or owner.ctx.ball_locked_for(owner) or ball_owned_by_other():
		return false
	if uses_clip_kicks():
		var plan: Dictionary = plan_clip_kick(_pending_action, _pending_charge, _pending_lob)
		if plan.is_empty():
			return false   # ningun pie llegaria a la pelota: se espera (buffer) o se descarta
		var act: StringName = _pending_action
		_pending_action = &""
		_kick_curl = _pending_curl
		_start_clip_kick(act, plan, _pending_stick, _pending_charge, _pending_lob)
		return true
	if not can_reach(Tuning.player.touch_reach + 0.3):
		return false
	var action: StringName = _pending_action
	_pending_action = &""
	_kick_curl = _pending_curl
	request_kick(action, _pending_stick, _pending_charge, _pending_lob)
	return true

## Segundos entre el inicio de la patada y el golpeo (la animacion y el impulso comparten este instante).
func contact_delay(action: StringName, charge: float) -> float:
	return 0.12 + 0.06 * charge if action == &"shot" else 0.10

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
		if action == &"cross":
			power = 0.6 + 0.4 * charge
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
## La latencia se cuantiza a pasos de fisica (el impulso solo puede ocurrir en un paso): el clip llega a la pose de
## contacto exactamente en el paso del impulso. Como el AnimationTree avanza en _process (despues de la fisica), esa pose
## es la imagen que se dibuja justo ANTES de que la pelota salga, y en la siguiente el pie sigue de largo con la pelota
## ya en marcha (medido con el esqueleto: punta del pie a 0.02-0.07 m en la imagen del contacto; el pie avanza
## 0.25-0.3 m por fotograma en un golpeo).
static func clip_timing(contact_time: float, action: StringName, charge: float) -> Dictionary:
	var t: PlayerTuning = Tuning.player
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var want: float = t.kick_latency + (0.04 * charge if action == &"shot" else 0.0)
	var steps: int = maxi(int(round(want / dt)), 2)
	var speed: float = clampf(contact_time / 0.30, 1.0, t.kick_clip_speed_max)
	var offset: float = contact_time - speed * dt * float(steps)
	if offset < 0.0:
		offset = 0.0
		speed = contact_time / (dt * float(steps))
	# Un poco menos que steps * dt: el temporizador llega a cero exactamente en el paso `steps`.
	return {"speed": speed, "offset": offset, "latency": float(steps) * dt - 0.0005}

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
	_through_active = false
	_cross_active = false
	pass_charge = 0.0
	shot_charge = 0.0
	through_charge = 0.0
	cross_charge = 0.0

## Velocidad (adelante, derecha) en m/s del cuerpo que deja QUIETO el pie de apoyo de un clip en el sitio en los
## KICK_PLANT_TIME previos al contacto (los clips en el sitio mueven el pie apoyado hacia atras a la velocidad de
## carrera que representan). playback: velocidad de reproduccion. Si el pie no esta apoyado, cero (el cuerpo se para).
static func clip_plant_velocity(clip: StringName, contact_time: float, foot: int, playback: float) -> Vector2:
	var paths: Dictionary = PackLibrary.meta(clip).get("paths", {})
	var key: String = "toe_l" if foot == 1 else "toe_r"
	if not paths.has(key):
		return Vector2.ZERO
	var path: PackedVector3Array = paths[key]
	var k1: int = mini(int(round(contact_time * 30.0)), path.size() - 1)
	var k0: int = maxi(k1 - maxi(int(round(KICK_PLANT_TIME * playback * 30.0)), 1), 0)
	if k1 <= k0 or path[k1].y > PLANT_FOOT_MAX_Y:
		return Vector2.ZERO
	var d: Vector3 = path[k1] - path[k0]
	var secs: float = float(k1 - k0) / 30.0 / playback
	return Vector2(-d.x, -d.z) / secs

## Velocidad del cuerpo (mundo) con el pie de apoyo plantado para un contacto, con orientacion yaw y velocidad previa v.
## La velocidad del clip se acota a la que trae el cuerpo + PLANT_SPEED_GAIN_MAX: un jugador parado no sale disparado
## porque el clip elegido represente un golpeo al trote (el pie de apoyo desliza algo en ese caso; plan_clip_kick
## prefiere los clips cuya velocidad de apoyo encaja con la del jugador, ver PLANT_MISMATCH_COST).
static func plant_velocity(contact: Dictionary, yaw: float, v: Vector3) -> Vector3:
	if not contact.has("plant"):
		return Vector3(v.x, 0.0, v.z) * KICK_PLANT_SPEED
	var pl: Vector2 = contact["plant"]
	var f: Vector3 = Locomotion.dir_from_yaw(yaw)
	var pv: Vector3 = f * pl.x + Vector3(-f.z, 0.0, f.x) * pl.y
	return pv.limit_length(Vector2(v.x, v.z).length() + PLANT_SPEED_GAIN_MAX)

## Recorrido del cuerpo en las proximas latency s de una patada que empieza (o sigue) con velocidad v: a velocidad
## constante hasta plantar el pie y a la velocidad de apoyo (plant_v) en los ultimos KICK_PLANT_TIME.
static func kick_body_travel(v: Vector3, latency: float, plant_v: Vector3) -> Vector3:
	var plant: float = minf(latency, KICK_PLANT_TIME)
	return Vector3(v.x, 0.0, v.z) * (latency - plant) + plant_v * plant

## Ajuste de paso maximo (m/s) a la velocidad de cuerpo v.
static func kick_nudge_cap(v: Vector3) -> float:
	return KICK_NUDGE_MAX + KICK_NUDGE_PER_MS * Vector2(v.x, v.z).length()

## Metros de ajuste de paso que caben antes de plantar el pie en una patada de latencia `latency`.
static func kick_adjust_capacity(v: Vector3, latency: float) -> float:
	return kick_nudge_cap(v) * maxf(latency - KICK_PLANT_TIME, 0.0)

## true durante una patada con clip (balanceo hasta el contacto).
func is_clip_kick_in_progress() -> bool:
	return _kick_action != &"" and not _kick_clip.is_empty()

## Velocidad del cuerpo durante una patada con clip: la de partida, frenada con el pie de apoyo plantado.
func kick_body_velocity() -> Vector3:
	if _kick_timer > KICK_PLANT_TIME:
		return _kick_v0
	return plant_velocity(_kick_clip["contact"], owner.locomotion.yaw, _kick_v0)

## Ajuste de paso en lazo cerrado: cada fotograma se vuelve a predecir donde estara el pie en el contacto y se corrige
## lo que falta con el cuerpo (acotado) hasta plantar el pie; con el pie plantado no hay ajuste.
func _steer_clip_kick() -> void:
	if _kick_timer <= KICK_PLANT_TIME:
		owner.nudge_velocity = Vector3.ZERO
		return
	var b: Ball = ball()
	if b == null or b.is_held():
		owner.nudge_velocity = Vector3.ZERO
		return
	var delta: Vector3 = predicted_foot_to_ball(_kick_clip["contact"], _kick_timer, _kick_v0)
	var flat_d := Vector3(delta.x, 0.0, delta.z)
	owner.nudge_velocity = (flat_d / maxf(_kick_timer - KICK_PLANT_TIME, 0.04)).limit_length(kick_nudge_cap(_kick_v0))

func predicted_foot_to_ball(contact: Dictionary, latency: float, body_v: Variant = null) -> Vector3:
	var b: Ball = ball()
	var loco: Locomotion = owner.locomotion
	var yaw: float = _predicted_yaw(latency)
	var v: Vector3 = body_v if body_v != null else loco.velocity
	var p: Vector3 = owner.global_position + kick_body_travel(v, latency, plant_velocity(contact, yaw, v))
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
							var pb: Vector3 = owner.global_position + kick_body_travel(loco.velocity, lat, plant_velocity(c, yaw, loco.velocity))
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
	var kind_key: StringName = action if action == &"cross" else (&"lob" if lob else action)
	for cand in AnimationCatalog.kick_candidates(kind_key):
		for smp in contact_samples(cand["contact"]):
			var c := {"time": smp["time"], "pos": smp["pos"], "foot": cand["foot"]}
			var timing: Dictionary = clip_timing(float(c["time"]), action, charge)
			c["plant"] = clip_plant_velocity(cand["clip"], float(c["time"]), int(c["foot"]), float(timing["speed"]))
			var delta: Vector3 = predicted_foot_to_ball(c, timing["latency"])
			var flat_d := Vector3(delta.x, 0.0, delta.z)
			# El ajuste solo cabe antes de plantar el pie: no se planifica uno que el cuerpo no puede dar.
			var step: Vector3 = flat_d.limit_length(minf(adjust_max, kick_adjust_capacity(owner.locomotion.velocity, float(timing["latency"]))))
			var residual: float = Vector3(flat_d.x - step.x, delta.y, flat_d.z - step.z).length()
			var mismatch: float = absf((c["plant"] as Vector2).length() - owner.locomotion.speed)
			var score: float = residual + 0.15 * step.length() + PLANT_MISMATCH_COST * mismatch
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
	_kick_v0 = KickModel.flat(owner.locomotion.velocity)
	kick_desired_dir = _desired_dir
	kick_desired_mag = clampf(owner.locomotion.speed / maxf(owner.locomotion.max_run_speed(), 0.1), 0.0, 1.0)
	_kick_timer = plan["latency"]
	lockout = _kick_timer + 0.4
	touch_timer = lockout
	owner.locomotion.turn_scale = t.kick_turn_scale
	owner.nudge_velocity = ((plan["adjust"] as Vector3) / maxf(_kick_timer - KICK_PLANT_TIME, 0.05)).limit_length(kick_nudge_cap(_kick_v0))
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
	# Tras el golpe el cuerpo sigue con la velocidad que traia (la del pie plantado era solo del balanceo).
	owner.locomotion.velocity = _kick_v0
	owner.locomotion.speed = _kick_v0.length()
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
	perform_action(action, _kick_stick, _kick_charge, _kick_lob)
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
	perform_action(action, _kick_stick, _kick_charge, _kick_lob)

## Ejecuta el golpeo de una accion (pase, filtrado, centro o tiro) en el instante de contacto.
func perform_action(action: StringName, stick_world: Vector3, charge: float, lob: bool) -> KickModel.KickResult:
	if shot_curl == 0.0:
		shot_curl = _kick_curl
	_kick_curl = 0.0
	match action:
		&"pass":
			return perform_pass(stick_world, charge, lob)
		&"through":
			return perform_through(stick_world, charge, lob)
		&"cross":
			return perform_cross(stick_world, charge, lob)
		_:
			return perform_shot(stick_world, charge, lob)

## Pase filtrado: al espacio por delante del desmarque del receptor.
func perform_through(stick_world: Vector3, charge: float, lob: bool) -> KickModel.KickResult:
	var ctx: MatchContext = owner.ctx
	var res: KickModel.KickResult = PassAssist.compute_through(owner, ctx, stick_world, charge, lob, rng, assist_pass_level())
	ball().kick(res.velocity, res.spin, owner)
	_after_kick(&"pass", res)
	var data: Dictionary = {"target": res.target.actor_id if res.target != null else -1, "kind": String(res.kind),
		"charge": charge, "error_deg": res.error_deg, "speed": res.velocity.length(), "through": true,
		"aim": [res.aim_point.x, res.aim_point.z]}
	data.merge(_kick_event_info)
	ctx.emit_event(GameEvent.make(GameEvent.Type.PASS, owner.actor_id, owner.team, data))
	return res

## Centro al area: con ALTO sale raso; con carga alta, tenso; si no, elevado.
func perform_cross(stick_world: Vector3, charge: float, low: bool) -> KickModel.KickResult:
	var ctx: MatchContext = owner.ctx
	var res: KickModel.KickResult = CrossAssist.compute(owner, ctx, stick_world, charge, low, rng, assist_pass_level(), shot_curl)
	shot_curl = 0.0
	ball().kick(res.velocity, res.spin, owner)
	_after_kick(&"pass", res)
	var data: Dictionary = {"target": res.target.actor_id if res.target != null else -1, "kind": String(res.kind),
		"charge": charge, "error_deg": res.error_deg, "speed": res.velocity.length(), "cross": true,
		"aim": [res.aim_point.x, res.aim_point.z]}
	data.merge(_kick_event_info)
	ctx.emit_event(GameEvent.make(GameEvent.Type.PASS, owner.actor_id, owner.team, data))
	return res

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
	var res: KickModel.KickResult = ShotAssist.compute(owner, ctx, stick_world, charge, lob, rng, assist_shot_level(), shot_curl)
	shot_curl = 0.0
	var b: Ball = ball()
	b.kick(res.velocity, res.spin, owner)
	_after_kick(&"shot", res)
	var data: Dictionary = {
		"kind": String(res.kind), "charge": charge, "error_deg": res.error_deg,
		"weak_foot": res.weak_foot, "speed": res.velocity.length(),
		"predicted_on_target": res.on_target, "assisted_deg": res.assisted_correction_deg,
		"dir": [res.final_dir.x, res.final_dir.z], "curl": res.curl,
	}
	data.merge(_kick_event_info)
	ctx.emit_event(GameEvent.make(GameEvent.Type.SHOT, owner.actor_id, owner.team, data))
	return res

func _after_kick(action: StringName, res: KickModel.KickResult) -> void:
	last_result = res
	# El receptor de un pase sabe a donde va la pelota: corre a ese punto (el pase no le cae del cielo).
	if action == &"pass" and res.target != null and is_instance_valid(res.target) and res.target != owner:
		res.target.expect_pass(res.aim_point, res.kind)
	_last_kick_msec = Time.get_ticks_msec()
	lockout = Tuning.player.kick_lockout
	touch_timer = lockout
	# Patear desequilibra levemente: pierde algo de velocidad.
	owner.locomotion.velocity *= 0.9
	kicked.emit(action, res)

# --- Pies animados (esqueleto vivo) ------------------------------------------------

## Distancia (m) maxima entre la punta del pie animado y el centro de la pelota para que el pie la toque.
const FOOT_CONTACT := 0.28
## Altura (m) maxima de la punta del pie para contar como toque raso.
const FOOT_MAX_Y := 0.20
## La pelota se deja esta distancia (m) por delante del alcance de la punta del pie (radio de la pelota y holgura).
const FOOT_BALL_LEAD := 0.10
## Segundos maximos sin pie en la pelota antes de tocarla igual si se escapa junto al cuerpo.
const FOOT_WAIT_MAX := 0.30
## true cuando el esqueleto del jugador se esta animando de verdad (en partido, no en pruebas headless).
var feet_live: bool = false
var _toe_ids: Array[int] = []
var _leg_bone: int = -1
static var _headless: bool = DisplayServer.get_name() == "headless"
var _toe_sk_prev: Vector3 = Vector3.ZERO
var _toe_now: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _toe_prev: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _toe_vel: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_reach: float = 0.45
var _reach_peak: float = 0.45
var _foot_wait: float = 0.0
## Empieza como "quieto": los pies solo se consideran vivos cuando se ve moverse el esqueleto.
var _still_frames: int = 30
var _dt: float = 1.0 / 60.0
## Toques de conduccion dados con el pie animado y distancia pie-pelota del ultimo (diagnostico y pruebas).
var foot_touches: int = 0
var last_touch_foot_distance: float = -1.0

func get_dt() -> float:
	return _dt

## Lee las puntas de los pies del esqueleto animado. Si no se mueven (headless, maniqui) feet_live queda en false y la
## conduccion usa la cadencia de la marcha.
func _sample_feet(dt: float) -> void:
	_dt = dt
	var v: FootballerVisual = owner.visual
	if v == null or v.is_placeholder or v.skeleton == null:
		feet_live = false
		return
	var sk: Skeleton3D = v.skeleton
	if _toe_ids.is_empty():
		_toe_ids = [sk.find_bone("mixamorig_LeftToeBase"), sk.find_bone("mixamorig_RightToeBase")]
		_leg_bone = sk.find_bone("mixamorig_LeftUpLeg")
		if _toe_ids[0] < 0 or _toe_ids[1] < 0:
			_toe_ids = []
			return
	# El esqueleto esta vivo si la punta del pie se mueve en el espacio del propio esqueleto (solo la animacion la mueve:
	# ni la inclinacion del cuerpo ni el desplazamiento del jugador). En headless la pose global no se recalcula.
	var toe_sk: Vector3 = sk.get_bone_global_pose(_toe_ids[0]).origin
	var moved: bool = _toe_sk_prev != Vector3.ZERO and toe_sk.distance_to(_toe_sk_prev) > 0.001
	_toe_sk_prev = toe_sk
	var body_v := Vector3(owner.locomotion.velocity.x, 0.0, owner.locomotion.velocity.z)
	var fwd: Vector3 = owner.locomotion.forward()
	var best_fwd: float = -INF
	for i in 2:
		_toe_prev[i] = _toe_now[i]
		_toe_now[i] = sk.global_transform * sk.get_bone_global_pose(_toe_ids[i]).origin
		_toe_vel[i] = (_toe_now[i] - _toe_prev[i]) / maxf(dt, 0.001) - body_v
		var rel: Vector3 = _toe_now[i] - owner.global_position
		if _toe_now[i].y < FOOT_MAX_Y:
			best_fwd = maxf(best_fwd, rel.dot(fwd))
	_still_frames = 0 if moved else _still_frames + 1
	# El esqueleto se considera vivo si las puntas se movieron respecto al cuerpo en el ultimo medio segundo.
	# En headless (servidor, pruebas sin render) la pose no es fiable: se usa la cadencia de la marcha.
	feet_live = foot_sync_enabled and _still_frames < 30 and not _headless

	# Alcance de la zancada: maximo reciente de la punta del pie apoyada/baja por delante del cuerpo.
	_reach_peak = maxf(_reach_peak - 0.5 * dt, best_fwd if best_fwd > -INF else 0.0)
	_foot_reach = clampf(_reach_peak, 0.2, 0.9)

## Pie (0 izquierdo, 1 derecho) que puede tocar la pelota ahora: punta baja, a FOOT_CONTACT de la pelota, por detras de
## ella y yendo hacia delante (o casi quieta) respecto al cuerpo. -1 si ninguno.
func _foot_strike(b: Ball, mode: StringName, close_in: bool = false) -> int:
	var fwd: Vector3 = owner.locomotion.forward()
	var push_dir: Vector3 = fwd if (mode == &"carry" or mode == &"setup") else KickModel.flat(b.global_position - owner.global_position).normalized()
	var radius: float = FOOT_CONTACT * (1.4 if mode == &"settle" or mode == &"lateral" or mode == &"redirect" or close_in else 1.0)
	if close_in:
		# Pelota pegada al cuerpo: la toca el pie que este encima, sin exigir que vaya hacia delante (la empuja o la arrastra).
		mode = &"near"
	var best: int = -1
	var best_d: float = radius
	for i in 2:
		var toe: Vector3 = _toe_now[i]
		if toe.y > FOOT_MAX_Y:
			continue
		var d: float = toe.distance_to(b.global_position)
		if d > best_d:
			continue
		if (mode == &"carry" or mode == &"setup") and ((b.global_position - toe).dot(push_dir) < -0.06 or _toe_vel[i].dot(fwd) < -0.6):
			continue
		best_d = d
		best = i
	return best

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
	# Con pies vivos se toca en cada apoyo hasta la carrera (el pie que llega a la pelota) y cada dos a sprint.
	var every: float = (1.0 if ratio < 0.6 else 2.0) if feet_live else (1.0 if ratio < 0.2 else 2.0)
	return clampf(step * every, 0.18 if feet_live else 0.2, 0.6)

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
	var strike: int = -1
	if feet_live:
		# Con el esqueleto animado el toque lo da un PIE: solo cuando una punta de pie baja llega a la pelota. Si no hay
		# pie en la pelota se espera (el jugador alcanza su propio toque largo); la pelota que se escapa junto al cuerpo
		# se toca igual tras FOOT_WAIT_MAX para no perderla.
		# Media vuelta (giro de mas de 100 grados) con la pelota aun al alcance: el toque de giro no espera a la cadencia
		# de la carrera; si esperase, la pelota (lanzada por el ultimo toque) se iria fuera del alcance.
		var reversal: bool = mode == &"redirect" and turn_angle > 100.0 and dist < reach * 1.2 and touch_timer < interval * 0.9 - REVERSAL_TOUCH_GAP
		if touch_timer > interval * 0.45 and not reversal:
			return
		var close_in: bool = off.dot(fwd) < _foot_reach * 0.9 and (mode == &"carry" or mode == &"setup")
		strike = _foot_strike(b, mode, close_in)
		if strike < 0:
			_foot_wait += get_dt()
			# En un cambio de rumbo no se puede esperar a la zancada: el toque llega antes (el pie se estira a la pelota).
			# Si el cuerpo alcanza a la pelota (queda pegada o por detras de la punta del pie) tampoco: el jugador la pisaria.
			var overrun: bool = off.dot(fwd) < _foot_reach * 0.9 and (mode == &"carry" or mode == &"setup")
			var wait_max: float = 0.08 if (mode == &"redirect" or mode == &"lateral" or overrun) else FOOT_WAIT_MAX
			# Con un golpeo pedido (modo setup) el toque de preparacion no espera a la zancada: el jugador va a la pelota.
			var setup_reach: bool = mode == &"setup" and dist < reach * 1.5
			if not (((urgent or overrun or dist > _planned_gap + 0.25) and dist < reach * 1.3) or setup_reach) or _foot_wait <= wait_max:
				return
	elif touch_timer > 0.0 and not (urgent and touch_timer < interval * 0.8) and not (mode == &"redirect" and turn_angle > 100.0 and touch_timer < interval * 0.9 - REVERSAL_TOUCH_GAP):
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
	# La pelota quedo detras: hay que girar o recuperarla (carry_steer lleva al jugador a ella), salvo que el toque sea
	# justo para traerla de vuelta. "Detras" respecto a hacia donde se quiere ir: con el joystick hacia atras, una pelota
	# a la espalda esta delante del nuevo rumbo y se puede arrastrar hacia alli.
	var ref_dir: Vector3 = desired_dir.normalized() if has_dir else fwd
	if off.dot(ref_dir) < -0.3 and off.dot(fwd) < -0.3 and (mode == &"carry" or mode == &"setup") and lateral_off < 0.45:
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

	# Con pies vivos la pelota se deja donde llega la punta del pie en su zancada (mas un radio): asi el siguiente toque
	# lo da el pie de verdad. Sin esqueleto animado, la ley de distancias de PlayerTuning.
	if feet_live and (mode == &"carry" or mode == &"setup" or mode == &"redirect"):
		var foot_gap: float = _foot_reach + FOOT_BALL_LEAD
		if mode == &"setup":
			foot_gap = _foot_reach * 0.8 + FOOT_BALL_LEAD
		var long_touch: float = gap - carry_gap(carry_speed, skill)
		gap = clampf(foot_gap + maxf(long_touch, 0.0) * 0.5, t.carry_gap_stand, reach * 1.2)
	# Arrancada: con SPRINT pedido y lejos de la velocidad punta, el toque se alarga (se empuja la pelota al espacio para
	# acelerar detras de ella, como un toque de arrancada); al llegar a la punta vuelve el control cercano.
	# Solo en linea recta (en un giro la velocidad cae y alargar el toque perdia la pelota: 6 de 20 giros a sprint) y menos
	# con mejor control.
	if mode == &"carry" and loco.sprinting and turn_angle < 15.0 and absf(loco.turn_rate) < 0.6:
		var missing: float = loco.max_sprint_speed() - loco.speed
		gap += clampf(missing * ACCEL_TOUCH_PER_MS, 0.0, ACCEL_TOUCH_MAX) * lerpf(1.0, 0.5, skill)
	gap = minf(gap, reach * 1.35 - 0.05)
	_planned_gap = gap
	_foot_wait = 0.0
	if strike >= 0:
		foot_touches += 1
		last_touch_foot_distance = _toe_now[strike].distance_to(b.global_position)

	# Posicion del jugador cuando la pelota llegue a destino: promedio entre su velocidad actual y la que tendra.
	var p_pos: Vector3 = KickModel.flat(owner.global_position)
	var b_pos: Vector3 = KickModel.flat(b.global_position)
	var future_player: Vector3
	if turn_angle > 100.0 and mode == &"redirect":
		# Media vuelta (arrastre): el cuerpo frena hasta pararse y sale hacia el rumbo nuevo; la pelota se lleva desde
		# donde se detiene el cuerpo, hacia el rumbo pedido (no solo se frena).
		var brake_a: float = maxf(t.brake * owner.attributes.factor("acceleration", 0.16), 1.0)
		var t_stop: float = loco.speed / brake_a
		travel = clampf(t_stop + 0.25, 0.3, 0.8)
		future_player = p_pos + body_v * (t_stop * 0.5) + touch_dir * carry_speed * maxf(travel - t_stop, 0.0) * 0.5
	elif turn_angle > 55.0 and mode != &"settle":
		# Giro cerrado: el cuerpo frena (sigue un instante su rumbo) y despues acelera hacia el nuevo.
		var t_align: float = minf(0.25 * turn_angle / 90.0, travel)
		future_player = p_pos + body_v * (t_align * 0.5) + touch_dir * carry_speed * maxf(travel - t_align, 0.0) * 0.5
	else:
		# En curva el cuerpo sigue girando hasta el proximo toque: la pelota se coloca sobre el arco que va a recorrer
		# (rumbo y velocidad girados a mitad del giro esperado), no en la tangente; si no, se va al exterior de la curva
		# y el pie ya no la alcanza en el toque siguiente.
		var bend: float = clampf(loco.turn_rate * travel * 0.8, -0.6, 0.6) if (mode == &"carry" and absf(loco.turn_rate) < 2.5) else 0.0
		if absf(bend) > 0.02:
			touch_dir = touch_dir.rotated(Vector3.UP, bend)
			future_player = p_pos + (body_v.rotated(Vector3.UP, bend) + touch_dir * carry_speed) * 0.5 * travel
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

## Recuperar la pelota propia que se queda atras o al costado en un giro: en vez de correr hacia donde apunta el
## joystick dejando la pelota (fallo visto en las pruebas y en el video: giro brusco hacia el arco y la pelota sigue
## sola hasta la banda), el jugador va a un punto JUSTO DETRAS de la pelota respecto al rumbo pedido y desde ahi la
## toca hacia alli. Devuelve la direccion de carrera a usar (cero = seguir el joystick).
func carry_steer(desired_dir: Vector3) -> Vector3:
	if desired_dir.length_squared() < 0.01 or _kick_action != &"":
		return Vector3.ZERO
	var b: Ball = ball()
	if b == null or b.is_held() or b.global_position.y > 0.6 or not is_dribbling():
		return Vector3.ZERO
	var off: Vector3 = ball_offset()
	var dist: float = off.length()
	# Al alcance del toque no hace falta ir: el toque de giro (redirect) la lleva al rumbo nuevo.
	if dist > 2.5 or dist < touch_reach() * 1.1:
		return Vector3.ZERO
	var want: Vector3 = desired_dir.normalized()
	# Pelota por delante en el rumbo pedido y algo centrada: conduccion normal.
	var ahead: float = off.dot(want)
	var side: float = absf(off.dot(Vector3(-want.z, 0.0, want.x)))
	if ahead > 0.15 and side < 0.55:
		return Vector3.ZERO
	var approach: Vector3 = owner.global_position + off - want * 0.35 * Tuning.player.touch_reach
	var to_a: Vector3 = KickModel.flat(approach - owner.global_position)
	if to_a.length() < 0.15:
		return Vector3.ZERO
	return to_a.normalized()

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
	if feet_live:
		# Con pies vivos el control lo hace el pie (o el cuerpo) cuando la pelota LLEGA a el, no a un metro: se espera a
		# que una punta de pie este en la pelota o a que la pelota vaya a alcanzar el cuerpo en el proximo paso.
		var toe_d: float = minf(_toe_now[0].distance_to(b.global_position), _toe_now[1].distance_to(b.global_position))
		var next_d: float = dist - closing * _dt * 1.1
		if toe_d > FOOT_CONTACT + 0.06 and next_d > 0.48:
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
	if b == null or owner.ctx.ball_locked_for(owner):
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
