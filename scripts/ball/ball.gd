class_name Ball
extends RigidBody3D
## Pelota independiente con fisica 3D (RigidBody3D / Jolt).
##
## Reglas del diseno:
##  - Nunca se teletransporta al pie del jugador ni se anula su velocidad para simular control.
##  - Los jugadores interactuan solo mediante impulsos (kick) en el instante del contacto.
##  - Resistencia del aire, efecto Magnus y rodadura se calculan en _integrate_forces.
##  - Excepcion explicita: el arquero puede sostenerla (hold/release) mientras la tiene en las manos.

signal touched(actor: Node)
signal hit_goal_frame(position: Vector3, speed: float)
signal floor_bounce(position: Vector3, speed: float)
signal released(by: Node)

const LAYER_WORLD := 1
const LAYER_BALL := 2
const LAYER_PLAYERS := 4
const LAYER_KEEPERS := 8
const LAYER_GOAL_FRAME := 16

var tuning: BallTuning
var radius: float = 0.1

## Ultimo actor que toco la pelota y el equipo al que pertenece (-1 si ninguno).
var last_toucher: Node = null
var last_touch_team: int = -1
var previous_toucher: Node = null
var previous_touch_team: int = -1
var last_touch_msec: int = 0

## Quien la sostiene ahora mismo (solo arquero).
var holder: Node = null
var _hold_anchor: Node3D = null

## Amortiguacion extra mientras esta dentro de la red del arco.
var net_damping: float = 0.0
var _net_volumes: int = 0

var _grounded: bool = false
var _pending_teleport: bool = false
var _teleport_pos: Vector3 = Vector3.ZERO
var _teleport_vel: Vector3 = Vector3.ZERO
var _prev_vy: float = 0.0
var _visual: MeshInstance3D = null

func _ready() -> void:
	add_to_group("ball")
	tuning = Tuning.ball
	_build()
	apply_tuning()

func _build() -> void:
	collision_layer = LAYER_BALL
	collision_mask = LAYER_WORLD | LAYER_PLAYERS | LAYER_KEEPERS | LAYER_GOAL_FRAME
	contact_monitor = true
	max_contacts_reported = 6
	continuous_cd = true
	can_sleep = false
	custom_integrator = false
	if get_node_or_null("CollisionShape3D") == null:
		var cs := CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		cs.shape = SphereShape3D.new()
		add_child(cs)
	if get_node_or_null("Visual") == null:
		_visual = MeshInstance3D.new()
		_visual.name = "Visual"
		var sphere := SphereMesh.new()
		sphere.radial_segments = 20
		sphere.rings = 10
		_visual.mesh = sphere
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/ball/ball.gdshader")
		_visual.material_override = mat
		_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(_visual)
	else:
		_visual = get_node("Visual")
	body_entered.connect(_on_body_entered)

## Aplica los parametros de BallTuning (se puede llamar en caliente desde el laboratorio).
func apply_tuning() -> void:
	radius = tuning.radius
	mass = tuning.mass
	# REPLACE: ignora el amortiguamiento por defecto del proyecto (que se SUMARIA y frenaria de mas);
	# la resistencia del aire y la rodadura se modelan explicitamente en _integrate_forces.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = tuning.angular_damp
	linear_damp = 0.0
	var pm := PhysicsMaterial.new()
	pm.bounce = tuning.bounce
	pm.friction = tuning.friction
	physics_material_override = pm
	# Inercia de una esfera hueca (balon): 2/3 m r^2. Coherente con rolling_spin() y kick().
	inertia = Vector3.ONE * ((2.0 / 3.0) * mass * radius * radius)
	var shape := (get_node("CollisionShape3D") as CollisionShape3D).shape as SphereShape3D
	shape.radius = radius
	if _visual != null:
		var sphere := _visual.mesh as SphereMesh
		sphere.radius = radius * tuning.visual_scale
		sphere.height = radius * 2.0 * tuning.visual_scale

# --- API publica -----------------------------------------------------------

## Golpe: aplica el impulso necesario para que la pelota salga con la velocidad y el giro dados.
func kick(target_velocity: Vector3, spin: Vector3 = Vector3.ZERO, kicker: Node = null) -> void:
	if holder != null:
		release(kicker)
	var dv: Vector3 = target_velocity - linear_velocity
	apply_central_impulse(dv * mass)
	var inertia: float = (2.0 / 3.0) * mass * radius * radius
	apply_torque_impulse((spin - angular_velocity) * inertia)
	register_touch(kicker)

## Giro de rodadura sin deslizamiento para una velocidad horizontal dada (w = up x v / r).
## Un golpe raso real transmite este giro; sin el, la pelota resbala y pierde ~30 % de velocidad.
func rolling_spin(velocity: Vector3) -> Vector3:
	return Vector3.UP.cross(Vector3(velocity.x, 0.0, velocity.z)) / radius

## Impulso arbitrario (desvios, choques) sin cambiar el ultimo toque salvo que se indique actor.
func push(impulse: Vector3, actor: Node = null) -> void:
	apply_central_impulse(impulse)
	if actor != null:
		register_touch(actor)

