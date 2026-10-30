class_name JsonCatalog
extends RefCounted
## Tablas del modo 4 (Json): modelo, escalones de la marcha (sin y con pelota), mezcla direccional y candidatos de
## patada por rol. Los clips salen de la libreria json_clips.res (ver PackLibrary.json_mode); aqui solo se dice cual va
## en cada escalon. Cada clip de marcha es UN ciclo que empieza en un apoyo del pie izquierdo, asi que todos se reproducen
## con una linea de tiempo comun de un ciclo (AnimationNodeAnimation.use_custom_timeline) y sus fases coinciden al mezclar.

const HUMAN_SCENE := "res://assets/characters/json/json_human.scn"
const KIT_SHADER_PATH := "res://assets/characters/json/json_kit.gdshader"

## Escalones de la marcha sin pelota: [clip, velocidad (m/s) a la que se reproduce a su ritmo natural]. -1 = la velocidad
## natural medida del clip (meta natural_speed). El reposo va a velocidad 0.
const GAIT := [
	[&"jn_idle_0520", 0.0], [&"jn_walk_0460", -1.0], [&"jn_jog_1144", -1.0], [&"jn_jog_2390", -1.0], [&"jn_sprint_3022", -1.0],
]
## Marcha con la pelota (conduccion): reposo con balon y ciclos de conduccion cada vez mas rapidos.
const CARRY := [
	[&"jn_idle_ball_0524", 0.0], [&"jn_dribble_walk_0234", -1.0], [&"jn_dribble_jog_1574", -1.0], [&"jn_dribble_run_3186", -1.0],
	[&"jn_dribble_fast_0548", -1.0], [&"jn_dribble_sprint_1582", -1.0],
]
## Roles de la mezcla direccional (marcaje, arquero): la direccion de cada clip sale de su meta natural_dir.
const DIR_ROLES: Array[StringName] = [&"dir_back", &"dir_back_diag", &"dir_fwd_diag", &"dir_side", &"dir_back_walk", &"dir_fwd_diag_walk"]

static func active() -> bool:
	return PackLibrary.json_mode()

## Modelo del modo: el humanoide propio (el GLB de Tripo adaptado se descarto: se deformaba con estas animaciones).
static func model_path() -> String:
	return HUMAN_SCENE if ResourceLoader.exists(HUMAN_SCENE) else ""

static func is_human_model(path: String) -> bool:
	return path == HUMAN_SCENE

## Escalones [clip, posicion en el BlendSpace (m/s)] de la marcha (carry: con pelota) que existen en la libreria.
static func gait_points(carry: bool) -> Array:
	var out: Array = []
	for pt in (CARRY if carry else GAIT):
		var id: StringName = pt[0]
		if not PackLibrary.has_clip(id):
			continue
		var pos: float = float(pt[1])
		if pos < 0.0:
			pos = float(PackLibrary.meta(id).get("natural_speed", 0.0))
		out.append([id, pos])
	return out

## Longitud de zancada (m por ciclo) de un escalon: velocidad natural por duracion del ciclo.
static func stride_of(id: StringName) -> float:
	var m: Dictionary = PackLibrary.meta(id)
	return float(m.get("natural_speed", 0.0)) * float(m.get("duration", 1.0))

## Ciclos por segundo de la marcha a una velocidad: la velocidad dividida por la zancada interpolada entre los escalones;
## parado, el ritmo del reposo.
static func cycles_per_second(speed: float, carry: bool) -> float:
	var pts: Array = gait_points(carry)
	if pts.size() < 2:
		return 1.0
	var idle_len: float = float(PackLibrary.meta(pts[0][0]).get("duration", 3.0))
	var idle_cps: float = 1.0 / maxf(idle_len, 0.3)
	if speed <= 0.1:
		return idle_cps
	var stride: float = stride_of(pts[pts.size() - 1][0])
	if speed < float(pts[pts.size() - 1][1]):
		for i in range(1, pts.size()):
			var a: Array = pts[i - 1]
			var b: Array = pts[i]
			if speed <= float(b[1]):
				var sa: float = stride_of(a[0]) if i > 1 else stride_of(b[0])
				var u: float = clampf((speed - float(a[1])) / maxf(float(b[1]) - float(a[1]), 0.001), 0.0, 1.0)
				stride = lerpf(sa, stride_of(b[0]), u)
				break
	return maxf(speed / maxf(stride, 0.2), idle_cps)

