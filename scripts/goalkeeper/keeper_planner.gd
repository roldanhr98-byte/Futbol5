class_name KeeperPlanner
extends RefCounted
## Planificador de atajadas (puro, sin nodos). Dada la trayectoria predicha de la pelota, elige entre los clips del
## arquero cual hace que las MANOS lleguen a la pelota: usa la trayectoria de manos medida de cada clip (con el
## desplazamiento de la raiz incluido), el instante de inicio y la velocidad de reproduccion.

## Clips de atajada y radio de contacto de las manos (m). Los espejos "_mirror" se agregan solos si existen.
const SAVE_CLIPS := {
	&"goalkeeper_catch": 0.40, &"goalkeeper_catch_2": 0.40, &"goalkeeper_catch_3": 0.42, &"goalkeeper_catch_4": 0.42,
	&"goalkeeper_body_block": 0.60, &"goalkeeper_body_block_2": 0.60, &"goalkeeper_body_block_3": 0.60,
	&"goalkeeper_diving_save": 0.50, &"goalkeeper_diving_save_2": 0.50,
	&"goalkeeper_scoop": 0.40, &"goalkeeper_sidestep": 0.45, &"goalkeeper_sidestep_2": 0.45,
}
## Recogida de pelota suelta y lenta: solo clips bajos (nada de estiradas ni bloqueos con el cuerpo).
const PICKUP_CLIPS := [&"goalkeeper_scoop", &"goalkeeper_catch", &"goalkeeper_catch_2", &"goalkeeper_catch_4"]
## Altura maxima (m) de las manos en el contacto de una recogida.
const PICKUP_MAX_HANDS_Y := 0.7

## Modo 4: roles de los clips de atajada y su radio de contacto de las manos (m).
const JSON_ROLE_RADIUS := {&"gk_catch": 0.42, &"gk_dive": 0.50, &"gk_scoop": 0.40, &"gk_sidestep": 0.45, &"gk_block": 0.60}

## Manos del arquero en la posicion de espera, en el marco del cuerpo (adelante, arriba, derecha).
const READY_HANDS := Vector3(0.35, 1.0, 0.0)

static func _role(id: StringName) -> StringName:
	if _role_cache.has(id):
		return _role_cache[id]
	var role := StringName(String(PackLibrary.meta(id).get("role", "")))
	_role_cache[id] = role
	return role

static func candidates() -> Array[StringName]:
	var out: Array[StringName] = []
	if PackLibrary.json_mode():
		for r in JSON_ROLE_RADIUS:
			out.append_array(PackLibrary.by_role(r))
		return out
	for id in SAVE_CLIPS:
		if PackLibrary.has_clip(id):
			out.append(id)
		var m := StringName(String(id) + "_mirror")
		if PackLibrary.has_clip(m):
			out.append(m)
	return out

static func radius_of(id: StringName) -> float:
	var scale: float = Tuning.keeper.contact_scale if Tuning.keeper != null else 1.0
	if PackLibrary.json_mode():
		return float(JSON_ROLE_RADIUS.get(_role(id), 0.45)) * scale
	var base := StringName(String(id).trim_suffix("_mirror"))
	return float(SAVE_CLIPS.get(base, 0.45)) * scale

## Posicion MUNDIAL de un punto de interes ("hands", "toe_l", "toe_r", "head") del clip en la muestra k, con el cuerpo
## en `origin` mirando a `yaw` al INICIO del clip (la trayectoria ya incluye el desplazamiento de la raiz).
static func path_world(id: StringName, key: String, k: int, origin: Vector3, yaw: float) -> Vector3:
	var hp: PackedVector3Array = PackLibrary.meta(id).get("paths", {}).get(key, PackedVector3Array())
	if hp.is_empty():
		return origin
	var h: Vector3 = hp[clampi(k, 0, hp.size() - 1)]
	var f: Vector3 = Locomotion.dir_from_yaw(yaw)
	var r := Vector3(-f.z, 0.0, f.x)
	return Vector3(origin.x, 0.0, origin.z) + f * h.x + r * h.z + Vector3.UP * h.y

