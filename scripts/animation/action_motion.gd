class_name ActionMotion
extends RefCounted
## Movimiento de raiz de una accion con clip del pack. Los clips guardan el desplazamiento de la raiz APARTE de la
## cadera (metadato root_path: acumulado a 30 Hz, metros de juego, (adelante, derecha)); el juego mueve al
## personaje siguiendo esa curva mientras dura la accion, y solo entonces: la locomocion queda en pausa.

var clip: StringName = &""
var speed: float = 1.0
## Tiempo (s) de reproduccion del clip (ya incluye el desfase de inicio).
var t: float = 0.0
var length: float = 0.0
## Si es > 0 la accion se corta a esos segundos de reproduccion (mundo real, no del clip).
var cut_after: float = -1.0
var elapsed: float = 0.0
var active: bool = false
var _path: PackedVector2Array = PackedVector2Array()

func start(id: StringName, play_speed: float = 1.0, start_at: float = 0.0, cut: float = -1.0) -> bool:
	var a: Animation = PackLibrary.clip(id)
	if a == null:
		return false
	clip = id
	speed = maxf(play_speed, 0.05)
	t = start_at
	length = a.length
	cut_after = cut
	elapsed = 0.0
	_path = PackLibrary.meta(id).get("root_path", PackedVector2Array())
	active = true
	return true

## Avanza dt segundos y devuelve la velocidad de raiz (adelante, derecha) en m/s del mundo. Termina solo.
func step(dt: float) -> Vector2:
	if not active:
		return Vector2.ZERO
	var v: Vector2 = sample_velocity(t) * speed
	t += dt * speed
	elapsed += dt
	if t >= length or (cut_after > 0.0 and elapsed >= cut_after):
		active = false
	return v

## Velocidad de raiz (adelante, derecha) del clip en el instante t del clip (a velocidad 1).
func sample_velocity(at: float) -> Vector2:
	if _path.size() < 2:
		return Vector2.ZERO
	var f: float = clampf(at * 30.0, 0.0, float(_path.size() - 2))
	var i: int = int(f)
	return (_path[i + 1] - _path[i]) * 30.0

func stop() -> void:
	active = false

## Desplazamiento acumulado (adelante, derecha) entre dos instantes del clip.
static func offset_between(id: StringName, t0: float, t1: float) -> Vector2:
	var path: PackedVector2Array = PackLibrary.meta(id).get("root_path", PackedVector2Array())
	if path.size() < 2:
		return Vector2.ZERO
	return _at(path, t1) - _at(path, t0)

static func _at(path: PackedVector2Array, tt: float) -> Vector2:
	var f: float = clampf(tt * 30.0, 0.0, float(path.size() - 1))
	var i: int = mini(int(f), path.size() - 2)
	return path[i].lerp(path[i + 1], f - float(i))
