class_name MatchContext
extends RefCounted
## Vista compartida del partido para controladores, asistencias e IA.
## Contiene referencias a entidades y un bus de eventos; NO contiene reglas.
## Convencion: el equipo 0 defiende el arco -X y ataca el arco +X; el equipo 1 al reves.

signal event_emitted(event: GameEvent)

var ball: Ball
var pitch: Pitch
var camera: MatchCamera
var footballers: Array[Footballer] = []
var keepers: Array = []          # Goalkeeper (se tipa como Array para evitar dependencia circular)
var match_time: float = 0.0
var tick: int = 0
## Si es false, los futbolistas ignoran la entrada (saque, celebracion, fin de partido).
var input_enabled: bool = true
## Segundos seguidos que la pelota lleva practicamente parada y sin que nadie la sostenga. Lo actualiza MatchManager
## y lo usa la IA para romper un atasco: si la jugada se muere, el mas cercano de cada equipo va a buscarla.
var ball_stall_seconds: float = 0.0

## Actualiza el contador de pelota muerta (lo llama MatchManager cada paso de fisica mientras se juega).
func update_ball_stall(delta: float) -> void:
	if ball != null and not ball.is_held() and ball.linear_velocity.length() < 0.6:
		ball_stall_seconds += delta
	else:
		ball_stall_seconds = 0.0

func emit_event(e: GameEvent) -> void:
	e.tick = tick
	e.match_time = match_time
	event_emitted.emit(e)

func register_footballer(f: Footballer) -> void:
	if not footballers.has(f):
		footballers.append(f)

func unregister_footballer(f: Footballer) -> void:
	footballers.erase(f)

func teammates_of(p: Footballer) -> Array[Footballer]:
	var out: Array[Footballer] = []
	for f in footballers:
		if f != p and f.team == p.team:
			out.append(f)
	return out

func opponents_of(p: Footballer) -> Array[Footballer]:
	var out: Array[Footballer] = []
	for f in footballers:
		if f.team != p.team:
			out.append(f)
	return out

func opponents_of_team(team: int) -> Array[Footballer]:
	var out: Array[Footballer] = []
	for f in footballers:
		if f.team != team:
			out.append(f)
	return out

## Arco que ataca un equipo: el equipo 0 ataca +X.
func attacking_goal(team: int) -> Goal:
	return pitch.get_goal(1 if team == 0 else -1)

func defending_goal(team: int) -> Goal:
	return pitch.get_goal(-1 if team == 0 else 1)

func register_keeper(k: Node) -> void:
	if not keepers.has(k):
		keepers.append(k)

func unregister_keeper(k: Node) -> void:
	keepers.erase(k)

func keeper_defending(team: int) -> Node:
	for k in keepers:
		if int(k.get("team")) == team:
			return k
	return null

## Jugador (no arquero) del equipo dado mas cercano a un punto.
func nearest_footballer(pos: Vector3, team: int = -1, exclude: Footballer = null) -> Footballer:
	var best: Footballer = null
	var best_d: float = INF
	for f in footballers:
		if f == exclude or (team >= 0 and f.team != team):
			continue
		var d: float = Vector2(f.global_position.x - pos.x, f.global_position.z - pos.z).length()
		if d < best_d:
			best_d = d
			best = f
	return best

## Convierte un vector 2D de pantalla en direccion de mundo usando la camara si existe.
func screen_to_world(v: Vector2) -> Vector3:
	if camera != null and is_instance_valid(camera):
		return camera.screen_to_world_dir(v)
	return Vector3(v.x, 0.0, v.y)