## Igual que path_world pero con el cuerpo YA movido por la raiz: `body` es la posicion actual del arquero. Resta el
## desplazamiento de raiz acumulado en la muestra k, asi que sigue valiendo si una colision desvio al arquero.
static func path_world_at_body(id: StringName, key: String, k: int, body: Vector3, yaw: float) -> Vector3:
	var meta: Dictionary = PackLibrary.meta(id)
	var hp: PackedVector3Array = meta.get("paths", {}).get(key, PackedVector3Array())
	var rp: PackedVector2Array = meta.get("root_path", PackedVector2Array())
	if hp.is_empty():
		return body
	var kk: int = clampi(k, 0, hp.size() - 1)
	var h: Vector3 = hp[kk]
	var ro: Vector2 = rp[mini(kk, rp.size() - 1)] if rp.size() > 0 else Vector2.ZERO
	var f: Vector3 = Locomotion.dir_from_yaw(yaw)
	var r := Vector3(-f.z, 0.0, f.x)
	return Vector3(body.x, 0.0, body.z) + f * (h.x - ro.x) + r * (h.z - ro.y) + Vector3.UP * h.y

## Instante (s del clip) de maxima velocidad de un punto de interes: lanzamiento de una mano o golpeo de un pie.
static func peak_speed_time(id: StringName, key: String) -> float:
	var hp: PackedVector3Array = PackLibrary.meta(id).get("paths", {}).get(key, PackedVector3Array())
	var best_i: int = 0
	var best_v: float = -1.0
	for i in range(1, hp.size() - 1):
		var v: float = (hp[i + 1] - hp[i - 1]).length()
		if v > best_v:
			best_v = v
			best_i = i
	return float(best_i) / 30.0

## Posicion MUNDIAL de las manos en el instante k (muestra a 30 Hz) del clip, con el cuerpo en `origin` mirando a `yaw`
## al inicio del clip (el desplazamiento de la raiz ya esta incluido en la trayectoria).
static func hands_world(id: StringName, k: int, origin: Vector3, yaw: float) -> Vector3:
	var hp: PackedVector3Array = PackLibrary.meta(id).get("paths", {}).get("hands", PackedVector3Array())
	if hp.is_empty():
		return origin
	var h: Vector3 = hp[clampi(k, 0, hp.size() - 1)]
	var f: Vector3 = Locomotion.dir_from_yaw(yaw)
	var r := Vector3(-f.z, 0.0, f.x)
	return Vector3(origin.x, 0.0, origin.z) + f * h.x + r * h.z + Vector3.UP * h.y

## Costo (por segundo de clip) que suma un clip largo entre los que llegan: a igual estilo, el que se recupera antes.
const DURATION_COST := 0.06

## Preferencia de estilo entre los clips que SI llegan (suma al puntaje; menor = mas natural): atrapar antes que
## estirarse, estirarse antes que dar un paso lateral, y bloquear con el cuerpo solo si no queda otra.
static func style_penalty(id: StringName) -> float:
	if PackLibrary.json_mode():
		match _role(id):
			&"gk_catch", &"gk_scoop":
				return 0.0
			&"gk_dive":
				return 0.12
			&"gk_sidestep":
				return 0.18
		return 0.30
	var n: String = String(id)
	if n.contains("scoop") or n.contains("catch"):
		return 0.0
	if n.contains("diving"):
		return 0.12
	if n.contains("sidestep"):
		return 0.18
	return 0.30

static var _bbox_cache: Dictionary = {}
## Rol de cada clip (se consulta en el bucle interno de plan_save).
static var _role_cache: Dictionary = {}

## Vacia los datos calculados con la libreria de clips (cambian al cambiar de modo).
static func reset_caches() -> void:
	_bbox_cache = {}
	_role_cache = {}

