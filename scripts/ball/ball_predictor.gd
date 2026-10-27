class_name BallPredictor
extends RefCounted
## Prediccion de la trayectoria de la pelota con el mismo modelo que Ball: gravedad, arrastre cuadratico, rebote
## contra el piso y rodadura. Solo LEE (no mueve nada). Lo usan el arquero y la IA para anticiparse.

const GRAVITY := 9.81
const SUBSTEPS := 4
## Calibracion contra la pelota real (Jolt, medida con la pelota rodando a 9 y 15 m/s): el arrastre efectivo es ~0.5 de la
## formula cuadratica y la rodadura efectiva ~1.16 de BallTuning.rolling_decel. Sin esto el predictor se queda corto ~4 %.
const DRAG_SCALE := 0.5
const ROLL_SCALE := 1.16

## Posiciones cada `step` segundos desde ahora (indice 0 = posicion actual) hasta `horizon` segundos.
static func trajectory(pos: Vector3, vel: Vector3, horizon: float, step: float = 1.0 / 30.0) -> PackedVector3Array:
	var bt: BallTuning = Tuning.ball
	var out := PackedVector3Array()
	out.append(pos)
	var p: Vector3 = pos
	var v: Vector3 = vel
	var dt: float = step / float(SUBSTEPS)
	var area: float = PI * bt.radius * bt.radius
	var n: int = int(horizon / step)
	for i in n:
		for s in SUBSTEPS:
			v.y -= GRAVITY * dt
			var spd: float = v.length()
			if spd > 0.01:
				var dv: float = minf(DRAG_SCALE * 0.5 * bt.air_density * bt.drag_coefficient * area * spd * spd / bt.mass * dt, spd)
				v -= v / spd * dv
			p += v * dt
			if p.y <= bt.radius:
				p.y = bt.radius
				if v.y < -1.0:
					v.y = -v.y * bt.bounce
					v.x *= 0.93
					v.z *= 0.93
				else:
					v.y = 0.0
					var hs: float = Vector2(v.x, v.z).length()
					if hs > 0.0001:
						var k: float = maxf(hs - bt.rolling_decel * ROLL_SCALE * dt, 0.0) / hs
						v.x *= k
						v.z *= k
		out.append(p)
	return out

## Primer indice de la trayectoria donde la coordenada X cruza x_plane en el sentido de `dir_sign` (+1: X creciente). -1 si no.
static func crossing_x(traj: PackedVector3Array, x_plane: float, dir_sign: float) -> int:
	for i in range(1, traj.size()):
		if (traj[i - 1].x - x_plane) * dir_sign < 0.0 and (traj[i].x - x_plane) * dir_sign >= 0.0:
			return i
	return -1