## Candidatos de patada de un tipo: [{clip, foot, contact, ks}] con el contacto medido del clip. charge (0..1) elige la clase de
## potencia: el pase suave con poca carga, el tiro fuerte con carga alta.
static func kick_candidates(kind: StringName, charge: float) -> Array:
	var roles: Array = []
	match kind:
		&"shot":
			roles = [&"kick_shot", &"kick_shot_hard"] if charge >= 0.45 else [&"kick_shot"]
		&"lob":
			roles = [&"kick_lob"]
		&"cross":
			roles = [&"kick_lob", &"kick_pass"]
		_:
			roles = [&"kick_pass_soft", &"kick_pass"] if charge < 0.35 else ([&"kick_pass", &"kick_shot"] if charge >= 0.8 else [&"kick_pass"])
	var key: String = String(kind) + ("+" if charge >= 0.45 else "-") + ("s" if charge < 0.35 else ("h" if charge >= 0.8 else "m"))
	if _kick_cache.has(key):
		return _kick_cache[key]
	var out: Array = []
	for r in roles:
		for id in PackLibrary.by_role(r):
			var m: Dictionary = PackLibrary.meta(id)
			if not m.has("contact"):
				continue
			# Solo golpeos limpios (contacto medido al convertir): pie bajo delante del cuerpo, apoyo en el suelo, hacia delante.
			if not bool(m["contact"].get("clean", true)):
				continue
			out.append({"clip": id, "foot": m["contact"]["foot"], "contact": m["contact"], "role": r})
	_kick_cache[key] = out
	return out

static var _kick_cache: Dictionary = {}

## Situaciones de presentacion (AnimationCatalog.FIELD) -> roles de los clips JSON. Se elige entre TODOS los clips de esos
## roles que se pueden reproducir en el sitio (poco recorrido de raiz): festejos, lamentos, enojo, aplausos, gestos,
## calentamiento. Cada pedido toma otro clip.
const SITUATION_ROLES := {
	&"celebrate": [&"celebrate", &"clap"],
	&"celebrate_scorer": [&"celebrate_scorer", &"celebrate"],
	&"celebrate_team": [&"celebrate_team", &"clap", &"celebrate"],
	&"thumbs_up": [&"thumbs_up", &"clap", &"gesture"],
	&"dejected": [&"dejected"],
	&"angry": [&"angry", &"dejected"],
	&"frustrated": [&"angry", &"dejected"],
	&"victory_end": [&"celebrate", &"celebrate_scorer", &"celebrate_team"],
	&"defeat_end": [&"defeat_end", &"dejected"],
	&"draw_end": [&"clap", &"gesture", &"nis_idle"],
	&"warmup": [&"warmup"],
	&"idle_fidget": [&"idle_fidget", &"nis_idle", &"idle_ready"],
	&"tackle_stand": [&"tackle_stand"],
	&"press_duel": [&"jostle", &"tackle_stand"],
	&"wall": [&"wall"],
}
## Recorrido de raiz maximo (m) de un clip de presentacion (se reproduce en el sitio).
const SITUATION_ROOT_MAX := 1.0
static var _situation_cache: Dictionary = {}
static var _situation_turn: int = 0

## Clip para una situacion de presentacion (modo 4), o &"" si no hay. pick: preferencia del que lo pide (su id).
static func situation_clip(situation: StringName, pick: int) -> StringName:
	if not SITUATION_ROLES.has(situation):
		return &""
	if not _situation_cache.has(situation):
		var pool: Array[StringName] = []
		for role in SITUATION_ROLES[situation]:
			for id in PackLibrary.by_role(role):
				if String(id).ends_with("_mirror"):
					continue
				var m: Dictionary = PackLibrary.meta(id)
				if (m.get("root_total", Vector2.ZERO) as Vector2).length() <= SITUATION_ROOT_MAX and float(m.get("duration", 0.0)) >= 0.6:
					pool.append(id)
		_situation_cache[situation] = pool
	var p: Array = _situation_cache[situation]
	if p.is_empty():
		return &""
	_situation_turn += 1
	return p[(absi(pick) * 7 + _situation_turn * 13) % p.size()]

## Vacia las listas calculadas (cambian al recargar la libreria).
static func reset_caches() -> void:
	_kick_cache = {}
	_situation_cache = {}
