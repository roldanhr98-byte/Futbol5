class_name AnimDB
extends RefCounted
## Base de datos de animaciones del modo 4 (assets/animations/animdb.json, como animdb.adb de UCS; la genera
## tools/json_anim/make_animdb.py con nuestro banco y el animdb.adb de UCS). Por clip del banco (indice NNNN de los JSON):
## accion, sistema que lo usa, si esta conectado, y los datos de UCS: cuadro y pie del toque de pelota, destino de la pelota,
## giro (+ = izquierda) y la ventana del joystick (grados respecto del frente) en la que UCS elige el clip. El indice
## «acciones» lista TODOS los clips de cada accion. Los espejos («_mirror») usan el registro del clip con el lado cambiado.

const PATH := "res://assets/animations/animdb.json"
const NO_WINDOW := Vector2(-INF, INF)

static var _db: Dictionary = {}
static var _loaded: bool = false

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(d) == TYPE_DICTIONARY:
		_db = d

static func available() -> bool:
	_ensure()
	return not _db.is_empty()

## Indice NNNN del clip (los ids de la libreria terminan en «_NNNN» o «_NNNN_mirror»).
static func index_of(id: StringName) -> String:
	var s: String = String(id).trim_suffix("_mirror")
	var k: int = s.rfind("_")
	var tail: String = s.substr(k + 1) if k >= 0 else s
	return tail if tail.length() == 4 and tail.is_valid_int() else ""

## Datos de UCS del clip ya con el lado del espejo aplicado; {} si no esta.
static func ucs(id: StringName) -> Dictionary:
	_ensure()
	var key: String = index_of(id)
	if key == "" or not (_db.get("clips", {}) as Dictionary).has(key):
		return {}
	var u: Dictionary = ((_db["clips"] as Dictionary)[key] as Dictionary).get("ucs", {})
	if u.is_empty() or not String(id).ends_with("_mirror"):
		return u
	var m: Dictionary = u.duplicate(true)
	var w: Array = u.get("ventana_joystick", [0, 0])
	m["ventana_joystick"] = [-float(w[1]), -float(w[0])]
	m["giro_sector"] = -float(u.get("giro_sector", 0))
	m["giro_medido"] = -float(u.get("giro_medido", 0))
	var dst: Array = u.get("destino_m", [0.0, 0.0])
	m["destino_m"] = [float(dst[0]), -float(dst[1])]
	var foot: String = String(u.get("toque_pie", ""))
	m["toque_pie"] = "der" if foot == "izq" else ("izq" if foot == "der" else foot)
	return m

## Ventana del joystick (grados, + = izquierda) en la que UCS elige el clip; sin datos, sin limite.
static func joystick_window(id: StringName) -> Vector2:
	var u: Dictionary = ucs(id)
	var w: Array = u.get("ventana_joystick", [])
	if w.size() < 2 or (float(w[0]) == 0.0 and float(w[1]) == 0.0):
		return NO_WINDOW
	return Vector2(float(w[0]), float(w[1]))

## Todos los clips de una accion (rol), conectados o no.
static func clips_for(action: String) -> Array:
	_ensure()
	return (_db.get("acciones", {}) as Dictionary).get(action, [])

static func summary() -> Dictionary:
	_ensure()
	return _db.get("resumen", {})