func register_touch(actor: Node) -> void:
	if actor == null:
		return
	if actor != last_toucher:
		previous_toucher = last_toucher
		previous_touch_team = last_touch_team
	last_toucher = actor
	var team_value: Variant = actor.get("team")
	last_touch_team = int(team_value) if team_value != null else -1
	last_touch_msec = Time.get_ticks_msec()
	touched.emit(actor)

## Teletransporte controlado (saques de centro, reinicios). No se usa durante el juego normal.
func reset_at(pos: Vector3, vel: Vector3 = Vector3.ZERO) -> void:
	if holder != null:
		release(null)
	_pending_teleport = true
	_teleport_pos = pos
	_teleport_vel = vel
	last_toucher = null
	last_touch_team = -1
	previous_toucher = null
	previous_touch_team = -1

func hold(anchor: Node3D, by: Node) -> void:
	holder = by
	_hold_anchor = anchor
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	register_touch(by)

func release(by: Node, velocity: Vector3 = Vector3.ZERO) -> void:
	if holder == null:
		return
	holder = null
	_hold_anchor = null
	freeze = false
	linear_velocity = velocity
	released.emit(by)

func is_held() -> bool:
	return holder != null

func is_grounded() -> bool:
	return _grounded

func speed() -> float:
	return linear_velocity.length()

func ground_speed() -> float:
	return Vector2(linear_velocity.x, linear_velocity.z).length()

func enter_net() -> void:
	_net_volumes += 1
	net_damping = tuning.net_damping

func exit_net() -> void:
	_net_volumes = maxi(0, _net_volumes - 1)
	if _net_volumes == 0:
		net_damping = 0.0

func capture_state(tick: int = 0) -> BallState:
	var s := BallState.new()
	s.tick = tick
	s.position = global_position
	s.linear_velocity = linear_velocity
	s.angular_velocity = angular_velocity
	s.orientation = global_transform.basis.get_rotation_quaternion()
	var holder_id_value: Variant = holder.get("actor_id") if holder != null else null
	s.holder_id = int(holder_id_value) if holder_id_value != null else -1
	var toucher_id_value: Variant = last_toucher.get("actor_id") if last_toucher != null else null
	s.last_toucher_id = int(toucher_id_value) if toucher_id_value != null else -1
	return s

func apply_state(s: BallState) -> void:
	reset_at(s.position, s.linear_velocity)
	angular_velocity = s.angular_velocity

# --- Fisica ----------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if holder != null and _hold_anchor != null and is_instance_valid(_hold_anchor):
		global_position = _hold_anchor.global_position

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _pending_teleport:
		_pending_teleport = false
		state.transform = Transform3D(Basis.IDENTITY, _teleport_pos)
		state.linear_velocity = _teleport_vel
		state.angular_velocity = Vector3.ZERO
		return
	var dt: float = state.step
	var v: Vector3 = state.linear_velocity
	var w: Vector3 = state.angular_velocity

	_grounded = false
	var floor_contact: bool = false
	for i in state.get_contact_count():
		if state.get_contact_local_normal(i).y > 0.6:
			floor_contact = true
			break
	_grounded = floor_contact

	# Rebote contra el piso: se detecta por inversion del signo de la velocidad vertical.
	if floor_contact and _prev_vy < -1.0 and v.y > 0.0:
		floor_bounce.emit(state.transform.origin, absf(_prev_vy))
	_prev_vy = v.y

	# Resistencia aerodinamica cuadratica.
	var spd: float = v.length()
	if spd > 0.01:
		var area: float = PI * radius * radius
		var drag_force: float = 0.5 * tuning.air_density * tuning.drag_coefficient * area * spd * spd
		var dv: float = minf(drag_force / mass * dt, spd)
		v -= v / spd * dv

	# Efecto Magnus (solo en el aire).
	if not floor_contact and spd > 1.0:
		v += w.cross(v) * (tuning.magnus_k / mass) * dt

	# Rodadura sobre el piso: desacelera linealmente y arrastra el giro para no pelear con la friccion.
	if floor_contact and absf(v.y) < 0.6:
		var hv := Vector3(v.x, 0.0, v.z)
		var hs: float = hv.length()
		if hs > 0.0001:
			var dec: float = tuning.rolling_decel * dt
			var new_hs: float = maxf(hs - dec, 0.0)
			var ratio: float = new_hs / hs
			hv *= ratio
			v.x = hv.x
			v.z = hv.z
			w.x *= ratio
			w.z *= ratio
		w.y = move_toward(w.y, 0.0, tuning.spin_decel_ground * dt)
		if hs < 0.05:
			w = w.move_toward(Vector3.ZERO, tuning.spin_decel_ground * dt)

	# Red del arco: frena la pelota de forma agresiva.
	if net_damping > 0.0:
		var k: float = exp(-net_damping * dt)
		v *= k
		w *= k

	if v.length() > tuning.max_speed:
		v = v.normalized() * tuning.max_speed
	if w.length() > tuning.max_spin:
		w = w.normalized() * tuning.max_spin

	state.linear_velocity = v
	state.angular_velocity = w

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("goal_frame"):
		hit_goal_frame.emit(global_position, linear_velocity.length())
	elif body.is_in_group("net_surface"):
		# La red cede: absorbe la mayor parte de la energia del impacto (la pelota cae en la red).
		linear_velocity *= tuning.net_restitution
		angular_velocity *= 0.3
