class_name MatchCamera
extends Camera3D
## Camara elevada estilo transmision deportiva. Sigue una mezcla entre el jugador controlado
## y la pelota con amortiguacion exponencial (independiente de los FPS), ajusta el encuadre
## segun la separacion entre ambos y nunca entra en el volumen de las paredes.
## Mantiene un yaw fijo: el joystick siempre es relativo a la pantalla.

@export var pitch_deg: float = 55.0
@export var base_distance: float = 20.0
@export var max_distance: float = 30.0
## Semivida del suavizado de posicion (s). Mayor = camara mas lenta.
@export var follow_halflife: float = 0.22
@export var zoom_halflife: float = 0.55
@export var ball_lead_time: float = 0.28
@export var focus_weight_with_ball: float = 0.4
@export var focus_weight_without_ball: float = 0.72

var ball: Node3D = null
var focus_actor: Node3D = null
var pitch_config: PitchConfig = null

var _focus: Vector3 = Vector3.ZERO
var _distance: float = 20.0
var _initialized: bool = false

func _ready() -> void:
	fov = 42.0
	near = 0.5
	far = 140.0
	keep_aspect = Camera3D.KEEP_HEIGHT
	current = true
	if pitch_config == null:
		pitch_config = Tuning.pitch
	_distance = base_distance

func setup(ball_node: Node3D, actor: Node3D, cfg: PitchConfig = null) -> void:
	ball = ball_node
	focus_actor = actor
	if cfg != null:
		pitch_config = cfg
	snap_to_target()

func set_focus_actor(actor: Node3D) -> void:
	focus_actor = actor

func snap_to_target() -> void:
	_focus = _target_focus()
	_distance = _target_distance()
	_apply_transform()
	_initialized = true

func _process(delta: float) -> void:
	if ball == null:
		return
	if not _initialized:
		snap_to_target()
		return
	var target: Vector3 = _target_focus()
	_focus = _damp_vec3(_focus, target, follow_halflife, delta)
	_distance = _damp_float(_distance, _target_distance(), zoom_halflife, delta)
	_apply_transform()

func _target_focus() -> Vector3:
	var ball_pos: Vector3 = Vector3.ZERO
	var ball_vel: Vector3 = Vector3.ZERO
	if ball != null:
		ball_pos = ball.global_position
		if ball is RigidBody3D:
			ball_vel = (ball as RigidBody3D).linear_velocity
	var lead_ball: Vector3 = ball_pos + Vector3(ball_vel.x, 0.0, ball_vel.z) * ball_lead_time
	var f: Vector3 = lead_ball
	if focus_actor != null and is_instance_valid(focus_actor):
		var a: Vector3 = focus_actor.global_position
		var near_ball: bool = a.distance_to(ball_pos) < 3.0
		var w: float = focus_weight_with_ball if near_ball else focus_weight_without_ball
		f = a.lerp(lead_ball, w)
	f.y = 0.0
	# Limites: que los arcos sigan visibles y la camara no persiga hasta los extremos.
	var hl: float = pitch_config.half_length()
	var hw: float = pitch_config.half_width()
	f.x = clampf(f.x, -(hl - 8.0), hl - 8.0)
	f.z = clampf(f.z, -hw * 0.55, hw * 0.55)
	return f

func _target_distance() -> float:
	var sep: float = 0.0
	if focus_actor != null and is_instance_valid(focus_actor) and ball != null:
		var d: Vector3 = focus_actor.global_position - ball.global_position
		sep = Vector2(d.x, d.z).length()
	return clampf(base_distance + maxf(sep - 7.0, 0.0) * 0.55, base_distance, max_distance)

func _apply_transform() -> void:
	var p: float = deg_to_rad(pitch_deg)
	var offset := Vector3(0.0, sin(p), cos(p)) * _distance
	var pos: Vector3 = _focus + offset
	# Evitar atravesar paredes y luces: siempre por encima de la altura de las paredes.
	var min_y: float = pitch_config.wall_height + 2.0
	pos.y = maxf(pos.y, min_y)
	look_at_from_position(pos, _focus, Vector3.UP)

static func _damp_float(current_value: float, target: float, halflife: float, delta: float) -> float:
	var a: float = 1.0 - pow(0.5, delta / maxf(halflife, 0.0001))
	return lerpf(current_value, target, a)

static func _damp_vec3(current_value: Vector3, target: Vector3, halflife: float, delta: float) -> Vector3:
	var a: float = 1.0 - pow(0.5, delta / maxf(halflife, 0.0001))
	return current_value.lerp(target, a)

## Convierte un vector 2D de pantalla (x derecha, y abajo) en direccion de mundo sobre el plano XZ.
func screen_to_world_dir(v: Vector2) -> Vector3:
	var basis_x: Vector3 = global_transform.basis.x
	var basis_z: Vector3 = global_transform.basis.z
	var right := Vector3(basis_x.x, 0.0, basis_x.z).normalized()
	var back := Vector3(basis_z.x, 0.0, basis_z.z).normalized()
	return (right * v.x + back * v.y)