## Caja (min, max) de la trayectoria de manos de un clip en el marco del cuerpo (adelante, arriba, derecha).
static func _bbox(id: StringName, hp: PackedVector3Array) -> Array:
	if _bbox_cache.has(id):
		return _bbox_cache[id]
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for h in hp:
		lo = Vector3(minf(lo.x, h.x), minf(lo.y, h.y), minf(lo.z, h.z))
		hi = Vector3(maxf(hi.x, h.x), maxf(hi.y, h.y), maxf(hi.z, h.z))
	_bbox_cache[id] = [lo, hi]
	return [lo, hi]

## Planifica una atajada. traj: posiciones de la pelota cada `step` s (0 = ahora). min_delay: segundos hasta que el
## arquero puede empezar a moverse. Usa la aproximacion CONTINUA entre cada manos(k) y la poligonal de la pelota.
## human: (latencia s, velocidad m/s) del limite humano de las manos: desde ahora, las manos no llegan a un punto antes de
## latencia + distancia desde la posicion de espera (READY_HANDS) / velocidad, aunque el clip lo haga mas rapido (varios
## clips empiezan con la estirada ya lanzada). Vector2.ZERO = sin limite.
## Devuelve {} o {clip, speed, k, tau, delay, arrive, dist, radius, travel}.
static func plan_save(origin: Vector3, yaw: float, traj: PackedVector3Array, step: float, min_delay: float,
		_ball_speed: float, pickup: bool, speeds: Array = [1.0, 1.4], human: Vector2 = Vector2.ZERO) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = INF
	var best_dist: float = INF
	var f: Vector3 = Locomotion.dir_from_yaw(yaw)
	var r := Vector3(-f.z, 0.0, f.x)
	var o := Vector3(origin.x, 0.0, origin.z)
	# Pelota en el marco local del arquero (adelante, arriba, derecha) y ventana donde esta al alcance (< 4.5 m).
	var local := PackedVector3Array()
	var first: int = -1
	var last: int = -1
	var wlo := Vector3(INF, INF, INF)
	var whi := Vector3(-INF, -INF, -INF)
	for i in traj.size():
		var d: Vector3 = traj[i] - o
		var lp := Vector3(d.dot(f), traj[i].y, d.dot(r))
		local.append(lp)
		if float(i) * step >= min_delay and Vector2(lp.x, lp.z).length() <= 4.5:
			if first < 0:
				first = i
			last = i
			wlo = Vector3(minf(wlo.x, lp.x), minf(wlo.y, lp.y), minf(wlo.z, lp.z))
			whi = Vector3(maxf(whi.x, lp.x), maxf(whi.y, lp.y), maxf(whi.z, lp.z))
	if first < 0:
		return {}
	var seg_hi: int = mini(last, local.size() - 2)
	# La caja incluye el final del ultimo segmento que se recorre (puede quedar fuera de la ventana de 4.5 m).
	var tail: Vector3 = local[seg_hi + 1]
	wlo = Vector3(minf(wlo.x, tail.x), minf(wlo.y, tail.y), minf(wlo.z, tail.z))
	whi = Vector3(maxf(whi.x, tail.x), maxf(whi.y, tail.y), maxf(whi.z, tail.z))
	# Caja de cada segmento de la pelota: descarta sin proyectar los segmentos que no pueden mejorar el resultado.
	var seg_lo := PackedVector3Array()
	var seg_hi_box := PackedVector3Array()
	seg_lo.resize(local.size())
	seg_hi_box.resize(local.size())
	for i in range(first, seg_hi + 1):
		var a0: Vector3 = local[i]
		var a1: Vector3 = local[i + 1]
		seg_lo[i] = Vector3(minf(a0.x, a1.x), minf(a0.y, a1.y), minf(a0.z, a1.z))
		seg_hi_box[i] = Vector3(maxf(a0.x, a1.x), maxf(a0.y, a1.y), maxf(a0.z, a1.z))
	for id in candidates():
		var is_pickup_clip: bool = PICKUP_CLIPS.has(StringName(String(id).trim_suffix("_mirror")))
		if pickup != is_pickup_clip and (pickup or String(id).begins_with("goalkeeper_scoop")):
			continue
		var meta: Dictionary = PackLibrary.meta(id)
		var hp: PackedVector3Array = meta.get("paths", {}).get("hands", PackedVector3Array())
		if hp.is_empty():
			continue
		var rad: float = radius_of(id)
		var bb: Array = _bbox(id, hp)
		var lo: Vector3 = bb[0] - Vector3.ONE * (rad + 0.9)
		var hi: Vector3 = bb[1] + Vector3.ONE * (rad + 0.9)
		if whi.x < lo.x or wlo.x > hi.x or whi.y < lo.y or wlo.y > hi.y or whi.z < lo.z or wlo.z > hi.z:
			continue
		var rp: PackedVector2Array = meta.get("root_path", PackedVector2Array())
		for sp in speeds:
			var k: int = 6
			while k < hp.size():
				var h: Vector3 = hp[k]
				if pickup and h.y > PICKUP_MAX_HANDS_Y:
					k += 2
					continue
				# Manos fuera de la caja que barre la pelota (+ radio): ningun segmento puede quedar mas cerca que
				# best_dist ni dentro del radio (mismo resultado, sin recorrer la trayectoria).
				var gap: float = maxf(maxf(wlo.x - h.x, h.x - whi.x), maxf(maxf(wlo.y - h.y, h.y - whi.y), maxf(wlo.z - h.z, h.z - whi.z)))
				if gap > rad and gap > best_dist:
					k += 2
					continue
				var tau: float = float(k) / 30.0
				var earliest: float = min_delay + tau / sp
				if human.y > 0.0:
					earliest = maxf(earliest, min_delay + human.x + (h - READY_HANDS).length() / human.y)
				var i: int = maxi(first, int(floor(earliest / step)))
				while i <= seg_hi:
					var sl: Vector3 = seg_lo[i]
					var sh: Vector3 = seg_hi_box[i]
					var sgap: float = maxf(maxf(sl.x - h.x, h.x - sh.x), maxf(maxf(sl.y - h.y, h.y - sh.y), maxf(sl.z - h.z, h.z - sh.z)))
					if sgap > rad and sgap > best_dist:
						i += 1
						continue
					var a: Vector3 = local[i]
					var ab: Vector3 = local[i + 1] - a
					var len2: float = ab.length_squared()
					var u: float = clampf((h - a).dot(ab) / len2, 0.0, 1.0) if len2 > 1e-8 else 0.0
					var t_arr: float = (float(i) + u) * step
					if t_arr >= earliest:
						var dist: float = (a + ab * u - h).length()
						if dist < rad * 0.85 or dist < best_dist:
							best_dist = minf(best_dist, dist)
							var travel: float = rp[mini(k, rp.size() - 1)].length() if rp.size() > 0 else 0.0
							# Valido = las manos llegan con holgura (85 % del radio): se elige el estilo mas natural.
							# Si ninguno llega con holgura, gana el que queda mas cerca (puntaje alto = intento forzado).
							var score: float
							if dist <= rad * 0.85:
								# Entre los que llegan, los cortos (se recupera antes: no se tira al suelo por una pelota mansa).
								score = style_penalty(id) + 0.03 * travel + (0.05 if sp > 1.0 else 0.0) + 0.2 * dist / rad \
									+ DURATION_COST * float(meta.get("duration", 1.0)) / sp
							else:
								score = 5.0 + dist
							if score < best_score:
								best_score = score
								best = {"clip": id, "speed": sp, "k": k, "tau": tau, "arrive": t_arr, "dist": dist,
									"radius": rad, "delay": maxf(t_arr - tau / sp, min_delay), "travel": travel}
					i += 1
				k += 2
	return best
