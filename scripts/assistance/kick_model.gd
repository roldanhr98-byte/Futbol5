class_name KickModel
extends RefCounted
## Utilidades compartidas por pases y tiros: geometria en el plano XZ, error por atributos,
## equilibrio, pie de golpeo. La precision NUNCA es perfecta: depende de distancia, potencia,
## equilibrio, orientacion del cuerpo y atributos.

const G: float = 9.81

## Resultado de calcular un golpe. No toca la pelota: quien lo ejecuta decide.
class KickResult:
	extends RefCounted
	var velocity: Vector3 = Vector3.ZERO
	var spin: Vector3 = Vector3.ZERO
	var kind: StringName = &"pass"
	var target: Footballer = null
	var aim_point: Vector3 = Vector3.ZERO
	var intended_dir: Vector3 = Vector3.ZERO
	var final_dir: Vector3 = Vector3.ZERO
	var error_deg: float = 0.0
	var sigma_deg: float = 0.0
	var assisted_correction_deg: float = 0.0
	var weak_foot: bool = false
	var charge: float = 0.0
	var on_target: bool = false

static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

static func angle_between_deg(a: Vector3, b: Vector3) -> float:
	var fa: Vector3 = flat(a)
	var fb: Vector3 = flat(b)
	if fa.length_squared() < 0.0001 or fb.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(absf(fa.signed_angle_to(fb, Vector3.UP)))

static func signed_angle_deg(from_dir: Vector3, to_dir: Vector3) -> float:
	var fa: Vector3 = flat(from_dir)
	var fb: Vector3 = flat(to_dir)
	if fa.length_squared() < 0.0001 or fb.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(fa.signed_angle_to(fb, Vector3.UP))

## Gira "dir" hacia "target_dir" como maximo max_deg grados (plano XZ).
static func rotate_toward(dir: Vector3, target_dir: Vector3, max_deg: float) -> Vector3:
	var diff: float = signed_angle_deg(dir, target_dir)
	var applied: float = clampf(diff, -max_deg, max_deg)
	return flat(dir).normalized().rotated(Vector3.UP, deg_to_rad(applied))

static func gaussian_clipped(rng: RandomNumberGenerator, sigma: float, clip: float = 2.2) -> float:
	return clampf(rng.randfn(0.0, sigma), -sigma * clip, sigma * clip)

## 1.0 = totalmente equilibrado. Baja con giros bruscos, frenadas y cansancio.
static func balance_state(f: Footballer) -> float:
	var loc: Locomotion = f.locomotion
	var unstable: float = clampf(absf(loc.turn_rate) / 7.0, 0.0, 0.45)
	if loc.braking:
		unstable += 0.15
	if loc.exhausted:
		unstable += 0.1
	unstable *= 1.0 - f.attributes.norm("balance") * 0.5
	return clampf(1.0 - unstable, 0.35, 1.0)

## Proporcion de desalineacion entre el cuerpo y la direccion del golpe (0..1).
static func misalignment(f: Footballer, dir: Vector3) -> float:
	return clampf(angle_between_deg(f.locomotion.forward(), dir) / 180.0, 0.0, 1.0)

## True si el balon queda del lado del pie no dominante.
static func is_weak_foot(f: Footballer, ball_pos: Vector3) -> bool:
	var rel: Vector3 = flat(ball_pos - f.global_position)
	var side: float = rel.dot(f.locomotion.right())
	var uses_right: bool = side >= 0.0
	return uses_right != f.dominant_right

## Penalizacion de la pierna debil segun el atributo (1.0 = sin penalizacion).
static func weak_foot_error_mult(f: Footballer) -> float:
	return lerpf(1.9, 1.08, f.attributes.norm("weak_foot"))

static func weak_foot_power_mult(f: Footballer) -> float:
	return lerpf(0.84, 0.98, f.attributes.norm("weak_foot"))

## Velocidad inicial (m/s) para recorrer d metros por el suelo y llegar con "arrival" m/s.
## Modelo exacto de la pelota: desaceleracion = rodadura + k v^2 (arrastre cuadratico), donde
## k = 0.5 rho Cd A / m. Integrando v dv / (a + k v^2) se obtiene v0^2 = ((a + k va^2) e^(2kd) - a) / k.
static func ground_speed_for_distance(d: float, arrival: float) -> float:
	var bt: BallTuning = Tuning.ball
	var k: float = 0.5 * bt.air_density * bt.drag_coefficient * PI * bt.radius * bt.radius / bt.mass
	var a: float = bt.rolling_decel
	var v0_sq: float = ((a + k * arrival * arrival) * exp(2.0 * k * maxf(d, 0.0)) - a) / k
	return sqrt(maxf(v0_sq, arrival * arrival))

## Velocidad de lanzamiento para un pase elevado que cubre d metros con el angulo dado (grados).
static func lob_speed_for_distance(d: float, angle_deg: float) -> float:
	var s2: float = sin(deg_to_rad(angle_deg * 2.0))
	return sqrt(maxf(d, 0.5) * G / maxf(s2, 0.05)) * 1.1
